-- =====================================================================
-- 04_create_indexes.sql — single-column + composite индексы
-- =====================================================================

SET search_path TO index_demo;

-- USERS
CREATE UNIQUE INDEX idx_users_email             ON users (email);
CREATE INDEX        idx_users_created_at_desc   ON users (created_at DESC);

-- ORDERS
CREATE INDEX        idx_orders_user_id          ON orders (user_id);
CREATE INDEX        idx_orders_created_at       ON orders (created_at);

-- Composite: правило leftmost prefix —
--   WHERE user_id=?                         ✓ используется
--   WHERE user_id=? AND status=?            ✓ используется полностью
--   WHERE status=?                          ✗ НЕ используется
-- Колонка сортировки идёт последней с DESC, чтобы убрать этап Sort из плана.
CREATE INDEX idx_orders_user_status_date
    ON orders (user_id, status, created_at DESC);

-- FK после индекса (на проде так же делают при больших загрузках)
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users(user_id);

ANALYZE users;
ANALYZE orders;

\echo '--- Indexes created ---'
\di+ index_demo.*
