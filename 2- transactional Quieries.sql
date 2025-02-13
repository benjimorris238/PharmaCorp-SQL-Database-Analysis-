--------------------------------------------------------------------------------------------------------------------------
--View All Tables
--------------------------------------------------------------------------------------------------------------------------
SELECT * FROM disease;
SELECT * FROM disease_type;
SELECT * FROM diseased_patient;
SELECT * FROM medicine;
SELECT * FROM indication;
SELECT * FROM profit;
SELECT * FROM location;
SELECT * FROM outcome;



--------------------------------------------------------------------------------------------------------------------------
--Numer of PharmaCorp Patients
--------------------------------------------------------------------------------------------------------------------------
	WITH Pharma_medications AS (
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company = 'PharmaCorp'
),

Pharma_Indication AS (
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM Pharma_medications)
)

SELECT 
    COUNT(DISTINCT o.person_id) AS Pharma_Patients
FROM 
    outcome o
WHERE 
    o.indication_id IN (SELECT indication_id FROM Pharma_Indication);


--------------------------------------------------------------------------------------------------------------------------
--Numer of Non PharmaCorp Patients
--------------------------------------------------------------------------------------------------------------------------
	WITH Pharma_medications AS (
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company = 'PharmaCorp'
),

Pharma_Indication AS (
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM Pharma_medications)
)

SELECT 
    COUNT(DISTINCT o.person_id) AS non_Pharma_Patients
FROM 
    outcome o
WHERE 
    o.indication_id not IN (SELECT indication_id FROM Pharma_Indication);


--------------------------------------------------------------------------------------------------------------------------
--Company Count of Patients
--------------------------------------------------------------------------------------------------------------------------


WITH Company_medications AS (
    SELECT 
        m.medicine_id,
        m.company
    FROM 
        medicine m
),

Company_Indications AS (
    SELECT 
        i.indication_id,
        cm.company
    FROM 
        indication i
    JOIN 
        Company_medications cm ON i.medicine_id = cm.medicine_id
)

SELECT 
    ci.company AS company_name,
    COUNT(DISTINCT o.person_id) AS patient_count
FROM 
    outcome o
JOIN 
    Company_Indications ci ON o.indication_id = ci.indication_id
GROUP BY 
    ci.company
ORDER BY 
    patient_count DESC;	

--------------------------------------------------------------------------------------------------------------------------
-- Pharma Corp Profit 
--------------------------------------------------------------------------------------------------------------------------
WITH Pharma_medications AS (
    
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company = 'PharmaCorp'
),

Pharma_Indications AS (
   
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM Pharma_medications)
),

Indication_Counts AS (
    
    SELECT 
        o.indication_id,
        COUNT(*) AS occurrence_count
    FROM 
        outcome o
    WHERE 
        o.indication_id IN (SELECT indication_id FROM Pharma_Indications)
    GROUP BY 
        o.indication_id
)

SELECT 
    SUM(ic.occurrence_count * p.profit) AS Pharma_total_profit
FROM 
    Indication_Counts ic
JOIN 
    profit p ON ic.indication_id = p.indication_id;

--------------------------------------------------------------------------------------------------------------------------
-- non Pharma Corp Profit 
--------------------------------------------------------------------------------------------------------------------------
WITH NonPharma_medications AS (
    
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company != 'PharmaCorp'
),

NonPharma_Indications AS (
    
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM NonPharma_medications)
),

Indication_Counts AS (
    
    SELECT 
        o.indication_id,
        COUNT(*) AS occurrence_count
    FROM 
        outcome o
    WHERE 
        o.indication_id IN (SELECT indication_id FROM NonPharma_Indications)
    GROUP BY 
        o.indication_id
)

SELECT 
    SUM(ic.occurrence_count * p.profit) AS total_nonpharmacorp_profit
FROM 
    Indication_Counts ic
JOIN 
    profit p ON ic.indication_id = p.indication_id;

--------------------------------------------------------------------------------------------------------------------------
-- Profit by Company 
--------------------------------------------------------------------------------------------------------------------------
WITH Company_medications AS (
   
    SELECT 
        m.medicine_id,
        m.company
    FROM 
        medicine m
),

Company_Indications AS (
    
    SELECT 
        i.indication_id,
        cm.company
    FROM 
        indication i
    JOIN 
        Company_medications cm ON i.medicine_id = cm.medicine_id
),

Indication_Counts AS (
    
    SELECT 
        ci.company,
        o.indication_id,
        COUNT(*) AS occurrence_count
    FROM 
        outcome o
    JOIN 
        Company_Indications ci ON o.indication_id = ci.indication_id
    GROUP BY 
        ci.company, o.indication_id
)

SELECT 
    ic.company AS company_name,
    SUM(ic.occurrence_count * p.profit) AS total_profit
FROM 
    Indication_Counts ic
JOIN 
    profit p ON ic.indication_id = p.indication_id
GROUP BY 
    ic.company
ORDER BY 
    total_profit DESC;

--------------------------------------------------------------------------------------------------------------------------
-- DML ( Find List of Competing Drugs Between MediHealth and PharmaCorp)
--------------------------------------------------------------------------------------------------------------------------
WITH Duplicate_Ingredients AS (
    SELECT 
        active_ingredient_name
    FROM 
        medicine
    WHERE 
        company IN ('PharmaCorp', 'MediHealth')
    GROUP BY 
        active_ingredient_name
    HAVING 
        COUNT(*) > 1
)

SELECT 
    *
FROM 
    medicine
WHERE 
    company IN ('PharmaCorp', 'MediHealth')
    AND active_ingredient_name IN (SELECT active_ingredient_name FROM Duplicate_Ingredients)
ORDER BY 
    active_ingredient_name;

--------------------------------------------------------------------------------------------------------------------------
-- DML ( original Outcome with Medication Name)
--------------------------------------------------------------------------------------------------------------------------
WITH filtered_meds AS (
    SELECT 
        m.medicine_id, 
        m.active_ingredient_name,
        m.name AS medication_name,
        m.company
    FROM 
        medicine m
    WHERE 
        m.company IN ('PharmaCorp', 'MediHealth')
        AND m.active_ingredient_name IN (
            SELECT 
                active_ingredient_name
            FROM 
                medicine
            WHERE 
                company IN ('PharmaCorp', 'MediHealth')
            GROUP BY 
                active_ingredient_name
            HAVING 
                COUNT(*) > 1
        )
)
SELECT 
    o.outcome_id,
    o.person_id,
    o.indication_id,
    o.outcome,
    o.outcome_date,
    fm.medication_name,
    fm.company
FROM 
    outcome o
JOIN 
    indication i ON o.indication_id = i.indication_id
JOIN 
    filtered_meds fm ON i.medicine_id = fm.medicine_id
LIMIT 20;

--------------------------------------------------------------------------------------------------------------------------
-- DML ( Update Medication ID)
--------------------------------------------------------------------------------------------------------------------------
WITH pharma_names AS (
    SELECT 
        active_ingredient_name,
        name AS pharma_name
    FROM medicine
    WHERE company = 'PharmaCorp'
)
UPDATE medicine m
SET name = pn.pharma_name
FROM pharma_names pn
WHERE m.active_ingredient_name = pn.active_ingredient_name
AND m.company = 'MediHealth';

--------------------------------------------------------------------------------------------------------------------------
-- DML ( Confirm Update)
--------------------------------------------------------------------------------------------------------------------------
WITH Duplicate_Ingredients AS (
    SELECT 
        active_ingredient_name
    FROM 
        medicine
    WHERE 
        company IN ('PharmaCorp', 'MediHealth')
    GROUP BY 
        active_ingredient_name
    HAVING 
        COUNT(*) > 1
)

SELECT 
    *
FROM 
    medicine
WHERE 
    company IN ('PharmaCorp', 'MediHealth')
    AND active_ingredient_name IN (SELECT active_ingredient_name FROM Duplicate_Ingredients)
ORDER BY 
    active_ingredient_name;

--------------------------------------------------------------------------------------------------------------------------
-- DML ( Update Comapny Name)
--------------------------------------------------------------------------------------------------------------------------

UPDATE medicine
SET company = 'PharmaCorp'
WHERE company = 'MediHealth';


--------------------------------------------------------------------------------------------------------------------------
-- DML ( confirm update)
--------------------------------------------------------------------------------------------------------------------------
WITH filtered_meds AS (
    SELECT 
        m.medicine_id, 
        m.active_ingredient_name,
        m.name AS medication_name,
        m.company
    FROM 
        medicine m
    WHERE 
        m.company IN ('PharmaCorp', 'MediHealth')
        AND m.active_ingredient_name IN (
            SELECT 
                active_ingredient_name
            FROM 
                medicine
            WHERE 
                company IN ('PharmaCorp', 'MediHealth')
            GROUP BY 
                active_ingredient_name
            HAVING 
                COUNT(*) > 1
        )
)
SELECT 
    o.outcome_id,
    o.person_id,
    o.indication_id,
    o.outcome,
    o.outcome_date,
    fm.medication_name,
    fm.company
FROM 
    outcome o
JOIN 
    indication i ON o.indication_id = i.indication_id
JOIN 
    filtered_meds fm ON i.medicine_id = fm.medicine_id
LIMIT 20;


--------------------------------------------------------------------------------------------------------------------------
--New Numer of PharmaCorp Patients
--------------------------------------------------------------------------------------------------------------------------
	WITH Pharma_medications AS (
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company = 'PharmaCorp'
),

Pharma_Indication AS (
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM Pharma_medications)
)

SELECT 
    COUNT(DISTINCT o.person_id) AS Pharma_Patients
FROM 
    outcome o
WHERE 
    o.indication_id IN (SELECT indication_id FROM Pharma_Indication);


--------------------------------------------------------------------------------------------------------------------------
--Numer of Non PharmaCorp Patients
--------------------------------------------------------------------------------------------------------------------------
	WITH Pharma_medications AS (
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company = 'PharmaCorp'
),

Pharma_Indication AS (
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM Pharma_medications)
)

SELECT 
    COUNT(DISTINCT o.person_id) AS non_Pharma_Patients
FROM 
    outcome o
WHERE 
    o.indication_id not IN (SELECT indication_id FROM Pharma_Indication);


--------------------------------------------------------------------------------------------------------------------------
--Company Count of Patients
--------------------------------------------------------------------------------------------------------------------------


WITH Company_medications AS (
    SELECT 
        m.medicine_id,
        m.company
    FROM 
        medicine m
),

Company_Indications AS (
    SELECT 
        i.indication_id,
        cm.company
    FROM 
        indication i
    JOIN 
        Company_medications cm ON i.medicine_id = cm.medicine_id
)

SELECT 
    ci.company AS company_name,
    COUNT(DISTINCT o.person_id) AS patient_count
FROM 
    outcome o
JOIN 
    Company_Indications ci ON o.indication_id = ci.indication_id
GROUP BY 
    ci.company
ORDER BY 
    patient_count DESC;	

--------------------------------------------------------------------------------------------------------------------------
-- Pharma Corp Profit 
--------------------------------------------------------------------------------------------------------------------------
WITH Pharma_medications AS (
    
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company = 'PharmaCorp'
),

Pharma_Indications AS (
   
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM Pharma_medications)
),

Indication_Counts AS (
    
    SELECT 
        o.indication_id,
        COUNT(*) AS occurrence_count
    FROM 
        outcome o
    WHERE 
        o.indication_id IN (SELECT indication_id FROM Pharma_Indications)
    GROUP BY 
        o.indication_id
)

SELECT 
    SUM(ic.occurrence_count * p.profit) AS Pharma_total_profit
FROM 
    Indication_Counts ic
JOIN 
    profit p ON ic.indication_id = p.indication_id;

--------------------------------------------------------------------------------------------------------------------------
-- non Pharma Corp Profit 
--------------------------------------------------------------------------------------------------------------------------
WITH NonPharma_medications AS (
    
    SELECT 
        medicine_id
    FROM 
        medicine
    WHERE 
        company != 'PharmaCorp'
),

NonPharma_Indications AS (
    
    SELECT 
        indication_id
    FROM 
        indication
    WHERE 
        medicine_id IN (SELECT medicine_id FROM NonPharma_medications)
),

Indication_Counts AS (
    
    SELECT 
        o.indication_id,
        COUNT(*) AS occurrence_count
    FROM 
        outcome o
    WHERE 
        o.indication_id IN (SELECT indication_id FROM NonPharma_Indications)
    GROUP BY 
        o.indication_id
)

SELECT 
    SUM(ic.occurrence_count * p.profit) AS total_nonpharmacorp_profit
FROM 
    Indication_Counts ic
JOIN 
    profit p ON ic.indication_id = p.indication_id;

--------------------------------------------------------------------------------------------------------------------------
-- Profit by Company 
--------------------------------------------------------------------------------------------------------------------------
WITH Company_medications AS (
   
    SELECT 
        m.medicine_id,
        m.company
    FROM 
        medicine m
),

Company_Indications AS (
    
    SELECT 
        i.indication_id,
        cm.company
    FROM 
        indication i
    JOIN 
        Company_medications cm ON i.medicine_id = cm.medicine_id
),

Indication_Counts AS (
    
    SELECT 
        ci.company,
        o.indication_id,
        COUNT(*) AS occurrence_count
    FROM 
        outcome o
    JOIN 
        Company_Indications ci ON o.indication_id = ci.indication_id
    GROUP BY 
        ci.company, o.indication_id
)

SELECT 
    ic.company AS company_name,
    SUM(ic.occurrence_count * p.profit) AS total_profit
FROM 
    Indication_Counts ic
JOIN 
    profit p ON ic.indication_id = p.indication_id
GROUP BY 
    ic.company
ORDER BY 
    total_profit DESC;




