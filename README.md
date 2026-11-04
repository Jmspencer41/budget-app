# Budget+

An open source, self hosted budgeting app for households. Run it on your own server, keep your financial data at home, and share budgets with the people you live with.
If you are interested in helping develop this project, please check [DEVELOPMENT.md](DEVELOPMENT.md) for instructions.

> **Name note:** the final name is still being decided. You may see "Budget Buddy" in the app itself.

## Features

* Shared budgets with roles: owner, editor, or viewer
* Categories as either a recurring spending limit or a savings goal
* Log expenses or contributions against a category
* Income sources that repeat (weekly, every two weeks, monthly, and more) or manual income you log by hand
* Budget totals and remaining amounts calculated for you
* One container serves both the web app and the API, with Postgres alongside it

## Project status

**Early development. Not ready for anything outside your own home network.**

* There is no login protection on the API yet. Anyone who can reach the server can read or change any budget.
* The bundled web app currently only works from a browser on the server itself (see [Known limitations](#known-limitations)).
* Prebuilt images on Docker Hub or GHCR are not published yet. For now you build from source.

Keep it on your LAN and do not forward its ports to the internet until authentication ships.

## Requirements

* A Linux server (any distro) with Docker Engine and the Docker Compose plugin
* About 1 GB of free RAM and a few GB of disk for the first build
* Git (only until prebuilt images are published)

Check Docker is ready:

```bash
docker compose version
```

## Install

### Option 1: Prebuilt image (coming soon)

Once images are published, installing will look like this. You will not need the source code.

```yaml
# docker-compose.yml
services:
  db:
    image: postgres:16
    container_name: budget-db
    environment:
      POSTGRES_DB: budgetapp
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d budgetapp"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  app:
    image: ghcr.io/jmspencer41/budget-app:latest   # final image name TBD
    container_name: budget-api
    depends_on:
      db:
        condition: service_healthy
    environment:
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      TZ: ${TZ}
      SPRING_DATASOURCE_URL: jdbc:postgresql://db:5432/budgetapp
    ports:
      - "8080:8080"
    restart: unless-stopped

volumes:
  db_data:
```

### Option 2: Build from source (works today)

```bash
git clone https://github.com/Jmspencer41/budget-app.git
cd budget-app
cp .env.example .env
nano .env                      # set your own values, see below
docker compose up -d --build
```

The first build takes several minutes because it compiles both the Flutter web app and the Java API. Later starts are quick.

## Configure

Everything lives in `.env` next to `docker-compose.yml`:

| Variable      | What it does                                   | Example            |
| ------------- | ---------------------------------------------- | ------------------ |
| `DB_USER`     | Postgres username, also used by the app        | `budget`           |
| `DB_PASSWORD` | Postgres password. **Change this.**            | a long random string |
| `TZ`          | Time zone for the app container                | `America/New_York` |

Generate a password with `openssl rand -base64 24` is recommended. 

## Use it

Open `http://localhost:8080` in a browser on the server, create an account, then create your first budget.

Check that both containers are healthy:

```bash
docker compose ps
```

## Update

Build from source:

```bash
git pull
docker compose up -d --build
```

Prebuilt image (once published):

```bash
docker compose pull
docker compose up -d
```

Database migrations run automatically when the app starts. Your data is kept in the `db_data` volume across updates.

## Back up and restore

Back up:

```bash
docker exec budget-db pg_dump -U "$DB_USER" -d budgetapp > budget-backup-$(date +%F).sql
```

Restore into a fresh install (stop the app first so it is not writing):

```bash
docker compose stop api
cat budget-backup-YYYY-MM-DD.sql | docker exec -i budget-db psql -U "$DB_USER" -d budgetapp
docker compose start api
```

Replace `$DB_USER` with the value from your `.env` if it is not set in your shell.

## Stop or remove

```bash
docker compose down        # stop, keep data
docker compose down -v     # stop and DELETE all data
```

## Reverse proxy

Running behind Nginx Proxy Manager, Traefik, or Caddy is the planned setup. Point the proxy at port `8080` of the server. This will be documented properly once authentication and the web app address fix (below) are done.

## Security checklist

* Change `DB_PASSWORD` before first start
* Remove the `5432:5432` port line from `docker-compose.yml`. Only the app needs to talk to Postgres, and it does that on the internal Docker network.
* Do not expose port 8080 to the internet yet
* Back up regularly

## Known limitations

* **No authentication or role checks.** Coming next.
* **Web app address is fixed to `localhost:8080`.** Browsers on other devices load the page but cannot reach the API. Fix is planned before the first release.
* No editing for most items yet (create and delete only)
* Automatic income is stored but not generated on a schedule yet
* Android and iOS builds are not published

## Contributing

See [DEVELOPMENT.md](DEVELOPMENT.md) for how to build, run, and test the project on Linux or on Windows with WSL.

## License

[AGPL-3.0](LICENSE)
