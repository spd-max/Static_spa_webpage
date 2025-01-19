CREATE VIEW SeriesInstCode AS
SELECT DISTINCT
    SERIES_NAME,
    ATT_VALUE AS InstCode
FROM YourTable
WHERE ATT_NAME = 'InstCode'; -- Filters only rows where the attribute is InstCode