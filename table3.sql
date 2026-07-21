select *from table3;
desc table3;


DROP TABLE IF EXISTS table3_dedup;
DROP TABLE IF EXISTS table3_stats;
DROP PROCEDURE IF EXISTS impute_table3_median;
DROP PROCEDURE IF EXISTS cap_table3_outliers;
DROP PROCEDURE IF EXISTS replace_text_nulls_table3;
DROP PROCEDURE IF EXISTS compute_numeric_eda_for_table3;

CREATE TABLE table3_dedup AS
SELECT *
FROM (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY COALESCE(_id, '<<NULL>>')
           ORDER BY COALESCE(_id, '<<NULL>>')
         ) AS rn
  FROM table3
) t
WHERE rn = 1;

-- replace original table 
DROP TABLE table3;
RENAME TABLE table3_dedup TO table3;

-- 2. Remove rows missing critical fields
DELETE FROM table3
WHERE _id IS NULL
  OR date_of_first_presentation_for_ivf IS NULL;

-- 3. Median imputation for numeric columns
DROP PROCEDURE IF EXISTS impute_table3_median;
DELIMITER $$
CREATE PROCEDURE impute_table3_median()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE ncnt INT;
  DECLARE offset_val INT;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table3'
      AND DATA_TYPE IN ('int','bigint','float','double','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  loop_med: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE loop_med; END IF;

    SET @sql = CONCAT('SELECT COUNT(`', col, '`) INTO @cnt FROM table3 WHERE `', col, '` IS NOT NULL');
    PREPARE ps1 FROM @sql; EXECUTE ps1; DEALLOCATE PREPARE ps1;
    SET ncnt = CAST(IFNULL(@cnt,0) AS SIGNED);

    IF ncnt = 0 THEN
      SET @cnt = NULL;
      ITERATE loop_med;
    END IF;

    IF (ncnt % 2) = 1 THEN
      SET offset_val = FLOOR(ncnt/2);
      SET @sql = CONCAT('SELECT `', col, '` INTO @med FROM table3 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS SIGNED), ',1');
    ELSE
      SET offset_val = CAST(ncnt/2 - 1 AS SIGNED);
      SET @sql = CONCAT('SELECT AVG(x) INTO @med FROM (SELECT `', col, '` AS x FROM table3 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', CAST(offset_val AS SIGNED), ',2) t');
    END IF;

    PREPARE ps2 FROM @sql; EXECUTE ps2; DEALLOCATE PREPARE ps2;

    IF @med IS NOT NULL THEN
      SET @upd = CONCAT('UPDATE table3 SET `', col, '` = ', @med, ' WHERE `', col, '` IS NULL');
      PREPARE ps3 FROM @upd; EXECUTE ps3; DEALLOCATE PREPARE ps3;
    END IF;

    SET @cnt = NULL; SET @med = NULL; SET @upd = NULL;
  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL impute_table3_median();
DROP PROCEDURE IF EXISTS impute_table3_median;

-- 4. Cap numeric outliers (mean ± 3 * std) for numeric columns
DROP PROCEDURE IF EXISTS cap_table3_outliers;
DELIMITER $$
CREATE PROCEDURE cap_table3_outliers()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table3'
      AND DATA_TYPE IN ('double','float','decimal','int','bigint');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  loop_cap: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE loop_cap; END IF;

    SET @q = CONCAT('SELECT AVG(`', col, '`), STDDEV_POP(`', col, '`) INTO @m, @s FROM table3 WHERE `', col, '` IS NOT NULL');
    PREPARE p1 FROM @q; EXECUTE p1; DEALLOCATE PREPARE p1;

    IF @s IS NULL OR @s = 0 THEN
      SET @m = NULL; SET @s = NULL;
      ITERATE loop_cap;
    END IF;

    SET @low = @m - 3*@s;
    SET @high = @m + 3*@s;

    SET @updq = CONCAT('UPDATE table3 SET `', col, '` = LEAST(GREATEST(`', col, '`, ', @low, '), ', @high, ') WHERE `', col, '` IS NOT NULL');
    PREPARE p2 FROM @updq; EXECUTE p2; DEALLOCATE PREPARE p2;

    SET @m = NULL; SET @s = NULL; SET @low = NULL; SET @high = NULL; SET @updq = NULL;
  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;

CALL cap_table3_outliers();
DROP PROCEDURE IF EXISTS cap_table3_outliers;

-- 5. Replace ALL TEXT/VARCHAR/CHAR NULLs with 'Unknown'


DROP PROCEDURE IF EXISTS replace_text_nulls_table3;
DELIMITER $$
CREATE PROCEDURE replace_text_nulls_table3()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE cur1 CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table3'
      AND DATA_TYPE IN ('varchar','text','longtext','char');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur1;
  replace_loop: LOOP
    FETCH cur1 INTO col;
    IF done = 1 THEN
      LEAVE replace_loop;
    END IF;

    SET @upd = CONCAT('UPDATE table3 SET `', col, '` = ''Unknown'' WHERE `', col, '` IS NULL');
    PREPARE stmt_upd FROM @upd;
    EXECUTE stmt_upd;
    DEALLOCATE PREPARE stmt_upd;

  END LOOP;
  CLOSE cur1;
END$$
DELIMITER ;

CALL replace_text_nulls_table3();
DROP PROCEDURE IF EXISTS replace_text_nulls_table3;


-- 6. Compute numeric EDA into table3_stats
DROP TABLE IF EXISTS table3_stats;
CREATE TABLE table3_stats (
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

DROP PROCEDURE IF EXISTS compute_numeric_eda_for_table3;
DELIMITER $$
CREATE PROCEDURE compute_numeric_eda_for_table3()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE colname VARCHAR(128);
  DECLARE n_count INT;
  DECLARE offset_val INT;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table3'
      AND DATA_TYPE IN ('tinyint','smallint','mediumint','int','bigint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  TRUNCATE TABLE table3_stats;

  OPEN cur;
  eda_loop: LOOP
    FETCH cur INTO colname;
    IF done = 1 THEN LEAVE eda_loop; END IF;

    SET @sql = CONCAT('SELECT COUNT(`', colname, '`) INTO @n FROM table3 WHERE `', colname, '` IS NOT NULL');
    PREPARE ps1 FROM @sql; EXECUTE ps1; DEALLOCATE PREPARE ps1;
    SET n_count = CAST(IFNULL(@n,0) AS SIGNED);

    IF n_count = 0 THEN
      INSERT INTO table3_stats(column_name, n) VALUES(colname, 0);
      SET @n = NULL;
      ITERATE eda_loop;
    END IF;

    SET @sql = CONCAT('SELECT AVG(`', colname, '`), VAR_POP(`', colname, '`), STDDEV_POP(`', colname, '`) INTO @meanv, @varv, @stdv FROM table3 WHERE `', colname, '` IS NOT NULL');
    PREPARE ps2 FROM @sql; EXECUTE ps2; DEALLOCATE PREPARE ps2;

    IF (n_count % 2) = 1 THEN
      SET offset_val = FLOOR(n_count/2);
      SET @sql = CONCAT('SELECT `', colname, '` INTO @medianv FROM table3 WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', CAST(offset_val AS SIGNED), ',1');
    ELSE
      SET offset_val = CAST(n_count/2 - 1 AS SIGNED);
      SET @sql = CONCAT('SELECT AVG(x) INTO @medianv FROM (SELECT `', colname, '` AS x FROM table3 WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', CAST(offset_val AS SIGNED), ',2) t');
    END IF;
    PREPARE ps3 FROM @sql; EXECUTE ps3; DEALLOCATE PREPARE ps3;

    SET @sql = CONCAT('SELECT `', colname, '` INTO @modev FROM table3 WHERE `', colname, '` IS NOT NULL GROUP BY `', colname, '` ORDER BY COUNT(*) DESC LIMIT 1');
    PREPARE ps4 FROM @sql; EXECUTE ps4; DEALLOCATE PREPARE ps4;

    IF @meanv IS NOT NULL THEN
      SET @sql = CONCAT('SELECT SUM(POW(`', colname, '` - ', CAST(@meanv AS CHAR), ',3)), SUM(POW(`', colname, '` - ', CAST(@meanv AS CHAR), ',4)) INTO @s3, @s4 FROM table3 WHERE `', colname, '` IS NOT NULL');
      PREPARE ps5 FROM @sql; EXECUTE ps5; DEALLOCATE PREPARE ps5;
    ELSE
      SET @s3 = NULL; SET @s4 = NULL;
    END IF;

    IF @stdv IS NULL OR @stdv = 0 THEN
      SET @skew = NULL; SET @kurt = NULL;
    ELSE
      SET @skew = (@s3 / n_count) / POW(@stdv, 3);
      SET @kurt = (@s4 / n_count) / POW(@stdv, 4) - 3;
    END IF;

    INSERT INTO table3_stats(column_name, n, mean, median, mode, variance, stddev, skewness, kurtosis)
    VALUES(colname, n_count, @meanv, @medianv, @modev, @varv, @stdv, @skew, @kurt);

    SET @n = NULL; SET @meanv = NULL; SET @varv = NULL; SET @stdv = NULL;
    SET @medianv = NULL; SET @modev = NULL; SET @s3 = NULL; SET @s4 = NULL;
    SET @skew = NULL; SET @kurt = NULL;

  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;

CALL compute_numeric_eda_for_table3();
DROP PROCEDURE IF EXISTS compute_numeric_eda_for_table3;

-- 7. Preview results
SELECT * FROM table3_stats ORDER BY column_name;
