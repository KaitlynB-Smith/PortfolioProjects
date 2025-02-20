---------------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------- DATA CLEANING AND EXPLORATION WITH SQL ------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------ DATA CLEANING ------------------------------------------------------------------

-- Find and Delete Duplicates
-- Identify Any Missing Values
-- Populate Missing Values
-- Standardize Formats
-- Create New Columns

---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------- FINDING UNIQUE VALUES -------------------------
-- 'Category' - 8 Unique Values
-- 'Item' - 201 Unique Values
-- 'Price_Per_Unit' - 26 Unique Values
-- 'Quantity' - 11 Unique Values
-- 'Total_Spent' - 228 Unique Values
-- 'Payment_Method' - 3 Unique Values
-- 'Location' - 2 Unique Values
-- 'Transaction_Date' - 1114 Unique Values
-- 'Discount_Applied' - 3 Unique Values

SELECT 
	COUNT(DISTINCT Transaction_ID) AS Transaction_ID,
	COUNT(DISTINCT Customer_ID) AS Customer_ID, 
	COUNT(DISTINCT Category) AS Category, 
	COUNT(DISTINCT Item) AS Item, 
	COUNT(DISTINCT Price_Per_Unit) AS Price_Per_Unit, 
	COUNT(DISTINCT Quantity) AS Quantity, 
	COUNT(DISTINCT Total_Spent) AS Total_Spent, 
	COUNT(DISTINCT Payment_Method) AS Payment_Method, 
	COUNT(DISTINCT Location) AS Location, 
	COUNT(DISTINCT Transaction_Date) AS Transaction_Date, 
	COUNT(DISTINCT Discount_Applied) AS Discount_Applied
FROM PortfolioProject.dbo.retail_store_sales

---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------- FINDING AND DELETING DUPLICATES -------------------------

-- No Duplicates Found 

SELECT COUNT(DISTINCT Transaction_ID)
FROM PortfolioProject.dbo.retail_store_sales

---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------- IDENTIFYING MISSING VALUES -------------------------

-- 'Item' - 1213 nulls
-- 'Price_Per_Unit' - 609 nulls
-- 'Quantity' - 604 nulls
-- 'Total_Spent' - 604 nulls
-- 'Discount_Applied' - 4199 nulls

SELECT 
	SUM(CASE WHEN Transaction_ID IS NULL THEN 1 ELSE 0 END) AS Transaction_ID_Nulls,
	SUM(CASE WHEN Customer_ID IS NULL THEN 1 ELSE 0 END) AS Customer_ID_Nulls,
	SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS Category_Nulls,
	SUM(CASE WHEN Item IS NULL THEN 1 ELSE 0 END) AS Item_Nulls,
	SUM(CASE WHEN Price_Per_Unit IS NULL THEN 1 ELSE 0 END) AS Price_Per_Unit_Nulls,
	SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS Quantity_Nulls,
	SUM(CASE WHEN Total_Spent IS NULL THEN 1 ELSE 0 END) AS Total_Spent_Nulls,
	SUM(CASE WHEN Payment_Method IS NULL THEN 1 ELSE 0 END) AS Payment_Method_Nulls,
	SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS Locationt_Nulls,
	SUM(CASE WHEN Transaction_Date IS NULL THEN 1 ELSE 0 END) AS Transaction_Date_Nulls,
	SUM(CASE WHEN Discount_Applied IS NULL THEN 1 ELSE 0 END) AS Discount_Applied_Nulls
FROM PortfolioProject.dbo.retail_store_sales

---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------- REPOPULATING MISSING VALUES -------------------------

-- Populate null values in 'Item', 'Price_Per_Unit', 'Quantity', and 'Total_Spent' 

----- PRICE_PER_UNIT -----
-- Populate null values using the equation ('Total_Spent')/('Quantity') = 'Price_Per_Unit'

SELECT	
	Price_Per_Unit,
	Total_Spent / Quantity AS Price_Per_Unit_2,
	Quantity,
	Total_Spent
FROM PortfolioProject.dbo.retail_store_sales
WHERE Price_Per_Unit IS NULL

UPDATE PortfolioProject.dbo.retail_store_sales
SET Price_Per_Unit = Total_Spent / Quantity
WHERE Price_Per_Unit IS NULL


----- ITEM  ----- 
-- Create a column with concatenated data from the 'Category' and 'Price_Per_Unit' columns called 'Category_Price_Per_Unit'

ALTER TABLE PortfolioProject.dbo.retail_store_sales
ADD Category_Price_Per_Unit nvarchar(50)

UPDATE PortfolioProject.dbo.retail_store_sales
SET Category_Price_Per_Unit = CONCAT(Category, '_', Price_Per_Unit)

-- Replace null 'Item' values with the values corresponding to matching 'Category_Price_Per_Unit' values by using a self-join

SELECT
    A.Category_Price_Per_Unit,
    A.Item AS A_Item,
    (SELECT TOP 1 B.Item 
     FROM PortfolioProject.dbo.retail_store_sales AS B
     WHERE B.Category_Price_Per_Unit = A.Category_Price_Per_Unit
       AND B.Item IS NOT NULL) AS FilledItem
FROM PortfolioProject.dbo.retail_store_sales AS A
WHERE A.Item IS NULL

UPDATE A
SET Item = (
	SELECT TOP 1 B.Item 
	FROM PortfolioProject.dbo.retail_store_sales AS B
	WHERE B.Category_Price_Per_Unit = A.Category_Price_Per_Unit
       AND B.Item IS NOT NULL
)	
FROM PortfolioProject.dbo.retail_store_sales AS A
WHERE A.Item IS NULL
	AND EXISTS (
		SELECT 1
		  FROM PortfolioProject.dbo.retail_store_sales AS B
		  WHERE B.Category_Price_Per_Unit = A.Category_Price_Per_Unit
			AND B.Item IS NOT NULL
	)


----- QUANTITY ----- 
-- Calculate the average quantity purchased for each combination of 'Customer_ID', 'Category', and 'Payment_Method'
-- Use these calculations to populate NULL values in Quantity, prioritizing the specific average for the customer's category and payment method
-- If no specific average exists for a type of payment method, use the average quantity across all payment methods for that customer and category
-- If no average was available for any payment method for the customer and category, populate the field with the customer's overall average quantity

SELECT *
FROM PortfolioProject.dbo.retail_store_sales
WHERE Quantity IS NULL

-- Create new column 'Imputed_Quantity' to contain the calculated quantities.

ALTER TABLE PortfolioProject.dbo.retail_store_sales
ADD Imputed_Quantity int

WITH ImputedQuantities AS (
	SELECT 
		r.Customer_ID,
		r.Category,
		r.Item,
		r.Quantity AS Original_Quantity,
		CAST(ROUND(COALESCE( 
			CASE r.Payment_Method
				WHEN 'Digital Wallet' THEN iq.Avg_Digital_Wallet
				WHEN 'Credit Card' THEN iq.Avg_Credit_Card
				WHEN 'Cash' THEN iq.Avg_Cash
				ELSE NULL
			END,
			iq.Avg_Quantity,
			(SELECT AVG(Quantity) FROM PortfolioProject.dbo.retail_store_sales WHERE Customer_ID = r.Customer_ID)
		), 0) AS int) AS Imputed_Quantity
	FROM PortfolioProject.dbo.retail_store_sales AS r
	INNER JOIN (
		SELECT 
			Customer_ID,
			Category,
			Item, 
			AVG(Quantity) AS Avg_Quantity,
			AVG(CASE WHEN Payment_Method = 'Digital Wallet' THEN Quantity ELSE NULL END) AS Avg_Digital_Wallet,
			AVG(CASE WHEN Payment_Method = 'Credit Card' THEN Quantity ELSE NULL END) AS Avg_Credit_Card,
			AVG(CASE WHEN Payment_Method = 'Cash' THEN Quantity ELSE NULL END) AS Avg_Cash
		FROM PortfolioProject.dbo.retail_store_sales 
		GROUP BY
			Customer_ID, 
			Category, 
			Item
	) AS iq
		ON r.Customer_ID = iq.Customer_ID
		AND r.Category = iq.Category
		AND r.Item = iq.Item
	WHERE r.Quantity IS NULL
)
UPDATE r
SET r.Imputed_Quantity = iq.Imputed_Quantity
FROM PortfolioProject.dbo.retail_store_sales AS r
INNER JOIN ImputedQuantities AS iq
	ON r.Customer_ID = iq.Customer_ID
	AND r.Category = iq.Category
	AND r.Item = iq.Item
WHERE r.Quantity IS NULL


-- Creating new column 'Combined_Quantity' to contain combined data from the 'Quantity' and 'Imputed_Quantity'


ALTER TABLE PortfolioProject.dbo.retail_store_sales
ADD Quantity_Combined int

UPDATE PortfolioProject.dbo.retail_store_sales
SET Quantity_Combined = COALESCE(CAST(Imputed_Quantity AS float), Quantity)


----- TOTAL_SPENT ----- 
-- Populate nulls using the equation ('Price_Per_Unit') * ('Quantity_Combined') = ('Imputed_Total_Spent')

SELECT *
FROM PortfolioProject.dbo.retail_store_sales
WHERE Total_Spent IS NULL

ALTER TABLE PortfolioProject.dbo.retail_store_sales
ADD Imputed_Total_Spent float

UPDATE PortfolioProject.dbo.retail_store_sales
SET Imputed_Total_Spent = Price_Per_Unit * Quantity_Combined


---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------- STANDARDIZING FORMATS -------------------------

----- TRANSACTION_DATE -----
-- Convert datatype from 'datetime' to 'date'

ALTER TABLE PortfolioProject.dbo.retail_store_sales
ALTER COLUMN Transaction_Date date

UPDATE PortfolioProject.dbo.
SET Transaction_Date = CAST(Transaction_Date AS date)


----- DISCOUNT_APPLIED -----
-- Convert datatype from 'bit' to 'nvarchar(50)' - replace '0' with 'No', replace '1' with 'Yes'

ALTER TABLE PortfolioProject.dbo.retail_store_sales
ALTER COLUMN Discount_Applied nvarchar(50)

UPDATE PortfolioProject.dbo.retail_store_sales
SET Discount_Applied = CASE 
		 WHEN Discount_Applied = '0' THEN 'No'
		 WHEN Discount_Applied = '1' THEN 'Yes'
		 ELSE Discount_Applied
		 END

---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------- CREATING NEW COLUMNS -------------------------

----- WEEK_DAY -----
-- Create a column for the day of the week of the transaction

ALTER TABLE PortfolioProject.dbo.retail_store_sales
ADD Week_Day nvarchar(50)

UPDATE PortfolioProject.dbo.retail_store_sales
SET Week_Day = DATENAME(dw, Transaction_Date)

----- MONTH -----
-- Create a column for the month of the transaction

ALTER TABLE PortfolioProject.dbo.retail_store_sales
ADD Month nvarchar(50)

UPDATE PortfolioProject.dbo.retail_store_sales
SET Month = DATENAME(mm, Transaction_Date)


---------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------ DATA EXPLORATION ---------------------------------------------------------------

-- Temporal Analysis
-- Transaction Overview
-- Customer Behavior
-- Product Analysis
-- Payment Method Analysis
-- Location Analysis


----- TEMPORAL ANALYSIS -----
-- On average, Fridays generated greater revenue

SELECT 
	Week_Day,
	AVG(Imputed_Total_Spent) AS Avg_Spent
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY Week_Day
Order BY AVG(Imputed_Total_Spent) DESC

-- January generated the greatest revenue on average

SELECT 
	Month,
	AVG(Imputed_Total_Spent) AS Avg_Spent
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY Month
Order BY AVG(Imputed_Total_Spent) DESC

----- TRANSACTION OVERVIEW -----
-- Customers spent between 5 and 410 dollars per transaction with an average of 130 dollars spent per transaction

SELECT 
	AVG(Imputed_Total_Spent) AS Avg_Spent,
	MAX(Imputed_Total_Spent) AS Max_Spent,
	MIN(Imputed_Total_Spent) AS Min_Spent
FROM PortfolioProject.dbo.retail_store_sales

-- The greatest number of transactions occurred in 2024, with the fewest in 2025

SELECT 
	YEAR(Transaction_Date) AS Year,
	COUNT(Transaction_ID) AS Transactions
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY YEAR(Transaction_Date) 
ORDER BY COUNT(Transaction_ID) DESC

-- Observing only the month of January, 2025 has the fewest amount of transactions and the lowest amount spent per transaction

SELECT 
	YEAR(Transaction_Date) AS Year,
	COUNT(Transaction_ID) AS Transactions,
	ROUND(SUM(Imputed_Total_Spent) / COUNT(Transaction_ID), 2) AS Avg_Spent
FROM PortfolioProject.dbo.retail_store_sales
WHERE Month = 'January' 
GROUP BY YEAR(Transaction_Date) 
ORDER BY COUNT(Transaction_ID) DESC

-- Customers spent between 122.17 - 138.06 per transaction

SELECT 
	Customer_ID, 
	ROUND(AVG(Imputed_Total_Spent), 2) AS Avg_Spent,
	COUNT(Transaction_ID) AS Num_of_Transactions,
	MIN(Transaction_Date) AS From_Date,
	MAX(Transaction_Date) AS To_Date
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY Customer_ID
ORDER BY Avg_Spent DESC

----- CATEGORY ANALYSIS -----
-- The butcher's category yielded the highest sales with an average of 25.25 dollars being spent per item

SELECT 
	Category,
	SUM(Imputed_Total_Spent) AS Total_Spent,
	COUNT(Transaction_ID) AS Count_Transactions, 
	SUM(Quantity_Combined) AS Quantity, 
	SUM(Imputed_Total_Spent) / SUM(Quantity_Combined) AS Avg_Spent_Per_Item
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY Category
ORDER BY SUM(Imputed_Total_Spent) DESC

-- Top 5 items sold in each category by count of transaction ID

WITH Ranked_Items_Count AS (
	SELECT 
		Category,
		Item,
		COUNT(Transaction_ID) AS Transactions,
		ROW_NUMBER() OVER(PARTITION BY Category ORDER BY COUNT(Transaction_ID) DESC) AS Rank
	FROM PortfolioProject.dbo.retail_store_sales
	GROUP BY Category, Item
)
SELECT 
	Category,
	Item,
	Transactions,
	Rank
FROM Ranked_Items_Count
WHERE Rank <= 5
ORDER BY Category, Rank ASC

-- Top 5 items sold in each category by total revenue

WITH Ranked_Items_Sum AS (
	SELECT 
		Category,
		Item,
		SUM(Imputed_Total_Spent) AS Total_Spent,
		ROW_NUMBER() OVER(PARTITION BY Category ORDER BY SUM(Imputed_Total_Spent) DESC) AS Rank
	FROM PortfolioProject.dbo.retail_store_sales
	GROUP BY Category, Item
)
SELECT 
	Category,
	Item,
	Total_Spent,
	Rank
FROM Ranked_Items_Sum
WHERE Rank <= 5
ORDER BY Category, Rank ASC

----- PRODUCT ANALYSIS -----

-- Most popular items by quantity

WITH Ranked_Items_Quantity AS (
	SELECT 
		Item,
		SUM(Quantity_Combined) AS Quantity,
		ROW_NUMBER() OVER(ORDER BY SUM(Quantity_Combined) DESC) AS Rank
	FROM PortfolioProject.dbo.retail_store_sales
	GROUP BY Item
)
SELECT 
	Item,
	Quantity,
	Rank
FROM Ranked_Items_Quantity
WHERE Rank <= 10
ORDER BY Rank ASC

-- Most popular items by revenue

WITH Ranked_Items_Revenue AS (
	SELECT 
		Item,
		SUM(Imputed_Total_Spent) AS Revenue,
		ROW_NUMBER() OVER(ORDER BY SUM(Imputed_Total_Spent) DESC) AS Rank
	FROM PortfolioProject.dbo.retail_store_sales
	GROUP BY Item
)
SELECT 
	Item,
	Revenue,
	Rank
FROM Ranked_Items_Revenue
WHERE Rank <= 10
ORDER BY Rank ASC

----- PAYMENT METHOD ANALYSIS -----
-- The most commonly used payment method was cash, and the average transaction value was the greatest for cash.

SELECT 
	Payment_Method,
	COUNT(Payment_Method) AS Count_Payment_Method, 
	AVG(Imputed_Total_Spent) AS Avg_Transaction_Value
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY Payment_Method


-- In-store cash sales occurred most often and generated the highest total revenue

SELECT 
	Payment_Method,
	Location,
	COUNT(Payment_Method) AS Count_Payment_Method, 
	SUM(Imputed_Total_Spent) AS Sum_Transaction_Value
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY Payment_Method, Location
ORDER BY SUM(Imputed_Total_Spent) DESC

----- LOCATION ANALYSIS -----

-- More purchases occurred online as opposed to in-store.
-- Online sales also generated greater revenue

SELECT 
	Location,
	COUNT(Transaction_ID) AS Count_Transactions, 
	AVG(Imputed_Total_Spent) AS Avg_Spent,
	SUM(Imputed_Total_Spent) AS Total_Spent
FROM PortfolioProject.dbo.retail_store_sales
GROUP BY Location

-- Top 10 most popular items by quantity at each location

WITH Ranked_Items_Location AS (
	SELECT 
		Item,
		Location,
		SUM(Quantity_Combined) AS Sum_Quantity,
		ROW_NUMBER() OVER(PARTITION BY Location ORDER BY SUM(Quantity_Combined) DESC) AS Rank
	FROM PortfolioProject.dbo.retail_store_sales
	GROUP BY Location, Item
)
SELECT 
	Item,
	Location,
	Sum_Quantity,
	Rank
FROM Ranked_Items_Location
WHERE Rank <= 10
ORDER BY Location, Rank ASC

-- Top 10 most popular items by revenue at each location

WITH Ranked_Items_Location AS (
	SELECT 
		Item,
		Location,
		SUM(Imputed_Total_Spent) AS Total_Spent,
		ROW_NUMBER() OVER(PARTITION BY Location ORDER BY SUM(Imputed_Total_Spent) DESC) AS Rank
	FROM PortfolioProject.dbo.retail_store_sales
	GROUP BY Location, Item
)
SELECT 
	Item,
	Location,
	Total_Spent,
	Rank
FROM Ranked_Items_Location
WHERE Rank <= 10
ORDER BY Location, Rank ASC


