# =====================================================================
# Makefile — управление демо-проектом по индексам PostgreSQL
# =====================================================================

# --- параметры ---
# Имена с префиксом PG_, чтобы не конфликтовать с переменными окружения
# вроде $USER, $DB, которые часто уже экспортированы в шелле и перебили бы
# обычные ?= в Make.
#
# ВНИМАНИЕ: комментарии в Makefile нельзя писать на той же строке, что и
# присваивание — Make захватит хвост строки (включая пробелы) в значение
# переменной. Поэтому все комментарии — отдельными строками.
DC          ?= docker compose
SERVICE     ?= postgres
PG_DB       ?= index_demo
PG_USER     ?= demo
# Размер набора по умолчанию (можно переопределить: make demo ROWS=50000)
ROWS        ?= 10000
# Путь к SQL-файлам внутри контейнера (см. volume в docker-compose.yml)
SQL_DIR     := /sql

PSQL        = $(DC) exec -T $(SERVICE) psql -U $(PG_USER) -d $(PG_DB) -X -v ON_ERROR_STOP=1
PSQL_FILE   = $(PSQL) -f
PSQL_FILE_V = $(PSQL) -v rows=$(ROWS) -f

# --- мета ---
.DEFAULT_GOAL := help
.PHONY: help up down restart wait psql logs status \
        ddl gen gen-10k gen-50k gen-100k \
        before indexes after \
        demo demo-10k demo-50k demo-100k demo-all \
        clean reset nuke

help: ## Показать список команд
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m [ROWS=N]\n\nTargets:\n"} \
	      /^[a-zA-Z0-9_.-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make up                 # поднять PostgreSQL в Docker"
	@echo "  make demo ROWS=50000    # полный прогон на 50k строк"
	@echo "  make demo-all           # три прогона: 10k, 50k, 100k"
	@echo "  make psql               # интерактивная psql-сессия"
	@echo ""

# ---------------------------------------------------------------------
# Жизненный цикл контейнера
# ---------------------------------------------------------------------
up: ## Поднять контейнер с PostgreSQL и дождаться готовности
	$(DC) up -d $(SERVICE)
	@$(MAKE) -s wait

down: ## Остановить контейнер (данные сохраняются в volume)
	$(DC) down

restart: ## Перезапустить контейнер
	$(DC) restart $(SERVICE)
	@$(MAKE) -s wait

wait: ## Дождаться, пока PG готов принимать соединения
	@echo "Waiting for PostgreSQL..."
	@for i in $$(seq 1 30); do \
	  if $(DC) exec -T $(SERVICE) pg_isready -U $(PG_USER) -d $(PG_DB) >/dev/null 2>&1; then \
	    echo "PostgreSQL is ready."; exit 0; \
	  fi; sleep 1; \
	done; \
	echo "PostgreSQL did not become ready in time" >&2; exit 1

status: ## Показать статус контейнера
	$(DC) ps

logs: ## Показать логи PostgreSQL (Ctrl+C чтобы выйти)
	$(DC) logs -f $(SERVICE)

psql: ## Открыть интерактивную psql-сессию в контейнере
	$(DC) exec $(SERVICE) psql -U $(PG_USER) -d $(PG_DB)

# ---------------------------------------------------------------------
# Этапы демо
# ---------------------------------------------------------------------
ddl: ## (1) Создать схему index_demo и таблицы users/orders
	$(PSQL_FILE) $(SQL_DIR)/01_ddl.sql

gen: ## (2) Сгенерировать данные (по умолчанию ROWS=10000)
	@echo ">>> Generating $(ROWS) users + $$(( $(ROWS) * 5 )) orders..."
	$(PSQL_FILE_V) $(SQL_DIR)/02_generate_data.sql

gen-10k:  ## Сгенерировать 10 000 пользователей
	@$(MAKE) -s gen ROWS=10000

gen-50k:  ## Сгенерировать 50 000 пользователей
	@$(MAKE) -s gen ROWS=50000

gen-100k: ## Сгенерировать 100 000 пользователей
	@$(MAKE) -s gen ROWS=100000

before: ## (3) EXPLAIN ANALYZE без индексов
	$(PSQL_FILE) $(SQL_DIR)/03_explain_before.sql

indexes: ## (4) Создать single-column и composite индексы
	$(PSQL_FILE) $(SQL_DIR)/04_create_indexes.sql

after: ## (5) EXPLAIN ANALYZE после индексов
	$(PSQL_FILE) $(SQL_DIR)/05_explain_after.sql

# ---------------------------------------------------------------------
# Композитные сценарии
# ---------------------------------------------------------------------
demo: ## Полный прогон на текущем ROWS (ddl -> gen -> before -> indexes -> after)
	@$(MAKE) -s ddl
	@$(MAKE) -s gen ROWS=$(ROWS)
	@echo ""
	@echo "##############################################################"
	@echo "# BEFORE INDEXES (rows=$(ROWS))"
	@echo "##############################################################"
	@$(MAKE) -s before
	@$(MAKE) -s indexes
	@echo ""
	@echo "##############################################################"
	@echo "# AFTER INDEXES (rows=$(ROWS))"
	@echo "##############################################################"
	@$(MAKE) -s after

demo-10k:  ## Прогон на 10k
	@$(MAKE) -s demo ROWS=10000  | tee logs_10k.txt

demo-50k:  ## Прогон на 50k
	@$(MAKE) -s demo ROWS=50000  | tee logs_50k.txt

demo-100k: ## Прогон на 100k
	@$(MAKE) -s demo ROWS=100000 | tee logs_100k.txt

demo-all: ## Три прогона подряд (10k, 50k, 100k) с логами в файлы
	@$(MAKE) -s demo-10k
	@$(MAKE) -s demo-50k
	@$(MAKE) -s demo-100k
	@echo ""
	@echo "Done. Logs: logs_10k.txt, logs_50k.txt, logs_100k.txt"

# ---------------------------------------------------------------------
# Очистка
# ---------------------------------------------------------------------
clean: ## Удалить только схему index_demo (БД и контейнер живут)
	$(PSQL) -c "DROP SCHEMA IF EXISTS index_demo CASCADE;"

reset: ## Полный сброс схемы и пересоздание (без перегенерации данных)
	@$(MAKE) -s clean
	@$(MAKE) -s ddl

nuke: ## Снести контейнер вместе с volume (полный сброс данных)
	$(DC) down -v