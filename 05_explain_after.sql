-- =====================================================================
-- 05_explain_after.sql — те же запросы после индексов
-- Сравнивайте Execution Time и тип Scan с 03_explain_before.sql
-- =====================================================================

SET search_path TO index_demo;

\echo '\n=========================================================='
\echo '  AFTER INDEXES'
\echo '=========================================================='

\echo '\n--- Q1: WHERE email = ?  (expect: Index Scan using idx_users_email) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM users WHERE email = 'user_777@example.com';

\echo '\n--- Q2: WHERE status = blocked  (still Seq Scan! low selectivity) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM users WHERE status = 'blocked';

\echo '\n--- Q3: ORDER BY created_at DESC LIMIT 20  (Index Scan, no Sort) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT user_id, email, created_at
FROM   users
ORDER  BY created_at DESC
LIMIT  20;

\echo '\n--- Q4: JOIN users x orders by email  (Nested Loop + Index Scans) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT u.user_id, u.email, o.order_id, o.amount, o.created_at
FROM   users  u
JOIN   orders o ON o.user_id = u.user_id
WHERE  u.email = 'user_42@example.com';

\echo '\n--- Q5: orders in last 30 days  (Bitmap Index Scan + Bitmap Heap Scan) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM   orders
WHERE  created_at >= NOW() - INTERVAL '30 days';

\echo '\n--- Q6: paid orders for one user (composite index, no Sort step) ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, amount, created_at
FROM   orders
WHERE  user_id = 123 AND status = 'paid'
ORDER  BY created_at DESC;

\echo '\n--- Q6b BONUS: leftmost prefix violation — composite NOT used ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM orders WHERE status = 'paid';
