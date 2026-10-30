BEGIN

DECLARE concepto_antiguo, concepto_nuevo, mes_string, prefijo STRING;

SET prefijo = 'INNX';

SET mes_string = CAST(mes_int AS STRING);


/*
CALL `mm-commissions-reporting.COMISIONES.pr_innx`(202411);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.innx`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER() OVER() AS commission_id
     ,'calculado' AS estado
     ,* EXCEPT(commission_id, estado)
     
FROM (
     SELECT
           TRANSACCIONES.* EXCEPT(concepto, comision)
          ,INCENTIVOS.concepto
          ,INCENTIVOS.comision
           
     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
     INNER JOIN (
                SELECT mes, phone_nm, service_id, marca, concepto, SUM(comision) comision
                FROM `mm-commissions-reporting.GS.no_exclusivo_incentivos`
                GROUP BY 1,2,3,4,5
                ) INCENTIVOS
               ON CASE WHEN TRANSACCIONES.marca = 'PEPEPHONE' THEN TRANSACCIONES.service_id ELSE TRANSACCIONES.phone_nm END
                  =
                  CASE WHEN INCENTIVOS.marca = 'PEPEPHONE' THEN INCENTIVOS.service_id ELSE INCENTIVOS.phone_nm END
     
                  AND TRANSACCIONES.marca = INCENTIVOS.marca
                  AND INCENTIVOS.mes
                        BETWEEN
                          CAST(SUBSTR(REPLACE(CAST(DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH) AS STRING), '-', ''), 1, 6) AS INT64)
                          AND
                          mes_int
         
     WHERE TRANSACCIONES.id_mes = mes_int
           AND TRANSACCIONES.agrupacion_canal = 'No Exclusivo'
           AND TRANSACCIONES.concepto LIKE 'A%'
     
     QUALIFY ROW_NUMBER() OVER (
                               PARTITION BY TRANSACCIONES.phone_nm, TRANSACCIONES.service_id, TRANSACCIONES.marca
                               ORDER BY concepto ASC
                               ) = 1
     )
)
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('INNX_', mes_int, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.innx), 'TEMP.innx', 'ACTUALIZAR');

END