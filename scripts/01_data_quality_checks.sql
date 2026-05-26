-- ==========================================
-- LOGISTICS DATA WAREHOUSE — ПЕРЕВІРКА ДАНИХ
-- Проєкт : pet-project-ymailo
-- Шар    : Data Quality Checks
-- ==========================================

-- 1. Загальна кількість рядків та NULL у RT_Num
SELECT
  COUNT(*)                AS total_rows,
  COUNT(RT_Num)           AS rows_with_rt,
  COUNTIF(RT_Num IS NULL) AS rows_with_null_rt
FROM `pet-project-ymailo.pet_project.stg_raw_august`;

-- 2. Унікальність менеджерів (перевірка дублів і варіантів написання)
SELECT
  TRIM(LOWER(Manager))                 AS normalized,
  COUNT(*)                             AS raw_variants,
  STRING_AGG(DISTINCT Manager, ' | ') AS all_spellings
FROM `pet-project-ymailo.pet_project.stg_raw_august`
WHERE Manager IS NOT NULL
GROUP BY 1
ORDER BY raw_variants DESC;

-- 3. Перевірка цілісності fct_orders після трансформації
SELECT
  COUNT(*)                                     AS total_orders,
  COUNT(DISTINCT internal_order_id)            AS distinct_orders,
  COUNT(*) - COUNT(DISTINCT internal_order_id) AS duplicate_order_keys,
  COUNTIF(manager_id IS NULL)                  AS null_manager_id,
  COUNTIF(loading_geography_id IS NULL)        AS null_loading_geo,
  COUNTIF(unloading_geography_id IS NULL)      AS null_unloading_geo,
  COUNTIF(price_eur IS NULL)                   AS null_price,
  COUNTIF(distance_km IS NULL)                 AS null_distance,
  COUNTIF(loading_date IS NULL)                AS null_loading_date,
  COUNTIF(unloading_date IS NULL)              AS null_unloading_date
FROM `pet-project-ymailo.pet_project.fct_orders`;

-- 4. Перевірка логіки дат
SELECT *
FROM `pet-project-ymailo.pet_project.fct_orders`
WHERE unloading_date < loading_date;

-- 5. Перевірка нульових або від'ємних числових значень
SELECT *
FROM `pet-project-ymailo.pet_project.fct_orders`
WHERE price_eur <= 0
   OR distance_km <= 0;

-- 6. Перевірка референційної цілісності — менеджери
SELECT f.*
FROM `pet-project-ymailo.pet_project.fct_orders` f
LEFT JOIN `pet-project-ymailo.pet_project.dim_managers` m
       ON f.manager_id = m.manager_id
WHERE m.manager_id IS NULL;

-- 7. Перевірка референційної цілісності — географія
SELECT f.internal_order_id
FROM `pet-project-ymailo.pet_project.fct_orders` f
LEFT JOIN `pet-project-ymailo.pet_project.dim_geography` g_load
       ON f.loading_geography_id = g_load.geography_id
LEFT JOIN `pet-project-ymailo.pet_project.dim_geography` g_unl
       ON f.unloading_geography_id = g_unl.geography_id
WHERE g_load.geography_id IS NULL
   OR g_unl.geography_id IS NULL;

fix: оновлено data quality checks — видалено неіснуючі поля round_trip_id та truck_id, додано повну перевірку цілісності fct_orders
