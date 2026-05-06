mod auth;
mod db;

use axum::{
    extract::{Json, Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Router,
};
use db::AppState;
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use tower_http::cors::CorsLayer;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let db_address = std::env::var("SURREALDB_ADDRESS")
        .unwrap_or_else(|_| "localhost:8000".to_string());
    let namespace = std::env::var("SURREALDB_NAMESPACE")
        .unwrap_or_else(|_| "vertex".to_string());
    let database = std::env::var("SURREALDB_DATABASE")
        .unwrap_or_else(|_| "wallet".to_string());
    let user = std::env::var("SURREAL_USER")
        .unwrap_or_else(|_| "root".to_string());
    let pass = std::env::var("SURREAL_PASS")
        .unwrap_or_else(|_| "root".to_string());

    let app_state = AppState::new(&db_address, &user, &pass, &namespace, &database)
        .await
        .expect("Failed to connect to database");

    let app = Router::new()
        .route("/health", get(health))
        .route("/api/auth/nonce", get(auth::get_nonce))
        .route("/api/auth/verify", post(auth::verify_and_login))
        .route("/api/transactions", post(save_transaction))
        .route("/api/transactions/:wallet_id", get(get_transactions))
        .layer(CorsLayer::permissive())
        .with_state(app_state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    eprintln!("Server listening on {}", addr);
    axum::serve(listener, app).await.unwrap();
}

async fn health() -> &'static str {
    "ok"
}

#[derive(Debug, Serialize, Deserialize)]
struct SaveTransactionRequest {
    wallet_id: String,
    tx_hash: String,
    from_address: String,
    to_address: String,
    amount: String,
    chain_id: i64,
}

async fn save_transaction(
    _claims: auth::Claims,
    State(state): State<AppState>,
    Json(payload): Json<SaveTransactionRequest>,
) -> impl IntoResponse {
    match state
        .save_transaction(
            &payload.wallet_id,
            &payload.tx_hash,
            &payload.from_address,
            &payload.to_address,
            &payload.amount,
            payload.chain_id,
        )
        .await
    {
        Ok(tx) => (StatusCode::CREATED, Json(tx)).into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": e.to_string() })),
        )
            .into_response(),
    }
}

async fn get_transactions(
    _claims: auth::Claims,
    State(state): State<AppState>,
    Path(wallet_id): Path<String>,
) -> impl IntoResponse {
    match state.get_transactions_by_wallet(&wallet_id).await {
        Ok(txs) => (StatusCode::OK, Json(txs)).into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": e.to_string() })),
        )
            .into_response(),
    }
}
