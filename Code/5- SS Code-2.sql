SET ROLE postgres;
SET search_path TO public;
DROP VIEW IF EXISTS medical_records_doctor;

----------------------------------------------------------------------------------------------------------------------
-- Create role doctor and grant mike doctor role 
----------------------------------------------------------------------------------------------------------------------
DROP ROLE IF EXISTS doctor;
CREATE ROLE doctor;
DROP ROLE IF EXISTS Mike;
CREATE ROLE Mike LOGIN PASSWORD 'Doctor';
GRANT doctor TO Mike;
----------------------------------------------------------------------------------------------------------------------
-- Create role Patient and grant David Garcia patient role 
----------------------------------------------------------------------------------------------------------------------
DROP ROLE IF EXISTS patient;
CREATE ROLE patient;
DROP ROLE IF EXISTS "David Garcia";
CREATE ROLE "David Garcia" LOGIN PASSWORD 'PatientPass';

GRANT patient TO "David Garcia";
----------------------------------------------------------------------------------------------------------------------
-- Create View for doctor role 
----------------------------------------------------------------------------------------------------------------------

CREATE VIEW medical_records_doctor AS
SELECT 
    o.person_id,
    dp.last_name,
    dp.first_name,
    dp.gender,
	dp.age,
    l.country_name,
	dp.is_insured,
    d.disease_name AS disease,
	m.name AS medication_name,
    dp.severity_value,
    dp.start_date,
    dp.end_date
    
   
FROM 
    public.outcome o
JOIN 
    public.diseased_patient dp ON o.person_id = dp.person_id
JOIN 
    public.disease d ON dp.disease_id = d.disease_id
JOIN 
    public.indication i ON o.indication_id = i.indication_id
JOIN 
    public.medicine m ON i.medicine_id = m.medicine_id
JOIN 
    public.location l ON dp.primary_location_id = l.location_id;
----------------------------------------------------------------------------------------------------------------------
-- Select View
----------------------------------------------------------------------------------------------------------------------
SELECT * FROM 	Medical_records_doctor;

----------------------------------------------------------------------------------------------------------------------
-- grant View to Doctor
----------------------------------------------------------------------------------------------------------------------

GRANT SELECT ON medical_records_doctor TO doctor;




----------------------------------------------------------------------------------------------------------------------
-- Grant patient privilages 
----------------------------------------------------------------------------------------------------------------------

GRANT SELECT ON diseased_patient TO patient;
GRANT SELECT ON location TO patient;
GRANT SELECT ON disease TO patient;
GRANT SELECT ON medicine TO patient;
GRANT SELECT ON outcome TO patient;
GRANT SELECT ON indication TO patient;

----------------------------------------------------------------------------------------------------------------------
-- Grant Row Level Security 
----------------------------------------------------------------------------------------------------------------------

ALTER TABLE diseased_patient ENABLE ROW LEVEL SECURITY;
ALTER TABLE outcome ENABLE ROW LEVEL SECURITY;
ALTER TABLE indication ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION set_patient_context(p_person_id INT)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_person_id', p_person_id::TEXT, false);
END;
$$ LANGUAGE plpgsql;

CREATE POLICY patient_own_records_policy
ON diseased_patient
USING (person_id = current_setting('app.current_person_id')::INT);

CREATE POLICY patient_own_outcomes_policy
ON outcome
USING (person_id = current_setting('app.current_person_id')::INT);

CREATE POLICY patient_own_indications_policy
ON indication
USING (
    EXISTS (
        SELECT 1
        FROM outcome o
        WHERE o.indication_id = indication.indication_id
        AND o.person_id = current_setting('app.current_person_id')::INT
    )
);



----------------------------------------------------------------------------------------------------------------------
-- RUN IN PATIENT SERVER - select own medical records 
----------------------------------------------------------------------------------------------------------------------
SELECT set_patient_context(1);
SET ROLE patient;
SELECT 
    o.person_id,
    dp.last_name,
    dp.first_name,
    dp.gender,
    dp.age,
    l.country_name,
    dp.is_insured,
    d.disease_name AS disease,
    m.name AS medication_name,
    dp.severity_value,
    dp.start_date,
    dp.end_date
FROM 
    diseased_patient dp
LEFT JOIN location l ON dp.primary_location_id = l.location_id
LEFT JOIN disease d ON dp.disease_id = d.disease_id
LEFT JOIN outcome o ON dp.person_id = o.person_id
LEFT JOIN indication i ON o.indication_id = i.indication_id
LEFT JOIN medicine m ON i.medicine_id = m.medicine_id
WHERE 
    dp.person_id = current_setting('app.current_person_id')::INT;
