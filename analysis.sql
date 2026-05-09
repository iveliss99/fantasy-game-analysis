/* Проект «Секреты Тёмнолесья»
 * Цель: изучить влияние характеристик игроков и персонажей
 * на покупку внутриигровой валюты «райские лепестки»,
 * а также оценить активность игроков при внутриигровых покупках
 *
 * Автор: Булычева Евдокия Валерьевна, 116 кагорта
 * Дата: 29.12.2024
 */

-- ============================================================
-- ЧАСТЬ 1. ИССЛЕДОВАТЕЛЬСКИЙ АНАЛИЗ ДАННЫХ
-- ============================================================

-- 1.1. Доля платящих игроков по всем данным
SELECT COUNT(id)  AS total_users,
       SUM(payer) AS payers,
       AVG(payer) AS part_of_total
FROM fantasy.users;
-- Результат: 22 214 игроков, 3 929 платящих, доля ~0.18

-- 1.2. Доля платящих игроков в разрезе расы персонажа
SELECT r.race,
       COUNT(u.id)  AS total_users,
       SUM(u.payer) AS payers,
       AVG(u.payer) AS part_of_total
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race;
-- Demon ~0.19 (макс), Elf ~0.17 (мин) — различия незначительные

-- 1.3. Статистика по стоимости покупок
SELECT COUNT(amount)                                              AS count_am,
       SUM(amount)                                               AS sum_am,
       MIN(amount)                                               AS min_am,
       MAX(amount)                                               AS max_am,
       AVG(amount)                                               AS avg_am,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount)       AS med_am,
       STDDEV(amount)                                            AS st_am
FROM fantasy.events;
-- 1 307 678 покупок, сумма 686 615 040, среднее 525.69, медиана 74.86
-- Разрыв среднего и медианы — наличие редких крупных покупок

-- 1.4. Аномальные покупки с нулевой стоимостью
SELECT SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END)                      AS count_zero_am,
       SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END)::real / COUNT(amount) * 100
                                                                         AS part_of_zero_am
FROM fantasy.events;
-- 907 покупок с нулевой стоимостью (~0.07%) — исключаются из дальнейшего анализа

-- 1.5. Сравнение активности платящих и неплатящих игроков
WITH base AS (
    SELECT DISTINCT u.payer,
                    u.id,
                    COUNT(u.id)              AS total_id,
                    COUNT(e.transaction_id)  AS count_tr,
                    SUM(e.amount)            AS sum_am
    FROM fantasy.users AS u
    JOIN fantasy.events AS e ON u.id = e.id
    GROUP BY u.payer, u.id
),
total AS (
    SELECT payer,
           SUM(total_id)  AS total_users,
           AVG(count_tr)  AS avg_count_tr,
           AVG(sum_am)    AS avg_sum_am
    FROM base
    GROUP BY payer
)
SELECT * FROM total;
-- Платящие: ~82 покупки, ~55 468 лепестков на игрока
-- Неплатящие: ~98 покупок, ~48 627 лепестков на игрока
-- Платящих в 5.5 раза меньше, но средняя сумма выше

-- 1.6. Популярность эпических предметов (без нулевых покупок)
WITH sales AS (
    SELECT i.game_items,
           COUNT(e.transaction_id)  AS abs_sales,
           COUNT(DISTINCT e.id)     AS total_users
    FROM fantasy.events AS e
    JOIN fantasy.items AS i ON e.item_code = i.item_code
    WHERE e.amount > 0
    GROUP BY i.game_items
)
SELECT game_items,
       abs_sales,
       abs_sales::real / SUM(abs_sales) OVER () * 100  AS rel_sales,
       total_users::real / SUM(total_users) OVER () * 100 AS rel_users
FROM sales
ORDER BY rel_sales DESC;
-- Book of Legends: 1 004 516 продаж, ~76.87% от всех покупок
-- 19 предметов с 1 продажей каждый (~0.0001%)


-- ============================================================
-- ЧАСТЬ 2. AD HOC АНАЛИЗ
-- ============================================================

-- Зависимость активности игроков от расы персонажа (без нулевых покупок)
WITH users AS (
    SELECT race_id,
           COUNT(DISTINCT id) AS total_users
    FROM fantasy.users
    GROUP BY race_id
),
players AS (
    SELECT u.race_id,
           COUNT(DISTINCT u.id)  AS buyers,
           SUM(u.payer)          AS payers
    FROM fantasy.users AS u
    JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.race_id
),
activity AS (
    SELECT u.race_id,
           COUNT(e.transaction_id)::real / COUNT(DISTINCT u.id)  AS part_of_buys,
           AVG(e.amount)                                          AS avg_am,
           SUM(e.amount)::real / COUNT(DISTINCT u.id)            AS sum_avg_am
    FROM fantasy.users AS u
    JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.race_id
)
SELECT u.race_id,
       r.race,
       u.total_users,
       p.buyers,
       p.buyers::real / u.total_users     AS buyers_part,
       p.payers::real / p.buyers          AS payers_part,
       a.part_of_buys,
       a.avg_am,
       a.sum_avg_am
FROM users AS u
JOIN players AS p  ON u.race_id = p.race_id
JOIN activity AS a ON p.race_id = a.race_id
JOIN fantasy.race AS r ON a.race_id = r.race_id;
-- Human: макс количество покупок (121 на игрока)
-- Northman: макс средняя стоимость покупки (761 лепесток)
-- Demon: мин активность и мин суммарные расходы
-- Различия между расами есть, но не критичны
