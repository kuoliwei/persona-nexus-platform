# One-shot bootstrap for a fresh machine. Idempotent: safe to re-run,
# skips whatever already exists instead of erroring or overwriting it.
#
# What it does, in order:
#   1. Check prerequisites (git, node/npm, conda, docker, ollama on PATH)
#   2. Clone the 11 sub-repos listed in MICROSERVICES.md
#   3. Generate .env files for the 5 backend services (JWT_SECRET shared
#      between auth-service and api-gateway)
#   4. npm install across the 9 JS projects, including the npm install-script
#      approval step that prisma/bcrypt need (npm blocks these by default)
#   5. prisma migrate deploy + generate for user/character/chat-service
#   6. Create the ai-service conda env and pip install requirements.txt
#   7. Print what still needs manual attention
#
# What this does NOT do (deliberately, see 佈署便利性改進清單.md):
#   - Install Docker/Ollama/WSL2/Node.js themselves - those are one-time,
#     higher-privilege installs a human should drive.
#   - Pull an Ollama model - that's a multi-GB download and a model choice,
#     not something to do silently as a side effect of "setup".

$root = $PSScriptRoot

function Write-Step { param($msg) Write-Host "`n== $msg ==" -ForegroundColor Cyan }
function Write-Ok { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  [SKIP] $msg" -ForegroundColor DarkGray }
function Write-Warn2 { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }

function Write-Utf8NoBom {
    param($Path, $Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
# 1. Prerequisite check
# ---------------------------------------------------------------------------
Write-Step "Checking prerequisites"

$missing = @()
foreach ($tool in @('git', 'node', 'npm', 'conda', 'docker', 'ollama')) {
    $found = Get-Command $tool -ErrorAction SilentlyContinue
    if ($found) {
        Write-Ok "$tool -> $($found.Source)"
    } else {
        Write-Warn2 "$tool not found on PATH"
        $missing += $tool
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Install these first (winget install --id <pkg> works for Node.js/Docker/Ollama)," -ForegroundColor Red
    Write-Host "then open a new terminal (so PATH picks up the install) and re-run this script." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Clone the 11 sub-repos (see MICROSERVICES.md)
# ---------------------------------------------------------------------------
Write-Step "Cloning sub-repositories"

$repos = @(
    'auth-service', 'user-service', 'character-service', 'chat-service', 'ai-service', 'api-gateway',
    'persona-nexus-auth', 'persona-nexus-character', 'persona-nexus-lobby', 'persona-nexus-chat'
)

foreach ($repo in $repos) {
    $path = Join-Path $root $repo
    if (Test-Path $path) {
        Write-Skip "$repo (already exists)"
        continue
    }
    Write-Host "  Cloning $repo..."
    git clone "https://github.com/kuoliwei/$repo.git" $path
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to clone $repo" -ForegroundColor Red
        exit 1
    }
    Write-Ok "$repo cloned"
}

# ---------------------------------------------------------------------------
# 3. Generate .env files for the 5 backend services
# ---------------------------------------------------------------------------
Write-Step "Generating .env files"

$authEnvPath = Join-Path $root "auth-service\.env"
$gatewayEnvPath = Join-Path $root "api-gateway\.env"
$authEnvExists = Test-Path $authEnvPath
$gatewayEnvExists = Test-Path $gatewayEnvPath

# JWT_SECRET must be identical in both files - only generate a fresh one when
# NEITHER exists yet. If exactly one exists, that's a partial/inconsistent
# state this script shouldn't guess its way out of.
$jwtSecret = $null
if ((-not $authEnvExists) -and (-not $gatewayEnvExists)) {
    $bytes = New-Object byte[] 32
    $rng = New-Object Security.Cryptography.RNGCryptoServiceProvider
    $rng.GetBytes($bytes)
    $jwtSecret = -join ($bytes | ForEach-Object { $_.ToString("x2") })
    Write-Ok "generated a new JWT_SECRET"
} elseif ($authEnvExists -xor $gatewayEnvExists) {
    Write-Warn2 "auth-service/.env and api-gateway/.env are in an inconsistent state (only one exists) - leaving both alone, make sure JWT_SECRET matches in both manually"
} else {
    Write-Skip "auth-service/.env and api-gateway/.env already exist"
}

if ($jwtSecret) {
    Write-Utf8NoBom $authEnvPath @"
PORT=3000
CORS_ORIGIN=http://localhost:8000
JWT_SECRET=$jwtSecret
USER_SERVICE_URL=http://localhost:4000
"@
    Write-Ok "auth-service/.env written"

    Write-Utf8NoBom $gatewayEnvPath @"
PORT=8000
FRONTEND_ORIGIN=http://localhost:5173,http://localhost:5174,http://localhost:5175,http://localhost:5176
JWT_SECRET=$jwtSecret
AUTH_SERVICE_URL=http://localhost:3000
USER_SERVICE_URL=http://localhost:4000
CHARACTER_SERVICE_URL=http://localhost:5000
CHAT_SERVICE_URL=http://localhost:6000
AI_SERVICE_URL=http://localhost:6001
"@
    Write-Ok "api-gateway/.env written"
}

# The other three don't involve JWT_SECRET, so they're independent of the
# auth-service/api-gateway pairing above.
$plainEnvFiles = @{
    'user-service' = "PORT=4000`nDATABASE_URL=file:./prisma/dev.db`n"
    'character-service' = "PORT=5000`nDATABASE_URL=file:./prisma/dev.db`n"
    'chat-service' = "PORT=6000`nDATABASE_URL=file:./prisma/dev.db`nGATEWAY_URL=http://localhost:8000`n"
}

foreach ($service in $plainEnvFiles.Keys) {
    $envPath = Join-Path $root "$service\.env"
    if (Test-Path $envPath) {
        Write-Skip "$service/.env already exists"
        continue
    }
    Write-Utf8NoBom $envPath $plainEnvFiles[$service]
    Write-Ok "$service/.env written"
}

# ai-service doesn't read .env at all - it reads src/config/config.json,
# which is gitignored (machine-specific: which Ollama model you've pulled).
# First run on a fresh clone: copy the committed config.example.json template
# and stop, because ollama.model in the template is a placeholder - the
# service would fail to start (or fail every chat generation) with it as-is,
# and this is a choice only the person running it can make (model depends on
# their GPU VRAM). Existing config.json is never touched.
$aiConfigPath = Join-Path $root "ai-service\src\config\config.json"
$aiConfigExamplePath = Join-Path $root "ai-service\src\config\config.example.json"
if (Test-Path $aiConfigPath) {
    Write-Skip "ai-service/src/config/config.json already exists"
} elseif (Test-Path $aiConfigExamplePath) {
    Copy-Item $aiConfigExamplePath $aiConfigPath
    Write-Warn2 "ai-service/src/config/config.json created from config.example.json - edit ollama.model to a model you've pulled (ollama pull ...) before starting ai-service"
} else {
    Write-Skip "ai-service/src/config/config.example.json not found, skipping"
}

# ---------------------------------------------------------------------------
# 4. npm install (9 JS projects)
# ---------------------------------------------------------------------------
Write-Step "Installing npm dependencies"

$jsProjects = @(
    'auth-service', 'user-service', 'character-service', 'chat-service', 'api-gateway',
    'persona-nexus-auth', 'persona-nexus-character', 'persona-nexus-lobby', 'persona-nexus-chat'
)

foreach ($proj in $jsProjects) {
    $projPath = Join-Path $root $proj
    if (-not (Test-Path $projPath)) {
        Write-Warn2 "$proj folder missing, skipping npm install"
        continue
    }

    Write-Host "  npm install: $proj"
    Push-Location $projPath
    npm install --silent | Out-Null
    $installFailed = ($LASTEXITCODE -ne 0)

    # npm's install-script gate blocks native builds (bcrypt) and Prisma's
    # postinstall (engine download) unless explicitly approved. Skipping this
    # leaves those two packages silently broken at runtime. Safe to call even
    # when nothing is pending (e.g. on a second run of this script).
    # Note: deliberately NOT using 2>&1 here - in Windows PowerShell 5.1 that
    # wraps each stderr line from a native exe in a NativeCommandError, which
    # (with strict error handling) aborts the script even on success.
    npm approve-scripts --all | Out-Null
    npm install --silent | Out-Null
    Pop-Location

    if ($installFailed) {
        Write-Host "npm install failed for $proj" -ForegroundColor Red
        exit 1
    }
    Write-Ok "$proj"
}

# ---------------------------------------------------------------------------
# 5. Prisma migrate + generate (SQLite-backed services)
# ---------------------------------------------------------------------------
Write-Step "Running Prisma migrations"

foreach ($proj in @('user-service', 'character-service', 'chat-service')) {
    $projPath = Join-Path $root $proj
    if (-not (Test-Path $projPath)) {
        Write-Warn2 "$proj folder missing, skipping Prisma"
        continue
    }
    Write-Host "  prisma migrate deploy + generate: $proj"
    Push-Location $projPath
    npx prisma migrate deploy | Out-Null
    npx prisma generate | Out-Null
    $generateFailed = ($LASTEXITCODE -ne 0)
    Pop-Location

    if ($generateFailed) {
        # Common cause: this service's dev server is currently running and
        # has the Prisma query engine DLL locked (Windows can't rename over
        # an open file). Not fatal - any previously generated client is still
        # valid - but flag it instead of claiming success.
        Write-Warn2 "$proj - prisma generate failed (is its dev server currently running? stop it and re-run this script if so)"
    } else {
        Write-Ok "$proj"
    }
}

# ---------------------------------------------------------------------------
# 6. ai-service conda environment
# ---------------------------------------------------------------------------
Write-Step "Setting up the ai-service conda environment"

$envList = conda env list
$aiServiceEnvLine = $envList | Where-Object { $_ -match '^\s*ai-service\s' }

if ($aiServiceEnvLine) {
    Write-Skip "conda env 'ai-service' already exists"
} else {
    Write-Host "  Creating conda env 'ai-service' (Python 3.11)..."
    conda create -n ai-service python=3.11 -y | Out-Null
    Write-Ok "conda env created"
    $envList = conda env list
    $aiServiceEnvLine = $envList | Where-Object { $_ -match '^\s*ai-service\s' }
}

$aiServicePath = Join-Path $root "ai-service"
$requirementsPath = Join-Path $aiServicePath "requirements.txt"
if (Test-Path $requirementsPath) {
    # Parse the actual env path out of `conda env list` rather than assuming
    # it lives under <conda base>\envs\ - conda's envs_dirs setting can put
    # named envs under the user profile instead (e.g. ~\.conda\envs\...),
    # and guessing wrong here silently skips the whole pip install step.
    # Split-on-whitespace would break if the path itself contains spaces
    # (e.g. a Windows username with a space in it), so match everything
    # after the env name instead of taking "the last token".
    $pythonExe = $null
    if ($aiServiceEnvLine -match '^ai-service\s*\*?\s*(.+)$') {
        $condaEnvPath = $matches[1].Trim()
        $candidatePython = Join-Path $condaEnvPath "python.exe"
        if (Test-Path $candidatePython) {
            $pythonExe = $candidatePython
        }
    }
    if ($pythonExe) {
        Write-Host "  Installing ai-service Python dependencies..."
        & $pythonExe -m pip install -r $requirementsPath --quiet
        Write-Ok "ai-service dependencies installed"
    } else {
        Write-Warn2 "could not locate the ai-service conda env's python.exe - install ai-service deps manually (conda activate ai-service && pip install -r requirements.txt)"
    }
} else {
    Write-Skip "ai-service/requirements.txt not found"
}

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
Write-Step "Done"

Write-Host ""
Write-Host "Still needs your attention:" -ForegroundColor Yellow
Write-Host "  - Docker Desktop must actually be running (WSL2 backend) before Qdrant/Caddy can start."
Write-Host "  - Pull at least one Ollama model sized to your GPU, e.g.:"
Write-Host "      ollama pull hf.co/unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL"
Write-Host "      ollama pull nomic-embed-text"
Write-Host "    Then point ai-service/src/config/config.json's ollama.model at whatever you pulled."
Write-Host "  - Start everything with start-all-services.bat (from this folder)."
Write-Host "  - Run check-vite-configs.ps1 any time you touch a frontend's vite.config.js."
Write-Host ""
