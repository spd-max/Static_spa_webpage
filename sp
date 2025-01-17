CREATE PROCEDURE GetSeriesByAttributes
    @FilterCriteria FilterTableType READONLY -- Accept the filter table as a parameter
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Identify all SERIES_NAME that match the filter criteria
    SELECT t.SERIES_NAME
    INTO #MatchingSeries
    FROM YourTable t
    JOIN @FilterCriteria f
        ON (t.ATT_NAME = 'inst_type' AND t.ATT_VALUE = f.INSTRUMENT)
        OR (t.ATT_NAME = f.ATTRIBUTE AND t.ATT_VALUE = f.ATTRIBUTE_VALUE)
    GROUP BY t.SERIES_NAME
    HAVING COUNT(DISTINCT f.ATTRIBUTE) = (SELECT COUNT(*) FROM @FilterCriteria);

    -- Step 2: Fetch all rows for the matching SERIES_NAME
    SELECT t.*
    FROM YourTable t
    JOIN #MatchingSeries s
        ON t.SERIES_NAME = s.SERIES_NAME;

    -- Cleanup temporary table
    DROP TABLE #MatchingSeries;
END;