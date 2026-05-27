USE NS vertex DB wallet;

DEFINE TABLE wallets SCHEMAFULL;
DEFINE FIELD user_id ON wallets TYPE string;
DEFINE FIELD address ON wallets TYPE string;
DEFINE FIELD created_at ON wallets TYPE datetime DEFAULT time::now();
DEFINE INDEX wallet_address ON wallets FIELDS address UNIQUE;
DEFINE INDEX wallet_user ON wallets FIELDS user_id;

DEFINE TABLE transactions SCHEMAFULL;
DEFINE FIELD wallet_id ON transactions TYPE string;
DEFINE FIELD tx_hash ON transactions TYPE string;
DEFINE FIELD from_address ON transactions TYPE string;
DEFINE FIELD to_address ON transactions TYPE string;
DEFINE FIELD amount ON transactions TYPE string;
DEFINE FIELD status ON transactions TYPE string DEFAULT 'pending';
DEFINE FIELD chain_id ON transactions TYPE int;
DEFINE FIELD created_at ON transactions TYPE datetime DEFAULT time::now();
DEFINE INDEX tx_hash ON transactions FIELDS tx_hash UNIQUE;
DEFINE INDEX tx_wallet ON transactions FIELDS wallet_id;

DEFINE TABLE user SCHEMAFULL;
DEFINE FIELD address ON user TYPE string;
DEFINE FIELD created_at ON user TYPE datetime DEFAULT time::now();
DEFINE INDEX user_address ON user FIELDS address UNIQUE;

DEFINE TABLE nonce SCHEMAFULL;
DEFINE FIELD value ON nonce TYPE string;
DEFINE FIELD exp ON nonce TYPE datetime;
DEFINE FIELD iat ON nonce TYPE datetime DEFAULT time::now();
DEFINE INDEX nonce_value ON nonce FIELDS value UNIQUE;
