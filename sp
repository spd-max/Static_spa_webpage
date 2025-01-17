CREATE PROCEDURE GetSeriesByAttributes
    @FilterCriteria FilterTableType READONLY -- Accept the filter table as a parameter
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Filter the main table to find relevant SERIES_NAME
    SELECT DISTINCT t.SERIES_NAME
    INTO #MatchingSeries
    FROM YourTable t
    JOIN @FilterCriteria f
        ON (
            (t.ATT_NAME = 'inst_type' AND t.ATT_VALUE = f.INSTRUMENT) OR
            (t.ATT_NAME = f.ATTRIBUTE AND t.ATT_VALUE = f.ATTRIBUTE_VALUE)
        )
    GROUP BY t.SERIES_NAME
    HAVING COUNT(DISTINCT f.ATTRIBUTE) = 
           (SELECT COUNT(*) FROM @FilterCriteria WHERE INSTRUMENT = f.INSTRUMENT);

    -- Step 2: Pivot only the filtered series
    DECLARE @Columns NVARCHAR(MAX), @DynamicSQL NVARCHAR(MAX);

    -- Get dynamic list of attributes
    SELECT @Columns = STRING_AGG(QUOTENAME(ATT_NAME), ',') WITHIN GROUP (ORDER BY ATT_NAME)
    FROM (SELECT DISTINCT ATT_NAME FROM YourTable) AS Attrs;

    -- Build dynamic SQL for pivoting and final filtering
    SET @DynamicSQL = '
        SELECT SERIES_NAME, ' + @Columns + '
        INTO #PivotedTable
        FROM (
            SELECT SERIES_NAME, ATT_NAME, ATT_VALUE
            FROM YourTable
            WHERE SERIES_NAME IN (SELECT SERIES_NAME FROM #MatchingSeries)
        ) AS SourceTable
        PIVOT (
            MAX(ATT_VALUE) FOR ATT_NAME IN (' + @Columns + ')
        ) AS PivotTable;

        -- Fetch all rows for matching series
        SELECT t.*
        FROM YourTable t
        JOIN #MatchingSeries s
            ON t.SERIES_NAME = s.SERIES_NAME;

        -- Cleanup temporary tables
        DROP TABLE #PivotedTable;
        DROP TABLE #MatchingSeries;
    ';

    -- Execute dynamic SQL
    EXEC sp_executesql @DynamicSQL;
END;