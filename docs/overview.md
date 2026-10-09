# Budgeting Application
 
## Overview
 
This project is an open source budgeting application that allows users to
create budgets and share them with other users. A household, for example,
can maintain one shared budget with multiple members, each with their own
role (owner, editor, or viewer), while still tracking individual income and
spending underneath that shared budget.
 
The application is self-hosted. It is built to run in Docker containers,
deployed with Docker Compose, and reverse proxied through Nginx Proxy
Manager behind Cloudflare, The initial deployment will be available at
`budget.spencerplus.com`.
 
## Goals
 
- Support shared budgets between multiple users, with per-user roles
- Support user-defined categories within a budget, either as recurring
  spending limits (weekly, biweekly, monthly, etc.) or as long-term savings
  goals
- Support tracking of income sources and individual income entries,
  including manually logged and automatically generated recurring income
- Support logging of transactions (purchases) against categories, with the
  remaining balance in a category calculated from its transactions
- Ship as a self-hostable, open source application others can deploy with
  their own Docker Compose file
- Provide a single API-driven backend that powers a web app, an Android
  app, and an iOS app
Target: a working version 1.0 by the end of the semester, published both on
Docker Hub and as source on GitHub.
 
## Architecture
 
The backend does not follow a traditional Model-View-Controller structure
in the classic web-application sense, since it is not rendering HTML
templates. Instead, it follows an API-first architecture, where the
"View" is replaced by JSON responses consumed by separate client
applications (web, Android, iOS). The rest of the pattern maps closely:
 
- **Model** — the entity classes (e.g. `User`, `Budget`, `Category`,
  `Transaction`) that represent the application's data and map directly to
  database tables
- **Controller** — the REST controllers that receive HTTP requests, hand
  them off to the appropriate business logic, and return a response
- **View** — in place of rendered pages, the API returns structured JSON.
  Each significant entity has a corresponding Response object that shapes
  exactly what is returned to a client, so internal-only or sensitive
  fields (such as a password hash) are never exposed
Between the Controller and the Model sits a **Service** layer, which holds
the application's actual business logic (creating records, calculating
values such as a category's remaining balance, and eventually enforcing
permissions), and a **Repository** layer, which handles all direct
communication with the database. Every feature in the backend follows the
same five-part structure:
 
1. A Flyway migration file, which creates the database table
2. An Entity class, which maps that table to a Java object
3. A Repository interface, which provides save/find/delete operations
4. A Service class, which contains the business logic for that feature
5. A Controller class, which exposes the feature as REST endpoints
This structure is repeated consistently across every feature in the
application, including `User`, `Budget`, `BudgetMember`, `Category`,
`Transaction`, `IncomeSource`, and `IncomeEntry`.
 
## Backend Technology Stack
 
- **Language:** Java 21
- **Framework:** Spring Boot 3
- **Build tool:** Maven
- **Database:** PostgreSQL
- **Schema migrations:** Flyway
- **Security:** Spring Security (password hashing via BCrypt; full
  authentication/authorization still in progress)
- **Containerization:** Docker, deployed via Docker Compose
## Core Domain Model
 
- **User** — an individual account, with authentication credentials
- **Budget** — a shareable container for financial planning; owned by a
  user and shared with others through `BudgetMember`
- **BudgetMember** — a join table linking users to budgets, with a role of
  `OWNER`, `EDITOR`, or `VIEWER`
- **Category** — a spending limit or savings goal that belongs to a
  budget; either `RECURRING` (with a frequency such as weekly, biweekly, or
  monthly) or a `GOAL` (a fixed target with no reset period)
- **Transaction** — a purchase or expense logged against a category and a
  user; used to calculate a category's remaining balance
- **IncomeSource** — a defined source of income (an employer, a side job,
  etc.) tied to a user and a destination budget, either logged manually or
  set to auto-generate recurring entries
- **IncomeEntry** — an individual instance of income received from an
  income source
Money values throughout the schema are stored as integer cents rather than
floating-point numbers, to avoid rounding errors in financial calculations.
Derived values, such as a category's remaining balance or a budget's total,
are calculated on demand from underlying records rather than stored
directly, so there is no risk of a stored value drifting out of sync with
the transactions that determine it.
 
## Deployment
 
The application is designed to run as a small number of Docker containers
behind a reverse proxy:
 
- **App container** — the compiled Spring Boot application, serving the
  REST API
- **Database container** — PostgreSQL, with its data stored in a named
  Docker volume so it persists independently of the application container
Docker Compose is used to run these containers together in development and
in production. Nginx Proxy Manager handles the reverse proxy, routing
`budget.spencerplus.com` to the app container, with Cloudflare providing
DNS and network-level protection
 
Once a stable release is ready, the application image will be published to
a public container registry so that other users can self-host it with
their own Docker Compose file and a small set of environment variables,
without needing to build the project from source themselves. The project's
source code will also remain available and open source on GitHub.
 
## Frontend
 
The frontend is being built using Dart and Flutter, which allows a single
codebase to target a web app, an Android app, and an iOS app. The frontend
communicates with the backend exclusively through the REST API described
above, using standard HTTP requests with JSON request and response bodies.
No frontend code has direct access to the database; all reads and writes
go through the API.
 
## Status
 
Core backend data model and create operations are implemented for all major
entities. Read endpoints and derived calculations (such as category and
budget remaining balances) are in progress. Authentication is currently
open for development purposes and will be replaced with token-based
authentication before release.

The Flutter client covers the first household workflow: create a budget,
add people, log expenses that count toward the budget, and track income
as a repeating paycheck or a side hustle updated by hand. That ledger is
stored on the device until the API can serve it from Postgres.
 
