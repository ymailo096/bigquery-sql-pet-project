-- 1. Перевірка кількості NULL у полі RT_Num в сирих даних за серпень
SELECT 
  COUNT(*) AS total_rows,
  COUNT(RT_Num) AS rows_with_rt,
  COUNTIF(RT_Num IS NULL) AS rows_with_null_rt
FROM `pet-project-ymailo.pet_project.stg_raw_august`;

-- 2. Перевірка цілісності зв'язків у фінальній таблиці фактів fct_orders
SELECT 
  COUNT(*) AS total_orders,
  COUNT(round_trip_id) AS orders_with_round_trip,
  COUNTIF(round_trip_id IS NULL AND truck_id IS NOT NULL) AS one_way_orders_with_truck,
  COUNTIF(round_trip_id IS NULL AND truck_id IS NULL) AS stranded_orders_without_any_trip
FROM `pet-project-ymailo.pet_project.fct_orders`;
