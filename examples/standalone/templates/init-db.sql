CREATE TABLE IF NOT EXISTS "credit_card" (
    card_type_code TEXT,
    card_type_full_name TEXT,
    issuing_bank TEXT,
    card_number TEXT,
    card_holders_name TEXT,
    cvv_cvv2 TEXT,
    issue_date TEXT,
    expiry_date TEXT,
    billing_date TEXT,
    card_pin TEXT,
    credit_limit TEXT
);

CREATE ROLE plaintext_reader;
GRANT SELECT (
    issuing_bank,
    card_number,
    card_holders_name,
    cvv_cvv2,
    issue_date,
    expiry_date,
    billing_date,
    card_pin
) ON credit_card TO plaintext_reader;

CREATE ROLE encrypted_data_reader;
GRANT SELECT (
    issuing_bank,
    card_number,
    card_holders_name,
    cvv_cvv2,
    issue_date,
    expiry_date,
    billing_date,
    card_pin
) ON credit_card TO encrypted_data_reader;
