# Budget App

An open source, self-hosted budgeting application built from scratch. Supports shared budgets between multiple users, custom categories, and income tracking.

## Status

Early development. Currently building out the core backend API.

## Tech Stack

- **Backend:** Java 21, Spring Boot 3
- **Database:** PostgreSQL
- **Migrations:** Flyway
- **Build tool:** Maven
- **Containerization:** Docker / Docker Compose

## Features

The Flutter client lets a household:

- Create an account on the device
- Create a budget and add other people to it, with a role of owner, editor, or viewer
- Add custom categories, either a recurring spending limit or a savings goal
- Log expenses or contributions that count toward that category
- Add income that repeats automatically, or manual income such as a side hustle that you log by hand

The client stores that ledger on the device for now. The Spring Boot API and Postgres database are the home-lab backend; connecting the client to those endpoints is the next step, so every device shares one database.

## Run the Flutter app

```bash
cd src/frontend_app
flutter pub get
flutter run
```

## Home lab

Copy the env file, then start Postgres and the API:

```bash
cp .env.example .env
docker compose up --build
```

The API listens on port 8080. Postgres keeps its data in the `db_data` volume. Change `DB_USER` and `DB_PASSWORD` in `.env` before you expose this beyond your own network. Authentication on the API is still open while the client is being connected.


## Known issues and gaps

### Backend

- **No authentication or authorization.** All endpoints are open; login returns the user but no token. Roles are stored but never checked. Anyone can add anyone as `OWNER`, and anyone can delete any budget, category, transaction, member, or income record by ID. Plan: JWT (library already in the pom) plus role checks in the services.
- **`GET /api/users/by-email` leaks user details** to anyone. Remove or restrict once auth exists.
- **Duplicate member returns 500** (UNIQUE constraint). Should check `findByBudgetIdAndUserId` first and return 409.
- **Duplicate signup email returns 500.** Should return 409.
- **No global error handler** (`@ControllerAdvice`), so failures that are not explicit `ResponseStatusException`s surface as a generic 500.
- **`GET /api/categories/{id}/remaining` returns 500 for a missing category** (plain `RuntimeException`). Should be a 404 `ResponseStatusException`, matching `deleteCategory`.
- **No length validation** on names and titles, so a value over 100 characters fails at the database with 500.
- **No update (`PUT`/`PATCH`) endpoints at all.** Deletes now exist for everything except users.
- **Frequency does not affect calculations**; limits never reset.
- **Budget total and remaining mix goals with limits.**
- **Category frequency rules not enforced** (goals can have one, recurring can be missing one).
- **No membership checks** when logging or deleting transactions or income.
- **Auto generated income is not implemented**: `autoGenerate` and `nextPayDate` are stored, nothing runs on a schedule.
- **No automated tests.** JUnit and Testcontainers are ready in the pom.
- **Style cleanup:** Streams in `IncomeSourceController` and `IncomeEntryController`; `BudgetMemberView` should become its own response DTO; `IncomeSourceController` and `BudgetController` use wildcard `org.springframework.web.bind.annotation.*` imports while the others list imports one by one.

### Frontend

- **Editing a paycheck does not reach the server** (`updatePaycheck` is local only) and is reverted on the next refresh. Needs a backend update endpoint first.
- **API errors are invisible outside the account screen.** `ledger.error` is only displayed on `AccountScreen`, so a failed add or delete on any other screen (for example a 409 from trying to remove the owner) fails silently.
- **No way to sign in to an existing server account on a new device.** `AccountScreen` only offers Sign in when an account is already saved on the device. On a fresh browser it only shows Create account, and creating with an existing email fails on the server.
- **The password is stored in plain text on the device**, and signing out does not remove it.
- **No re-authentication on launch**: if `signedIn` was saved as true, the app loads that user's data from the API using the cached ID.
- **Create budget dialog's extra members are dropped in remote mode**; only the title is sent.
- **Goals are sent with a frequency**; the client only knows weekly, biweekly, and monthly; `nextPayDate` is always today.
- **Many sequential requests** on every load and after every change (one per budget, category, and income source).
- **After a database wipe**, clear the browser's site data or the app keeps a stale account.
- **Web branding is half done**: the favicon and PWA icons are the Spencer+ logo, but the tab title, manifest name, description, and theme color are still Flutter template values (see 10.2).
- **Glass card styling is partial**: budgets, categories, and people use `GlassCard`; the Income tab, the budget detail's income rows, and the Overview are still flat rows with hairlines. Converting `income_screen.dart` was the next planned step.
- **Android:** package ID is still `com.example.frontend_app`; no `INTERNET` permission in the main manifest; cleartext HTTP blocked on release builds; default launcher icon.
- **No remote mode tests.**

### Deployment

- **`API_BASE` is baked in as `http://localhost:8080`** in the Docker web build. A visitor opening `budget.spencerplus.com` would have their browser call `localhost:8080` on their own machine. Since the web app and API are served from the same origin, the web build should use a relative base (the page's own origin) instead. An empty value cannot be used for this because empty means local only mode, so this needs a small change in `api.dart`.
- **Port 5432 is published** to the host. Remove for production.
- **No published image or release compose file yet.**
- **`target/` and Flutter's generated `ephemeral/` files** are build output and should be gitignored if they are committed.

---

## Roadmap

**Done**

- Full data model and migrations V1 to V8
- Create and list endpoints for every entity
- **Delete endpoints for every entity except users**, with 404 for missing rows and 409 for removing a budget's owner
- Budget delete with cascade (backend), now also category → transactions and income source → entries through the same V8 cascades
- **Client deletes wired to the API** (budgets, categories, expenses, members, income sources, payments)
- **Detail screens no longer close themselves** after a remote refresh (lookups by ID)
- Category remaining, budget total, budget remaining
- Docker Compose with a single container for web and API
- Flutter client merged (PR #1), plus the review fixes: cascade migration, transactional budget creation, shared budget listing, removal of auto-created "changeme" accounts
- **Glass card UI** (`GlassCard`, status tinted) on the budgets list, categories, and people
- **Spencer+ favicon and web icons**

**Next**

1. Finish the glass card pass on the Income tab (and decide on the Overview).
2. Update endpoints for budgets, categories, transactions, members, income sources, and income entries; then wire `updatePaycheck` through the client.
3. Error handling: `@ControllerAdvice`, 404 and 409 instead of 500; show `ledger.error` on every screen, not only sign in.
4. Real authentication with JWT, and role checks (owner manages members and deletes the budget, editor adds, changes, and deletes items, viewer reads only). Then remove or lock down `by-email`.
5. Sign in to an existing server account from a fresh device.
6. Period aware calculations using category frequency.
7. Auto generated income scheduler.
8. Tests: JUnit with Testcontainers for services and controllers (including deletes and cascades); Flutter tests for remote mode.
9. Release: fix `API_BASE`, GitHub Actions image publishing, release compose file, remove port 5432, deploy behind Nginx Proxy Manager and Cloudflare.
10. Android build (package ID, permissions, HTTPS, launcher icon). iOS needs a Mac.
11. Choose the final app name, then update the web title, manifest, and Android label to match.


**Stretch Goals**

1. Adding some charts and analytics to the main page or maybe a separate tab.
2. Include a way to upload files (receipts and documents). 
3. a separate investment or retirement account table with a stored balance.


## License

AGPL-3.0