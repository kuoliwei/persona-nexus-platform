@echo off
setlocal enabledelayedexpansion

set PROJECT_ROOT=%~dp0

echo Starting all services...
echo.

echo Starting api-gateway (Port 8000)...
start "api-gateway" cmd /k "cd /d %PROJECT_ROOT%api-gateway && npm run dev"
timeout /t 2 /nobreak

echo Starting persona-nexus-auth (Port 5173)...
start "persona-nexus-auth" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-auth && npm run dev"
timeout /t 2 /nobreak

echo Starting persona-nexus-character (Port 5174)...
start "persona-nexus-character" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-character && npm run dev"
timeout /t 2 /nobreak

echo Starting persona-nexus-lobby (Port 5175)...
start "persona-nexus-lobby" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-lobby && npm run dev"
timeout /t 2 /nobreak

echo Starting persona-nexus-chat (Port 5176)...
start "persona-nexus-chat" cmd /k "cd /d %PROJECT_ROOT%persona-nexus-chat && npm run dev"
timeout /t 2 /nobreak

echo.

REM --- Caddy reverse proxy: the single origin everything is served from ---
REM Required since the same-origin migration. The frontends call the API with
REM relative paths (/api/...), so opening a Vite port directly no longer works.
echo Checking Caddy (Port 8080)...
curl -s -o nul http://localhost:8080/
if errorlevel 1 (
    echo   Caddy not responding, starting container...
    docker run -d --rm --name nexus-caddy -p 8080:8080 --add-host host.docker.internal:host-gateway -e NEXUS_UPSTREAM_HOST=host.docker.internal -v "%PROJECT_ROOT%deploy\Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2-alpine
    timeout /t 3 /nobreak
) else (
    echo   Caddy already running.
)

echo.
echo All services started!
echo.
echo   ==^> Open the app at:  http://localhost:8080
echo.
echo   Do NOT open 5173/5174/5175/5176 directly. The frontends call the API with
echo   relative paths, so those ports only work through the proxy above.
echo.
echo   Backend services are NOT started by this script - run
echo   start-backend-services.bat as well, or API calls will fail.
echo.
echo Individual services (for debugging only - see the warning above):
echo   api-gateway:             http://localhost:8000
echo   persona-nexus-auth:      http://localhost:5173  (served at /login)
echo   persona-nexus-character: http://localhost:5174  (served at /character)
echo   persona-nexus-lobby:     http://localhost:5175  (served at /)
echo   persona-nexus-chat:      http://localhost:5176  (served at /chat)
echo.
echo   Stop the proxy with: docker stop nexus-caddy
echo.
pause
