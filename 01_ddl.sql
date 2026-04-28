-- =====================================================================
-- 01_ddl.sql — схема и таблицы
-- =====================================================================

DROP SCHEMA IF EXISTS index_demo CASCADE;
CREATE SCHEMA index_demo;
SET search_path TO index_demo;

-- ---------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id    BIGSERIAL PRIMARY KEY,
    email      VARCHAR(120) NOT NULL,
    full_name  VARCHAR(120) NOT NULL,
    country    VARCHAR(2)   NOT NULL,
    status     VARCHAR(16)  NOT NULL,
    created_at TIMESTAMP    NOT NULL
);

-- ---------------------------------------------------------------------
-- orders (FK добавим после загрузки данных)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id   BIGSERIAL PRIMARY KEY,
    user_id    BIGINT        NOT NULL,
    amount     NUMERIC(12,2) NOT NULL,
    currency   VARCHAR(3)    NOT NULL,
    status     VARCHAR(16)   NOT NULL,
    created_at TIMESTAMP     NOT NULL
);

\echo '--- DDL applied ---'
\dt index_demo.*
