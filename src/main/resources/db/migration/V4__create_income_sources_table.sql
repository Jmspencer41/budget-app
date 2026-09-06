CREATE TABLE income_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    budget_id UUID NOT NULL REFERENCES budgets(id),
    name VARCHAR(100) NOT NULL,              
    amount_cents BIGINT NOT NULL,            
    frequency VARCHAR(20) NOT NULL,          
    auto_generate BOOLEAN NOT NULL DEFAULT false,
    next_pay_date DATE,                       
    created_at TIMESTAMP NOT NULL DEFAULT now()
);