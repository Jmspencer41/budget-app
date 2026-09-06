CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES budgets(id),
    name VARCHAR(100) NOT NULL,
    category_type VARCHAR(20) NOT NULL,
    frequency VARCHAR(20),                   
    amount_cents BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);