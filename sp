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