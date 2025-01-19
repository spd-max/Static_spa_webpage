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