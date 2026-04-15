use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use uuid::Uuid;
use chrono::Utc;

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

impl AppState {
    pub async fn save_nonce(&self, nonce: &str) {
        let mut nonces = self.nonces.lock().await;
        nonces.insert(nonce.to_string(), Utc::now().timestamp().to_string());
    }

    pub async fn get_nonce(&self, nonce: &str) -> Option<String> {
        let mut nonces = self.nonces.lock().await;
        nonces.remove(nonce)
    }

    pub async fn get_user_by_address(&self, address: &str) -> Option<User> {
        let users = self.users.lock().await;
        users.get(&address.to_lowercase()).cloned()
    }

    pub async fn create_user(&self, address: &str) -> User {
        let user = User {
            id: Some(Uuid::new_v4().to_string()),
            address: address.to_lowercase(),
            created_at: Some(Utc::now().to_rfc3339()),
        };
        let mut users = self.users.lock().await;
        users.insert(user.address.clone(), user.clone());
        user
    }

    pub async fn get_wallet_by_address(&self, address: &str) -> Option<String> {
        let wallets = self.wallets.lock().await;
        wallets.get(&address.to_lowercase()).cloned()
    }

    pub async fn create_wallet(&self, user_id: &str, address: &str) -> String {
        let wallet_id = Uuid::new_v4().to_string();
        let mut wallets = self.wallets.lock().await;
        wallets.insert(address.to_lowercase(), user_id.to_string());
        wallet_id
    }
}
