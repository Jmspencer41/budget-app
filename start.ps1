# Starts Postgres, the Spring API, and the Flutter client from the main branch.
# Postgres and the API run as Linux containers in Docker Desktop's WSL2 VM.
# Flutter runs on this PC and talks to http://localhost:8080.
#
# Usage, from the repo root:
#   .\start.ps1
#   .\start.ps1 -Device windows
#
# If Windows blocks the script:
#   powershell -ExecutionPolicy Bypass -File .\start.ps1

param(
    [string]$Device = "chrome"
)

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Test-NativeCommand {
    param([string]$Name)
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed (exit $LASTEXITCODE)."
    }
}

if (Test-Path (Join-Path $PSScriptRoot ".git")) {
    Write-Host "Updating the main branch..."
    git fetch origin
    Test-NativeCommand "git fetch"
    git checkout main
    Test-NativeCommand "git checkout main"
    git pull --ff-only origin main
    Test-NativeCommand "git pull"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker is not on PATH. Install Docker Desktop and start it, then run this script again."
}

docker info --format "{{.OSType}}" | Out-Null
Test-NativeCommand "docker info"

if (-not (Test-Path .env)) {
    if (-not (Test-Path .env.example)) {
        throw ".env is missing and .env.example was not found."
    }
    Copy-Item .env.example .env
    Write-Host "Created .env from .env.example"
}

Write-Host "Starting Postgres and the API in Docker..."
docker compose up --build -d
Test-NativeCommand "docker compose up"

Write-Host "Waiting for the API on http://localhost:8080 ..."
$ready = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    $code = & curl.exe -s -o NUL -w "%{http_code}" --max-time 2 http://localhost:8080/api/users
    if ($code -match "^[1-5][0-9][0-9]$") {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $ready) {
    Write-Host "The API did not respond. Recent logs:"
    docker compose logs api --tail 40
    throw "The API did not become ready. Check 'docker compose logs api'."
}

Write-Host "API is up. Starting the Flutter app on $Device ..."
Set-Location (Join-Path $PSScriptRoot "src\frontend_app")
flutter pub get
Test-NativeCommand "flutter pub get"

flutter run -d $Device --dart-define=API_BASE=http://localhost:8080
$flutterExit = $LASTEXITCODE

Write-Host ""
Write-Host "Flutter exited. Postgres and the API are still running."
Write-Host "Stop them from the repo root with: docker compose down"
if ($flutterExit -ne 0) {
    exit $flutterExit
}
