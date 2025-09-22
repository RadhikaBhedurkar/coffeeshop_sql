--        Coffee Shop SQL Case Study - Database Setup

create database coffee_shop;

use coffee_shop;

CREATE TABLE Ingredients (
    ing_id VARCHAR(10) PRIMARY KEY,
    ing_name VARCHAR(100) NOT NULL,
    ing_weight INTEGER NOT NULL,
    ing_meas VARCHAR(16),
    ing_price DECIMAL(10,2)
);

CREATE TABLE Inventary (
    inv_id VARCHAR(10) PRIMARY KEY,
    ing_id VARCHAR(10) NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity >= 0)
);

CREATE TABLE menu_items (
    item_id VARCHAR(10) PRIMARY KEY,
    sku VARCHAR(20) NOT NULL,
    item_name VARCHAR(50) NOT NULL,
    item_cat VARCHAR(30) NOT NULL,
    item_size VARCHAR(10) NOT NULL,
    item_price DECIMAL(5,2) NOT NULL CHECK(item_price >= 0)
);

CREATE TABLE orders (
    row_id SERIAL PRIMARY KEY,
    order_id TEXT,
    created_at TEXT,
    item_id VARCHAR(10),
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    cust_name VARCHAR(50),
    in_or_out TEXT
);

CREATE TABLE recipe (
    row_id SERIAL PRIMARY KEY,
    recipe_id VARCHAR(20) NOT NULL,
    ing_id VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0)
);

CREATE TABLE rota (
    row_id SERIAL PRIMARY KEY,
    rota_id VARCHAR(10),
    date DATE,
    shift_id VARCHAR(10),
    staff_id VARCHAR(10)
);

CREATE TABLE shift (
    shift_id VARCHAR(10) PRIMARY KEY,
    day_of_week VARCHAR(10),
    start_time TIME,
    end_time TIME
);

CREATE TABLE staff (
    staff_id VARCHAR(10) PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    position VARCHAR(50),
    sal_per_hour DECIMAL(10,2)
);

CREATE TABLE coffeeshop (
    row_id SERIAL PRIMARY KEY,
    rota_id VARCHAR(10),
	date VARCHAR(10),
    shift_id VARCHAR(10),
    staff_id VARCHAR(10)
);

SELECT * FROM coffeeshop;
SELECT * FROM ingredients;
SELECT * FROM inventary;
SELECT * FROM menu_items;
SELECT * FROM orders;
SELECT * FROM recipe;
SELECT * FROM rota;
SELECT * FROM shift;
SELECT * FROM staff;


-- Q1:   Calculate total hours worked by each employee per week.

SELECT sf.staff_id,
       sf.first_name,
       sf.last_name,
       DATE_SUB(cs.date, INTERVAL (DAYOFWEEK(cs.date) - 1) DAY) AS week_start,
       SUM(TIMESTAMPDIFF(HOUR, s.start_time, s.end_time)) AS total_worked_hours
FROM staff sf
JOIN coffeeshop cs ON sf.staff_id = cs.staff_id
JOIN shift s ON cs.shift_id = s.shift_id
GROUP BY sf.staff_id, sf.first_name, sf.last_name, week_start
ORDER BY sf.staff_id;

-- Q2:   Identify employees working overtime (more than 25 hours).

SELECT staff_id, first_name, last_name, week_start, total_worked_hours
FROM (
    SELECT sf.staff_id,
           sf.first_name,
           sf.last_name,
           -- Get the start of the week (Sunday as default in MySQL)
           DATE_SUB(cs.date, INTERVAL (DAYOFWEEK(cs.date) - 1) DAY) AS week_start,
           -- Sum hours worked in each shift
           SUM(TIMESTAMPDIFF(HOUR, s.start_time, s.end_time)) AS total_worked_hours
    FROM staff sf
    JOIN coffeeshop cs ON sf.staff_id = cs.staff_id
    JOIN shift s ON cs.shift_id = s.shift_id
    GROUP BY sf.staff_id, sf.first_name, sf.last_name, week_start
) subquery
WHERE total_worked_hours > 25
ORDER BY staff_id;

-- Q3: Rank employees based on total hours worked

WITH emp_worked_hours AS (
    SELECT sf.staff_id,
           sf.first_name,
           sf.last_name,
           -- Get the start of the week (Sunday as default in MySQL)
           DATE_SUB(cs.date, INTERVAL (DAYOFWEEK(cs.date) - 1) DAY) AS week_start,
           -- Calculate total worked hours
           SUM(TIMESTAMPDIFF(HOUR, s.start_time, s.end_time)) AS total_worked_hours
    FROM staff sf
    JOIN coffeeshop cs ON sf.staff_id = cs.staff_id
    JOIN shift s ON cs.shift_id = s.shift_id
    GROUP BY sf.staff_id, sf.first_name, sf.last_name, week_start
)
SELECT staff_id,
       first_name,
       last_name,
       total_worked_hours,
       DENSE_RANK() OVER (ORDER BY total_worked_hours DESC) AS rank_top_working_employees
FROM emp_worked_hours
ORDER BY rank_top_working_employees;

-- Q4: Suggest an optimized shift allocation to balance the workload

WITH EmployeeHours AS (
    SELECT sf.staff_id,
           sf.first_name,
           sf.last_name,
           -- Convert worked time into decimal hours
           SUM(TIMESTAMPDIFF(MINUTE, s.start_time, s.end_time)) / 60 AS total_worked_hours
    FROM staff sf
    JOIN coffeeshop cs ON sf.staff_id = cs.staff_id
    JOIN shift s ON cs.shift_id = s.shift_id
    GROUP BY sf.staff_id, sf.first_name, sf.last_name
),
OverWorked AS (
    SELECT staff_id, first_name, last_name, total_worked_hours
    FROM EmployeeHours
    WHERE total_worked_hours > 25
),
UnderWorked AS (
    SELECT staff_id, first_name, last_name, total_worked_hours
    FROM EmployeeHours
    WHERE total_worked_hours < 25
)
SELECT o.staff_id AS overworked_id,
       o.first_name AS overworked_firstname,
       u.staff_id AS underworked_id,
       u.first_name AS underworked_firstname,
       'Consider Shift reallocation' AS suggestion
FROM OverWorked o
CROSS JOIN UnderWorked u
ORDER BY o.staff_id, u.staff_id;

-- Q5: Detect employees with overlapping shifts (same date, overlapping times)

WITH Overlappingshifts AS (
    SELECT cs.shift_id,
           cs.date,
           s.start_time,
           s.end_time,
           GROUP_CONCAT(CONCAT(st.first_name, ' ', st.last_name) SEPARATOR ' | ') AS employees,
           COUNT(*) AS employees_count
    FROM coffeeshop cs
    JOIN shift s ON cs.shift_id = s.shift_id
    JOIN staff st ON cs.staff_id = st.staff_id
    GROUP BY cs.shift_id, cs.date, s.start_time, s.end_time
    HAVING COUNT(*) > 1
)
SELECT shift_id,
       date,
       start_time,
       end_time,
       employees,
       employees_count
FROM Overlappingshifts
ORDER BY date, shift_id;

-- Q6: Identify shifts with insufficient staff

SELECT cs.shift_id,
       cs.date,
       s.start_time,
       s.end_time,
       GROUP_CONCAT(CONCAT(st.first_name, ' ', st.last_name) SEPARATOR ' | ') AS employees,
       COUNT(*) AS employees_count
FROM coffeeshop cs
JOIN shift s ON cs.shift_id = s.shift_id
JOIN staff st ON cs.staff_id = st.staff_id
GROUP BY cs.shift_id, cs.date, s.start_time, s.end_time
HAVING COUNT(*) <= 1
ORDER BY cs.date, cs.shift_id;

-- Q7: Identify busiest hours based on total sales

SELECT HOUR(o.created_at) AS busiest_hours,
       SUM(o.quantity * mi.item_price) AS total_sales
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY busiest_hours
ORDER BY total_sales DESC;

-- Q8: Create a view summarizing total revenue per month, orders, and average order value

CREATE VIEW monthly_kpis AS 
SELECT MONTH(o.created_at) AS month,
       SUM(o.quantity * mi.item_price) AS revenue_per_month,
       SUM(o.quantity) AS orders_per_month,
       ROUND(SUM(o.quantity * mi.item_price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY MONTH(o.created_at)
ORDER BY month ASC;

-- Q9: Determine the most profitable category (Hot Drinks, Cold Drinks, Pastries, etc.)

SELECT mi.item_cat AS profitable_category, 
       SUM(CASE WHEN o.in_or_out = 'out' THEN o.quantity ELSE 0 END) AS quantity_sold_out,
       SUM(CASE WHEN o.in_or_out = 'in' THEN o.quantity ELSE 0 END) AS quantity_sold_in,
       SUM(o.quantity) AS total_quantity_sold,
       SUM(o.quantity * mi.item_price) AS revenue_per_category
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY mi.item_cat
ORDER BY total_quantity_sold DESC
LIMIT 1;

-- Q10: Find customers who order at least 14 times per week

SELECT cust_name,
       MONTH(created_at) AS month,
       WEEK(created_at, 1) AS week_of_year,       -- 1 = week starts on Monday
       FLOOR((DAY(created_at) - 1) / 7) + 1 AS week_of_month,
       COUNT(*) AS total_orders
FROM orders
-- WHERE MONTH(created_at) = 2   -- optional filter by month
GROUP BY cust_name, month, week_of_year, week_of_month
HAVING COUNT(*) >= 14
ORDER BY total_orders ASC;

-- Q.11 Identify customers who haven't placed an order in the last 30 days

SELECT DISTINCT cust_name
FROM orders
WHERE cust_name NOT IN (
    SELECT DISTINCT cust_name
    FROM orders
    WHERE created_at > CURRENT_DATE - INTERVAL 30 DAY
);

-- Q12: Preferred order times with period labels

SELECT order_period, order_count
FROM (
    SELECT CASE 
             WHEN HOUR(created_at) BETWEEN 5 AND 10 THEN 'Morning'
             WHEN HOUR(created_at) BETWEEN 12 AND 15 THEN 'Afternoon'
             WHEN HOUR(created_at) BETWEEN 17 AND 19 THEN 'Evening'
             ELSE 'Other'
           END AS order_period,
           COUNT(*) AS order_count
    FROM orders
    GROUP BY order_period

    UNION ALL

    SELECT 'Total' AS order_period, COUNT(*) AS order_count
    FROM orders
) AS combined_result
ORDER BY 
    order_period = 'Morning' DESC, 
    order_period = 'Afternoon' DESC, 
    order_period = 'Evening' DESC,
    order_period = 'Other' DESC, 
    order_period = 'Total' DESC;

-- Q13: Identify top 5 best-selling items and their revenue contribution

SELECT mi.item_name,
       o.item_id,
       SUM(o.quantity) AS quantity_sold,
       SUM(o.quantity * mi.item_price) AS revenue_contribution
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY mi.item_name, o.item_id
ORDER BY quantity_sold DESC
LIMIT 5;

-- Q14: Find least-selling items and suggest potential removal or discounts

SELECT mi.item_name,
       o.item_id,
       SUM(o.quantity) AS quantity_sold,
       SUM(o.quantity * mi.item_price) AS revenue_contribution, 
       CASE 
           WHEN SUM(o.quantity) < 5 THEN 'Removal'
           WHEN SUM(o.quantity) <= 10 AND SUM(o.quantity * mi.item_price) > 40 THEN 'Discount'
           WHEN SUM(o.quantity) BETWEEN 10 AND 15 THEN 'Discount'
           WHEN SUM(o.quantity) > 15 THEN 'Keep'
       END AS status_recommendation,
       CASE 
           WHEN SUM(o.quantity) < 5 THEN 'Very Low Sales'
           WHEN SUM(o.quantity) <= 10 AND SUM(o.quantity * mi.item_price) > 40 THEN 'High Price Items'
           WHEN SUM(o.quantity) BETWEEN 10 AND 15 THEN 'Medium Sales'
           WHEN SUM(o.quantity) > 15 THEN 'High Sales'
           ELSE 'Unknown'
       END AS reason
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY mi.item_name, o.item_id
ORDER BY quantity_sold ASC, revenue_contribution ASC;

-- Q15: Identify best-selling items and recommend marketing focus

SELECT mi.item_name,
       mi.item_cat,
       SUM(o.quantity) AS total_quantity_sold, 
       CASE 
           WHEN SUM(o.quantity) >= 30 THEN 'Top Seller - Focus Marketing'
           WHEN SUM(o.quantity) BETWEEN 20 AND 29 THEN 'Moderate Seller - Some Marketing'
           ELSE 'Low Seller - Little or No Marketing'
       END AS marketing_recommendation
FROM menu_items mi
JOIN orders o ON mi.item_id = o.item_id
GROUP BY mi.item_name, mi.item_cat
ORDER BY total_quantity_sold DESC;

-- Q16: List all ingredients that are running low in inventory (quantity < 5)

WITH ing_quantity AS (
    SELECT ing.ing_id,
           ing.ing_name,
           ing.ing_weight,
           ing.ing_meas AS measurement,
           SUM(inv.quantity) AS quantity_left
    FROM ingredients ing
    JOIN inventary inv ON ing.ing_id = inv.ing_id
    GROUP BY ing.ing_id, ing.ing_name, ing.ing_weight, ing.ing_meas
)
SELECT *
FROM ing_quantity
WHERE quantity_left < 5
ORDER BY quantity_left ASC;

-- Q17: Estimate the number of shifts a staff member has worked since the beginning of the year

WITH ordered_shifts AS (
    SELECT staff_id,
           date,
           ROW_NUMBER() OVER (PARTITION BY staff_id ORDER BY date) AS rn
    FROM rota
    WHERE date >= '2024-01-01'
)
SELECT staff_id,
       MAX(rn) AS total_shifts_worked
FROM ordered_shifts
GROUP BY staff_id
ORDER BY total_shifts_worked ASC;

-- Q18: Identify Frequently Ordered Menu Item Chains like Coffee -> Muffin -> Cookies

-- Chains of length 2
SELECT CONCAT(mi1.item_name, '->', mi2.item_name) AS item_chain,
       COUNT(*) AS frequency,
       2 AS chain_length
FROM orders o1
JOIN orders o2 ON o1.order_id = o2.order_id AND o1.item_id < o2.item_id
JOIN menu_items mi1 ON o1.item_id = mi1.item_id
JOIN menu_items mi2 ON o2.item_id = mi2.item_id
GROUP BY item_chain

UNION ALL

-- Chains of length 3
SELECT CONCAT(mi1.item_name, '->', mi2.item_name, '->', mi3.item_name) AS item_chain,
       COUNT(*) AS frequency,
       3 AS chain_length
FROM orders o1
JOIN orders o2 ON o1.order_id = o2.order_id AND o1.item_id < o2.item_id
JOIN orders o3 ON o1.order_id = o3.order_id AND o2.item_id < o3.item_id
JOIN menu_items mi1 ON o1.item_id = mi1.item_id
JOIN menu_items mi2 ON o2.item_id = mi2.item_id
JOIN menu_items mi3 ON o3.item_id = mi3.item_id
GROUP BY item_chain
ORDER BY chain_length DESC, frequency DESC;

-- Q19: Find customers with 10+ orders spread over 5 or more days for loyalty rewards

SELECT cust_name,
       COUNT(*) AS total_orders,
       COUNT(DISTINCT DATE(created_at)) AS distinct_order_days
FROM orders
GROUP BY cust_name
HAVING COUNT(*) >= 10 
   AND COUNT(DISTINCT DATE(created_at)) >= 5;
   
-- Q20: Most popular menu items by time of day (morning, afternoon, evening)

WITH orders_by_time AS (
    SELECT item_id,
           CASE 
               WHEN HOUR(created_at) BETWEEN 5 AND 11 THEN 'Morning'
               WHEN HOUR(created_at) BETWEEN 12 AND 16 THEN 'Afternoon'
               WHEN HOUR(created_at) BETWEEN 17 AND 20 THEN 'Evening'
           END AS time_of_day
    FROM orders
),
item_counts AS (
    SELECT item_id,
           time_of_day,
           COUNT(*) AS order_count
    FROM orders_by_time
    WHERE time_of_day IS NOT NULL
    GROUP BY item_id, time_of_day
),
ranked_items AS (
    SELECT item_id,
           time_of_day,
           order_count,
           ROW_NUMBER() OVER (
               PARTITION BY time_of_day 
               ORDER BY order_count DESC
           ) AS rn
    FROM item_counts
)
SELECT ri.time_of_day,
       ri.item_id,
       COALESCE(mi.item_name, 'No Data') AS item_name,
       ri.order_count
FROM ranked_items ri
LEFT JOIN menu_items mi 
       ON ri.item_id = mi.item_id
WHERE ri.rn = 1
ORDER BY FIELD(ri.time_of_day, 'Morning', 'Afternoon', 'Evening');

-- Q21: Find employees working during the highest-revenue shifts.

WITH shift_revenue AS (
    SELECT r.shift_id,
           r.date AS shift_date,
           SUM(o.quantity * mi.item_price) AS total_shift_revenue
    FROM orders o
    JOIN menu_items mi ON o.item_id = mi.item_id
    JOIN rota r ON DATE(o.created_at) = r.date
    JOIN shift s ON r.shift_id = s.shift_id
    WHERE TIME(o.created_at) BETWEEN s.start_time AND s.end_time
    GROUP BY r.shift_id, r.date
),
max_revenue AS (
    SELECT MAX(total_shift_revenue) AS max_rev
    FROM shift_revenue
)	
SELECT sr.shift_id,
       r.staff_id,
       sr.shift_date,
       sr.total_shift_revenue
FROM shift_revenue sr
JOIN rota r 
     ON sr.shift_id = r.shift_id 
    AND sr.shift_date = r.date
JOIN max_revenue mr 
     ON sr.total_shift_revenue = mr.max_rev;

-- Q22: Rank employees based on their total revenue generated across all shifts.

WITH employee_revenue AS (
    SELECT r.staff_id, 
           COUNT(DISTINCT o.order_id) AS total_orders, 
           SUM(o.quantity) AS total_quantity, 
           SUM(o.quantity * mi.item_price) AS total_revenue, 
           AVG(mi.item_price) AS avg_item_price
    FROM orders o
    JOIN menu_items mi ON o.item_id = mi.item_id
    JOIN rota r        ON DATE(o.created_at) = r.date
    JOIN shift s       ON r.shift_id = s.shift_id
    WHERE TIME(o.created_at) BETWEEN s.start_time AND s.end_time
    GROUP BY r.staff_id
)
SELECT staff_id, 
       total_orders, 
       total_quantity, 
       total_revenue, 
       avg_item_price,
       RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM employee_revenue
ORDER BY revenue_rank;
