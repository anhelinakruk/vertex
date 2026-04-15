use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Clone, Default)]
pub struct AppState {
    pub nonces: Arc<Mutex<HashMap<String, String>>>,
    pub users: Arc<Mutex<HashMap<String, User>>>,
    pub wallets: Arc<Mutex<HashMap<String, String>>>,
}

#[derive(Debug, Clone)]
pub struct User {
    pub id: Option<String>,
    pub address: String,
    pub created_at: Option<String>,
}
