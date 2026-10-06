@echo off
REM Development startup script for Windows

echo 🚀 Starting Algo Trading Platform (Development)

REM Check if .env exists
if not exist .env (
    echo ⚠️  .env not found, copying from .env.example
    copy .env.example .env
)

REM Auto-generate WEBHOOK_SECRET if not set or using placeholder
for /f "tokens=1,* delims==" %%a in ('findstr /i "WEBHOOK_SECRET=" .env 2^>nul') do set CURRENT_WEBHOOK_SECRET=%%b
if not defined CURRENT_WEBHOOK_SECRET (
    echo 🔑 Generating WEBHOOK_SECRET...
    for /f %%i in ('python -c "import secrets; print(secrets.token_urlsafe(32))"') do set NEW_WEBHOOK_SECRET=%%i
    powershell -Command "(Get-Content .env) -replace 'WEBHOOK_SECRET=.*', 'WEBHOOK_SECRET=%NEW_WEBHOOK_SECRET%' | Set-Content .env"
    echo ✅ WEBHOOK_SECRET generated
) else if "%CURRENT_WEBHOOK_SECRET%"=="your-webhook-secret-here" (
    echo 🔑 Generating WEBHOOK_SECRET...
    for /f %%i in ('python -c "import secrets; print(secrets.token_urlsafe(32))"') do set NEW_WEBHOOK_SECRET=%%i
    powershell -Command "(Get-Content .env) -replace 'WEBHOOK_SECRET=.*', 'WEBHOOK_SECRET=%NEW_WEBHOOK_SECRET%' | Set-Content .env"
    echo ✅ WEBHOOK_SECRET generated
)

REM Auto-generate ENCRYPTION_KEY if not set or using placeholder
for /f "tokens=1,* delims==" %%a in ('findstr /i "ENCRYPTION_KEY=" .env 2^>nul') do set CURRENT_ENCRYPTION_KEY=%%b
if not defined CURRENT_ENCRYPTION_KEY (
    echo 🔐 Generating ENCRYPTION_KEY...
    for /f %%i in ('python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"') do set NEW_ENCRYPTION_KEY=%%i
    powershell -Command "(Get-Content .env) -replace 'ENCRYPTION_KEY=.*', 'ENCRYPTION_KEY=%NEW_ENCRYPTION_KEY%' | Set-Content .env"
    echo ✅ ENCRYPTION_KEY generated
) else if "%CURRENT_ENCRYPTION_KEY%"=="your-encryption-key-here" (
    echo 🔐 Generating ENCRYPTION_KEY...
    for /f %%i in ('python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"') do set NEW_ENCRYPTION_KEY=%%i
    powershell -Command "(Get-Content .env) -replace 'ENCRYPTION_KEY=.*', 'ENCRYPTION_KEY=%NEW_ENCRYPTION_KEY%' | Set-Content .env"
    echo ✅ ENCRYPTION_KEY generated
)

REM Check for required Dhan credentials
for /f "tokens=1,* delims==" %%a in ('findstr /i "DHAN_CLIENT_ID=" .env 2^>nul') do set DHAN_CLIENT_ID=%%b
for /f "tokens=1,* delims==" %%a in ('findstr /i "DHAN_ACCESS_TOKEN=" .env 2^>nul') do set DHAN_ACCESS_TOKEN=%%b

if "%DHAN_CLIENT_ID%"=="" (
    echo ❌ DHAN_CLIENT_ID not set in .env
    echo 📝 Get it from https://dhan.co/api
    pause
    exit /b 1
)
if "%DHAN_ACCESS_TOKEN%"=="" (
    echo ❌ DHAN_ACCESS_TOKEN not set in .env
    echo 📝 Get it from https://dhan.co/api
    pause
    exit /b 1
)

REM Generate JWT keys if not present
if not exist keys\private.pem (
    echo 🔐 Generating JWT keys...
    mkdir keys 2>nul
    openssl genrsa -out keys\private.pem 2048
    openssl rsa -in keys\private.pem -pubout -out keys\public.pem
    echo ✅ Keys generated
)

REM Start Docker services
echo 🐳 Starting Docker services...
docker-compose up -d postgres timescaledb redis

REM Wait for services
echo ⏳ Waiting for services...
timeout /t 10 >nul

REM Run migrations
echo 📦 Running database migrations...
docker-compose exec -T api alembic upgrade head 2>nul || (
    echo ⚠️  API container not running, running migrations locally...
    alembic upgrade head
)

REM Start API
echo 🌐 Starting API server...
cd algo_trading
start "API Server" cmd /k "uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"

REM Start Frontend
echo 🎨 Starting Frontend...
cd ..\frontend
start "Frontend" cmd /k "npm run dev"

echo.
echo ✅ Platform started!
echo.
echo 📍 Access points:
echo    API:       http://localhost:8000
echo    Docs:      http://localhost:8000/docs
echo    Frontend:  http://localhost:5173
echo    Flower:    http://localhost:5555
echo.
echo 🛑 Close the terminal windows to stop all services
pause