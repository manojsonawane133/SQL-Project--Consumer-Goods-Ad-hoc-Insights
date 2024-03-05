-- database used for this gdb023
use gdb023;
# import data from sql
 
-- --------------------------------------------------------------------------------------------
# Q.1 Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC regions

SELECT DISTINCT market 
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC";
-- --------------------------------------------------------------------------------------------
# Q.2 What is the percentage of Unique product increase in 2021 vs 2020
-- unique_products 2020
-- unique products 2021 
-- pct change

-- creating cte
with cte1 as(
select count(distinct(product_code)) as product_in_2020
from  fact_gross_price
where fiscal_year = 2020),  -- 245
cte2 as (
select count(distinct(product_code)) as product_in_2021
from  fact_gross_price
where fiscal_year = 2021)  -- 334
select cte1.product_in_2020,cte2.product_in_2021,
(cte2.product_in_2021-cte1.product_in_2020) as change_in_products,
round(((cte2.product_in_2021-cte1.product_in_2020)/cte1.product_in_2020*100),2) as pct_change
from cte1,cte2;
-- --------------------------------------------------------------------------------------------
# Q.3 Provide a report with all unique product counts for each segment and sort them in descending order of product counts
-- segment & product_count

select count( distinct product_code) as unique_product_count
from dim_product; -- 397

select segment, 
	   count( distinct product_code) as unique_product_count
from dim_product
group by segment
order by unique_product_count desc ; 
-- --------------------------------------------------------------------------------------------
# Q.4 follow up : which segment had the most increase in unique products in 2021 vs 2020 ?
-- segment
-- product count 2020
-- product count 2021
-- difference 

WITH cte1 AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN s.fiscal_year = 2020 THEN s.product_code END) AS unique_product_count_2020,
        COUNT(DISTINCT CASE WHEN s.fiscal_year = 2021 THEN s.product_code END) AS unique_product_count_2021,
        p.segment
    FROM fact_sales_monthly AS s
    JOIN dim_product AS p 
    ON s.product_code = p.product_code
    WHERE s.fiscal_year IN (2020, 2021)
    GROUP BY p.segment)
SELECT 
    segment,
    unique_product_count_2020,
    unique_product_count_2021,
    unique_product_count_2021 - unique_product_count_2020 AS difference
FROM cte1;
-- --------------------------------------------------------------------------------------------
# Q.5 Get the products that have highest and lowest manufacturing costs
-- product_code, product, manufacturing_cost
with cte as (
select m.product_code,p.product,m.manufacturing_cost,
		dense_rank() over (order by m.manufacturing_cost desc) as highest_cost,
		dense_rank() over (order by m.manufacturing_cost asc) as lowest_cost
from fact_manufacturing_cost as m
join dim_product as p
on m.product_code = p.product_code
)
select product_code, product ,manufacturing_cost
from cte 
where highest_cost=1 or lowest_cost = 1;
-- --------------------------------------------------------------------------------------------

# Q.6 Generate a report which contains the top 5 customer who received an average high pre_invoice_discount_pct
# for the fiscal_year 2021 and in the indian_market
-- customer_code
-- customer
-- average_discount_percentage

WITH cte AS (
    SELECT c.customer_code, c.customer,
        ROUND(AVG(pid.pre_invoice_discount_pct)*100, 2) AS average_discount_percentage,
        DENSE_RANK() OVER (ORDER BY AVG(pid.pre_invoice_discount_pct) DESC) AS ranking
    FROM fact_pre_invoice_deductions AS pid
    JOIN dim_customer AS c ON pid.customer_code = c.customer_code
    WHERE c.market = 'India' AND pid.fiscal_year = 2021
    GROUP BY c.customer_code, c.customer
)
SELECT customer_code,customer, average_discount_percentage
FROM cte
WHERE ranking <= 5;


-- -------------------------------------------------------------------------------------------

/*
Q.7 Get the complete report for the gross sales amount for the customer 'AtliQ Exclusive' for each month.
This analysis helps to get an idea of low and high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount
*/
WITH cte AS (
    SELECT 
        MONTH(s.date) AS month_num,s.fiscal_year,
        ROUND(SUM(s.sold_quantity * gp.gross_price) / 1000000, 2) AS gross_sales_amount_millions
    FROM fact_gross_price AS gp
    JOIN fact_sales_monthly AS s 
    ON s.product_code = gp.product_code
    JOIN dim_customer AS c 
    ON s.customer_code = c.customer_code
    WHERE c.customer = 'Atliq Exclusive'
    GROUP BY month_num, fiscal_year
    ORDER BY fiscal_year, month_num asc
)
SELECT month_num AS 'month', fiscal_year, gross_sales_amount_millions
FROM cte;

-- -------------------------------------------------------------------------



/* 
Q.8 In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity. 
Quarter ,total_sold_quantity
*/

WITH cte AS (
  SELECT date,month(date_add(date,interval 4 month)) AS period, fiscal_year,sold_quantity 
FROM fact_sales_monthly
)
SELECT CASE 
   when period/3 <= 1 then "Q1"
   when period/3 <= 2 and period/3 > 1 then "Q2"
   when period/3 <=3 and period/3 > 2 then "Q3"
   when period/3 <=4 and period/3 > 3 then "Q4" END quarter,
 round(sum(sold_quantity)/1000000,2) as total_sold_quanity_in_millions FROM cte
WHERE fiscal_year = 2020
GROUP BY quarter
ORDER BY total_sold_quanity_in_millions DESC ;
-- --------------------------------------------------------------------------------

/*
Q.9 Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields,
channel
gross_sales_mln
percentage.
*/

WITH cte AS (
	SELECT c.channel,sum(s.sold_quantity * g.gross_price) AS total_sales
	FROM fact_sales_monthly s 
	JOIN fact_gross_price g 
    ON s.product_code = g.product_code
	JOIN dim_customer c
    ON s.customer_code = c.customer_code
	WHERE s.fiscal_year= 2021
	GROUP BY c.channel
	ORDER BY total_sales DESC
)
SELECT 
  channel,
  round(total_sales/1000000,2) AS gross_sales_in_millions,
  round(total_sales/(sum(total_sales) OVER())*100,2) AS percentage 
FROM cte ;


-- ---------------------------------------------------------------------------------------------


/*
Q.10 Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields,
division
product_code,
product,
total_sold_quantity
rank_order
*/

WITH RankedProducts AS (
    SELECT division, product_code, product, total_sold_quantity,
        ROW_NUMBER() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
    FROM (
        SELECT p.division, s.product_code, p.product, SUM(s.sold_quantity) AS total_sold_quantity
        FROM dim_product AS p
        JOIN fact_sales_monthly AS s 
        ON s.product_code = p.product_code
        WHERE s.fiscal_year = 2021
        GROUP BY p.division, s.product_code, p.product
    ) AS TotalSoldQuantityByProduct
)
SELECT division, product_code, product, total_sold_quantity, rank_order
FROM RankedProducts
WHERE rank_order <= 3;

-- ----------------------------------------------------------------------------------------