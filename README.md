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


## License

AGPL-3.0