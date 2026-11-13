# Campus Artwork Exhibit

A static recreation of the Figma desktop prototype. Open `index.html` in a browser, or serve this folder with `python3 -m http.server 8000` and visit `http://localhost:8000`. There is no build step.

- The gallery, exhibition, artist directory, and demo account and studio pages are plain HTML.
- Update sample titles, artists, prices, and statuses in the relevant HTML pages. Collection cards in `collection.html` use medium and availability classes for the CSS filters. If the sample catalog changes, update the associated filter counts in `styles.css`.
- Replace the sample artwork in `assets/` or point each image tag at its replacement. Update the alt text to match. The gallery crops artwork to fit each slot.
- Shared colors, type, spacing, and motion live in `styles.css`. Fonts are bundled with their licenses in `assets/`.
- The account and studio forms demonstrate navigation only. Field values are neither transmitted nor saved. There is no authentication, upload, payment, or backend.
