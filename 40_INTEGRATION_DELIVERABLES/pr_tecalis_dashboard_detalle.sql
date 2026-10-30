BEGIN

-- CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_tecalis_dashboard_detalle`(202609);

-- VALIDAR QUE EXISTEN DATOS
ASSERT EXISTS (
  SELECT 1
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE id_mes = id_mes_pr
  AND canal IN ('ALTN','ALTNC','ALTNH')
)
AS 'No existen transacciones para el mes indicado';

/*
-- VALIDAR MAPPINGS
ASSERT NOT EXISTS (

  SELECT DISTINCT t.concepto

  FROM `mm-commissions-reporting.COMISIONES.transacciones` t

  LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS_PLANTILLA_TECALIS` c
    ON t.concepto = c.concepto

  WHERE t.id_mes = id_mes_pr
    AND t.cif = 'B75728329'
    AND t.canal IN ('ALTN','ALTNH','ALTNC')
    AND c.concepto IS NULL

)
AS 'Existen conceptos sin mapping en CONCEPTOS_PLANTILLA_TECALIS';

*/

DELETE
FROM `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_detalle`
WHERE id_mes = id_mes_pr;


-- CREATE OR REPLACE TABLE `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_detalle` AS (
INSERT INTO `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_detalle` (
WITH BASE AS (
        SELECT

            TRANSACCIONES.id_mes,
            CASE WHEN CONCEPTOS.AP IS TRUE THEN 'AP' ELSE MARCA END AS AGRUPACION,
            TRANSACCIONES.marca,

            CONCEPTO_PLANTILLA AS concepto,

            CASE WHEN TRANSACCIONES.commission_id LIKE  'OSPCARNE%' THEN TRANSACCIONES.seller ELSE TRANSACCIONES.id_comisionista END AS ID_PDV,
            TRANSACCIONES.nombre_comercio AS NOMBRE_PDV,

            CASE
                WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes%' THEN NULL
                WHEN TRANSACCIONES.concepto LIKE '%Extracomision Volumen Movil%' THEN NULL
                WHEN TRANSACCIONES.service_type LIKE '%INTERNET%'
                     AND TRANSACCIONES.marca = 'PEPEPHONE'
                     THEN TRANSACCIONES.service_id
                WHEN TRANSACCIONES.concepto like '%Cartera%' AND TRANSACCIONES.marca IN ('JAZZTEL','ORANGE','SIMYO') THEN NULL
                ELSE TRANSACCIONES.phone_nm
            END AS phone_nm,


            CASE
                WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes%' THEN NULL
                WHEN TRANSACCIONES.concepto LIKE '%Extracomision Volumen Movil%' THEN NULL
                WHEN TRANSACCIONES.concepto like '%Cartera%' AND TRANSACCIONES.marca IN ('JAZZTEL','ORANGE','SIMYO') THEN PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
                ELSE TRANSACCIONES.activation_date
            END AS FECHA_ACTIVACION,

            CASE
                WHEN CONCEPTOS.AP IS TRUE THEN TRANSACCIONES.concepto 
                WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes%' THEN 'Lote Mensual'
                WHEN TRANSACCIONES.concepto LIKE 'B -%' THEN TRANSACCIONES.concepto
                WHEN CONCEPTOS.CONCEPTO_PLANTILLA = 'RECARGA' THEN TRANSACCIONES.tariff_ds
                WHEN TRANSACCIONES.tariff_ds IS NULL THEN TRANSACCIONES.concepto
                WHEN TRANSACCIONES.service_type IN (
                    'RENUEVO',
                    'ENERGY',
                    'SECURITY',
                    'TV'
                ) THEN TRANSACCIONES.concepto
                WHEN TRANSACCIONES.concepto like '%Cartera%' AND TRANSACCIONES.marca IN ('JAZZTEL','ORANGE','SIMYO') THEN 'CARTERA NMR'
                WHEN CONCEPTOS.CONCEPTO_PLANTILLA = 'CARTERA' THEN TRANSACCIONES.concepto
                WHEN TRANSACCIONES.concepto LIKE '%Dispositivo Financiado' THEN TRANSACCIONES.CONCEPTO
                ELSE COALESCE(TRANSACCIONES.tariff_ds, TRANSACCIONES.concepto)
            END AS NOMBRE_TARIFA,

            SUM(TRANSACCIONES.comision) AS COMISION,

            CASE
                WHEN TRANSACCIONES.concepto LIKE '%Rappel Lotes%' THEN NULL
                WHEN TRANSACCIONES.concepto LIKE '%Extracomision Volumen Movil%' THEN NULL
                WHEN TRANSACCIONES.concepto like '%Cartera%' AND TRANSACCIONES.marca IN ('JAZZTEL','ORANGE','SIMYO') THEN NULL
                ELSE TRANSACCIONES.service_id
            END AS SUSCRIPTION_ID,
            CASE WHEN CONCEPTOS.CONCEPTO_PLANTILLA = 'RECARGA' and TRANSACCIONES.concepto LIKE '%Primera%' THEN ROUND((COMISION *2) ,2)
                 WHEN CONCEPTOS.CONCEPTO_PLANTILLA = 'RECARGA' and TRANSACCIONES.concepto LIKE '%Sucesiva%' THEN ROUND((COMISION/20 * 100),2)
                 ELSE NULL END AS IMPORTE_RECARGA,
            CAST (NULL AS STRING) AS POR_COMISION,
            CASE
                WHEN UPPER(TRANSACCIONES.concepto) LIKE '%RENUE%' THEN 'Renove'
                WHEN TRANSACCIONES.service_type = 'ENERGY' THEN 'Energía'
                WHEN TRANSACCIONES.service_type = 'INTERNET' THEN 'Fijo'
                WHEN TRANSACCIONES.service_type = 'MOBILE' THEN 'Pospago'
                WHEN TRANSACCIONES.service_type = 'SECURITY' THEN 'Alarma'
                WHEN TRANSACCIONES.service_type = 'TV' THEN 'TV'
                ELSE 'Pospago'
            END AS modalidad,
            CASE
                WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) = 'Z' THEN 'X' ELSE ''
            END AS regularizacion,
            TRANSACCIONES.invoice_id,
            TRANSACCIONES.commission_id,
            TRANSACCIONES.CONCEPTO AS TR_CONCEPTO

        FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

        LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS_PLANTILLA_TECALIS` CONCEPTOS
        ON TRANSACCIONES.CONCEPTO = CONCEPTOS.CONCEPTO

        WHERE TRANSACCIONES.id_mes = id_mes_pr
        --   AND TRANSACCIONES.estado IN ('facturado','publicado','validado')
          AND TRANSACCIONES.cif = 'B75728329'
          AND CANAL IN ('ALTN','ALTNH','ALTNC')
        --   AND TRANSACCIONES.CONCEPTO != 'D - Incentivo Tactico'
        AND TRANSACCIONES.concepto NOT IN (

'D - Incentivo Tactico',
'Y - Clawback Servicio Movil Pospago',
'F - Renuevo'
)
          
        GROUP BY ALL

    )

    SELECT

    ID_MES,
    -- AGRUPACION,
     CASE 
        WHEN AGRUPACION = 'AP' THEN 'AP (D)'
        WHEN AGRUPACION = 'ORANGE' THEN 'Orange (D)'
        WHEN AGRUPACION = 'JAZZTEL' THEN 'Jazztel (D)'
        WHEN AGRUPACION = 'SIMYO' THEN 'Simyo (D)'
        WHEN AGRUPACION = 'YOIGO' THEN 'Yoigo (D)'
        WHEN AGRUPACION = 'MASMOVIL' THEN 'MásM (D)'
        WHEN AGRUPACION = 'PEPEPHONE' THEN 'Pepe (D)'
        WHEN AGRUPACION = 'GUUK' THEN 'Guuk (D)'
        WHEN AGRUPACION = 'LLAMAYA' THEN 'Llamaya (D)'
        WHEN AGRUPACION = 'PEPEENERGY' THEN 'PepeEnergy (D)'
                
    END AS AGRUPACION,
    CONCEPTO,
    ID_PDV,
    NOMBRE_PDV,
    PHONE_NM,
    FECHA_ACTIVACION,
    COALESCE(NOMBRE_TARIFA,TR_CONCEPTO) AS NOMBRE_TARIFA,
    COMISION,
    SUSCRIPTION_ID,
    REPLACE(CAST(IMPORTE_RECARGA AS STRING),'.',',') AS IMPORTE_RECARGA,
    POR_COMISION,
    MODALIDAD,
    REGULARIZACION,
    INVOICE_ID,
    commission_id,
    TR_CONCEPTO,


    FROM BASE

    WHERE comision <> 0 
    
    )
;


---- TABLA DE SUMA
DELETE
FROM `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_suma`
WHERE id_mes = id_mes_pr
;

INSERT INTO  `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_suma` (
SELECT 
 ID_MES,
 REPLACE(AGRUPACION,'(D)','(S)') AS AGRUPACION, 
 CONCEPTO, 
 ID_PDV, 
 NOMBRE_PDV, 
 SUM(COMISION) AS IMPORTE
FROM `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_detalle`
WHERE ID_MES = id_mes_pr
GROUP BY ALL
)
;

END