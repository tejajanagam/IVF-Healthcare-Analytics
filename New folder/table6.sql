select *from table6;
desc table6

CREATE TABLE table6_dedup AS
SELECT *
FROM (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY group_1_chm_2_non_chm_, bmp15_pg_ml_, lif_pg_ml_
           ORDER BY group_1_chm_2_non_chm_, bmp15_pg_ml_, lif_pg_ml_
         ) AS __rownum__
  FROM table6
) t
WHERE __rownum__ = 1;

-- replace original table (rename)
DROP TABLE IF EXISTS table6;
RENAME TABLE table6_dedup TO table6;

-- 3. Median imputation procedure (numeric columns only)
DROP PROCEDURE IF EXISTS impute_table6_median;
DELIMITER $$
CREATE PROCEDURE impute_table6_median()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE ncnt INT;
  DECLARE offset_val INT;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table6'
      AND DATA_TYPE IN ('bigint','int','smallint','mediumint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  median_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE median_loop; END IF;

    -- count non-null values into user var @cnt
    SET @sql = CONCAT('SELECT COUNT(`', col, '`) INTO @cnt FROM table6 WHERE `', col, '` IS NOT NULL');
    PREPARE ps_cnt FROM @sql; EXECUTE ps_cnt; DEALLOCATE PREPARE ps_cnt;
    SET ncnt = CAST(IFNULL(@cnt,0) AS SIGNED);

    IF ncnt = 0 THEN
      SET @cnt = NULL;
      ITERATE median_loop;
    END IF;

    IF (ncnt % 2) = 1 THEN
      SET offset_val = FLOOR(ncnt/2);
      SET @sql = CONCAT('SELECT `', col, '` INTO @med FROM table6 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS SIGNED), ',1');
    ELSE
      SET offset_val = CAST(ncnt/2 - 1 AS SIGNED);
      SET @sql = CONCAT('SELECT AVG(x) INTO @med FROM (SELECT `', col, '` AS x FROM table6 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS SIGNED), ',2) t');
    END IF;

    PREPARE ps_med FROM @sql; EXECUTE ps_med; DEALLOCATE PREPARE ps_med;

    IF @med IS NOT NULL THEN
      SET @upd = CONCAT('UPDATE table6 SET `', col, '` = ', @med, ' WHERE `', col, '` IS NULL');
      PREPARE ps_upd FROM @upd; EXECUTE ps_upd; DEALLOCATE PREPARE ps_upd;
    END IF;

    SET @cnt = NULL; SET @med = NULL; SET @upd = NULL;
  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL impute_table6_median();
DROP PROCEDURE IF EXISTS impute_table6_median;

-- 4. Cap numeric outliers (mean ± 3*std)
DROP PROCEDURE IF EXISTS cap_table6_outliers;
DELIMITER $$
CREATE PROCEDURE cap_table6_outliers()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table6'
      AND DATA_TYPE IN ('bigint','int','smallint','mediumint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  cap_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE cap_loop; END IF;

    -- compute mean/std into @m and @s
    SET @sql = CONCAT('SELECT AVG(`', col, '`), STDDEV_POP(`', col, '`) INTO @m, @s FROM table6 WHERE `', col, '` IS NOT NULL');
    PREPARE ps_stat FROM @sql; EXECUTE ps_stat; DEALLOCATE PREPARE ps_stat;

    IF @s IS NULL OR @s = 0 THEN
      SET @m = NULL; SET @s = NULL;
      ITERATE cap_loop;
    END IF;

    SET @low = @m - 3*@s;
    SET @high = @m + 3*@s;

    SET @sql = CONCAT('UPDATE table6 SET `', col, '` = LEAST(GREATEST(`', col, '`, ', @low, '), ', @high, ') WHERE `', col, '` IS NOT NULL');
    PREPARE ps_upd FROM @sql; EXECUTE ps_upd; DEALLOCATE PREPARE ps_upd;

    SET @m = NULL; SET @s = NULL; SET @low = NULL; SET @high = NULL;
  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;

CALL cap_table6_outliers();
DROP PROCEDURE IF EXISTS cap_table6_outliers;

-- 5. Compute numeric EDA and save to table6_stats
DROP TABLE IF EXISTS table6_stats;
CREATE TABLE table6_stats (
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

DROP PROCEDURE IF EXISTS compute_table6_eda;
DELIMITER $$
CREATE PROCEDURE compute_table6_eda()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE ncnt INT;
  DECLARE offset_val INT;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table6'
      AND DATA_TYPE IN ('bigint','int','smallint','mediumint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  TRUNCATE TABLE table6_stats;

  OPEN cur;
  eda_loop: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE eda_loop; END IF;

    -- count
    SET @sql = CONCAT('SELECT COUNT(`', col, '`) INTO @cnt FROM table6 WHERE `', col, '` IS NOT NULL');
    PREPARE ps_cnt FROM @sql; EXECUTE ps_cnt; DEALLOCATE PREPARE ps_cnt;
    SET ncnt = CAST(IFNULL(@cnt,0) AS SIGNED);

    IF ncnt = 0 THEN
      INSERT INTO table6_stats(column_name, n) VALUES(col, 0);
      SET @cnt = NULL;
      ITERATE eda_loop;
    END IF;

    -- mean, var_pop, std_pop
    SET @sql = CONCAT('SELECT AVG(`', col, '`), VAR_POP(`', col, '`), STDDEV_POP(`', col, '`) INTO @meanv, @varv, @stdv FROM table6 WHERE `', col, '` IS NOT NULL');
    PREPARE ps_stat FROM @sql; EXECUTE ps_stat; DEALLOCATE PREPARE ps_stat;

    -- median
    IF (ncnt % 2) = 1 THEN
      SET offset_val = FLOOR(ncnt/2);
      SET @sql = CONCAT('SELECT `', col, '` INTO @medianv FROM table6 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS SIGNED), ',1');
    ELSE
      SET offset_val = CAST(ncnt/2 - 1 AS SIGNED);
      SET @sql = CONCAT('SELECT AVG(x) INTO @medianv FROM (SELECT `', col, '` AS x FROM table6 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS SIGNED), ',2) t');
    END IF;
    PREPARE ps_med FROM @sql; EXECUTE ps_med; DEALLOCATE PREPARE ps_med;

    -- mode (most frequent single value)
    SET @sql = CONCAT('SELECT `', col, '` INTO @modev FROM table6 WHERE `', col, '` IS NOT NULL GROUP BY `', col, '` ORDER BY COUNT(*) DESC LIMIT 1');
    PREPARE ps_mode FROM @sql; EXECUTE ps_mode; DEALLOCATE PREPARE ps_mode;

    -- sums for skew/kurtosis (if mean exists)
    IF @meanv IS NOT NULL THEN
      SET @sql = CONCAT('SELECT SUM(POW(`', col, '` - ', CAST(@meanv AS CHAR), ',3)), SUM(POW(`', col, '` - ', CAST(@meanv AS CHAR), ',4)) INTO @s3, @s4 FROM table6 WHERE `', col, '` IS NOT NULL');
      PREPARE ps_sums FROM @sql; EXECUTE ps_sums; DEALLOCATE PREPARE ps_sums;
    ELSE
      SET @s3 = NULL; SET @s4 = NULL;
    END IF;

    IF @stdv IS NULL OR @stdv = 0 THEN
      SET @skew = NULL; SET @kurt = NULL;
    ELSE
      SET @skew = (@s3 / ncnt) / POW(@stdv, 3);
      SET @kurt = (@s4 / ncnt) / POW(@stdv, 4) - 3;
    END IF;

    INSERT INTO table6_stats(column_name, n, mean, median, mode, variance, stddev, skewness, kurtosis)
    VALUES(col, ncnt, @meanv, @medianv, @modev, @varv, @stdv, @skew, @kurt);

    -- reset
    SET @cnt = NULL; SET @meanv = NULL; SET @varv = NULL; SET @stdv = NULL;
    SET @medianv = NULL; SET @modev = NULL; SET @s3 = NULL; SET @s4 = NULL;
    SET @skew = NULL; SET @kurt = NULL;
  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;

CALL compute_table6_eda();
DROP PROCEDURE IF EXISTS compute_table6_eda;

-- Show EDA results
SELECT * FROM table6_stats ORDER BY column_name;
