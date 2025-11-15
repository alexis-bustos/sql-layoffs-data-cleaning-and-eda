-- Exploratory Data Analysis

SELECT *
FROM layoffs_staging2;

SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging2;

-- Find companies that have laid off 100 percent of their workforce
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;

-- Find the total number of layoffs based on company
SELECT company, SUM(total_laid_off) as total_layoffs
FROM layoffs_staging2
GROUP BY company
ORDER BY total_layoffs DESC;

-- What is the date range for these layoffs
SELECT MIN(date), MAX(date)
FROM layoffs_staging2;

-- What are the top 5 industry that had the highest number of layoffs?
SELECT
    industry,
    SUM(total_laid_off) as total_layoffs
FROM layoffs_staging2
GROUP BY industry
ORDER BY total_layoffs DESC
LIMIT 5;

-- Which countries had the highest number of layoffs?
SELECT 
    country
, 
    SUM
(total_laid_off) as total_layoffs
FROM layoffs_staging2
GROUP BY country
ORDER BY total_layoffs DESC;

-- How many layoffs were reported per day in the United States?
SELECT
    date,
    SUM(total_laid_off)  AS layoffs_per_day
FROM layoffs_staging2
WHERE country = 'United States'
GROUP BY date
ORDER BY date;

-- Which stages had the most layoffs?
SELECT
    stage,
    SUM(total_laid_off)  AS total_layoffs
FROM layoffs_staging2
GROUP BY stage
ORDER BY 2 DESC;


-- Find the rolling total of layoffs
-- First find how many layoffs per month and year
SELECT
    SUBSTRING(date, 1,7) AS month,
    SUM(total_laid_off) AS layoffs_per_month
FROM layoffs_staging2
WHERE SUBSTRING(date, 1,7) IS NOT NULL
GROUP BY month
ORDER BY 1;

-- next, we'll want to see a rolling sum per month
WITH
    rolling_total
    AS
    (
        SELECT
            SUBSTRING(date, 1,7) AS month,
            SUM(total_laid_off) AS total_layoffs
        FROM layoffs_staging2
        GROUP BY month
        ORDER BY 1
    )
SELECT
    month,
    total_layoffs,
    SUM(total_layoffs) OVER (ORDER BY month) AS rolling_sum
FROM rolling_total;


-- Now, let's look at layoffs per company per year.
SELECT
    company,
    YEAR(date) AS calendar_year,
    SUM(total_laid_off) as total_layoffs
FROM layoffs_staging2
GROUP BY company, calendar_year
ORDER BY company;

-- rank the company with the most amount of layoffs based on previous query
-- You first create a CTE that calculates how many layoffs each company had per year
WITH
    Company_Year (company, years, total_layoffs)
    AS
    (
        SELECT
            company,
            YEAR(date) AS calendar_year,
            SUM(total_laid_off) as total_layoffs
        FROM layoffs_staging2
        GROUP BY company, calendar_year
    )

SELECT *,
    -- Now you take that CTE and apply a DENSE_RANK() window function
    DENSE_RANK() OVER (PARTITION BY years ORDER BY total_layoffs DESC) AS Ranking
/*
    This means:
        Partition by years → for each year separately
        Order by total_layoffs DESC → biggest layoffs rank #1
        DENSE_RANK → If two companies tie, they share the same rank (no rank skipped)
    */
FROM Company_Year
WHERE years IS NOT NULL
ORDER BY Ranking;
-- CTE summarizes total layoffs per company per year.
-- DENSE_RANK ranks companies within each year based on highest layoffs.

-- THE SAME QUERY, but adding another CTE to limit the number of results to the top 
WITH
    Company_Year (company, years, total_layoffs)
    AS
    (
        SELECT
            company,
            YEAR(date) AS years,
            SUM(total_laid_off) as total_layoffs
        FROM layoffs_staging2
        GROUP BY company, years
    ),
    Company_Year_Rank
    AS
    (
        -- add another cte to limit the number of results
        SELECT
            *,
            DENSE_RANK() OVER (PARTITION BY years ORDER BY total_layoffs DESC) AS Ranking
        FROM Company_Year
        WHERE years IS NOT NULL
    )

SELECT *
FROM Company_Year_Rank
WHERE Ranking <= 5
;
-- These results (above) show the top 5 companies with the biggest layoffs


SELECT
    months,
    total_layoffs
FROM
    (SELECT
        SUBSTRING(date, 1,7) AS months,
        total_laid_off,
        SUM(total_laid_off) OVER (PARTITION BY SUBSTRING(date, 1,7) ORDER BY total_laid_off) as total_layoffs
    FROM layoffs_staging2
    WHERE total_laid_off IS NOT NULL) as sub
GROUP BY months, total_layoffs;

WITH
    monthly
    AS
    (
        SELECT
            DATE_FORMAT(date, '%Y-%m') AS months,
            SUM(total_laid_off) AS monthly_layoffs
        FROM layoffs_staging2
        WHERE total_laid_off IS NOT NULL
        GROUP BY months
    )
SELECT
    months,
    monthly_layoffs,
    SUM(monthly_layoffs) OVER (ORDER BY months) as rolling_layoffs
FROM monthly
ORDER BY months;



-- Find the total number of employees each company originally had (for those who provide necessary values)
WITH
    total_employees
    AS
    (
        SELECT company, industry, total_laid_off, percentage_laid_off
        FROM layoffs_staging2
        WHERE 
        total_laid_off IS NOT NULL AND
            percentage_laid_off IS NOT NULL
    )
SELECT *,
    ROUND(total_laid_off / percentage_laid_off,0) AS employees_before_layoffs
FROM total_employees;