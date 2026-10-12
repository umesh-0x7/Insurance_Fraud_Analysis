CREATE DATABASE insurance_claims;
USE insurance_claims;

SELECT COUNT(*) FROM claims;
SELECT COUNT(*) FROM claims WHERE AgeOfPolicyHolder = '16 to 17';
SELECT SUM(FraudFound_P) FROM claims;
SELECT VERSION();

-- Insurance claims fraud analysis (MySQL 8)
-- Table: claims (15,420 rows, 33 columns; 923 fraud cases)

SHOW COLUMNS FROM claims;

-- 1.Fraud rate by coverage type and fault

SELECT BasePolicy, Fault,
       COUNT(*) AS claims,
       SUM(FraudFound_P) AS fraud_cases,
       ROUND(100 * AVG(FraudFound_P), 2) AS fraud_rate_pct
FROM claims
GROUP BY BasePolicy, Fault
ORDER BY fraud_rate_pct DESC;

-- 2. Policy types ranked by fraud "lift" vs. the overall rate
 
WITH overall AS (                            
    SELECT AVG(FraudFound_P) AS overall_rate FROM claims
)
SELECT c.PolicyType,
       COUNT(*) AS claims,
       ROUND(100 * AVG(c.FraudFound_P), 2) AS fraud_rate_pct,
       ROUND(AVG(c.FraudFound_P) / o.overall_rate, 2) AS lift
FROM claims c
CROSS JOIN overall o
GROUP BY c.PolicyType, o.overall_rate
HAVING COUNT(*) >= 100
ORDER BY lift DESC;


-- 3. Monthly claim volume with change and 3-month rolling average

WITH monthly AS (                                  
    SELECT `Year` AS yr,
           FIELD(`Month`, 'Jan','Feb','Mar','Apr','May','Jun',
                          'Jul','Aug','Sep','Oct','Nov','Dec') AS month_num,
           COUNT(*) AS claims,
           SUM(FraudFound_P) AS fraud_cases
    FROM claims
    GROUP BY `Year`, month_num
)
SELECT yr, month_num, claims, fraud_cases,
       claims - LAG(claims) OVER (ORDER BY yr, month_num) AS change_vs_prev,
       ROUND(AVG(claims) OVER (ORDER BY yr, month_num
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS rolling_3m_avg
FROM monthly
ORDER BY yr, month_num;


-- 4. Vehicle category ranked by fraud rate within each coverage type

WITH seg AS (                                     
    SELECT BasePolicy, VehicleCategory,
           COUNT(*) AS claims,
           SUM(FraudFound_P) AS fraud_cases,
           ROUND(100 * AVG(FraudFound_P), 2) AS fraud_rate_pct
    FROM claims
    GROUP BY BasePolicy, VehicleCategory
    HAVING COUNT(*) >= 100
)
SELECT *,
       RANK() OVER (PARTITION BY BasePolicy ORDER BY fraud_rate_pct DESC) AS rank_in_coverage
FROM seg
ORDER BY BasePolicy, rank_in_coverage;


 -- 5. Review rule: at-fault claims on All Perils or Collision policies
 
SELECT CASE WHEN Fault = 'Policy Holder' AND BasePolicy IN ('All Perils', 'Collision')
            THEN 'Flagged' ELSE 'Not flagged' END AS group_label,
       COUNT(*) AS claims,
       SUM(FraudFound_P) AS fraud_cases,
       ROUND(100 * AVG(FraudFound_P), 2) AS fraud_rate_pct,
       ROUND(100 * SUM(FraudFound_P) / (SELECT SUM(FraudFound_P) FROM claims), 1) AS share_of_all_fraud_pct
FROM claims
GROUP BY group_label;