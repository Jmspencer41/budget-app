# Project Context

This document explains how the whole project works: what each piece does, how the pieces talk to each other, how data moves from a button tap in the app to a row in Postgres, and what is still missing or broken. It is written so a new contributor (or an AI assistant) can read it once and understand the codebase without opening every file.

Last reviewed against the code: November 5, 2026. See [section 17](#17-change-log) for what changed since the November 4 review.

---

## Table of contents

1. [What this project is](#1-what-this-project-is)
2. [Repository layout](#2-repository-layout)
3. [How the pieces fit together](#3-how-the-pieces-fit-together)
4. [Running the project](#4-running-the-project)
5. [Backend (Spring Boot)](#5-backend-spring-boot)
6. [Database (Postgres and Flyway)](#6-database-postgres-and-flyway)
7. [Backend features, one by one](#7-backend-features-one-by-one)
8. [API reference](#8-api-reference)
9. [Derived values, category periods, and income](#9-derived-values-category-periods-and-income)
10. [Frontend (Flutter)](#10-frontend-flutter)
11. [How the frontend maps to the backend](#11-how-the-frontend-maps-to-the-backend)
12. [Docker build and deployment](#12-docker-build-and-deployment)
13. [Project conventions and rules](#13-project-conventions-and-rules)
14. [Known issues and gaps](#14-known-issues-and-gaps)
15. [Roadmap](#15-roadmap)
16. [Handy commands](#16-handy-commands)
17. [Change log](#17-change-log)

---

## 1. What this project is

An open source, self hosted budgeting app. The main idea is **shared budgets**: a household can keep one budget that several people work on, each with a role (`OWNER`, `EDITOR`, or `VIEWER`), while each person still logs their own spending and income under it.

Inside a budget:

- **Categories** are either a **recurring spending limit** (for example, $400 a month for groceries) or a **savings goal** (for example, $2,000 for a vacation). Recurring categories reset on their own schedule (daily through yearly), and every past period can be looked back at.
- **Transactions** are purchases logged against a category by a specific user. They count against a limit or toward a goal.
- **Income sources** are things like a paycheck or a side job. Each one belongs to one user and sends money to one budget. A scheduled paycheck has a frequency and an **anchor date** (one real payday), and every payday is calculated from it, so the app can show how much has actually come in this month so far, not a monthly average.
- **Income entries** are individual payments logged by hand for irregular income (a side hustle).

It is **API first**. The backend is a Spring Boot REST API that returns JSON. The client is a Flutter app that can build for web, Android, iOS, Linux, macOS, and Windows from one codebase. No client ever talks to the database directly.

It ships as **Docker Compose**: one container for the app (the API plus the compiled Flutter web app) and one container for Postgres. The target is a working release by the end of the semester, published on GitHub and a container registry (GHCR or Docker Hub). The initial build will run at `budget.spencerplus.com` behind Nginx Proxy Manager and Cloudflare.

The final app name is undecided. The docs say "Budget+", the Flutter client says "Budget Buddy", and the web tab title still says `frontend_app`.

License: **AGPL-3.0**.

---

## 2. Repository layout

```
budget-app/
├── pom.xml                      Maven build for the backend (like package.json for Java)
├── Dockerfile                   3-stage build: Flutter web → Maven jar → JRE runtime
├── docker-compose.yml           Runs Postgres (budget-db) and the app (budget-api)
├── .env.example                 Template for DB_USER, DB_PASSWORD, and TZ (copy to .env)
├── .env                         Real values. Gitignored. Never commit.
├── start-server.sh              Linux helper: pulls main, builds, starts, waits for the API
├── start.ps1                    Windows helper: same idea, then launches Flutter
├── linuxInstructions.md         Step by step home lab setup on Linux
├── windowsInstructions.md       Step by step setup on Windows with Docker Desktop
├── CONTEXT.md                   This file
├── scripts/
│   └── seed_test_data.sql       Test data for manual testing (section 16)
├── README.md
├── LICENSE                      AGPL-3.0
├── docs/
│   ├── overview.md              Original design overview
│   └── sql_table_diagram.drawio Database diagram (open with draw.io)
├── target/                      Maven build output. Generated. Do not edit.
└── src/
    ├── test/java/com/spencerplus/budget/
    │   ├── budgetmembers/BudgetMemberServiceTest.java   JUnit + Mockito tests for adding members (no database)
    │   └── incomesource/IncomeSourcePayDatesTest.java   JUnit tests for the pay date math (no database)
    ├── main/
    │   ├── java/com/spencerplus/budget/
    │   │   ├── BudgetApplication.java     Spring Boot entry point (main method)
    │   │   ├── config/                    SecurityConfig (password hashing, CORS, open endpoints)
    │   │   ├── user/                      Accounts, signup, login
    │   │   ├── budget/                    Budgets, totals
    │   │   ├── budgetmembers/             Who is on which budget, with what role
    │   │   ├── category/                  Spending limits, savings goals, periods and history
    │   │   ├── transaction/               Purchases logged against categories
    │   │   ├── incomesource/              Paychecks and side jobs
    │   │   └── incomeentry/               Individual payments received
    │   └── resources/
    │       ├── application.yml            Port, database connection, JPA and Flyway settings
    │       ├── db/migration/V1..V8        Flyway SQL files that build the schema
    │       └── static/                    (Only exists during the Docker build) the Flutter web app
    └── frontend_app/                      The Flutter client (see section 10)
        ├── pubspec.yaml                   Flutter dependencies (like pom.xml)
        ├── lib/                           ALL the app's Dart code lives here
        │   └── screens/                   One file per screen group (account, overview, budgets, category history, income)
        ├── test/                          Flutter widget tests and pay_dates_test.dart
        ├── web/                           Web shell: index.html, manifest, favicon, icons, logo source images
        ├── android/ ios/ linux/ macos/ windows/   Native shells per platform (mostly generated)
        └── analysis_options.yaml          Lint rules
```

---

## 3. How the pieces fit together

```
┌────────────────────────────────────────────────────────────────┐
│ Flutter app (web, Android, desktop)                            │
│                                                                │
│   screens/*.dart  ──calls──►  Ledger (ledger.dart)             │
│                               │  holds all app state            │
│                               │  saves a copy to the device     │
│                               ▼                                 │
│                          BudgetApi (api.dart)                   │
│                               │  only when API_BASE is set      │
└───────────────────────────────┼────────────────────────────────┘
                                │ HTTP + JSON
                                ▼
┌────────────────────────────────────────────────────────────────┐
│ budget-api container (Spring Boot, port 8080)                  │
│                                                                │
│   Security filter (CORS, everything currently permitted)       │
│        ▼                                                       │
│   Controller   receives the request, validates the body         │
│        ▼                                                       │
│   Service      business logic (create, delete, calculate, list) │
│        ▼                                                       │
│   Repository   Spring Data JPA, generates SQL                    │
│        ▼                                                       │
│   Entity       Java object that maps to one table row           │
└───────────────────────────────┼────────────────────────────────┘
                                │ JDBC
                                ▼
┌────────────────────────────────────────────────────────────────┐
│ budget-db container (Postgres 16, port 5432)                   │
│   data lives in the db_data Docker volume                       │
│   schema created by Flyway migrations on API startup            │
└────────────────────────────────────────────────────────────────┘
```

In the Docker build, the compiled Flutter web app is copied into the jar's `static/` folder, so **one container serves both the web UI and the API** at `http://localhost:8080`. Spring Boot automatically serves anything in `static/` at the root path.

### A request, start to finish

Here is what happens when a user adds a $42.50 grocery expense in the app with the API enabled:

1. The user fills in the expense dialog (`dialogs.dart`) and taps **Add**. The dialog returns an `Expense` object.
2. `CategoryScreen` calls `ledger.addExpense(budgetId, categoryId, expense)`.
3. `Ledger` sees that `API_BASE` is set, so it calls `_api.addExpense(...)` inside `_remoteAction`.
4. `BudgetApi` converts dollars to cents (`42.50` → `4250`), formats the date as `YYYY-MM-DD`, and sends `POST /api/transactions` with a JSON body.
5. Spring Security lets it through (everything is `permitAll()` for now). CORS headers are added.
6. `TransactionController.createTransaction` receives the body as a `CreateTransactionRequest` record. `@Valid` checks it (`categoryId` and `userId` not null, `amountCents` positive, `transactionDate` not null). A failure here returns **400**.
7. The controller calls `TransactionService.createTransaction(...)`, which builds a `Transaction` entity and calls `transactionRepository.save(...)`.
8. Hibernate generates a UUID, runs an `INSERT INTO transactions ...`, and returns the saved entity.
9. The controller converts the entity to a `TransactionResponse` record and Spring turns it into JSON.
10. Back in the app, `_remoteAction` calls `_refreshFromApi()`, which reloads **every** budget, member, category (with its current period), transaction, income source, and income entry from the API, replaces the in-memory lists, saves a copy to the device, and tells the UI to redraw.
11. The category card and category page recompute "spent this period" from the reloaded transactions, and the category page reloads its Past periods section.

Deletes follow the same path: the **×** or trash icon calls a `Ledger` remove method, which sends `DELETE /api/<entity>/{id}` through `_remoteAction`, then reloads everything.

---

## 4. Running the project

### With Docker (the normal way)

```bash
cp .env.example .env        # then edit DB_USER, DB_PASSWORD, and TZ
docker compose up -d --build
```

- `http://localhost:8080` serves the web app and the API.
- Postgres listens on `localhost:5432`, database `budgetapp`.
- `TZ` in `.env` sets the API container's time zone (for example `America/New_York`). It decides what "today" is, which decides which period is current. See section 12.2.
- `start-server.sh` (Linux) and `start.ps1` (Windows) wrap this: they pull `main`, create `.env` if missing, build, start, wait until port 8080 answers, and print the applied migrations.

After a rebuild, browsers cache the old favicon and Flutter's service worker caches assets. If the UI or tab icon looks stale, open DevTools → Application → Clear site data, then hard refresh (Ctrl+Shift+R). This also clears a stale cached account after a database wipe.

### Backend on the host (for debugging in Eclipse)

```bash
docker compose up -d db                  # only the database
export DB_USER=... DB_PASSWORD=...       # must match .env; Maven does not read .env
mvn spring-boot:run                      # or run BudgetApplication from Eclipse
```

`application.yml` points at `jdbc:postgresql://localhost:5432/budgetapp` and falls back to `budgetapp` / `localdev` if the env vars are missing. In Docker, `SPRING_DATASOURCE_URL` overrides the host to `db` (the Postgres container's name on the Compose network). Run on the host, the API uses the host machine's time zone.

### Flutter client on its own

The Flutter SDK is needed for this. It is not installed on Josh's machine; the Docker build compiles the web app.

```bash
cd src/frontend_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080   # web
flutter run -d linux  --dart-define=API_BASE=http://localhost:8080   # Linux desktop
flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8080  # Android emulator
```

- On the Android emulator, `localhost` means the emulator itself. `10.0.2.2` is the emulator's alias for the host machine.
- Leaving out `--dart-define=API_BASE=...` runs the app in **local only mode** (see section 10.3).
- In the `flutter run` terminal: `r` hot reload, `R` hot restart, `q` quit.
- iOS and macOS builds need a Mac with Xcode.

Since Flutter is not installed locally, Dart compile errors show up in the `flutter build web` step of `docker compose up -d --build`.

### Running the tests

- **Java (JUnit):** in Eclipse, right click a test class (under `src/test/java`) → **Run As → JUnit Test**. With Maven installed, `mvn test` runs them all, or `mvn test -Dtest=BudgetMemberServiceTest` runs one class. These tests need no database. The Docker build skips tests (`-DskipTests`).
- Mockito prints "A Java agent has been loaded dynamically" and a class data sharing warning on Java 21. Both are harmless. To hide them under Maven, add a `maven-surefire-plugin` with `<argLine>-XX:+EnableDynamicAgentLoading -Xshare:off</argLine>`; in Eclipse, add the same flags as VM arguments in the run configuration.
- **Dart:** Flutter is not installed locally, so the tests run inside the Flutter image the Docker build already uses. The project folder is mounted read only and copied inside the container, so nothing is written back:

```bash
docker run --rm -v "$PWD/src/frontend_app":/src:ro,z ghcr.io/cirruslabs/flutter:stable \
  sh -c "cp -r /src /app && cd /app && flutter pub get && flutter test test/pay_dates_test.dart"
```

The `z` on the volume is for SELinux on Fedora, which otherwise blocks the container from reading the files.

---

## 5. Backend (Spring Boot)

### 5.1 Stack

| Piece | Version / detail |
| --- | --- |
| Java | 21 |
| Spring Boot | 3.3.4 (`spring-boot-starter-parent`) |
| Build tool | Maven |
| Web | `spring-boot-starter-web` (embedded Tomcat, Jackson for JSON) |
| Database access | `spring-boot-starter-data-jpa` (Hibernate) |
| Database driver | `org.postgresql:postgresql` |
| Migrations | `flyway-core` + `flyway-database-postgresql` |
| Security | `spring-boot-starter-security` (BCrypt hashing, CORS) |
| Validation | `spring-boot-starter-validation` (`@NotNull`, `@NotBlank`, `@Positive`, `@Min`) |
| JWT | `jjwt-api`, `jjwt-impl`, `jjwt-jackson` 0.12.6. **In the pom but not used yet.** |
| Testing | `spring-boot-starter-test`, `spring-security-test`, Testcontainers 1.20.1 (`junit-jupiter`, `postgresql`). Two test classes so far: `IncomeSourcePayDatesTest` (plain JUnit) and `BudgetMemberServiceTest` (JUnit with Mockito mocks, which come with `spring-boot-starter-test`). Neither starts Spring or needs a database. |
| Packaging | `spring-boot-maven-plugin` builds one runnable "fat jar": `budget-app-0.0.1-SNAPSHOT.jar` |

No Lombok. Getters and setters are written by hand.

### 5.2 Configuration (`application.yml`)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/budgetapp
    username: ${DB_USER:budgetapp}      # env var, with a default after the colon
    password: ${DB_PASSWORD:localdev}
  jpa:
    hibernate:
      ddl-auto: validate                # Hibernate never changes the schema, it only checks it
  flyway:
    enabled: true                       # run migrations on startup
server:
  port: 8080
  error:
    include-message: always           # put ResponseStatusException messages in error bodies
```

`ddl-auto: validate` matters: on startup Hibernate compares every `@Entity` against the real tables. If a column is missing or the wrong type, **the app refuses to start**. All schema changes must go through Flyway.

### 5.3 Startup sequence

1. `BudgetApplication.main` calls `SpringApplication.run`.
2. Spring connects to Postgres.
3. **Flyway** checks the `flyway_schema_history` table and runs any migration files that have not run yet, in version order. It also checks that the files that already ran have not been edited (checksum). An edited migration stops startup with a checksum error.
4. **Hibernate** validates the entities against the schema.
5. Spring creates every `@Service`, `@RestController`, and repository and wires them together through their constructors.
6. Tomcat starts listening on port 8080.

### 5.4 Package layout and the five-part pattern

Package root: `com.spencerplus.budget`. Every feature lives in its own subpackage and follows the same pattern:

| File | Job |
| --- | --- |
| `V#__create_x_table.sql` | Flyway migration that creates the table |
| `X.java` | `@Entity`. One object = one row. Private fields, hand-written getters and setters. |
| `XRepository.java` | Interface extending `JpaRepository<X, UUID>`. Spring generates the SQL from method names like `findByBudgetId`. |
| `XService.java` | `@Service`. Business logic. The only layer that touches repositories. |
| `XController.java` | `@RestController`. Maps URLs to service calls. Never touches a repository. |
| `CreateXRequest.java` | Java `record` for the incoming JSON body, with validation annotations. |
| `XResponse.java` | Java `record` for the outgoing JSON, with a static `fromEntity(...)` method. |

**Entities are never returned directly.** This keeps internal fields (most importantly `User.passwordHash`) out of API responses and lets the database shape change without changing the JSON.

**Layering rule:** Controller → Service → Repository. A Service may use another feature's repository or service (for example `BudgetService` uses `CategoryRepository`, `CategoryService`, `BudgetMemberRepository`, and `IncomeSourceService`; `CategoryService` uses `TransactionRepository`). The income code goes through services only: `BudgetService` → `IncomeSourceService` → `IncomeEntryService` → `IncomeEntryRepository`.

**Delete pattern** (used by every feature): the controller has `@DeleteMapping("/{id}")` returning `void` (empty 200). The service checks `existsById` (or `findById`) first and throws `ResponseStatusException(HttpStatus.NOT_FOUND, "... not found")` if the row is missing, then calls `deleteById`. Child rows are removed by the database cascade (V8), not by Java.

**Computed values in responses:** when a response needs something that is calculated (like a category's current period), the **service** computes it and the controller passes it into `fromEntity`. The response record stays a plain mapper with no logic of its own. Income sources go one step further: `IncomeSourceService.toResponse(source, asOf)` calculates the three month values and calls `IncomeSourceResponse.fromEntity` itself, so the controller just calls `toResponse`.

### 5.5 How entities relate in Java

Entities store foreign keys as **plain `UUID` fields** (`budgetId`, `userId`, `categoryId`), not as JPA relationships (`@ManyToOne`, `@OneToMany`). This keeps the entities simple and avoids lazy loading problems. The trade off is that a service has to look up related rows itself (for example `BudgetMemberService.listForBudget` looks up each member's `User` to get their name), and cascading deletes are handled **in the database** (V8), not by Hibernate.

IDs: each entity uses `@Id @GeneratedValue private UUID id;`. Hibernate generates the UUID in Java before the insert. The `DEFAULT gen_random_uuid()` in the SQL is a fallback that only applies to rows inserted by hand in `psql`.

Timestamps: each entity sets `createdAt = LocalDateTime.now()` in Java when the object is created. The SQL `DEFAULT now()` likewise only applies to manual inserts. Inside the container this uses the time zone from `TZ` (see 12.2).

Enums are stored as strings using `@Enumerated(EnumType.STRING)`, so the database holds `'MONTHLY'`, not `2`. Adding or reordering enum values never corrupts existing rows.

Dates that matter for budgeting (`transaction_date`, `anchor_date`, `received_date`) are `LocalDate`, with no time or time zone attached.

### 5.6 Security (`config/SecurityConfig.java`)

- `PasswordEncoder` bean: `BCryptPasswordEncoder`. Passwords are hashed on signup and checked with `matches` on login.
- `SecurityFilterChain`: CSRF disabled, CORS enabled, and **`anyRequest().permitAll()`**. There is a `TODO` noting this is open for development.
- `CorsConfigurationSource`: allows **any origin** (`setAllowedOriginPatterns("*")`), methods `GET, POST, PUT, PATCH, DELETE, OPTIONS`, any header.

What this means today: **there is no authentication.** Login only checks the password and returns the user. It does not issue a token, and no endpoint requires one. Anyone who can reach port 8080 can read, change, or **delete** anything, including adding themselves to any budget as an `EDITOR`.

### 5.7 Validation and errors

- Request records use Jakarta validation annotations. The controller parameter has `@Valid`, so a bad body returns **400 Bad Request** before the service runs.
- An enum value that does not exist (for example `"role": "ADMIN"`) or a badly formatted UUID or date fails JSON parsing and also returns **400**.
- Services throw `ResponseStatusException` for expected problems:
  - **400**: a recurring category without a `frequency` and `anchorDate`, or a goal with either one; a history request with `periods` outside 1 to 60; a history request for a goal; a transaction filter where `from` is after `to`; an income source that breaks the schedule rules (section 7.6), on create or update; a frequency that does not exist (for example `DAILY` for income).
  - **401**: wrong password on login.
  - **404**: a user, budget, category, transaction, member, income source, or income entry that does not exist (every delete, `GET /api/categories/{id}/remaining`, and `/history`).
  - **400** also: adding a budget member with role `OWNER`.
  - **404** also: adding a member to a budget or user that does not exist.
  - **409**: deleting the `OWNER` membership; adding a user who is already a member of the budget.
- Everything else that goes wrong becomes **500**. There is no `@ControllerAdvice` global error handler yet. Examples: a duplicate email on signup, a foreign key that points at nothing (for example a category for a budget ID that does not exist).
- The `categories` and `income_sources` tables also have **CHECK constraints** for their anchor rules (section 6.2). The service validation catches bad input first, so the constraints are a safety net; if one ever fires, it surfaces as a 500.
- Error bodies look like `{"timestamp": "...", "status": 409, "error": "Conflict", "message": "User is already a member of this budget", "path": "/api/..."}`. The `message` field comes from `server.error.include-message: always` in `application.yml` (Spring Boot leaves it out by default). Every current message is safe to show; login's is deliberately vague ("Invalid email or password").

### 5.8 JSON format

- Field names are the Java record component names in camelCase (`amountCents`, `budgetId`, `transactionDate`, `anchorDate`, `periodStart`).
- `UUID` → string: `"3f2c...-..."`
- `LocalDate` → `"2026-10-27"`
- `LocalDateTime` → `"2026-10-27T23:24:29.508124"` (no time zone)
- Enums → their name as a string: `"MONTHLY"`
- Money → whole number of cents: `4250` means $42.50
- Missing optional values → `null` (for example a goal's `frequency`, `anchorDate`, `periodStart`, `periodEnd`, or irregular income's `anchorDate` and `nextPayDate`)
- Endpoints that return a single `long` (totals, remaining) return a bare number, not an object.
- Delete endpoints return an empty body with status 200.
- Query parameter dates (`from`, `to`, `asOf`) use the same `yyyy-MM-dd` format.

---

## 6. Database (Postgres and Flyway)

### 6.1 Migrations

Located in `src/main/resources/db/migration/`. **Never edit a migration that has already run.** Add a new file instead. **The next one is `V9__...sql`.** The file name format is `V<number>__<description>.sql` (two underscores).

| File | What it does |
| --- | --- |
| `V1__create_users_table.sql` | `users` |
| `V2__create_budget_table.sql` | `budgets` (owner is a user) |
| `V3__create_budget_members_table.sql` | `budget_members` (join table, unique per budget and user) |
| `V4__create_income_sources_table.sql` | `income_sources`, including `anchor_date`, `second_pay_day`, and three CHECK constraints |
| `V5__create_income_entries_table.sql` | `income_entries` |
| `V6__create_categories_table.sql` | `categories`, including `anchor_date` and its CHECK constraint |
| `V7__create_transactions_table.sql` | `transactions` |
| `V8__cascade_deletes.sql` | Replaces five foreign keys with `ON DELETE CASCADE` versions |

Note that income tables (V4, V5) were created before categories (V6) because of the Budget and Category redesign partway through the project.

**One exception to the rule, made on purpose:** on November 3, 2026, `anchor_date` and its CHECK constraint were added by **editing V6** instead of adding V9. This was only acceptable because the app has never been released, so every existing database (Josh's and Philip's) could be wiped with `docker compose down -v`. Any database that ran the old V6 fails on startup with a Flyway checksum error until it is wiped.

**The same exception was used once more** on November 4, 2026: **V4 was edited** to replace `next_pay_date` with `anchor_date`, add `second_pay_day`, and add three CHECK constraints (section 6.2). Every database had to be wiped with `docker compose down -v` again.

**After the first release, this is never acceptable again**; all schema changes go in new migrations.

### 6.2 Tables

All primary keys are `UUID`. All tables have `created_at TIMESTAMP NOT NULL DEFAULT now()`.

**`users`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `first_name` | VARCHAR(100) | NOT NULL |
| `last_name` | VARCHAR(100) | NOT NULL |
| `email` | VARCHAR(255) | NOT NULL, UNIQUE |
| `password_hash` | VARCHAR(255) | NOT NULL, BCrypt hash |
| `birthday` | DATE | optional |

**`budgets`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `title` | VARCHAR(100) | NOT NULL |
| `owner_id` | UUID | NOT NULL, FK → `users.id` (no cascade) |

**`budget_members`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `budget_id` | UUID | NOT NULL, FK → `budgets.id` **ON DELETE CASCADE** |
| `user_id` | UUID | NOT NULL, FK → `users.id` |
| `role` | VARCHAR(20) | `OWNER`, `EDITOR`, `VIEWER` |
| | | `UNIQUE (budget_id, user_id)` |

**`categories`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `budget_id` | UUID | NOT NULL, FK → `budgets.id` **ON DELETE CASCADE** |
| `name` | VARCHAR(100) | NOT NULL |
| `category_type` | VARCHAR(20) | `RECURRING` or `GOAL` |
| `frequency` | VARCHAR(20) | nullable. `DAILY, WEEKLY, BIWEEKLY, MONTHLY, QUARTERLY, SEMIANNUALLY, YEARLY`. Required for recurring, null for goals (enforced by the service). |
| `amount_cents` | BIGINT | NOT NULL. The limit per period (recurring) or the target (goal). |
| `anchor_date` | DATE | nullable. The first day of the category's first period. Every period boundary is computed from it (section 9). Null for goals. |
| | | `CONSTRAINT chk_categories_anchor_date CHECK ((category_type = 'RECURRING' AND anchor_date IS NOT NULL) OR (category_type = 'GOAL' AND anchor_date IS NULL))` |

**`transactions`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `category_id` | UUID | NOT NULL, FK → `categories.id` **ON DELETE CASCADE** |
| `user_id` | UUID | NOT NULL, FK → `users.id` (who logged it) |
| `merchant` | VARCHAR(255) | optional |
| `description` | VARCHAR(255) | optional |
| `amount_cents` | BIGINT | NOT NULL |
| `transaction_date` | DATE | NOT NULL. Decides which period the transaction counts toward. |

**`income_sources`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `user_id` | UUID | NOT NULL, FK → `users.id` (who earns it) |
| `budget_id` | UUID | NOT NULL, FK → `budgets.id` **ON DELETE CASCADE** |
| `name` | VARCHAR(100) | NOT NULL |
| `amount_cents` | BIGINT | NOT NULL. Amount of each paycheck (0 for irregular income). |
| `frequency` | VARCHAR(20) | NOT NULL. `WEEKLY, BIWEEKLY, SEMIMONTHLY, MONTHLY, IRREGULAR` (no `DAILY`) |
| `auto_generate` | BOOLEAN | NOT NULL, default false. The client uses it to mean "scheduled paycheck" (true) or "manual income" (false). No scheduler acts on it. |
| `anchor_date` | DATE | nullable. One real payday. Every payday is calculated from it (section 9.4). Required for every frequency except `IRREGULAR`, which must leave it null. |
| `second_pay_day` | INTEGER | nullable. The second day of the month (1 to 31) for `SEMIMONTHLY`. Null for every other frequency. `INTEGER`, not `SMALLINT`, so Hibernate's `validate` accepts a plain `Integer` field. |
| | | `CONSTRAINT chk_income_sources_frequency CHECK (frequency IN ('WEEKLY', 'BIWEEKLY', 'SEMIMONTHLY', 'MONTHLY', 'IRREGULAR'))` |
| | | `CONSTRAINT chk_income_sources_anchor_date CHECK ((frequency = 'IRREGULAR' AND anchor_date IS NULL) OR (frequency <> 'IRREGULAR' AND anchor_date IS NOT NULL))` |
| | | `CONSTRAINT chk_income_sources_second_pay_day CHECK ((frequency = 'SEMIMONTHLY' AND second_pay_day IS NOT NULL AND second_pay_day BETWEEN 1 AND 31) OR (frequency <> 'SEMIMONTHLY' AND second_pay_day IS NULL))`. The explicit `IS NOT NULL` matters: `NULL BETWEEN 1 AND 31` is NULL, and a CHECK passes on NULL. |

**`income_entries`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `income_source_id` | UUID | NOT NULL, FK → `income_sources.id` **ON DELETE CASCADE** |
| `amount_cents` | BIGINT | NOT NULL |
| `received_date` | DATE | NOT NULL |

Flyway also creates its own `flyway_schema_history` table.

### 6.3 Relationships and cascades

```
users ─┬─< budgets (owner_id)
       ├─< budget_members >─┐
       ├─< transactions     │
       └─< income_sources   │
                            │
budgets ─┬─< budget_members ┘        (CASCADE)
         ├─< categories ─< transactions          (CASCADE, CASCADE)
         └─< income_sources ─< income_entries    (CASCADE, CASCADE)
```

Deleting a budget removes its members, categories, the categories' transactions, its income sources, and those sources' entries, all in one statement thanks to V8. Deleting a category removes its transactions; deleting an income source removes its entries.

Foreign keys pointing at `users` have **no cascade**. There is no endpoint to delete a user yet; when one is added, it will need to decide what happens to budgets that user owns and transactions they logged.

### 6.4 Design decisions

- **Money is stored as `BIGINT` cents**, never floating point, so there are no rounding errors.
- **Derived values are never stored.** A budget's total, a category's remaining balance, and **every period** (start, end, spent) are calculated from the underlying rows every time they are requested, so they can never drift out of sync. There is no scheduled job that "closes" a period.
- **One anchor date per category** defines all of its periods. The client turns user friendly choices ("1st of the month", "weeks start on Friday", "calendar quarters") into that one date, so the backend only has one period rule per frequency.
- **Categories cannot be edited.** Frequency, amount, and anchor are fixed when a category is created. Without editing, history computed from current settings is always accurate. To test different settings, change the row directly in `psql`; history recalculates immediately because nothing is stored.
- **One income source has exactly one destination budget.** A paycheck split between two budgets is modeled as two income sources.
- **Scheduled income is calculated, not logged.** A paycheck stores its amount, frequency, and one anchor payday. "Received this month" is the amount times the number of paydays from the 1st through today; nothing writes an income entry on payday. The trade off is that every paycheck is assumed to be the same amount (see 14.1).
- **Irregular income is logged.** Side hustle money is only counted when someone logs an income entry for it.
- **The anchor is a fixed payday, not a "next" payday.** A stored next payday would go stale after every payday; a fixed anchor never needs updating, the same idea as category periods.
- **Creating a budget also creates the owner's `OWNER` membership row**, in the same database transaction.
- **The owner membership cannot be deleted** on its own (409). It only goes away when the whole budget is deleted.
- **The owner membership can only be created with the budget.** `POST /api/budgetmembers` rejects role `OWNER` with 400.
- **Duplicate members are checked in Java and guaranteed by the database.** The service looks for an existing row first, for a clean 409. If two identical requests race past that check, the `UNIQUE (budget_id, user_id)` constraint stops the second insert, and the service turns that error into the same 409.

---

## 7. Backend features, one by one

### 7.1 `user`

- **Entity** `User`: `id, firstName, lastName, email, passwordHash, birthday, createdAt`.
- **Repository** `UserRepository`: `findByEmail(String) → Optional<User>`.
- **Service** `UserService`:
  - `createUser(firstName, lastName, email, rawPassword, birthday)`: hashes the password with BCrypt and saves. A duplicate email hits the UNIQUE constraint and returns 500.
  - `findByEmail(email)`: throws 404 if missing.
  - `login(email, rawPassword)`: finds the user, then `passwordEncoder.matches`. Wrong password throws 401. **Returns the user; no token is issued.**
- **Controller** `UserController` at `/api/users`:
  - `POST /api/users` with `CreateUserRequest(firstName, lastName, email, password, birthday?)`. All but birthday are `@NotBlank`.
  - `POST /api/users/login` with the nested record `LoginRequest(email, password)`.
  - `GET /api/users/by-email?email=...`. **Public lookup by email. Leaks user details. Should be removed or restricted.** The Flutter client uses it to turn an email into a user ID when adding a member.
- **Response** `UserResponse`: `id, firstName, lastName, email, birthday, createdAt`. No password hash.
- No update or delete endpoint for users.

### 7.2 `budget`

- **Entity** `Budget`: `id, title, ownerId, createdAt`.
- **Repository** `BudgetRepository`: `findByOwnerId(UUID)` (currently unused, since listing goes through memberships).
- **Service** `BudgetService`:
  - `createBudget(title, ownerId)`: `@Transactional`. Saves the budget, then saves a `BudgetMember` with role `OWNER` for the owner. If either insert fails, both roll back.
  - `listForUser(userId)`: finds every `BudgetMember` row for the user, collects the budget IDs, and calls `findAllById`. This returns **budgets the user is a member of**, including ones shared with them, not only ones they own.
  - `deleteBudget(budgetId)`: throws 404 if the budget does not exist, otherwise `deleteById`. The database cascade removes everything under it.
  - `getTotal(budgetId)`: see section 9.
  - `getRemainingBalance(budgetId)`: see section 9.
  - `getIncome(budgetId, asOf)`: 404 if the budget does not exist. Adds up `getReceivedCents` and `getExpectedCents` for every income source on the budget, through `IncomeSourceService` (not the repository). Returns a `BudgetIncomeResponse`.
- **Controller** `BudgetController` at `/api/budgets`:
  - `POST /api/budgets` with `CreateBudgetRequest(title, ownerId)`. `title` is `@NotBlank`. `ownerId` has no `@NotNull`, so a missing owner reaches the database and returns 500.
  - `GET /api/budgets?userId=...`
  - `DELETE /api/budgets/{id}`
  - `GET /api/budgets/{id}/total`
  - `GET /api/budgets/{id}/remaining`
  - `GET /api/budgets/{id}/income?asOf=yyyy-MM-dd` (`asOf` optional, defaults to the server's today)
- **Response** `BudgetResponse`: `id, title, ownerId, createdAt`.
- **Response** `BudgetIncomeResponse`: `budgetId, asOf, receivedThisMonthCents, expectedThisMonthCents`. The client does not call this endpoint; it adds up the per source numbers it already has. It is there for curl testing and future clients.

### 7.3 `budgetmembers`

- **Entity** `BudgetMember`: `id, budgetId, userId, role, createdAt`. The `Role` enum (`OWNER, EDITOR, VIEWER`) is nested inside the entity class, so other code refers to it as `BudgetMember.Role`.
- **Repository** `BudgetMemberRepository`: `findByUserId`, `findByBudgetId`, `findByBudgetIdAndUserId` (used for the duplicate check; also the natural tool for permission checks later).
- **Service** `BudgetMemberService` (depends on `BudgetMemberRepository`, `UserRepository`, and `BudgetRepository`):
  - `createBudgetMember(budgetId, userId, role)`: checks in this order, then saves:
    1. role `OWNER` → **400** (the owner row is only created with the budget)
    2. `budgetRepository.existsById` false → **404** "Budget not found"
    3. `userRepository.existsById` false → **404** "User not found"
    4. `findByBudgetIdAndUserId` present → **409** "User is already a member of this budget"
    5. `saveAndFlush`, so the insert runs right away. A `DataIntegrityViolationException` (two identical requests at once) becomes the same **409**. The same exception would also cover a budget or user deleted in the tiny gap after the checks, which is rare enough to accept.
    The 404s come before the 409 so a bad ID is never reported as a duplicate.
  - `deleteBudgetMember(memberId)`: looks up the membership row (404 if missing). If its role is `OWNER`, throws **409** ("The owner cannot be removed from a budget"). Otherwise deletes it. The ID is the **membership row's ID**, not the user's ID.
  - `listForBudget(budgetId)`: for each membership, looks up the `User` and builds a display name `"First Last"` (or `"Member"` if the user row is missing). Returns `BudgetMemberView` records.
  - `BudgetMemberView(id, budgetId, userId, name, role)` is a record nested inside the service. **Style cleanup planned:** fold it into a proper response DTO in its own file.
- **Controller** `BudgetMemberController` at `/api/budgetmembers`:
  - `POST /api/budgetmembers` with `CreateBudgetMemberRequest(budgetId, userId, role)`, all `@NotNull`.
  - `GET /api/budgetmembers/budget/{budgetId}` returns the views (with `name`).
  - `DELETE /api/budgetmembers/{id}`
- **Response** `BudgetMemberResponse`: `id, budgetId, userId, role` (no name; used for the POST response).

### 7.4 `category`

- **Entity** `Category`: `id, budgetId, name, categoryType, frequency, amountCents, createdAt, anchorDate`. Nested enums `CategoryType { RECURRING, GOAL }` and `Frequency { DAILY, WEEKLY, BIWEEKLY, MONTHLY, QUARTERLY, SEMIANNUALLY, YEARLY }`. `anchorDate` is a `LocalDate` mapped to `anchor_date` and is nullable (goals).
- **Records**:
  - `CreateCategoryRequest(budgetId @NotNull, name @NotBlank, categoryType @NotNull, frequency, amountCents @Positive, anchorDate)`. `frequency` and `anchorDate` have no annotation because goals send null; the service enforces the rule.
  - `CategoryResponse(id, budgetId, name, categoryType, frequency, amountCents, createdAt, anchorDate, periodStart, periodEnd)`. Built with `fromEntity(Category, CategoryPeriod currentPeriod)`; a null period (goals) gives null `periodStart` and `periodEnd`.
  - `CategoryPeriod(start, end)`: an internal date range used inside the backend. Never sent as JSON on its own.
  - `CategoryPeriodResponse(periodStart, periodEnd, limitCents, spentCents, remainingCents)`: one row of history.
- **Repository** `CategoryRepository`: `findByBudgetId`.
- **Service** `CategoryService`:
  - `createCategory(budgetId, name, type, frequency, amountCents, anchorDate)`: validates first. RECURRING needs both `frequency` and `anchorDate`; GOAL must have neither. A violation throws **400**. Then saves.
  - `deleteCategory(categoryId)`: 404 if missing, otherwise deletes. Its transactions cascade.
  - `getCategory(categoryId)`: shared lookup, 404 if missing. Used by `getRemainingAmount` and `getHistory`.
  - `getRemainingAmount(categoryId)`: goals subtract every transaction ever; recurring categories subtract only the **current period's** transactions. See section 9.
  - `getCurrentPeriod(category)`: the period containing today, or null for goals. The controller calls it to fill `periodStart` and `periodEnd`.
  - `getHistory(categoryId, periods)`: newest period first, starting with the current one and walking back until it has `periods` rows or reaches the anchor. One `findByCategoryIdAndTransactionDateBetween` query per period. 400 for goals or a `periods` value outside 1 to `MAX_HISTORY_PERIODS` (60).
  - `getPeriodContaining(frequency, anchorDate, date)`: public pure date math, so it can be unit tested without a database. See section 9.
  - Private helpers: `getPeriodIndex`, `getPeriodStart`, `sumAmounts` (plain for loop).
  - `getCategoriesForBudget(budgetId)`.
- **Controller** `CategoryController` at `/api/categories`:
  - `POST /api/categories`
  - `GET /api/categories/budget/{budgetId}`: each response includes the current period.
  - `GET /api/categories/{id}/remaining`
  - `GET /api/categories/{id}/history?periods=N` (`periods` defaults to 6)
  - `DELETE /api/categories/{id}`

### 7.5 `transaction`

- **Entity** `Transaction`: `id, categoryId, userId, merchant, description, amountCents, transactionDate, createdAt`.
- **Repository** `TransactionRepository`: `findByCategoryId`, `findByUserId` (unused so far), and three date filters built from method names: `findByCategoryIdAndTransactionDateBetween` (both ends inclusive), `findByCategoryIdAndTransactionDateGreaterThanEqual`, `findByCategoryIdAndTransactionDateLessThanEqual`.
- **Service** `TransactionService`:
  - `createTransaction(...)`
  - `deleteTransaction(transactionId)`: 404 if missing.
  - `getTransactionForCategory(categoryId, from, to)`: `from` and `to` are optional. Both → `Between`; only `from` → on or after; only `to` → on or before; neither → every transaction. `from` after `to` → **400**. It branches instead of filling a missing bound with `LocalDate.MIN`/`MAX`, because those are outside the date range Postgres supports.
- **Controller** `TransactionController` at `/api/transactions`:
  - `POST /api/transactions` with `CreateTransactionRequest(categoryId @NotNull, userId @NotNull, merchant, description, amountCents @Positive, transactionDate @NotNull)`.
  - `GET /api/transactions/category/{categoryId}?from=&to=`. Both query params are optional `@RequestParam(required = false)` with `@DateTimeFormat(iso = DateTimeFormat.ISO.DATE)`.
  - `DELETE /api/transactions/{id}`
- **Response** `TransactionResponse`: all entity fields.

Nothing checks that the user logging (or deleting) the transaction is a member of the category's budget. Nothing checks that `transactionDate` is not in the future.

### 7.6 `incomesource`

- **Entity** `IncomeSource`: `id, userId, budgetId, name, amountCents, frequency, autoGenerate, anchorDate, secondPayDay, createdAt`. Nested enum `Frequency { WEEKLY, BIWEEKLY, SEMIMONTHLY, MONTHLY, IRREGULAR }` (different from the category enum: it has `SEMIMONTHLY` and `IRREGULAR`, and no daily, quarterly, or yearly). `anchorDate` is a nullable `LocalDate`; `secondPayDay` is a nullable `Integer`.
- **Records**:
  - `CreateIncomeSourceRequest(userId @NotNull, budgetId @NotNull, name @NotBlank, amountCents @Min(0), frequency @NotNull, autoGenerate, anchorDate, secondPayDay)`. `anchorDate` and `secondPayDay` have no annotation because whether they are required depends on the frequency; the service checks.
  - `UpdateIncomeSourceRequest(name @NotBlank, amountCents @Min(0), frequency @NotNull, anchorDate, secondPayDay)`. No `userId` or `budgetId`: an edit cannot move income to another person or budget. `autoGenerate` is not editable either.
  - `IncomeSourceResponse(id, userId, budgetId, name, amountCents, frequency, autoGenerate, anchorDate, secondPayDay, receivedThisMonthCents, expectedThisMonthCents, nextPayDate, createdAt)`. The last three before `createdAt` are calculated. `fromEntity(source, receivedThisMonthCents, expectedThisMonthCents, nextPayDate)`.
- **Repository** `IncomeSourceRepository`: `findByUserId` (unused), `findByBudgetId`.
- **Service** `IncomeSourceService` (depends on `IncomeSourceRepository` and `IncomeEntryService`):
  - `createIncomeSource(userId, budgetId, name, amountCents, frequency, autoGenerate, anchorDate, secondPayDay)`: validates the schedule, then saves.
  - `updateIncomeSource(id, name, amountCents, frequency, anchorDate, secondPayDay)`: 404 if missing, same validation, then saves.
  - `deleteIncomeSource(id)`: 404 if missing; its entries cascade.
  - `listForBudget(budgetId)`.
  - `toResponse(source, asOf)`: calls the three month methods and builds the response.
  - `validateSchedule` (private), the same rules as the CHECK constraints, as clean **400**s:
    - `IRREGULAR` must have no `anchorDate` and no `secondPayDay`.
    - Every other frequency needs an `anchorDate`.
    - `SEMIMONTHLY` needs a `secondPayDay` from 1 to 31 that is **different from the anchor's day** (the same day twice would count every paycheck double). The database does not check this last rule.
    - No other frequency may have a `secondPayDay`.
  - `getPayDates(source, from, to)`: every payday in the range, both ends included, oldest first. Section 9.4.
  - `getReceivedCents(source, asOf)`, `getExpectedCents(source, asOf)`, `getNextPayDate(source, asOf)`: section 9.4.
  - Private helpers: `addEveryNDays`, `addMonthly`, `addSemimonthly`.
- **Controller** `IncomeSourceController` at `/api/incomesources`:
  - `POST /api/incomesources`. The response uses the server's today.
  - `GET /api/incomesources/budget/{budgetId}?asOf=yyyy-MM-dd`. `asOf` is optional (`@RequestParam(required = false)` with `@DateTimeFormat(iso = DateTimeFormat.ISO.DATE)`) and defaults to `LocalDate.now()`. The client always sends the device's own date, so "today" follows the user's time zone, not the server's. Uses a plain for loop (the old Stream is gone).
  - `PUT /api/incomesources/{id}` with `UpdateIncomeSourceRequest`. The response uses the server's today.
  - `DELETE /api/incomesources/{id}`

### 7.7 `incomeentry`

- **Entity** `IncomeEntry`: `id, incomeSourceId, amountCents, receivedDate, createdAt`.
- **Repository** `IncomeEntryRepository`: `findByIncomeSourceId`, `findByIncomeSourceIdAndReceivedDateBetween` (both ends inclusive).
- **Service** `IncomeEntryService`: `createIncomeEntry(...)`, `deleteIncomeEntry(incomeEntryId)` (404 if missing), `listForSource(incomeSourceId)`, and `getTotalCentsBetween(incomeSourceId, start, end)` (plain for loop), which `IncomeSourceService` uses for irregular income.
- **Controller** `IncomeEntryController` at `/api/incomeentries`:
  - `POST /api/incomeentries` with `CreateIncomeEntryRequest(incomeSourceId @NotNull, amountCents @Positive, receivedDate @NotNull)`.
  - `GET /api/incomeentries/source/{incomeSourceId}`. **Also uses a Stream.**
  - `DELETE /api/incomeentries/{id}`
- **Response** `IncomeEntryResponse`: all entity fields.

---

## 8. API reference

Base URL: `http://localhost:8080` (or wherever the container runs). All bodies are JSON with `Content-Type: application/json`.

| Method | Path | Body / params | Returns | Confirmed working |
| --- | --- | --- | --- | --- |
| POST | `/api/users` | `firstName, lastName, email, password, birthday?` | `UserResponse` | yes |
| POST | `/api/users/login` | `email, password` | `UserResponse` or 401/404 | yes |
| GET | `/api/users/by-email?email=` | query param | `UserResponse` or 404 | |
| POST | `/api/budgets` | `title, ownerId` | `BudgetResponse` | yes |
| GET | `/api/budgets?userId=` | query param | `BudgetResponse[]` | yes |
| DELETE | `/api/budgets/{id}` | | empty 200, or 404 | |
| GET | `/api/budgets/{id}/total` | | number (cents) | |
| GET | `/api/budgets/{id}/remaining` | | number (cents) | |
| GET | `/api/budgets/{id}/income?asOf=` | `asOf` optional, `yyyy-MM-dd` | `BudgetIncomeResponse`, or 404 | yes |
| POST | `/api/budgetmembers` | `budgetId, userId, role` (`EDITOR` or `VIEWER`) | `BudgetMemberResponse`, 400 (`OWNER`), 404 (budget or user), or 409 (already a member) | yes |
| GET | `/api/budgetmembers/budget/{budgetId}` | | `[{id, budgetId, userId, name, role}]` | yes |
| DELETE | `/api/budgetmembers/{id}` | membership ID | empty 200, 404, or 409 (owner) | |
| POST | `/api/categories` | `budgetId, name, categoryType, frequency?, amountCents, anchorDate?` | `CategoryResponse`, or 400 if the anchor rule is broken | yes |
| GET | `/api/categories/budget/{budgetId}` | | `CategoryResponse[]` (with `periodStart`, `periodEnd`) | yes |
| GET | `/api/categories/{id}/remaining` | | number (cents), or 404 | yes |
| GET | `/api/categories/{id}/history?periods=` | `periods` 1 to 60, default 6 | `CategoryPeriodResponse[]` newest first, or 400/404 | yes |
| DELETE | `/api/categories/{id}` | | empty 200, or 404 | |
| POST | `/api/transactions` | `categoryId, userId, merchant?, description?, amountCents, transactionDate` | `TransactionResponse` | yes |
| GET | `/api/transactions/category/{categoryId}?from=&to=` | both optional, `yyyy-MM-dd` | `TransactionResponse[]`, or 400 if `from` > `to` | yes |
| DELETE | `/api/transactions/{id}` | | empty 200, or 404 | |
| POST | `/api/incomesources` | `userId, budgetId, name, amountCents, frequency, autoGenerate, anchorDate?, secondPayDay?` | `IncomeSourceResponse`, or 400 if the schedule rules are broken | yes |
| GET | `/api/incomesources/budget/{budgetId}?asOf=` | `asOf` optional, `yyyy-MM-dd` | `IncomeSourceResponse[]` with the month values for `asOf` | yes |
| PUT | `/api/incomesources/{id}` | `name, amountCents, frequency, anchorDate?, secondPayDay?` | `IncomeSourceResponse`, or 400/404 | yes |
| DELETE | `/api/incomesources/{id}` | | empty 200, or 404 | |
| POST | `/api/incomeentries` | `incomeSourceId, amountCents, receivedDate` | `IncomeEntryResponse` | |
| GET | `/api/incomeentries/source/{incomeSourceId}` | | `IncomeEntryResponse[]` | |
| DELETE | `/api/incomeentries/{id}` | | empty 200, or 404 | |

**Not implemented yet:** update endpoints for everything except income sources (`PUT /api/incomesources/{id}` is the only one), and any delete for users.

### Category JSON examples

A recurring category in `GET /api/categories/budget/{budgetId}`:

```json
{
  "id": "4915fdae-...",
  "budgetId": "4532940b-...",
  "name": "Dining Out",
  "categoryType": "RECURRING",
  "frequency": "WEEKLY",
  "amountCents": 7500,
  "createdAt": "2026-11-03T22:20:11.120391",
  "anchorDate": "2026-09-04",
  "periodStart": "2026-10-30",
  "periodEnd": "2026-11-05"
}
```

A goal has `"frequency": null, "anchorDate": null, "periodStart": null, "periodEnd": null`.

One row from `GET /api/categories/{id}/history`:

```json
{ "periodStart": "2026-08-01", "periodEnd": "2026-08-31", "limitCents": 100000, "spentCents": 117120, "remainingCents": -17120 }
```

### Income JSON examples

A biweekly paycheck in `GET /api/incomesources/budget/{budgetId}?asOf=2026-11-04`:

```json
{
  "id": "138c5d4c-...",
  "userId": "e74bf673-...",
  "budgetId": "fd7b50c8-...",
  "name": "Paycheck",
  "amountCents": 200000,
  "frequency": "BIWEEKLY",
  "autoGenerate": true,
  "anchorDate": "2026-10-24",
  "secondPayDay": null,
  "receivedThisMonthCents": 0,
  "expectedThisMonthCents": 400000,
  "nextPayDate": "2026-11-07",
  "createdAt": "2026-11-04T20:43:22.581626"
}
```

A twice a month paycheck has `"frequency": "SEMIMONTHLY"` and a `secondPayDay` (for example `15` with an anchor on the 1st). Irregular income has `"frequency": "IRREGULAR"`, `"amountCents": 0`, and `null` for `anchorDate`, `secondPayDay`, and `nextPayDate`; its received and expected values come from logged income entries.

`GET /api/budgets/{id}/income?asOf=2026-11-21`:

```json
{ "budgetId": "fd7b50c8-...", "asOf": "2026-11-21", "receivedThisMonthCents": 1100000, "expectedThisMonthCents": 1100000 }
```

### Example walkthrough with curl

Replace every `REAL_..._ID` with an actual UUID copied from the previous response. Pasting the placeholder text literally is a common slip. Storing IDs in shell variables avoids it (see section 16).

```bash
# 1. Create a user, copy the "id" from the response
curl -s -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Ada","lastName":"Lovelace","email":"ada@example.com","password":"secret"}'

# 2. Create a budget owned by that user (also creates the OWNER membership)
curl -s -X POST http://localhost:8080/api/budgets \
  -H "Content-Type: application/json" \
  -d '{"title":"Household","ownerId":"REAL_USER_ID"}'

# 3. Add a $400/month grocery limit that resets on the 1st
curl -s -X POST http://localhost:8080/api/categories \
  -H "Content-Type: application/json" \
  -d '{"budgetId":"REAL_BUDGET_ID","name":"Groceries","categoryType":"RECURRING","frequency":"MONTHLY","amountCents":40000,"anchorDate":"2026-11-01"}'

# 3b. Add a $2,000 savings goal (no frequency, no anchor)
curl -s -X POST http://localhost:8080/api/categories \
  -H "Content-Type: application/json" \
  -d '{"budgetId":"REAL_BUDGET_ID","name":"Vacation","categoryType":"GOAL","amountCents":200000}'

# 4. Log a $42.50 purchase
curl -s -X POST http://localhost:8080/api/transactions \
  -H "Content-Type: application/json" \
  -d '{"categoryId":"REAL_CATEGORY_ID","userId":"REAL_USER_ID","merchant":"Kroger","amountCents":4250,"transactionDate":"2026-11-03"}'

# 5. What is left in the current period (should print 35750)
curl -s http://localhost:8080/api/categories/REAL_CATEGORY_ID/remaining

# 6. The last 6 periods, newest first
curl -s "http://localhost:8080/api/categories/REAL_CATEGORY_ID/history?periods=6"

# 7. Only November's transactions (quotes stop the shell from treating & as "run in background")
curl -s "http://localhost:8080/api/transactions/category/REAL_CATEGORY_ID?from=2026-11-01&to=2026-11-30"

# 8. Delete just that transaction (prints 200; a second run prints 404)
curl -i -X DELETE http://localhost:8080/api/transactions/REAL_TRANSACTION_ID

# 9. Add a $2,000 paycheck every 2 weeks, with Oct 24 as a real payday
curl -s -X POST http://localhost:8080/api/incomesources \
  -H "Content-Type: application/json" \
  -d '{"userId":"REAL_USER_ID","budgetId":"REAL_BUDGET_ID","name":"Paycheck","amountCents":200000,"frequency":"BIWEEKLY","autoGenerate":true,"anchorDate":"2026-10-24"}'

# 10. Income as of a given day (try the day before and the day of a payday)
curl -s "http://localhost:8080/api/incomesources/budget/REAL_BUDGET_ID?asOf=2026-11-07"
curl -s "http://localhost:8080/api/budgets/REAL_BUDGET_ID/income?asOf=2026-11-07"; echo

# 11. Change the paycheck (PUT sends the whole schedule, not just the changed field)
curl -s -X PUT http://localhost:8080/api/incomesources/REAL_INCOME_SOURCE_ID \
  -H "Content-Type: application/json" \
  -d '{"name":"Paycheck","amountCents":250000,"frequency":"BIWEEKLY","anchorDate":"2026-10-31"}'

# 12. Delete the budget (cascades to everything under it)
curl -i -X DELETE http://localhost:8080/api/budgets/REAL_BUDGET_ID
```

Responses that return one object end without a newline, so the next prompt can run into the output. Adding `; echo` after the curl command prints a newline.

---

## 9. Derived values, category periods, and income

Everything here is calculated on request in the service layer, using plain for loops. Nothing is stored.

### 9.1 How periods work

A recurring category has a `frequency` and an `anchorDate`. Period number `0` starts on the anchor. Period `n` starts at `anchor + n × (one frequency step)`, and ends the day before period `n + 1` starts. Both ends are inclusive.

| Frequency | Start of period `n` |
| --- | --- |
| DAILY | `anchor.plusDays(n)` |
| WEEKLY | `anchor.plusWeeks(n)` |
| BIWEEKLY | `anchor.plusWeeks(2n)` |
| MONTHLY | `anchor.plusMonths(n)` |
| QUARTERLY | `anchor.plusMonths(3n)` |
| SEMIANNUALLY | `anchor.plusMonths(6n)` |
| YEARLY | `anchor.plusYears(n)` |

To find the period that contains a date, `getPeriodIndex` first estimates `n` with `ChronoUnit` (days, weeks, months, or years between the anchor and the date, divided by the step), then corrects it with two small loops: step back while period `n` starts after the date, step forward while period `n + 1` starts on or before the date.

Details worth knowing:

- **Periods are always measured from the anchor, never chained** from the previous period. An anchor on January 31 gives Feb 28 (or 29), Mar 31, Apr 30, and so on. It never drifts down to the 28th.
- **A date before the anchor** (an anchor in the future) is treated as period 0. The client's date pickers only allow today or earlier, so this only happens with hand edited data.
- **"Today" is `LocalDate.now()`** in the API container, which uses the `TZ` environment variable. Without `TZ`, the container runs in UTC and flips to the next day at 7 PM Eastern, so periods can change early on the last evening of a period.

Examples with the seed data: a weekly category anchored Friday Sep 4, 2026 has periods Friday to Thursday, so on Nov 3 the current period is Oct 30 to Nov 5. A biweekly category anchored Aug 14 is in Oct 23 to Nov 5. A semiannual category anchored Jan 1 is in Jul 1 to Dec 31.

### 9.2 The calculations

**Category remaining** (`CategoryService.getRemainingAmount`):

```
recurring: remaining = amountCents − sum(transactions dated in the current period)
goal:      remaining = amountCents − sum(all transactions ever)
```

For a recurring limit, a positive number is money left this period and a negative number means over the limit. For a goal, it is how much is still needed.

**Category history** (`CategoryService.getHistory`): for each period from the current one backward, `spentCents` is the sum of that period's transactions, `limitCents` is the category's `amountCents`, and `remainingCents` is the difference.

**Budget total** (`BudgetService.getTotal`):

```
total = sum(amountCents of every category in the budget)
```

**Budget remaining** (`BudgetService.getRemainingBalance`):

```
remaining = sum(getRemainingAmount of every category in the budget)
```

Because it calls `getRemainingAmount`, this now uses each recurring category's current period automatically.

### 9.3 Limitations

- **Budget level totals do not mean much yet.** `getTotal` adds weekly, monthly, yearly, and goal amounts together. `getRemainingBalance` adds current period remainders of different lengths plus goal remainders. Neither is used by the client, and neither should be built into UI until a budget level number is designed (for example a "monthly equivalent" or a budget level date view).
- **History runs one query per period** (up to 60). Fine at household scale.
- **History uses the category's current `amountCents` for every past period.** That is only correct because categories cannot be edited. If editing is ever added, amount changes will need an effective dated table so old periods keep their old limit.
- `getRemainingBalance` runs one transaction query per category (fine at this size).

### 9.4 Income paydays and month totals

All in `IncomeSourceService`, using plain for loops. Nothing is stored; every number is calculated for the `asOf` date on request.

**Paydays** (`getPayDates(source, from, to)`): every payday from `from` to `to`, both ends included, oldest first. Nothing is ever paid before the anchor, so `from` is moved up to the anchor when it is earlier.

| Frequency | Paydays |
| --- | --- |
| WEEKLY | `anchor.plusDays(7n)` |
| BIWEEKLY | `anchor.plusDays(14n)` |
| MONTHLY | `anchor.plusMonths(n)`. An anchor on the 31st gives Feb 28 (or 29), then Mar 31 again. |
| SEMIMONTHLY | The anchor's day and `secondPayDay` in every month, earlier day first. A day past the end of a short month uses the last day (the 31st becomes the 30th, 29th, or 28th). If both days land on the same date (the 30th and 31st in February), it counts once. |
| IRREGULAR | none |

Like category periods, paydays are **always measured from the anchor, never chained** from the previous payday, so month end dates never drift. Weekly and biweekly find the first index with rounded up division (`(days + step - 1) / step`) instead of looping from the anchor.

**Month totals:**

```
received this month  = amountCents × (paydays from the 1st of asOf's month through asOf)
expected this month  = amountCents × (paydays in all of asOf's month)
next pay date        = first payday after asOf (null for irregular)

irregular income:
received this month  = sum of income entries from the 1st through asOf
expected this month  = sum of income entries in the whole month (including ones dated later this month)
```

- **The payday itself counts** as received. On Nov 7 a Nov 7 paycheck is already in "received".
- **Next pay date is the first payday after today**, because today's payday is already counted. If the anchor is in the future, it is the anchor.
- **Expected uses the real number of paydays**, so a biweekly $2,000 paycheck expects $4,000 in most months and $6,000 in the two or three months a year that have three paydays. The old client showed a flat average ($4,333.33).

Examples with a $2,000 biweekly paycheck anchored Oct 24, 2026 (paydays Nov 7, Nov 21, ...):

| asOf | Received | Expected | Next |
| --- | --- | --- | --- |
| Nov 6 | 0 | 400000 | Nov 7 |
| Nov 7 | 200000 | 400000 | Nov 21 |
| Nov 21 | 400000 | 400000 | Dec 5 |
| Jan 31, 2027 | 600000 | 600000 (Jan 2, 16, 30) | Feb 13 |

**Why `asOf`:** "today" decides what counts as received. The server's today follows the container's `TZ`, but the user may be somewhere else, so the client sends its own date with `?asOf=`. When `asOf` is left off, the server uses its own today.

**The same math exists in Dart** (`payDatesBetween` in `models.dart`, section 10.4) for local only mode and for when the server cannot be reached. The Java and Dart versions are tested against the same cases (`IncomeSourcePayDatesTest` and `test/pay_dates_test.dart`).

The Flutter client does not call `/total`, `/remaining` (budget), or `/remaining` (category). It computes period spending itself from the transactions and period dates it already loaded (see 10.4), and calls `/history` for past periods.

---

## 10. Frontend (Flutter)

### 10.1 What Flutter is, briefly

Flutter is Google's UI toolkit. You write the app once in **Dart**, and Flutter compiles it for each platform. Everything on screen is a **widget** (a class that describes part of the UI). A `StatelessWidget` just draws from its inputs. A `StatefulWidget` has a `State` object that can change and call `setState` to redraw. A `FutureBuilder` is a widget that shows one thing while a network request is loading and another once the result arrives.

Dart notes for Java developers: a leading underscore (`_name`) makes something **private to its file**, not just its class. `is!` means "is not an instance of". `...[a, b]` spreads a list into another list, and `if (x) widget` inside a list adds the widget only when `x` is true.

### 10.2 Folder roles

- **`lib/`**: all of the app's real code. This is the only place you normally edit.
- **`pubspec.yaml`**: package name (`frontend_app`), version `1.0.0+1`, Dart SDK `^3.11.5`, and dependencies: `http` (network calls), `shared_preferences` (small key value storage on the device), `cupertino_icons`. Dev dependencies: `flutter_test`, `flutter_lints`.
- **`pubspec.lock`**: generated exact versions. Do not edit.
- **`test/widget_test.dart`**: two widget tests (see 10.9).
- **`web/`**: what the Docker image serves.
  - `index.html` links `favicon.png` as the tab icon and `manifest.json` for install/home screen info.
  - `favicon.png` (32×32) and `icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png` were regenerated from the **Spencer+ logo** with ImageMagick. Maskable icons are shrunk to about 80% and padded so a circle or squircle crop does not cut them off.
  - `Spencer_Plus_Logo_Cross.png` (original) and `logo_clean.png` (white background made transparent) are the source images. They sit in `web/`, so they are bundled into the build too. Harmless, but they can be moved out of `web/` if the build should stay lean.
  - Still template values: `<title>frontend_app</title>`, `apple-mobile-web-app-title` `frontend_app`, the `description` meta tag ("A new Flutter project."), and in `manifest.json` `name`/`short_name` `frontend_app`, `description`, and the blue `#0175C2` `background_color`/`theme_color`. These should change once the app name is decided.
- **`android/`, `ios/`, `linux/`, `macos/`, `windows/`**: native shells generated by Flutter. Each is a small native app that starts the Flutter engine, which then runs the `lib/` code. You only touch these for platform settings: app name, icon, package ID, permissions. Files named `GeneratedPluginRegistrant`, anything under `ephemeral/`, and `flutter_export_environment.sh` are build output and should never be edited (and ideally should be in `.gitignore`).

### 10.3 Two modes: local only and remote

The app is controlled by one compile time setting in `api.dart`:

```dart
const apiBaseUrl = String.fromEnvironment('API_BASE', defaultValue: '');
```

- **Local only mode** (`API_BASE` empty, the default): no network calls at all. Everything lives in memory and is saved to the device with `shared_preferences`. This is how the widget tests run. **There are no category periods in this mode**: the server computes them, so categories show all time totals, the Past periods section is hidden, and the history screen shows a message instead. **Income does work in this mode**: the client calculates paydays itself with `payDatesBetween` (the same rules as the server), so "so far" and "this month" are correct. Local only mode is planned to stay for a future simple, single user mobile app with no sharing.
- **Remote mode** (`--dart-define=API_BASE=http://...`): adds and deletes go to the API, and the app reloads its data from the API after each one. A copy of the last loaded data is still cached on the device. The server's income numbers (`receivedThisMonth`, `expectedThisMonth`, `nextPayDate`) are **not** saved in that copy, because they would be stale the next day. If the server cannot be reached on launch, the cached income falls back to the client's own payday math, so the numbers stay correct.

`Ledger` checks this with `bool get _remote => apiBaseUrl.isNotEmpty;`. Because it is a compile time constant, the mode is baked into each build; the Docker web build uses `http://localhost:8080`.

### 10.4 `lib/` file by file

**`main.dart`**: entry point.

- `main()` runs `BudgetApp`.
- `BudgetApp` creates **one `Ledger`** for the whole app and calls `ledger.load()` once. It sets the `MaterialApp` title "Budget Buddy" and the theme. (The browser tab text comes from `web/index.html`, which still says `frontend_app`.)
- `HomeShell` listens to the ledger and decides what to show:
  - not loaded yet → spinner
  - not signed in → `AccountScreen`
  - signed in → three tabs with a bottom `NavigationBar`: **Overview**, **Budgets**, **Income**. An `IndexedStack` keeps all three alive and shows one.

**`ledger.dart`**: the app's state and the brain of the client. `Ledger extends ChangeNotifier`, which means screens can `addListener` to it and redraw when it calls `notifyListeners()`.

State it holds:

- `List<Budget> budgets`, `List<IncomeSource> incomes`
- `Account? account`, `bool signedIn`, `bool loaded`, `String? error`
- `BudgetApi _api`

Key methods:

| Method | Local only mode | Remote mode |
| --- | --- | --- |
| `load()` | Reads the saved JSON from `shared_preferences` (key `budget_buddy_ledger_v2`, falls back to `_v1`) | Same, then if signed in with an account ID, calls `_refreshFromApi()` |
| `createAccount` | Saves the account locally | `POST /api/users` |
| `signIn` | Compares email and password to the account saved on the device | `POST /api/users/login`. Always returns `true` immediately; failures show up in `error` |
| `signOut` | Sets `signedIn = false` (account stays saved) | Same |
| `addBudget` | Inserts locally | `POST /api/budgets` (title and owner only) |
| `deleteBudget` | Removes the budget and its income locally | `DELETE /api/budgets/{id}` |
| `addMember` | Adds locally (name must be unique) | Looks up the user by email, then `POST /api/budgetmembers`. Email is required. |
| `removeMember` | Removes locally (never the owner) | `DELETE /api/budgetmembers/{member.id}`. Skips the owner and any member without an ID. |
| `addCategory` | Inserts locally | `POST /api/categories`, including `anchorDate` |
| `removeCategory` | Removes locally | `DELETE /api/categories/{id}` |
| `addExpense` | Inserts locally | `POST /api/transactions` |
| `removeExpense` | Removes locally | `DELETE /api/transactions/{id}` |
| `addIncome` | Inserts locally | `POST /api/incomesources` |
| `updatePaycheck(source, name, amount, frequency, anchorDate?, secondPayDay?)` | Edits locally | `PUT /api/incomesources/{id}`. Clears `secondPayDay` unless the frequency is semimonthly. |
| `logSideHustle` | Adds a payment locally | `POST /api/incomeentries` |
| `removePayment` | Removes locally | `DELETE /api/incomeentries/{id}` |
| `removeIncome` | Removes locally | `DELETE /api/incomesources/{id}` |
| `loadHistory(categoryId, periods)` | Returns an empty list | `GET /api/categories/{id}/history`. Returns a `Future`; not stored in the ledger. |
| `loadExpenses(categoryId, from, to)` | Returns an empty list | `GET /api/transactions/category/{id}?from=&to=`. Returns a `Future`; not stored in the ledger. |
| `expectedIncomeDuring(month)` | Sum of every source's `expectedDuring(month)` | same |
| `receivedIncomeDuring(month)` | Sum of every source's `receivedDuring(month)` | same |
| `receivedIncomeFor(budgetId, month)`, `expectedIncomeFor(budgetId, month)` | The same two sums for one budget | same |
| `spentDuring(month)` | Sum of recurring category spending in that **calendar** month | same |

`loadHistory` and `loadExpenses` are read only lookups that screens call directly and show with a `FutureBuilder`. They exist on `Ledger` only because `_api` is private; they do not change ledger state or call `notifyListeners`.

Private helpers:

- `_remoteAction(action)`: runs `action` (an API call) in the background without waiting. On success it calls `_refreshFromApi()` and `_touch()`. On failure it stores the message in `error` and notifies listeners. The UI does not wait for it.
- `_refreshFromApi()`: calls `_api.loadBudgets(account.id)` and `_api.loadIncome(budgets)` and **replaces** the `budgets` and `incomes` lists with brand new objects.
- `_touch()`: notifies listeners, then saves a JSON snapshot (account, signedIn, budgets, incomes) to `shared_preferences`. Saves are chained on `_tail` so they happen in order.
- `newId()`: makes a local ID from the current time plus random noise. Used for objects created on the device; the server replaces these with real UUIDs after a refresh.

**`api.dart`**: the HTTP client. `BudgetApi` wraps every backend call.

- Create methods: `createUser`, `login`, `createBudget`, `addMember`, `addCategory`, `addExpense`, `addIncome`, `logPayment`.
- Update method: `updateIncome(source)` → `PUT /api/incomesources/{id}`.
- `addIncome` and `updateIncome` share `_incomeSchedule(source)`, which builds `name`, `amountCents`, `frequency`, `anchorDate`, and `secondPayDay` (POST adds `userId`, `budgetId`, and `autoGenerate` with a `...` spread). A paycheck sends its frequency and anchor (`anchorDate ?? today` as a fallback; the dialog always sets it), and `secondPayDay` only for semimonthly. Manual income sends `IRREGULAR`, `0`, and nulls.
- `addCategory` sends `frequency` as `frequency.name.toUpperCase()` (the Dart enum names match the server's) and `anchorDate` as `yyyy-MM-dd`. **For goals it sends `null` for both.**
- Delete methods: `deleteBudget`, `deleteCategory`, `deleteExpense` (transaction), `deleteMember` (membership ID), `deleteIncome` (income source), `deletePayment` (income entry).
- Load methods:
  - `loadBudgets(userId)` builds the full tree: `GET /api/budgets?userId=`, then for each budget `GET /api/budgetmembers/budget/{id}` and `GET /api/categories/budget/{id}`, then for each category `loadExpenses(id)` (every transaction, unfiltered). Each category gets its `anchorDate`, `periodStart`, and `periodEnd` from the response.
  - `loadIncome(budgets)`: for each budget `GET /api/incomesources/budget/{id}?asOf=<device's date>`, then for each source `GET /api/incomeentries/source/{id}`. Reads `anchorDate`, `secondPayDay`, `receivedThisMonthCents`, `expectedThisMonthCents`, and `nextPayDate` into the model.
  - `loadHistory(categoryId, periods)` → `List<PeriodSummary>`.
  - `loadExpenses(categoryId, from?, to?)` → `List<Expense>`. Adds `from` and/or `to` to the query string only when given.
- That is **one request per budget, category, and income source**, run one after another. Fine for a household, slow at scale.
- `_userIdFor(name, email)` uses the public `by-email` endpoint. A 404 becomes "No account found for X. They need to sign up first."
- `addMember` catches a 409 from `POST /api/budgetmembers` and rethrows it as "That person is already on this budget." Other errors pass through unchanged. The message only reaches the user once `ledger.error` is shown outside the account screen (see 14.2).
- `_expense(row)` turns one transaction JSON row into an `Expense` (label from `merchant`, falling back to `description`). Used by `loadExpenses`.
- `_object(method, path, body)` handles single object requests. It supports **`GET`, `POST`, `PUT`, and `DELETE`**. Anything else throws `Unsupported $method`. An empty response body (like a delete's) returns an empty map.
- `_list(path)` handles list responses.
- `_check` turns any status 400 or higher into `ApiException('API $method $path failed ($status)')`.
- Conversion helpers: `_cents(dollars)` rounds `dollars * 100`; `_dollars(cents)` divides by 100; `_date(DateTime)` → `YYYY-MM-DD`; `_apiFrequency` and `_payFrequency` map **income** frequencies (`WEEKLY`, `BIWEEKLY`, `SEMIMONTHLY`, `MONTHLY`; an unknown value falls back to monthly); `_categoryFrequency` maps a server category frequency string to `CategoryFrequency` (unknown or null falls back to monthly); `_role` maps role strings (unknown falls back to viewer).
- `_account(body, password)` builds an `Account` from the server response **and attaches the password the user typed**, which then gets saved on the device.

**`models.dart`**: plain Dart data classes, each (except `PeriodSummary`) with `toJson()` and `fromJson()` for device storage.

| Class | Fields | Computed |
| --- | --- | --- |
| `Account` | `id?, firstName, lastName, email, password` | `displayName` |
| `Budget` | `id, name, members, categories` | `totalLimit` and `totalSpent` (recurring categories only; `totalSpent` sums each category's **current period**), `spentDuring(month)` (calendar month) |
| `Member` | `name, role, id?, userId?, email?` | `id` is the membership row ID used for delete |
| `BudgetCategory` | `id, name, kind, frequency, anchorDate?, periodStart?, periodEnd?, target, expenses` | see below |
| `Expense` | `id, label, amount, date` | |
| `PeriodSummary` | `start, end, limit, spent` | `remaining`, `isOver`, `fraction`. One row from `/history`. Not stored on the device. |
| `IncomeSource` | `id, budgetId, name, kind, frequency?, paycheckAmount, anchorDate?, secondPayDay?, payments`, plus read only server values `receivedThisMonth?, expectedThisMonth?, nextPayDate?` | `totalLogged`, `receivedDuring(month)`, `expectedDuring(month)`, `upcomingPayDate` |
| `IncomePayment` | `id, amount, date` | |

`BudgetCategory` computed values:

- `hasPeriod`: true for a recurring category that came from the server with `periodStart` and `periodEnd`. False for goals and in local only mode.
- `periodExpenses`: the expenses dated inside the current period (both ends inclusive, compared by date only with `_dateOnly`), or **all** expenses when `hasPeriod` is false.
- `current`: sum of `periodExpenses`. This one getter is what makes the whole UI period aware: `remaining`, `isOver`, `fraction`, the card colors, `Budget.totalSpent`, and the Overview's "Over the limit" list are all built on it.
- `remaining`, `isOver` (recurring only), `fraction` (for the progress bar, capped at 1.4).
- `periodLabel`: "Nov 1 to Nov 30", a single date for daily categories, years added when the period crosses a year; null without a period.

Enums: `BudgetRole { owner, editor, viewer }`, `CategoryKind { recurring, goal }`, `CategoryFrequency { daily, weekly, biweekly, monthly, quarterly, semiannually, yearly }` (each with a `label`, for example "Every 2 weeks"), `IncomeKind { paycheck, sideHustle }` (`isAutomatic` is true for paycheck), `PayFrequency { weekly, biweekly, semimonthly, monthly }` (**income only**; semimonthly's label is "Twice a month").

`payDatesBetween(frequency, anchorDate, secondPayDay, from, to)`: the Dart copy of the server's `getPayDates` (section 9.4), with helpers `_daysBetween`, `_addMonths`, `_addEveryNDays`, `_addMonthly`, `_addSemimonthly`. Two Dart specific details:

- Dart has no `plusMonths`. `DateTime(2027, 1 + 1, 31)` rolls over to March 3, so `_addMonths` clamps the day to the end of the month like Java does.
- Dates are built from year, month, and day (`DateTime(y, m, d + 14)`) instead of adding a `Duration`, which would land on the wrong day across a daylight saving change. `_daysBetween` uses UTC dates for the same reason.

`IncomeSource` month values:

- `receivedDuring(month)`: the server's `receivedThisMonth` when there is one **and** `month` is the current month (the server value only describes the current month). Otherwise `_localTotal` from the 1st through today (a past month counts in full, a future month is 0).
- `expectedDuring(month)`: the server's `expectedThisMonth` under the same condition, otherwise `_localTotal` for the whole month.
- `upcomingPayDate`: the server's `nextPayDate`, otherwise calculated (the anchor if it is in the future, else the first payday after today within two months).
- `_localTotal(from, to)`: a paycheck is the number of `payDatesBetween` × `paycheckAmount` (0 with no anchor); a side hustle is the sum of payments dated in the range.

The old `monthlyEquivalent` average (biweekly × 26 / 12) was **removed**; nothing uses an average anymore.

`Budget.fromJson` contains a small migration: an old saved format with loose `expenses` and no categories is converted into a single "Spending" category. Category frequencies saved before `CategoryFrequency` existed (`weekly`, `biweekly`, `monthly`) have the same names, so old device data still loads.

Money in the client is a `double` of dollars. The API layer converts to and from cents at the boundary.

**`screens/account_screen.dart`**: sign in or create account.

- If an account is already saved on the device (`ledger.account != null`), it shows **Sign in** (email and password). Otherwise it shows **Create account** (first name, last name, email, password; the password must be at least 4 characters).
- The subtitle changes depending on local or remote mode.
- Shows `ledger.error` in red. This is the **only screen that displays API errors**.

**`screens/overview_screen.dart`**: the "This month" tab. (Still flat rows; no glass cards.)

- Header with the account name, month, and a **Sign out** button.
- Summary: **Income so far** (`receivedIncomeDuring`, paydays from the 1st through today) with "$X expected this month" under it, **Spent** (recurring categories this **calendar** month, any date in the month), **Left** (income so far minus spent). Every budget the user belongs to is included, including shared and view only ones (see 14.2).
- **Over the limit**: recurring categories over their limit **in their current period** (through `isOver`).
- **Spending**: this calendar month's expenses across all budgets, newest first.
- **Income**: every income source, "Every 2 weeks · $2,000.00 so far of $4,000.00" (manual: "$X logged this month").
- There is no "last N transactions" or "last N days" rule anywhere on this tab. Everything except Over the limit is the current calendar month, and lists have no length limit.

**`screens/budgets_screen.dart`**: three screens.

- `BudgetsScreen` (tab): each budget is a **`GlassCard`** tinted rust if over its limit, otherwise moss. Inside: the name, member chips (translucent white background, pill shape), and `spent / limit` (current periods summed). The **+** opens the create budget dialog. Tapping a card opens its detail.
- `BudgetDetailScreen`: totals ("Spent against limits" is the sum of current periods, plus "$X this month" for the calendar month); **Categories** as glass cards tinted gold (goal), rust (over this period), or moss. Each recurring card shows **this period's** spending against the limit and a subtitle like "Weekly · Oct 30 to Nov 5". Tap to open, **×** to remove. **People** as neutral glass cards (**×** to remove anyone but the owner); **Income** for this budget (flat `IncomeRow`s). The header also shows **Income this month**: "$X so far" and "$Y expected this month" (`receivedIncomeFor` and `expectedIncomeFor`). The trash icon in the app bar asks for confirmation, then calls `ledger.deleteBudget`. It looks up its budget **by ID** on every rebuild and pops itself only when the budget no longer exists.
- `CategoryScreen`:
  - Header: this period's spending against the limit, "$X left · Oct 30 to Nov 5", and a fill bar. Goals show all time progress.
  - **Expenses this period** (or **Contributions** for goals): add with **+**, remove with **×**. Rows stay flat on purpose.
  - **Past periods** (recurring categories in remote mode only): the three most recent completed periods as `PeriodRow` cards, then a **See all history** button that opens `CategoryHistoryScreen`. It requests 4 periods from `/history` and drops the first (the current one, already shown at the top). The request reruns whenever the ledger changes, so a backdated expense updates the right past period. Because the `FutureBuilder` keeps the previous result while the new one loads, the spinner only shows on the first load.
  - Finds its category by budget ID and category ID and pops only if the category is gone.

**`screens/category_history_screen.dart`**: history for one category.

- `CategoryHistoryScreen`: loads 12 periods from `/history`. A summary line ("Over the limit in 2 of 6 periods", "Average $715.80 per period") sits above one `PeriodRow` per period, the first one tagged **Current**. **Show more** asks for 12 more at a time, up to the backend's cap of 60. The button only shows when the server returned as many periods as asked for; fewer means the anchor was reached.
- `PeriodRow` (public, also used by `CategoryScreen`): a `GlassCard` with the date range, `spent / limit`, "Over by $X" in rust or "$X left", and a fill bar. When given a `ledger` and `category`, it is tappable, shows a chevron, and opens `PeriodDetailScreen`.
- `PeriodDetailScreen`: the period's totals at the top (taken from the `PeriodSummary`, so they show instantly) and a **Transactions** list loaded with `ledger.loadExpenses(categoryId, from: start, to: end)`, sorted newest first. **Read only**: no add or delete.

**`screens/income_screen.dart`**:

- `IncomeScreen` (tab): every income source, separated by `Hairline`s (not glass cards yet). **+** opens the income dialog (requires at least one budget).
- `IncomeRow`: one source, on two lines: "Budget · Every 2 weeks · next Nov 7" (`upcomingPayDate`; hidden when there is none) and "$0.00 so far · $4,000.00 this month" (manual: "$X logged this month"). The number on the right is still the amount of one paycheck (or the all time total for manual income). Tapping a paycheck opens the edit dialog (`updatePaycheck`, now saved to the server). Tapping a side hustle opens `SideHustleScreen`. Side hustles get a **Log** button. Every row has **×** to remove. Also reused on the budget detail screen.
- `SideHustleScreen`: total brought in, this month's amount so far (`receivedDuring`, so an entry dated later this month is not counted yet), and the list of logged payments (each removable). Looks up its source by ID and pops only if it is gone.

**`dialogs.dart`**: every popup form. Each `show...Dialog` function returns the new object, or `null` if cancelled.

| Dialog | Collects | Notes |
| --- | --- | --- |
| `showCreateBudgetDialog` | name, extra members by name and role | Owner is added automatically. **In remote mode only the title is sent; extra members are dropped.** |
| `showAddMemberDialog` | name, email, role (editor or viewer) | Email is required in remote mode |
| `showCategoryDialog` | name, type, reset frequency and start option (recurring only), amount | Turns the start option into one `anchorDate` (below). Amount must be greater than 0. |
| `showExpenseDialog` | label, amount, date | Date picker allows 2000 to 2100 |
| `showIncomeDialog` | automatic or manual, name, budget, and for automatic: amount, frequency, **payday**, and **second payday** (twice a month only) | Also used to edit a paycheck (it edits the existing object in place) |
| `showLogIncomeDialog` | amount, date | For side hustles |

The category dialog's start options, and how each becomes the anchor:

| Frequency | Option shown | Anchor sent |
| --- | --- | --- |
| Daily | none | today |
| Weekly | "Week starts on" weekday dropdown | the most recent chosen weekday, today or earlier |
| Every 2 weeks | date picker ("First day of a 2 week period") | the picked date |
| Monthly | "1st of the month" or "Specific day" (1 to 31) | the 1st of this month, or the most recent month that actually has that day, today or earlier (picking the 31st in November gives October 31, so the "31st" pattern is kept) |
| Quarterly / Every 6 months / Yearly | "Calendar quarters" / "January and July" / "January 1", or "Specific date" | the start of the current calendar quarter, half, or year, or the picked date |
| Savings goal | none | null |

- Changing the frequency resets the option to the calendar choice.
- Date pickers in this dialog only allow **today or earlier**, so the current period always exists.
- Dates are built with the `DateTime(year, month, day - n)` constructor, never by subtracting a `Duration`, because subtracting 24 hour chunks across a daylight saving change can land on the wrong day. `DateTime(year, month + 1, 0)` gives the last day of a month.
- A live line under the options shows the result: "Current period starts Nov 1, 2026."

The income dialog's schedule fields (automatic income only):

- **Payday** ("First payday" for twice a month): a date picker labeled "Pick your most recent payday, or your first one if it has not happened yet." Defaults to today for a new paycheck, or the saved anchor when editing. Allows dates from 2000 up to **one year ahead**, for a job that has not paid yet.
- **Second payday each month**: a 1 to 31 dropdown, shown only for "Twice a month". 31 is labeled "31 (last day)". Defaults to the 15th, or the 31st when the first payday is on the 15th. A note explains that days past the end of a short month use the last day.
- Saving twice a month with the same day twice shows "Pick a second payday that is different from the first." instead of letting the server return 400.

**`format.dart`**: `money(double)` → `$1,234.56`; `dateShort` → `Oct 27`; `monthYear` → `October 2026`; `sameMonth(a, b)`; `parseMoney(text)` strips `$` and commas and parses; `periodRange(start, end)` → "Oct 30 to Nov 5", adding years when the range crosses a year or is not in the current year, and a single date when start and end are the same day.

**`theme.dart`**: dark "space" look.

- `AppColors`: `paper` (near black background), `paperDim`, `bgGlow`, `ink` (main text), `inkFade` (secondary text), `hairline` (dividers), `moss` (green, good), `rust` (red, over or delete), `gold` (goals, editors, and 90% or more of a limit).
- `spendColor(spent, limit)`: moss under 90%, gold from 90% to 100%, rust over the limit.
- `buildTheme()`: Material 3 dark theme seeded from `moss`.
- `ledgerNumber()`: monospace text style with tabular figures for money.
- Reusable widgets: `SpaceBackground` (gradient plus a fixed random starfield), `SectionHeader` (title with optional trailing text and optional **+**), `Hairline`, `RoleBadge`, `RowAction` (small icon button), `FillBar` (thin progress bar), `EmptyNote` (gray helper text), and **`GlassCard`**.
- `GlassCard(child, tint, onTap?)`: a `Material` with an 8% fill of the tint color, a 28% tint border, 16px rounded corners, and 16px side / 5px vertical outer padding. An `InkWell` inside gives a ripple clipped to the corners; with no `onTap` it is inert. There is **no `BackdropFilter` blur** on purpose: blur on every card is expensive on the web build. Content inside a card uses about 14px side padding.

### 10.5 How the UI redraws

1. A screen calls a `Ledger` method.
2. Local only mode: the ledger changes its lists and calls `_touch()`, which calls `notifyListeners()`.
3. Remote mode: the ledger fires the API call in the background. When it finishes, `_refreshFromApi()` replaces the lists and `_touch()` notifies.
4. Every screen that called `ledger.addListener(...)` runs its handler, which calls `setState`, and Flutter rebuilds that screen. Detail screens re-find their object by ID at this point, because the refresh replaced every object. `CategoryScreen` also restarts its Past periods request.

History and period detail screens are different: they fetch once when opened (`FutureBuilder`) and do not listen to the ledger. Reopening them gets fresh data.

### 10.6 Accounts and passwords on the device

The account (including the **plain text password**) is saved in `shared_preferences` in both modes. On the web, this is the browser's local storage for the site. Signing out keeps the account and only flips `signedIn`. After the database is wiped (`docker compose down -v`), the app still has the old account and old IDs cached, so the browser's site data must be cleared.

### 10.7 Android, iOS, and desktop specifics

- The Android package ID is still the template's `com.example.frontend_app`, and the launcher label is `frontend_app`. Both are set in `android/app/build.gradle.kts` and `android/app/src/main/AndroidManifest.xml`. The Android, iOS, macOS, and Windows launcher icons are still Flutter's defaults (only the web icons were replaced).
- The main Android manifest does **not** declare the `INTERNET` permission. Debug builds get it from the debug manifest automatically, but a release build will not be able to reach the API until it is added.
- Android 9 and later block plain `http://` traffic by default, so release builds will need either HTTPS or a cleartext exception.
- iOS and macOS can only be built on a Mac.

### 10.8 Running Flutter without Android Studio

Eclipse has no maintained Flutter support. Flutter, the Android SDK command line tools, and the Android emulator all work from the terminal, and VSCodium with the Dart and Flutter extensions is an open source editor option for the Dart code.

When editing Dart through the terminal, writing a whole file with `cat > file <<'EOF' ... EOF` is safer than pasting fragments into Eclipse. The quotes around the first `EOF` stop the shell from touching `$` in Dart strings. Close the file in Eclipse first (without saving) so it does not write its old copy back.

### 10.9 Tests

`test/widget_test.dart` runs in local only mode with mocked `shared_preferences`:

1. **Expenses count toward a category limit**: create an account, create "Household", add a $100 "Groceries" category, log a $42.50 expense, add "Jordan" as a member, rebuild the app, and check everything was restored from device storage.
2. **A side hustle total updates when money is logged**: add a manual income source, log $80, check the total.

Both still pass after the period changes, because local only mode has no periods and falls back to all time totals.

`test/pay_dates_test.dart` (7 tests) checks `payDatesBetween` against the same cases as the Java `IncomeSourcePayDatesTest`: biweekly November (2 paydays) and January 2027 (3), a monthly anchor on Jan 31 (Feb 28, then Mar 31), semimonthly 15th and 31st in a 30 day month, semimonthly skipping dates before the anchor, a future anchor, and `expectedDuring` with no server values (4000 and 6000, not 4333.33).

Run them with Docker (section 4, "Running the tests"), or `flutter test` from `src/frontend_app` with Flutter installed. The Docker build does **not** run them. There are no tests for remote mode, deletes, the category dialog's anchor logic, or category periods.

---

## 11. How the frontend maps to the backend

| Client concept | Server concept | Conversion |
| --- | --- | --- |
| `Account` | `User` | password is kept on the client |
| `Budget.name` | `Budget.title` | |
| `Member` | `BudgetMemberView` | `role` lowercased ↔ uppercased; `Member.id` = membership row ID (used for delete) |
| `BudgetCategory` | `Category` | `kind` recurring/goal ↔ `categoryType` RECURRING/GOAL; `target` dollars ↔ `amountCents` |
| `CategoryFrequency` (7 values) | `Category.Frequency` (7 values) | same names, lowercase ↔ uppercase; goals send `null` |
| `BudgetCategory.anchorDate` | `Category.anchorDate` | `DateTime` ↔ `"yyyy-MM-dd"`; goals send `null` |
| `BudgetCategory.periodStart`, `periodEnd` | `CategoryResponse.periodStart`, `periodEnd` | read only, computed by the server for "today" |
| `BudgetCategory.current` | `/api/categories/{id}/remaining` | client sums the period's transactions itself; does not call the endpoint |
| `PeriodSummary` | `CategoryPeriodResponse` | `limit`, `spent` dollars ↔ `limitCents`, `spentCents`; `remainingCents` is ignored and recomputed |
| `Expense` | `Transaction` | `label` is sent as both `merchant` and `description`; read back from `merchant`, falling back to `description` |
| `IncomeSource` (paycheck) | `IncomeSource` with `autoGenerate: true` | `paycheckAmount` ↔ `amountCents`; `PayFrequency` lowercase ↔ uppercase (`semimonthly` ↔ `SEMIMONTHLY`); `anchorDate` `DateTime` ↔ `"yyyy-MM-dd"`; `secondPayDay` sent only for semimonthly |
| `IncomeSource.receivedThisMonth`, `expectedThisMonth`, `nextPayDate` | `IncomeSourceResponse.receivedThisMonthCents`, `expectedThisMonthCents`, `nextPayDate` | read only, calculated by the server for the `asOf` date the client sends (the device's today); cents ↔ dollars |
| `IncomeSource` (side hustle) | `IncomeSource` with `autoGenerate: false`, `frequency: IRREGULAR`, `amountCents: 0`, `anchorDate: null` | |
| `ledger.receivedIncomeFor(budgetId)`, `expectedIncomeFor(budgetId)` | `/api/budgets/{id}/income` | client adds up its own sources; does not call the endpoint |
| `IncomePayment` | `IncomeEntry` | `date` ↔ `receivedDate` |
| `Budget.totalLimit`, `totalSpent` | `/api/budgets/{id}/total`, `/remaining` | client calculates its own; does not call the endpoints |

---

## 12. Docker build and deployment

### 12.1 `Dockerfile` (three stages)

```dockerfile
# Stage 1: build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /web
COPY src/frontend_app/ .
RUN flutter pub get && flutter build web --release --dart-define=API_BASE=http://localhost:8080

# Stage 2: build the Spring Boot jar, with the web app inside it
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
COPY --from=web /web/build/web ./src/main/resources/static
RUN mvn -q -DskipTests package

# Stage 3: small runtime image with only a JRE and the jar
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/budget-app-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Because of stage 1, **nobody needs Flutter, Java, or Maven installed** to run the project. Docker is enough. Any change under `src/frontend_app/` (Dart code, icons, `index.html`) needs `docker compose up -d --build` to show up. The "You appear to be trying to run flutter as root" warning in stage 1 is harmless.

If a build fails, Docker keeps the **previous** image running, so the app still starts with the old code. Always check the build output, not just whether the site loads.

### 12.2 `docker-compose.yml`

- **`db`**: `postgres:16`, container `budget-db`. `POSTGRES_DB=budgetapp`, user and password from `.env`. Port `5432:5432` published (remove for production). Volume `db_data:/var/lib/postgresql/data`. Healthcheck runs `pg_isready` every 5 seconds, up to 10 retries.
- **`api`**: built from the `Dockerfile`, container `budget-api`. Waits for `db` to be **healthy** before starting. Gets `DB_USER`, `DB_PASSWORD`, **`TZ`**, and `SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/budgetapp`. Port `8080:8080`.

`.env` is required. Without it, the user and password are empty and Postgres will not start.

**`TZ`** is set as `TZ: ${TZ}` and read from `.env` (for example `TZ=America/New_York`). The JVM uses it for `LocalDate.now()` and `LocalDateTime.now()`. It is what makes "today", and therefore the current period, match the household's local date. `.env.example` should include a `TZ=` line so self hosters set their own. If `.env` leaves it out, the value is empty and the container falls back to UTC. Changing it only needs `docker compose up -d` (no rebuild); `docker exec budget-api date` shows the container's time.

YAML does not allow tab characters for indentation. A tab in this file makes `docker compose` fail with "found a tab character that violates indentation". `docker compose config` checks the file and prints the final values.

### 12.3 Target production setup

```
Internet → Cloudflare (DNS, protection) → Nginx Proxy Manager (homelab) → budget-api:8080 → budget-db
```

at `budget.spencerplus.com`, like the rest of the Spencer+ homelab.

Planned but not done:

- A GitHub Actions workflow that builds and pushes the image to GHCR or Docker Hub on `v*` tags.
- A release compose file that uses `image:` instead of `build:`, so self hosters only need the compose file and a `.env`.
- Removing the published `5432` port.
- Fixing `API_BASE` (see 14.3), which is currently baked in as `http://localhost:8080`.
- Putting real authentication in place first (section 14.1), since the delete endpoints are public too.

---

## 13. Project conventions and rules

- **Layering:** Controller → Service → Repository. Controllers never touch repositories.
- **No Lombok.** Hand-written getters and setters.
- **Plain for loops** instead of Streams (in both Java and new Dart code).
- **Never return entities** from controllers. Always a `Response` record. Calculated values are computed by the service and passed into `fromEntity`.
- **Money as `long` cents.** UUID primary keys. Enums stored as strings.
- **Derived values are calculated, never stored.** This includes every category period.
- **Missing rows are 404s** via `ResponseStatusException`, not plain `RuntimeException`. Bad input the annotations cannot express is a 400 thrown by the service.
- **Never edit a Flyway migration that has already run.** Add the next version. Next is still **V9**. (The two pre-release exceptions, V6 and V4, are documented in 6.1.)
- **Schedules are anchored.** Anything that repeats (category periods, paydays) stores one real date and calculates every occurrence from it, never by chaining from the last one. The server and the client use the same rules.
- **"Today" comes from the client** when it matters (`asOf`), so the user's time zone wins over the server's.
- **Categories are not editable** by design (see 6.4).
- **Secrets and settings** come from env vars (`DB_USER`, `DB_PASSWORD`, `TZ`). `.env` is gitignored; `.env.example` is committed.
- **Minimal dependencies and tooling.** End users should only need `docker compose up`.
- **Keep UI code simple**: no over-engineering (for example, `GlassCard` skips blur).
- **Open source, privacy first, self hosted.**
- Josh writes the backend code himself and prefers review that points out bugs over rewrites. For Dart, where he is less familiar, whole file replacements are preferred over piecemeal edits. Big features are done in phases (database, entity and records, service math with tests, endpoints, client model and API, UI, wrap up), each tested before the next, on a feature branch.

---

## 14. Known issues and gaps

### 14.1 Backend

- **No authentication or authorization.** All endpoints are open; login returns the user but no token. Anyone can add anyone to any budget as an editor or viewer, and anyone can delete any budget, category, transaction, member, or income record by ID. This is the root of the sharing problems below: with no logged in user on the request, the server has no idea who is asking, so it cannot check roles. Plan: JWT (library already in the pom) plus role checks in the services.
- **Roles are stored but never enforced.** No service checks the caller's role, so a `VIEWER` can create categories, log transactions, delete the budget, or add members.
- **No way to change a member's role, transfer ownership, or leave a budget.** There is no endpoint for any of the three.
- **No invite or accept step.** Adding a member is instant, and the invited person cannot decline.
- **`GET /api/users/by-email` leaks user details.** Anyone who knows someone's email can get their ID and name. Remove or restrict once auth exists.
- **Duplicate signup email returns 500.** Should return 409.
- **No global error handler** (`@ControllerAdvice`), so failures that are not explicit `ResponseStatusException`s surface as a generic 500. (`ResponseStatusException` messages are now included in error bodies; see 5.7.)
- **Creating a category for a budget that does not exist returns 500** (foreign key). Same for every create endpoint with a bad parent ID. Easiest to fix everywhere at once, probably alongside role checks, which will look up the budget anyway.
- **No length validation** on names and titles, so a value over 100 characters fails at the database with 500.
- **Only one update endpoint** (`PUT /api/incomesources/{id}`). Categories are intentionally not editable; budgets, transactions, members, and income entries could use updates.
- **Budget total and remaining are not meaningful** (they mix frequencies and goals; see 9.3).
- **History runs one query per period**, and the category list computes each category's period separately. Fine at this size.
- **No membership checks** when logging or deleting transactions or income.
- **No check on future transaction dates.**
- **Every paycheck is assumed to be the same amount.** Scheduled income is calculated from the schedule, so overtime, a bonus, or a smaller first check cannot be recorded for one payday. If that is needed later, the fix is a scheduler that writes an income entry on each payday (what `autoGenerate` was originally for) so single paychecks can be edited.
- **`autoGenerate` is now just a "scheduled paycheck" flag**; nothing runs on a schedule. It is not editable through PUT, so a paycheck cannot be turned into manual income (or back) without deleting and re-adding it.
- **POST and PUT for income sources answer with the server's today**, not the client's. The client reloads the list with `asOf` right after, so this does not show, but other clients should not rely on those three values.
- **Few automated tests.** The backend tests are `IncomeSourcePayDatesTest` (8 tests, pay date math only) and `BudgetMemberServiceTest` (6 tests, every branch of `createBudgetMember` with Mockito mocks). JUnit and Testcontainers are ready in the pom. `CategoryService.getPeriodContaining` is pure date math and the next best candidate (January 31 monthly anchor, biweekly parity, week boundaries, a date before the anchor). Testing it the same way needs no database: create the service with `null` repositories.
- **Style cleanup:** a Stream in `IncomeEntryController` (the one in `IncomeSourceController` was replaced with a for loop); `BudgetMemberView` should become its own response DTO; `IncomeSourceController` and `BudgetController` use wildcard `org.springframework.web.bind.annotation.*` imports while the others list imports one by one.

### 14.2 Frontend

- **Expenses from past periods cannot be deleted in the UI.** The category page only lists the current period, and `PeriodDetailScreen` is read only. A wrongly dated expense has to be removed with `psql` or curl. Adding a **×** to period detail rows is a small change.
- **A future dated expense** (the expense dialog allows dates up to 2100) does not show in the current period until its period arrives, which can look like it disappeared.
- **API errors are invisible outside the account screen.** `ledger.error` is only displayed on `AccountScreen`, so a failed add or delete on any other screen (for example a 400 from the category rules, a 409 from removing the owner, or the new "That person is already on this budget." message) fails silently.
- **No way to sign in to an existing server account on a new device.** `AccountScreen` only offers Sign in when an account is already saved on the device. On a fresh browser it only shows Create account, and creating with an existing email fails on the server.
- **The password is stored in plain text on the device**, and signing out does not remove it.
- **No re-authentication on launch**: if `signedIn` was saved as true, the app loads that user's data from the API using the cached ID.
- **Create budget dialog's extra members are dropped in remote mode**; only the title is sent.
- **The income dialog edits the paycheck object before the server answers.** If the PUT fails (for example a 400), the row shows the new values until the next refresh, and the error is invisible outside the account screen.
- **The Overview includes every budget the user belongs to**, including view only ones. With the test data, Josh's Overview counts Abigail's paycheck and hobby spending from Abigail Personal, where he is only a viewer. Needs a decision: only owner and editor budgets, or a budget filter.
- **Overview Spent and Income use different cutoffs.** Income so far stops at today; Spent counts every expense dated in the month, including future dated ones, so a future expense lowers "Left" early.
- **Overview Spent is by calendar month** even for weekly or yearly categories (those are only judged on their own periods in "Over the limit").
- **Many sequential requests** on every load and after every change (one per budget, category, and income source). Every category's **entire** transaction history is loaded, even though cards only need the current period. The category page also reruns its Past periods request on every ledger change.
- **The budget level totals mix period lengths**: "Spent against limits" adds a weekly category's week to a monthly category's month. Rough, not wrong, but not a meaningful single number.
- **Category periods do not exist in local only mode** (the server computes them). Income does work there (the client has its own payday math).
- **`BudgetCategory.periodLabel` duplicates `periodRange`** in `format.dart`. Optional cleanup: `String? get periodLabel => hasPeriod ? periodRange(periodStart!, periodEnd!) : null;`.
- **After a database wipe**, clear the browser's site data or the app keeps a stale account.
- **Web branding is half done**: the favicon and PWA icons are the Spencer+ logo, but the tab title, manifest name, description, and theme color are still Flutter template values (see 10.2).
- **Glass card styling is partial**: budgets, categories, people, and period rows use `GlassCard`; the Income tab, the budget detail's income rows, and the Overview are still flat rows with hairlines. The income rows now have two subtitle lines.
- **Android:** package ID is still `com.example.frontend_app`; no `INTERNET` permission in the main manifest; cleartext HTTP blocked on release builds; default launcher icon.
- **No remote mode tests.** The only Dart tests are the two widget tests and `pay_dates_test.dart`.

### 14.3 Deployment

- **`API_BASE` is baked in as `http://localhost:8080`** in the Docker web build. A visitor opening `budget.spencerplus.com` would have their browser call `localhost:8080` on their own machine. Since the web app and API are served from the same origin, the web build should use a relative base (the page's own origin) instead. An empty value cannot be used for this because empty means local only mode, so this needs a small change in `api.dart`.
- **`TZ` has no fallback** in `docker-compose.yml`; a `.env` without it runs in UTC. Either keep `TZ=` in `.env.example` or change the line to `TZ: ${TZ:-America/New_York}`.
- **Port 5432 is published** to the host. Remove for production.
- **No published image or release compose file yet.**
- **`target/` and Flutter's generated `ephemeral/` files** are build output and should be gitignored if they are committed.

---

## 15. Roadmap

**Done**

- Full data model and migrations V1 to V8
- Create and list endpoints for every entity
- Delete endpoints for every entity except users, with 404 for missing rows and 409 for removing a budget's owner
- Budget delete with cascade, plus category → transactions and income source → entries through the same V8 cascades
- Client deletes wired to the API (budgets, categories, expenses, members, income sources, payments)
- Detail screens no longer close themselves after a remote refresh (lookups by ID)
- Category remaining, budget total, budget remaining
- **Category periods** (November 3, 2026):
  - `anchor_date` column with a CHECK constraint, and validation of the recurring/goal rules (400)
  - Period math for all seven frequencies; `remaining` scoped to the current period
  - `GET /api/categories/{id}/history`, and `from`/`to` filters on the transactions endpoint
  - Category responses include the current `periodStart`/`periodEnd`
  - Create category dialog with frequency specific start options, turned into one anchor date
  - Category cards and the category page show current period spending
  - Past periods section on the category page, a full history screen, and a period detail screen
  - API container time zone (`TZ`)
- Docker Compose with a single container for web and API
- Flutter client merged (PR #1), plus the review fixes: cascade migration, transactional budget creation, shared budget listing, removal of auto-created "changeme" accounts
- Glass card UI (`GlassCard`, status tinted) on the budgets list, categories, people, and period rows
- Spencer+ favicon and web icons
- **Income paydays** (November 4, 2026), on the `income-pay-dates` branch:
  - `income_sources` has `anchor_date` and `second_pay_day` with three CHECK constraints (V4 edited, pre-release); `DAILY` removed from income
  - Pay date math for weekly, biweekly, twice a month, and monthly, with "received this month" (only paydays that already happened), "expected this month" (real number of paydays), and next payday
  - `asOf` on the income list, `GET /api/budgets/{id}/income`, and `PUT /api/incomesources/{id}`
  - First JUnit test class (`IncomeSourcePayDatesTest`) and a Dart test (`pay_dates_test.dart`) for the same cases
  - Income dialog with a payday picker and a second payday for twice a month; rows show "so far · this month · next"; Overview and budget detail use income received so far
  - The same pay date math in Dart, for local only mode and when the server is unreachable
  - `scripts/seed_test_data.sql` for manual testing
- **Budget member checks** (November 5, 2026): adding a member returns 400 for role `OWNER`, 404 for a missing budget or user, and 409 for a duplicate (including two requests at once) instead of 500; error bodies include the message; `BudgetMemberServiceTest`; the client turns the 409 into a friendly message

**Next**

1. Small history follow ups: allow deleting expenses from `PeriodDetailScreen`; add a `TZ=` line to `.env.example`; optionally shorten `periodLabel`.
2. Merge `income-pay-dates` into `main` (fast forward) after the full test. Then unit tests for `getPeriodContaining` (cheap and high value).
3. Finish the glass card pass on the Income tab (and decide on the Overview).
4. Update endpoints for budgets, transactions, members, and income entries (income sources already have PUT). (Categories stay non-editable.)
4b. Decide what the Overview counts: shared view only budgets, and whether future dated expenses count before their date.
5. Error handling: show `ledger.error` on every screen, not only sign in (needed before the member 409 message is visible). Apply the member pattern (check first, 404/409) to signup's duplicate email and to bad parent IDs on the other create endpoints, or add a `@ControllerAdvice`.
6. Real authentication with JWT, and role checks (owner manages members and deletes the budget, editor adds, changes, and deletes items, viewer reads only). Then remove or lock down `by-email`.
7. Sign in to an existing server account from a fresh device.
8. Budget level history: a date stepper on the budget screen ("< Aug 2026 >") where each card shows the period that contained that date. Needs an optional `asOf` date on `GET /api/categories/budget/{id}`; `getPeriodContaining` already accepts any date. Also decide what a meaningful budget level total is.
9. Only if per paycheck edits are needed (bonus, overtime): a scheduler that writes an income entry on each payday so single paychecks can be changed.
10. Tests: JUnit with Testcontainers for services and controllers (including deletes, cascades, and history); Flutter tests for remote mode and the category dialog.
11. Release: fix `API_BASE`, GitHub Actions image publishing, release compose file, remove port 5432, deploy behind Nginx Proxy Manager and Cloudflare.
12. Android build (package ID, permissions, HTTPS, launcher icon). iOS needs a Mac.
13. Choose the final app name, then update the web title, manifest, and Android label to match.

**Stretch Goals**

1. Adding some charts and analytics to the main page or maybe a separate tab (history data from `/history` is a natural source).
2. Include a way to upload files (receipts and documents).
3. A separate investment or retirement account table with a stored balance.

---

## 16. Handy commands

```bash
# Docker
docker compose up -d --build          # rebuild and start everything
docker compose up -d                  # apply .env or compose changes without rebuilding
docker compose up -d db               # only Postgres (for running the API from Eclipse)
docker compose ps                     # container status
docker compose logs -f api            # follow the API log
docker compose config                 # check docker-compose.yml and print the final values
docker compose down                   # stop, keep data
docker compose down -v                # stop and WIPE all data (required after editing a migration)
docker exec budget-api date           # show the API container's clock and time zone

# Postgres shell (use your DB_USER from .env)
docker exec -it budget-db psql -U budgetapp -d budgetapp
#   \dt                list tables
#   \d categories      describe a table (shows anchor_date and the CHECK constraint)
#   select version, description, success from flyway_schema_history order by installed_rank;
#   q                  leave the pager
#   \q                 exit psql

# One-off query without opening psql
docker exec -it budget-db psql -U budgetapp -d budgetapp -c "SELECT name, category_type, frequency, anchor_date FROM categories;"

# Change a category's settings for testing (history recalculates immediately)
docker exec -it budget-db psql -U budgetapp -d budgetapp -c "UPDATE categories SET anchor_date = '2026-06-01' WHERE name = 'Groceries & Supplies';"

# Look up an ID into a shell variable, then use it (avoids pasting placeholders)
CAT=$(docker exec budget-db psql -U budgetapp -d budgetapp -tAc "SELECT id FROM categories WHERE name='Groceries & Supplies'")
curl -s "http://localhost:8080/api/categories/$CAT/history?periods=6"
curl -s "http://localhost:8080/api/transactions/category/$CAT?from=2026-08-01&to=2026-08-31"

# Load the test data (3 budgets, 11 categories, 31 transactions, 11 income sources, 7 entries).
# Needs Josh's account and Abigail's (abigailspencer@gmail.com) to exist first; create hers through the API so the password works:
curl -s -X POST http://localhost:8080/api/users -H "Content-Type: application/json" \
  -d '{"firstName":"Abigail","lastName":"Spencer","email":"abigailspencer@gmail.com","password":"password123"}'; echo
docker exec -i budget-db psql -U budgetapp -d budgetapp < scripts/seed_test_data.sql
# Safe to rerun: it deletes its own budgets (fixed IDs 11111111-0000-0000-0000-00000000000X) first.
# Paydays use fixed dates (expected values for Nov 4, 2026 are in the comments); transactions and entries are relative to today.

# Every table at once
for t in users budgets budget_members categories transactions income_sources income_entries; do
  echo "===== $t ====="; docker exec budget-db psql -U budgetapp -d budgetapp -c "SELECT * FROM $t;"
done

# Income schedule only
docker exec budget-db psql -U budgetapp -d budgetapp -c "SELECT name, amount_cents, frequency, anchor_date, second_pay_day, auto_generate FROM income_sources;"

# Income numbers for any day (readable output)
curl -s "http://localhost:8080/api/incomesources/budget/$BUDGET?asOf=2026-11-07" | python3 -m json.tool | grep -E '"name"|ThisMonthCents|nextPayDate'
curl -s "http://localhost:8080/api/budgets/$BUDGET/income?asOf=2026-11-30"; echo

# Status code only (for checking 400 and 404)
curl -s -o /dev/null -w "%{http_code}\n" -X PUT http://localhost:8080/api/incomesources/$SOURCE -H "Content-Type: application/json" -d '{...}'

# Tests
mvn test                                      # every JUnit test; needs Maven in the terminal (sudo dnf install maven); or Run As → JUnit Test in Eclipse
mvn test -Dtest=BudgetMemberServiceTest       # one class

# Fire 5 identical requests at once (race test for duplicate members; expect one 200 and four 409s)
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8080/api/budgetmembers \
    -H "Content-Type: application/json" \
    -d "{\"budgetId\":\"$BUDGET\",\"userId\":\"$NEWUSER\",\"role\":\"EDITOR\"}" &
done; wait

# Budgets whose owner has no OWNER membership row (from before createBudget added it)
docker exec budget-db psql -U budgetapp -d budgetapp -c "SELECT b.id, b.title FROM budgets b WHERE NOT EXISTS (SELECT 1 FROM budget_members m WHERE m.budget_id = b.id AND m.user_id = b.owner_id);"
docker run --rm -v "$PWD/src/frontend_app":/src:ro,z ghcr.io/cirruslabs/flutter:stable \
  sh -c "cp -r /src /app && cd /app && flutter pub get && flutter test test/pay_dates_test.dart"

# Git: feature branches
git branch --show-current             # which branch am I on
git switch -c name                    # new branch from here (keeps uncommitted changes)
git push -u origin name               # first push of a new branch
git log --oneline -5                  # recent commits

# Run a block of SQL (for seeding test data) from the terminal
docker exec -i budget-db psql -U budgetapp -d budgetapp <<'SQL'
-- statements here
SQL

# Backend on the host
export DB_USER=budgetapp DB_PASSWORD=yourpassword
mvn spring-boot:run
mvn -DskipTests package               # build the jar into target/

# Flutter (from src/frontend_app)
flutter pub get                       # download Dart dependencies
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
flutter test                          # run widget tests
flutter doctor                        # check the toolchain

# Find tab characters in a file (YAML rejects them)
grep -nP '\t' docker-compose.yml

# Regenerate web icons from the logo (from src/frontend_app/web, needs ImageMagick)
magick logo_clean.png -resize 32x32 -background none -gravity center -extent 32x32 favicon.png
for s in 192 512; do
  magick logo_clean.png -resize ${s}x${s} -background none -gravity center -extent ${s}x${s} icons/Icon-$s.png
  magick logo_clean.png -resize $((s*8/10))x$((s*8/10)) -background white -gravity center -extent ${s}x${s} icons/Icon-maskable-$s.png
done
# After rebuilding: DevTools → Application → Clear site data, then Ctrl+Shift+R
```

---

## 17. Change log

**November 5, 2026: budget member checks**

Adding a user who was already on a budget returned 500 from the UNIQUE constraint. It now returns a clean error, and so do the other bad inputs to that endpoint.

- Backend, budgetmembers: `BudgetMemberService` gained `BudgetRepository` as a dependency. `createBudgetMember` now rejects role `OWNER` (400), a missing budget or user (404), and an existing membership (409, through `findByBudgetIdAndUserId`), in that order. It saves with `saveAndFlush` and turns a `DataIntegrityViolationException` into the same 409, so two identical requests at once no longer give a 500. The controller did not change.
- Backend, config: `server.error.include-message: always` in `application.yml`, so every `ResponseStatusException` message appears in the error body's `message` field.
- Backend, tests: new `BudgetMemberServiceTest` (6 tests: OWNER role, missing budget, missing user, existing member, constraint violation on save, valid member). Uses Mockito, no database.
- Client, api: `addMember` turns a 409 into "That person is already on this budget." It is not visible yet outside the account screen (14.2).
- Data note: budgets created before `createBudget` added the OWNER row have no owner membership, so the duplicate check cannot see the owner on them. Fixed on Josh's database by updating that row to `OWNER`; the query to find others is in section 16.
- Tested with curl: valid member 200, duplicate 409, owner 409, role OWNER 400, random budget 404, random user 404, and five simultaneous identical requests gave one 200 and four 409s.

**November 4, 2026: income paydays (branch `income-pay-dates`)**

The income tab showed a monthly average ($2,000 every 2 weeks showed as $4,333.33 a month) instead of what had actually been paid. Income now shows money received so far this month, based on real paydays.

- Database: **edited V4** (pre-release only; every database was wiped): `next_pay_date` replaced by `anchor_date`; added `second_pay_day INTEGER`; added `chk_income_sources_frequency`, `chk_income_sources_anchor_date`, and `chk_income_sources_second_pay_day`. `DAILY` is no longer an income frequency. Next migration is still V9.
- Backend, incomesource: `IncomeSource.anchorDate` and `secondPayDay` (the stored `nextPayDate` field removed; next payday is now calculated); `DAILY` removed from the enum. `CreateIncomeSourceRequest` takes `anchorDate` and `secondPayDay`. New `UpdateIncomeSourceRequest`. `IncomeSourceResponse` gained `anchorDate`, `secondPayDay`, `receivedThisMonthCents`, `expectedThisMonthCents`, `nextPayDate`, and `fromEntity` takes the three calculated values. `IncomeSourceService` gained `IncomeEntryService` as a dependency, `validateSchedule` (400s), `updateIncomeSource`, `toResponse`, `getPayDates`, `getReceivedCents`, `getExpectedCents`, `getNextPayDate`, and the private `addEveryNDays`, `addMonthly`, `addSemimonthly`. The controller's list takes `?asOf=`, uses a for loop instead of a Stream, and has a new `PUT /{id}`.
- Backend, incomeentry: `findByIncomeSourceIdAndReceivedDateBetween` and `IncomeEntryService.getTotalCentsBetween`.
- Backend, budget: `BudgetService` depends on `IncomeSourceService`; new `getIncome(budgetId, asOf)`, `BudgetIncomeResponse`, and `GET /api/budgets/{id}/income?asOf=`.
- Backend, tests: first test class, `src/test/java/.../incomesource/IncomeSourcePayDatesTest.java` (8 tests). The math was also checked against a brute force list over 20,000 random date ranges with no mismatches.
- Client, models: `PayFrequency.semimonthly` ("Twice a month"); `IncomeSource` gained `anchorDate`, `secondPayDay`, `receivedThisMonth`, `expectedThisMonth`, `nextPayDate`, `receivedDuring`, `upcomingPayDate`, `_localTotal`; `expectedDuring` uses the server value or real paydays. New `payDatesBetween` and its helpers. `monthlyEquivalent` removed. Every `switch` on `PayFrequency` handles `semimonthly` (Dart 3 rejects a switch that misses an enum value).
- Client, api: `addIncome` and new `updateIncome` share `_incomeSchedule`; `_object` supports `PUT`; `loadIncome` sends `?asOf=` with the device's date and reads the new fields; `_apiFrequency` and `_payFrequency` handle `SEMIMONTHLY` (it used to come back as monthly).
- Client, ledger: `updatePaycheck` takes optional `anchorDate` and `secondPayDay` and calls the API in remote mode; new `receivedIncomeDuring`, `receivedIncomeFor`, `expectedIncomeFor`.
- Client, dialogs: the income dialog has a payday picker and a second payday dropdown for twice a month, a same day check, and passes both values when adding or editing.
- Client, screens: `IncomeRow` shows "Budget · Every 2 weeks · next Nov 7" and "$0.00 so far · $4,000.00 this month"; the edit passes the new fields. The side hustle screen counts only entries up to today. The Overview shows "Income so far" with "expected this month" under it, and Left uses income so far. The budget detail header shows the budget's income so far and expected.
- Client, tests: `test/pay_dates_test.dart` (7 tests), run with the Flutter Docker image.
- Scripts: `scripts/seed_test_data.sql` with test data for every income and category case, using Josh's account and a second test account (Abigail).

**November 3, 2026: category periods and history**

- Database: added `anchor_date DATE` and the `chk_categories_anchor_date` CHECK constraint to `categories` by **editing V6** (pre-release only; every database was wiped). Next migration is still V9.
- Backend, category: `Category.anchorDate`; `CreateCategoryRequest.anchorDate`; `createCategory` validates the recurring/goal rules (400). New `CategoryPeriod` and `CategoryPeriodResponse` records. New service methods `getCategory`, `getCurrentPeriod`, `getHistory`, `getPeriodContaining`, plus private `getPeriodIndex`, `getPeriodStart`, `sumAmounts`. `getRemainingAmount` now uses the current period for recurring categories and returns 404 (instead of 500) for a missing category. `CategoryResponse` gained `anchorDate`, `periodStart`, `periodEnd`, and `fromEntity` now takes the current period. New endpoint `GET /api/categories/{id}/history?periods=`. The `budget/{budgetId}` mapping gained its missing leading slash.
- Backend, transaction: three date filter repository methods; `getTransactionForCategory` takes optional `from`/`to` (400 if reversed); the controller reads them as optional ISO date query params.
- Docker: `TZ` added to the api service environment and to `.env`, so "today" matches local time.
- Client, models: new `CategoryFrequency` enum (all seven server frequencies) replaces `PayFrequency` for categories; `PayFrequency` is now income only. `BudgetCategory` gained `anchorDate`, `periodStart`, `periodEnd`, `hasPeriod`, `periodExpenses`, `periodLabel`, and `current` now sums only the current period. New `PeriodSummary`.
- Client, api: goals now send `null` frequency and anchor (they were sending a frequency, which the new validation rejects). Added `loadHistory`, `loadExpenses` (with `from`/`to`), and `_expense`; `_categories` reads `anchorDate` and the period fields and loads transactions through `loadExpenses`. Cleaned up stray tabs and the unindented `_userIdFor`.
- Client, ledger: added `loadHistory` and `loadExpenses` pass throughs.
- Client, format: added `periodRange`.
- Client, dialogs: the category dialog has frequency specific start options and a live "Current period starts ..." preview, and returns an `anchorDate`.
- Client, screens: category cards show current period spending and "Frequency · period"; the category page shows this period's expenses and a Past periods section with "See all history"; new `category_history_screen.dart` with `CategoryHistoryScreen`, the public `PeriodRow`, and `PeriodDetailScreen`.

**November 1, 2026**

- Backend: added `DELETE /{id}` to categories, transactions, budget members, income sources, and income entries. Budget delete now returns 404 for a missing ID instead of a silent 200. Every delete service checks existence first and throws a 404 `ResponseStatusException`. Removing the `OWNER` membership returns 409.
- Client: `api.dart` `_object` now supports `DELETE`, with six new delete methods. Every remove method in `ledger.dart` (except `updatePaycheck`, which is an edit) now calls the API in remote mode. Before this, removes only changed local state and the items came back on the next refresh.
- Client: `BudgetDetailScreen`, `CategoryScreen`, and `SideHustleScreen` find their object by ID after each refresh, fixing the bug where any remote change closed the open detail screen.
- UI: added `GlassCard` to `theme.dart` (status tinted translucent card, no blur) and applied it to the budgets list, categories, and people. Member chips use a translucent white background.
- Web: replaced the Flutter favicon and PWA icons with the Spencer+ logo; source images `Spencer_Plus_Logo_Cross.png` and `logo_clean.png` added to `web/`.
