-- ==============================================================================
-- PROJECT: Medicare Claims Analysis (CMS DE-SynPUF, Sample 1)
-- DESCRIPTION: SQL analysis of synthetic Medicare beneficiaries and their
--              inpatient and outpatient claims from 2008 to 2010.
-- SKILLS: Joins, Aggregations, CASE, CTEs, Subqueries, EXISTS, Data Quality Checks
-- ==============================================================================


-- ==========================================
-- PART 1: DATA OVERVIEW
-- ==========================================

-- 1. How big is the dataset and what period do the claims cover?
SELECT
    (SELECT COUNT(*) FROM synpuf.beneficiary) AS beneficiaries,
    (SELECT COUNT(*) FROM synpuf.inpatient_claims) AS inpatient_claims,
    (SELECT COUNT(*) FROM synpuf.outpatient_claims) AS outpatient_claims,
    (SELECT MIN(clm_from_dt) FROM synpuf.inpatient_claims) AS first_claim,
    (SELECT MAX(clm_from_dt) FROM synpuf.inpatient_claims) AS last_claim;


-- ==========================================
-- PART 2: BENEFICIARY DEMOGRAPHICS
-- ==========================================

-- 2. Beneficiaries and average age by sex
SELECT
    CASE
        WHEN sex_code = '1' THEN 'Male'
        WHEN sex_code = '2' THEN 'Female'
    END AS sex,
    COUNT(*) AS beneficiaries,
    ROUND(AVG(EXTRACT(YEAR FROM AGE(DATE '2009-12-31', birth_date))), 1) AS avg_age
FROM synpuf.beneficiary
GROUP BY sex_code
ORDER BY beneficiaries DESC;

-- 3. Beneficiaries by race
SELECT
    CASE
        WHEN race_code = '1' THEN 'White'
        WHEN race_code = '2' THEN 'Black'
        WHEN race_code = '3' THEN 'Other'
        WHEN race_code = '5' THEN 'Hispanic'
    END AS race,
    COUNT(*) AS beneficiaries,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM synpuf.beneficiary), 1) AS pct
FROM synpuf.beneficiary
GROUP BY race_code
ORDER BY beneficiaries DESC;

-- 4. Beneficiaries by age group (age at the end of 2009)
WITH BeneficiaryAge AS (
    SELECT
        EXTRACT(YEAR FROM AGE(DATE '2009-12-31', birth_date)) AS age
    FROM synpuf.beneficiary
)
SELECT
    CASE
        WHEN age < 65 THEN 'Under 65'
        WHEN age < 75 THEN '65-74'
        WHEN age < 85 THEN '75-84'
        ELSE '85+'
    END AS age_group,
    COUNT(*) AS beneficiaries
FROM BeneficiaryAge
GROUP BY age_group
ORDER BY MIN(age);

-- 5. Top 10 states by beneficiaries, with average Medicare payment (2009)
SELECT
    s.state,
    COUNT(*) AS beneficiaries,
    ROUND(AVG(b.medreimb_ip + b.medreimb_op + b.medreimb_car), 2) AS avg_medicare_paid
FROM synpuf.beneficiary_2009 b
JOIN synpuf.states s ON s.state_code = b.sp_state_code
GROUP BY s.state
ORDER BY beneficiaries DESC
LIMIT 10;


-- ==========================================
-- PART 3: CHRONIC CONDITIONS & COST
-- ==========================================

-- 6. Share of beneficiaries with each chronic condition, 2008 vs 2009 (flags: 1 = yes, 2 = no)
SELECT
    '2008' AS year,
    ROUND(AVG(CASE WHEN sp_diabetes = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS diabetes,
    ROUND(AVG(CASE WHEN sp_ischmcht = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS ischemic_heart,
    ROUND(AVG(CASE WHEN sp_chf = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS heart_failure,
    ROUND(AVG(CASE WHEN sp_depressn = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS depression,
    ROUND(AVG(CASE WHEN sp_chrnkidn = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS kidney_disease,
    ROUND(AVG(CASE WHEN sp_copd = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS copd,
    ROUND(AVG(CASE WHEN sp_alzhdmta = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS alzheimers,
    ROUND(AVG(CASE WHEN sp_cncr = 1 THEN 1.0 ELSE 0 END) * 100, 1) AS cancer
FROM synpuf.beneficiary_2008
UNION ALL
SELECT
    '2009',
    ROUND(AVG(CASE WHEN sp_diabetes = 1 THEN 1.0 ELSE 0 END) * 100, 1),
    ROUND(AVG(CASE WHEN sp_ischmcht = 1 THEN 1.0 ELSE 0 END) * 100, 1),
    ROUND(AVG(CASE WHEN sp_chf = 1 THEN 1.0 ELSE 0 END) * 100, 1),
    ROUND(AVG(CASE WHEN sp_depressn = 1 THEN 1.0 ELSE 0 END) * 100, 1),
    ROUND(AVG(CASE WHEN sp_chrnkidn = 1 THEN 1.0 ELSE 0 END) * 100, 1),
    ROUND(AVG(CASE WHEN sp_copd = 1 THEN 1.0 ELSE 0 END) * 100, 1),
    ROUND(AVG(CASE WHEN sp_alzhdmta = 1 THEN 1.0 ELSE 0 END) * 100, 1),
    ROUND(AVG(CASE WHEN sp_cncr = 1 THEN 1.0 ELSE 0 END) * 100, 1)
FROM synpuf.beneficiary_2009;

-- 7. Does the average Medicare payment rise with the number of chronic conditions? (2009)
WITH ChronicCount AS (
    SELECT
        (CASE WHEN sp_alzhdmta = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_chf = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_chrnkidn = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_cncr = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_copd = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_depressn = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_diabetes = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_ischmcht = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_osteoprs = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_ra_oa = 1 THEN 1 ELSE 0 END)
        + (CASE WHEN sp_strketia = 1 THEN 1 ELSE 0 END) AS chronic_conditions,
        medreimb_ip + medreimb_op + medreimb_car AS total_paid
    FROM synpuf.beneficiary_2009
)
SELECT
    chronic_conditions,
    COUNT(*) AS beneficiaries,
    ROUND(AVG(total_paid), 2) AS avg_medicare_paid
FROM ChronicCount
GROUP BY chronic_conditions
ORDER BY chronic_conditions;

-- 8. Diabetic vs non-diabetic beneficiaries: average payment by care setting (2009)
SELECT
    CASE
        WHEN sp_diabetes = 1 THEN 'Diabetic'
        ELSE 'Not diabetic'
    END AS group_name,
    COUNT(*) AS beneficiaries,
    ROUND(AVG(medreimb_ip), 2) AS avg_inpatient,
    ROUND(AVG(medreimb_op), 2) AS avg_outpatient,
    ROUND(AVG(medreimb_car), 2) AS avg_carrier,
    ROUND(AVG(medreimb_ip + medreimb_op + medreimb_car), 2) AS avg_total
FROM synpuf.beneficiary_2009
GROUP BY group_name;

-- 9. Total Medicare spending by care setting (2009)
WITH SettingSpend AS (
    SELECT
        'Inpatient' AS setting,
        SUM(medreimb_ip) AS medicare_paid
    FROM synpuf.beneficiary_2009
    UNION ALL
    SELECT
        'Outpatient',
        SUM(medreimb_op)
    FROM synpuf.beneficiary_2009
    UNION ALL
    SELECT
        'Carrier (physician)',
        SUM(medreimb_car)
    FROM synpuf.beneficiary_2009
)
SELECT
    setting,
    ROUND(medicare_paid, 2) AS medicare_paid,
    ROUND(medicare_paid * 100.0 / (SELECT SUM(medicare_paid) FROM SettingSpend), 1) AS pct
FROM SettingSpend
ORDER BY medicare_paid DESC;

-- 10. How concentrated is spending? Beneficiaries grouped into spending bands (2009)
WITH BeneficiarySpend AS (
    SELECT
        medreimb_ip + medreimb_op + medreimb_car AS total_paid
    FROM synpuf.beneficiary_2009
)
SELECT
    CASE
        WHEN total_paid <= 0 THEN '$0 or less'
        WHEN total_paid < 1000 THEN 'Under $1K'
        WHEN total_paid < 10000 THEN '$1K-$10K'
        WHEN total_paid < 50000 THEN '$10K-$50K'
        ELSE '$50K+'
    END AS spending_band,
    COUNT(*) AS beneficiaries,
    ROUND(SUM(total_paid), 2) AS medicare_paid,
    ROUND(SUM(total_paid) * 100.0 / (SELECT SUM(total_paid) FROM BeneficiarySpend), 1) AS pct_of_spend
FROM BeneficiarySpend
GROUP BY spending_band
ORDER BY MIN(total_paid);


-- ==========================================
-- PART 4: INPATIENT (HOSPITAL) CLAIMS
-- ==========================================

-- 11. Inpatient claims, payments and average stay by year
SELECT
    EXTRACT(YEAR FROM clm_from_dt) AS year,
    COUNT(*) AS claims,
    ROUND(SUM(clm_pmt_amt), 2) AS total_paid,
    ROUND(AVG(clm_pmt_amt), 2) AS avg_paid,
    ROUND(AVG(clm_utlztn_day_cnt), 1) AS avg_days
FROM synpuf.inpatient_claims
WHERE clm_from_dt IS NOT NULL
GROUP BY year
ORDER BY year;

-- 12. Monthly admissions trend
SELECT
    TO_CHAR(clm_from_dt, 'YYYY-MM') AS month,
    COUNT(*) AS admissions
FROM synpuf.inpatient_claims
WHERE clm_from_dt >= '2008-01-01'
GROUP BY month
ORDER BY month;

-- 13. Length of stay: average, median and longest
SELECT
    ROUND(AVG(nch_bene_dschrg_dt - clm_admsn_dt), 1) AS avg_length_of_stay,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY nch_bene_dschrg_dt - clm_admsn_dt) AS median_length_of_stay,
    MAX(nch_bene_dschrg_dt - clm_admsn_dt) AS longest_stay
FROM synpuf.inpatient_claims;

-- 14. Top 10 DRGs by total payment
SELECT
    clm_drg_cd AS drg,
    COUNT(*) AS claims,
    ROUND(SUM(clm_pmt_amt), 2) AS total_paid,
    ROUND(AVG(clm_pmt_amt), 2) AS avg_paid,
    ROUND(AVG(nch_bene_dschrg_dt - clm_admsn_dt), 1) AS avg_stay
FROM synpuf.inpatient_claims
WHERE clm_drg_cd IS NOT NULL
GROUP BY clm_drg_cd
ORDER BY total_paid DESC
LIMIT 10;

-- 15. Top 10 admitting diagnoses (ICD-9)
SELECT
    admtng_icd9_dgns_cd AS admitting_diagnosis,
    COUNT(*) AS admissions,
    ROUND(AVG(clm_pmt_amt), 2) AS avg_paid
FROM synpuf.inpatient_claims
WHERE admtng_icd9_dgns_cd IS NOT NULL
GROUP BY admtng_icd9_dgns_cd
ORDER BY admissions DESC
LIMIT 10;

-- 16. 30-day readmission rate (another admission within 30 days of discharge)
WITH Readmitted AS (
    SELECT DISTINCT
        a.clm_id,
        a.segment
    FROM synpuf.inpatient_claims a
    JOIN synpuf.inpatient_claims b ON b.desynpuf_id = a.desynpuf_id
    WHERE b.clm_admsn_dt > a.nch_bene_dschrg_dt
        AND b.clm_admsn_dt <= a.nch_bene_dschrg_dt + 30
)
SELECT
    COUNT(*) AS admissions,
    COUNT(r.clm_id) AS readmitted_within_30_days,
    ROUND(COUNT(r.clm_id) * 100.0 / COUNT(*), 1) AS readmission_rate
FROM synpuf.inpatient_claims c
LEFT JOIN Readmitted r ON r.clm_id = c.clm_id AND r.segment = c.segment
WHERE c.nch_bene_dschrg_dt IS NOT NULL;

-- 17. Top 10 hospitals (providers) by total inpatient payment
SELECT
    prvdr_num AS provider,
    COUNT(*) AS claims,
    COUNT(DISTINCT desynpuf_id) AS patients,
    ROUND(SUM(clm_pmt_amt), 2) AS total_paid,
    ROUND(AVG(clm_pmt_amt), 2) AS avg_paid
FROM synpuf.inpatient_claims
GROUP BY prvdr_num
ORDER BY total_paid DESC
LIMIT 10;

-- 18. What does the patient pay per hospital stay compared with Medicare?
SELECT
    ROUND(AVG(nch_bene_ip_ddctbl_amt), 2) AS avg_deductible,
    ROUND(AVG(nch_bene_pta_coinsrnc_lblty_am), 2) AS avg_coinsurance,
    ROUND(AVG(clm_pmt_amt), 2) AS avg_medicare_paid,
    ROUND(AVG(nch_prmry_pyr_clm_pd_amt), 2) AS avg_other_primary_payer
FROM synpuf.inpatient_claims;


-- ==========================================
-- PART 5: OUTPATIENT CLAIMS & UTILIZATION
-- ==========================================

-- 19. Outpatient claims and payments by year
SELECT
    EXTRACT(YEAR FROM clm_from_dt) AS year,
    COUNT(*) AS claims,
    ROUND(SUM(clm_pmt_amt), 2) AS total_paid,
    ROUND(AVG(clm_pmt_amt), 2) AS avg_paid
FROM synpuf.outpatient_claims
WHERE clm_from_dt IS NOT NULL
GROUP BY year
ORDER BY year;

-- 20. Top 10 outpatient services (first HCPCS code on the claim)
SELECT
    hcpcs_cd_1 AS hcpcs,
    COUNT(*) AS claims,
    ROUND(AVG(clm_pmt_amt), 2) AS avg_claim_paid
FROM synpuf.outpatient_claims
WHERE hcpcs_cd_1 IS NOT NULL
GROUP BY hcpcs_cd_1
ORDER BY claims DESC
LIMIT 10;

-- 21. Top 10 busiest attending physicians (NPI)
SELECT
    at_physn_npi AS attending_physician,
    COUNT(*) AS claims,
    COUNT(DISTINCT desynpuf_id) AS patients,
    ROUND(SUM(clm_pmt_amt), 2) AS total_paid
FROM synpuf.outpatient_claims
WHERE at_physn_npi IS NOT NULL
GROUP BY at_physn_npi
ORDER BY claims DESC
LIMIT 10;

-- 22. How many outpatient claims does each beneficiary have? (Left join keeps people with none)
WITH ClaimsPerPerson AS (
    SELECT
        b.desynpuf_id,
        COUNT(o.clm_id) AS claims
    FROM synpuf.beneficiary b
    LEFT JOIN synpuf.outpatient_claims o ON o.desynpuf_id = b.desynpuf_id
    GROUP BY b.desynpuf_id
)
SELECT
    CASE
        WHEN claims = 0 THEN '0 claims'
        WHEN claims <= 5 THEN '1-5'
        WHEN claims <= 20 THEN '6-20'
        WHEN claims <= 50 THEN '21-50'
        ELSE '50+'
    END AS outpatient_claims,
    COUNT(*) AS beneficiaries
FROM ClaimsPerPerson
GROUP BY outpatient_claims
ORDER BY MIN(claims);

-- 23. Deaths by year
SELECT
    EXTRACT(YEAR FROM death_date) AS year,
    COUNT(*) AS deaths
FROM synpuf.beneficiary
WHERE death_date IS NOT NULL
GROUP BY year
ORDER BY year;


-- ==========================================
-- PART 6: DATA QUALITY CHECKS
-- ==========================================

-- 24. Missing dates, zero payments, impossible stays and claims after death
WITH QualityChecks AS (
    SELECT 'Inpatient claims with no start date' AS check_name, COUNT(*) AS rows_found
    FROM synpuf.inpatient_claims
    WHERE clm_from_dt IS NULL
    UNION ALL
    SELECT 'Inpatient claims paid $0 or less', COUNT(*)
    FROM synpuf.inpatient_claims
    WHERE clm_pmt_amt <= 0
    UNION ALL
    SELECT 'Outpatient claims with no start date', COUNT(*)
    FROM synpuf.outpatient_claims
    WHERE clm_from_dt IS NULL
    UNION ALL
    SELECT 'Outpatient claims paid $0 or less', COUNT(*)
    FROM synpuf.outpatient_claims
    WHERE clm_pmt_amt <= 0
    UNION ALL
    SELECT 'Discharge before admission', COUNT(*)
    FROM synpuf.inpatient_claims
    WHERE nch_bene_dschrg_dt < clm_admsn_dt
    UNION ALL
    SELECT 'Claims after the beneficiary died', COUNT(*)
    FROM synpuf.inpatient_claims c
    JOIN synpuf.beneficiary b ON b.desynpuf_id = c.desynpuf_id
    WHERE b.death_date IS NOT NULL AND c.clm_from_dt > b.death_date
)
SELECT *
FROM QualityChecks
ORDER BY rows_found DESC, check_name;
