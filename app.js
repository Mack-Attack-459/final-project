/* Connects the static gallery pages to the PHP/MySQL API in /api. */
(() => {
  const escapeHTML = (value = "") => String(value).replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);
  const money = value => value == null || value === "" ? "Not for sale" : `$${Number(value).toFixed(2)}`;
  const mediumClass = medium => /photo|photograph|camera/i.test(medium) ? "photo" : "painting";
  const statusClass = status => status === "Sold" ? "sold" : status === "Not for Sale" ? "unavailable" : "available";
  function setupImageFallbacks(root = document) {
    root.querySelectorAll("img:not([data-fallback-bound])").forEach(image => {
      image.dataset.fallbackBound = "true";
      image.addEventListener("error", () => {
        if (image.dataset.fallbackShown) return;
        image.dataset.fallbackShown = "true";
        image.src = "assets/bloom.png";
      });
    });
  }
  let activeUser = null;

  async function api(path, options = {}) {
    const response = await fetch(`api/${path}`, {
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", ...(options.headers || {}) },
      ...options,
    });
    let data;
    try { data = await response.json(); }
    catch { throw new Error("The PHP API did not return JSON. Start the PHP server to use the connected features."); }
    if (!response.ok) throw new Error(data.error || `Request failed (${response.status}).`);
    return data;
  }

  const request = (path, body, method = "POST") => api(path, { method, body: JSON.stringify(body) });
  const setMessage = (form, text, isError = false) => {
    const target = form.querySelector(".form-message");
    if (!target) return;
    target.textContent = text;
    target.classList.toggle("error", isError);
  };
  const reportBackendIssue = error => {
    console.warn("Campus Artwork Exhibit API:", error.message);
    const main = document.querySelector("main");
    if (!main || main.querySelector(".backend-notice")) return;
    const notice = document.createElement("p");
    notice.className = "notice backend-notice";
    notice.setAttribute("role", "status");
    notice.textContent = "Live database features are unavailable. Start PHP and MySQL using the README setup steps.";
    main.prepend(notice);
  };

  function updateNavigation() {
    document.querySelectorAll('.header > a[href="account.html"]').forEach(link => {
      link.textContent = activeUser ? `Hi, ${activeUser.first_name}` : "My account";
      link.setAttribute("aria-label", activeUser ? `Account for ${activeUser.first_name}` : "My account");
    });
    const header = document.querySelector(".header");
    if (activeUser?.role === "Administrator" && header && !header.querySelector(".admin-link")) {
      const link = document.createElement("a");
      link.className = "pill admin-link";
      link.href = "admin.html";
      link.textContent = "Gallery admin";
      header.append(link);
    } else if (activeUser?.role !== "Administrator") header?.querySelector(".admin-link")?.remove();
  }

  function authForms() {
    const signup = document.querySelector('[data-form="signup"]');
    signup?.addEventListener("submit", async event => {
      event.preventDefault();
      const data = new FormData(signup);
      try {
        const result = await request("auth.php", {
          action: "signup", firstName: data.get("firstName"), lastName: data.get("lastName"),
          email: data.get("email"), password: data.get("password"), role: data.get("role")
        });
        activeUser = result.user;
        location.href = activeUser.role === "Artist" ? "studio.html" : activeUser.role === "Administrator" ? "admin.html" : "account.html";
      } catch (error) { setMessage(signup, error.message, true); }
    });

    const signin = document.querySelector('[data-form="signin"]');
    signin?.addEventListener("submit", async event => {
      event.preventDefault();
      const data = new FormData(signin);
      try {
        const result = await request("auth.php", { action: "signin", email: data.get("email"), password: data.get("password") });
        activeUser = result.user;
        location.href = activeUser.role === "Artist" ? "studio.html" : activeUser.role === "Administrator" ? "admin.html" : "account.html";
      } catch (error) { setMessage(signin, error.message, true); }
    });

    document.addEventListener("click", async event => {
      if (!event.target.closest("[data-signout]")) return;
      event.preventDefault();
      try { await request("auth.php", { action: "signout" }); }
      catch (error) { console.warn("Sign-out request:", error.message); }
      location.href = "index.html";
    });
  }

  async function loadProfile() {
    try {
      const result = await api("profile.php", { method: "GET" });
      activeUser = result.user;
      return result.user;
    } catch (error) {
      if (!(error.message === "Please sign in first.")) reportBackendIssue(error);
      return null;
    }
  }

  async function profileForm() {
    const form = document.querySelector('[data-form="profile"]');
    if (!form) return;
    const user = activeUser || await loadProfile();
    if (!user || user.role !== "Artist") { location.href = "sign-in.html"; return; }
    const profile = user.profile || {};
    form.elements.displayName.value = profile.display_name || `${user.first_name} ${user.last_name}`;
    form.elements.medium.value = profile.art_medium || "";
    form.elements.photoUrl.value = profile.profile_photo_url || "";
    form.elements.biography.value = profile.biography || "";
    form.addEventListener("submit", async event => {
      event.preventDefault();
      try {
        await request("profile.php", {
          firstName: user.first_name, lastName: user.last_name, email: user.email,
          displayName: form.elements.displayName.value.trim(), medium: form.elements.medium.value.trim(),
          photoUrl: form.elements.photoUrl.value.trim(), biography: form.elements.biography.value.trim()
        });
        setMessage(form, "Profile saved to the Campus Artwork Exhibit database.");
      } catch (error) { setMessage(form, error.message, true); }
    });
  }

  async function artworkForm() {
    const form = document.querySelector('[data-form="artwork"]');
    if (!form) return;
    const user = activeUser || await loadProfile();
    if (!user || user.role !== "Artist") { location.href = "sign-in.html"; return; }
    form.elements.year.value = new Date().getFullYear();
    form.elements.imageUrl.addEventListener("input", () => {
      if (form.elements.imageUrl.value) document.querySelector(".work-form figure .art").src = form.elements.imageUrl.value;
    });
    form.addEventListener("submit", async event => {
      event.preventDefault();
      const data = new FormData(form);
      try {
        await request("artworks.php", {
          title: data.get("title"), imageUrl: data.get("imageUrl"), medium: data.get("medium"),
          year: data.get("year"), price: data.get("price"), description: data.get("description"), availability: data.get("availability")
        });
        location.href = "studio.html?added=1";
      } catch (error) { setMessage(form, error.message, true); }
    });
  }

  function artworkCard(item) {
    const status = String(item.availability || "Available");
    const price = status === "Available" && item.price != null ? `${money(item.price)} · Available` : status;
    return `<article class="art-card ${mediumClass(item.medium)} ${statusClass(status)}" data-db-art="${Number(item.id)}"><a href="artwork.html?id=${Number(item.id)}"><img class="art" src="${escapeHTML(item.imageUrl)}" alt="Artwork: ${escapeHTML(item.title)}" loading="lazy"><h3>${escapeHTML(item.title)}</h3></a><p>${escapeHTML(item.artistName)}</p><p>${escapeHTML(price)}</p></article>`;
  }

  function bindCollectionFilters() {
    const collection = document.querySelector(".collection");
    if (!collection) return;
    const apply = () => {
      const medium = collection.querySelector('input[name="medium"]:checked')?.value || "all";
      const status = collection.querySelector(".collection-meta select")?.value || "any";
      let visible = 0;
      collection.querySelectorAll(".art-grid .art-card").forEach(card => {
        const show = (medium === "all" || card.classList.contains(medium)) && (status === "any" || card.classList.contains(status));
        card.hidden = !show;
        if (show) visible++;
      });
      const count = collection.querySelector(".count");
      if (count) count.textContent = `${visible} ${visible === 1 ? "artwork" : "artworks"}`;
      const empty = collection.querySelector(".empty");
      if (empty) empty.hidden = visible !== 0;
    };
    collection.querySelectorAll('input[name="medium"]').forEach(input => input.addEventListener("change", apply));
    collection.querySelector(".collection-meta select")?.addEventListener("change", apply);
    apply();
  }

  async function renderCollection() {
    const grid = document.querySelector(".collection .art-grid");
    if (!grid) return;
    try {
      const result = await api("artworks.php", { method: "GET" });
      const empty = grid.querySelector(".empty");
      result.artworks.forEach(item => {
        if (!grid.querySelector(`[data-db-art="${Number(item.id)}"]`)) empty.insertAdjacentHTML("beforebegin", artworkCard(item));
      });
      setupImageFallbacks(grid);
    } catch (error) { reportBackendIssue(error); }
    bindCollectionFilters();
  }

  async function renderStudio() {
    const section = document.querySelector(".page-studio .studio");
    if (!section) return;
    const user = activeUser || await loadProfile();
    if (!user || user.role !== "Artist") { location.href = "sign-in.html"; return; }
    try {
      const result = await api("artworks.php?mine=1", { method: "GET" });
      const grid = section.querySelector(".studio-grid");
      const sale = grid.querySelector(".sale");
      grid.querySelectorAll(".art-card").forEach(card => card.remove());
      sale.hidden = true;
      const stats = section.querySelectorAll(".stat strong");
      if (stats[0]) stats[0].textContent = String(result.artworks.length);
      if (stats[1]) stats[1].textContent = "0";
      if (stats[2]) stats[2].textContent = "0";
      if (result.artworks.length) {
        result.artworks.forEach(item => sale.insertAdjacentHTML("beforebegin", artworkCard(item)));
      } else {
        const empty = document.createElement("p");
        empty.className = "studio-empty";
        empty.textContent = "Your registered artwork will appear here. Start by adding your first piece.";
        grid.prepend(empty);
      }
      setupImageFallbacks(grid);
      const added = new URLSearchParams(location.search).get("added");
      if (added) {
        const notice = document.createElement("p");
        notice.className = "notice";
        notice.setAttribute("role", "status");
        notice.textContent = "Your artwork has been saved to the database and added to your studio.";
        section.prepend(notice);
        history.replaceState(null, "", "studio.html");
      }
    } catch (error) { reportBackendIssue(error); }
  }

  async function renderAccount() {
    if (!document.querySelector(".page-account")) return;
    const user = activeUser || await loadProfile();
    if (!user) { location.href = "sign-in.html"; return; }
    document.querySelector(".page-account .intro h1").textContent = `Hello, ${user.first_name}.`;
    const section = document.querySelector(".account > section");
    const customer = user.profile || {};
    section.innerHTML = `<form class="form" data-form="contact"><h2>Contact details</h2><label for="email-address">Email address<input type="email" id="email-address" name="email" value="${escapeHTML(user.email)}" required></label><label for="phone-number">Phone number (optional)<input type="tel" id="phone-number" name="phone" value="${escapeHTML(customer.phone_number || "")}"></label><div class="actions"><button class="pill solid">Save details</button><a class="pill" href="index.html" data-signout>Sign out</a></div><p class="form-message" role="status" aria-live="polite"></p></form>`;
    section.querySelector("form").addEventListener("submit", async event => {
      event.preventDefault();
      const form = event.currentTarget;
      try {
        await request("profile.php", { firstName: user.first_name, lastName: user.last_name, email: form.elements.email.value, phone: form.elements.phone.value });
        user.email = form.elements.email.value.trim();
        setMessage(form, "Your contact details were saved.");
        updateNavigation();
      } catch (error) { setMessage(form, error.message, true); }
    });
    document.querySelectorAll("#purchases article.purchase").forEach(card => card.remove());
    const note = document.querySelector("#purchases > p");
    if (user.role === "Customer") {
      try {
        const result = await api("purchases.php", { method: "GET" });
        result.purchases.forEach(purchase => {
          const article = document.createElement("article");
          article.className = "panel purchase";
          article.innerHTML = `<img class="art" src="${escapeHTML(purchase.imageUrl)}" alt="Artwork: ${escapeHTML(purchase.artworkTitle)}"><div><h3>${escapeHTML(purchase.artworkTitle)}</h3><p>${escapeHTML(purchase.artistName)}</p><p>${money(purchase.amount)} · ${escapeHTML(purchase.status)}</p><p>${escapeHTML(purchase.saleDate)} · Sale #${Number(purchase.id)}</p></div>`;
          note?.before(article);
          setupImageFallbacks(article);
        });
        if (note) note.textContent = result.purchases.length ? "Your recorded purchases." : "No purchases have been recorded for this account yet.";
      } catch (error) { if (note) note.textContent = error.message; }
    } else if (note) note.textContent = user.role === "Artist" ? "Purchases appear here once the gallery records a completed sale." : "Purchase history is available to customer accounts.";
  }

  async function renderArtists() {
    const list = document.querySelector(".artist-list");
    if (!list) return;
    try {
      const [artistResult, artworkResult] = await Promise.all([api("artists.php", { method: "GET" }), api("artworks.php", { method: "GET" })]);
      const jumpList = document.querySelector(".artist-jump ul");
      artistResult.artists.forEach(artist => {
        const id = `database-artist-${Number(artist.id)}`;
        if (document.getElementById(id)) return;
        const link = document.createElement("li");
        link.innerHTML = `<a href="#${id}">${escapeHTML(artist.displayName)}</a>`;
        jumpList?.append(link);
        const row = document.createElement("div");
        row.className = "artist-row";
        row.innerHTML = `<strong>${escapeHTML(artist.displayName)}</strong><small>${escapeHTML(artist.medium)}</small><a class="pill solid" href="#${id}" aria-label="View profile for ${escapeHTML(artist.displayName)}">View profile</a>`;
        list.append(row);
        const works = artworkResult.artworks.filter(item => Number(item.artist_id) === Number(artist.id));
        const photo = artist.photoUrl || "assets/auth.png";
        const profile = document.createElement("article");
        profile.id = id;
        profile.className = "artist-profile panel";
        profile.innerHTML = `<img class="art" src="${escapeHTML(photo)}" alt="${escapeHTML(artist.displayName)}'s profile"><div><p class="eyebrow">ARTIST PROFILE</p><h2>${escapeHTML(artist.displayName)}</h2><p>${escapeHTML(artist.medium)} · Morgan State University</p><p>${escapeHTML(artist.biography)}</p><p>Selected work: ${works.length ? works.map(item => `<a href="artwork.html?id=${Number(item.id)}">${escapeHTML(item.title)}</a>`).join(" · ") : "No artwork listed yet."}</p><a class="pill solid" href="artists.html">Back to artists</a></div>`;
        document.querySelector(".artists").append(profile);
        setupImageFallbacks(profile);
      });
    } catch (error) { reportBackendIssue(error); }
  }

  async function renderArtworkDetail() {
    const id = new URLSearchParams(location.search).get("id");
    if (!document.querySelector(".page-artwork") || !id || !/^\d+$/.test(id)) return;
    try {
      const result = await api(`artworks.php?id=${encodeURIComponent(id)}`, { method: "GET" });
      const item = result.artwork;
      const image = document.querySelector(".detail > .art");
      const copy = document.querySelector(".detail-copy");
      document.querySelector(".page-artwork .intro h1").textContent = item.title;
      document.title = `${item.title} | Campus Artwork Exhibit`;
      image.src = item.imageUrl;
      image.alt = `Artwork: ${item.title}`;
      copy.querySelector(".eyebrow").textContent = item.availability.toUpperCase();
      copy.querySelector("h2").textContent = `By ${item.artistName}`;
      copy.querySelector("h2 + p").textContent = `${item.medium} · ${item.year}`;
      copy.querySelector("h3 + p").textContent = item.description;
      copy.querySelector(".display").hidden = true;
      copy.querySelector(".asking").textContent = item.availability === "Available" ? `Asking price · ${money(item.price)}` : item.availability;
      copy.querySelector('.actions a[href^="artists.html"]').href = `artists.html#database-artist-${Number(item.artist_id)}`;
      setupImageFallbacks(document.querySelector(".detail"));
    } catch (error) { reportBackendIssue(error); }
  }

  async function renderExhibitions() {
    if (!document.querySelector(".page-exhibition")) return;
    try {
      const result = await api("exhibitions.php", { method: "GET" });
      const container = document.querySelector(".page-exhibition .exhibition > div");
      if (!result.exhibitions.length || !container) return;
      const list = document.createElement("section");
      list.className = "database-exhibitions";
      list.innerHTML = `<h3>More exhibitions</h3>` + result.exhibitions.map(item => `<article class="panel exhibition-card"><p class="eyebrow">${escapeHTML(item.status)} · ${escapeHTML(item.startDate)}–${escapeHTML(item.endDate)}</p><h3>${escapeHTML(item.title)}</h3><p>${escapeHTML(item.description)}</p><p>${escapeHTML(item.location)} · ${escapeHTML(item.building)}, Room ${escapeHTML(item.room)}</p><p>${Number(item.artworkCount)} artworks</p></article>`).join("");
      container.append(list);
    } catch (error) { reportBackendIssue(error); }
  }

  async function renderAdmin() {
    if (!document.querySelector(".page-admin")) return;
    const user = activeUser || await loadProfile();
    if (!user || user.role !== "Administrator") { location.href = "sign-in.html"; return; }
    const fillOptions = (select, items, label) => {
      const initial = select.querySelector("option")?.outerHTML || '<option value="">Choose</option>';
      select.innerHTML = initial + items.map(item => `<option value="${Number(item.id)}">${escapeHTML(label(item))}</option>`).join("");
    };
    const refresh = async () => {
      const data = await api("admin.php", {}, "GET");
      fillOptions(document.querySelector("#exhibition-location"), data.locations, item => `${item.name} · ${item.building}, ${item.room}`);
      fillOptions(document.querySelector("#sale-artwork"), data.artworks, item => `${item.title} · ${item.artistName} · ${money(item.price)}`);
      fillOptions(document.querySelector("#sale-customer"), data.customers, item => `${item.firstName} ${item.lastName} · ${item.email}`);
      fillOptions(document.querySelector("#placement-exhibition"), data.exhibitions, item => `${item.title} · ${item.status}`);
      fillOptions(document.querySelector("#placement-artwork"), data.displayArtworks, item => `${item.title} · ${item.artistName} · ${item.status}`);
      const list = document.querySelector('[data-admin-list="exhibitions"]');
      list.innerHTML = data.exhibitions.length ? data.exhibitions.map(item => `<article class="admin-list-item"><strong>${escapeHTML(item.title)}</strong><span>${escapeHTML(item.status)}</span></article>`).join("") : "<p>No exhibitions have been created yet.</p>";
    };
    try { await refresh(); }
    catch (error) { reportBackendIssue(error); }
    document.querySelectorAll("[data-admin-form]").forEach(form => form.addEventListener("submit", async event => {
      event.preventDefault();
      const data = new FormData(form);
      let payload;
      const formType = form.dataset.adminForm;
      if (formType === "location") payload = { action: "createLocation", name: data.get("name"), building: data.get("building"), room: data.get("room"), address: data.get("address") };
      if (formType === "exhibition") payload = { action: "createExhibition", locationId: data.get("locationId"), title: data.get("title"), description: data.get("description"), startDate: data.get("startDate"), endDate: data.get("endDate"), status: data.get("status") };
      if (formType === "sale") payload = { action: "recordSale", artworkId: data.get("artworkId"), customerId: data.get("customerId") };
      if (formType === "placement") payload = { action: "assignArtwork", exhibitionId: data.get("exhibitionId"), artworkId: data.get("artworkId"), label: data.get("label"), position: data.get("position") };
      try {
        await request("admin.php", payload);
        setMessage(form, formType === "sale" ? "Sale recorded. The artwork is now marked sold." : formType === "placement" ? "Artwork placement saved." : "Saved to the database.");
        if (formType === "location" || formType === "sale" || formType === "placement") form.reset();
        await refresh();
      } catch (error) { setMessage(form, error.message, true); }
    }));
  }

  async function initialize() {
    try {
      const result = await api("auth.php", { method: "GET" });
      activeUser = result.user;
    } catch (error) { reportBackendIssue(error); }
    updateNavigation();
    setupImageFallbacks();
    authForms();
    await Promise.all([profileForm(), artworkForm(), renderCollection(), renderStudio(), renderAccount(), renderArtists(), renderArtworkDetail(), renderExhibitions(), renderAdmin()]);
  }

  initialize();
})();
