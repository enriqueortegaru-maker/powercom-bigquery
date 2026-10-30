BEGIN

-- CALL `mm-commissions-reporting.COMISIONES.pr_dealers_ALTERNOS_CM_MB`()

CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.DEALERS_ALTERNOS_CM_MB` AS

SELECT 
  id_comisionista,
  'B2B - Marblanca' AS agrupacion_canal,
  cif,
  a.razon_social
FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA` b ON a.cif = b.documento
WHERE b.documento IS NOT NULL
GROUP BY ALL

UNION ALL

SELECT 
  id_comisionista,
  'B2B - Cablemovil' AS agrupacion_canal,
  cif,
  a.razon_social
FROM `mm-commissions-reporting.GS.ALT_ALTERNOS_CM_MB` a
LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` b ON a.cif = b.documento
WHERE b.documento IS NOT NULL
GROUP BY ALL
;
END