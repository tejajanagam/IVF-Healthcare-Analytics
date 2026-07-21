select *from table5;

desc table5;


DROP TABLE IF EXISTS table5_backup;
CREATE TABLE table5_backup AS SELECT * FROM table5;


DROP TABLE IF EXISTS table5_clean;
CREATE TABLE table5_clean AS
SELECT
  -- treat group as integer-like (NULL if not numeric)
  CASE WHEN TRIM(REPLACE(CAST(group_1_chm_2_non_chm_ AS CHAR),',','.')) REGEXP '^[+-]?[0-9]+$'
       THEN CAST(REPLACE(TRIM(CAST(group_1_chm_2_non_chm_ AS CHAR)),',','.') AS SIGNED)
       ELSE NULL END AS group_1_chm_2_non_chm_,

  CASE WHEN TRIM(REPLACE(CAST(weight_kg_ AS CHAR),',','.')) REGEXP '^[+-]?[0-9]+(\\.[0-9]+)?$'
       THEN CAST(REPLACE(TRIM(CAST(weight_kg_ AS CHAR)),',','.') AS DOUBLE) ELSE NULL END AS weight_kg_,

  CASE WHEN TRIM(REPLACE(CAST(apgar AS CHAR),',','.')) REGEXP '^[+-]?[0-9]+(\\.[0-9]+)?$'
       THEN CAST(REPLACE(TRIM(CAST(apgar AS CHAR)),',','.') AS DOUBLE) ELSE NULL END AS apgar,

  CASE WHEN TRIM(REPLACE(CAST(gender_0_male_1_female_ AS CHAR),',','.')) REGEXP '^[+-]?[0-9]+(\\.[0-9]+)?$'
       THEN CAST(REPLACE(TRIM(CAST(gender_0_male_1_female_ AS CHAR)),',','.') AS DOUBLE) ELSE NULL END AS gender_0_male_1_female_,

  NULLIF(TRIM(CAST(note AS CHAR)), '') AS note

FROM table5;

-- 2) Deduplicate (keep first row per full key set)
DROP TABLE IF EXISTS table5_dedup;
CREATE TABLE table5_dedup AS
SELECT *
FROM (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY group_1_chm_2_non_chm_, weight_kg_, apgar, gender_0_male_1_female_, note
           ORDER BY group_1_chm_2_non_chm_
         ) AS __rn__
  FROM table5_clean
) t
WHERE __rn__ = 1;

DROP TABLE IF EXISTS table5_clean;
RENAME TABLE table5_dedup TO table5_clean;

DELETE FROM table5_clean WHERE group_1_chm_2_non_chm_ IS NULL;

-- 4) Median imputation for numeric columns (safe procedure)
DROP PROCEDURE IF EXISTS impute_table5_median;
DELIMITER $$
CREATE PROCEDURE impute_table5_median()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE ncnt INT DEFAULT 0;
  DECLARE offset_val INT DEFAULT 0;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table5_clean'
      AND DATA_TYPE IN ('bigint','double','float','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  impute_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE impute_loop; END IF;

    -- count non-null values into @cnt
    SET @sql = CONCAT('SELECT COUNT(`', col, '`) INTO @cnt FROM table5_clean WHERE `', col, '` IS NOT NULL');
    PREPARE stmt_cnt FROM @sql; EXECUTE stmt_cnt; DEALLOCATE PREPARE stmt_cnt;
    SET ncnt = IFNULL(@cnt, 0);

    IF ncnt = 0 THEN
      SET @cnt = NULL;
      ITERATE impute_loop;
    END IF;

    -- compute median into @med
    IF (ncnt % 2) = 1 THEN
      SET offset_val = FLOOR(ncnt/2);
      SET @sql = CONCAT('SELECT `', col, '` INTO @med FROM table5_clean WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS CHAR), ',1');
    ELSE
      SET offset_val = ncnt/2 - 1;
      SET @sql = CONCAT('SELECT AVG(x) INTO @med FROM (SELECT `', col, '` AS x FROM table5_clean WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS CHAR), ',2) t');
    END IF;

    PREPARE stmt_med FROM @sql; EXECUTE stmt_med; DEALLOCATE PREPARE stmt_med;

    -- update NULLs if median exists
    IF @med IS NOT NULL THEN
      SET @sql = CONCAT('UPDATE table5_clean SET `', col, '` = ', @med, ' WHERE `', col, '` IS NULL');
      PREPARE stmt_upd FROM @sql; EXECUTE stmt_upd; DEALLOCATE PREPARE stmt_upd;
    END IF;

    SET @cnt = NULL; SET @med = NULL;
  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL impute_table5_median();
DROP PROCEDURE IF EXISTS impute_table5_median;

-- 5) Cap numeric outliers (mean ± 3 * stddev) using safe dynamic SQL
DROP PROCEDURE IF EXISTS cap_table5_outliers;
DELIMITER $$
CREATE PROCEDURE cap_table5_outliers()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table5_clean'
      AND DATA_TYPE IN ('bigint','double','float','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  outlier_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE outlier_loop; END IF;

    -- compute mean and std into @m and @s
    SET @sql = CONCAT('SELECT AVG(`', col, '`), STDDEV_POP(`', col, '`) INTO @m, @s FROM table5_clean WHERE `', col, '` IS NOT NULL');
    PREPARE stmt1 FROM @sql; EXECUTE stmt1; DEALLOCATE PREPARE stmt1;

    IF @s IS NULL OR @s = 0 THEN
      ITERATE outlier_loop;
    END IF;

    SET @low = @m - 3*@s;
    SET @high = @m + 3*@s;

    SET @sql = CONCAT('UPDATE table5_clean SET `', col, '` = LEAST(GREATEST(`', col, '`, ', @low, '), ', @high, ') WHERE `', col, '` IS NOT NULL');
    PREPARE stmt2 FROM @sql; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

    SET @m = NULL; SET @s = NULL; SET @low = NULL; SET @high = NULL;
  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL cap_table5_outliers();
DROP PROCEDURE IF EXISTS cap_table5_outliers;

-- 6) Create EDA results table and procedure
DROP TABLE IF EXISTS table5_stats;
CREATE TABLE table5_stats (
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

DROP PROCEDURE IF EXISTS compute_table5_eda;
DELIMITER $$
CREATE PROCEDURE compute_table5_eda()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE ncnt INT DEFAULT 0;
  DECLARE offset_val INT DEFAULT 0;
  DECLARE med_val DOUBLE;
  DECLARE mode_val DOUBLE;
  DECLARE mean_val DOUBLE;
  DECLARE var_val DOUBLE;
  DECLARE std_val DOUBLE;
  DECLARE s3 DOUBLE;
  DECLARE s4 DOUBLE;
  DECLARE skew_val DOUBLE;
  DECLARE kurt_val DOUBLE;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table5_clean'
      AND DATA_TYPE IN ('bigint','double','float','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  TRUNCATE TABLE table5_stats;

  OPEN cur;
  eda_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE eda_loop; END IF;

    -- count non-null
    SET @sql = CONCAT('SELECT COUNT(`', col, '`) INTO @cnt FROM table5_clean WHERE `', col, '` IS NOT NULL');
    PREPARE stmt_cnt FROM @sql; EXECUTE stmt_cnt; DEALLOCATE PREPARE stmt_cnt;
    SET ncnt = IFNULL(@cnt, 0);

    IF ncnt = 0 THEN
      INSERT INTO table5_stats(column_name, n) VALUES(col, 0);
      SET @cnt = NULL;
      ITERATE eda_loop;
    END IF;

    -- median
    IF (ncnt % 2) = 1 THEN
      SET offset_val = FLOOR(ncnt/2);
      SET @sql = CONCAT('SELECT `', col, '` INTO @med FROM table5_clean WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS CHAR), ',1');
    ELSE
      SET offset_val = ncnt/2 - 1;
      SET @sql = CONCAT('SELECT AVG(x) INTO @med FROM (SELECT `', col, '` AS x FROM table5_clean WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS CHAR), ',2) t');
    END IF;
    PREPARE stmt_med FROM @sql; EXECUTE stmt_med; DEALLOCATE PREPARE stmt_med;
    SET med_val = @med;

    -- mode (most frequent single value)
    SET @sql = CONCAT('SELECT `', col, '` INTO @mode FROM table5_clean WHERE `', col, '` IS NOT NULL GROUP BY `', col, '` ORDER BY COUNT(*) DESC LIMIT 1');
    PREPARE stmt_mode FROM @sql; EXECUTE stmt_mode; DEALLOCATE PREPARE stmt_mode;
    SET mode_val = @mode;

    -- mean, var_pop, stddev_pop
    SET @sql = CONCAT('SELECT AVG(`', col, '`), VAR_POP(`', col, '`), STDDEV_POP(`', col, '`) INTO @mean, @var, @std FROM table5_clean WHERE `', col, '` IS NOT NULL');
    PREPARE stmt_stat FROM @sql; EXECUTE stmt_stat; DEALLOCATE PREPARE stmt_stat;
    SET mean_val = @mean; SET var_val = @var; SET std_val = @std;

    -- skew/kurt sums
    IF mean_val IS NOT NULL THEN
      SET @sql = CONCAT('SELECT SUM(POW(`', col, '` - ', CAST(mean_val AS CHAR), ',3)), SUM(POW(`', col, '` - ', CAST(mean_val AS CHAR), ',4)) INTO @s3, @s4 FROM table5_clean WHERE `', col, '` IS NOT NULL');
      PREPARE stmt_sums FROM @sql; EXECUTE stmt_sums; DEALLOCATE PREPARE stmt_sums;
      SET s3 = @s3; SET s4 = @s4;
    ELSE
      SET s3 = NULL; SET s4 = NULL;
    END IF;

    IF std_val IS NULL OR std_val = 0 THEN
      SET skew_val = NULL; SET kurt_val = NULL;
    ELSE
      SET skew_val = (s3 / ncnt) / POW(std_val, 3);
      SET kurt_val = (s4 / ncnt) / POW(std_val, 4) - 3;
    END IF;

    INSERT INTO table5_stats(column_name, n, mean, median, mode, variance, stddev, skewness, kurtosis)
    VALUES(col, ncnt, mean_val, med_val, mode_val, var_val, std_val, skew_val, kurt_val);

    -- reset
    SET @cnt = NULL; SET @med = NULL; SET @mode = NULL; SET @mean = NULL; SET @var = NULL; SET @std = NULL;
    SET @s3 = NULL; SET @s4 = NULL;
    SET ncnt = 0; SET med_val = NULL; SET mode_val = NULL; SET mean_val = NULL; SET var_val = NULL; SET std_val = NULL;
    SET s3 = NULL; SET s4 = NULL; SET skew_val = NULL; SET kurt_val = NULL;
  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL compute_table5_eda();
DROP PROCEDURE IF EXISTS compute_table5_eda;

-- 7) Show final stats and a sample of cleaned rows
SELECT * FROM table5_stats ORDER BY column_name;
SELECT * FROM table5_clean LIMIT 50;
