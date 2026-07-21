select *from table2;

DESCRIBE table2;

DROP TABLE IF EXISTS table2_dedup;

CREATE TABLE table2_dedup AS
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY fc_no, cycle_no, age, duration_of_infertility, bmi
           ) AS rn
    FROM table2
) t
WHERE rn = 1;

DROP TABLE table2;
RENAME TABLE table2_dedup TO table2;


DELETE FROM table2
WHERE fc_no IS NULL
   OR primary_infertility IS NULL
   OR protocol IS NULL
   OR cause IS NULL;
   
DROP PROCEDURE IF EXISTS impute_table2_median;
DELIMITER $$
CREATE PROCEDURE impute_table2_median()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);
  DECLARE n INT;
  DECLARE offset INT;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table2'
      AND DATA_TYPE IN ('int','bigint','float','double','decimal');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  loop1: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE loop1; END IF;

    SET @q = CONCAT('SELECT COUNT(`', col, '`) INTO @n FROM table2 WHERE `', col, '` IS NOT NULL');
    PREPARE s FROM @q; EXECUTE s; DEALLOCATE PREPARE s;
    SET n = @n;

    IF n = 0 THEN ITERATE loop1; END IF;

    IF (n % 2) = 1 THEN
      SET offset = FLOOR(n/2);
      SET @q = CONCAT('SELECT `', col, '` INTO @med FROM table2 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', offset, ',1');
    ELSE
      SET offset = n/2 - 1;
      SET @q = CONCAT('SELECT AVG(x) INTO @med FROM (SELECT `', col, '` AS x FROM table2 WHERE `', col, '` IS NOT NULL ORDER BY `', col, '` LIMIT ', offset, ',2) q');
    END IF;

    PREPARE s2 FROM @q; EXECUTE s2; DEALLOCATE PREPARE s2;

    SET @medval = @med;
    SET @q = CONCAT('UPDATE table2 SET `', col, '` = ', @medval, ' WHERE `', col, '` IS NULL');
    PREPARE s3 FROM @q; EXECUTE s3; DEALLOCATE PREPARE s3;

  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL impute_table2_median();
DROP PROCEDURE IF EXISTS impute_table2_median;


DROP PROCEDURE IF EXISTS cap_table2_outliers;
DELIMITER $$
CREATE PROCEDURE cap_table2_outliers()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE col VARCHAR(128);

  DECLARE cur CURSOR FOR
  SELECT COLUMN_NAME
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'table2'
    AND DATA_TYPE IN ('double','float','decimal','int','bigint');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  loop2: LOOP
    FETCH cur INTO col;
    IF done = 1 THEN LEAVE loop2; END IF;

    SET @q = CONCAT('SELECT AVG(`', col, '`), STDDEV_POP(`', col, '`) INTO @m, @s FROM table2');
    PREPARE s FROM @q; EXECUTE s; DEALLOCATE PREPARE s;

    IF @s IS NULL OR @s = 0 THEN ITERATE loop2; END IF;

    SET @low = @m - 3*@s;
    SET @high = @m + 3*@s;

    SET @q = CONCAT('UPDATE table2 SET `', col, '` = LEAST(GREATEST(`', col, '`, ', @low, '), ', @high, ')');
    PREPARE s2 FROM @q; EXECUTE s2; DEALLOCATE PREPARE s2;

  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL cap_table2_outliers();
DROP PROCEDURE IF EXISTS cap_table2_outliers;

DROP TABLE IF EXISTS table2_stats;

CREATE TABLE table2_stats (
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

DROP PROCEDURE IF EXISTS compute_numeric_eda_for_table2;
DELIMITER $$
CREATE PROCEDURE compute_numeric_eda_for_table2()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE colname VARCHAR(128);
  DECLARE n_count INT;
  DECLARE offset_val INT;

  DECLARE cur CURSOR FOR
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'table2'
      AND DATA_TYPE IN ('tinyint','smallint','mediumint','int','bigint','decimal','float','double','real');

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  TRUNCATE TABLE table2_stats;

  OPEN cur;
  eda_loop: LOOP
    FETCH cur INTO colname;
    IF done = 1 THEN
      LEAVE eda_loop;
    END IF;

    SET @sql = CONCAT('SELECT COUNT(`', colname, '`) INTO @n FROM table2 WHERE `', colname, '` IS NOT NULL');
    PREPARE ps1 FROM @sql; EXECUTE ps1; DEALLOCATE PREPARE ps1;
    SET n_count = CAST(IFNULL(@n,0) AS SIGNED);

    IF n_count = 0 THEN
      INSERT INTO table2_stats(column_name, n) VALUES(colname, 0);
      SET @n = NULL;
      ITERATE eda_loop;
    END IF;

    SET @sql = CONCAT('SELECT AVG(`', colname, '`), VAR_POP(`', colname, '`), STDDEV_POP(`', colname, '`) INTO @meanv, @varv, @stdv FROM table2 WHERE `', colname, '` IS NOT NULL');
    PREPARE ps2 FROM @sql; EXECUTE ps2; DEALLOCATE PREPARE ps2;

    IF (n_count % 2) = 1 THEN
      SET offset_val = FLOOR(n_count/2);
      SET @sql = CONCAT('SELECT `', colname, '` INTO @medianv FROM table2 WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', CAST(offset_val AS SIGNED), ',1');
    ELSE
      SET offset_val = CAST(n_count/2 - 1 AS SIGNED);
      SET @sql = CONCAT('SELECT AVG(x) INTO @medianv FROM (SELECT `', colname, '` AS x FROM table2 WHERE `', colname, '` IS NOT NULL ORDER BY `', colname, '` LIMIT ', CAST(offset_val AS SIGNED), ',2) t');
    END IF;
    PREPARE ps3 FROM @sql; EXECUTE ps3; DEALLOCATE PREPARE ps3;

    SET @sql = CONCAT('SELECT `', colname, '` INTO @modev FROM table2 WHERE `', colname, '` IS NOT NULL GROUP BY `', colname, '` ORDER BY COUNT(*) DESC LIMIT 1');
    PREPARE ps4 FROM @sql; EXECUTE ps4; DEALLOCATE PREPARE ps4;

    IF @meanv IS NOT NULL THEN
      SET @sql = CONCAT('SELECT SUM(POW(`', colname, '` - ', CAST(@meanv AS CHAR), ',3)), SUM(POW(`', colname, '` - ', CAST(@meanv AS CHAR), ',4)) INTO @s3, @s4 FROM table2 WHERE `', colname, '` IS NOT NULL');
      PREPARE ps5 FROM @sql; EXECUTE ps5; DEALLOCATE PREPARE ps5;
    ELSE
      SET @s3 = NULL; SET @s4 = NULL;
    END IF;

    IF @stdv IS NULL OR @stdv = 0 THEN
      SET @skew = NULL;
      SET @kurt = NULL;
    ELSE
      SET @skew = (@s3 / n_count) / POW(@stdv, 3);
      SET @kurt = (@s4 / n_count) / POW(@stdv, 4) - 3;
    END IF;

    INSERT INTO table2_stats(column_name, n, mean, median, mode, variance, stddev, skewness, kurtosis)
    VALUES(colname, n_count, @meanv, @medianv, @modev, @varv, @stdv, @skew, @kurt);

    SET @n = NULL; SET @meanv = NULL; SET @varv = NULL; SET @stdv = NULL;
    SET @medianv = NULL; SET @modev = NULL; SET @s3 = NULL; SET @s4 = NULL;
    SET @skew = NULL; SET @kurt = NULL;
  END LOOP;

  CLOSE cur;
END$$
DELIMITER ;

CALL compute_numeric_eda_for_table2();

SELECT * FROM table2_stats ORDER BY column_name;
