# Developing Budget+

This guide is for people working on the code. If you just want to run the app, see [README.md](README.md).

* [Stack and layout](#stack-and-layout)
* [Code conventions](#code-conventions)
* [Linux](#linux)
* [Windows with WSL](#windows-with-wsl)
* [Everyday tasks (both platforms)](#everyday-tasks-both-platforms)
* [Known issues and roadmap](#known-issues-and-roadmap)

---

## Stack and layout

| Part      | Tech                                                        |
| --------- | ----------------------------------------------------------- |
| Backend   | Java 21, Spring Boot 3.3, Maven                             |
| Database  | PostgreSQL 16, Flyway migrations, JPA with `ddl-auto: validate` |
| Frontend  | Flutter (web, Android, iOS from one codebase)               |
| Packaging | Docker multi stage build, Docker Compose                    |

| Path                                   | What it is                                                        |
| -------------------------------------- | ----------------------------------------------------------------- |
| `src/main/java/com/spencerplus/budget` | API code. One package per feature (`user`, `budget`, `category`, ...) |
| `src/main/resources/application.yml`   | API config. Reads `DB_USER` and `DB_PASSWORD` from the environment |
| `src/main/resources/db/migration`      | Flyway SQL files (`V1__...sql` to `V8__...sql`)                   |
| `src/frontend_app`                     | Flutter client. `lib/api.dart` holds all HTTP calls               |
| `Dockerfile`                           | Stage 1 builds Flutter web, stage 2 builds the jar with the web build in `static/`, stage 3 is the JRE runtime |
| `docker-compose.yml`                   | `db` (Postgres) and `api` (the app)                               |
| `.env.example`                         | Template for `.env` (`DB_USER`, `DB_PASSWORD`, `TZ`)              |

When the full stack runs in Docker, `http://localhost:8080` serves both the web UI and the API under `/api/...`.

---

## Code conventions

* **Layering:** Controller calls Service, Service calls Repository. A Controller never touches a Repository.
* **Feature pattern:** migration, Entity, Repository, Service, Controller, plus a `CreateXRequest` record and an `XResponse` record. Never return an Entity from a controller.
* **No Lombok.** Write getters and setters by hand.
* **Plain `for` loops** instead of Streams.
* **Money is `long` cents.** Primary keys are UUIDs. Enums are stored as strings.
* **Derived values** (budget total, category remaining) are calculated on request, never stored.
* **Never edit a migration that has already run.** Add a new one. The next is `V9__description.sql`.
* Keep dependencies minimal. End users should only ever need `docker compose up`.

---

## Linux

Tested on Fedora. Ubuntu and Debian commands are shown too.

### 1. Install tools

| Tool                    | Needed for                                        |
| ----------------------- | ------------------------------------------------- |
| Git                     | Always                                            |
| Docker Engine + Compose | Always (database, full stack, Testcontainers)     |
| JDK 21 + Maven          | Running or debugging the API outside Docker, running tests |
| Flutter SDK             | Only if you work on the frontend with hot reload  |

Fedora:

```bash
sudo dnf install git java-21-openjdk-devel maven
```

Ubuntu or Debian:

```bash
sudo apt update
sudo apt install git openjdk-21-jdk maven
```

Docker: follow the [Docker Engine install guide](https://docs.docker.com/engine/install/) for your distro, then let your user run it without `sudo`:

```bash
sudo usermod -aG docker "$USER"     # add yourself to the docker group
# log out and back in
docker compose version              # confirm it works
```

Flutter (optional): follow the [Flutter Linux install guide](https://docs.flutter.dev/get-started/install/linux), then run `flutter doctor`.

Check Java:

```bash
java -version    # should say 21
mvn -version     # should also report Java 21
```

### 2. Clone and configure

```bash
git clone git@github.com:Jmspencer41/budget-app.git   # or the https URL
cd budget-app
cp .env.example .env      # local dev can keep the default values
```

### 3. Run it

Pick the mode that fits what you are working on. Commands for all three are in [Everyday tasks](#everyday-tasks-both-platforms).

| Mode                     | When to use it                                    |
| ------------------------ | ------------------------------------------------- |
| **A. Full stack in Docker** | Trying the app end to end, checking a release build |
| **B. API from your IDE**    | Backend work. Fast restarts, breakpoints          |
| **C. Flutter with hot reload** | Frontend work                                  |

#### A. Full stack in Docker

```bash
docker compose up -d --build      # build both images and start in the background
docker compose logs -f api        # watch startup; Ctrl+C stops watching, not the app
```

Open http://localhost:8080.

#### B. API from your IDE or Maven

Run only Postgres in Docker:

```bash
docker compose up -d db
```

Then start the API on your machine. Maven does not read `.env`, so export the values first:

```bash
set -a; source .env; set +a      # load every line of .env into this shell
mvn spring-boot:run
```

In Eclipse or IntelliJ, run `BudgetApplication` and add `DB_USER` and `DB_PASSWORD` to the run configuration's environment.

If the `api` container is also running, stop it first so port 8080 is free: `docker compose stop api`.

#### C. Flutter with hot reload

Start the backend with mode A or B, then:

```bash
cd src/frontend_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

In the `flutter run` terminal: `r` hot reload, `R` hot restart, `q` quit.

Leaving out `--dart-define=API_BASE=...` puts the app in device only mode. Nothing is sent to the API.

---

## Windows with WSL

On Windows, do all development inside WSL (Ubuntu). You get the same commands as Linux, and Docker runs natively.

### 1. Install WSL and Ubuntu

In PowerShell **as Administrator**:

```powershell
wsl --install -d Ubuntu      # installs WSL2 and Ubuntu
```

Reboot, open **Ubuntu** from the Start menu, and create your Linux user.

### 2. Install Docker

Choose one:

* **Docker Desktop (easier):** install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/). In *Settings > Resources > WSL integration*, turn on your Ubuntu distro. `docker` then works inside Ubuntu.
* **Docker Engine inside WSL (lighter, no Desktop license questions):** follow the Ubuntu steps from the [Docker Engine install guide](https://docs.docker.com/engine/install/ubuntu/) inside the Ubuntu terminal. Recent WSL has systemd on by default, so the Docker service starts normally.

Check from the Ubuntu terminal:

```bash
docker compose version
```

### 3. Install the rest inside Ubuntu

```bash
sudo apt update
sudo apt install git openjdk-21-jdk maven
```

Flutter (optional): install it inside Ubuntu with the [Flutter Linux install guide](https://docs.flutter.dev/get-started/install/linux). For the Windows desktop target only, install Flutter on Windows instead.

### 4. Clone into the Linux file system

Clone into your Ubuntu home folder, **not** under `/mnt/c/...`. Builds on the Windows drive are many times slower and file watching breaks.

```bash
cd ~
git config --global core.autocrlf input    # keep LF line endings so scripts and SQL stay clean
git clone git@github.com:Jmspencer41/budget-app.git
cd budget-app
cp .env.example .env
```

You can open the folder from Windows Explorer at `\\wsl$\Ubuntu\home\<your-linux-user>\budget-app`.

### 5. Editor

* **VS Code:** install the *WSL* extension, then run `code .` from the repo folder in Ubuntu.
* **IntelliJ IDEA:** open the project from the `\\wsl$\...` path; IntelliJ detects WSL and uses the JDK inside it.

### 6. Run it

Every command in the Linux section works unchanged in the Ubuntu terminal. WSL forwards `localhost`, so open http://localhost:8080 in your normal Windows browser.

Flutter web from inside WSL has no Chrome to launch, so serve it and open it from Windows:

```bash
cd src/frontend_app
flutter pub get
flutter run -d web-server --web-port 5000 --dart-define=API_BASE=http://localhost:8080
```

Then browse to http://localhost:5000 in Windows. Press `r` in the terminal to hot reload, then refresh the browser.

### Windows troubleshooting

| Problem                                    | Fix                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------- |
| `docker: command not found` in Ubuntu       | Turn on WSL integration in Docker Desktop, or install Docker Engine in WSL |
| Port 8080 or 5432 already in use            | Something on Windows is using it. Stop it, or change the left port in `docker-compose.yml` (`"8081:8080"`) |
| Very slow builds                            | Repo is under `/mnt/c`. Move it to `~`                               |
| `bad interpreter: /bin/bash^M`              | CRLF line endings. Set `core.autocrlf input` and reclone            |

---

## Everyday tasks (both platforms)

All commands run from the repo root unless noted.

### Start, stop, rebuild

```bash
docker compose up -d --build     # rebuild after code changes and restart
docker compose ps                # what's running and healthy
docker compose logs -f api       # follow the API log
docker compose stop              # stop, keep containers and data
docker compose down              # remove containers, keep data
docker compose down -v           # remove containers AND wipe the database
```

After `down -v`, clear the site data for `localhost:8080` in your browser, or the app keeps a stale saved account.

### Get the latest code

```bash
git checkout main
git pull
docker compose up -d --build
```

### Work on a branch

```bash
git checkout -b feature/short-name     # new branch from main
# ...edit, then:
git add -A
git commit -m "Short description of the change"
git push -u origin feature/short-name  # then open a pull request on GitHub
```

### Test

Backend (JUnit and Testcontainers are in the pom; Docker must be running for Testcontainers):

```bash
mvn test
```

Frontend:

```bash
cd src/frontend_app
flutter test
```

Quick API smoke test:

```bash
curl -s -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Ada","lastName":"Lovelace","email":"ada@example.com","password":"secret"}'
```

A JSON body with an `id` means the API wrote to Postgres. Copy real IDs from responses into later requests. Do not paste placeholders like `<user-id>` literally.

### Look at the database

```bash
docker exec -it budget-db psql -U changeme -d budgetapp   # use your DB_USER
```

Useful inside psql:

```sql
\dt                                    -- list tables
select * from flyway_schema_history;   -- which migrations ran
select email from users;
```

Press `q` to leave the pager and `\q` to exit.

### Add a database change

1. Create `src/main/resources/db/migration/V9__what_it_does.sql` (two underscores).
2. Update the Entity to match, since Hibernate validates the schema on startup.
3. Rebuild: `docker compose up -d --build`.

If Flyway reports a checksum mismatch, an applied migration was edited. Revert the edit and put the change in a new migration instead. On a throwaway local database you can also wipe with `docker compose down -v`.

### API reference

| Area         | Endpoints |
| ------------ | --------- |
| Users        | `POST /api/users`, `POST /api/users/login`, `GET /api/users/by-email?email=` |
| Budgets      | `POST /api/budgets`, `GET /api/budgets?userId=`, `DELETE /api/budgets/{id}`, `GET /api/budgets/{id}/total`, `GET /api/budgets/{id}/remaining` |
| Members      | `POST /api/budgetmembers`, `GET /api/budgetmembers/budget/{budgetId}` |
| Categories   | `POST /api/categories`, `GET /api/categories/budget/{budgetId}`, `GET /api/categories/{id}/remaining` |
| Transactions | `POST /api/transactions`, `GET /api/transactions/category/{categoryId}` |
| Income       | `POST /api/incomesources`, `GET /api/incomesources/budget/{budgetId}`, `POST /api/incomeentries`, `GET /api/incomeentries/source/{incomeSourceId}` |

---

## Known issues and roadmap

### Known issues

**Backend**

* No authentication or role checks. All endpoints are `permitAll()`; anyone can add anyone as `OWNER`.
* `GET /api/users/by-email` exposes user details.
* Duplicate member or duplicate signup email returns 500 instead of 409.
* No global error handler (`@ControllerAdvice`).
* No update (`PUT`/`PATCH`) endpoints.
* Category frequency does not affect calculations yet.
* Auto generated income is stored but nothing runs it.
* No automated tests yet.
* Style cleanup: Streams in some controllers, `BudgetMemberView` should become its own response DTO.

**Frontend**

* Sign in on a fresh device is not supported; password is stored on the device.
* API errors are only shown on the account screen.
* Android package is still `com.example.frontend_app`.

**Deployment**

* `API_BASE` is baked in as `http://localhost:8080` in the Docker web build. Since the UI and API share an origin, the web build should call the page's own origin.
* Port 5432 is published to the host.
* No published image or release compose file.

### Roadmap

1. Update endpoints, then wire edits through the client
2. Error handling: `@ControllerAdvice`, proper 404 and 409
3. JWT authentication and role checks; lock down `by-email`
4. Sign in to an existing account from a new device
5. Period aware calculations using category frequency
6. Auto generated income scheduler
7. Tests: JUnit with Testcontainers; Flutter remote mode tests
8. Release: fix `API_BASE`, GitHub Actions publishing to GHCR on `v*` tags, release compose file, remove port 5432
9. Android build; iOS needs a Mac
10. Pick the final app name

Stretch goals: charts and analytics, receipt uploads, investment and retirement accounts.
