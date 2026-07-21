create database ivf1;
use ivf1;
select *from raw_table;
select *from table2;
select *from table3;
select *from table4;
select *from table5;
select *from table6;

DESCRIBE raw_table;

DROP TABLE IF EXISTS raw_table_cleaned;
DROP TABLE IF EXISTS raw_table_dedup;
DROP TABLE IF EXISTS numeric_stats_results;
DROP PROCEDURE IF EXISTS impute_numeric_mean_then_median;
DROP PROCEDURE IF EXISTS cap_numeric_outliers;
DROP PROCEDURE IF EXISTS compute_numeric_eda;

CREATE TABLE raw_table_cleaned AS
SELECT
  NULLIF(TRIM(patient_name_and_surname), '') AS patient_name_and_surname,

  CASE WHEN TRIM(age) REGEXP '^[0-9]+$' THEN CAST(TRIM(age) AS SIGNED) ELSE NULL END AS age,
  CASE WHEN TRIM(spouse_age) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(spouse_age),',','.') AS DOUBLE) ELSE NULL END AS spouse_age,

  NULLIF(TRIM(clinical_pregnancy), '') AS clinical_pregnancy,

  CASE WHEN TRIM(live_birth) REGEXP '^[0-9]+$' THEN CAST(TRIM(live_birth) AS SIGNED) ELSE NULL END AS live_birth,
  CASE WHEN TRIM(week_of_birth) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(week_of_birth),',','.') AS DOUBLE) ELSE NULL END AS week_of_birth,
  CASE WHEN TRIM(neonatal_death) REGEXP '^[0-9]+$' THEN CAST(TRIM(neonatal_death) AS SIGNED) ELSE NULL END AS neonatal_death,

  NULLIF(TRIM(abortion), '') AS abortion,

  CASE WHEN TRIM(bhcg_12) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(bhcg_12),',','.') AS DOUBLE) ELSE NULL END AS bhcg_12,
  CASE WHEN TRIM(bhcg_14) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(bhcg_14),',','.') AS DOUBLE) ELSE NULL END AS bhcg_14,

  NULLIF(TRIM(bhcg_12_14_increase), '') AS bhcg_12_14_increase,

  CASE WHEN TRIM(twin) REGEXP '^[0-9]+$' THEN CAST(TRIM(twin) AS SIGNED) ELSE NULL END AS twin,
  CASE WHEN TRIM(indication) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(indication),',','.') AS DOUBLE) ELSE NULL END AS indication,
  CASE WHEN TRIM(fsh) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(fsh),',','.') AS DOUBLE) ELSE NULL END AS fsh,

  CASE WHEN REPLACE(TRIM(e2),',','.') REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(e2),',','.') AS DOUBLE) ELSE NULL END AS e2,
  CASE WHEN REPLACE(TRIM(progesterone),',','.') REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(progesterone),',','.') AS DOUBLE) ELSE NULL END AS progesterone,
  CASE WHEN REPLACE(TRIM(number_of_oocytes),',','.') REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(number_of_oocytes),',','.') AS DOUBLE) ELSE NULL END AS number_of_oocytes,

  CASE WHEN TRIM(embryo_tranfer_day) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(embryo_tranfer_day),',','.') AS DOUBLE) ELSE NULL END AS embryo_tranfer_day,

  CASE WHEN REPLACE(TRIM(endometrial_thickness_on_the_day_of_transfer),',','.') REGEXP '^[0-9.]+$'
       THEN CAST(REPLACE(TRIM(endometrial_thickness_on_the_day_of_transfer),',','.') AS DOUBLE) ELSE NULL END
       AS endometrial_thickness_on_the_day_of_transfer,

  CASE WHEN TRIM(ind_number_of_days) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(ind_number_of_days),',','.') AS DOUBLE) ELSE NULL END AS ind_number_of_days,
  CASE WHEN TRIM(number_of_embryos_transferred) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(number_of_embryos_transferred),',','.') AS DOUBLE) ELSE NULL END AS number_of_embryos_transferred,

  CASE WHEN TRIM(eu) REGEXP '^[0-9]+$' THEN CAST(TRIM(eu) AS SIGNED) ELSE NULL END AS eu,
  CASE WHEN TRIM(amh) REGEXP '^[0-9.]+$' THEN CAST(REPLACE(TRIM(amh),',','.') AS DOUBLE) ELSE NULL END AS amh

FROM raw_table;

-- Quick check
SELECT COUNT(*) AS raw_table_cleaned_rows FROM raw_table_cleaned;


-- Remove duplicates 

CREATE TABLE raw_table_dedup AS
SELECT *
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        COALESCE(patient_name_and_surname, '<<NULL>>'),
        COALESCE(age, -999999999),
        COALESCE(spouse_age, -999999999),
        COALESCE(clinical_pregnancy, '<<NULL>>'),
        COALESCE(live_birth, -999999999),
        COALESCE(week_of_birth, -999999999),
        COALESCE(neonatal_death, -999999999),
        COALESCE(abortion, '<<NULL>>'),
        COALESCE(bhcg_12, -999999999),
        COALESCE(bhcg_14, -999999999),
        COALESCE(bhcg_12_14_increase, '<<NULL>>'),
        COALESCE(twin, -999999999),
        COALESCE(indication, -999999999),
        COALESCE(fsh, -999999999),
        COALESCE(e2, -999999999),
        COALESCE(progesterone, -999999999),
        COALESCE(number_of_oocytes, -999999999),
        COALESCE(embryo_tranfer_day, -999999999),
        COALESCE(endometrial_thickness_on_the_day_of_transfer, -999999999),
        COALESCE(ind_number_of_days, -999999999),
        COALESCE(number_of_embryos_transferred, -999999999),
        COALESCE(eu, -999999999),
        COALESCE(amh, -999999999)
      ORDER BY patient_name_and_surname, age
    ) AS rn
  FROM raw_table_cleaned
) t
WHERE rn = 1;

-- Replace cleaned table with deduped table
DROP TABLE raw_table_cleaned;
RENAME TABLE raw_table_dedup TO raw_table_cleaned;

SELECT COUNT(*) AS deduped_rows FROM raw_table_cleaned;


--  Show numeric NULL counts (bump GROUP_CONCAT for safety)

SET SESSION group_concat_max_len = 1000000;

SET @sql = (
  SELECT GROUP_CONCAT(
    CONCAT(
      'SELECT ''', COLUMN_NAME, ''' AS col, SUM(`', COLUMN_NAME, '` IS NULL) AS nulls FROM raw_table_cleaned'
    ) SEPARATOR ' UNION ALL '
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'raw_table_cleaned'
    AND DATA_TYPE IN ('tinyint','smallint','mediumint','int','bigint','decimal','float','double','real')
);

-- safe dynamic null-count run (replacement for the IF block)
SET SESSION group_concat_max_len = 1000000;

SET @sql = (
  SELECT GROUP_CONCAT(
    CONCAT(
      'SELECT ''', COLUMN_NAME, ''' AS col, SUM(`', COLUMN_NAME, '` IS NULL) AS nulls FROM raw_table_cleaned'
    ) SEPARATOR ' UNION ALL '
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'raw_table_cleaned'
    AND DATA_TYPE IN ('tinyint','smallint','mediumint','int','bigint','decimal','float','double','real')
);

-- if no numeric cols were found, fall back to a harmless SELECT message
SET @sql = COALESCE(@sql, 'SELECT ''No numeric columns found in raw_table_cleaned'' AS msg');

PREPARE stmt_count FROM @sql;
EXECUTE stmt_count;
DEALLOCATE PREPARE stmt_count;

-- Impute numeric NULLs — mean, and if mean is NULL fallback to median

DROP PROCEDURE IF EXISTS impute_numeric_mean_then_median;
DELIMITER $$
CREATE PROCEDURE impute_numeric_mean_then_median()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE colname VARCHAR(128);

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'raw_table_cleaned'
      AND DATA_TYPE IN ('tinyint','smallint','mediumint','int','bigint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO colname;
    IF done = 1 THEN
      LEAVE read_loop;
    END IF;

    -- count available values
    SET @sql = CONCAT('SELECT COUNT(`', colname, '`) INTO @n FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL');
    PREPARE s_count FROM @sql; EXECUTE s_count; DEALLOCATE PREPARE s_count;

    IF @n IS NULL OR @n = 0 THEN
      ITERATE read_loop;
    END IF;

    -- try mean
    SET @sql = CONCAT('SELECT AVG(`', colname, '`) INTO @mean_val FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL');
    PREPARE s_mean FROM @sql; EXECUTE s_mean; DEALLOCATE PREPARE s_mean;

    -- if mean missing, compute median
    IF @mean_val IS NULL THEN
      IF (@n % 2) = 1 THEN
        SET @offset = FLOOR(@n/2);
        SET @sql = CONCAT('SELECT `', colname, '` INTO @median_val FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', @offset, ',1');
        PREPARE s_med1 FROM @sql; EXECUTE s_med1; DEALLOCATE PREPARE s_med1;
      ELSE
        SET @offset = @n/2 - 1;
        SET @sql = CONCAT('SELECT AVG(x) INTO @median_val FROM (SELECT `', colname, '` AS x FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', @offset, ',2) t');
        PREPARE s_med2 FROM @sql; EXECUTE s_med2; DEALLOCATE PREPARE s_med2;
      END IF;
    END IF;

    SET @rep = IFNULL(@mean_val, @median_val);

    IF @rep IS NOT NULL THEN
      SET @sql = CONCAT('UPDATE raw_table_cleaned SET `', colname, '` = ', @rep, ' WHERE `', colname, '` IS NULL');
      PREPARE s_upd FROM @sql; EXECUTE s_upd; DEALLOCATE PREPARE s_upd;
    END IF;

    -- reset
    SET @mean_val = NULL;
    SET @median_val = NULL;
    SET @n = NULL;
    SET @rep = NULL;

  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;

CALL impute_numeric_mean_then_median();
DROP PROCEDURE IF EXISTS impute_numeric_mean_then_median;



--  Reomve text null values

DELETE FROM raw_table_cleaned
WHERE patient_name_and_surname IS NULL
   OR clinical_pregnancy IS NULL
   OR abortion IS NULL
   OR bhcg_12_14_increase IS NULL;


-- Step 6: Cap numeric outliers using mean ± 3*stddev (auto-detect numeric columns)

DROP PROCEDURE IF EXISTS cap_numeric_outliers;
DELIMITER $$
CREATE PROCEDURE cap_numeric_outliers()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE colname VARCHAR(128);

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'raw_table_cleaned'
      AND DATA_TYPE IN ('tinyint','smallint','mediumint','int','bigint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  cap_loop: LOOP
    FETCH cur INTO colname;
    IF done = 1 THEN
      LEAVE cap_loop;
    END IF;

    SET @sql = CONCAT('SELECT AVG(`', colname, '`), STDDEV_POP(`', colname, '`) INTO @m, @s FROM raw_table_cleaned');
    PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

    IF @s IS NOT NULL AND @s > 0 THEN
      SET @high = @m + 3*@s;
      SET @low  = @m - 3*@s;
      SET @sql = CONCAT('UPDATE raw_table_cleaned SET `', colname, '` = GREATEST(LEAST(`', colname, '`, ', @high, '), ', @low, ')');
      PREPARE s2 FROM @sql; EXECUTE s2; DEALLOCATE PREPARE s2;
    END IF;

    SET @m = NULL; SET @s = NULL; SET @high = NULL; SET @low = NULL;

  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;

CALL cap_numeric_outliers();
DROP PROCEDURE IF EXISTS cap_numeric_outliers;


-- Compute numeric EDA and store in numeric_stats_results

DROP PROCEDURE IF EXISTS compute_numeric_eda;
DROP TABLE IF EXISTS numeric_stats_results;

CREATE TABLE numeric_stats_results (
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
CREATE PROCEDURE compute_numeric_eda()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE colname VARCHAR(128);

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'raw_table_cleaned'
      AND DATA_TYPE IN ('tinyint','smallint','mediumint','int','bigint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  TRUNCATE TABLE numeric_stats_results;

  OPEN cur;
  eda_loop: LOOP
    FETCH cur INTO colname;
    IF done = 1 THEN
      LEAVE eda_loop;
    END IF;

    -- count into @n
    SET @sql = CONCAT('SELECT COUNT(`', colname, '`) INTO @n FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL');
    PREPARE stmt1 FROM @sql; EXECUTE stmt1; DEALLOCATE PREPARE stmt1;

    -- cast to integer safely
    SET @n_int = CAST(IFNULL(@n,0) AS SIGNED);

    IF @n_int = 0 THEN
      INSERT INTO numeric_stats_results(column_name, n) VALUES(colname, 0);
      -- reset user vars
      SET @n = NULL; SET @n_int = NULL;
      ITERATE eda_loop;
    END IF;

    -- mean, var_pop, std_pop into user vars
    SET @sql = CONCAT('SELECT AVG(`', colname, '`), VAR_POP(`', colname, '`), STDDEV_POP(`', colname, '`) INTO @mean_val, @var_pop, @std_pop FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL');
    PREPARE stmt2 FROM @sql; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

    -- compute median with integer offset
    IF (@n_int % 2) = 1 THEN
      SET @offset = FLOOR(@n_int/2);
      SET @sql = CONCAT('SELECT `', colname, '` INTO @median_val FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', CAST(@offset AS SIGNED), ',1');
    ELSE
      SET @offset = CAST(@n_int/2 - 1 AS SIGNED);
      SET @sql = CONCAT('SELECT AVG(x) INTO @median_val FROM (SELECT `', colname, '` AS x FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', CAST(@offset AS SIGNED), ',2) t');
    END IF;
    PREPARE stmt3 FROM @sql; EXECUTE stmt3; DEALLOCATE PREPARE stmt3;

    -- mode
    SET @sql = CONCAT('SELECT `', colname, '` INTO @mode_val FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL GROUP BY `', colname, '` ORDER BY COUNT(*) DESC LIMIT 1');
    PREPARE stmt4 FROM @sql; EXECUTE stmt4; DEALLOCATE PREPARE stmt4;

    -- sums for skew/kurt (only if mean exists)
    IF @mean_val IS NULL THEN
      SET @sum3 = NULL; SET @sum4 = NULL;
    ELSE
      SET @sql = CONCAT('SELECT SUM(POW(`', colname, '` - ', CAST(@mean_val AS CHAR), ',3)), SUM(POW(`', colname, '` - ', CAST(@mean_val AS CHAR), ',4)) INTO @sum3, @sum4 FROM raw_table_cleaned WHERE `', colname, '` IS NOT NULL');
      PREPARE stmt5 FROM @sql; EXECUTE stmt5; DEALLOCATE PREPARE stmt5;
    END IF;

    -- compute skewness/kurtosis
    IF @std_pop IS NULL OR @std_pop = 0 THEN
      SET @skew = NULL; SET @kurt = NULL;
    ELSE
      SET @skew = (@sum3 / @n_int) / POW(@std_pop, 3);
      SET @kurt = (@sum4 / @n_int) / POW(@std_pop, 4) - 3;
    END IF;

    -- insert results (use the user vars)
    INSERT INTO numeric_stats_results(column_name, n, mean, median, mode, variance, stddev, skewness, kurtosis)
    VALUES(colname, @n_int, @mean_val, @median_val, @mode_val, @var_pop, @std_pop, @skew, @kurt);

    -- reset user vars for next iteration
    SET @n = NULL; SET @n_int = NULL; SET @mean_val = NULL; SET @var_pop = NULL; SET @std_pop = NULL;
    SET @median_val = NULL; SET @mode_val = NULL; SET @sum3 = NULL; SET @sum4 = NULL; SET @skew = NULL; SET @kurt = NULL;
    SET @offset = NULL;

  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;


CALL compute_numeric_eda();
DROP PROCEDURE IF EXISTS compute_numeric_eda;

-- Preview numeric stats
SELECT * FROM numeric_stats_results ORDER BY column_name;


--  Export cleaned table to CSV on the DB server (change path if needed)

SELECT * FROM raw_table_cleaned
INTO OUTFILE '/tmp/raw_table_cleaned.csv'
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

SELECT COUNT(*) AS final_row_count FROM raw_table_cleaned;
SELECT * FROM raw_table_cleaned LIMIT 10;
SELECT * FROM numeric_stats_results ORDER BY column_name;
