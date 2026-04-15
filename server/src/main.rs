use axum::{routing::get, Router, Json, extract};
use std::net::SocketAddr;
use siwe::generate_nonce;

mod db;
mod auth;

use db::AppState;
use auth::{AppError, GenerateNonceResponse};

async fn health() -> &'static str {
    "ok"
}

async fn get_nonce(
    extract::State(state): extract::State<AppState>,
) -> Result<Json<GenerateNonceResponse>, AppError> {
    let nonce = generate_nonce();
    state.save_nonce(&nonce).await;
    Ok(Json(GenerateNonceResponse { nonce }))
}

#[tokio::main]
async fn main() {
    let state = AppState::default();
    
    let app = Router::new()
        .route("/health", get(health))
        .route("/api/auth/nonce", get(get_nonce))
        .with_state(state);

    let addr: SocketAddr = "127.0.0.1:3000"
        .parse()
        .expect("valid bind address");

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind server socket");

    axum::serve(listener, app).await.expect("run server");
}
