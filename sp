CREATE PROCEDURE GetSeriesByAttributes
    @FilterCriteria FilterTableType READONLY -- Accept the filter table as a parameter
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Declare variables for dynamic SQL
    DECLARE @Columns NVARCHAR(MAX), @FilterConditions NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

    -- Step 2: Get the unique list of attributes (ensure NVARCHAR(MAX))
    SELECT @Columns = STRING_AGG(QUOTENAME(ATT_NAME), ',') WITHIN GROUP (ORDER BY ATT_NAME)
    FROM (SELECT DISTINCT CAST(ATT_NAME AS NVARCHAR(MAX)) AS ATT_NAME FROM YourTable) AS Attrs;

    -- Step 3: Dynamically generate filter conditions (ensure NVARCHAR(MAX))
    SELECT @FilterConditions = STRING_AGG(
        'p.' + QUOTENAME(CAST(ATT_NAME AS NVARCHAR(MAX))) + ' = f.[ATTRIBUTE_VALUE] AND f.[ATTRIBUTE] = ''' + CAST(ATT_NAME AS NVARCHAR(MAX)) + '''',
        ' AND '
    ) WITHIN GROUP (ORDER BY ATT_NAME)
    FROM (SELECT DISTINCT CAST(ATT_NAME AS NVARCHAR(MAX)) AS ATT_NAME FROM YourTable) AS Attrs;

    -- Step 4: Ensure both variables are treated as NVARCHAR(MAX)
    SET @Columns = CAST(@Columns AS NVARCHAR(MAX));
    SET @FilterConditions = CAST(@FilterConditions AS NVARCHAR(MAX));

    -- Step 5: Build the dynamic SQL for pivoting and filtering
    SET @DynamicSQL = '
        -- Create pivoted table
        SELECT SERIES_NAME, ' + @Columns + '
        INTO #PivotedTable
        FROM (
            SELECT SERIES_NAME, ATT_NAME, ATT_VALUE
            FROM YourTable
        ) AS SourceTable
        PIVOT (
            MAX(ATT_VALUE) FOR ATT_NAME IN (' + @Columns + ')
        ) AS PivotTable;

        -- Filter pivoted table
        SELECT p.SERIES_NAME
        INTO #MatchingSeries
        FROM #PivotedTable p
        JOIN @FilterCriteria f
            ON (p.inst_type = f.[INSTRUMENT] OR f.[INSTRUMENT] IS NULL)
            AND (' + @FilterConditions + ');

        -- Fetch all rows for matching series
        SELECT t.*
        FROM YourTable t
        JOIN #MatchingSeries s
            ON t.SERIES_NAME = s.SERIES_NAME;

        -- Cleanup temporary tables
        DROP TABLE #PivotedTable;
        DROP TABLE #MatchingSeries;
    ';

    -- Step 6: Execute dynamic SQL
    EXEC sp_executesql @DynamicSQL, N'@FilterCriteria FilterTableType READONLY', @FilterCriteria = @FilterCriteria;
END;