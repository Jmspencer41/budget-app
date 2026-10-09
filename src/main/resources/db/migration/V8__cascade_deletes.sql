ALTER TABLE budget_members DROP CONSTRAINT budget_members_budget_id_fkey,
       ADD FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE;
ALTER TABLE categories DROP CONSTRAINT categories_budget_id_fkey,
       ADD FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE;
ALTER TABLE income_sources DROP CONSTRAINT income_sources_budget_id_fkey,
       ADD FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE;
ALTER TABLE transactions DROP CONSTRAINT transactions_category_id_fkey,
       ADD FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE;
ALTER TABLE income_entries DROP CONSTRAINT income_entries_income_source_id_fkey,
       ADD FOREIGN KEY (income_source_id) REFERENCES income_sources(id) ON DELETE CASCADE;