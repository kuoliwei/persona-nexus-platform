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

echo.
echo All services started!
echo Service URLs:
echo   auth-service: http://localhost:3000
echo   user-service: http://localhost:4000
echo   character-service: http://localhost:5000
echo   chat-service: http://localhost:6000
echo   ai-service: http://localhost:6001
echo.
echo Note: ai-service also needs Ollama (11434) and Qdrant (6333) running.

echo.
pause
