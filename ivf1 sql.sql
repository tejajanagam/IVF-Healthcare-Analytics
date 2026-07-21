Create database ivf;
use ivf;
SET SQL_SAFE_UPDATES = 0;
SET GLOBAL local_infile = 1;
desc elisa;
CREATE TABLE elisa (
  patient_name_surname VARCHAR(255),
  age INT,
  spouse_age INT,
  clinical_pregnancy VARCHAR(50),
  live_birth INT,
  week_of_birth INT,
  neonatal_death INT,
  abortion INT,
  bhcg_12 DOUBLE,
  bhcg_14 DOUBLE,
  bhcg_increase DOUBLE,
  twin INT,
  indication Double,
  fsh DOUBLE,
  e2 DOUBLE,
  progesterone DOUBLE,
  number_of_oocytes INT,
  embryo_transfer_day VARCHAR(50),
  endometrial_thickness DOUBLE,
  ind_number_of_days INT,
  embryos_transferred INT,
  eu VARCHAR(10),
  amh DOUBLE
);

select *from elisa;
drop table elisa;
select count(*) from elisa;


LOAD DATA LOCAL INFILE 'C:/Users/tejaj/OneDrive/Desktop/project 2/Reports and Dashboards Data.csv'
INTO TABLE elisa
CHARACTER SET latin1
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  patient_name_surname,
  age,
  spouse_age,
  clinical_pregnancy,
  live_birth,
  week_of_birth,
  neonatal_death,
  abortion,
  bhcg_12,
  bhcg_14,
  bhcg_increase,
  twin,
  indication,
  fsh,
  e2,
  progesterone,
  number_of_oocytes,
  embryo_transfer_day,
  endometrial_thickness,
  ind_number_of_days,
  embryos_transferred,
  eu,
  amh
);

SELECT
  SUM(age IS NULL) AS missing_age,
  SUM(spouse_age IS NULL) AS missing_spouse_age,
  SUM(bhcg_12 IS NULL) AS missing_bhcg_12,
  SUM(bhcg_14 IS NULL) AS missing_bhcg_14,
  SUM(amh IS NULL) AS missing_amh,
  SUM(endometrial_thickness IS NULL) AS missing_endometrial
FROM elisa;

UPDATE elisa
SET 
  patient_name_surname = TRIM(patient_name_surname),
  clinical_pregnancy = TRIM(clinical_pregnancy),
  embryo_transfer_day = TRIM(embryo_transfer_day),
  eu = TRIM(eu);
  
CREATE TABLE elisa_clean AS
SELECT DISTINCT * FROM elisa;

WITH ordered AS (
  SELECT age,
         ROW_NUMBER() OVER (ORDER BY age) AS rn,
         COUNT(*) OVER () AS total_rows
  FROM elisa_clean
  WHERE age IS NOT NULL
)
SELECT AVG(age) AS median_age
FROM ordered
WHERE rn IN (FLOOR((total_rows+1)/2), CEIL((total_rows+1)/2));

UPDATE elisa_clean SET age = 32 WHERE age IS NULL;

SELECT
  MIN(age) AS min_age,
  MAX(age) AS max_age,
  AVG(age) AS avg_age,
  STDDEV(age) AS sd_age
FROM elisa_clean;

SELECT
  MIN(amh), MAX(amh), AVG(amh), STDDEV(amh)
FROM elisa_clean;

SELECT clinical_pregnancy, COUNT(*) AS count
FROM elisa_clean
GROUP BY clinical_pregnancy
ORDER BY count DESC;

SELECT live_birth, COUNT(*) 
FROM elisa_clean
GROUP BY live_birth;














  /*dataset 2*/
CREATE TABLE `data2` (
  `Fc_no` VARCHAR(20), 
  `Cycle_no` DOUBLE, 
  `Age` DOUBLE, 
  `Duration_of_infertility` DOUBLE, 
  `BMI` DOUBLE, 
  `Primary_infertility` DOUBLE, 
  `Male_female_combined` VARCHAR(20), 
  `Cause` VARCHAR(39), 
  `AFC` DOUBLE, 
  `AMH_ng_ml` DOUBLE, 
  `Protocol` VARCHAR(20), 
  `Gonadotrophins_IU` DOUBLE, 
  `Trigger` VARCHAR(30), 
  `Days_of_stimulation` DOUBLE, 
  `E2_on_trigger_day` DOUBLE, 
  `P4_on_trigger_day` DOUBLE, 
  `Endometrium_mm` DOUBLE, 
  `No_of_follicles_gt_14_mm` DOUBLE, 
  `No_of_oocytes` DOUBLE, 
  `M2` DOUBLE, 
  `MI` DOUBLE, 
  `GV` DOUBLE, 
  `ICSI` DOUBLE,
  `IVF` DOUBLE, 
  `Total_2PN` DOUBLE, 
  `Day_of_transfer` DOUBLE, 
  `No_of_embryos_transferred` DOUBLE, 
  `Grade` VARCHAR(50), 
  `Fresh_transfer` DOUBLE, 
  `Frozen_transfer` DOUBLE, 
  `Biochemical_preg` DOUBLE, 
  `Clinical_preg` DOUBLE, 
  `Twin` DOUBLE, 
  `Triplet` DOUBLE, 
  `Miscarriage` DOUBLE, 
  `Ongoing` DOUBLE, 
  `Remark` VARCHAR(255), 
  INDEX (`Fc_no`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



LOAD DATA LOCAL INFILE "C:/Users/tejaj/OneDrive/Desktop/project 2/Reports and Dashboards Data2.csv"
INTO TABLE `data2`
CHARACTER SET latin1
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
 `Fc_no`, `Cycle_no`, `Age`, `Duration_of_infertility`, `BMI`, `Primary_infertility`,
 `Male_female_combined`, `Cause`, `AFC`, `AMH_ng_ml`, `Protocol`, `Gonadotrophins_IU`,
 `Trigger`, `Days_of_stimulation`, `E2_on_trigger_day`, `P4_on_trigger_day`,
 `Endometrium_mm`, `No_of_follicles_gt_14_mm`, `No_of_oocytes`, `M2`, `MI`, `GV`,
 `ICSI`, `IVF`, `Total_2PN`, `Day_of_transfer`, `No_of_embryos_transferred`,
 `Grade`, `Fresh_transfer`, `Frozen_transfer`, `Biochemical_preg`, `Clinical_preg`,
 `Twin`, `Triplet`, `Miscarriage`, `Ongoing`, `Remark`
);

select count(*) from data2;
select *from data2;
drop table data2;

SELECT *
FROM data2
WHERE Fc_no = ''
   OR Fc_no = '0'
   OR (Age = 0 AND Duration_of_infertility = 0 AND BMI = 0);
   
DELETE FROM data2
WHERE Fc_no = ''
   OR Fc_no = '0'
   OR (Age = 0 AND Duration_of_infertility = 0 AND BMI = 0);
   
SELECT COUNT(*) FROM data2;


DROP TABLE IF EXISTS data3;
DROP TABLE IF EXISTS data3_typed;

CREATE TABLE data3 (
    `start`                VARCHAR(50),
    `end`                  VARCHAR(50),
    `Date_of_first_presentation_for_IVF` DATE,
    `Age_In_Years`         INT,
    `Religion`             VARCHAR(100),
    `Tribe`                VARCHAR(100),
    `Parity`               INT,
    `Is_menses_regular`    VARCHAR(50),
    `Menstrual_cycle_length` FLOAT,
    `Number_of_days_of_Menses` FLOAT,
    `Previous_miscarriages` INT,
    `Previous_live_births`  INT,
    `Has_the_patient_ever_given_birth` VARCHAR(50),
    `Does_patient_have_HBP` VARCHAR(50),
    `Does_patient_have_DM`  VARCHAR(50),
    `Has_patient_been_transfused` VARCHAR(50),
    `Any_History_of_STI`   VARCHAR(100),
    `Any_abnormal_vaginal_discharge` VARCHAR(50),
    `Any_abnormal_genital_swelling` VARCHAR(50),
    `Age_of_spouse` INT,
    `Occupation_of_spouse` VARCHAR(100),
    `Does_spouse_have_HBP` VARCHAR(50),
    `Does_spouse_have_DM`  VARCHAR(50),
    `Has_spouse_been_transfused` VARCHAR(50),
    `Any_history_of_STI_spouse` VARCHAR(100),
    `Abnormal_discharge_spouse` VARCHAR(50),
    `Abnormal_swelling_spouse`  VARCHAR(50),
    `Has_spouse_impotence` VARCHAR(50),
    `HSG_Result`           VARCHAR(200),
    `HyCoSy_Result`        VARCHAR(200),
    `TVS_Result`           VARCHAR(200),
    `Umor_Cysts`           VARCHAR(100),
    `FSH` FLOAT,
    `LH` FLOAT,
    `Prolactin` FLOAT,
    `TSH` FLOAT,
    `Semen_Analysis_Result` VARCHAR(300),
    `_id` INT,
    `_uuid` VARCHAR(100),
    `_submission_time` VARCHAR(50),
    `_validation_status` VARCHAR(50),
    `_notes` VARCHAR(200),
    `_status` VARCHAR(100),
    `_submitted_by` VARCHAR(100),
    `_tags` VARCHAR(100),
    `_index` INT
);

LOAD DATA LOCAL INFILE "C:/Users/tejaj/OneDrive/Desktop/project 2/Reports and Dashboards Data3.csv"
INTO TABLE data3
CHARACTER SET latin1
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

select count(*) from data3;





