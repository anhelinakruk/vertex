# Vertex Wallet — Claude Code Context

## Project Overview

Mobile crypto wallet app (iOS) with a Rust backend. Users can create wallets, send tokens,
and view transaction history. Cryptographic operations happen **client-side** via a Rust
library exposed through UniFFI bindings.

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Rust + Axum |
| Database | SurrealDB (multi-model, SQL+NoSQL) |
| Auth | JWT — issued after wallet signature verification |
| Crypto lib | Rust library via UniFFI (client-side operations) |
| Mobile | iOS — Swift |
| Local cache | Core Data (5 min TTL) |
| Containers | Docker + docker-compose |

## Repository Structure

```
vertex/
├── server/              # Rust backend (Axum)
│   ├── src/main.rs
│   └── Cargo.toml
├── fixtures/
│   └── setup.surql      # SurrealDB schema init
├── docker-compose.yml   # Runs backend + SurrealDB
├── surrealdb.Dockerfile
└── .env.example
```

## Running Locally

```bash
# Copy env
cp .env.example .env

# Start all services (SurrealDB + backend)
docker-compose up --build

# SurrealDB available at: http://localhost:8000
# Backend API available at:  http://localhost:3000
```

## Architecture

Microservices — no direct service-to-service communication. Each service talks
independently to the client (REST API) and shares SurrealDB.

**Auth Service** (`/api/auth`)
- `GET /api/auth/nonce` — generates nonce for a wallet address
- `POST /api/auth/verify` — verifies wallet signature, returns JWT

**Transaction Service** (`/api/transactions`)
- `POST /api/transactions` — records a completed transaction
- `GET /api/transactions/{wallet_id}` — returns transaction history for a wallet

## Auth Flow

1. Client requests nonce for its wallet address
2. Client signs the nonce with its private key (client-side, UniFFI)
3. Client sends signature to `/api/auth/verify`
4. Backend verifies signature → issues JWT
5. Client uses JWT for all subsequent API requests

## Database Schema (SurrealDB)

```
wallets        { address, created_at }
auth_nonce     { id, wallet_address, nonce, expires_at }
sessions       { id, wallet_address, jwt_token, created_at }

wallets → auth_nonce  (1-N)
wallets → sessions    (1-N)
```

Schema is initialized in `fixtures/setup.surql`.

## Error Format

All API errors return consistent JSON:

```json
{
  "code": 400,
  "message": "Invalid wallet address",
  "details": "Provided address has invalid format"
}
```

## Security Rules

- Private keys are **never** sent to or stored on the backend
- No secrets in the repository — use environment variables
- All inputs validated at API boundaries
- JWT used for all authenticated endpoints

## Environment Variables

See `.env.example`:

```
SURREAL_BIND, SURREAL_USER, SURREAL_PASS
SURREALDB_ADDRESS, SURREALDB_NAMESPACE, SURREALDB_DATABASE
SURREAL_IMPORT_FILE
```

## Current Status

- [x] Docker + docker-compose setup
- [x] SurrealDB containerized with healthcheck
- [x] Rust project scaffolded (Cargo.toml, main.rs)
- [ ] Axum + dependencies in Cargo.toml
- [ ] Auth Service endpoints
- [ ] Transaction Service endpoints
- [ ] Database schema (setup.surql)
- [ ] UniFFI crypto library
