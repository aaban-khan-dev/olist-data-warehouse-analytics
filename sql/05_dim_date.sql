USE OlistDW;
GO

DROP TABLE IF EXISTS mart.dim_date;
GO

CREATE TABLE mart.dim_date (
    date_sk       INT         PRIMARY KEY,   
    full_date     DATE        NOT NULL,
    year          INT         NOT NULL,
    quarter       INT         NOT NULL,
    month         INT         NOT NULL,
    month_name    VARCHAR(20) NOT NULL,
    day           INT         NOT NULL,
    weekday_name  VARCHAR(20) NOT NULL,
    is_weekend    BIT         NOT NULL,
    is_holiday    BIT         NOT NULL DEFAULT 0,
    holiday_name  VARCHAR(50) NULL
);
GO


-- Generate one row per calendar day using a recursive CTE
WITH date_range AS (
    SELECT CAST('2016-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d)
    FROM date_range
    WHERE d < '2018-12-31'
)
INSERT INTO mart.dim_date
    (date_sk, full_date, year, quarter, month, month_name, day, weekday_name, is_weekend, is_holiday)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd')) AS date_sk,
    d                                    AS full_date,
    YEAR(d)                              AS year,
    DATEPART(QUARTER, d)                 AS quarter,
    MONTH(d)                             AS month,
    DATENAME(MONTH, d)                   AS month_name,
    DAY(d)                               AS day,
    DATENAME(WEEKDAY, d)                 AS weekday_name,
    CASE WHEN DATENAME(WEEKDAY, d) IN ('Saturday','Sunday') THEN 1 ELSE 0 END AS is_weekend,
    0                                    AS is_holiday
FROM date_range
OPTION (MAXRECURSION 0);   
GO


-- Unknown-date member (date_sk = -1) for facts with null/bad dates
INSERT INTO mart.dim_date
    (date_sk, full_date, year, quarter, month, month_name, day, weekday_name, is_weekend, is_holiday, holiday_name)
VALUES
    (-1, '1900-01-01', 1900, 1, 1, 'Unknown', 1, 'Unknown', 0, 0, 'Unknown');
GO


-- Fixed-date Brazilian national holidays 
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'New Year'       WHERE month = 1  AND day = 1;
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'Tiradentes'     WHERE month = 4  AND day = 21;
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'Labour Day'     WHERE month = 5  AND day = 1;
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'Independence'   WHERE month = 9  AND day = 7;
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'Our Lady Aparecida' WHERE month = 10 AND day = 12;
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'All Souls'      WHERE month = 11 AND day = 2;
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'Republic Day'   WHERE month = 11 AND day = 15;
UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'Christmas'      WHERE month = 12 AND day = 25;

UPDATE mart.dim_date SET is_holiday = 1, holiday_name = 'Carnival' WHERE full_date IN ('2016-02-08','2016-02-09','2017-02-27','2017-02-28','2018-02-12','2018-02-13');
GO


-- Row count
SELECT COUNT(*) AS total_rows FROM mart.dim_date;

-- Spot check a few dates
SELECT * FROM mart.dim_date WHERE full_date IN ('2017-01-01','2017-12-25','2017-02-28','2017-06-15');

-- Confirm holidays flagged
SELECT full_date, holiday_name FROM mart.dim_date WHERE is_holiday = 1 ORDER BY full_date;

-- Weekend check
SELECT weekday_name, is_weekend, COUNT(*) FROM mart.dim_date GROUP BY weekday_name, is_weekend ORDER BY is_weekend;