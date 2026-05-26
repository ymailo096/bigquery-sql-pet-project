-- ==========================================
-- LOGISTICS DATA WAREHOUSE — ТРАНСФОРМАЦІЯ
-- Проєкт : pet-project-ymailo
-- Шар    : Staging → Зіркова схема (3NF)
-- ==========================================

-- 1. Створення довідника менеджерів
CREATE OR REPLACE TABLE `pet-project-ymailo.pet_project.dim_managers` AS
SELECT 1 AS manager_id, 'MAILO' AS manager_name
UNION ALL SELECT 2, 'KUBRAK'
UNION ALL SELECT 3, 'DYPTAN';

-- 2. Створення довідника унікальних адрес
CREATE OR REPLACE TABLE `pet-project-ymailo.pet_project.dim_geography` AS
WITH all_addresses AS (
  SELECT TRIM(Loading_Address) AS addr
  FROM `pet-project-ymailo.pet_project.stg_raw_august`
  WHERE Loading_Address IS NOT NULL
  UNION DISTINCT
  SELECT TRIM(Unloading_Address)
  FROM `pet-project-ymailo.pet_project.stg_raw_august`
  WHERE Unloading_Address IS NOT NULL
)
SELECT
  ROW_NUMBER() OVER (ORDER BY addr) AS geography_id,
  addr AS full_address
FROM all_addresses;

-- 3. Створення таблиці фактів замовлень
CREATE OR REPLACE TABLE `pet-project-ymailo.pet_project.fct_orders` AS
SELECT
  CAST(raw.Internal_order_number AS STRING)  AS internal_order_id,
  g_load.geography_id                        AS loading_geography_id,
  g_unl.geography_id                         AS unloading_geography_id,
  m.manager_id,
  -- Очищення ціни: видаляємо €, нерозривні пробіли, замінюємо кому на крапку
  SAFE_CAST(
    REPLACE(REGEXP_REPLACE(CAST(raw.Price__EUR AS STRING), r'[€\u00a0\s]', ''), ',', '.')
  AS FLOAT64)                                AS price_eur,
  SAFE_CAST(raw.Distance__km AS INT64)       AS distance_km,
  -- Конвертація дат з ДД.ММ.РРРР у YYYY-MM-DD
  SAFE.PARSE_DATE('%d.%m.%Y', CAST(raw.Loading_date   AS STRING)) AS loading_date,
  SAFE.PARSE_DATE('%d.%m.%Y', CAST(raw.Unloading_date AS STRING)) AS unloading_date
FROM `pet-project-ymailo.pet_project.stg_raw_august` raw
-- Джойн з довідником менеджерів
LEFT JOIN `pet-project-ymailo.pet_project.dim_managers` m
       ON UPPER(TRIM(raw.Manager)) = m.manager_name
-- Джойн з географією для точки завантаження
LEFT JOIN `pet-project-ymailo.pet_project.dim_geography` g_load
       ON TRIM(raw.Loading_Address) = g_load.full_address
-- Джойн з географією для точки розвантаження
LEFT JOIN `pet-project-ymailo.pet_project.dim_geography` g_unl
       ON TRIM(raw.Unloading_Address) = g_unl.full_address
WHERE raw.Internal_order_number IS NOT NULL;

-- 4. Аналітична вʼюха для Tableau Public
CREATE OR REPLACE VIEW `pet-project-ymailo.pet_project.vw_tableau_final` AS
SELECT
  f.internal_order_id,
  f.price_eur,
  f.distance_km,
  ROUND(f.price_eur / NULLIF(f.distance_km, 0), 2)    AS eur_per_km,
  DATE_DIFF(f.unloading_date, f.loading_date, DAY)     AS days_in_transit,
  f.loading_date,
  f.unloading_date,
  m.manager_name,
  g_load.full_address                                  AS loading_address,
  SUBSTR(TRIM(g_load.full_address), 1, 2)              AS loading_country,
  g_unl.full_address                                   AS unloading_address,
  SUBSTR(TRIM(g_unl.full_address), 1, 2)               AS unloading_country
FROM `pet-project-ymailo.pet_project.fct_orders` f
LEFT JOIN `pet-project-ymailo.pet_project.dim_managers` m
       ON f.manager_id = m.manager_id
LEFT JOIN `pet-project-ymailo.pet_project.dim_geography` g_load
       ON f.loading_geography_id = g_load.geography_id
LEFT JOIN `pet-project-ymailo.pet_project.dim_geography` g_unl
       ON f.unloading_geography_id = g_unl.geography_id;
