-- Databricks notebook source
--The metrics that you need to develop are:
--1. What is the daily sales price per unit?
--2. What is the average unit sales price of this product?
--3. What is the daily % gross profit?
--4. What is the daily % gross profit per unit?
--5. Pick any 3 periods during which this product was on promotion/special
--a. What was the Price Elasticity of Demand during each of these periods?
--b. In your opinion, does this product perform better or worse when sold at a promotional price?

--Data Inspection
SELECT
  *
FROM
  fnb_sales.data.sales_dataset;

--Dataset contains 1053 rows and four columns. Date is in timestamp formt,
--sales and cost of sales are decimals and quantity sold is an interger.
--Data was over a 3 year peiod (from December 2013 to November 2016).
-------------------------------------------------------------------------
--Checking for Null values
SELECT
  *
FROM
  fnb_sales.data.sales_dataset
WHERE
  Date IS NULL
  OR Sales IS NULL
  OR `Cost Of Sales` IS NULL
  OR `Quantity Sold` IS NULL;

--It shows that there are no nulls in the dataset
-------------------------------------------------------------------------
--Checking for duplicates
SELECT
  Date,
  Sales,
  `Cost Of Sales`,
  `Quantity Sold`,
  COUNT(*) as duplicate_count
FROM
  fnb_sales.data.sales_dataset
GROUP BY
  Date,
  Sales,
  `Cost Of Sales`,
  `Quantity Sold`
HAVING
  COUNT(*) > 1;

--There are no duplicate columns
--------------------------------------------------------------------------

--Calculating daily sales price per unit
SELECT Date,
       Sales,
       `Quantity Sold`,
       Sales/`Quantity Sold` AS `Unit Price`
From fnb_sales.data.sales_dataset
ORDER BY Date;
--------------------------------------------------------------------------

--Calculating the average unit sales price
SELECT ROUND(AVG(Sales/`Quantity Sold`), 2) AS `AVG Unit Price`
FROM fnb_sales.data.sales_dataset;
--------------------------------------------------------------------------

--Calculating daily gross profit
SELECT Date,
       Sales,
       `Cost Of Sales`,
       ROUND ((Sales-`Cost Of Sales`),2) AS `Daily Gross Profit`
FROM fnb_sales.data.sales_dataset;
--------------------------------------------------------------------------       
---Calculating the daily % gross profit
SELECT Date,
       Sales,
      ROUND(((Sales-`Cost of Sales`)/Sales)*100, 2) AS `Daily % Gross Profit`
FROM fnb_sales.data.sales_dataset;
----------------------------------------------------------------------------------------------------------

--Calculating the daily % gross profit per unit
SELECT Date,
       Sales,
       `Cost Of Sales`,
       `Quantity Sold`,
       ROUND(((Sales-`Cost of Sales`)/`Quantity Sold`)/(Sales/`Quantity Sold`)*100, 2) AS `Daily % Gross Profit Per Unit`
FROM fnb_sales.data.sales_dataset;
-------------------------------------------------------------------------

--Calculaating total revenue
SELECT Date, 
       ROUND ((Sales/`Quantity Sold`*`Quantity Sold`), 2) AS Revenue
FROM fnb_sales.data.sales_dataset;
-------------------------------------------------------------------------
SELECT
    Date,
    Sales,
    LAG(Sales) OVER (
        ORDER BY Date
    ) AS previous_sale,
    
    Sales - previous_sale AS sales_change,

    CASE
        WHEN Sales > previous_sale THEN 'Growth'
        WHEN Sales < previous_sale THEN 'Decline'
    END AS sales_indicator
    FROM fnb_sales.data.sales_dataset;

--Extracting year, month, day and dayname from the date column
SELECT 
        YEAR (Date) AS Transaction_year,
        DATE_FORMAT(Date, 'MMMM') AS Transaction_month,
        DATE_FORMAT (Date, 'dd') AS Transaction_day,
        DAYNAME (Date) AS Transaction_dayname
FROM  fnb_sales.data.sales_dataset;
-------------------------------------------------------------------------

--Selecting periods when product was on promotion using average price
--First set the price to which the price was 10% less than the average price to allow for 10% discount price.
SELECT Date, 
       Sales, 
       `Quantity Sold`,
       CASE 
           WHEN (Sales/`Quantity Sold`) < 37.07 * 0.90 THEN 'Promotion'
           ELSE 'Non-promotion'
       END AS `Promotion Status`
FROM fnb_sales.data.sales_dataset;
--------------------------------------------------------------------------
--Creating date time buckets for promotion and non-promotion periods periods 
SELECT Date,
       `Quantity Sold`,
       CASE
           WHEN Date BETWEEN '2013-12-30' AND '2014-01-07' THEN 'Promotion period 1'
           WHEN Date BETWEEN '2014-02-07' AND '2014-02-17' THEN 'Promotion period 2'
           WHEN Date BETWEEN '2014-02-21' AND '2014-03-17' THEN 'Promotion period 3'
           WHEN Date BETWEEN '2014-04-10' AND '2014-04-22' THEN 'Promotion period 4'
           Else 'Non Promotion'
END AS `Promotion Period`
FROM fnb_sales.data.sales_dataset;
--------------------------------------------------------------------------
-- Calculating Price Elasticity of Demand for Promotion Periods

-- Step 1: Calculating metrics for each period (promotion vs baseline) using a CTE
WITH period_metrics AS (
  SELECT 
    CASE
      WHEN Date BETWEEN '2013-12-30' AND '2014-01-07' THEN 'Promotion_1'
      WHEN Date BETWEEN '2014-02-07' AND '2014-02-17' THEN 'Promotion_2'
      WHEN Date BETWEEN '2014-02-21' AND '2014-03-17' THEN 'Promotion_3'
      WHEN Date BETWEEN '2014-04-10' AND '2014-04-22' THEN 'Promotion_4'
      ELSE 'Baseline'
    END AS Period,
    AVG(Sales / `Quantity Sold`) AS Avg_Unit_Price,
    AVG(`Quantity Sold`) AS Avg_Quantity_Sold
  FROM fnb_sales.data.sales_dataset
  GROUP BY 
    CASE
      WHEN Date BETWEEN '2013-12-30' AND '2014-01-07' THEN 'Promotion_1'
      WHEN Date BETWEEN '2014-02-07' AND '2014-02-17' THEN 'Promotion_2'
      WHEN Date BETWEEN '2014-02-21' AND '2014-03-17' THEN 'Promotion_3'
      WHEN Date BETWEEN '2014-04-10' AND '2014-04-22' THEN 'Promotion_4'
      ELSE 'Baseline'
    END
),

-- Step 2: Geting baseline metrics for comparison
baseline AS (
  SELECT 
    Avg_Unit_Price AS Baseline_Price,
    Avg_Quantity_Sold AS Baseline_Quantity
  FROM period_metrics
  WHERE Period = 'Baseline'
)

-- Step 3: Calculating Price Elasticity of Demand for each promotion period
SELECT 
  pm.Period,
  ROUND(pm.Avg_Unit_Price, 2) AS Promotion_Avg_Price,
  ROUND(b.Baseline_Price, 2) AS Baseline_Avg_Price,
  ROUND(pm.Avg_Quantity_Sold, 2) AS Promotion_Avg_Quantity,
  ROUND(b.Baseline_Quantity, 2) AS Baseline_Avg_Quantity,
  ROUND(((pm.Avg_Unit_Price - b.Baseline_Price) / b.Baseline_Price) * 100, 2) AS Percent_Price_Change,
  ROUND(((pm.Avg_Quantity_Sold - b.Baseline_Quantity) / b.Baseline_Quantity) * 100, 2) AS Percent_Quantity_Change,
  ROUND(((pm.Avg_Quantity_Sold - b.Baseline_Quantity) / b.Baseline_Quantity) / ((pm.Avg_Unit_Price - b.Baseline_Price) / b.Baseline_Price), 2) AS `Price Elasticity of Demand`
FROM period_metrics pm
CROSS JOIN baseline b
WHERE pm.Period != 'Baseline'
ORDER BY pm.Period;
--------------------------------------------------------------------------
-- Building the Big Query with all calculated metrics including Price Elasticity

-- Calculating metrics for each period
WITH period_metrics_big AS (
  SELECT 
    CASE
      WHEN Date BETWEEN '2013-12-30' AND '2014-01-07' THEN 'Promotion_1'
      WHEN Date BETWEEN '2014-02-07' AND '2014-02-17' THEN 'Promotion_2'
      WHEN Date BETWEEN '2014-02-21' AND '2014-03-17' THEN 'Promotion_3'
      WHEN Date BETWEEN '2014-04-10' AND '2014-04-22' THEN 'Promotion_4'
      ELSE 'Baseline'
    END AS Period_Key,
    AVG(Sales / `Quantity Sold`) AS Avg_Unit_Price,
    AVG(`Quantity Sold`) AS Avg_Quantity_Sold
  FROM fnb_sales.data.sales_dataset
  GROUP BY 
    CASE
      WHEN Date BETWEEN '2013-12-30' AND '2014-01-07' THEN 'Promotion_1'
      WHEN Date BETWEEN '2014-02-07' AND '2014-02-17' THEN 'Promotion_2'
      WHEN Date BETWEEN '2014-02-21' AND '2014-03-17' THEN 'Promotion_3'
      WHEN Date BETWEEN '2014-04-10' AND '2014-04-22' THEN 'Promotion_4'
      ELSE 'Baseline'
    END
),

-- Getting baseline metrics
baseline_big AS (
  SELECT 
    Avg_Unit_Price AS Baseline_Price,
    Avg_Quantity_Sold AS Baseline_Quantity
  FROM period_metrics_big
  WHERE Period_Key = 'Baseline'
),

-- Calculating Price Electricity of Demand (PED) for each period
elasticity_by_period AS (
  SELECT 
    pm.Period_Key,
    ROUND(
      ((pm.Avg_Quantity_Sold - b.Baseline_Quantity) / b.Baseline_Quantity) / 
      ((pm.Avg_Unit_Price - b.Baseline_Price) / b.Baseline_Price)
    , 2) AS Price_Elasticity_of_Demand
  FROM period_metrics_big pm
  CROSS JOIN baseline_big b
  WHERE pm.Period_Key != 'Baseline'
)

-- Building the main query with all metrics
SELECT 
       d.Date,
       YEAR(d.Date) AS Transaction_year,
       DATE_FORMAT(d.Date, 'MMMM') AS Transaction_month,
       DATE_FORMAT(d.Date, 'dd') AS Transaction_day,
       DAYNAME(d.Date) AS Transaction_dayname,
       ROUND ((d.`Quantity Sold`), 2) AS `Quantity Sold`,
       Round ((d.Sales), 2) AS Sales,
       Round ((d.Sales / d.`Quantity Sold`), 2) AS `Unit Price`,
       ROUND ((d.`Cost Of Sales`), 2) AS `Cost Of Sales`,
       ROUND((d.Sales - d.`Cost Of Sales`), 2) AS `Daily Gross Profit`,
       ROUND(((d.Sales - d.`Cost of Sales`) / d.Sales) * 100, 2) AS `Daily % Gross Profit`,
       ROUND(((d.Sales - d.`Cost of Sales`) / d.`Quantity Sold`) / (d.Sales / d.`Quantity Sold`) * 100, 2) AS `Daily % Gross Profit Per Unit`,

       CASE 
           WHEN (d.Sales / d.`Quantity Sold`) < 37.07 * 0.90 THEN 'Promotion'
           ELSE 'Non-promotion'
       END AS `Promotion Status`,
       CASE
           WHEN d.Date BETWEEN '2013-12-30' AND '2014-01-07' THEN 'Promotion period 1'
           WHEN d.Date BETWEEN '2014-02-07' AND '2014-02-17' THEN 'Promotion period 2'
           WHEN d.Date BETWEEN '2014-02-21' AND '2014-03-17' THEN 'Promotion period 3'
           WHEN d.Date BETWEEN '2014-04-10' AND '2014-04-22' THEN 'Promotion period 4'
           ELSE 'Non Promotion'
       END AS `Promotion Period`,
       e.Price_Elasticity_of_Demand AS `Price Elasticity of Demand`,
       ROUND(LAG(d.Sales - d.`Cost Of Sales`) OVER (ORDER BY d.Date), 2) AS previous_gross_profit,
       ROUND((d.Sales - d.`Cost Of Sales`) - LAG(d.Sales - d.`Cost Of Sales`) OVER (ORDER BY d.Date), 2) AS gross_profit_change,
       CASE
           WHEN (d.Sales - d.`Cost Of Sales`) > LAG(d.Sales - d.`Cost Of Sales`) OVER (ORDER BY d.Date) THEN 'Growth'
           WHEN (d.Sales - d.`Cost Of Sales`) < LAG(d.Sales - d.`Cost Of Sales`) OVER (ORDER BY d.Date) THEN 'Decline'
           ELSE 'No Change'
       END AS gross_profit_indicator
FROM fnb_sales.data.sales_dataset d
LEFT JOIN elasticity_by_period e
  ON CASE
       WHEN d.Date BETWEEN '2013-12-30' AND '2014-01-07' THEN 'Promotion_1'
       WHEN d.Date BETWEEN '2014-02-07' AND '2014-02-17' THEN 'Promotion_2'
       WHEN d.Date BETWEEN '2014-02-21' AND '2014-03-17' THEN 'Promotion_3'
       WHEN d.Date BETWEEN '2014-04-10' AND '2014-04-22' THEN 'Promotion_4'
     END = e.Period_Key
ORDER BY d.Date;