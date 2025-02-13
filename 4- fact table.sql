SET search_path TO finalproject_dw;

DROP TABLE IF EXISTS finalproject_dw.fact_disease_outcome_no_country CASCADE;
DROP TABLE IF EXISTS finalproject_dw.fact_disease_outcome CASCADE;
DROP TABLE IF EXISTS finalproject_dw.dim_disease_intensity_level CASCADE;
DROP TABLE IF EXISTS finalproject_dw.fact_disease_intensity CASCADE;
----------------------------------------------------------------------------------------------------------------------
-- Create Fact Table with Country 
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.fact_disease_outcome (
    fact_disease_outcome_id SERIAL PRIMARY KEY,         
    disease_id INT REFERENCES finalproject_dw.dim_disease (disease_id),
    age_id INT REFERENCES finalproject_dw.dim_age (age_id),
    gender_id INT REFERENCES finalproject_dw.dim_gender (gender_id),
    location_id INT REFERENCES finalproject_dw.dim_location (location_id),
    recovered_count INT,
    worsened_count INT,
    died_count INT,
    relapsed_count INT,
    effectiveness DECIMAL(10, 2),
    avg_cost_per_drug DECIMAL(10, 2),
    overall_avg_cost DECIMAL(10, 2),
    avg_profit DECIMAL(10, 2)
);

----------------------------------------------------------------------------------------------------------------------
-- Insert into Fact Table
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.fact_disease_outcome (
    disease_id,
    age_id,
    gender_id,
    location_id,
    recovered_count,
    worsened_count,
    died_count,
    relapsed_count,
    effectiveness,
    avg_cost_per_drug,
    overall_avg_cost,
    avg_profit
)
SELECT 
    d.disease_id,                      
    -- Manually map age to age_id using a CASE statement
    CASE
        WHEN dp.age <= 10 THEN 1  -- '0-10' -> age_id 1
        WHEN dp.age <= 20 THEN 2  -- '11-20' -> age_id 2
        WHEN dp.age <= 30 THEN 3  -- '21-30' -> age_id 3
        WHEN dp.age <= 40 THEN 4  -- '31-40' -> age_id 4
        WHEN dp.age <= 50 THEN 5  -- '41-50' -> age_id 5
        WHEN dp.age <= 60 THEN 6  -- '51-60' -> age_id 6
        WHEN dp.age <= 70 THEN 7  -- '61-70' -> age_id 7
        ELSE 8                    -- '71+' -> age_id 8
    END AS age_id,
    g.gender_id,                         
    l.location_id,                       
    -- Outcome Counts
    SUM(CASE WHEN o.outcome = 'recovered' AND o.outcome != 'relapse' THEN 1 ELSE 0 END) AS recovered_count,
    SUM(CASE WHEN o.outcome = 'worsened' THEN 1 ELSE 0 END) AS worsened_count,
    SUM(CASE WHEN o.outcome = 'died' THEN 1 ELSE 0 END) AS died_count,
    SUM(CASE WHEN o.outcome = 'relapse' THEN 1 ELSE 0 END) AS relapsed_count,
    -- Effectiveness: Recovered / Total Outcomes Excluding Relapsed
    CASE 
        WHEN COUNT(*) > 0 THEN (SUM(CASE WHEN o.outcome = 'recovered' AND o.outcome != 'relapse' THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        ELSE 0 
    END AS effectiveness,
    -- Average Cost Per Drug considering frequency of indications
    CASE 
        WHEN SUM(ic.indication_count) > 0 THEN SUM(ic.indication_count * p.cost) / SUM(ic.indication_count)
        ELSE 0 
    END AS avg_cost_per_drug,
    -- Overall Average Cost
    (SELECT AVG(cost) FROM public.profit) AS overall_avg_cost,
    -- Average Profit
    CASE 
        WHEN COUNT(*) > 0 THEN SUM(p.profit) / COUNT(*) 
        ELSE 0 
    END AS avg_profit
FROM 
    public.diseased_patient dp
JOIN 
    finalproject_dw.dim_disease d ON dp.disease_id = d.disease_id
JOIN 
    finalproject_dw.dim_gender g ON dp.gender = g.gender 
JOIN 
    finalproject_dw.dim_location l ON dp.primary_location_id = l.location_id
JOIN 
    public.outcome o ON dp.person_id = o.person_id
JOIN 
    public.indication i ON o.indication_id = i.indication_id
JOIN 
    public.profit p ON i.indication_id = p.indication_id

JOIN (
    SELECT 
        o.indication_id,
        COUNT(*) AS indication_count
    FROM 
        public.outcome o
    GROUP BY 
        o.indication_id
) ic ON o.indication_id = ic.indication_id
GROUP BY 
    d.disease_id, 
    g.gender_id, 
    l.location_id,
    age_id  
ORDER BY 
    d.disease_id, 
    age_id, 
    g.gender_id, 
    l.location_id;

----------------------------------------------------------------------------------------------------------------------
-- Select fact table
----------------------------------------------------------------------------------------------------------------------
SELECT 
    f.fact_disease_outcome_id,
    d.disease_name,         
    a.age_range,              
    g.gender,                
    l.country_name,          
    f.recovered_count,
    f.worsened_count,
    f.died_count,
    f.relapsed_count,
    f.effectiveness,
    f.avg_cost_per_drug,
    f.overall_avg_cost,
    f.avg_profit
FROM 
    finalproject_dw.fact_disease_outcome f
JOIN 
    finalproject_dw.dim_disease d ON f.disease_id = d.disease_id
JOIN 
    finalproject_dw.dim_age a ON f.age_id = a.age_id
JOIN 
    finalproject_dw.dim_gender g ON f.gender_id = g.gender_id
JOIN 
    finalproject_dw.dim_location l ON f.location_id = l.location_id
ORDER BY 
    f.effectiveness DESC, 
    f.avg_cost_per_drug DESC;


----------------------------------------------------------------------------------------------------------------------
-- Create Fact Table with no Country 
---------------------------------------------------------------------------------------------------------------------

CREATE TABLE finalproject_dw.fact_disease_outcome_no_country (
    fact_disease_outcome_id SERIAL PRIMARY KEY,         
    disease_id INT REFERENCES finalproject_dw.dim_disease (disease_id),
    age_id INT REFERENCES finalproject_dw.dim_age (age_id),
    gender_id INT REFERENCES finalproject_dw.dim_gender (gender_id),
    recovered_count INT,
    worsened_count INT,
    died_count INT,
    relapsed_count INT,
    effectiveness DECIMAL(10, 2),
    avg_cost_per_drug DECIMAL(10, 2),
    overall_avg_cost DECIMAL(10, 2),
    avg_profit DECIMAL(10, 2)
);

----------------------------------------------------------------------------------------------------------------------
--Fil Fact Table with no Country 
---------------------------------------------------------------------------------------------------------------------

WITH Indication_Costs AS (
    SELECT 
        o.person_id,
        p.cost,
        COUNT(o.indication_id) AS indication_count
    FROM 
        public.outcome o
    JOIN 
        public.profit p ON o.indication_id = p.indication_id
    GROUP BY 
        o.person_id, p.cost
)

INSERT INTO finalproject_dw.fact_disease_outcome_no_country (
    disease_id,
    age_id,
    gender_id,
    recovered_count,
    worsened_count,
    died_count,
    relapsed_count,
    effectiveness,
    avg_cost_per_drug,
    overall_avg_cost,
    avg_profit
)
SELECT 
    d.disease_id,                         
    -- Manually map age to age_id using a CASE statement
    CASE
        WHEN dp.age <= 10 THEN 1  -- '0-10' -> age_id 1
        WHEN dp.age <= 20 THEN 2  -- '11-20' -> age_id 2
        WHEN dp.age <= 30 THEN 3  -- '21-30' -> age_id 3
        WHEN dp.age <= 40 THEN 4  -- '31-40' -> age_id 4
        WHEN dp.age <= 50 THEN 5  -- '41-50' -> age_id 5
        WHEN dp.age <= 60 THEN 6  -- '51-60' -> age_id 6
        WHEN dp.age <= 70 THEN 7  -- '61-70' -> age_id 7
        ELSE 8                    -- '71+' -> age_id 8
    END AS age_id,
    g.gender_id,                          
    -- Outcome Counts
    SUM(CASE WHEN o.outcome = 'recovered' AND o.outcome != 'relapse' THEN 1 ELSE 0 END) AS recovered_count,
    SUM(CASE WHEN o.outcome = 'worsened' THEN 1 ELSE 0 END) AS worsened_count,
    SUM(CASE WHEN o.outcome = 'died' THEN 1 ELSE 0 END) AS died_count,
    SUM(CASE WHEN o.outcome = 'relapse' THEN 1 ELSE 0 END) AS relapsed_count,
    -- Effectiveness: Recovered / Total Outcomes Excluding Relapsed
    CASE 
        WHEN COUNT(*) > 0 THEN (SUM(CASE WHEN o.outcome = 'recovered' AND o.outcome != 'relapse' THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        ELSE 0 
    END AS effectiveness,
    -- Average Cost Per Drug considering frequency of indications
    CASE 
        WHEN SUM(ic.indication_count) > 0 THEN SUM(ic.cost * ic.indication_count) / SUM(ic.indication_count)
        ELSE 0 
    END AS avg_cost_per_drug,
    -- Overall Average Cost
    (SELECT AVG(cost) FROM public.profit) AS overall_avg_cost,
    -- Average Profit
    CASE 
        WHEN COUNT(*) > 0 THEN SUM(p.profit) / COUNT(*) 
        ELSE 0 
    END AS avg_profit
FROM 
    public.diseased_patient dp
JOIN 
    finalproject_dw.dim_disease d ON dp.disease_id = d.disease_id
JOIN 
    finalproject_dw.dim_gender g ON dp.gender = g.gender  
JOIN 
    public.outcome o ON dp.person_id = o.person_id
JOIN 
    public.indication i ON o.indication_id = i.indication_id
JOIN 
    public.profit p ON i.indication_id = p.indication_id
JOIN 
    Indication_Costs ic ON o.person_id = ic.person_id  
GROUP BY 
    d.disease_id, 
    g.gender_id, 
    age_id  
ORDER BY 
    d.disease_id, 
    age_id, 
    g.gender_id;

----------------------------------------------------------------------------------------------------------------------
-- Select fact table
----------------------------------------------------------------------------------------------------------------------
SELECT 
    f.fact_disease_outcome_id,
    d.disease_name,
    a.age_range,
    g.gender,
    f.recovered_count,
    f.worsened_count,
    f.died_count,
    f.relapsed_count,
    f.effectiveness,
    f.avg_cost_per_drug,
    f.overall_avg_cost,
    f.avg_profit
FROM 
    finalproject_dw.fact_disease_outcome_no_country f
JOIN 
    finalproject_dw.dim_disease d ON f.disease_id = d.disease_id
JOIN 
    finalproject_dw.dim_age a ON f.age_id = a.age_id
JOIN 
    finalproject_dw.dim_gender g ON f.gender_id = g.gender_id
ORDER BY 
    effectiveness, 
    avg_cost_per_drug DESC;




----------------------------------------------------------------------------------------------------------------------
-- Create intensity disease  dim table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.dim_disease_intensity_level (
    intensity_level_scd_id SERIAL PRIMARY KEY,
    disease_name VARCHAR(255),
    intensity_level INT,
    start_year INT DEFAULT 2020 NOT NULL,
    end_year INT DEFAULT 2025,
    is_current BOOLEAN DEFAULT TRUE
);
----------------------------------------------------------------------------------------------------------------------
-- Fill  intensity disease  dim table
----------------------------------------------------------------------------------------------------------------------

INSERT INTO finalproject_dw.dim_disease_intensity_level (
    disease_name,
    intensity_level
)
SELECT 
    d.disease_name,
    ilq.intensity_level
FROM 
    public.disease pd
JOIN 
    finalproject_dw.dim_disease d ON pd.disease_name = d.disease_name
JOIN 
    finalproject_dw.dim_intensity_level_quantity ilq ON pd.intensity_level_qty = ilq.intensity_level;
----------------------------------------------------------------------------------------------------------------------
-- create Fact Table
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE finalproject_dw.fact_disease_intensity (
    fact_disease_intensity_id SERIAL PRIMARY KEY,
    year_id INT REFERENCES finalproject_dw.dim_year (year_id),
    disease_id INT REFERENCES finalproject_dw.dim_disease (disease_id),
    intensity_level_id INT REFERENCES finalproject_dw.dim_intensity_level_quantity (intensity_level_id)
);



----------------------------------------------------------------------------------------------------------------------
-- Fill Fact Table
----------------------------------------------------------------------------------------------------------------------

INSERT INTO finalproject_dw.fact_disease_intensity (
    year_id,
    disease_id,
    intensity_level_id
)
SELECT 
    y.year_id,
    d.disease_id,
    ilq.intensity_level_id
FROM 
    finalproject_dw.dim_year y
JOIN 
    finalproject_dw.dim_disease_intensity_level dil 
    ON y.year BETWEEN dil.start_year AND COALESCE(dil.end_year, y.year)
JOIN 
    finalproject_dw.dim_disease d ON dil.disease_name = d.disease_name
JOIN 
    finalproject_dw.dim_intensity_level_quantity ilq ON dil.intensity_level = ilq.intensity_level
WHERE 
    dil.is_current = TRUE
ORDER BY 
    y.year,
    d.disease_id;
----------------------------------------------------------------------------------------------------------------------
-- Select Fact Table
----------------------------------------------------------------------------------------------------------------------



SELECT 
    f.fact_disease_intensity_id,
    y.year AS year,
    d.disease_name,
    ilq.intensity_level AS intensity_level
FROM 
    finalproject_dw.fact_disease_intensity f
JOIN 
    finalproject_dw.dim_year y ON f.year_id = y.year_id
JOIN 
    finalproject_dw.dim_disease d ON f.disease_id = d.disease_id
JOIN 
    finalproject_dw.dim_intensity_level_quantity ilq ON f.intensity_level_id = ilq.intensity_level_id
ORDER BY 
    y.year,
    d.disease_name;	

----------------------------------------------------------------------------------------------------------------------
-- Update intensity disease  dim table - change COVID to false
----------------------------------------------------------------------------------------------------------------------
UPDATE finalproject_dw.dim_disease_intensity_level
SET 
    end_year = 2022,
    is_current = FALSE
FROM 
    finalproject_dw.dim_disease d
WHERE 
    finalproject_dw.dim_disease_intensity_level.disease_name = d.disease_name
    AND d.disease_name = 'COVID-19'
    AND finalproject_dw.dim_disease_intensity_level.is_current = TRUE;  	

----------------------------------------------------------------------------------------------------------------------
-- Update intensity disease  dim table - Add new COVID Value 
----------------------------------------------------------------------------------------------------------------------
INSERT INTO finalproject_dw.dim_disease_intensity_level (
    disease_name,
    intensity_level,
    start_year,
    end_year,
    is_current
)
VALUES 
    ('COVID-19', '9', 2023, 2025, TRUE);

----------------------------------------------------------------------------------------------------------------------
-- Update intensity disease  dim table - change COVID to false
----------------------------------------------------------------------------------------------------------------------
UPDATE finalproject_dw.fact_disease_intensity f
SET intensity_level_id = (
    SELECT ilq.intensity_level_id
    FROM finalproject_dw.dim_disease_intensity_level dil
    JOIN finalproject_dw.dim_disease d ON dil.disease_name = d.disease_name
    JOIN finalproject_dw.dim_intensity_level_quantity ilq ON dil.intensity_level = ilq.intensity_level
    JOIN finalproject_dw.dim_year y ON f.year_id = y.year_id
    WHERE f.disease_id = d.disease_id
      AND y.year BETWEEN dil.start_year AND COALESCE(dil.end_year, y.year)
      AND dil.is_current = TRUE
)
WHERE EXISTS (
    SELECT 1
    FROM finalproject_dw.dim_disease_intensity_level dil
    JOIN finalproject_dw.dim_disease d ON dil.disease_name = d.disease_name
    JOIN finalproject_dw.dim_year y ON f.year_id = y.year_id
    WHERE f.disease_id = d.disease_id
      AND y.year BETWEEN dil.start_year AND COALESCE(dil.end_year, y.year)
      AND dil.is_current = TRUE
);

----------------------------------------------------------------------------------------------------------------------
-- see updated fact table for 2022 and 2023 
----------------------------------------------------------------------------------------------------------------------
SELECT 
    f.fact_disease_intensity_id,
    y.year AS year,
    d.disease_name,
    ilq.intensity_level
FROM 
    finalproject_dw.fact_disease_intensity f
JOIN 
    finalproject_dw.dim_year y ON f.year_id = y.year_id
JOIN 
    finalproject_dw.dim_disease d ON f.disease_id = d.disease_id
JOIN 
    finalproject_dw.dim_intensity_level_quantity ilq ON f.intensity_level_id = ilq.intensity_level_id
WHERE 
    y.year IN (2022, 2023)
ORDER BY 
    y.year,
    d.disease_name;
