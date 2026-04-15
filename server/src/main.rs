use axum::{routing::get, Router};
use std::net::SocketAddr;

mod db;
use db::AppState;

async fn health() -> &'static str {
    "ok"
}

#[tokio::main]
async fn main() {
    let state = AppState::default();
    
    let app = Router::new()
        .route("/health", get(health))
        .with_state(state);

    let addr: SocketAddr = "127.0.0.1:3000"
        .parse()
        .expect("valid bind address");

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind server socket");

    axum::serve(listener, app).await.expect("run server");
}
