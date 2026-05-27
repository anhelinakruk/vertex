# Vertex Wallet

Mobile crypto wallet for iOS with a Rust backend. Users can create wallets, send ETH tokens, and view transaction history. Cryptographic operations are performed client-side via a Rust library exposed through UniFFI bindings.

## Team

- Anhelina Kruk 53518 — Backend (Rust/Axum), crypto library (UniFFI)
- Daria Kozlovska 51762 — Frontend (iOS/Swift), UI/UX

## Requirements

- Docker + Docker Compose (or Podman Compose)
- Xcode 15+ (for the iOS app)

## Run locally

### 1. Clone the repository

```bash
git clone https://github.com/anhelinakruk/vertex.git
cd vertex
```

### 2. Configure environment

```bash
cp .env.example .env
```

The default values in `.env.example` work out of the box for local development.

### 3. Start backend + database

```bash
docker-compose up --build
```

This starts:
- **SurrealDB** at `http://localhost:8000`
- **Backend API** at `http://localhost:3000`

To stop:
```bash
docker-compose down
```

### 4. Run the iOS app

Open `frontend/frontend.xcodeproj` in Xcode and run on a simulator or physical device (iOS 16+).

The app connects to the backend at `http://localhost:3000` and to the Sepolia testnet via Alchemy.

---

### Running the backend without Docker

If you want to run the backend directly (requires Rust toolchain):

```bash
# Start only the database
docker-compose up surrealdb

# In a second terminal — change SURREALDB_ADDRESS in .env to localhost:8000, then:
cd server
cargo run
```

## Architecture

| Layer | Technology |
|---|---|
| Backend | Rust + Axum |
| Database | SurrealDB |
| Auth | JWT (issued after wallet signature verification) |
| Crypto lib | Rust library via UniFFI (client-side) |
| Mobile | iOS — Swift |
| Local cache | Core Data (5 min TTL) |
| Containers | Docker + docker-compose |

## API

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/auth/nonce` | Generate nonce for wallet address | — |
| POST | `/api/auth/verify` | Verify ECDSA signature, get JWT | — |
| POST | `/api/transactions` | Save a completed transaction | JWT |
| GET | `/api/transactions/:wallet_id` | Get transaction history | JWT |
| GET | `/health` | Health check | — |

### Error format

All errors return consistent JSON:

```json
{
  "code": 400,
  "message": "Unauthorized",
  "details": "Invalid token"
}
```

## Database schema (SurrealDB)

```
user           { address, created_at }
wallets        { user_id, address, created_at }
auth_nonce     { value, exp, iat }
transactions   { wallet_id, tx_hash, from_address, to_address, amount, status, chain_id, created_at }
```

## Security

- Private keys are **never** sent to or stored on the backend
- All crypto operations happen client-side via UniFFI
- JWT used for all authenticated endpoints
- No secrets committed to the repository — use `.env`
