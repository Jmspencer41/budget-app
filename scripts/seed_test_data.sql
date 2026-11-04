-- Budget+ test data.
-- Run from the project folder:
--   docker exec -i budget-db psql -U budgetapp -d budgetapp < scripts/seed_test_data.sql
--
-- Safe to run more than once: it deletes the budgets it made last time first,
-- and the cascade removes their members, categories, transactions, income, and entries.
--
-- Income paydays use fixed anchor dates so they can be checked on a calendar.
-- Transactions and side hustle entries are relative to today, so there is always
-- data for today, this week, this month, and the three months before.

\set ON_ERROR_STOP on

-- Look up the two test accounts. Stops here if either one doesn't exist yet.
SELECT id AS josh FROM users WHERE email = 'jmspencer41@gmail.com' \gset
SELECT id AS abigail FROM users WHERE email = 'abigailspencer@gmail.com' \gset

-- Dates relative to today, saved as psql variables.
SELECT CURRENT_DATE AS today,
       date_trunc('month', CURRENT_DATE)::date AS month_start,
       (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date AS month_end,
       (date_trunc('month', CURRENT_DATE) - interval '1 month')::date AS last_month,
       (date_trunc('month', CURRENT_DATE) - interval '2 months')::date AS two_months_ago,
       (date_trunc('month', CURRENT_DATE) - interval '3 months')::date AS three_months_ago
\gset

BEGIN;

-- Clear the last run.
DELETE FROM budgets WHERE id IN (
  '11111111-0000-0000-0000-000000000001',
  '11111111-0000-0000-0000-000000000002',
  '11111111-0000-0000-0000-000000000003'
);

-- ---------- Budgets ----------
INSERT INTO budgets (id, title, owner_id) VALUES
  ('11111111-0000-0000-0000-000000000001', 'Household',    :'josh'),
  ('11111111-0000-0000-0000-000000000002', 'Side Gigs',    :'josh'),
  ('11111111-0000-0000-0000-000000000003', 'Abigail Personal', :'abigail');

-- ---------- Members: owners, a shared editor, and a viewer ----------
INSERT INTO budget_members (budget_id, user_id, role) VALUES
  ('11111111-0000-0000-0000-000000000001', :'josh', 'OWNER'),
  ('11111111-0000-0000-0000-000000000001', :'abigail',  'EDITOR'),
  ('11111111-0000-0000-0000-000000000002', :'josh', 'OWNER'),
  ('11111111-0000-0000-0000-000000000003', :'abigail',  'OWNER'),
  ('11111111-0000-0000-0000-000000000003', :'josh', 'VIEWER');

-- ---------- Categories: every frequency, a goal, and an empty one ----------
INSERT INTO categories (id, budget_id, name, category_type, frequency, amount_cents, anchor_date) VALUES
  ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Groceries',     'RECURRING', 'MONTHLY',      60000,  '2026-01-01'),
  ('22222222-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'Gas',           'RECURRING', 'WEEKLY',       7500,   '2026-01-05'),  -- weeks start Monday
  ('22222222-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000001', 'Dining out',    'RECURRING', 'BIWEEKLY',     15000,  '2026-10-02'),  -- set up to go over
  ('22222222-0000-0000-0000-000000000004', '11111111-0000-0000-0000-000000000001', 'Coffee',        'RECURRING', 'DAILY',        800,    '2026-01-01'),  -- over today
  ('22222222-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000001', 'Streaming',     'RECURRING', 'QUARTERLY',    9000,   '2026-01-01'),
  ('22222222-0000-0000-0000-000000000006', '11111111-0000-0000-0000-000000000001', 'Car insurance', 'RECURRING', 'SEMIANNUALLY', 90000,  '2026-01-01'),
  ('22222222-0000-0000-0000-000000000007', '11111111-0000-0000-0000-000000000001', 'Gifts',         'RECURRING', 'YEARLY',       100000, '2026-01-01'),
  ('22222222-0000-0000-0000-000000000008', '11111111-0000-0000-0000-000000000001', 'Vacation fund', 'GOAL',      NULL,           300000, NULL),
  ('22222222-0000-0000-0000-000000000009', '11111111-0000-0000-0000-000000000001', 'Pet care',      'RECURRING', 'MONTHLY',      5000,   '2026-01-01'),  -- no spending at all
  ('22222222-0000-0000-0000-000000000010', '11111111-0000-0000-0000-000000000002', 'Supplies',      'RECURRING', 'MONTHLY',      20000,  '2026-01-15'),  -- periods run 15th to 14th
  ('22222222-0000-0000-0000-000000000011', '11111111-0000-0000-0000-000000000003', 'Hobbies',       'RECURRING', 'MONTHLY',      10000,  '2026-01-01');

-- ---------- Transactions: today, this week, this month, and past months ----------
INSERT INTO transactions (category_id, user_id, merchant, description, amount_cents, transaction_date) VALUES
  -- Groceries (monthly)
  ('22222222-0000-0000-0000-000000000001', :'josh', 'Kroger',     'Weekly groceries', 8432,  :'today'::date - 1),
  ('22222222-0000-0000-0000-000000000001', :'abigail',  'Aldi',       'Restock',          6215,  :'today'::date - 3),
  ('22222222-0000-0000-0000-000000000001', :'josh', 'Kroger',     'Weekly groceries', 9120,  :'last_month'::date + 3),
  ('22222222-0000-0000-0000-000000000001', :'josh', 'Costco',     'Bulk run',         21500, :'last_month'::date + 17),
  ('22222222-0000-0000-0000-000000000001', :'abigail',  'Aldi',       'Restock',          7450,  :'last_month'::date + 25),
  ('22222222-0000-0000-0000-000000000001', :'josh', 'Kroger',     'Weekly groceries', 13000, :'two_months_ago'::date + 10),
  ('22222222-0000-0000-0000-000000000001', :'josh', 'Costco',     'Bulk run',         52000, :'three_months_ago'::date + 5),  -- that month went over
  ('22222222-0000-0000-0000-000000000001', :'josh', 'Kroger',     'Weekly groceries', 15000, :'three_months_ago'::date + 20),
  -- Gas (weekly)
  ('22222222-0000-0000-0000-000000000002', :'josh', 'Shell',      'Fill up',          4100,  :'today'::date),
  ('22222222-0000-0000-0000-000000000002', :'josh', 'Speedway',   'Fill up',          3900,  :'today'::date - 8),
  ('22222222-0000-0000-0000-000000000002', :'abigail',  'BP',         'Fill up',          4500,  :'today'::date - 15),
  ('22222222-0000-0000-0000-000000000002', :'josh', 'Shell',      'Fill up',          8200,  :'today'::date - 22),  -- that week went over
  -- Dining out (biweekly, over the limit in the current period)
  ('22222222-0000-0000-0000-000000000003', :'josh', 'Steakhouse', 'Dinner',           9000,  :'today'::date - 1),
  ('22222222-0000-0000-0000-000000000003', :'abigail',  'Sushi bar',  'Dinner',           8000,  :'today'::date - 2),
  ('22222222-0000-0000-0000-000000000003', :'josh', 'Pizza',      'Takeout',          4500,  :'last_month'::date + 12),
  -- Coffee (daily, two in one day puts today over)
  ('22222222-0000-0000-0000-000000000004', :'josh', 'Starbucks',  'Latte',            650,   :'today'::date),
  ('22222222-0000-0000-0000-000000000004', :'josh', 'Gas station','Coffee',           300,   :'today'::date),
  ('22222222-0000-0000-0000-000000000004', :'abigail',  'Starbucks',  'Cold brew',        550,   :'today'::date - 1),
  -- Streaming (quarterly)
  ('22222222-0000-0000-0000-000000000005', :'josh', 'Netflix',    'Subscription',     1599,  :'last_month'::date + 1),
  ('22222222-0000-0000-0000-000000000005', :'josh', 'Spotify',    'Subscription',     1099,  :'last_month'::date + 1),
  ('22222222-0000-0000-0000-000000000005', :'josh', 'Netflix',    'Subscription',     1599,  :'two_months_ago'::date + 1),
  -- Car insurance (every 6 months)
  ('22222222-0000-0000-0000-000000000006', :'josh', 'Progressive','Premium',          82000, :'three_months_ago'::date + 1),
  -- Gifts (yearly)
  ('22222222-0000-0000-0000-000000000007', :'josh', 'Amazon',     'Birthday gift',    4999,  :'today'::date - 4),
  ('22222222-0000-0000-0000-000000000007', :'abigail',  'Target',     'Anniversary',      2500,  :'two_months_ago'::date + 14),
  -- Vacation fund (goal contributions)
  ('22222222-0000-0000-0000-000000000008', :'josh', 'Savings',    'Monthly deposit',  50000, :'three_months_ago'::date + 1),
  ('22222222-0000-0000-0000-000000000008', :'josh', 'Savings',    'Monthly deposit',  50000, :'two_months_ago'::date + 1),
  ('22222222-0000-0000-0000-000000000008', :'josh', 'Savings',    'Monthly deposit',  50000, :'last_month'::date + 1),
  ('22222222-0000-0000-0000-000000000008', :'abigail',  'Savings',    'Extra deposit',    25000, :'today'::date - 2),
  -- Supplies (Side Gigs, mid-month periods)
  ('22222222-0000-0000-0000-000000000010', :'josh', 'Micro Center','Cables and parts',4500,  :'last_month'::date + 20),
  ('22222222-0000-0000-0000-000000000010', :'josh', 'Amazon',     'Drive enclosure',  3000,  :'today'::date - 1),
  -- Hobbies (Abigail Personal, Josh can only view)
  ('22222222-0000-0000-0000-000000000011', :'abigail',  'Hobby Lobby','Paint',            2500,  :'today'::date - 5);

-- ---------- Income sources: every frequency and edge case ----------
-- Fixed anchors. Expected numbers for Nov 4, 2026 are in the comments.
INSERT INTO income_sources (id, user_id, budget_id, name, amount_cents, frequency, auto_generate, anchor_date, second_pay_day) VALUES
  -- Biweekly Fridays: Oct 2, 16, 30 (a 3 paycheck month), then Nov 13, 27. Nov 4: 0 of 4000, next Nov 13
  ('33333333-0000-0000-0000-000000000001', :'josh', '11111111-0000-0000-0000-000000000001', 'Main job',           200000, 'BIWEEKLY',    true,  '2026-10-02', NULL),
  -- Weekly Fridays: Nov 6, 13, 20, 27. Jan 2027 has 5. Nov 4: 0 of 2000, next Nov 6
  ('33333333-0000-0000-0000-000000000002', :'josh', '11111111-0000-0000-0000-000000000001', 'Part time',          50000,  'WEEKLY',      true,  '2026-09-04', NULL),
  -- 1st and 15th, Abigail's income on a shared budget. Nov 4: 1800 of 3600, next Nov 15
  ('33333333-0000-0000-0000-000000000003', :'abigail',  '11111111-0000-0000-0000-000000000001', 'Abigail job',            180000, 'SEMIMONTHLY', true,  '2026-06-01', 15),
  -- 15th and last day: Nov 15 and 30, Feb 15 and 28. Nov 4: 0 of 3600, next Nov 15
  ('33333333-0000-0000-0000-000000000004', :'josh', '11111111-0000-0000-0000-000000000001', 'Contract work',      180000, 'SEMIMONTHLY', true,  '2026-06-15', 31),
  -- Monthly on the 31st: Nov 30, Feb 28, then back to Mar 31. Nov 4: 0 of 3000, next Nov 30
  ('33333333-0000-0000-0000-000000000005', :'josh', '11111111-0000-0000-0000-000000000001', 'Pension',            300000, 'MONTHLY',     true,  '2026-01-31', NULL),
  -- Monthly on the 1st. Nov 4: 1200 of 1200, next Dec 1
  ('33333333-0000-0000-0000-000000000006', :'josh', '11111111-0000-0000-0000-000000000001', 'Roommate rent',      120000, 'MONTHLY',     true,  '2026-03-01', NULL),
  -- Anchor in the future, nothing paid yet. Nov 4: 0 of 0, next Dec 4
  ('33333333-0000-0000-0000-000000000007', :'josh', '11111111-0000-0000-0000-000000000001', 'New job',            150000, 'BIWEEKLY',    true,  '2026-12-04', NULL),
  -- Monthly on the 4th, so Nov 4 is a payday and counts. Nov 4: 250 of 250, next Dec 4
  ('33333333-0000-0000-0000-000000000008', :'josh', '11111111-0000-0000-0000-000000000002', 'Storage unit rent',  25000,  'MONTHLY',     true,  '2026-08-04', NULL),
  -- Manual income with entries (below)
  ('33333333-0000-0000-0000-000000000009', :'josh', '11111111-0000-0000-0000-000000000002', 'Freelance IT',       0,      'IRREGULAR',   false, NULL,         NULL),
  -- Manual income with nothing logged
  ('33333333-0000-0000-0000-000000000010', :'josh', '11111111-0000-0000-0000-000000000002', 'Reselling',          0,      'IRREGULAR',   false, NULL,         NULL),
  -- Abigail's own budget: Oct 9, 23, Nov 6, 20. Nov 4: 0 of 1800, next Nov 6
  ('33333333-0000-0000-0000-000000000011', :'abigail',  '11111111-0000-0000-0000-000000000003', 'Abigail paycheck',       90000,  'BIWEEKLY',    true,  '2026-10-09', NULL);

-- ---------- Manual income entries (Freelance IT) ----------
INSERT INTO income_entries (income_source_id, amount_cents, received_date) VALUES
  ('33333333-0000-0000-0000-000000000009', 45000, :'three_months_ago'::date + 9),
  ('33333333-0000-0000-0000-000000000009', 30000, :'two_months_ago'::date + 20),
  ('33333333-0000-0000-0000-000000000009', 25000, :'last_month'::date + 3),
  ('33333333-0000-0000-0000-000000000009', 15000, :'last_month'::date + 27),
  ('33333333-0000-0000-0000-000000000009', 12000, :'month_start'::date),  -- the 1st counts
  ('33333333-0000-0000-0000-000000000009', 8000,  :'today'::date),        -- today counts
  ('33333333-0000-0000-0000-000000000009', 20000, :'month_end'::date);    -- future: expected only, not received yet

COMMIT;

-- Summary
SELECT b.title, count(DISTINCT c.id) AS categories, count(DISTINCT t.id) AS transactions,
       count(DISTINCT i.id) AS income_sources, count(DISTINCT e.id) AS income_entries
FROM budgets b
LEFT JOIN categories c ON c.budget_id = b.id
LEFT JOIN transactions t ON t.category_id = c.id
LEFT JOIN income_sources i ON i.budget_id = b.id
LEFT JOIN income_entries e ON e.income_source_id = i.id
WHERE b.id::text LIKE '11111111-%'
GROUP BY b.title
ORDER BY b.title;
