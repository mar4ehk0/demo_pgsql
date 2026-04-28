# pg_index_demo

Учебный проект для демонстрации эффекта индексов в PostgreSQL.
Полностью изолированный: PostgreSQL крутится в Docker, всё управление —
через `make`.

## Что внутри

```
pg_index_demo/
├── docker-compose.yml          PostgreSQL 16-alpine, порт 5433 на хосте
├── Makefile                    все команды проекта
├── 01_ddl.sql                  схема + таблицы users, orders
├── 02_generate_data.sql        generate_series, параметр :rows
├── 03_explain_before.sql       6 запросов с EXPLAIN ANALYZE без индексов
├── 04_create_indexes.sql       single-column + composite индексы
└── 05_explain_after.sql        те же 6 запросов после индексов
```

## Требования

- Docker + Docker Compose v2
- GNU make

## Быстрый старт

```bash
make up                     # поднять PostgreSQL
make demo ROWS=50000        # ddl -> gen -> before -> indexes -> after
make psql                   # для ручных экспериментов
make down                   # остановить (данные сохраняются)
make nuke                   # снести вместе с volume
```

Чтобы увидеть весь список команд:

```bash
make help
```

## Сценарии прогона

```bash
make demo-10k               # быстрый прогон (логи в logs_10k.txt)
make demo-50k               #                       logs_50k.txt
make demo-100k              # самый тяжёлый прогон  logs_100k.txt
make demo-all               # все три подряд
```

После `demo-all` сравните `logs_*.txt` — самый яркий контраст планов
выполнения «до/после индексов» виден на 100k.

## Пошаговый прогон вручную

Если нужно показывать аудитории по одному шагу:

```bash
make up
make ddl                    # 1. создать схему
make gen ROWS=100000        # 2. сгенерировать 100k users + 500k orders
make before                 # 3. EXPLAIN ANALYZE — Seq Scan везде
make indexes                # 4. создать индексы
make after                  # 5. EXPLAIN ANALYZE — Index Scan / Bitmap / Nested Loop
```

## На что обращать внимание в выводе EXPLAIN ANALYZE

| Запрос | До индексов | После индексов |
|--------|-------------|-----------------|
| Q1 поиск по email                       | Seq Scan                | **Index Scan**                       |
| Q2 фильтр по status='blocked'           | Seq Scan                | Seq Scan (низкая селективность — индекс не помогает) |
| Q3 ORDER BY created_at DESC LIMIT 20    | Seq Scan + Sort         | **Index Scan + Limit (без Sort)**    |
| Q4 JOIN users × orders                  | Hash Join + 2× Seq Scan | **Nested Loop + 2× Index Scan**      |
| Q5 диапазон дат                         | Seq Scan                | **Bitmap Index Scan + Bitmap Heap**  |
| Q6 user_id + status + ORDER BY date     | Seq Scan + Sort         | **Index Scan по composite, без Sort**|
| Q6b status без user_id                  | —                       | Seq Scan (правило leftmost prefix)   |

Главные числа в EXPLAIN ANALYZE:
- **Execution Time** — суммарное время выполнения
- **actual rows / loops** — сколько строк реально прочитано
- **Buffers: shared hit / read** — попадания в кэш vs чтения с диска
- Тип узла: `Seq Scan`, `Index Scan`, `Bitmap Index Scan`, `Sort`, `Nested Loop`, `Hash Join`

## Подключение из локальных клиентов

Контейнер пробрасывает порт **5433** на хост (чтобы не конфликтовать
с локальной установкой PG):

```
host:     localhost
port:     5433
db:       index_demo
user:     demo
password: demo
```

Все параметры можно переопределить из CLI:

```bash
make demo ROWS=100000
make psql PG_USER=demo PG_DB=index_demo
make up SERVICE=postgres
```

> Переменные в Makefile названы `PG_USER` и `PG_DB` (не `USER`/`DB`),
> потому что `$USER` уже есть в окружении почти любой Unix-системы и
> перебивает значение из Makefile.

## Тонкости конфигурации

В `docker-compose.yml` намеренно выставлены:

- `shared_buffers=256MB` — данные горячие, чтобы измерять CPU, а не I/O
- `work_mem=4MB` — на 100k строках без индекса увидите *external merge Disk* при сортировке
- `random_page_cost=1.1` — близко к значению для SSD; планировщик чаще выбирает Index Scan

Если хотите чистый «дисковый» сценарий — увеличьте объём данных или
уменьшите `shared_buffers`.