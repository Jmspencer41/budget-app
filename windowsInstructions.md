# Run Budget Buddy on Windows

This guide starts the three pieces of the project on a Windows machine:

- **Database:** PostgreSQL 16, a Linux container from `docker-compose.yml`
- **Backend:** the Spring Boot API, also a Linux container from `docker-compose.yml`
- **Frontend:** the Flutter app in `src/frontend_app`, running on Windows and talking to that API

Docker Desktop runs those containers in its WSL2 Linux VM. That matches a home lab: the server and the database stay on Linux, and this Windows PC is the client. You do not install Postgres on Windows or in Ubuntu.

Commands below are for **PowerShell**. Run them from the repository root (the folder that contains `pom.xml` and `docker-compose.yml`).

## Start all three with one script

After the tools in section 1 are installed and `.env` exists (section 3 creates it; the script creates it from `.env.example` if you skip that step):

```powershell
.\start.ps1
```

That builds and starts Postgres and the API in the WSL2 Linux VM, waits until the API answers on port 8080, then runs the Flutter app in Chrome against `http://localhost:8080`. For the Windows desktop app instead:

```powershell
.\start.ps1 -Device windows
```

If Windows refuses to run the script:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Quitting Flutter leaves the containers running. Stop them with `docker compose down`. The sections below are the same steps, run by hand.

## What each important file does

| File | Role |
| --- | --- |
| `docker-compose.yml` | Starts Postgres (`budget-db`) and the API (`budget-api`) |
| `.env.example` | Sample database username and password. Copy this to `.env` |
| `Dockerfile` | Builds the API with Java 21 and Maven, then runs the jar |
| `pom.xml` | Maven build for the Spring Boot 3.3 / Java 21 API |
| `src/main/resources/application.yml` | API port `8080` and the Postgres connection |
| `src/main/resources/db/migration` | Flyway SQL files. They create the tables when the API starts |
| `src/frontend_app` | Flutter app (Windows, web, Android, and iOS from one codebase) |
| `src/frontend_app/lib/main.dart` | App entry point |
| `src/frontend_app/pubspec.yaml` | Flutter package name and dependencies |
| `start.ps1` | Starts the database, API, and Flutter app in one step |

## 1. Install the tools

Install these once:

1. [Git for Windows](https://git-scm.com/download/win)
2. [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/), using the WSL2 engine. Leave it running. In Docker Desktop, confirm the engine is started before the commands below. `wsl -l -v` should list `docker-desktop` as Running. That distro is the Linux host for Postgres and the API.
3. [Flutter SDK](https://docs.flutter.dev/install/windows) for the frontend. After it is on your `PATH`, run:

```powershell
flutter doctor
```

`flutter doctor` should show Flutter and Chrome (or Windows desktop) as available. To run the native Windows app, also install [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) with the **Desktop development with C++** workload. Chrome alone is enough if you only want the app in a browser.

You do not need Java or Maven installed to run the API. The `Dockerfile` builds it inside Docker.

## 2. Get the code

```powershell
git clone https://github.com/Jmspencer41/budget-app.git
cd budget-app
```

The frontend work lives on the `philip` branch:

```powershell
git checkout philip
```

## 3. Create the env file

Docker Compose reads database credentials from a file named `.env` in the repo root. `.env.example` is the template:

```powershell
Copy-Item .env.example .env
```

Open `.env`. It looks like this:

```text
DB_USER=changeme
DB_PASSWORD=changeme
```

Those two values become the Postgres user and password, and the API uses the same pair. Change them if you want. Do not commit `.env`. It is listed in `.gitignore`.

`application.yml` points a locally run API at `localhost:5432` and database `budgetapp`. Inside Docker, `docker-compose.yml` overrides that host to `db`, which is the Postgres container.

## 4. Start the database and the API on Linux

From the repo root, with Docker Desktop running. Compose starts both containers inside the WSL2 Linux VM:

```powershell
docker compose up --build
```

The first build downloads Postgres and Maven images and compiles the API. Later starts are faster.

When it is ready you should see:

- Postgres accepting connections
- Flyway applying migrations from `src/main/resources/db/migration`
- Spring Boot listening on port **8080**

Leave this window open. It is the server log.

Check both containers in a second PowerShell window:

```powershell
docker compose ps
```

`budget-db` and `budget-api` should be running. `budget-db` should be healthy.

### Confirm the API

PowerShell's `curl` is an alias, so call `curl.exe`:

```powershell
curl.exe -X POST http://localhost:8080/api/users -H "Content-Type: application/json" -d "{\"firstName\":\"Ada\",\"lastName\":\"Lovelace\",\"email\":\"ada@example.com\",\"password\":\"secret\"}"
```

A JSON body with an `id` and the name you sent means the API wrote a user into Postgres. Sending the same email again fails, because email is unique.

Postgres is on **localhost:5432**, database **budgetapp**, with the user and password from `.env`.

### If the API container exits

```powershell
docker compose logs api
```

Typical causes:

- Port **8080** or **5432** is already taken. Stop the other program, or change the left-hand port in `docker-compose.yml` (for example `"8081:8080"`).
- `.env` is missing, so `DB_USER` and `DB_PASSWORD` are empty and Postgres will not start.
- Docker Desktop is not running.

## 5. Run the Flutter frontend

Open another PowerShell window. From the repo root:

```powershell
cd src/frontend_app
flutter pub get
```

See which devices Flutter can use:

```powershell
flutter devices
```

Point the app at the API with `API_BASE`. Without that flag the app keeps a local copy only, which is what the widget tests use.

**Browser** (no Visual Studio required):

```powershell
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

**Windows desktop** (needs the Visual Studio C++ workload):

```powershell
flutter run -d windows --dart-define=API_BASE=http://localhost:8080
```

The first compile can take a few minutes. The app opens on **Create account**. After you create an account you can:

- create a budget and add other people
- add a category as a recurring limit or a savings goal
- log expenses or contributions that count toward that category
- add automatic income (weekly, every two weeks, or monthly) or manual income you update by logging money

With `API_BASE` set, those actions are saved in Postgres through the API (`src/frontend_app/lib/api.dart`). The account screen says the budgets are stored on the home server. Confirm a row landed in Linux Postgres:

```powershell
docker exec budget-db psql -U changeme -d budgetapp -c "select email from users;"
```

Use the `DB_USER` from `.env` in place of `changeme` if you changed it. Omit `--dart-define` only when you want the on-device ledger and no API calls.

In the `flutter run` window:

- `r` hot reloads
- `R` hot restarts
- `q` quits the app

## 6. Stop everything

In the Flutter window, press `q`.

In the repo root:

```powershell
docker compose down
```

That stops the API and Postgres. The database files stay in the Docker volume `db_data`, so the next `docker compose up --build` keeps existing rows.

To delete the database data as well:

```powershell
docker compose down -v
```

## Run the API on the host instead of in Docker

Use this only if you want to debug the API from an IDE. Postgres can stay in Docker.

Start only the database:

```powershell
docker compose up db
```

In another window, from the repo root, match the credentials in `.env`. Maven does not read `.env` for you. Spring reads `DB_USER` and `DB_PASSWORD` from the environment (`src/main/resources/application.yml`).

```powershell
$env:DB_USER = "changeme"
$env:DB_PASSWORD = "changeme"
mvn spring-boot:run
```

This path needs JDK 21 and Maven on your `PATH`. `mvn -version` should report Java 21. The API still listens on http://localhost:8080.
