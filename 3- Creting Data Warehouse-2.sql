SET search_path TO finalproject_dw;


DROP TABLE IF EXISTS finalproject_dw.dim_age CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_gender CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_location CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_disease CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_profit CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_diseased_patient CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_medicine CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_indication CASCADE;
DROP TABLE IF EXISTS finalproject_dw.fact_disease_outcome CASCADE;
DROP TABLE IF EXISTS finalproject_dw.disease_outcome_summary CASCADE;
DROP TABLE IF EXISTS dim_year CASCADE;
DROP TABLE IF EXISTS dim_intensity_level_quantity CASCADE;

----------------------------------------------------------------------------------------------------------------------
-- Create Dim Age Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_age (
    age_id SERIAL PRIMARY KEY,
    age_range VARCHAR(20)
);

----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Age Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_age (age_range)
SELECT DISTINCT
    CASE
        WHEN Age <= 10 THEN '0-10'
        WHEN Age <= 20 THEN '11-20'
        WHEN Age <= 30 THEN '21-30'
        WHEN Age <= 40 THEN '31-40'
        WHEN Age <= 50 THEN '41-50'
        WHEN Age <= 60 THEN '51-60'
        WHEN Age <= 70 THEN '61-70'
        ELSE '71+'
    END AS age_range
FROM public.Diseased_Patient;
----------------------------------------------------------------------------------------------------------------------
-- Create Dim Disease Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_disease (
    disease_id SERIAL PRIMARY KEY,
    disease_name VARCHAR(100),
    intensity_level_qty INT,
    disease_type_code CHAR(10)
);

----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Disease Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_disease (disease_name, intensity_level_qty, disease_type_code)
SELECT DISTINCT
    Disease_Name,
    Intensity_Level_Qty,
    Disease_Type_Code
FROM public.Disease;
----------------------------------------------------------------------------------------------------------------------
-- Create Dim Medicine Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_medicine (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(150),
    company VARCHAR(150)
);

----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Medicine Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_medicine (medicine_name, company)
SELECT DISTINCT
    name AS medicine_name,
    company
FROM public.medicine;

----------------------------------------------------------------------------------------------------------------------
-- Create Dim Indication Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_indication (
    indication_id SERIAL PRIMARY KEY,
    medicine_id INT,
    disease_id INT
);

----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Indication Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_indication (indication_id, medicine_id, disease_id)
SELECT DISTINCT
    ind.indication_id,
    ind.medicine_id,
    ind.disease_id
FROM public.indication ind
WHERE ind.medicine_id IN (SELECT medicine_id FROM finalproject_dw.dim_medicine);

----------------------------------------------------------------------------------------------------------------------
-- Create Dim Gender Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_gender (
    gender_id SERIAL PRIMARY KEY,
    gender CHAR(1) NOT NULL,
    gender_desc VARCHAR(10) NOT NULL
);

----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Gender Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_gender (gender, gender_desc)
SELECT DISTINCT 
    gender,
    CASE 
        WHEN gender = 'M' THEN 'Male'
        WHEN gender = 'F' THEN 'Female'
        ELSE 'Unknown'
    END AS gender_desc
FROM public.diseased_patient;


----------------------------------------------------------------------------------------------------------------------
-- Create Dim Location Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_location (
    location_id SERIAL PRIMARY KEY,
    city_name VARCHAR(100),
    state_province_name VARCHAR(100),
    country_name VARCHAR(100),
    developing_flag CHAR(1),
    wealth_rank_number INT
);
----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Location Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_location (city_name, state_province_name, country_name, developing_flag, wealth_rank_number)
SELECT DISTINCT
    City_Name,
    State_Province_Name,
    Country_Name,
    Developing_Flag,
    Wealth_Rank_Number
FROM public.Location;
----------------------------------------------------------------------------------------------------------------------
-- Create Dim Profit Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_profit (
    profit_id SERIAL PRIMARY KEY,
    cost DECIMAL(10, 2),
    price DECIMAL(10, 2),
    profit DECIMAL(10, 2),
    percentage_profit DECIMAL(10, 2)
);

----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Profit Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_profit (cost, price, profit, percentage_profit)
SELECT DISTINCT
    Cost,
    Price,
    Profit,
    Percentage_Profit
FROM public.Profit;

----------------------------------------------------------------------------------------------------------------------
-- Create Dim Year Table
----------------------------------------------------------------------------------------------------------------------

CREATE TABLE dim_year (
    year_id INT PRIMARY KEY,
    year INT
);
----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Year Table
----------------------------------------------------------------------------------------------------------------------

INSERT INTO dim_year (year_id, year)
SELECT 
    ROW_NUMBER() OVER (ORDER BY EXTRACT(YEAR FROM fdo.outcome_date)) AS year_id,
    EXTRACT(YEAR FROM fdo.outcome_date) AS year
FROM 
    public.outcome fdo
GROUP BY 
    EXTRACT(YEAR FROM fdo.outcome_date)
ORDER BY 
    year;
----------------------------------------------------------------------------------------------------------------------
-- Create Dim Diseased Patient Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_diseased_patient (
    diseased_patient_id SERIAL PRIMARY KEY,
    last_name VARCHAR(50),
    first_name VARCHAR(50),
    gender_id INT,
    age_id INT,
    is_insured BOOLEAN DEFAULT FALSE,
    start_date DATE,
    end_date DATE
);
----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Diseased Patient Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_diseased_patient (last_name, first_name, gender_id, age_id, is_insured, start_date, end_date)
SELECT 
    Last_Name,
    First_Name,
    (SELECT gender_id FROM finalproject_dw.dim_gender WHERE gender = dp.Gender) AS gender_id,
    (SELECT age_id FROM finalproject_dw.dim_age 
        WHERE age_range = CASE
                            WHEN dp.Age <= 10 THEN '0-10'
                            WHEN dp.Age <= 20 THEN '11-20'
                            WHEN dp.Age <= 30 THEN '21-30'
                            WHEN dp.Age <= 40 THEN '31-40'
                            WHEN dp.Age <= 50 THEN '41-50'
                            WHEN dp.Age <= 60 THEN '51-60'
                            WHEN dp.Age <= 70 THEN '61-70'
                            ELSE '71+'
                         END) AS age_id,
    Is_Insured,
    Start_Date,
    End_Date
FROM public.Diseased_Patient dp;
----------------------------------------------------------------------------------------------------------------------
-- Create Dim Intensity Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE dim_intensity_level_quantity (
    intensity_level_id INT PRIMARY KEY,
    intensity_level INT
);
----------------------------------------------------------------------------------------------------------------------
-- Fill Dim Intensity Table
----------------------------------------------------------------------------------------------------------------------
WITH intensity_levels AS (
    SELECT DISTINCT intensity_level_qty
    FROM public.disease
    WHERE intensity_level_qty IS NOT NULL
)
INSERT INTO dim_intensity_level_quantity (intensity_level_id, intensity_level)
SELECT 
    ROW_NUMBER() OVER (ORDER BY intensity_level_qty) AS intensity_level_id,
    intensity_level_qty
FROM intensity_levels;


