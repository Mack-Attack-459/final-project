# Campus Artwork Exhibit

**COSC 459 Final Project**

**Team:** Okikioluwa Popoola and Jesse Obasi

Campus Artwork Exhibit is a Morgan State University gallery concept where visitors can discover student artwork, artists, and exhibitions. This repository contains the multi-page website prototype and the team's submitted MySQL schema and query script.

## Run the PHP and MySQL app

1. Start MySQL in MAMP (or another local MySQL server). The default configuration expects MySQL at `127.0.0.1:8889` with the local MAMP `root` account. Override it with the environment variables listed below if your setup differs.
2. Import `database.sql` once into MySQL. For MAMP, open phpMyAdmin or run:

   ```sh
   mysql -h 127.0.0.1 -P 8889 -u root -p < database.sql
   ```

   The schema script creates the database and includes sample records.
3. Confirm PHP has the `mysqli` extension, then start the built-in PHP server from this folder:

   ```sh
   php -S 127.0.0.1:8000
   ```

4. Open <http://127.0.0.1:8000>.

Database settings can be overridden with `CAE_DB_HOST`, `CAE_DB_PORT`, `CAE_DB_USER`, `CAE_DB_PASS`, and `CAE_DB_NAME`. Defaults are `127.0.0.1`, `8889`, `root`, `root`, and `campus_artwork_exhibit`.

## Connected features

- Visitors can create accounts and sign in. PHP sessions keep the signed-in account, and PHP `password_hash`/`password_verify` handle new account passwords.
- Artists can edit their artist profile and register artwork. Artwork is saved to MySQL and appears in the public collection and the artist studio.
- Visitors can browse and filter artwork, open artwork details, browse artist profiles, and see exhibitions from MySQL.
- Gallery administrators can add locations and exhibitions, place artwork in exhibitions, and record a completed sale. The sale uses the listed price; the database trigger changes the artwork status to Sold. Customer accounts can view recorded purchases.
- The seeded SQL accounts use `SHA2` hashes to match the class SQL script. On a successful first sign-in, the PHP endpoint upgrades that account's hash to PHP's password hash.

Sample accounts use the password `demo-password-01!`:

- Artist: `amina.cole@example.edu`
- Customer: `olivia.king@example.edu`
- Administrator: `morgan.james@example.edu`

## Database

`database.sql` contains the MySQL schema, constraints, triggers, sample records, and queries submitted for Milestone 2. It creates the `campus_artwork_exhibit` database and begins with `DROP DATABASE IF EXISTS`; importing it again will erase and rebuild that database. Import it only into a fresh database or after backing up any data you need.

## Prototype scope

This is a local academic project, not a production deployment. Keep database credentials local and use a dedicated database account outside MAMP. Artwork images are entered as URLs; the application does not upload image files or process payments. PHP role checks and database constraints protect the local demo flows.

## Suggested video walkthrough

The exact video prompt is in Canvas, which currently requires signing in. For a project demo, a clear walkthrough would show one user journey end to end: sign in as an artist, update the profile, register artwork, find it in the public collection, then sign in as an administrator to create an exhibition and record a sale; finish by showing the artwork's Sold status and the customer's purchase history. Explain which database tables each step uses. Check the Canvas prompt for its required length, format, and submission details before recording.

## Project files

- `index.html`, `discover.html`, `collection.html`, `exhibition.html`, `artists.html`: public gallery and discovery pages.
- `sign-in.html`, `create-account.html`, `account.html`: visitor account flows.
- `studio.html`, `edit-profile.html`, `register-artwork.html`: artist workspace and artwork entry.
- `app.js`: browser-side interactions that call the PHP API.
- `api/`: PHP endpoints for account sessions, profiles, artwork, artists, exhibitions, gallery administration, and customer purchase history.
- `styles.css`: responsive layout, type, colors, focus states, and interaction styling.
- `assets/`: artwork imagery and licensed font files.
- `database.sql`: submitted MySQL implementation and query script.
