 /* ==========================================================================
PROJECT: GLOBAL MACROECONOMIC DATA ANALYSIS
AUTHOR: [Emre Kaya]
DATE: 2026-04-25
DATA SOURCE: World Bank Indicators (2010-2024)
DESCRIPTION: This script processes raw economic data to analyze stability, 
             correlation, and performance across 217  countries.
==========================================================================
*/
 
 -- ==========================================================================
-- SETUP: DATABASE & VIEW CREATION
-- ==========================================================================
-- Ensure you have imported 'WorldBank_Cleaned_Data.csv' as a table named 'RawEconomicData'

DROP VIEW IF EXISTS dbo.v_EconomicSummary;
CREATE VIEW dbo.v_EconomicSummary AS
SELECT 
    CountryName, 
    IndicatorCode, 
    [Year], 
    [Value]
FROM dbo.RawEconomicData;

 -- ==========================================================================
-- 1. COMPREHENSIVE MACROECONOMIC SCORECARD (2023)
-- Goal: Consolidate 8 key indicators into a wide format for global comparison.
-- Indicators: Growth, Inflation, Unemployment, FX, Debt, FDI, etc.
-- ==========================================================================
WITH PivotData AS (
    SELECT 
        CountryName,
        Year,
        MAX(CASE WHEN IndicatorCode = 'NY.GDP.MKTP.KD.ZG' THEN Value END) AS Annual_Growth,
        MAX(CASE WHEN IndicatorCode = 'FP.CPI.TOTL.ZG' THEN Value END) AS Inflation,
        MAX(CASE WHEN IndicatorCode = 'SL.UEM.TOTL.ZS' THEN Value END) AS Unemployment,
        MAX(CASE WHEN IndicatorCode = 'PA.NUS.FCRF' THEN Value END) AS Exchange_Rates,
        MAX(CASE WHEN IndicatorCode = 'BN.CAB.XOKA.GD.ZS' THEN Value END) AS Current_Account_Balance,
        MAX(CASE WHEN IndicatorCode = 'BX.KLT.DINV.WD.GD.ZS' THEN Value END) AS FDI_Net_Inflows,
        MAX(CASE WHEN IndicatorCode = 'GC.DOD.TOTL.GD.ZS' THEN Value END) AS Central_Government_Debt,
        MAX(CASE WHEN IndicatorCode = 'NY.GDP.PCAP.PP.CD' THEN Value END) AS GDP_Per_Capita
    FROM v_EconomicSummary
    GROUP BY CountryName, Year
)
SELECT * FROM PivotData
WHERE Year = 2023
ORDER BY Annual_Growth DESC;

-- ==========================================================================
-- 2. SINGLE COUNTRY HISTORICAL ANALYSIS
-- Goal: Analyze all 8 indicators for a specific country over time.
-- Note: Replace 'Turkiye' with any country to view its economic history.
-- ==========================================================================
SELECT 
    CountryName,
    Year,
    MAX(CASE WHEN IndicatorCode = 'NY.GDP.MKTP.KD.ZG' THEN Value END) AS [GDP Growth %],
    MAX(CASE WHEN IndicatorCode = 'FP.CPI.TOTL.ZG' THEN Value END) AS [Inflation %],
    MAX(CASE WHEN IndicatorCode = 'SL.UEM.TOTL.ZS' THEN Value END) AS [Unemployment %],
    MAX(CASE WHEN IndicatorCode = 'PA.NUS.FCRF' THEN Value END) AS [Exchange Rate (USD)],
    MAX(CASE WHEN IndicatorCode = 'BN.CAB.XOKA.GD.ZS' THEN Value END) AS [Current Account % of GDP],
    MAX(CASE WHEN IndicatorCode = 'BX.KLT.DINV.WD.GD.ZS' THEN Value END) AS [FDI Net Inflows %],
    MAX(CASE WHEN IndicatorCode = 'GC.DOD.TOTL.GD.ZS' THEN Value END) AS [Govt Debt % of GDP],
    MAX(CASE WHEN IndicatorCode = 'NY.GDP.PCAP.PP.CD' THEN Value END) AS [GDP Per Capita (PPP)]
FROM v_EconomicSummary
WHERE CountryName = 'Turkiye' -- You can specify any country here
GROUP BY CountryName, Year
ORDER BY Year DESC;

-- ==========================================================================
-- 3. ENHANCED INFLATION VOLATILITY & TREND ANALYSIS
-- Goal: Detect price instability by comparing annual values to moving averages.
-- Methodology: Uses Window Functions to calculate Trend (3Y) and Volatility Gap.
-- ==========================================================================
SELECT 
    CountryName,
    Year,
    Value AS Annual_Inflation,
    -- Calculates the 3-Year rolling average to identify the underlying trend
    AVG(Value) OVER (PARTITION BY CountryName ORDER BY Year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS Trend_3Y,
    -- Volatility Calculation: Measuring the deviation between current value and trend
    ABS(Value - AVG(Value) OVER (PARTITION BY CountryName ORDER BY Year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS Volatility_Gap
FROM v_EconomicSummary
WHERE IndicatorCode = 'FP.CPI.TOTL.ZG'
ORDER BY CountryName, Year ASC;

-- ==========================================================================
-- 4. LAGGED ECONOMIC CORRELATION (Growth vs. Future Inflation)
-- Goal: Analyze if high growth in the previous year leads to inflation today.
-- Use Case: Testing the "Overheating Economy" theory using time-lagged data.
-- ==========================================================================
WITH YearlyData AS (
    SELECT 
        CountryName, Year,
        MAX(CASE WHEN IndicatorCode = 'NY.GDP.MKTP.KD.ZG' THEN Value END) AS Growth,
        MAX(CASE WHEN IndicatorCode = 'FP.CPI.TOTL.ZG' THEN Value END) AS Inflation
    FROM v_EconomicSummary
    GROUP BY CountryName, Year
)
SELECT 
    CountryName,
    Year,
    Growth AS Current_Year_Growth,
    -- Retrieves the growth rate from the previous year using LAG function
    LAG(Growth) OVER (PARTITION BY CountryName ORDER BY Year) AS Previous_Year_Growth,
    Inflation AS Current_Year_Inflation
FROM YearlyData
WHERE Growth IS NOT NULL AND Inflation IS NOT NULL;

-- ==========================================================================
-- 5. ECONOMIC STABILITY INDEX (2024 Analysis)
-- Formula: (Growth * 2) - (Inflation * 0.5) - (Unemployment * 0.3)
-- Goal: Identify the most resilient economies based on custom weighting.
-- ==========================================================================
WITH CountryStats AS (
    SELECT 
        CountryName,
        Year,
        MAX(CASE WHEN IndicatorCode = 'NY.GDP.MKTP.KD.ZG' THEN Value END) AS Growth,
        MAX(CASE WHEN IndicatorCode = 'FP.CPI.TOTL.ZG' THEN Value END) AS Inflation,
        MAX(CASE WHEN IndicatorCode = 'SL.UEM.TOTL.ZS' THEN Value END) AS Unemployment
    FROM v_EconomicSummary
    GROUP BY CountryName, Year
)
SELECT 
    CountryName, Year, Growth, Inflation, Unemployment,
    ROUND((Growth * 2) - (Inflation * 0.5) - (Unemployment * 0.3), 2) AS Stability_Score
FROM CountryStats
WHERE Year = 2024 
  AND Growth IS NOT NULL 
  AND Inflation IS NOT NULL
ORDER BY Stability_Score DESC;

-- ==========================================================================
-- 6. CATEGORICAL INFLATION RISK ANALYSIS (2023)
-- Goal: Classify countries into risk groups based on inflation thresholds.
-- Categories: Price Stability, Moderate, High, and Hyperinflation Risk.
-- ==========================================================================
SELECT 
    CountryName,
    Year,
    Value AS Inflation_Rate,
    CASE 
        WHEN Value <= 2 THEN 'Price Stability (Target)'
        WHEN Value > 2 AND Value <= 10 THEN 'Moderate Inflation'
        WHEN Value > 10 AND Value <= 40 THEN 'High Inflation'
        WHEN Value > 40 THEN 'Hyperinflation Risk'
        ELSE 'No Data'
    END AS Inflation_Risk_Category
FROM v_EconomicSummary
WHERE IndicatorCode = 'FP.CPI.TOTL.ZG' -- Inflation Indicator
  AND Year = 2023
ORDER BY Value DESC;
