# Run Budget Buddy in a home lab

This guide puts Budget Buddy on a Linux server:

- **Database:** PostgreSQL 16, from `docker-compose.yml`
- **Backend:** the Spring Boot API, from the same Compose file
- **Frontend:** the Flutter app in `src/frontend_app`, on this server or on another device on your network, talking to that API

The server holds the data. Phones, a browser, or another computer are clients. You do not install Postgres or Java on the host. Docker builds the API and runs both containers.

Commands below are for a normal Linux shell. Run them from the repository root (the folder that contains `pom.xml` and `docker-compose.yml`).

## Start the server with one script

After Docker is installed (section 1) and this repo is on the server:

```bash
bash start-server.sh
```

That checks out `main`, updates it, downloads the Postgres image, builds the API image, starts both containers, and waits until Flyway has created the tables and the API answers on port 8080. It creates `.env` from `.env.example` when `.env` is missing. The Flutter app stays a separate step (section 5). The sections below are the same server steps, run by hand.

## What each important file does

| File | Role |
| --- | --- |
| `docker-compose.yml` | Starts Postgres (`budget-db`) and the API (`budget-api`) |
| `.env.example` | Sample database username and password. Copy this to `.env` |
| `Dockerfile` | Builds the API with Java 21 and Maven, then runs the jar |
| `pom.xml` | Maven build for the Spring Boot 3.3 / Java 21 API |
| `src/main/resources/application.yml` | API port `8080` and the Postgres connection |
| `src/main/resources/db/migration` | Flyway SQL files. They create the tables when the API starts |
| `src/frontend_app` | Flutter app (Linux, web, Android, and iOS from one codebase) |
| `src/frontend_app/lib/main.dart` | App entry point |
| `src/frontend_app/lib/api.dart` | Client calls to the API. Used when `API_BASE` is set |
| `windowsInstructions.md` | The same stack on a Windows PC, with the database still in Linux containers |
| `start-server.sh` | Downloads images, starts Postgres, applies migrations, and starts the API |

## 1. Install the tools

On the Linux server, install these once:

1. Git
2. Docker Engine and the Docker Compose plugin. On Debian or Ubuntu:

```bash
sudo apt update
sudo apt install -y git ca-certificates curl
```

Install Docker from the [Docker Engine instructions for your distro](https://docs.docker.com/engine/install/). After it is installed, your user should be able to run Docker without `sudo`:

```bash
sudo usermod -aG docker "$USER"
```

Log out and back in so the group change applies. `docker compose version` should print a version.

3. [Flutter SDK](https://docs.flutter.dev/install/manual) on any machine that will run the app (the server, or your own computer). Then:

```bash
flutter doctor
```

Chrome is enough to use the app in a browser. For a native Linux window, `flutter doctor` also needs the Linux desktop libraries (CMake, Ninja, Clang, GTK 3, and pkg-config). You do not need Java or Maven on the host. The `Dockerfile` builds the API inside Docker.

## 2. Get the code

```bash
git clone https://github.com/Jmspencer41/budget-app.git
cd budget-app
git checkout main
```

Clone already selects `main`. The checkout command keeps the server on that branch.

## 3. Create the env file

Docker Compose reads database credentials from `.env` in the repo root:

```bash
cp .env.example .env
```

`.env` looks like this:

```text
DB_USER=changeme
DB_PASSWORD=changeme
```

Change both values before anyone else on the network can reach the server. Those two values are the Postgres user and password, and the API uses the same pair. Do not commit `.env`. It is listed in `.gitignore`.

Inside Docker, the API connects to host `db` (the Postgres container), database `budgetapp`. A copy of the API run directly on the host uses `localhost:5432` instead (`src/main/resources/application.yml`).

## 4. Start the database and the API

From the repo root, either run `bash start-server.sh` or do it by hand:

```bash
docker compose up --build -d
```

The first build downloads the Postgres and Java images and compiles the API. Later starts are faster. `-d` leaves both containers running after you close the terminal. They stop on reboot, and the next `docker compose up -d` brings them back with the same data.

When it is ready:

- Postgres accepts connections
- Flyway applies migrations from `src/main/resources/db/migration`
- Spring Boot listens on port **8080**

Check the containers:

```bash
docker compose ps
```

`budget-db` and `budget-api` should be running. `budget-db` should be healthy.

Follow the API log if you want to watch startup:

```bash
docker compose logs -f api
```

### Confirm the API

```bash
curl -s -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Ada","lastName":"Lovelace","email":"ada@example.com","password":"secret"}'
```

A JSON body with an `id` and that name means the API wrote a user into Postgres. Sending the same email again fails, because email is unique.

Postgres is on port **5432** of the server, database **budgetapp**, with the user and password from `.env`. Confirm the row from the server:

```bash
docker exec budget-db psql -U changeme -d budgetapp -c "select email from users;"
```

Use the `DB_USER` from `.env` in place of `changeme` if you changed it.

### If the API container exits

```bash
docker compose logs api
```

Typical causes:

- Port **8080** or **5432** is already taken. Stop the other program, or change the left-hand port in `docker-compose.yml` (for example `"8081:8080"`). If you change the API port, use that port in `API_BASE` below.
- `.env` is missing, so `DB_USER` and `DB_PASSWORD` are empty and Postgres will not start.
- The Docker daemon is not running.

## 5. Run the Flutter app on the server

From the repo root:

```bash
cd src/frontend_app
flutter pub get
flutter devices
```

Point the app at the API with `API_BASE`. Without that flag the app keeps a copy on that device only, which is what the widget tests use.

**Browser:**

```bash
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

**Linux desktop** (after `flutter doctor` shows the Linux toolchain):

```bash
flutter run -d linux --dart-define=API_BASE=http://localhost:8080
```

The first compile can take a few minutes. The app opens on **Create account**. The account screen says budgets are stored on the home server. After you create an account you can:

- create a budget and add other people
- add a category as a recurring limit or a savings goal
- log expenses or contributions that count toward that category
- add automatic income (weekly, every two weeks, or monthly) or manual income you update by logging money

Those actions are saved in Postgres through the API. The `select email from users` command above should list the account you created.

In the `flutter run` terminal:

- `r` hot reloads
- `R` hot restarts
- `q` quits the app

Quitting the app leaves Postgres and the API running.

## 6. Use the app from another device on the network

Leave `docker compose` running on the server. Find the server's address on your LAN, for example `192.168.1.20`:

```bash
hostname -I
```

On the other computer, clone this repo, check out `main`, install Flutter, then start the app with that address:

```bash
cd src/frontend_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://192.168.1.20:8080
```

Replace `192.168.1.20` with the server address. Use the same flag for `linux`, `windows`, or a phone device Flutter lists. Every client with that `API_BASE` reads and writes the same Postgres database.

If the other device cannot connect, allow port 8080 through the server firewall from your LAN. On Ubuntu with UFW, that is:

```bash
sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp
```

Use your own subnet. Leave port 5432 closed to other machines. Clients talk to the API, and the API talks to Postgres on the Docker network.

The API currently allows requests without a login token. Keep it on your home network. Change the database password in `.env`, and do not forward ports 8080 or 5432 to the internet, until sign-in is required.

To serve the Flutter web app from the Linux host for browsers on the LAN:

```bash
cd src/frontend_app
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=7357 \
  --dart-define=API_BASE=http://192.168.1.20:8080
```

Open `http://192.168.1.20:7357` from another browser on the network. `API_BASE` must be an address that browser can reach, which is the server's LAN address, because the page runs in that browser.

## 7. Stop everything

Stop the Flutter app with `q` in its terminal.

On the server, from the repo root:

```bash
docker compose down
```

That stops the API and Postgres. The database files stay in the Docker volume `db_data`, so the next `docker compose up -d` keeps existing rows.

To delete the database data as well:

```bash
docker compose down -v
```

## Run the API on the host instead of in Docker

Use this only when you want to debug the API from an IDE. Postgres can stay in Docker.

Start only the database:

```bash
docker compose up -d db
```

In another terminal, from the repo root, match the credentials in `.env`. Maven does not read `.env` for you. Spring reads `DB_USER` and `DB_PASSWORD` from the environment.

```bash
export DB_USER=changeme
export DB_PASSWORD=changeme
mvn spring-boot:run
```

This path needs JDK 21 and Maven on your `PATH`. `mvn -version` should report Java 21. The API still listens on http://localhost:8080. Set `API_BASE` to that address when you start Flutter.
