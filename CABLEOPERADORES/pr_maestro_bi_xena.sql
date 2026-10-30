BEGIN

CREATE OR REPLACE TABLE `mm-commissions-reporting.CABLEOPERADORES.Maestro_BI_XENA` AS
SELECT 
  *
FROM `mm-b2b-reporting.MAESTROS.Maestro_BI_XENA` WHERE pvp_sin_iva IS NOT NULL;

END