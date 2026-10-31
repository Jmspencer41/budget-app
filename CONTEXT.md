# Project Context

This document explains how the whole project works: what each piece does, how the pieces talk to each other, how data moves from a button tap in the app to a row in Postgres, and what is still missing or broken. It is written so a new contributor (or an AI assistant) can read it once and understand the codebase without opening every file.

Last reviewed against the code: October 2026.

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
9. [Derived values (totals and remaining)](#9-derived-values-totals-and-remaining)
10. [Frontend (Flutter)](#10-frontend-flutter)
11. [How the frontend maps to the backend](#11-how-the-frontend-maps-to-the-backend)
12. [Docker build and deployment](#12-docker-build-and-deployment)
13. [Project conventions and rules](#13-project-conventions-and-rules)
14. [Known issues and gaps](#14-known-issues-and-gaps)
15. [Roadmap](#15-roadmap)
16. [Handy commands](#16-handy-commands)

---

## 1. What this project is

An open source, self-hosted budgeting app. The main idea is **shared budgets**: a household can keep one budget that several people work on, each with a role (`OWNER`, `EDITOR`, or `VIEWER`), while each person still logs their own spending and income under it.

Inside a budget:

- **Categories** are either a **recurring spending limit** (for example, $400 a month for groceries) or a **savings goal** (for example, $2,000 for a vacation).
- **Transactions** are purchases logged against a category by a specific user. They count against a limit or toward a goal.
- **Income sources** are things like a paycheck or a side job. Each one belongs to one user and sends money to one budget.
- **Income entries** are individual payments received from an income source.

It is **API first**. The backend is a Spring Boot REST API that returns JSON. The client is a Flutter app that can build for web, Android, iOS, Linux, macOS, and Windows from one codebase. No client ever talks to the database directly.

It ships as **Docker Compose**: one container for the app (the API plus the compiled Flutter web app) and one container for Postgres. The target is a working release by the end of the year, published on GitHub and a container registry (GHCR or Docker Hub), 

the initial build will be running at `budget.spencerplus.com` behind Nginx Proxy Manager and Cloudflare.

License: **AGPL-3.0**.

---

## 2. Repository layout

```
budget-app/
├── pom.xml                      Maven build for the backend (like package.json for Java)
├── Dockerfile                   3-stage build: Flutter web → Maven jar → JRE runtime
├── docker-compose.yml           Runs Postgres (budget-db) and the app (budget-api)
├── .env.example                 Template for DB_USER and DB_PASSWORD (copy to .env)
├── .env                         Real credentials. Gitignored. Never commit.
├── start-server.sh              Linux helper: pulls main, builds, starts, waits for the API
├── start.ps1                    Windows helper: same idea, then launches Flutter
├── linuxInstructions.md         Step by step home lab setup on Linux
├── windowsInstructions.md       Step by step setup on Windows with Docker Desktop
├── README.md
├── LICENSE                      AGPL-3.0
├── docs/
│   ├── overview.md              Original design overview
│   └── sql_table_diagram.drawio Database diagram (open with draw.io)
├── target/                      Maven build output. Generated. Do not edit.
└── src/
    ├── main/
    │   ├── java/com/spencerplus/budget/
    │   │   ├── BudgetApplication.java     Spring Boot entry point (main method)
    │   │   ├── config/                    SecurityConfig (password hashing, CORS, open endpoints)
    │   │   ├── user/                      Accounts, signup, login
    │   │   ├── budget/                    Budgets, totals
    │   │   ├── budgetmembers/             Who is on which budget, with what role
    │   │   ├── category/                  Spending limits and savings goals
    │   │   ├── transaction/               Purchases logged against categories
    │   │   ├── incomesource/              Paychecks and side jobs
    │   │   └── incomeentry/               Individual payments received
    │   └── resources/
    │       ├── application.yml            Port, database connection, JPA and Flyway settings
    │       ├── db/migration/V1..V8        Flyway SQL files that build the schema
    │       └── static/                    (Only exists during the Docker build) the Flutter web app
    └── frontend_app/                      The Flutter client (see section 11)
        ├── pubspec.yaml                   Flutter dependencies (like pom.xml)
        ├── lib/                           ALL the app's Dart code lives here
        ├── test/                          Flutter widget tests
        ├── web/                           Web shell: index.html, manifest, icons
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
│   Service      business logic (create, calculate, list)         │
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
10. Back in the app, `_remoteAction` calls `_refreshFromApi()`, which reloads **every** budget, member, category, transaction, income source, and income entry from the API, replaces the in-memory lists, saves a copy to the device, and tells the UI to redraw.

---

## 4. Running the project

### With Docker (the normal way)

```bash
cp .env.example .env        # then edit DB_USER and DB_PASSWORD
docker compose up -d --build
```

- `http://localhost:8080` serves the web app and the API.
- Postgres listens on `localhost:5432`, database `budgetapp`.
- `start-server.sh` (Linux) and `start.ps1` (Windows) wrap this: they pull `main`, create `.env` if missing, build, start, wait until port 8080 answers, and print the applied migrations.

### Backend on the host (for debugging in Eclipse)

```bash
docker compose up -d db                  # only the database
export DB_USER=... DB_PASSWORD=...       # must match .env; Maven does not read .env
mvn spring-boot:run                      # or run BudgetApplication from Eclipse
```

`application.yml` points at `jdbc:postgresql://localhost:5432/budgetapp` and falls back to `budgetapp` / `localdev` if the env vars are missing. In Docker, `SPRING_DATASOURCE_URL` overrides the host to `db` (the Postgres container's name on the Compose network).

### Flutter client on its own

The Flutter SDK is needed for this.

```bash
cd src/frontend_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080   # web
flutter run -d linux  --dart-define=API_BASE=http://localhost:8080   # Linux desktop
flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8080  # Android emulator
```

- On the Android emulator, `localhost` means the emulator itself. `10.0.2.2` is the emulator's alias for the host machine.
- Leaving out `--dart-define=API_BASE=...` runs the app in **local only mode** (see section 11.3).
- In the `flutter run` terminal: `r` hot reload, `R` hot restart, `q` quit.
- iOS and macOS builds need a Mac with Xcode.

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
| Testing | `spring-boot-starter-test`, `spring-security-test`, Testcontainers 1.20.1 (`junit-jupiter`, `postgresql`). **No tests written yet.** |
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
```

`ddl-auto: validate` matters: on startup Hibernate compares every `@Entity` against the real tables. If a column is missing or the wrong type, **the app refuses to start**. All schema changes must go through a new Flyway migration.

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
| `XResponse.java` | Java `record` for the outgoing JSON, with a static `fromEntity(X)` method. |

**Entities are never returned directly.** This keeps internal fields (most importantly `User.passwordHash`) out of API responses and lets the database shape change without changing the JSON.

**Layering rule:** Controller → Service → Repository. A Service may use another feature's repository or service (for example `BudgetService` uses `CategoryRepository`, `CategoryService`, and `BudgetMemberRepository`).

### 5.5 How entities relate in Java

Entities store foreign keys as **plain `UUID` fields** (`budgetId`, `userId`, `categoryId`), not as JPA relationships (`@ManyToOne`, `@OneToMany`). This keeps the entities simple and avoids lazy loading problems. The trade off is that a service has to look up related rows itself (for example `BudgetMemberService.listForBudget` looks up each member's `User` to get their name), and cascading deletes are handled **in the database** (V8), not by Hibernate.

IDs: each entity uses `@Id @GeneratedValue private UUID id;`. Hibernate generates the UUID in Java before the insert. The `DEFAULT gen_random_uuid()` in the SQL is a fallback that only applies to rows inserted by hand in `psql`.

Timestamps: each entity sets `createdAt = LocalDateTime.now()` in Java when the object is created. The SQL `DEFAULT now()` likewise only applies to manual inserts. Inside the container this is UTC.

Enums are stored as strings using `@Enumerated(EnumType.STRING)`, so the database holds `'MONTHLY'`, not `2`. Adding or reordering enum values never corrupts existing rows.

### 5.6 Security (`config/SecurityConfig.java`)

- `PasswordEncoder` bean: `BCryptPasswordEncoder`. Passwords are hashed on signup and checked with `matches` on login.
- `SecurityFilterChain`: CSRF disabled, CORS enabled, and **`anyRequest().permitAll()`**. There is a `TODO` noting this is open for development.
- `CorsConfigurationSource`: allows **any origin** (`setAllowedOriginPatterns("*")`), methods `GET, POST, PUT, PATCH, DELETE, OPTIONS`, any header.

What this means today: **there is no authentication.** Login only checks the password and returns the user. It does not issue a token, and no endpoint requires one. Anyone who can reach port 8080 can read or change anything, including adding themselves as `OWNER` of any budget.

### 5.7 Validation and errors

- Request records use Jakarta validation annotations. The controller parameter has `@Valid`, so a bad body returns **400 Bad Request** before the service runs.
- An enum value that does not exist (for example `"role": "ADMIN"`) or a badly formatted UUID or date fails JSON parsing and also returns **400**.
- `UserService` throws `ResponseStatusException` with **404** (user not found) or **401** (wrong password).
- Everything else that goes wrong becomes **500**. There is no `@ControllerAdvice` global error handler yet. Examples: a duplicate email on signup, a duplicate budget member, a foreign key that points at nothing, a category that does not exist in `/remaining` (it throws a plain `RuntimeException`).
- Spring's default error body looks like `{"timestamp": "...", "status": 400, "error": "Bad Request", "path": "/api/..."}`. The exception message is not included by default.

### 5.8 JSON format

- Field names are the Java record component names in camelCase (`amountCents`, `budgetId`, `transactionDate`).
- `UUID` → string: `"3f2c...-..."`
- `LocalDate` → `"2026-10-27"`
- `LocalDateTime` → `"2026-10-27T23:24:29.508124"` (no time zone)
- Enums → their name as a string: `"MONTHLY"`
- Money → whole number of cents: `4250` means $42.50
- Endpoints that return a single `long` (totals, remaining) return a bare number, not an object.

---

## 6. Database (Postgres and Flyway)

### 6.1 Migrations

Located in `src/main/resources/db/migration/`. **Never edit a migration that has already run.** Add a new file instead. **The next one is `V9__...sql`.** The file name format is `V<number>__<description>.sql` (two underscores).

| File | What it does |
| --- | --- |
| `V1__create_users_table.sql` | `users` |
| `V2__create_budget_table.sql` | `budgets` (owner is a user) |
| `V3__create_budget_members_table.sql` | `budget_members` (join table, unique per budget and user) |
| `V4__create_income_sources_table.sql` | `income_sources` |
| `V5__create_income_entries_table.sql` | `income_entries` |
| `V6__create_categories_table.sql` | `categories` |
| `V7__create_transactions_table.sql` | `transactions` |
| `V8__cascade_deletes.sql` | Replaces five foreign keys with `ON DELETE CASCADE` versions |

Note that income tables (V4, V5) were created before categories (V6) because of the Budget and Category redesign partway through the project.

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
| `frequency` | VARCHAR(20) | nullable. `DAILY, WEEKLY, BIWEEKLY, MONTHLY, QUARTERLY, SEMIANNUALLY, YEARLY`. Meant to be null for goals. |
| `amount_cents` | BIGINT | NOT NULL. The limit (recurring) or the target (goal). |

**`transactions`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `category_id` | UUID | NOT NULL, FK → `categories.id` **ON DELETE CASCADE** |
| `user_id` | UUID | NOT NULL, FK → `users.id` (who logged it) |
| `merchant` | VARCHAR(255) | optional |
| `description` | VARCHAR(255) | optional |
| `amount_cents` | BIGINT | NOT NULL |
| `transaction_date` | DATE | NOT NULL |

**`income_sources`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | UUID | PK |
| `user_id` | UUID | NOT NULL, FK → `users.id` (who earns it) |
| `budget_id` | UUID | NOT NULL, FK → `budgets.id` **ON DELETE CASCADE** |
| `name` | VARCHAR(100) | NOT NULL |
| `amount_cents` | BIGINT | NOT NULL. Expected amount per payment (0 for irregular income). |
| `frequency` | VARCHAR(20) | NOT NULL. `DAILY, WEEKLY, BIWEEKLY, SEMIMONTHLY, MONTHLY, IRREGULAR` |
| `auto_generate` | BOOLEAN | NOT NULL, default false. Stored, but **nothing acts on it yet**. |
| `next_pay_date` | DATE | optional |

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

Deleting a budget removes its members, categories, the categories' transactions, its income sources, and those sources' entries, all in one statement thanks to V8.

Foreign keys pointing at `users` have **no cascade**. There is no endpoint to delete a user yet; when one is added, it will need to decide what happens to budgets that user owns and transactions they logged.

### 6.4 Design decisions

- **Money is stored as `BIGINT` cents**, never floating point, so there are no rounding errors.
- **Derived values are never stored.** A budget's total and a category's remaining balance are calculated from the underlying rows every time they are requested, so they can never drift out of sync.
- **One income source has exactly one destination budget.** A paycheck split between two budgets is modeled as two income sources.
- **Creating a budget also creates the owner's `OWNER` membership row**, in the same database transaction.

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

### 7.2 `budget`

- **Entity** `Budget`: `id, title, ownerId, createdAt`.
- **Repository** `BudgetRepository`: `findByOwnerId(UUID)` (currently unused, since listing goes through memberships).
- **Service** `BudgetService`:
  - `createBudget(title, ownerId)`: `@Transactional`. Saves the budget, then saves a `BudgetMember` with role `OWNER` for the owner. If either insert fails, both roll back.
  - `listForUser(userId)`: finds every `BudgetMember` row for the user, collects the budget IDs, and calls `findAllById`. This returns **budgets the user is a member of**, including ones shared with them, not only ones they own.
  - `deleteBudget(budgetId)`: `budgetRepository.deleteById`. The database cascade removes everything under it. On Spring Data 3, deleting an ID that does not exist silently does nothing and still returns 200.
  - `getTotal(budgetId)`: see section 10.
  - `getRemainingBalance(budgetId)`: see section 10.
- **Controller** `BudgetController` at `/api/budgets`:
  - `POST /api/budgets` with `CreateBudgetRequest(title, ownerId)`. `title` is `@NotBlank`. `ownerId` has no `@NotNull`, so a missing owner reaches the database and returns 500.
  - `GET /api/budgets?userId=...`
  - `DELETE /api/budgets/{id}`
  - `GET /api/budgets/{id}/total`
  - `GET /api/budgets/{id}/remaining`
- **Response** `BudgetResponse`: `id, title, ownerId, createdAt`.

### 7.3 `budgetmembers`

- **Entity** `BudgetMember`: `id, budgetId, userId, role, createdAt`. The `Role` enum (`OWNER, EDITOR, VIEWER`) is nested inside the entity class, so other code refers to it as `BudgetMember.Role`.
- **Repository** `BudgetMemberRepository`: `findByUserId`, `findByBudgetId`, `findByBudgetIdAndUserId` (the last is currently unused; it is the natural tool for duplicate checks and permission checks later).
- **Service** `BudgetMemberService`:
  - `createBudgetMember(budgetId, userId, role)`: saves without checks. A duplicate (same budget and user) hits the UNIQUE constraint and returns 500. Any role can be assigned, including `OWNER`.
  - `listForBudget(budgetId)`: for each membership, looks up the `User` and builds a display name `"First Last"` (or `"Member"` if the user row is missing). Returns `BudgetMemberView` records.
  - `BudgetMemberView(id, budgetId, userId, name, role)` is a record nested inside the service. **Style cleanup planned:** fold it into a proper response DTO in its own file.
- **Controller** `BudgetMemberController` at `/api/budgetmembers`:
  - `POST /api/budgetmembers` with `CreateBudgetMemberRequest(budgetId, userId, role)`, all `@NotNull`.
  - `GET /api/budgetmembers/budget/{budgetId}` returns the views (with `name`).
- **Response** `BudgetMemberResponse`: `id, budgetId, userId, role` (no name; used for the POST response).

### 7.4 `category`

- **Entity** `Category`: `id, budgetId, name, categoryType, frequency, amountCents, createdAt`. Nested enums `CategoryType { RECURRING, GOAL }` and `Frequency { DAILY, WEEKLY, BIWEEKLY, MONTHLY, QUARTERLY, SEMIANNUALLY, YEARLY }`.
- **Repository** `CategoryRepository`: `findByBudgetId`.
- **Service** `CategoryService`:
  - `createCategory(budgetId, name, type, frequency, amountCents)`: saves without checks. Nothing enforces "frequency must be null for goals" or "frequency required for recurring".
  - `getRemainingAmount(categoryId)`: see section 10. A missing category throws a plain `RuntimeException` → 500 (should be 404).
  - `getCategoriesForBudget(budgetId)`.
- **Controller** `CategoryController` at `/api/categories`:
  - `POST /api/categories` with `CreateCategoryRequest(budgetId @NotNull, name @NotBlank, categoryType @NotNull, frequency, amountCents @Positive)`.
  - `GET /api/categories/budget/{budgetId}`
  - `GET /api/categories/{id}/remaining`
- **Response** `CategoryResponse`: `id, budgetId, name, categoryType, frequency, amountCents, createdAt`.

### 7.5 `transaction`

- **Entity** `Transaction`: `id, categoryId, userId, merchant, description, amountCents, transactionDate, createdAt`.
- **Repository** `TransactionRepository`: `findByCategoryId`, `findByUserId` (unused so far).
- **Service** `TransactionService`: `createTransaction(...)`, `getTransactionForCategory(categoryId)`.
- **Controller** `TransactionController` at `/api/transactions`:
  - `POST /api/transactions` with `CreateTransactionRequest(categoryId @NotNull, userId @NotNull, merchant, description, amountCents @Positive, transactionDate @NotNull)`.
  - `GET /api/transactions/category/{categoryId}`
- **Response** `TransactionResponse`: all entity fields.

Nothing checks that the user logging the transaction is a member of the category's budget.

### 7.6 `incomesource`

- **Entity** `IncomeSource`: `id, userId, budgetId, name, amountCents, frequency, autoGenerate, nextPayDate, createdAt`. Nested enum `Frequency { DAILY, WEEKLY, BIWEEKLY, SEMIMONTHLY, MONTHLY, IRREGULAR }` (different from the category frequency enum: it has `SEMIMONTHLY` and `IRREGULAR`, and no quarterly or yearly).
- **Repository** `IncomeSourceRepository`: `findByUserId` (unused), `findByBudgetId`.
- **Service** `IncomeSourceService`: `createIncomeSource(...)`, `listForBudget(budgetId)`.
- **Controller** `IncomeSourceController` at `/api/incomesources`:
  - `POST /api/incomesources` with `CreateIncomeSourceRequest(userId @NotNull, budgetId @NotNull, name @NotBlank, amountCents @Min(0), frequency @NotNull, autoGenerate, nextPayDate)`.
  - `GET /api/incomesources/budget/{budgetId}`. **Uses a Stream** (`.stream().map(...).toList()`), which goes against the plain loop convention.
- **Response** `IncomeSourceResponse`: all entity fields.

`autoGenerate` and `nextPayDate` are stored but no scheduler exists to create income entries automatically.

### 7.7 `incomeentry`

- **Entity** `IncomeEntry`: `id, incomeSourceId, amountCents, receivedDate, createdAt`.
- **Repository** `IncomeEntryRepository`: `findByIncomeSourceId`.
- **Service** `IncomeEntryService`: `createIncomeEntry(...)`, `listForSource(incomeSourceId)`.
- **Controller** `IncomeEntryController` at `/api/incomeentries`:
  - `POST /api/incomeentries` with `CreateIncomeEntryRequest(incomeSourceId @NotNull, amountCents @Positive, receivedDate @NotNull)`.
  - `GET /api/incomeentries/source/{incomeSourceId}`. **Also uses a Stream.**
- **Response** `IncomeEntryResponse`: all entity fields.

---

## 8. API reference

Base URL: `http://localhost:8080` (or wherever the container runs). All bodies are JSON with `Content-Type: application/json`.

| Method | Path | Body / params | Returns | Confirmed working |
| --- | --- | --- | --- | --- |
| POST | `/api/users` | `firstName, lastName, email, password, birthday?` | `UserResponse` | yes |
| POST | `/api/users/login` | `email, password` | `UserResponse` or 401/404 | |
| GET | `/api/users/by-email?email=` | query param | `UserResponse` or 404 | |
| POST | `/api/budgets` | `title, ownerId` | `BudgetResponse` | yes |
| GET | `/api/budgets?userId=` | query param | `BudgetResponse[]` | yes |
| DELETE | `/api/budgets/{id}` | | empty 200 | |
| GET | `/api/budgets/{id}/total` | | number (cents) | |
| GET | `/api/budgets/{id}/remaining` | | number (cents) | |
| POST | `/api/budgetmembers` | `budgetId, userId, role` | `BudgetMemberResponse` | |
| GET | `/api/budgetmembers/budget/{budgetId}` | | `[{id, budgetId, userId, name, role}]` | |
| POST | `/api/categories` | `budgetId, name, categoryType, frequency?, amountCents` | `CategoryResponse` | yes |
| GET | `/api/categories/budget/{budgetId}` | | `CategoryResponse[]` | |
| GET | `/api/categories/{id}/remaining` | | number (cents) | |
| POST | `/api/transactions` | `categoryId, userId, merchant?, description?, amountCents, transactionDate` | `TransactionResponse` | yes |
| GET | `/api/transactions/category/{categoryId}` | | `TransactionResponse[]` | |
| POST | `/api/incomesources` | `userId, budgetId, name, amountCents, frequency, autoGenerate, nextPayDate?` | `IncomeSourceResponse` | |
| GET | `/api/incomesources/budget/{budgetId}` | | `IncomeSourceResponse[]` | |
| POST | `/api/incomeentries` | `incomeSourceId, amountCents, receivedDate` | `IncomeEntryResponse` | |
| GET | `/api/incomeentries/source/{incomeSourceId}` | | `IncomeEntryResponse[]` | |

**Not implemented yet:** any `PUT`/`PATCH` (update) endpoint, and `DELETE` for everything except budgets.

### Example walkthrough with curl

Replace every `REAL_..._ID` with an actual UUID copied from the previous response. Pasting the placeholder text literally is a common slip.

```bash
# 1. Create a user, copy the "id" from the response
curl -s -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Ada","lastName":"Lovelace","email":"ada@example.com","password":"secret"}'

# 2. Create a budget owned by that user (also creates the OWNER membership)
curl -s -X POST http://localhost:8080/api/budgets \
  -H "Content-Type: application/json" \
  -d '{"title":"Household","ownerId":"REAL_USER_ID"}'

# 3. Add a $400/month grocery limit
curl -s -X POST http://localhost:8080/api/categories \
  -H "Content-Type: application/json" \
  -d '{"budgetId":"REAL_BUDGET_ID","name":"Groceries","categoryType":"RECURRING","frequency":"MONTHLY","amountCents":40000}'

# 4. Log a $42.50 purchase
curl -s -X POST http://localhost:8080/api/transactions \
  -H "Content-Type: application/json" \
  -d '{"categoryId":"REAL_CATEGORY_ID","userId":"REAL_USER_ID","merchant":"Kroger","amountCents":4250,"transactionDate":"2026-10-27"}'

# 5. Check what is left in the category (should print 35750)
curl -s http://localhost:8080/api/categories/REAL_CATEGORY_ID/remaining

# 6. Delete the budget (cascades to everything under it)
curl -i -X DELETE http://localhost:8080/api/budgets/REAL_BUDGET_ID
```

---

## 9. Derived values (totals and remaining)

All calculated on request in the service layer, using plain for loops.

**Category remaining** (`CategoryService.getRemainingAmount`):

```
remaining = category.amountCents − sum(all transactions in the category)
```

For a recurring limit, a positive number is money left and a negative number means over the limit. For a goal, it is how much is still needed.

**Budget total** (`BudgetService.getTotal`):

```
total = sum(amountCents of every category in the budget)
```

**Budget remaining** (`BudgetService.getRemainingBalance`):

```
remaining = sum(remaining of every category in the budget)
```

Limitations to be aware of:

- **Frequency is not used in any calculation yet.** A `MONTHLY` limit counts every transaction ever logged against it, not only this month's. Period based resets still need to be designed (likely by filtering transactions by `transaction_date` within the current period).
- **Goals and limits are mixed together** in the budget total and remaining, even though they mean different things.
- Income is not part of any backend calculation.
- `getRemainingBalance` runs one transaction query per category (fine at this size).

The Flutter client does its own calculations locally from the data it loads and does not call these three endpoints (see 11.4).

---

## 10. Frontend (Flutter)

### 10.1 What Flutter is, briefly

Flutter is Google's UI toolkit. You write the app once in **Dart**, and Flutter compiles it for each platform. Everything on screen is a **widget** (a class that describes part of the UI). A `StatelessWidget` just draws from its inputs. A `StatefulWidget` has a `State` object that can change and call `setState` to redraw.

### 10.2 Folder roles

- **`lib/`**: all of the app's real code. This is the only place you normally edit.
- **`pubspec.yaml`**: package name (`frontend_app`), version `1.0.0+1`, Dart SDK `^3.11.5`, and dependencies: `http` (network calls), `shared_preferences` (small key value storage on the device), `cupertino_icons`. Dev dependencies: `flutter_test`, `flutter_lints`.
- **`pubspec.lock`**: generated exact versions. Do not edit.
- **`test/widget_test.dart`**: two widget tests (see 11.9).
- **`web/`**: `index.html`, `manifest.json`, and icons for the web build. This is what the Docker image serves.
- **`android/`, `ios/`, `linux/`, `macos/`, `windows/`**: native shells generated by Flutter. Each is a small native app that starts the Flutter engine, which then runs the `lib/` code. You only touch these for platform settings: app name, icon, package ID, permissions. Files named `GeneratedPluginRegistrant`, anything under `ephemeral/`, and `flutter_export_environment.sh` are build output and should never be edited (and ideally should be in `.gitignore`).

### 10.3 Two modes: local only and remote

The app is controlled by one compile time setting in `api.dart`:

```dart
const apiBaseUrl = String.fromEnvironment('API_BASE', defaultValue: '');
```

- **Local only mode** (`API_BASE` empty, the default): no network calls at all. Everything lives in memory and is saved to the device with `shared_preferences`. This is how the widget tests run.
- **Remote mode** (`--dart-define=API_BASE=http://...`): adds go to the API, and the app reloads its data from the API after each one. A copy of the last loaded data is still cached on the device.

`Ledger` checks this with `bool get _remote => apiBaseUrl.isNotEmpty;`. Because it is a compile time constant, the mode is baked into each build; the Docker web build uses `http://localhost:8080`.

### 10.4 `lib/` file by file

**`main.dart`**: entry point.

- `main()` runs `BudgetApp`.
- `BudgetApp` creates **one `Ledger`** for the whole app and calls `ledger.load()` once. It sets the window title "Budget Buddy" and the theme.
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
| `deleteBudget` | Removes locally | **Removes locally only. No API call.** |
| `addMember` | Adds locally (name must be unique) | Looks up the user by email, then `POST /api/budgetmembers`. Email is required. |
| `removeMember` | Removes locally (not the owner) | **Local only** |
| `addCategory` | Inserts locally | `POST /api/categories` |
| `removeCategory` | Removes locally | **Local only** |
| `addExpense` | Inserts locally | `POST /api/transactions` |
| `removeExpense` | Removes locally | **Local only** |
| `addIncome` | Inserts locally | `POST /api/incomesources` |
| `updatePaycheck` | Edits locally | **Local only** |
| `logSideHustle` | Adds a payment locally | `POST /api/incomeentries` |
| `removePayment`, `removeIncome` | Remove locally | **Local only** |
| `expectedIncomeDuring(month)` | Sum of each source's expected income for that month | same |
| `spentDuring(month)` | Sum of recurring category spending for that month | same |

Private helpers:

- `_remoteAction(action)`: runs `action` (an API call) in the background without waiting. On success it calls `_refreshFromApi()` and `_touch()`. On failure it stores the message in `error` and notifies listeners. The UI does not wait for it.
- `_refreshFromApi()`: calls `_api.loadBudgets(account.id)` and `_api.loadIncome(budgets)` and **replaces** the `budgets` and `incomes` lists with brand new objects.
- `_touch()`: notifies listeners, then saves a JSON snapshot (account, signedIn, budgets, incomes) to `shared_preferences`. Saves are chained on `_tail` so they happen in order.
- `newId()`: makes a local ID from the current time plus random noise. Used for objects created on the device; the server replaces these with real UUIDs after a refresh.

**`api.dart`**: the HTTP client. `BudgetApi` wraps every backend call.

- Public methods: `createUser`, `login`, `createBudget`, `addMember`, `addCategory`, `addExpense`, `addIncome`, `logPayment`, `loadBudgets`, `loadIncome`.
- `loadBudgets(userId)` builds the full tree: `GET /api/budgets?userId=`, then for each budget `GET /api/budgetmembers/budget/{id}` and `GET /api/categories/budget/{id}`, then for each category `GET /api/transactions/category/{id}`.
- `loadIncome(budgets)`: for each budget `GET /api/incomesources/budget/{id}`, then for each source `GET /api/incomeentries/source/{id}`.
- That is **one request per budget, category, and income source**, run one after another. Fine for a household, slow at scale.
- `_userIdFor(name, email)` uses the public `by-email` endpoint. A 404 becomes "No account found for X. They need to sign up first."
- `_object(method, path, body)` handles single object requests. **It only supports `GET` and `POST`.** Anything else throws `Unsupported $method`.
- `_list(path)` handles list responses.
- `_check` turns any status 400 or higher into `ApiException('API $method $path failed ($status)')`.
- Conversion helpers: `_cents(dollars)` rounds `dollars * 100`; `_dollars(cents)` divides by 100; `_date(DateTime)` → `YYYY-MM-DD`; `_apiFrequency` and `_payFrequency` map between the client's three frequencies and the server's strings (unknown server values fall back to monthly); `_role` maps role strings (unknown falls back to viewer).
- `_account(body, password)` builds an `Account` from the server response **and attaches the password the user typed**, which then gets saved on the device.

**`models.dart`**: plain Dart data classes, each with `toJson()` and `fromJson()` for device storage.

| Class | Fields | Computed |
| --- | --- | --- |
| `Account` | `id?, firstName, lastName, email, password` | `displayName` |
| `Budget` | `id, name, members, categories` | `totalLimit` and `totalSpent` (recurring categories only), `spentDuring(month)` |
| `Member` | `name, role, id?, userId?, email?` | |
| `BudgetCategory` | `id, name, kind, frequency, target, expenses` | `current` (sum of all expenses), `remaining`, `isOver` (recurring only), `fraction` (for the progress bar, capped at 1.4) |
| `Expense` | `id, label, amount, date` | |
| `IncomeSource` | `id, budgetId, name, kind, frequency?, paycheckAmount, payments` | `totalLogged`, `expectedDuring(month)` |
| `IncomePayment` | `id, amount, date` | |

Enums: `BudgetRole { owner, editor, viewer }`, `CategoryKind { recurring, goal }`, `IncomeKind { paycheck, sideHustle }` (`isAutomatic` is true for paycheck), `PayFrequency { weekly, biweekly, monthly }`.

`monthlyEquivalent(frequency, amount)`: weekly × 52 / 12, biweekly × 26 / 12, monthly × 1. Used to show what a paycheck contributes in a typical month.

`IncomeSource.expectedDuring(month)`: for a paycheck, its monthly equivalent; for a side hustle, the sum of payments logged that month.

`Budget.fromJson` contains a small migration: an old saved format with loose `expenses` and no categories is converted into a single "Spending" category.

Money in the client is a `double` of dollars. The API layer converts to and from cents at the boundary.

**`screens/account_screen.dart`**: sign in or create account.

- If an account is already saved on the device (`ledger.account != null`), it shows **Sign in** (email and password). Otherwise it shows **Create account** (first name, last name, email, password; the password must be at least 4 characters).
- The subtitle changes depending on local or remote mode.
- Shows `ledger.error` in red. This is the **only screen that displays API errors**.

**`screens/overview_screen.dart`**: the "This month" tab.

- Header with the account name, month, and a **Sign out** button.
- Summary: **Income** (expected this month), **Spent** (recurring categories this month), **Left**.
- **Over the limit**: recurring categories whose total spending exceeds the limit.
- **Spending**: this month's expenses across all budgets, newest first.
- **Income**: every income source with its monthly figure.

**`screens/budgets_screen.dart`**: three screens.

- `BudgetsScreen` (tab): list of budgets with member chips and `spent / limit`. The **+** opens the create budget dialog. Tapping a budget opens its detail.
- `BudgetDetailScreen`: totals; **Categories** (add, tap to open, **×** to remove); **People** (add, **×** to remove anyone but the owner); **Income** for this budget. The trash icon in the app bar asks for confirmation, then calls `ledger.deleteBudget`. It listens to the ledger and **pops itself if its `Budget` object is no longer in `ledger.budgets`**.
- `CategoryScreen`: the category's progress and its expenses (add, **×** to remove). It also pops itself if its category or budget disappears.

**`screens/income_screen.dart`**:

- `IncomeScreen` (tab): every income source. **+** opens the income dialog (requires at least one budget).
- `IncomeRow`: one source. Tapping a paycheck opens the edit dialog (`updatePaycheck`). Tapping a side hustle opens `SideHustleScreen`. Side hustles get a **Log** button. Every row has **×** to remove. Also reused on the budget detail screen.
- `SideHustleScreen`: total brought in, this month's amount, and the list of logged payments (each removable).

**`dialogs.dart`**: every popup form. Each `show...Dialog` function returns the new object, or `null` if cancelled.

| Dialog | Collects | Notes |
| --- | --- | --- |
| `showCreateBudgetDialog` | name, extra members by name and role | Owner is added automatically. **In remote mode only the title is sent; extra members are dropped.** |
| `showAddMemberDialog` | name, email, role (editor or viewer) | Email is required in remote mode |
| `showCategoryDialog` | name, type, reset frequency (recurring only), amount | Amount must be greater than 0 |
| `showExpenseDialog` | label, amount, date | |
| `showIncomeDialog` | automatic or manual, name, budget, amount and frequency (automatic only) | Also used to edit a paycheck |
| `showLogIncomeDialog` | amount, date | For side hustles |

**`format.dart`**: `money(double)` → `$1,234.56`; `dateShort` → `Oct 27`; `monthYear` → `October 2026`; `sameMonth(a, b)`; `parseMoney(text)` strips `$` and commas and parses.

**`theme.dart`**: dark "space" look.

- `AppColors`: `paper` (near black background), `paperDim`, `bgGlow`, `ink` (main text), `inkFade` (secondary text), `hairline` (dividers), `moss` (green, good), `rust` (red, over or delete), `gold` (goals and editors).
- `buildTheme()`: Material 3 dark theme seeded from `moss`.
- `ledgerNumber()`: monospace text style with tabular figures for money.
- Reusable widgets: `SpaceBackground` (gradient plus a fixed random starfield), `SectionHeader` (title with optional **+**), `Hairline`, `RoleBadge`, `RowAction` (small icon button), `FillBar` (thin progress bar), `EmptyNote` (gray helper text).

### 10.5 How the UI redraws

1. A screen calls a `Ledger` method.
2. Local only mode: the ledger changes its lists and calls `_touch()`, which calls `notifyListeners()`.
3. Remote mode: the ledger fires the API call in the background. When it finishes, `_refreshFromApi()` replaces the lists and `_touch()` notifies.
4. Every screen that called `ledger.addListener(...)` runs its handler, which calls `setState`, and Flutter rebuilds that screen.

### 10.6 Accounts and passwords on the device

The account (including the **plain text password**) is saved in `shared_preferences` in both modes. On the web, this is the browser's local storage for the site. Signing out keeps the account and only flips `signedIn`. After the database is wiped (`docker compose down -v`), the app still has the old account and old IDs cached, so the browser's site data must be cleared.

### 10.7 Android, iOS, and desktop specifics

- The Android package ID is still the template's `com.example.frontend_app`, and the launcher label is `frontend_app`. Both are set in `android/app/build.gradle.kts` and `android/app/src/main/AndroidManifest.xml`.
- The main Android manifest does **not** declare the `INTERNET` permission. Debug builds get it from the debug manifest automatically, but a release build will not be able to reach the API until it is added.
- Android 9 and later block plain `http://` traffic by default, so release builds will need either HTTPS or a cleartext exception.
- iOS and macOS can only be built on a Mac.

### 10.8 Running Flutter without Android Studio

Eclipse has no maintained Flutter support. Flutter, the Android SDK command line tools, and the Android emulator all work from the terminal, and VSCodium with the Dart and Flutter extensions is an open source editor option for the Dart code.

### 10.9 Tests

`test/widget_test.dart` runs in local only mode with mocked `shared_preferences`:

1. **Expenses count toward a category limit**: create an account, create "Household", add a $100 "Groceries" category, log a $42.50 expense, add "Jordan" as a member, rebuild the app, and check everything was restored from device storage.
2. **A side hustle total updates when money is logged**: add a manual income source, log $80, check the total.

Run with `flutter test` from `src/frontend_app`. There are no tests for remote mode.

---

## 11. How the frontend maps to the backend

| Client concept | Server concept | Conversion |
| --- | --- | --- |
| `Account` | `User` | password is kept on the client |
| `Budget.name` | `Budget.title` | |
| `Member` | `BudgetMemberView` | `role` lowercased ↔ uppercased |
| `BudgetCategory` | `Category` | `kind` recurring/goal ↔ `categoryType` RECURRING/GOAL; `target` dollars ↔ `amountCents` |
| `PayFrequency` (3 values) | `Category.Frequency` (7 values) | weekly/biweekly/monthly only; other server values show as monthly. **Goals are sent with a frequency even though the server convention is null for goals.** |
| `Expense` | `Transaction` | `label` is sent as both `merchant` and `description`; read back from `merchant`, falling back to `description` |
| `IncomeSource` (paycheck) | `IncomeSource` with `autoGenerate: true` | `paycheckAmount` ↔ `amountCents`; `nextPayDate` is always set to today |
| `IncomeSource` (side hustle) | `IncomeSource` with `autoGenerate: false`, `frequency: IRREGULAR`, `amountCents: 0` | |
| `IncomePayment` | `IncomeEntry` | `date` ↔ `receivedDate` |
| `Budget.totalLimit`, `totalSpent`, `BudgetCategory.remaining` | `/total`, `/remaining` endpoints | client calculates its own; does not call the endpoints |

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

Because of stage 1, **nobody needs Flutter, Java, or Maven installed** to run the project. Docker is enough.

### 12.2 `docker-compose.yml`

- **`db`**: `postgres:16`, container `budget-db`. `POSTGRES_DB=budgetapp`, user and password from `.env`. Port `5432:5432` published (remove for production). Volume `db_data:/var/lib/postgresql/data`. Healthcheck runs `pg_isready` every 5 seconds, up to 10 retries.
- **`api`**: built from the `Dockerfile`, container `budget-api`. Waits for `db` to be **healthy** before starting. Gets `DB_USER`, `DB_PASSWORD`, and `SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/budgetapp`. Port `8080:8080`.

`.env` is required. Without it, the user and password are empty and Postgres will not start.

### 12.3 Target production setup

```
Internet → Cloudflare (DNS, protection) → Nginx Proxy Manager (homelab) → budget-api:8080 → budget-db
```

at `budget.spencerplus.com`, like the rest of the Spencer+ homelab.

Planned but not done:

- A GitHub Actions workflow that builds and pushes the image to GHCR or Docker Hub on `v*` tags.
- A release compose file that uses `image:` instead of `build:`, so self hosters only need the compose file and a `.env`.
- Removing the published `5432` port.
- Fixing `API_BASE` (see 15.3), which is currently baked in as `http://localhost:8080`.

---

## 13. Project conventions and rules

- **Layering:** Controller → Service → Repository. Controllers never touch repositories.
- **No Lombok.** Hand-written getters and setters.
- **Plain for loops** instead of Streams.
- **Never return entities** from controllers. Always a `Response` record.
- **Money as `long` cents.** UUID primary keys. Enums stored as strings.
- **Derived values are calculated, never stored.**
- **Never edit a Flyway migration that has already run.** Add the next version. Next is **V9**.
- **Secrets** come from env vars (`DB_USER`, `DB_PASSWORD`). `.env` is gitignored; `.env.example` is committed.
- **Minimal dependencies and tooling.** End users should only need `docker compose up`.
- **Open source, privacy first, self hosted.**
- Josh writes the backend code himself and prefers review that points out bugs over rewrites.

---

## 14. Known issues and gaps

### 14.1 Backend

- **No authentication or authorization.** All endpoints are open; login returns the user but no token. Roles are stored but never checked. Anyone can add anyone as `OWNER`. Plan: JWT (library already in the pom) plus role checks in the services.
- **`GET /api/users/by-email` leaks user details** to anyone. Remove or restrict once auth exists.
- **Duplicate member returns 500** (UNIQUE constraint). Should check `findByBudgetIdAndUserId` first and return 409.
- **Duplicate signup email returns 500.** Should return 409.
- **No global error handler** (`@ControllerAdvice`), so most failures surface as a generic 500.
- **`GET /api/categories/{id}/remaining` returns 500 for a missing category** (plain `RuntimeException`). Should be a 404 `ResponseStatusException`.
- **`CreateBudgetRequest.ownerId` has no `@NotNull`.**
- **No length validation** on names and titles, so a value over 100 characters fails at the database with 500.
- **No update endpoints at all, and delete only for budgets.**
- **`DELETE /api/budgets/{id}` returns 200 even if the budget does not exist.**
- **Frequency does not affect calculations**; limits never reset.
- **Budget total and remaining mix goals with limits.**
- **Category frequency rules not enforced** (goals can have one, recurring can be missing one).
- **No membership checks** when logging transactions or income.
- **Auto generated income is not implemented**: `autoGenerate` and `nextPayDate` are stored, nothing runs on a schedule.
- **No automated tests.** JUnit and Testcontainers are ready in the pom.
- **Style cleanup:** Streams in `IncomeSourceController` and `IncomeEntryController`; `BudgetMemberView` should become its own response DTO.

### 14.2 Frontend

- **Deleting does not reach the server.** Every remove method in `ledger.dart` (`deleteBudget`, `removeCategory`, `removeExpense`, `removeMember`, `removeIncome`, `removePayment`) only changes the local list. In remote mode the item disappears, then comes back on the next refresh. `api.dart` cannot send a `DELETE` at all (`_object` only handles `GET` and `POST`).
  - Fix for budgets: add a `'DELETE'` case to `_object` (`http.delete(uri, headers: headers)`), add `BudgetApi.deleteBudget(id)`, and give `Ledger.deleteBudget` an `if (_remote) { _remoteAction(() => _api.deleteBudget(budgetId)); return; }` branch like the add methods have.
  - The other removes need backend `DELETE` endpoints first. Until then, hide or disable those buttons in remote mode, or show an error.
- **Editing a paycheck does not reach the server** (`updatePaycheck` is local only) and is reverted on the next refresh.
- **Detail screens close themselves after any remote change.** `_refreshFromApi()` replaces every `Budget` and `BudgetCategory` with new objects. `BudgetDetailScreen` and `CategoryScreen` check `ledger.budgets.contains(budget)` by object identity, which is now false, so they pop. Comparing by `id` instead would fix it.
- **API errors are invisible outside the account screen.** `ledger.error` is only displayed on `AccountScreen`, so a failed add on any other screen fails silently.
- **No way to sign in to an existing server account on a new device.** `AccountScreen` only offers Sign in when an account is already saved on the device. On a fresh browser it only shows Create account, and creating with an existing email fails on the server.
- **The password is stored in plain text on the device**, and signing out does not remove it.
- **No re-authentication on launch**: if `signedIn` was saved as true, the app loads that user's data from the API using the cached ID.
- **Create budget dialog's extra members are dropped in remote mode**; only the title is sent.
- **Goals are sent with a frequency**; the client only knows weekly, biweekly, and monthly; `nextPayDate` is always today.
- **Many sequential requests** on every load and after every change (one per budget, category, and income source).
- **After a database wipe**, clear the browser's site data or the app keeps a stale account.
- **Android:** package ID is still `com.example.frontend_app`; no `INTERNET` permission in the main manifest; cleartext HTTP blocked on release builds.
- **No remote mode tests.**

### 14.3 Deployment

- **`API_BASE` is baked in as `http://localhost:8080`** in the Docker web build. A visitor opening `budget.spencerplus.com` would have their browser call `localhost:8080` on their own machine. Since the web app and API are served from the same origin, the web build should use a relative base (the page's own origin) instead. An empty value cannot be used for this because empty means local only mode, so this needs a small change in `api.dart`.
- **Port 5432 is published** to the host. Remove for production.
- **No published image or release compose file yet.**
- **`target/` and Flutter's generated `ephemeral/` files** are build output and should be gitignored if they are committed.

---

## 15. Roadmap

**Done**

- Full data model and migrations V1 to V8
- Create and list endpoints for every entity
- Budget delete with cascade (backend)
- Category remaining, budget total, budget remaining
- Docker Compose with a single container for web and API
- Flutter client merged (PR #1), plus the review fixes: cascade migration, transactional budget creation, shared budget listing, removal of auto-created "changeme" accounts

**Next**

1. Wire budget delete through the client; decide how other deletes behave until their endpoints exist.
2. Update and delete endpoints for categories, transactions, members, income sources, and income entries.
3. Error handling: `@ControllerAdvice`, 404 and 409 instead of 500.
4. Real authentication with JWT, and role checks (owner manages members, editor adds and changes, viewer reads only). Then remove or lock down `by-email`.
5. Period aware calculations using category frequency.
6. Auto generated income scheduler.
7. Tests: JUnit with Testcontainers for services and controllers; Flutter tests for remote mode.
8. Release: fix `API_BASE`, GitHub Actions image publishing, release compose file, remove port 5432, deploy behind Nginx Proxy Manager and Cloudflare.
9. Android build (package ID, permissions, HTTPS). iOS needs a Mac.
10. Choose the final app name.

**Idea, not started:** a separate investment or retirement account table with a stored balance.

---

## 16. Handy commands

```bash
# Docker
docker compose up -d --build          # rebuild and start everything
docker compose up -d db               # only Postgres (for running the API from Eclipse)
docker compose ps                     # container status
docker compose logs -f api            # follow the API log
docker compose down                   # stop, keep data
docker compose down -v                # stop and WIPE all data

# Postgres shell (use your DB_USER from .env)
docker exec -it budget-db psql -U budgetapp -d budgetapp
#   \dt                list tables
#   \d categories      describe a table
#   select version, description, success from flyway_schema_history order by installed_rank;
#   q                  leave the pager
#   \q                 exit psql

# Backend on the host
export DB_USER=budgetapp DB_PASSWORD=yourpassword
mvn spring-boot:run
mvn -DskipTests package               # build the jar into target/

# Flutter (from src/frontend_app)
flutter pub get                       # download Dart dependencies
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
flutter test                          # run widget tests
flutter doctor                        # check the toolchain
```