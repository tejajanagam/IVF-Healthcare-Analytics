select *from table4;

desc table4;


DROP TABLE IF EXISTS table4_clean;
DROP TABLE IF EXISTS table4_dedup;
DROP TABLE IF EXISTS table4_stats;
DROP PROCEDURE IF EXISTS impute_table4_median;
DROP PROCEDURE IF EXISTS cap_table4_outliers;
DROP PROCEDURE IF EXISTS compute_table4_eda;


CREATE TABLE table4_clean AS
SELECT
  group_1_chm_2_non_chm_,

  age_year_,

  bmi_kg_m2_,

  duration_of_fertility_year_,

  types_of_infertility_1_primary_2_secondary_,

  lh_fsh,

  /* Convert text to numeric safely */
  CASE 
      WHEN TRIM(REPLACE(tt_nmol_l_, ',', '.')) REGEXP '^[+-]?[0-9]+(\\.[0-9]+)?$'
      THEN CAST(REPLACE(tt_nmol_l_, ',', '.') AS DOUBLE)
      ELSE NULL
  END AS tt_nmol_l_,

  e2_pmol_l_,

  dose_of_gn_iu_,

  duration_of_gn_d_,

  e2_on_the_hcg_day_pmol_l_,

  retrieved_oocytes,

  fertilization_,

  good_quality_embryo_,

  clinical_pregnancy,

  miscarriage,

  live_birth,

  ga_weeks_,

  delivery_1_spontaneous_delivery_2_cs_3_conversion_to_cs_

FROM table4;

-- 2. Deduplicate
CREATE TABLE table4_dedup AS
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
             PARTITION BY group_1_chm_2_non_chm_, age_year_, bmi_kg_m2_, retrieved_oocytes
           ) AS rn
    FROM table4_clean
) t
WHERE rn = 1;

DROP TABLE table4_clean;
RENAME TABLE table4_dedup TO table4_clean;

-- 3. Median imputation for numeric columns
-- corrected median-imputation procedure for table4_clean
DROP PROCEDURE IF EXISTS impute_table4_median;
DELIMITER $$
CREATE PROCEDURE impute_table4_median()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE n INT DEFAULT 0;
  DECLARE offset_val INT DEFAULT 0;
  DECLARE med_local DOUBLE DEFAULT NULL;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table4_clean'
      AND DATA_TYPE IN ('bigint','double','float','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  impute_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN
      LEAVE impute_loop;
    END IF;

    -- 1) count non-null values into @cnt (via prepared statement)
    SET @sql = CONCAT('SELECT COUNT(`', col, '`) INTO @cnt FROM table4_clean WHERE `', col, '` IS NOT NULL');
    PREPARE stmt_count FROM @sql; EXECUTE stmt_count; DEALLOCATE PREPARE stmt_count;
    SET n = IFNULL(@cnt, 0);

    IF n = 0 THEN
      -- nothing to impute for this column
      SET @cnt = NULL;
      ITERATE impute_loop;
    END IF;

    -- 2) compute median into @med using proper LIMIT logic
    IF (n % 2) = 1 THEN
      SET offset_val = FLOOR(n/2);
      SET @sql = CONCAT(
        'SELECT `', col, '` INTO @med FROM table4_clean WHERE `', col,
        '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS CHAR), ',1'
      );
    ELSE
      SET offset_val = n/2 - 1;
      SET @sql = CONCAT(
        'SELECT AVG(x) INTO @med FROM (SELECT `', col,
        '` AS x FROM table4_clean WHERE `', col, '` IS NOT NULL ORDER BY `', col,
        '` LIMIT ', CAST(offset_val AS CHAR), ',2) t'
      );
    END IF;

    PREPARE stmt_med FROM @sql; EXECUTE stmt_med; DEALLOCATE PREPARE stmt_med;
    SET med_local = @med;            -- move into local variable
    SET @medv = med_local;          -- and into user var for safe CONCAT in next step

    -- 3) update NULLs only if median is not null
    IF @medv IS NOT NULL THEN
      SET @sql = CONCAT('UPDATE table4_clean SET `', col, '` = ', @medv, ' WHERE `', col, '` IS NULL');
      PREPARE stmt_upd FROM @sql; EXECUTE stmt_upd; DEALLOCATE PREPARE stmt_upd;
    END IF;

    -- reset temp vars for next column
    SET @cnt = NULL; SET @med = NULL; SET @medv = NULL; SET med_local = NULL;
  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

-- run the procedure
CALL impute_table4_median();

-- clean up
DROP PROCEDURE IF EXISTS impute_table4_median;

-- 4. Cap outliers (mean ± 3*stddev)
DROP PROCEDURE IF EXISTS cap_table4_outliers;
DELIMITER $$
CREATE PROCEDURE cap_table4_outliers()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table4_clean'
      AND DATA_TYPE IN ('bigint','double','float','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;

  outlier_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE outlier_loop; END IF;

    /* -------------------------------------------
       1) Compute AVG and STD into @m and @s
       ------------------------------------------- */
    SET @sql := CONCAT(
        'SELECT AVG(`', col, '`), STDDEV_POP(`', col, '`) ',
        'INTO @m, @s FROM table4_clean WHERE `', col, '` IS NOT NULL'
    );
    PREPARE stmt1 FROM @sql;
    EXECUTE stmt1;
    DEALLOCATE PREPARE stmt1;

    IF @s IS NULL OR @s = 0 THEN
      ITERATE outlier_loop;
    END IF;

    /* -------------------------------------------
       2) Compute bounds
       ------------------------------------------- */
    SET @low  := @m - 3*@s;
    SET @high := @m + 3*@s;

    /* -------------------------------------------
       3) Update values within the range
       ------------------------------------------- */
    SET @sql := CONCAT(
        'UPDATE table4_clean ',
        'SET `', col, '` = LEAST(GREATEST(`', col, '`, ', @low, '), ', @high, ') ',
        'WHERE `', col, '` IS NOT NULL'
    );

    PREPARE stmt2 FROM @sql;
    EXECUTE stmt2;
    DEALLOCATE PREPARE stmt2;

    -- reset
    SET @m = NULL; SET @s = NULL; SET @low = NULL; SET @high = NULL;

  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

-- Run it
CALL cap_table4_outliers();

-- Optionally drop procedure
DROP PROCEDURE IF EXISTS cap_table4_outliers;


-- 5. Create EDA table
CREATE TABLE table4_stats (
  column_name VARCHAR(128),
  n BIGINT,
  mean DOUBLE,
  median DOUBLE,
  mode DOUBLE,
  variance DOUBLE,
  stddev DOUBLE,
  skewness DOUBLE,
  kurtosis DOUBLE
);

-- 6. EDA Procedure
-- corrected compute_table4_eda procedure for table4_clean
DROP PROCEDURE IF EXISTS compute_table4_eda;

-- ensure results table exists (will be truncated by procedure)
DROP TABLE IF EXISTS table4_stats;
CREATE TABLE table4_stats (
  column_name VARCHAR(128) PRIMARY KEY,
  n BIGINT,
  mean DOUBLE,
  median DOUBLE,
  mode DOUBLE,
  variance DOUBLE,
  stddev DOUBLE,
  skewness DOUBLE,
  kurtosis DOUBLE
);

DELIMITER $$
CREATE PROCEDURE compute_table4_eda()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE n INT DEFAULT 0;
  DECLARE offset_val INT DEFAULT 0;

  DECLARE med_val DOUBLE DEFAULT NULL;
  DECLARE mode_val DOUBLE DEFAULT NULL;
  DECLARE mean_val DOUBLE DEFAULT NULL;
  DECLARE var_val DOUBLE DEFAULT NULL;
  DECLARE std_val DOUBLE DEFAULT NULL;
  DECLARE s3 DOUBLE DEFAULT NULL;
  DECLARE s4 DOUBLE DEFAULT NULL;
  DECLARE skew_val DOUBLE DEFAULT NULL;
  DECLARE kurt_val DOUBLE DEFAULT NULL;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table4_clean'
      AND DATA_TYPE IN ('bigint','double','float','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  TRUNCATE TABLE table4_stats;

  OPEN cur;
  eda_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN
      LEAVE eda_loop;
    END IF;

    -- 1) count non-null
    SET @sql = CONCAT('SELECT COUNT(`', col, '`) INTO @n FROM table4_clean WHERE `', col, '` IS NOT NULL');
    PREPARE stmt_cnt FROM @sql; EXECUTE stmt_cnt; DEALLOCATE PREPARE stmt_cnt;
    SET n = IFNULL(@n, 0);

    IF n = 0 THEN
      INSERT INTO table4_stats(column_name, n) VALUES(col, 0);
      SET @n = NULL;
      ITERATE eda_loop;
    END IF;

    -- 2) median
    IF (n % 2) = 1 THEN
      SET offset_val = FLOOR(n/2);
      SET @sql = CONCAT('SELECT `', col, '` INTO @med FROM table4_clean WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS CHAR), ',1');
    ELSE
      SET offset_val = n/2 - 1;
      SET @sql = CONCAT(
        'SELECT AVG(x) INTO @med FROM (SELECT `', col, '` AS x FROM table4_clean WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ',
        CAST(offset_val AS CHAR), ',2) t'
      );
    END IF;
    PREPARE stmt_med FROM @sql; EXECUTE stmt_med; DEALLOCATE PREPARE stmt_med;
    SET med_val = @med;

    -- 3) mode (most frequent single value)
    SET @sql = CONCAT('SELECT `', col, '` INTO @mode FROM table4_clean WHERE `', col, '` IS NOT NULL GROUP BY `', col, '` ORDER BY COUNT(*) DESC LIMIT 1');
    PREPARE stmt_mode FROM @sql; EXECUTE stmt_mode; DEALLOCATE PREPARE stmt_mode;
    SET mode_val = @mode;

    -- 4) mean, variance (population), stddev (population)
    SET @sql = CONCAT('SELECT AVG(`', col, '`), VAR_POP(`', col, '`), STDDEV_POP(`', col, '`) INTO @mean, @var, @std FROM table4_clean WHERE `', col, '` IS NOT NULL');
    PREPARE stmt_stat FROM @sql; EXECUTE stmt_stat; DEALLOCATE PREPARE stmt_stat;
    SET mean_val = @mean; SET var_val = @var; SET std_val = @std;

    -- 5) skewness & kurtosis sums (if mean exists)
    IF mean_val IS NOT NULL THEN
      SET @sql = CONCAT(
        'SELECT SUM(POW(`', col, '` - ', CAST(mean_val AS CHAR), ',3)), SUM(POW(`', col, '` - ', CAST(mean_val AS CHAR), ',4)) ',
        'INTO @s3, @s4 FROM table4_clean WHERE `', col, '` IS NOT NULL'
      );
      PREPARE stmt_sums FROM @sql; EXECUTE stmt_sums; DEALLOCATE PREPARE stmt_sums;
      SET s3 = @s3; SET s4 = @s4;
    ELSE
      SET s3 = NULL; SET s4 = NULL;
    END IF;

    -- 6) compute skew & kurtosis safely
    IF std_val IS NULL OR std_val = 0 THEN
      SET skew_val = NULL;
      SET kurt_val = NULL;
    ELSE
      SET skew_val = (s3 / n) / POW(std_val, 3);
      SET kurt_val = (s4 / n) / POW(std_val, 4) - 3;
    END IF;

    -- 7) insert result row
    INSERT INTO table4_stats(column_name, n, mean, median, mode, variance, stddev, skewness, kurtosis)
    VALUES(col, n, mean_val, med_val, mode_val, var_val, std_val, skew_val, kurt_val);

    -- reset temp vars
    SET @n = NULL; SET @med = NULL; SET @mode = NULL; SET @mean = NULL; SET @var = NULL; SET @std = NULL;
    SET @s3 = NULL; SET @s4 = NULL;
    SET n = 0; SET med_val = NULL; SET mode_val = NULL; SET mean_val = NULL; SET var_val = NULL; SET std_val = NULL;
    SET s3 = NULL; SET s4 = NULL; SET skew_val = NULL; SET kurt_val = NULL;

  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;


CALL compute_table4_eda();


SELECT * FROM table4_stats ORDER BY column_name;


SELECT * FROM table4_stats;
SELECT * FROM table4_clean LIMIT 20;


