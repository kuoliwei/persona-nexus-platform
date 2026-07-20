# Same-Origin Deployment Guide

This directory contains deployment configurations for the Persona Nexus platform using Caddy as a reverse proxy and Docker Compose for orchestration.

## Architecture Overview

- **Caddy** (`:8080`): Single entry point, reverse proxy to all services
- **API Gateway** (`:8000` internally): Routes all `/api/*` requests
- **Four Frontend Services**:
  - Lobby (`:5175`) → mounted at `/`
  - Auth (`:5173`) → mounted at `/login`
  - Character (`:5174`) → mounted at `/character`
  - Chat (`:5176`) → mounted at `/chat`
- **Backend Services**:
  - auth-service (`:3001`)
  - user-service (`:3002`)
  - character-service (`:3003`)
  - chat-service (`:3004`)
  - ai-service (`:3005`)

## Quick Start

### Prerequisites

- Docker & Docker Compose installed
- All microservices have `Dockerfile` in their root directories
- `.env` file in this directory (or use defaults)

### Starting the Stack

#### Method 1: Docker Compose (Recommended)

```bash
cd deploy
docker-compose up -d
```

This will:
1. Build all services (if images don't exist)
2. Start Caddy on `localhost:8080`
3. Start all frontends and backends

#### Method 2: Manual Start (for debugging)

Start services in separate terminals:

```bash
# Terminal 1: Caddy reverse proxy
caddy run --config ./Caddyfile --watch

# Terminal 2-5: Frontends (each in project directory)
cd ../persona-nexus-lobby && npm run dev
cd ../persona-nexus-auth && npm run dev
cd ../persona-nexus-character && npm run dev
cd ../persona-nexus-chat && npm run dev

# Terminal 6+: Backends (each in service directory)
cd ../auth-service && npm start
cd ../user-service && npm start
cd ../character-service && npm start
cd ../chat-service && npm start
cd ../ai-service && npm start
```

## Environment Variables

Create a `.env` file in the `deploy/` directory:

```bash
# Security
JWT_SECRET=your-secret-key-here

# Caddy domain (dev: localhost, prod: your domain)
CADDY_DOMAIN=localhost:8080

# Service ports (optional, defaults shown)
AUTH_SERVICE_URL=http://auth-service:3001
USER_SERVICE_URL=http://user-service:3002
CHARACTER_SERVICE_URL=http://character-service:3003
CHAT_SERVICE_URL=http://chat-service:3004
AI_SERVICE_URL=http://ai-service:3005
```

## Health Checks

### Test Caddy is running

```bash
curl http://localhost:8080/
# Should return lobby frontend HTML
```

### Test routing

```bash
# Lobby
curl http://localhost:8080/

# Auth frontend
curl http://localhost:8080/login

# Character frontend
curl http://localhost:8080/character

# Chat frontend
curl http://localhost:8080/chat

# API Gateway config
curl http://localhost:8080/api/config
```

### Test API calls

```bash
# Check auth endpoint
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}'
```

### View logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f caddy
docker-compose logs -f gateway
docker-compose logs -f lobby
```

## Stopping the Stack

```bash
docker-compose down

# Remove volumes (clears data)
docker-compose down -v
```

## Troubleshooting

### Caddy can't find frontend services

**Problem**: `502 Bad Gateway` when accessing `/login`, `/character`, or `/chat`

**Solution**: 
- Ensure frontend containers are running: `docker-compose ps`
- Check frontend is binding to `0.0.0.0` (not `localhost` only)
- Verify Caddy can reach by checking logs: `docker-compose logs caddy`

### Frontends can't reach API Gateway

**Problem**: Frontend API calls fail with `404` or `CORS` errors

**Solution**:
- Check that frontends use relative paths (`fetch('/api/...')`)
- Verify gateway is running: `docker-compose ps`
- Test gateway directly: `curl http://localhost:8080/api/config`

### Port conflicts

**Problem**: `Port 8080 already in use`

**Solution**:
- Stop other services using the port
- Or modify `Caddyfile` and `docker-compose.yml` to use different ports

### Container won't start

**Problem**: `docker-compose up` fails to start a container

**Solution**:
- Check if `Dockerfile` exists in service directory
- View build error: `docker-compose logs <service-name>`
- Rebuild image: `docker-compose build --no-cache <service-name>`

## Development Workflow

### Hot reloading frontends

The docker-compose setup mounts frontends as volumes, enabling hot reload:

```bash
# Edit frontend code
# Changes auto-reload in browser at http://localhost:8080
```

### Restarting a single service

```bash
docker-compose restart lobby
```

### Rebuilding after dependency changes

```bash
docker-compose build --no-cache <service-name>
docker-compose up -d
```

## Production Deployment

To deploy to production:

1. Update `Caddyfile` to use your domain (see commented section)
2. Set environment variables for production secrets
3. Ensure all services have proper environment configs
4. Run Caddy with auto HTTPS:
   ```bash
   docker-compose up -d
   # Caddy will automatically request Let's Encrypt certificate
   ```

## Network Architecture

All services communicate via the `nexus-network` Docker network:

```
┌─────────────────────────────────────────┐
│         Caddy (8080)                    │
│    Single reverse proxy entry           │
└─────────────────────────────────────────┘
         ↓                                  
    Routing by path                        
    ├─ / → Lobby (5175)                    
    ├─ /login → Auth (5173)                
    ├─ /character → Character (5174)       
    ├─ /chat → Chat (5176)                 
    └─ /api/* → Gateway (8000)             
                 ↓                         
        API Gateway routes to:             
        ├─ auth-service (3001)             
        ├─ user-service (3002)             
        ├─ character-service (3003)        
        ├─ chat-service (3004)             
        └─ ai-service (3005)               
```

## References

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Persona Nexus Architecture](../ARCHITECTURE.md)
