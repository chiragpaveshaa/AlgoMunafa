#!/bin/bash
# Development startup script

set -e

echo "🚀 Starting Algo Trading Platform (Development)"

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env not found, copying from .env.example"
    cp .env.example .env
fi

# Auto-generate WEBHOOK_SECRET if not set or using placeholder
if ! grep -q "^WEBHOOK_SECRET=" .env || grep -q "WEBHOOK_SECRET=your-webhook-secret-here" .env; then
    echo "🔑 Generating WEBHOOK_SECRET..."
    NEW_WEBHOOK_SECRET=$(python -c "import secrets; print(secrets.token_urlsafe(32))")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/WEBHOOK_SECRET=.*/WEBHOOK_SECRET=$NEW_WEBHOOK_SECRET/" .env
    else
        sed -i "s/WEBHOOK_SECRET=.*/WEBHOOK_SECRET=$NEW_WEBHOOK_SECRET/" .env
    fi
    echo "✅ WEBHOOK_SECRET generated"
fi

# Auto-generate ENCRYPTION_KEY if not set or using placeholder
if ! grep -q "^ENCRYPTION_KEY=" .env || grep -q "ENCRYPTION_KEY=your-encryption-key-here" .env; then
    echo "🔐 Generating ENCRYPTION_KEY..."
    NEW_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$NEW_ENCRYPTION_KEY/" .env
    else
        sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$NEW_ENCRYPTION_KEY/" .env
    fi
    echo "✅ ENCRYPTION_KEY generated"
fi

# Check for required Dhan credentials
if ! grep -q "^DHAN_CLIENT_ID=" .env || grep -q "DHAN_CLIENT_ID=your_dhan_client_id" .env; then
    echo "❌ DHAN_CLIENT_ID not set in .env"
    echo "📝 Get it from https://dhan.co/api"
    exit 1
fi

if ! grep -q "^DHAN_ACCESS_TOKEN=" .env || grep -q "DHAN_ACCESS_TOKEN=your_dhan_access_token" .env; then
    echo "❌ DHAN_ACCESS_TOKEN not set in .env"
    echo "📝 Get it from https://dhan.co/api"
    exit 1
fi

# Generate JWT keys if not present
if [ ! -f keys/private.pem ]; then
    echo "🔐 Generating JWT keys..."
    mkdir -p keys
    openssl genrsa -out keys/private.pem 2048
    openssl rsa -in keys/private.pem -pubout -out keys/public.pem
    echo "✅ Keys generated"
fi

# Start Docker services
echo "🐳 Starting Docker services..."
docker-compose up -d postgres timescaledb redis

# Wait for services
echo "⏳ Waiting for services..."
sleep 10

# Run migrations
echo "📦 Running database migrations..."
docker-compose exec -T api alembic upgrade head 2>/dev/null || {
    echo "⚠️  API container not running, running migrations locally..."
    alembic upgrade head
}

# Start API
echo "🌐 Starting API server..."
cd algo_trading
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 &
API_PID=$!

# Start Frontend
echo "🎨 Starting Frontend..."
cd ../frontend
npm run dev &
FRONTEND_PID=$!

echo ""
echo "✅ Platform started!"
echo ""
echo "📍 Access points:"
echo "   API:       http://localhost:8000"
echo "   Docs:      http://localhost:8000/docs"
echo "   Frontend:  http://localhost:5173"
echo "   Flower:    http://localhost:5555"
echo ""
echo "🛑 Press Ctrl+C to stop all services"

# Trap Ctrl+C
trap "kill $API_PID $FRONTEND_PID; docker-compose down; exit" INT

# Wait
wait