-- =====================================================================
-- 02_generate_data.sql — массовая генерация через generate_series
-- Параметр: -v rows=10000 | 50000 | 100000
-- На 1 user — 5 orders.
-- =====================================================================

SET search_path TO index_demo;
SELECT setseed(0.42);

TRUNCATE orders, users RESTART IDENTITY;

-- ---------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------
INSERT INTO users (email, full_name, country, status, created_at)
SELECT
    'user_' || g || '@example.com',
    'User '  || g,
    (ARRAY['US','DE','FR','UK','RU','PL','ES','IT','NL','CA'])
        [1 + (random() * 9)::int],
    (ARRAY['active','active','active','blocked','pending'])
        [1 + (random() * 4)::int],
    NOW() - (random() * INTERVAL '730 days')
FROM generate_series(1, :rows) g;

-- ---------------------------------------------------------------------
-- orders (5x от users)
-- ---------------------------------------------------------------------
INSERT INTO orders (user_id, amount, currency, status, created_at)
SELECT
    1 + (random() * (:rows - 1))::int,
    round((random() * 990 + 10)::numeric, 2),
    (ARRAY['USD','EUR','GBP','RUB'])[1 + (random() * 3)::int],
    (ARRAY['new','paid','paid','paid','cancelled','refunded'])
        [1 + (random() * 5)::int],
    NOW() - (random() * INTERVAL '365 days')
FROM generate_series(1, :rows * 5) g;

-- Статистика — критично для честного EXPLAIN
ANALYZE users;
ANALYZE orders;

\echo '--- Generated rows ---'
SELECT 'users'  AS table_name, COUNT(*) AS rows FROM users
UNION ALL
SELECT 'orders' AS table_name, COUNT(*) AS rows FROM orders;
