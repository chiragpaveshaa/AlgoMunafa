# Algo Trading Platform

A full-stack algorithmic trading platform with Dhan API integration, TradingView webhook support, and multi-client management for Nirmal Bang Securities.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ TradingView │────▶│  Webhook     │────▶│   Signal    │
│  (Alerts)   │     │  Receiver    │     │  Processor  │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                 │
                    ┌──────────────┐             │
                    │   Redis      │◀────────────┘
                    │  (Queue)     │
                    └──────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  Risk Engine  │ │  Order Mgmt   │ │  Position     │
│  (Pre-trade)  │ │  System (OMS) │ │  Manager      │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          ▼
                 ┌─────────────────┐
                 │  Dhan API       │
                 │  (REST + WS)    │
                 └─────────────────┘
```

## Features

- **TradingView Integration**: Receive signals via webhooks, idempotent processing
- **Dhan API**: Full REST + WebSocket integration (orders, positions, holdings, funds)
- **Multi-Client**: Nirmal Bang client mapping with encrypted Dhan credentials
- **Risk Management**: Pre-trade checks (position limits, exposure, margin, KYC)
- **Paper Trading**: Simulated execution for strategy testing
- **Backtesting**: Vectorized + event-driven engines (planned)
- **Real-time Dashboard**: React + TanStack Query + WebSocket updates
- **Audit Trail**: Immutable logging for compliance

## Tech Stack

| Layer | Technology |
|-------|------------|
| Backend | FastAPI, SQLAlchemy 2.0, PostgreSQL, Redis |
| Frontend | React 18, TypeScript, Vite, TanStack Query, Tailwind CSS |
| Auth | JWT (RS256), OAuth2, bcrypt |
| Queue | Redis Streams, Celery |
| Monitoring | Prometheus, Grafana, Sentry |

## Quick Start

### Prerequisites

- Python 3.11+
- Node.js 18+
- PostgreSQL 16+
- Redis 7+
- Dhan API credentials (apply at https://dhan.co/api)

### Backend Setup

```bash
cd algo_trading

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -e ".[dev,backtest]"

# Copy and configure environment
cp .env.example .env
# Edit .env with your credentials

# Generate JWT keys
mkdir -p keys
openssl genrsa -out keys/private.pem 2048
openssl rsa -in keys/private.pem -pubout -out keys/public.pem

# Generate encryption key
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Add to .env as ENCRYPTION_KEY

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload
```

### Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Start dev server
npm run dev
```

### Docker (Recommended)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f api

# Run migrations
docker-compose exec api alembic upgrade head
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_URL` | Redis connection string | Yes |
| `DHAN_CLIENT_ID` | Dhan API client ID | Yes |
| `DHAN_ACCESS_TOKEN` | Dhan API access token | Yes |
| `JWT_PRIVATE_KEY_PATH` | Path to RSA private key | Yes |
| `JWT_PUBLIC_KEY_PATH` | Path to RSA public key | Yes |
| `ENCRYPTION_KEY` | Fernet key for credential encryption | Yes |
| `WEBHOOK_SECRET` | HMAC secret for TradingView webhooks | Yes |

### Dhan API Setup

1. Apply for API access at https://dhan.co/api
2. Get `client_id` and `access_token`
3. Add to `.env`
4. Whitelist your server IP in Dhan dashboard

### TradingView Webhook Setup

1. In TradingView, create an alert
2. Set webhook URL: `https://your-domain.com/webhook/tradingview?strategy_webhook_id=YOUR_STRATEGY_ID`
3. Use JSON format:
```json
{
  "symbol": "RELIANCE",
  "exchange": "NSE",
  "action": "BUY",
  "order_type": "MARKET",
  "quantity": 10,
  "product_type": "INTRADAY",
  "price": 2500,
  "trigger_price": 2495
}
```

## Project Structure

```
algo_trading/
├── app/
│   ├── api/           # FastAPI routes
│   ├── core/          # Config, security
│   ├── db/            # Database session
│   ├── models/        # SQLAlchemy models
│   ├── schemas/       # Pydantic schemas
│   ├── services/      # Business logic
│   └── utils/         # Helpers
├── frontend/          # React application
├── alembic/           # Database migrations
├── tests/             # Pytest tests
└── docker-compose.yml
```

## API Endpoints

### Authentication
- `POST /auth/register` - Register user
- `POST /auth/login` - Login (returns JWT)
- `POST /auth/refresh` - Refresh token
- `GET /auth/me` - Current user

### Clients
- `GET /clients` - List clients
- `POST /clients` - Create client
- `GET /clients/{id}` - Get client
- `PATCH /clients/{id}` - Update client
- `DELETE /clients/{id}` - Deactivate client

### Strategies
- `GET /strategies` - List strategies
- `POST /strategies` - Create strategy
- `GET /strategies/{id}` - Get strategy
- `PATCH /strategies/{id}` - Update strategy
- `POST /strategies/{id}/deploy` - Deploy to clients

### Orders
- `GET /orders` - List orders (with filters)
- `POST /orders` - Place manual order
- `GET /orders/{id}` - Get order
- `POST /orders/{id}/cancel` - Cancel order
- `GET /orders/{id}/trades` - Get fills

### Positions
- `GET /positions?client_id=` - List positions
- `GET /positions/client/{id}/summary` - Portfolio summary
- `GET /positions/client/{id}/holdings` - Holdings
- `GET /positions/client/{id}/funds` - Fund limits

### Webhook
- `POST /webhook/tradingview?strategy_webhook_id=` - TradingView alerts

## Development

### Running Tests

```bash
# Backend
pytest tests/ -v

# Frontend
npm run lint
```

### Database Migrations

```bash
# Create migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

### Code Style

```bash
# Python
ruff check .
ruff format .

# Type checking
mypy app/
```

## Deployment

### Production Checklist

- [ ] Set `ENVIRONMENT=production`
- [ ] Use strong `JWT_SECRET_KEY` and `ENCRYPTION_KEY`
- [ ] Enable HTTPS (reverse proxy with nginx/Traefik)
- [ ] Configure PostgreSQL with SSL
- [ ] Set up Redis with auth
- [ ] Configure Prometheus + Grafana
- [ ] Set up Sentry DSN
- [ ] Enable webhook signature verification
- [ ] Set up automated backups
- [ ] Configure log aggregation

### Kubernetes

```yaml
# Example deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: algo-trading-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: algo-trading-api
  template:
    spec:
      containers:
      - name: api
        image: your-registry/algo-trading:latest
        envFrom:
        - secretRef:
            name: algo-trading-secrets
        ports:
        - containerPort: 8000
```

## Compliance (SEBI)

- All orders logged with timestamps, user, client, strategy
- Position limits enforced per client/risk profile
- Audit trail immutable (append-only)
- UCC mapping maintained for Nirmal Bang clients
- Daily position reports generated

## Contributing

1. Fork the repository
2. Create feature branch
3. Write tests
4. Ensure CI passes
5. Submit PR

## License

Proprietary - For internal use only