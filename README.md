# 📉 Data Cleaning in SQL: Layoffs Dataset

## 📝 Introduction

This project showcases my end-to-end SQL data cleaning process using a real-world layoffs dataset.
The goal was to take a raw, messy dataset and transform it into a clean, analysis-ready table using structured, repeatable SQL techniques.

## 🏁 Background

Raw datasets frequently contain issues such as:

- duplicate rows
- inconsistent text formatting
- inconsistent date formats
- blank and NULL values
- incorrect spellings
- unnecessary or irrelevant rows

This project walks through the exact SQL steps needed to clean the layoffs dataset.
To avoid altering the original data, I use staging tables, window functions, string functions, self-joins, and column transformations.

### Cleaning Objectives

1. Remove duplicates
2. Standardize text fields and formats
3. Identify and fix NULLs and blank values when appropriate
4. Convert incorrect data types (e.g., text → date)
5. Remove unnecessary rows and temporary columns

## 🛠️ Tools I Used

This entire project was built using:

- **SQL**: The backbone of my data cleaning, allowing me to query and modify the database. Critical in unearthing uncleansed data
- **MySQL**: The chosen database management system. Ideal for data previewing, schema exploration, and testing cleaning logic
- **MySQL Workbench**: Used for writing and executing SQL scripts
- **Git & GitHub**: Essential for version control and sharing my SQL scripts and data cleaning process, ensuring collaboration and project tracking

## 🔍 The Analysis: Data Cleaning Workflow

### 1. Remove Duplicates

Because MySQL does not allow deleting from a CTE directly, I used a staging table:

- Created layoffs_staging as a copy of the raw dataset
- Generated a row_num column using ROW_NUMBER() window function
- Inserted everything into a further staging table, layoffs_staging2
- Deleted rows where row_num > 1

**Key Query Snippet**:

```sql
WITH duplicate_cte AS (
	SELECT
		*,
		ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
	FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

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

INSERT INTO layoffs_staging2
SELECT
	*,
	ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

DELETE
FROM layoffs_staging2
WHERE row_num > 1;
```

### 2. Standardize & Clean Text Columns

**Actions included**:

- TRIM() company names
- Normalize industry names (CryptoCurrency → Crypto)
- Remove trailing punctuation in country names
- Convert date strings using STR_TO_DATE()
- Alter column metadata from TEXT → DATE

**Example**:

```sql
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';
```

### 3. Handling NULL and Blank Values

- Identified NULL rows in important columns
- Used a self-join to populate missing industry values
- Converted blank strings to NULL for consistency

**Key Query**:

```sql
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND  t2.industry IS NOT NULL;
```

### 4. Delete Irrelevant Rows / Columns

Rows with no layoff information were removed:

```sql
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;
```

Temporary columns like row_num were dropped because they were used in the staging table to delete duplicate rows.

## 📘 What I Learned

This project reinforced several valuable SQL data engineering concepts:

- How to safely clean data using staging tables
- How to remove duplicates using window functions in MySQL
- How to normalize categorical data using string functions
- How to handle NULL vs. empty string inconsistencies
- How to convert messy string dates into proper DATE formats
- How to use self-joins to enrich missing data
- How to think like a data engineer when preparing data for analysis

## Conclusion

By the end of this project, the original messy dataset was transformed into:

- A clean, analysis-ready table
- Consistent formats
- Standardized categories
- Reliable text fields
- Validated date formats
- No duplicates
- Only relevant rows

## Closing Thoughts

This project helped me understand how important reproducible cleaning workflows are in SQL.
Every decision, whether to delete, transform, or enrich data, needs to be logical and documented.

Data cleaning projects like this one are invaluable for roles in data engineering and data analytics.

🔗 Feel free to explore the SQL script, clone the repo, or reach out with questions!
