BEGIN

-- CALL `mm-commissions-reporting.COMISIONES.pr_dealers_AVATEL_CM_MB`()

CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.DEALERS_AVATEL_CM_MB` AS


SELECT id_comisionista, 'B2B - Cablemovil' AS agrupacion_canal
FROM `mm-commissions-reporting.GS.AVATEL_CABLEMOVIL`  
GROUP BY ALL

UNION ALL 

SELECT b.id_comisionista, 'B2B - Marblanca' AS agrupacion_canal
FROM `mm-commissions-reporting.GS.AVATEL_CABLEMOVIL` a
LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA` b ON a.cif = b.documento
WHERE b.id_comisionista IS NOT NULL
GROUP BY ALL
;
END