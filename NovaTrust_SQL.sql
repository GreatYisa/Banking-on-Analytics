SELECT TOP (1000) [CustomerID]
      ,[FirstName]
      ,[LastName]
      ,[DateOfBirth]
      ,[Contact_Email]
      ,[Contact_Phone]
      ,[Account_Type]
      ,[Account_Open_Date]
      ,[Account_Number]
      ,[Employment_Status]
  FROM [NovaTrust].[dbo].[Customers]

-- EDA
-- Explore Customers Table
SELECT COUNT(Account_Number) AS Count
FROM dbo.Customers;

-- Check for Null Valuees
SELECT
	*
FROM dbo.Customers c
WHERE c.Account_Number IS NULL
OR c.Account_Open_Date IS NULL
OR c.Account_Type IS NULL
OR c.Contact_Email IS NULL
OR c.Contact_Phone IS NULL
OR c.CustomerID IS NULL
OR c.DateOfBirth IS NULL
OR c.Employment_Status IS NULL

-- Check for duplicate
SELECT Account_Number, CustomerID, Contact_Email, COUNT(*) AS Counts
FROM dbo.Customers
GROUP BY Account_Number, CustomerID, Contact_Email
HAVING COUNT(*) > 1

-- Check Emploment Status
SELECT DISTINCT Employment_Status, COUNT(*) AS Count
FROM dbo.Customers
GROUP BY Employment_Status

-- Explore Transaction Table
SELECT TOP 10 *
FROM [dbo].[transaction] 


-- Check for Oldest and recent transaction date
SELECT MIN(TransactionDate) MinDate,  MAX(TransactionDate) MaxDate
FROM [dbo].[transaction]

-- Check for Max & Min Transaction Amount
SELECT MIN(transaction_Amount) MinTransaction, MAX(transaction_Amount) MaxTransaction
FROM [dbo].[transaction]

SELECT TransactionType, COUNt(*) Count
FROM[dbo].[transaction]
GROUP BY TransactionType;

-- Create stored procedures
CREATE PROCEDURE GetCustomerSegment
	@EmploymentStatus NVARCHAR(50),
	@DateCriteria DATE,
	@TransDescription NVARCHAR(50)
AS
BEGIN
--Extract student customers with salaries
WITH Salaries AS(
SELECT c.Account_Number,
		t.TransactionID,
		t.TransactionDate,
		t.Transaction_Amount,
		t.TransDescription
FROM [dbo].[Customers] AS c
INNER JOIN [dbo].[transaction] AS t
ON c.Account_Number = t.AccountNumber
WHERE c.Employment_Status = @EmploymentStatus
AND LOWER(t.TransDescription) LIKE '%' + @Transdescription + '%'
AND t.TransactionDate >= DATEADD(MONTH, -12, @DateCriteria)
AND t.TransactionType = 'Credit'
),

/* 
Next thing i have to do is to compute the Recency, Frequency and Monetary transaction for this customers.
I will be Segmenting the customers based on different criteria, Will be using RFM model to do that. 
RFM model is a type of customer segmentation model that segment customers based on three different metrics 
Which are the RECENCY, FREQUENCY and MONETARY.
For the purpose of this project, 
1. RECENCY in normal sales term, it measures when was the last time the customer purchase a product from the company or business,
but for the purpose of this project, it calculate when was the last time the customer recieved salary into the bank account
2. FREQUENCY in normal sales term, it calculate how often the customer purchase from a company or business,
but for the purpose of this project, it calculate how often the customer recieve salary into their bank account.
3. MONETARY VALUE it indicate how much has the customer spent with the company over time,
so in this case is going to be how much has the customer recieve in salary deposit over time.
The RFM model is what i will be using to Segment our customers in this project
*/

-- calculate RFM Values
RFM AS(
SELECT Account_Number,
		MAX(TransactionDate) AS LastTransactionDate,
		DATEDIFF(MONTH, MAX(TransactionDate), @DateCriteria) AS Recency,
		COUNT(TransactionID) AS Frequency,
		AVG(Transaction_Amount) AS MonetaryValue
FROM Salaries
GROUP BY Account_Number
HAVING AVG(Transaction_Amount) >= 200000
),
-- Assign RFM Scores to each customer
RFM_Scores AS(
SELECT Account_Number,
		LastTransactionDate,
		Recency,
		Frequency,
		MonetaryValue,
	  CASE
			WHEN Recency = 0 THEN 10
			WHEN Recency < 3 THEN 7
			WHEN Recency < 5 THEN 4
			ELSE 1
	  END AS R_Score,
	 -- Score customers based on their Frequency
	 CASE
			WHEN Frequency = 12 THEN 10
			WHEN Frequency >= 9 THEN 7
			WHEN Frequency >= 6 THEN 4
		    ELSE 1
	END AS F_Score,
	-- Score customers based on their MonetaryValue
	 CASE
			WHEN MonetaryValue > 600000 THEN 10
			WHEN MonetaryValue > 400000 THEN 7
			WHEN MonetaryValue BETWEEN 300000 AND 400000 THEN 4
			ELSE 1
	 END AS M_Score		   
FROM RFM
),

/* So now we have successfully scored our customers based on their 
RECENCY, FREQUENCY and their MONETARY VALUE.The next thing i will
be doing right now is to go ahead and segment the customers
*/
Segment AS(
SELECT Account_Number,
	LastTransactionDate,
	Recency,
	Frequency,
	MonetaryValue,
	CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 AS RFM_Segment, -- Calculate RFM scores
	CASE --
		WHEN MonetaryValue > 600000 THEN 'Above 600k'
		WHEN MonetaryValue BETWEEN 400000 AND 600000 THEN '400-600k'
		WHEN MonetaryValue BETWEEN 300000 AND 400000 THEN '300-400k'
		ELSE '200-300k'
	END AS SalaryRange,
	-- Customer Segmentation
	CASE
		WHEN CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 > 0.8 THEN 'Tier 1 Customers'
		WHEN CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 >= 0.6 THEN 'Tier 2 Customers'
		WHEN CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 >= 0.5 THEN 'Tier 3 Customers'
        ELSE 'Tier 4 Customers'
	END AS Segments

FROM RFM_Scores)

-- Retrieve final values
SELECT S.Account_Number,
		C.Contact_Email,
		LastTransactionDate,
		Recency As MonthlySinceLastSalary,
		Frequency AS SalariesRecieved,
		MonetaryValue AS AverageSalary,
		SalaryRange,
		Segments
From Segment S
LEFT JOIN [dbo].[Customers] C
ON S.Account_Number = C.Account_Number
END

EXEC GetCustomerSegment
	@EmploymentStatus = 'Student',
	@DateCriteria = '2023-08-31',
	@TransDescription = 'Salary';