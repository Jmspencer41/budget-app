CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES categories(id),
    user_id UUID NOT NULL REFERENCES users(id),
    merchant VARCHAR(255),
    description VARCHAR(255),
    amount_cents BIGINT NOT NULL,
    transaction_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);