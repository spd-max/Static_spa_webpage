CREATE VIEW SeriesInstCode AS
SELECT DISTINCT
    SERIES_NAME,
    ATT_VALUE AS InstCode
FROM YourTable
WHERE ATT_NAME = 'InstCode'; -- Filters only rows where the attribute is InstCod



CREATE PROCEDURE GetFilteredSeries
    @FilterCriteria FilterTableType READONLY -- Accept user input as a parameter
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Filter Series based on InstCode from input table
    DECLARE @InstCode NVARCHAR(50) = (
        SELECT DISTINCT INSTRUMENT
        FROM @FilterCriteria
        WHERE INSTRUMENT IS NOT NULL
    );

    -- Temporary table to store filtered series
    CREATE TABLE #FilteredSeries (
        SERIES_NAME NVARCHAR(50)
    );

    -- Insert matching series from SeriesInstCode
    INSERT INTO #FilteredSeries (SERIES_NAME)
    SELECT SERIES_NAME
    FROM SeriesInstCode
    WHERE InstCode = @InstCode;

    -- Step 2: Pivot relevant rows from the original table
    DECLARE @Columns NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

    -- Get relevant attributes for pivoting
    SELECT @Columns = STRING_AGG(QUOTENAME(ATTRIBUTE), ',') WITHIN GROUP (ORDER BY ATTRIBUTE)
    FROM (SELECT DISTINCT ATTRIBUTE FROM @FilterCriteria WHERE ATTRIBUTE != 'InstCode') AS Attrs;

    -- Ensure @Columns is treated as NVARCHAR(MAX) to avoid truncation
    SET @Columns = ISNULL(@Columns, '');

    -- Construct dynamic SQL for pivoting
    SET @DynamicSQL = '
        SELECT SERIES_NAME, ' + @Columns + '
        FROM (
            SELECT SERIES_NAME, ATT_NAME, ATT_VALUE
            FROM YourTable
            WHERE ATT_NAME IN (SELECT DISTINCT ATTRIBUTE FROM @FilterCriteria WHERE ATTRIBUTE != ''InstCode'')
                AND SERIES_NAME IN (SELECT SERIES_NAME FROM #FilteredSeries)
        ) AS SourceTable
        PIVOT (
            MAX(ATT_VALUE) FOR ATT_NAME IN (' + @Columns + ')
        ) AS PivotTable;
    ';

    -- Debugging: Print dynamic SQL for verification
    PRINT @DynamicSQL;

    -- Execute the dynamic SQL
    EXEC sp_executesql @DynamicSQL;

    -- Cleanup
    DROP TABLE #FilteredSeries;
END;




******^
DECLARE @Columns NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

-- Step 1: Generate the dynamic column list (attribute names)
SELECT @Columns = STRING_AGG(QUOTENAME(ATTRIBUTE), ',') WITHIN GROUP (ORDER BY ATTRIBUTE)
FROM (SELECT DISTINCT ATTRIBUTE FROM @UserInput) AS Attrs;

-- Step 2: Generate the dynamic SQL to pivot the data
SET @DynamicSQL = '
    WITH RankedInput AS (
        SELECT
            INSTRUMENT,
            ATTRIBUTE,
            ATTRIBUTE_VALUE,
            ROW_NUMBER() OVER (PARTITION BY INSTRUMENT, ATTRIBUTE ORDER BY ATTRIBUTE_VALUE) AS RowNum
        FROM @UserInput
    )
    SELECT INSTRUMENT, ' + @Columns + '
    FROM (
        SELECT 
            INSTRUMENT,
            ATTRIBUTE,
            ATTRIBUTE_VALUE,
            RowNum
        FROM RankedInput
    ) AS SourceTable
    PIVOT (
        MAX(ATTRIBUTE_VALUE) FOR ATTRIBUTE IN (' + @Columns + ')
    ) AS PivotTable
    ORDER BY INSTRUMENT, RowNum;
';

-- Step 3: Execute the dynamic SQL
EXEC sp_executesql @DynamicSQL, N'@UserInput UserInputTable READONLY', @UserInput = @UserInput;



DECLARE @Columns NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

-- Step 1: Generate the dynamic column list (attribute names)
SELECT @Columns = STRING_AGG(QUOTENAME(ATTRIBUTE), ',') WITHIN GROUP (ORDER BY ATTRIBUTE)
FROM (SELECT DISTINCT ATTRIBUTE FROM @UserInput) AS Attrs;

-- Step 2: Generate the dynamic SQL to pivot the data
SET @DynamicSQL = '
    WITH RankedInput AS (
        SELECT
            INSTRUMENT,
            ATTRIBUTE,
            ATTRIBUTE_VALUE,
            ROW_NUMBER() OVER (PARTITION BY INSTRUMENT, ATTRIBUTE ORDER BY ATTRIBUTE_VALUE) AS RowNum
        FROM @UserInput
    ),
    DistributedInput AS (
        SELECT
            INSTRUMENT,
            ATTRIBUTE,
            MAX(ATTRIBUTE_VALUE) OVER (PARTITION BY INSTRUMENT, ATTRIBUTE) AS ATTRIBUTE_VALUE,
            RowNum
        FROM RankedInput
    )
    SELECT DISTINCT INSTRUMENT, ' + @Columns + '
    FROM (
        SELECT 
            INSTRUMENT,
            ATTRIBUTE,
            ATTRIBUTE_VALUE,
            RowNum
        FROM DistributedInput
    ) AS SourceTable
    PIVOT (
        MAX(ATTRIBUTE_VALUE) FOR ATTRIBUTE IN (' + @Columns + ')
    ) AS PivotTable
    ORDER BY INSTRUMENT, RowNum;
';

-- Step 3: Execute the dynamic SQL
EXEC sp_executesql @DynamicSQL, N'@UserInput UserInputTable READONLY', @UserInput = @UserInput;




DECLARE @Columns NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

-- Step 1: Get all column names except "instrument" and "rownum"
SELECT @Columns = STRING_AGG(
    'UPDATE e
    SET ' + QUOTENAME(COLUMN_NAME) + ' = COALESCE(e.' + QUOTENAME(COLUMN_NAME) + ', s.' + QUOTENAME(COLUMN_NAME) + ')
    FROM ExistingTable e
    INNER JOIN (
        SELECT instrument, ' + QUOTENAME(COLUMN_NAME) + '
        FROM ExistingTable
        WHERE rownum = 1
    ) AS s
    ON e.instrument = s.instrument
    WHERE e.rownum > 1 AND e.' + QUOTENAME(COLUMN_NAME) + ' IS NULL;',
    CHAR(13) + CHAR(10)
)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ExistingTable' AND COLUMN_NAME NOT IN ('instrument', 'rownum');

-- Step 2: Execute the dynamic updates for each column
EXEC sp_executesql @Columns;




DECLARE @Columns NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

-- Step 1: Get all column names except "instrument" and "rownum"
SELECT @Columns = STRING_AGG(QUOTENAME(COLUMN_NAME), ',')
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ExistingTable' AND COLUMN_NAME NOT IN ('instrument', 'rownum');

-- Step 2: Generate dynamic SQL to create and populate the new table
SET @DynamicSQL = '
    -- Create the new table
    CREATE TABLE NewTable AS
    SELECT 
        e.instrument,
        e.rownum,
        ' + STRING_AGG(
            'COALESCE(e.' + QUOTENAME(COLUMN_NAME) + ', s.' + QUOTENAME(COLUMN_NAME) + ') AS ' + QUOTENAME(COLUMN_NAME),
            ', '
        ) + '
    FROM ExistingTable e
    LEFT JOIN (
        SELECT instrument, ' + @Columns + '
        FROM ExistingTable
        WHERE rownum = 1
    ) AS s
    ON e.instrument = s.instrument
';

-- Step 3: Execute the dynamic SQL
EXEC sp_executesql @DynamicSQL;
