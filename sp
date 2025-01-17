CREATE PROCEDURE GetSeriesByAttributes
    @FilterCriteria FilterTableType READONLY -- Accept user input as a parameter
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Declare variables for dynamic SQL
    DECLARE @RelevantAttributes NVARCHAR(MAX), @FilterConditions NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

    -- Step 2: Identify relevant attributes dynamically (from user-provided filter table)
    SELECT @RelevantAttributes = STRING_AGG(QUOTENAME(ATTRIBUTE), ',')
    FROM (SELECT DISTINCT ATTRIBUTE FROM @FilterCriteria) AS Attrs;

    -- Step 3: Generate dynamic WHERE conditions for filtering pivoted data
    SELECT @FilterConditions = STRING_AGG(
        'p.' + QUOTENAME(ATTRIBUTE) + ' = f.ATTRIBUTE_VALUE AND f.ATTRIBUTE = ''' + ATTRIBUTE + '''',
        ' AND '
    )
    FROM (SELECT DISTINCT ATTRIBUTE FROM @FilterCriteria) AS Attrs;

    -- Ensure the variables are NVARCHAR(MAX) to avoid truncation
    SET @RelevantAttributes = CAST(@RelevantAttributes AS NVARCHAR(MAX));
    SET @FilterConditions = CAST(@FilterConditions AS NVARCHAR(MAX));

    -- Step 4: Generate dynamic SQL for pivoting and filtering
    SET @DynamicSQL = '
        -- Step 4.1: Create pivoted table with only relevant attributes
        SELECT SERIES_NAME, ' + @RelevantAttributes + '
        INTO #PivotedTable
        FROM (
            SELECT SERIES_NAME, ATT_NAME, ATT_VALUE
            FROM YourTable
            WHERE ATT_NAME IN (SELECT ATTRIBUTE FROM @FilterCriteria) -- Process only relevant attributes
        ) AS SourceTable
        PIVOT (
            MAX(ATT_VALUE) FOR ATT_NAME IN (' + @RelevantAttributes + ')
        ) AS PivotTable;

        -- Step 4.2: Filter pivoted data based on filter conditions
        SELECT DISTINCT p.SERIES_NAME
        INTO #MatchingSeries
        FROM #PivotedTable p
        JOIN @FilterCriteria f
            ON (' + @FilterConditions + ');

        -- Step 4.3: Retrieve all rows for matching series from the original table
        SELECT t.*
        FROM YourTable t
        JOIN #MatchingSeries s
            ON t.SERIES_NAME = s.SERIES_NAME;

        -- Cleanup temporary tables
        DROP TABLE #PivotedTable;
        DROP TABLE #MatchingSeries;
    ';

    -- Step 5: Execute the dynamic SQL
    EXEC sp_executesql @DynamicSQL, N'@FilterCriteria FilterTableType READONLY', @FilterCriteria = @FilterCriteria;
END;