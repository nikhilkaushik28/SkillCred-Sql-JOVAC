-- Name :  Nikhil Kaushik
-- E-mail ID :  nikhil.kaushik_cs.h22@gla.ac.in
-- Project Name : Customer segmentation analysis to improve conversion





-- 1. Summary of active vs closed accounts.



SELECT
	"ACCOUNT_STATUS",
	COUNT("ACCOUNT_STATUS") AS total_account_status
FROM
	transaction_line tl
GROUP BY
	1
ORDER BY
	1;





-- 2. Breakdown of account types (e.g., loans, credit cards) and their current balances.



SELECT
	"ACCOUNT_CATEGORY",
	COUNT(*) as count,
	SUM("ACCOUNT_BALANCE") AS total_current_balance
FROM
	transaction_line tl
GROUP BY
	1
ORDER BY
	1;





-- 3. Analysis of loan amounts vs. account balances.



SELECT
	"ACCOUNT_CATEGORY",
	AVG("SANCTIONED_AMOUNT") AS avg_loan_amount,
	AVG("ACCOUNT_BALANCE") AS avg_account_balance
FROM
	transaction_line tl
GROUP BY
	1;





-- 4. overview of the closure percentages for different loan types by ownership type (Individual vs Joint Account) 



SELECT
	"ACCOUNT_CATEGORY",
	"OWNERSHIP_TYPE",
	COUNT(*) AS total_accounts,
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) AS closed_accounts,
	ROUND(SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END)::DECIMAL / COUNT(*) * 100, 2) AS closure_percentage
FROM
	transaction_line tl
GROUP BY
	1,
	2
ORDER BY
	2,
	1;




-- 5. Let’s start by segmenting customers based on FICO scores and account categories to see the distribution.



WITH fico_score_ranges AS (
SELECT
	"CUSTOMER_ID",
	"FICO_SCORE",
	"ACCOUNT_CATEGORY", 
	CASE 
		WHEN "FICO_SCORE" BETWEEN 300 AND 549 THEN 'Very Poor'
		WHEN "FICO_SCORE" BETWEEN 550 AND 649 THEN 'Poor'
		WHEN "FICO_SCORE" BETWEEN 650 AND 749 THEN 'Fair'
		WHEN "FICO_SCORE" BETWEEN 750 AND 849 THEN 'Good'
		WHEN "FICO_SCORE" BETWEEN 850 AND 949 THEN 'Excellent'
	END AS credit_segment
FROM
	transaction_line tl 
) ,
total_customers AS (
SELECT
	COUNT(DISTINCT "CUSTOMER_ID") AS total_customer
FROM
	transaction_line tl 
)
SELECT
	CREDIT_SEGMENT,
	"ACCOUNT_CATEGORY",
	COUNT("CUSTOMER_ID") AS customer_segment_count,
	tc.total_customer,
	(COUNT("CUSTOMER_ID") * 100 / tc.total_customer) AS percentage
FROM
	fico_score_ranges fsr
CROSS JOIN total_customers tc
GROUP BY
	1,
	2,
	4
ORDER BY
	2;




-- 6. Product Usage Segmentation: Categorizing customers by the types of accounts they hold (e.g., Auto Loans, Credit Cards, etc.).



WITH product_segmentation AS (
SELECT
	"CUSTOMER_ID",
	STRING_AGG(DISTINCT "ACCOUNT_CATEGORY", ', ') AS product_mix
FROM
	transaction_line tl
GROUP BY
	"CUSTOMER_ID"
)
SELECT
	product_mix,
	COUNT("CUSTOMER_ID") AS total_customers
FROM
	product_segmentation ps
GROUP BY
	1;




-- 7. Account Activity Segmentation: Segmenting customers by the status of their accounts (whether they have more active or closed accounts).



SELECT
	"CUSTOMER_ID",
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) AS active_accounts,
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) AS closed_accounts,
	CASE
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) > SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Active'
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) < SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Closed'
		ELSE 'EQUAL'
	END AS account_activity_segment
FROM
	transaction_line tl
GROUP BY
	1;





-- 8. Account Activity Segmentation Count 



WITH account_segments AS (
SELECT
	"CUSTOMER_ID",
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) AS active_accounts,
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) AS closed_accounts,
	CASE
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) > SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Active'
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) < SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Closed'
		ELSE 'EQUAL'
	END AS account_activity_segment
FROM
	transaction_line tl
GROUP BY
	1
)
SELECT
	account_activity_segment,
	COUNT("CUSTOMER_ID") AS total_customers
FROM
	account_segments ass
GROUP BY
	1
ORDER BY
	1;




-- 9. Create a cohort to reveal insights into customer retention and the life cycle of accounts. 
-- for example: categorize customers into cohorts based on their account opening dates and then analyse how these cohorts have behaved over time
-- analyse retention Rates (how long accounts stay open across different cohorts)



WITH cohorts AS (
	SELECT
		"CUSTOMER_ID",
		DATE_TRUNC('MONTH',
			CASE
				WHEN "OPENING_DATE" = '' THEN NULL
				ELSE "OPENING_DATE"::DATE
			END
		)::DATE AS cohort_month,
		"ACCOUNT_CATEGORY",
		COALESCE(
			CASE
				WHEN "CLOSED_DATE" = '' THEN NULL
				ELSE "CLOSED_DATE"::DATE
			END,
			NOW()
		)::DATE AS end_date
	FROM
		transaction_line tl
	WHERE
		"OPENING_DATE" != ''
),
cohort_sizes AS (
	SELECT
		cohort_month,
		"ACCOUNT_CATEGORY",
		COUNT(DISTINCT "CUSTOMER_ID") AS total_customers
	FROM
		cohorts c
	GROUP BY
		1,
		2
),
retention AS (
	SELECT
		c.cohort_month,
		c."ACCOUNT_CATEGORY",
		cs.total_customers,
		COUNT(DISTINCT 
				CASE 
	            	WHEN DATE_TRUNC('MONTH', c.end_date) >= c.cohort_month + INTERVAL '12 MONTHS' THEN c."CUSTOMER_ID"         	
				END
	        ) AS retained_customers_after_12_months
	FROM
		cohorts c
	JOIN cohort_sizes cs ON
		c.cohort_month = cs.cohort_month
		AND c."ACCOUNT_CATEGORY" = cs."ACCOUNT_CATEGORY"
	GROUP BY
		1,
		2,
		3
)
SELECT
	cohort_month,
	"ACCOUNT_CATEGORY",
	total_customers,
	retained_customers_after_12_months,
	ROUND((retained_customers_after_12_months::DECIMAL / total_customers::DECIMAL) * 100,
	2) AS retention_rate_after_12_months
FROM
	retention r
WHERE
	cohort_month <= NOW() - INTERVAL '12 MONTHS'
ORDER BY
	1,
	2;


 


-- 10. Identify Common Account Combinations: Look at customers who have multiple account types and identify common combinations.



WITH customer_accounts AS (
	SELECT
		"CUSTOMER_ID",
		ARRAY_AGG(DISTINCT "ACCOUNT_CATEGORY" ORDER by "ACCOUNT_CATEGORY") AS account_types,
		COUNT(DISTINCT "ACCOUNT_CATEGORY") AS num_account_types,
		ROUND(AVG("FICO_SCORE"), 2) AS avg_fico_score,
		SUM("ACCOUNT_BALANCE") AS total_balance,
		MAX("TENURE_MONTHS") AS max_tenure
	FROM
		transaction_line tl
	GROUP BY
		1
)




SELECT
	account_types,
	COUNT(*) AS combination_count
FROM
	customer_accounts ca
GROUP BY
	1
ORDER BY
	2 DESC;




-- 11. Predict Likely Next Products: Based on product holding patterns and customer behaviour within cohorts



WITH customer_accounts AS (
	SELECT
		"CUSTOMER_ID",
		ARRAY_AGG(DISTINCT "ACCOUNT_CATEGORY" ORDER by "ACCOUNT_CATEGORY") AS account_types,
		COUNT(DISTINCT "ACCOUNT_CATEGORY") AS num_account_types,
		ROUND(AVG("FICO_SCORE"), 2) AS avg_fico_score,
		SUM("ACCOUNT_BALANCE") AS total_balance,
		MAX("TENURE_MONTHS") AS max_tenure
	FROM
		transaction_line tl
	GROUP BY
		1
), 



customer_potential AS (
	SELECT
		ca."CUSTOMER_ID",
		ca.account_types,
		ca.num_account_types,
		ca.avg_fico_score,
		ca.total_balance,
		ca.max_tenure,
		(
			SELECT
				ARRAY_AGG(DISTINCT tl."ACCOUNT_CATEGORY")
			FROM
				transaction_line tl
			WHERE
				tl."ACCOUNT_CATEGORY" != ALL(ca.account_types)
		) AS potential_products
	FROM
		customer_accounts ca
)



SELECT
	cp."CUSTOMER_ID",
	cp.account_types AS current_products,
	cp.num_account_types,
	cp.avg_fico_score,
	cp.total_balance,
	cp.max_tenure,
	cp.potential_products AS recommended_product
FROM
	customer_potential cp
ORDER BY
	5 DESC,
	4 DESC;



