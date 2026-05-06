mod auth;
mod db;

use axum::{
    routing::{get, post},
    Router,
};
use db::AppState;
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
