#!/usr/bin/env bash
# Download and start the Budget Buddy home-lab server from the main branch:
# Postgres, Flyway migrations, and the Spring Boot API.
#
# From the repo root, after Docker is installed:
#   bash start-server.sh
#
# The Flutter app is a separate client. Point it at this server with
# --dart-define=API_BASE=http://<this-server>:8080

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ -d .git ]]; then
  echo "Updating the main branch..."
  git fetch origin
  git checkout main
  git pull --ff-only origin main
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Install Docker Engine, then run this script again." >&2
  echo "https://docs.docker.com/engine/install/" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed, but this user cannot reach the daemon." >&2
  echo "Start Docker, and add your user to the docker group if the command needs sudo." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "The Docker Compose plugin is missing. Install docker-compose-plugin, then run this script again." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  if [[ ! -f .env.example ]]; then
    echo ".env is missing and .env.example was not found." >&2
    exit 1
  fi
  cp .env.example .env
  echo "Created .env from .env.example."
  echo "Change DB_USER and DB_PASSWORD in .env before other people can reach this server."
fi

env_value() {
  local key="$1"
  local line
  line="$(grep -E "^${key}=" .env | head -n 1 || true)"
  line="${line#*=}"
  line="${line//$'\r'/}"
  printf '%s' "$line"
}

DB_USER="$(env_value DB_USER)"
DB_PASSWORD="$(env_value DB_PASSWORD)"

if [[ -z "$DB_USER" || -z "$DB_PASSWORD" ]]; then
  echo ".env must set DB_USER and DB_PASSWORD." >&2
  exit 1
fi

echo "Downloading the Postgres image and building the API..."
docker compose pull db
docker compose up --build -d

echo "Waiting for Postgres, Flyway, and the API..."
ready=0
for _ in $(seq 1 90); do
  code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:8080/api/users || true)"
  if [[ "$code" =~ ^[1-5][0-9][0-9]$ ]]; then
    ready=1
    break
  fi
  sleep 2
done

if [[ "$ready" -ne 1 ]]; then
  echo "The API did not answer on port 8080. Recent logs:" >&2
  docker compose logs api --tail 40 || true
  exit 1
fi

echo
echo "API is listening on http://localhost:8080"
echo "Postgres is on localhost:5432, database budgetapp, user ${DB_USER}."
echo
echo "Applied migrations:"
docker exec budget-db psql -U "$DB_USER" -d budgetapp \
  -c "select version, description, success from flyway_schema_history order by installed_rank;"

echo
echo "Containers:"
docker compose ps
echo
echo "Leave these running. Stop them with: docker compose down"
echo "Start a client with: flutter run -d chrome --dart-define=API_BASE=http://localhost:8080"
