CREATE TABLE income_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    budget_id UUID NOT NULL REFERENCES budgets(id),
    name VARCHAR(100) NOT NULL,
    amount_cents BIGINT NOT NULL,
    frequency VARCHAR(20) NOT NULL,
    auto_generate BOOLEAN NOT NULL DEFAULT false,
    anchor_date DATE,
    second_pay_day INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT now(),

    CONSTRAINT chk_income_sources_frequency CHECK (
        frequency IN ('WEEKLY', 'BIWEEKLY', 'SEMIMONTHLY', 'MONTHLY', 'IRREGULAR')
    ),

    CONSTRAINT chk_income_sources_anchor_date CHECK (
        (frequency = 'IRREGULAR' AND anchor_date IS NULL)
        OR (frequency <> 'IRREGULAR' AND anchor_date IS NOT NULL)
    ),

    CONSTRAINT chk_income_sources_second_pay_day CHECK (
        (frequency = 'SEMIMONTHLY' AND second_pay_day IS NOT NULL AND second_pay_day BETWEEN 1 AND 31)
        OR (frequency <> 'SEMIMONTHLY' AND second_pay_day IS NULL)
    )
);