BEGIN

SET canales_pr = ['ENK','EML','EYG'];

/*
call  COMISIONES.pr_retramitadas_exclusivo (202512, ['ENK','EML','EYG']);
*/

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.retramitadas_exclusivo` AS

INSERT INTO `mm-commissions-reporting.TEMP.retramitadas_exclusivo`

SELECT * EXCEPT(proceso_sap,id_registro,sociedad,bp, cuenta_contable, centro_coste, documento_sap, documento_sap_posicion, fecha_contabilizacion, creado, modificado,id_factura_drive, emails_acceso_trazabilidad, process_code)
FROM `mm-commissions-reporting.COMISIONES.transacciones`
WHERE agrupacion_canal = 'Exclusivo'
AND id_mes = id_mes_pr
AND comments LIKE 'Retramit%'
AND concepto IN ('A - Servicio Fijo','A - Servicio Movil Pospago')
GROUP BY ALL
;

END