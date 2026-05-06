use axum::{
    async_trait,
    extract::{FromRequestParts, State},
    http::{request::Parts, HeaderMap, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
    Json, RequestPartsExt,
};
use axum_extra::{
    headers::{authorization::Bearer, Authorization, Cookie},
    TypedHeader,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use serde_json::json;
use siwe::generate_nonce;

use crate::db::AppState;

#[derive(Debug)]
pub struct AppError(pub anyhow::Error);

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        eprintln!("Application error: {:?}", self.0);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": self.0.to_string() })),
        )
            .into_response()
    }
}

impl<E> From<E> for AppError
where
    E: Into<anyhow::Error>,
{
    fn from(err: E) -> Self {
        Self(err.into())
    }
}

#[derive(Debug)]
pub enum AuthError {
    MissingCredentials,
    InvalidToken,
    TokenExpired,
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AuthError::MissingCredentials => (StatusCode::UNAUTHORIZED, "Missing credentials"),
            AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "Invalid token"),
            AuthError::TokenExpired => (StatusCode::UNAUTHORIZED, "Token expired"),
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GenerateNonceResponse {
    pub nonce: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct VerifySignatureRequest {
    pub message: String,
    pub signature: String,
    pub address: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AuthResponse {
    pub access_token: String,
    pub user_id: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub exp: usize,
    pub sub: String,
}

fn get_jwt_secret() -> String {
    std::env::var("JWT_SECRET").unwrap_or_else(|_| "dev-secret-key".to_string())
}

pub fn generate_jwt(user_id: String) -> Result<String, AppError> {
    let exp = chrono::Utc::now()
        .checked_add_signed(chrono::Duration::days(7))
        .unwrap()
        .timestamp() as usize;
    let claims = Claims { exp, sub: user_id };
    let secret = get_jwt_secret();
    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_ref()),
    )?;
    Ok(token)
}

pub fn verify_jwt(token: String) -> Result<Claims, AppError> {
    let secret = get_jwt_secret();
    let token_data = decode::<Claims>(
        &token,
        &DecodingKey::from_secret(secret.as_ref()),
        &Validation::default(),
    )?;
    Ok(token_data.claims)
}

#[async_trait]
impl FromRequestParts<AppState> for Claims {
    type Rejection = AuthError;

    async fn from_request_parts(
        parts: &mut Parts,
        _state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        if let Ok(cookies) = parts.extract::<TypedHeader<Cookie>>().await {
            if let Some(token) = cookies.get("token") {
                return verify_jwt(token.to_string()).map_err(|_| AuthError::InvalidToken);
            }
        }
        if let Ok(TypedHeader(Authorization(bearer))) =
            parts.extract::<TypedHeader<Authorization<Bearer>>>().await
        {
            return verify_jwt(bearer.token().to_string()).map_err(|_| AuthError::InvalidToken);
        }
        Err(AuthError::MissingCredentials)
    }
}

pub async fn get_nonce(
    State(state): State<AppState>,
) -> Result<Json<GenerateNonceResponse>, AppError> {
    let nonce = generate_nonce();
    state.save_nonce(&nonce).await?;
    Ok(Json(GenerateNonceResponse { nonce }))
}

pub async fn verify_and_login(
    State(state): State<AppState>,
    Json(payload): Json<VerifySignatureRequest>,
) -> Result<(HeaderMap, Json<AuthResponse>), AppError> {
    let nonce = extract_nonce(&payload.message)
        .ok_or_else(|| anyhow::anyhow!("Nonce not found in message"))?;

    state
        .get_nonce(&nonce)
        .await?
        .ok_or_else(|| anyhow::anyhow!("Invalid or expired nonce"))?;

    // TODO: verify ECDSA signature against address

    let user = match state.get_user_by_address(&payload.address).await? {
        Some(u) => u,
        None => state.create_user(&payload.address).await?,
    };

    let user_id = user
        .id
        .ok_or_else(|| anyhow::anyhow!("User ID not found"))?
        .to_string();

    let _wallet = match state.get_wallet_by_address(payload.address.clone()).await? {
        Some(w) => w,
        None => state.create_wallet(&user_id, &payload.address).await?,
    };

    let token = generate_jwt(user_id.clone())?;

    let mut headers = HeaderMap::new();
    headers.insert(
        axum::http::header::SET_COOKIE,
        HeaderValue::from_str(&format!(
            "token={}; HttpOnly; Path=/; Max-Age=604800",
            token
        ))?,
    );

    Ok((headers, Json(AuthResponse { access_token: token, user_id })))
}

fn extract_nonce(message: &str) -> Option<String> {
    let marker = "Nonce: ";
    if let Some(start) = message.find(marker) {
        let nonce_part = &message[start + marker.len()..];
        let nonce = nonce_part.split_whitespace().next()?;
        Some(nonce.to_string())
    } else {
        None
    }
}
