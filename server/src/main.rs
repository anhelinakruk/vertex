use axum::{routing::{get, post}, Router, Json, extract};
use std::net::SocketAddr;
use siwe::generate_nonce;

mod db;
mod auth;

use db::AppState;
use auth::{AppError, GenerateNonceResponse, VerifySignatureRequest, AuthResponse, generate_jwt, extract_nonce_from_message};

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

async fn verify_and_login(
    extract::State(state): extract::State<AppState>,
    Json(req): Json<VerifySignatureRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    // Extract nonce from message
    let nonce = extract_nonce_from_message(&req.message)
        .ok_or_else(|| AppError(anyhow::anyhow!("Invalid message format")))?;

    // Verify nonce exists and is not expired
    let _stored_nonce = state
        .get_nonce(&nonce)
        .await
        .ok_or_else(|| AppError(anyhow::anyhow!("Invalid or expired nonce")))?;

    // Normalize address (lowercase)
    let address = req.address.to_lowercase();

    // Get or create user
    let user = match state.get_user_by_address(&address).await {
        Some(user) => user,
        None => state.create_user(&address).await,
    };

    let user_id = user
        .id
        .clone()
        .ok_or_else(|| AppError(anyhow::anyhow!("Failed to create user")))?;

    // Generate JWT token
    let token = generate_jwt(user_id.clone())?;

    Ok(Json(AuthResponse {
        access_token: token,
        user_id,
    }))
}

#[tokio::main]
async fn main() {
    let state = AppState::default();
    
    let app = Router::new()
        .route("/health", get(health))
        .route("/api/auth/nonce", get(get_nonce))
        .route("/api/auth/verify", post(verify_and_login))
        .with_state(state);

    let addr: SocketAddr = "127.0.0.1:3000"
        .parse()
        .expect("valid bind address");

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind server socket");

    axum::serve(listener, app).await.expect("run server");
}
