SELECT *
FROM layoffs;

-- Data Cleaning
-- 1. Remove Duplicates
-- 2. Standardize the Data (issues with spelling [capitalized or lowecase], then we standardize and make them all the same format, phone number formatting)
-- 3. Null Values or blank values (populate if you can. There are times where you should and other times where you shouldn't)
-- 4. Remove any columns and rows that aren't necessary

-- To avoid manipulating the raw data, create a new table
CREATE TABLE layoffs_staging
LIKE layoffs; -- this way, the primary keys and secondary indexes are copied over as well.



SELECT *
FROM layoffs_staging;

INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

/*---------- starting the cleaning process -----------------*/
/*---------- Step One -----------------*/
-- 1. Removing duplicates
-- The process involves creating unique identifying rows
SELECT
	*,
	ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

WITH duplicate_cte AS (
	SELECT
		*,
		ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
	FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- how you would DELETE duplicate in SQL Server:
WITH duplicate_cte AS (
	SELECT
		*,
		ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
	FROM layoffs_staging
)
DELETE
FROM duplicate_cte
WHERE row_num > 1;
-- you can't do it in MySQL because the target table (duplicate_cte) is not updateable

-- so, instead what we will do is create another staging table off of the query in the CTE and then delete the rows there.
-- we create the following create statement by right clicking on the layoffs_staging table > copy to clipboard > create statement
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int -- we added this one so we can filter on this and delete the necessary rows.
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

insert into layoffs_staging2
SELECT
	*,
	ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

-- run the following SELECT statement to identify what you're about to delete
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- now, we delete the rows in this new table
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- check again to ensure we deleted it.
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- now, we not that the column "row_num" is not necessary anymore. We only needed it to help us remove duplicates. 
-- the reason we don't need it is because it is a redundant column, adds up extra space in memory and storage.
-- the reason we had to do it this way was because we didn't have a column to uniquely identify each row at the start of the dataset.

/*---------- Step Two -----------------*/
-- 2. Standardizing Data (finding issue, fixing them, and format data)
-- First, check out the company column
-- remove whitespace from before and after the data
SELECT 
	company, TRIM(company)
FROM layoffs_staging2;

-- update all rows in the table's company column to that of TRIM(company)
UPDATE layoffs_staging2
SET company = TRIM(company);

-- verify that it worked
SELECT *
FROM layoffs_staging2;

-- next, we'll work on the industry col
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY 1; -- this orders by the first column (in this case by industry since it is the only column selected)

-- found 3 industries that should be standardized. They were Crypto, CryptoCurrency, and Crypto Currency
SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- There are some null and empty values in the industry column that I will fix later

-- Next, we'll look to see if there's anything to fix in the location column
SELECT DISTINCT location
FROM layoffs_staging2;
-- it's good, next moving on to country
SELECT DISTINCT country
FROM layoffs_staging2;

-- found a period after the US. 
-- checked to see if trim and trailing works:
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
order by 1;

-- update the table to delete that period.
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

SELECT DISTINCT country
FROM layoffs_staging2
WHERE country LIKE 'United States%';

-- next, we found that the date column is of the TEXT data type, so we use the STR_TO_DATE() function to convert it to DATE or DATETIME data type.
SELECT 
	`date`,
    STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

-- update the whole column to be DATE data type
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- if we had tried to convert the column to a DATE column from TEXT, it would give us an error, but now that we've converted the rows in the col
-- to DATE data types, we can alter the column data type to that of DATE
-- AGAIN, NEVER alter the raw dataset, only do this on the staging dataset.
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

SELECT 
	*
FROM layoffs_staging2;

/*---------- Step Three -----------------*/
-- 3. Working with NULL and Blank values

-- looking for nulls in certain columns
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
 OR industry = '';

-- so, we see that we have some matches with the query right above. Now, since we selected all cols for that query, we know the 
-- company name's, so we can search for other entries of that company and check if they have some data filled for industry. If so, 
-- we just have to populate the data.
SELECT *
FROM layoffs_staging2 
WHERE company = 'Airbnb' OR company LIKE 'Bally%';

-- we found that Airbnb is in the travel industry so we update that col
UPDATE layoffs_staging2
SET industry = 'Travel'
WHERE company = 'Airbnb';
-- another method that doesn't involve manually changing it like I did just now, would be to join the table to itself and update the values 
-- that are blank or null
SELECT *
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2 
	ON t1.company = t2.company
WHERE 
	(t1.industry IS NULL OR t1.industry = '') AND -- we are checking if there is an industry in this table that is null or blank and...
	t2.industry IS NOT NULL; -- if it matches with an industry in this table that is not null

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
SET t1.company = t2.company
WHERE 
	t1.industry IS NULL AND
    t2.industry IS NOT NULL;

-- initially, doesn't work because there are blank records in both columns so, an empty cell can't go into another blank cell.
-- the work around for this was to set the columns that were initially blank (on t1) to null values;
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- then run the select statement to see if we get the same records to fix. (but this time removing the search for t1.industry = '')
SELECT *
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2 
	ON t1.company = t2.company
WHERE 
	t1.industry IS NULL AND 
	t2.industry IS NOT NULL;

/*---------- Step Three -----------------*/
-- 4. Remove any columns or rows that aren't necessary

-- looking again at the columns and rows that had NULL values for total_laid_off and percentage_laid_off because 
-- they serve no value to us (DEPENDING ON THE QUESTION asked by the client). If they want us to check the companies that had layoffs
-- then we can get rid of these if we can't get data out of it.
SELECT *
FROM layoffs_staging2
WHERE 
	total_laid_off IS NULL AND
	percentage_laid_off IS NULL;

-- we can delete it because we won't need it for the exploratory part of this project
DELETE
FROM layoffs_staging2
WHERE 
	total_laid_off IS NULL AND
	percentage_laid_off IS NULL;

-- check table again
SELECT *
FROM layoffs_staging2;

-- delete the row_num column
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- check table again
SELECT *
FROM layoffs_staging2;












