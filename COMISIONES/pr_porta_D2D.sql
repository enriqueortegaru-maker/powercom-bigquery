BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'PRTV';

SET canales_pr =  COALESCE(canales_pr, ['D2D','D2N','DEM']);

/*
CALL COMISIONES.pr_porta_D2D (202407,['D2D','D2N','DEM']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.porta_D2D` AS (

  WITH ventas AS (
      SELECT id_comisionista, COUNT(*) AS ventas
      from `mm-commissions-reporting.COMISIONES.transacciones`
      WHERE id_mes = id_mes_pr
            AND canal IN UNNEST  (canales_pr)
            AND estado IN ('calculado', 'validado')
            AND concepto IN ('A - Servicio Fijo','A - Servicio Movil Pospago')
            AND deactivation_date = '9999-12-31'
      GROUP BY 1
      )

SELECT TRANSACCIONES.* EXCEPT (commission_id, estado, concepto, facturador, comments, comision)
      ,prefijo ||'_' || mes_string || '_' || TRANSACCIONES.canal || '_' || ROW_NUMBER() OVER() AS commission_id 
      ,'calculado' AS estado
      ,'D - Acelerador Porta V' AS concepto
      ,'C_MANUAL' AS facturador
      ,CAST(NULL AS STRING) AS comments
      ,CASE
      WHEN VENTAS.ventas BETWEEN 1 AND 24 THEN 5
      WHEN VENTAS.ventas BETWEEN 25 AND 50 THEN 10
      WHEN VENTAS.ventas BETWEEN 51 AND 80 THEN 15
      WHEN VENTAS.ventas BETWEEN 81 AND 120 THEN 20
      WHEN VENTAS.ventas >= 121 THEN 25
      END AS comision

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.activaciones` ACTIV
 ON TRANSACCIONES.service_id = ACTIV.service_id AND ACTIV.id_mes = id_mes_pr

LEFT JOIN ventas VENTAS
         ON TRANSACCIONES.id_comisionista = VENTAS.id_comisionista


WHERE TRANSACCIONES.canal IN UNNEST (canales_pr)
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago','A - Servicio Fijo')
      AND ACTIV.portability_operator_donor IN ('Vodafone España S.A.U-C','VODAFONE ENABLER / LOWI / VIVAZZI')
      AND TRANSACCIONES.deactivation_date = '9999-12-31'
      AND TRANSACCIONES.id_mes = id_mes_pr


)
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('PRTV', id_mes_pr, canales_pr, 'TEMP.porta_D2D' , 'ACTUALIZAR');

END