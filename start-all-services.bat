@echo off
setlocal enabledelayedexpansion

set PROJECT_ROOT=%~dp0

REM Machine-specific overrides (CONDA_ACTIVATE, CLOUDFLARED_PATH) live in this
REM gitignored file - see start-config.local.bat.example. Skipped if absent.
if exist "%PROJECT_ROOT%start-config.local.bat" call "%PROJECT_ROOT%start-config.local.bat"

REM ai-service is Python and runs inside the "ai-service" conda env. We call
REM that env's python.exe directly by full path instead of `call activate.bat`
REM + `python` - conda's activate.bat/conda.bat batch files can recurse into
REM "BATCH RECURSION exceeds STACK limits" when invoked from inside another
REM script's nested `start cmd /k ... && call ... && ...` chain (a known
REM conda-on-Windows batch quirk), and activation isn't actually needed just
REM to run one script - it only matters for resolving `python`/`pip` on PATH.
REM Set AI_PYTHON_EXE in start-config.local.bat if auto-detection below fails.
if not defined AI_PYTHON_EXE (
    set "AI_ENV_PATH="
    for /f "tokens=1,*" %%a in ('conda env list ^| findstr /b /c:"ai-service "') do set "AI_ENV_PATH=%%b"
    if defined AI_ENV_PATH (
        set "AI_PYTHON_EXE=!AI_ENV_PATH!\python.exe"
    )
)

if not defined AI_PYTHON_EXE (
    echo [ERROR] Could not find the "ai-service" conda env. Make sure it
    echo         exists - run: conda create -n ai-service python=3.11 - or set
    echo         AI_PYTHON_EXE manually in start-config.local.bat.
    pause
    exit /b 1
)

if not exist "!AI_PYTHON_EXE!" (
    echo [ERROR] Auto-detected AI_PYTHON_EXE does not exist: !AI_PYTHON_EXE!
    echo         Set the correct path manually in start-config.local.bat.
    pause
    exit /b 1
)

echo Starting all services...
echo.

REM --- ai-service dependencies: Ollama (11434) + Qdrant (6333) ---
REM Both are started only if not already up, so re-running this script is safe.

echo Checking Ollama (Port 11434)...
curl -s -o nul http://localhost:11434/api/tags
if errorlevel 1 (
    echo   Ollama not responding, starting...
    start "ollama" cmd /k "ollama serve"
) else (
    echo   Ollama already running.
)

echo Checking Qdrant (Port 6333)...
curl -s -o nul http://localhost:6333/
if errorlevel 1 (
    echo   Qdrant not responding, starting container...
    REM Reuses the existing qdrant_storage volume so RAG data persists.
    REM
    REM Deliberately NO --rm: with it the container was deleted the moment it
    REM stopped, so "restart Qdrant" was not actually a doable action - stopping
    REM it from Docker Desktop's Containers tab made it vanish, and re-launching
    REM from the Images tab gives a brand new container with default settings:
    REM no -p 6333:6333 and no -v qdrant_storage, i.e. nothing listening on 6333
    REM and an empty database. That is what made ai-service report
    REM "[WinError 10061] connection refused" until everything was restarted.
    REM
    REM Without --rm the container survives `docker stop`, so `docker start`
    REM (or the UI's play button) revives that same container with its port
    REM mappings and volume intact. `docker run` therefore only needs to happen
    REM the first time, or after an explicit `docker rm qdrant` - hence the
    REM start-then-run fallback below. --restart unless-stopped additionally
    REM brings it back when Docker Desktop starts, unless it was stopped by hand.
    docker start qdrant >nul 2>&1
    if errorlevel 1 (
        docker run -d --name qdrant --restart unless-stopped -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
    )
) else (
    echo   Qdrant already running.
)

echo.

echo Starting auth-service (Port 3000)...
start "auth-service" cmd /k "cd /d %PROJECT_ROOT%auth-service && npm run dev"

echo Starting user-service (Port 4000)...
start "user-service" cmd /k "cd /d %PROJECT_ROOT%user-service && npm run dev"

echo Starting character-service (Port 5000)...
start "character-service" cmd /k "cd /d %PROJECT_ROOT%character-service && npm run dev"

echo Starting chat-service (Port 6000)...
start "chat-service" cmd /k "cd /d %PROJECT_ROOT%chat-service && npm run dev"

echo Starting ai-service (Port 6001)...
REM AI_PYTHON_EXE's path can contain spaces (e.g. a Windows username with a
REM space in it), so the working directory is set via `start`'s own /d switch
REM instead of a `cd /d ... &&` prefix inside the quoted cmd /k string - nesting
REM a second quoted (space-containing) path inside that outer quoted string
REM breaks cmd.exe's parser ("... was unexpected at this time").
start "ai-service" /d "%PROJECT_ROOT%ai-service" cmd /k "set PYTHONIOENCODING=utf-8 && "%AI_PYTHON_EXE%" main.py"

echo Starting api-gateway (Port 8000)...
start "api-gateway" cmd /k "cd /d %PROJECT_ROOT%api-gateway && npm run dev"

echo Starting persona-nexus-auth (Port 5173)...
start "persona-nexus-auth" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-auth && npm run dev"

echo Starting persona-nexus-character (Port 5174)...
start "persona-nexus-character" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-character && npm run dev"

echo Starting persona-nexus-lobby (Port 5175)...
start "persona-nexus-lobby" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-lobby && npm run dev"

echo Starting persona-nexus-chat (Port 5176)...
start "persona-nexus-chat" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-chat && npm run dev"

echo.

REM --- Caddy reverse proxy: the single origin everything is served from ---
REM Required since the same-origin migration. The frontends call the API with
REM relative paths (/api/...), so opening a Vite port directly no longer works.
REM Run in Docker because caddy is not on PATH; NEXUS_UPSTREAM_HOST makes it
REM reach the dev servers running on the host.
echo Checking Caddy (Port 8080)...
curl -s -o nul http://localhost:8080/
if errorlevel 1 (
    echo   Caddy not responding, starting container...
    docker run -d --rm --name nexus-caddy -p 8080:8080 --add-host host.docker.internal:host-gateway -e NEXUS_UPSTREAM_HOST=host.docker.internal -v "%PROJECT_ROOT%deploy\Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2-alpine
) else (
    echo   Caddy already running.
)

echo.
echo All services started!
echo.
echo   ==^> Open the app at:  http://localhost:8080
echo.
echo   Everything is served from that one origin:
echo     /            lobby
echo     /login       auth
echo     /character   character
echo     /chat        chat
echo     /api/*       api-gateway
echo.
echo   Do NOT open 5173/5174/5175/5176 directly. The frontends call the API with
echo   relative paths, so those ports only work through the proxy above.
echo.
echo Individual services (for debugging only - see the warning above):
echo   backend:
echo     auth-service:      http://localhost:3000
echo     user-service:      http://localhost:4000
echo     character-service: http://localhost:5000
echo     chat-service:      http://localhost:6000
echo     ai-service:        http://localhost:6001
echo     api-gateway:       http://localhost:8000
echo   frontend (Vite dev servers):
echo     persona-nexus-auth:      http://localhost:5173  (served at /login)
echo     persona-nexus-character: http://localhost:5174  (served at /character)
echo     persona-nexus-lobby:     http://localhost:5175  (served at /)
echo     persona-nexus-chat:      http://localhost:5176  (served at /chat)
echo.
echo Note: ai-service also needs Ollama (11434) and Qdrant (6333) running.
echo   Stop the proxy with: docker stop nexus-caddy
echo.
echo ============================================================================
echo.
set /p START_TUNNEL="Do you want to expose the app to the public internet with Cloudflare Tunnel? (y/n): "
if /i not "%START_TUNNEL%"=="y" goto :skip_tunnel

REM Try PATH first (winget normally links cloudflared there), then a
REM machine-specific override, then the two common winget install locations.
set "CLOUDFLARED_EXE="
where cloudflared >nul 2>&1
if not errorlevel 1 set "CLOUDFLARED_EXE=cloudflared"

if not defined CLOUDFLARED_EXE if defined CLOUDFLARED_PATH if exist "%CLOUDFLARED_PATH%\cloudflared.exe" set "CLOUDFLARED_EXE=%CLOUDFLARED_PATH%\cloudflared.exe"

if not defined CLOUDFLARED_EXE if exist "C:\Program Files (x86)\cloudflared\cloudflared.exe" set "CLOUDFLARED_EXE=C:\Program Files (x86)\cloudflared\cloudflared.exe"

if not defined CLOUDFLARED_EXE if exist "C:\Program Files\cloudflared\cloudflared.exe" set "CLOUDFLARED_EXE=C:\Program Files\cloudflared\cloudflared.exe"

if not defined CLOUDFLARED_EXE goto :tunnel_not_found

echo.
echo Starting Cloudflare Tunnel...
echo   NOTE: Always forward port 8080 - the Caddy port - not other ports!
echo   This is a Quick Tunnel: the URL is random and changes every restart.
echo   For a fixed URL you need your own domain - see the Cloudflare Tunnel
echo   guide in the repo root.
echo.
start "cloudflared" cmd /k ""%CLOUDFLARED_EXE%" tunnel --url http://localhost:8080"
echo   cloudflared will open in a new window. Check it for your public URL.
echo.
goto :skip_tunnel

:tunnel_not_found
echo.
echo   [SKIPPED] cloudflared.exe not found. Install it first:
echo     winget install Cloudflare.cloudflared
echo   Then open a NEW terminal window (PATH needs a refresh) and re-run this
echo   script. If it is installed but still not detected, set CLOUDFLARED_PATH
echo   in start-config.local.bat to the folder containing cloudflared.exe.
echo.

:skip_tunnel
echo.
pause
