CREATE TABLE income_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    income_source_id UUID NOT NULL REFERENCES income_sources(id),
    amount_cents BIGINT NOT NULL,
    received_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);