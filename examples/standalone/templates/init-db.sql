-- Copyright 2025 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

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
