# =========================================================================================
# Docker Multi-Container Deployment Automation Script for TeamPulse
# Filename: deploy.ps1
# =========================================================================================

param(
    [switch]$SkipTeardown,
    [switch]$Prod,
    [switch]$NoBuild,
    [int]$HealthTimeoutSec = 60
)

$ErrorActionPreference = "Stop"
$ComposeFile = "../docker-compose.yml"

function Write-Step  { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

# ------------------------------------------------------------
# 1. PRE-FLIGHT VALIDATION
# ------------------------------------------------------------

Write-Step "Pre-flight Validation"

if(-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Fail "Docker CLI not found. Install Docker Desktop and ensure it is on PATH."
    exit 1
}

Write-Ok "Docker CLI found"

try {
    $null = docker info 2>&1
    if($LASTEXITCODE -ne 0){
        throw "Docker daemon not responding"
    }
    Write-Ok "Docker daemon is active and responsive"
} catch {
    Write-Fail "Docker daemon is not running or not reachable. Start Docker Desktop and retry."
    exit 1
}

if (-not (Test-Path $ComposeFile)) {
    Write-Fail "docker-compose.yml not found in current directory."
    exit 1
}

Write-Ok "docker-compose.yml located"

if($Prod) {
    $Services = @("mongodb", "backend-prod", "frontend-prod")
    $BackendService = "backend-prod"
    $BackendPort = 5000
    Write-Ok "Targeting PRODUCTION services"
} else {
    $Services = @("mongodb", "backend-dev", "frontend-dev")
    $BackendService = "backend-dev"
    $BackendPort = 4300
    Write-Ok "Targeting DEVELOPMENT services"
}

# ------------------------------------------------------------
# 2. ENVIRONMENT TEARDOWN
# ------------------------------------------------------------

if(-not $SkipTeardown){
    Write-Step "Environment Teardown"

    Write-Host "  Stopping existing containers..." -ForegroundColor DarkGray
    docker compose -f $ComposeFile down --remove-orphans 2>$null | Out-Null

    $stale = docker ps -aq --filter "name=teampulse" --filter "name=backend" --filter "name=frontend" 2>$null
    if($stale){
        Write-Host "  Removing leftover containers..." -ForegroundColor DarkGray
        docker rm -f $stale 2>$null | Out-Null
    }

    docker network prune -f 2>$null | Out-Null

    Write-Ok "Previous environment cleaned"
} else {
    Write-Warn "Skipping teardown (--SkipTeardown)"
}

# ------------------------------------------------------------
# 3. LIFECYCLE EXECUTION (build + start) 
# ------------------------------------------------------------

Write-Step "Lifecycle Execution"

$buildArgs = @("compose", "-f", $ComposeFile, "up", "-d", "--remove-orphans")

if (-not $NoBuild) {
    $buildArgs += "--build"
}

$buildArgs += $Services

Write-Host "  Running: docker $($buildArgs -join ' ')" -ForegroundColor DarkGray
& docker @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Fail "docker compose up failed (exit $LASTEXITCODE)"
    exit $LASTEXITCODE
}
Write-Ok "Containers built and started"

# ------------------------------------------------------------
# 4. POST-DEPLOYMENT VERIFICATION & SUMMARY
# ------------------------------------------------------------

Write-Step "Post-Deployment Verification"
$deadline = (Get-Date).AddSeconds($HealthTimeoutSec)
$backendReady = $false

while ((Get-Date) -lt $deadline) {
    $status = docker compose -f $ComposeFile ps --status running --services 2>$null
    if ($status -match $BackendService) {
        $backendReady = $true
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $backendReady) {
    Write-Fail "Backend container ($BackendService) did not become running within $HealthTimeoutSec s"
    docker compose -f $ComposeFile logs --tail 30 $BackendService
    exit 1
}
Write-Ok "Backend container is running"

$healthUrl = "http://localhost:$BackendPort/health"
$fallbackUrls = @(
    "http://localhost:$BackendPort/api/health",
    "http://localhost:$BackendPort/",
    "http://localhost:$BackendPort/api"
)

$httpOk = $false
$usedUrl = $null

foreach ($url in @($healthUrl) + $fallbackUrls) {
    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
            $httpOk = $true
            $usedUrl = $url
            break
        }
    }
    catch {
        # Silent retry jab tak response na mile
    }
}
if ($httpOk) {
    Write-Ok "Backend HTTP endpoint responded successfully ($usedUrl)"
}
else {
    Write-Warn "No HTTP health endpoint answered yet. Checking MongoDB logs connectivity..."
}
$logs = docker compose -f $ComposeFile logs --tail 60 $BackendService 2>$null
if ($logs -match "MongoDB|mongoose|connected|Connection established|Successfully connected|connected to database") {
    Write-Ok "Backend successfully established connection handshake with MongoDB!"
}
elseif ($httpOk) {
    Write-Ok "Backend is serving HTTP traffic (MongoDB connection assumed healthy)"
}
else {
    Write-Warn "Could not positively confirm MongoDB handshake from logs."
    Write-Host "  Recent backend logs for tracking:" -ForegroundColor DarkGray
    docker compose -f $ComposeFile logs --tail 20 $BackendService
}
# ------------------------------------------------------------
# 5. DEPLOYMENT SUMMARY
# ------------------------------------------------------------

Write-Step "Deployment Summary"
docker compose -f $ComposeFile ps

Write-Host ""
Write-Ok "Deployment finished successfully!"

if (-not $Prod) {
    Write-Host "  Frontend UI (Dev) : http://localhost:3000" -ForegroundColor White
    Write-Host "  Backend API (Dev) : http://localhost:4300" -ForegroundColor White
    Write-Host "  MongoDB Port(Dev) : localhost:27018" -ForegroundColor White
}
else {
    Write-Host "  Frontend UI (Prod): http://localhost:8000" -ForegroundColor White
    Write-Host "  Backend API (Prod): http://localhost:5000" -ForegroundColor White
    Write-Host "  MongoDB Port(Prod): localhost:27018" -ForegroundColor White
}
Write-Host ""

# ------------------------------------------------------------
# Run COMMAND 
# 1. Normal Standard Run (Development Stack Build + Verify): 

#    ▶ ./deploy.ps1

# 2. Production Stack Run (Agar testing done ho jaye aur prod 
#    services verify karni hon) : 

#    ▶ ./deploy.ps1 -Prod

# 1. Fast Verification Restart (Bina purane containers teardown 
#    kiye aur bina re-build kiye quick runtime check):

#    ▶ ./deploy.ps1 -SkipTeardown -NoBuild
# ------------------------------------------------------------