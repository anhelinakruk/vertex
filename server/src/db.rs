use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use surrealdb::engine::remote::ws::{Client, Ws};
use surrealdb::opt::auth::Root;
use surrealdb::sql::Thing;
use surrealdb::Surreal;

#[derive(Clone)]
pub struct AppState {
    pub database: Arc<Surreal<Client>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct User {
    pub id: Option<Thing>,
    pub address: String,
    pub created_at: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Wallet {
    pub id: Option<Thing>,
    pub user_id: String,
    pub address: String,
    pub created_at: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Nonce {
    pub id: Option<Thing>,
    pub value: String,
    pub exp: Option<String>,
    pub iat: Option<String>,
}

impl AppState {
    pub async fn new(
        address: &str,
        username: &str,
        password: &str,
        namespace: &str,
        database: &str,
    ) -> Result<Self> {
        let client = Surreal::new::<Ws>(address).await?;
        client.signin(Root { username, password }).await?;
        client.use_ns(namespace).use_db(database).await?;
        Ok(AppState { database: Arc::new(client) })
    }

    pub async fn create_user(&self, address: &str) -> Result<User> {
        let user: Option<User> = self
            .database
            .create("user")
            .content(User {
                id: None,
                address: address.to_lowercase(),
                created_at: None,
            })
            .await?;
        user.ok_or_else(|| anyhow::anyhow!("Failed to create user"))
    }

    pub async fn get_user_by_address(&self, address: &str) -> Result<Option<User>> {
        let mut result = self
            .database
            .query("SELECT * FROM user WHERE address = type::string(string::lowercase($address))")
            .bind(("address", address.to_string()))
            .await?;
        let users: Vec<User> = result.take(0)?;
        Ok(users.into_iter().next())
    }

    pub async fn save_nonce(&self, value: &str) -> Result<()> {
        self.database
            .query(
                "DELETE nonce WHERE exp < time::now() RETURN BEFORE;
                 CREATE ONLY nonce SET value = type::string($value), exp = time::now() + 5m, iat = time::now();",
            )
            .bind(("value", value.to_string()))
            .await?;
        Ok(())
    }

    pub async fn get_nonce(&self, value: &str) -> Result<Option<Nonce>> {
        let mut result = self
            .database
            .query(
                "DELETE nonce WHERE exp < time::now() RETURN BEFORE;
                 SELECT * FROM nonce WHERE value = type::string($value);",
            )
            .bind(("value", value.to_string()))
            .await?;
        let nonces: Vec<Nonce> = result.take(1)?;
        Ok(nonces.into_iter().next())
    }

    pub async fn get_wallet_by_address(&self, address: String) -> Result<Option<Wallet>> {
        let mut result = self
            .database
            .query("SELECT * FROM wallets WHERE address = $address")
            .bind(("address", address))
            .await?;
        let wallets: Vec<Wallet> = result.take(0)?;
        Ok(wallets.into_iter().next())
    }

    pub async fn create_wallet(&self, user_id: &str, address: &str) -> Result<Wallet> {
        let wallet: Option<Wallet> = self
            .database
            .create("wallets")
            .content(Wallet {
                id: None,
                user_id: user_id.to_string(),
                address: address.to_string(),
                created_at: None,
            })
            .await?;
        Ok(wallet.unwrap())
    }

    pub async fn save_transaction(
        &self,
        wallet_id: &str,
        tx_hash: &str,
        from_address: &str,
        to_address: &str,
        amount: &str,
        chain_id: i64,
    ) -> Result<Transaction> {
        let transaction: Option<Transaction> = self
            .database
            .create("transactions")
            .content(Transaction {
                id: None,
                wallet_id: wallet_id.to_string(),
                tx_hash: tx_hash.to_string(),
                from_address: from_address.to_string(),
                to_address: to_address.to_string(),
                amount: amount.to_string(),
                status: "pending".to_string(),
                chain_id,
                created_at: None,
            })
            .await?;
        transaction.ok_or_else(|| anyhow::anyhow!("Failed to save transaction"))
    }

    pub async fn get_transactions_by_wallet(&self, wallet_id: &str) -> Result<Vec<Transaction>> {
        let mut result = self
            .database
            .query("SELECT * FROM transactions WHERE wallet_id = $wallet_id ORDER BY created_at DESC")
            .bind(("wallet_id", wallet_id.to_string()))
            .await?;
        let transactions: Vec<Transaction> = result.take(0)?;
        Ok(transactions)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Transaction {
    pub id: Option<Thing>,
    pub wallet_id: String,
    pub tx_hash: String,
    pub from_address: String,
    pub to_address: String,
    pub amount: String,
    pub status: String,
    pub chain_id: i64,
    pub created_at: Option<String>,
}
