-- =====================================================================
-- 03_explain_before.sql — запросы БЕЗ индексов (только PK)
-- Ожидание: Seq Scan почти везде. Время растёт линейно с объёмом.
-- =====================================================================

SET search_path TO index_demo;

\echo '\n=========================================================='
\echo '  BEFORE INDEXES'
\echo '=========================================================='

\echo '\n--- Q1: WHERE email = ?  (expect: Seq Scan on users) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM users WHERE email = 'user_777@example.com';

\echo '\n--- Q2: WHERE status = blocked  (low selectivity, Seq Scan) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM users WHERE status = 'blocked';

\echo '\n--- Q3: ORDER BY created_at DESC LIMIT 20  (expect: Seq Scan + Sort) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT user_id, email, created_at
FROM   users
ORDER  BY created_at DESC
LIMIT  20;

\echo '\n--- Q4: JOIN users x orders by email  (expect: Hash Join + 2x Seq Scan) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT u.user_id, u.email, o.order_id, o.amount, o.created_at
FROM   users  u
JOIN   orders o ON o.user_id = u.user_id
WHERE  u.email = 'user_42@example.com';

\echo '\n--- Q5: orders in last 30 days  (expect: Seq Scan on orders) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM   orders
WHERE  created_at >= NOW() - INTERVAL '30 days';

\echo '\n--- Q6: paid orders for one user, sorted  (expect: Seq Scan + Sort) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, amount, created_at
FROM   orders
WHERE  user_id = 123 AND status = 'paid'
ORDER  BY created_at DESC;
