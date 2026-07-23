@echo off
setlocal enabledelayedexpansion

set PROJECT_ROOT=%~dp0

REM ai-service is Python and needs its conda env activated first.
REM conda is not on PATH, so call activate.bat by full path.
set CONDA_ACTIVATE=C:\Users\MSI3090\miniconda3\Scripts\activate.bat
set CONDA_ENV=ai-service

echo Starting all services...
echo.

REM --- ai-service dependencies: Ollama (11434) + Qdrant (6333) ---
REM Both are started only if not already up, so re-running this script is safe.

echo Checking Ollama (Port 11434)...
curl -s -o nul http://localhost:11434/api/tags
if errorlevel 1 (
    echo   Ollama not responding, starting...
    start "ollama" cmd /k "ollama serve"
    timeout /t 3 /nobreak
) else (
    echo   Ollama already running.
)

echo Checking Qdrant (Port 6333)...
curl -s -o nul http://localhost:6333/
if errorlevel 1 (
    echo   Qdrant not responding, starting container...
    REM Reuses the existing qdrant_storage volume so RAG data persists.
    docker run -d --rm --name qdrant -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
    timeout /t 3 /nobreak
) else (
    echo   Qdrant already running.
)

echo.

echo Starting auth-service (Port 3000)...
start "auth-service" cmd /k "cd /d %PROJECT_ROOT%auth-service && npm run dev"
timeout /t 2 /nobreak

echo Starting user-service (Port 4000)...
start "user-service" cmd /k "cd /d %PROJECT_ROOT%user-service && npm run dev"
timeout /t 2 /nobreak

echo Starting character-service (Port 5000)...
start "character-service" cmd /k "cd /d %PROJECT_ROOT%character-service && npm run dev"
timeout /t 2 /nobreak

echo Starting chat-service (Port 6000)...
start "chat-service" cmd /k "cd /d %PROJECT_ROOT%chat-service && npm run dev"
timeout /t 2 /nobreak

echo Starting ai-service (Port 6001)...
start "ai-service" cmd /k "cd /d %PROJECT_ROOT%ai-service && set PYTHONIOENCODING=utf-8 && call %CONDA_ACTIVATE% %CONDA_ENV% && python main.py"
timeout /t 2 /nobreak

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
REM Run in Docker because caddy is not on PATH; NEXUS_UPSTREAM_HOST makes it
REM reach the dev servers running on the host.
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
echo Individual services (for debugging):
echo   auth-service: http://localhost:3000
echo   user-service: http://localhost:4000
echo   character-service: http://localhost:5000
echo   chat-service: http://localhost:6000
echo   ai-service: http://localhost:6001
echo   api-gateway: http://localhost:8000
echo.
echo Note: ai-service also needs Ollama (11434) and Qdrant (6333) running.
echo   Stop the proxy with: docker stop nexus-caddy
echo.
pause
