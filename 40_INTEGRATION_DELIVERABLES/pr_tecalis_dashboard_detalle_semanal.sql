BEGIN

-- CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_tecalis_dashboard_detalle_semanal`(NULL,NULL);
-- CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_tecalis_dashboard_detalle_semanal`('2026-06-08','2026-06-14');


-- Si no se informan fechas, coger la última semana completa
IF fecha_inicio IS NULL OR fecha_fin IS NULL THEN

-- Domingo de la semana anterior
SET fecha_fin = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY);

-- Lunes de esa misma semana
SET fecha_inicio = DATE_SUB(fecha_fin, INTERVAL 6 DAY);

END IF;

/*
-- VALIDAR QUE EXISTEN DATOS
ASSERT EXISTS (
  SELECT 1
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE id_mes = id_mes_pr
  AND canal IN ('ALTN','ALTNC','ALTNH')
)
AS 'No existen transacciones para el mes indicado';


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
AS 'Existen conceptos sin mapping en CONCEPTOS_PLANTILLA_TECALIS';*/

/*BORRAMOS REGISTROS SI SON LA MISMA SEMANA*/
DELETE
FROM `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_detalle_semanal`
WHERE SEMANA = EXTRACT(ISOWEEK FROM fecha_fin);


INSERT INTO `mm-commissions-reporting.60_EDW_DELIVERABLES.tecalis_dashboard_detalle_semanal` (
WITH BASE AS (
        SELECT

            TRANSACCIONES.id_mes,
            CASE WHEN CONCEPTOS.AP IS TRUE THEN 'AP' ELSE MARCA END AS AGRUPACION,
            TRANSACCIONES.marca,

            CONCEPTO_PLANTILLA AS concepto,

            TRANSACCIONES.id_comisionista AS ID_PDV,
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
                WHEN TRANSACCIONES.concepto like '%Cartera%' AND TRANSACCIONES.marca IN ('JAZZTEL','ORANGE','SIMYO') THEN PARSE_DATE('%Y%m', CAST(TRANSACCIONES.id_mes AS STRING))
                ELSE TRANSACCIONES.activation_date
            END AS FECHA_ACTIVACION,

            CASE
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
                WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) = 'Z' THEN 'X'
            END AS regularizacion,
            TRANSACCIONES.invoice_id,
            TRANSACCIONES.commission_id,
            TRANSACCIONES.CONCEPTO AS TR_CONCEPTO

        FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

        LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS_PLANTILLA_TECALIS` CONCEPTOS
        ON TRANSACCIONES.CONCEPTO = CONCEPTOS.CONCEPTO

      WHERE DATE(TRANSACCIONES.activation_date) BETWEEN fecha_inicio AND fecha_fin
        --   AND TRANSACCIONES.estado IN ('facturado','publicado')
          AND TRANSACCIONES.cif = 'B75728329'
          AND CANAL IN ('ALTN','ALTNH','ALTNC')
          AND CONCEPTOS.PAGO = 'SEMANAL'
          -- AND id_comisionista IN (
          --   '33001',
          --   '4210',
          --   '50443',
          --   '52780',
          --   '53089',
          --   '56281',
          --   '58575',
          --   '60966'

          -- )
        AND id_comisionista IN (
        SELECT DISTINCT ID_PdV AS id_comisionista
        FROM `mm-sales-reporting.optico.optico_noexclusivo_26N`
        WHERE  PANZER =  'SUPREME'
        AND fecha_optico = fecha_fin
        AND ESTADO = 'ACTIVO'
        )
        
        GROUP BY ALL

    )

    SELECT

    ID_MES,
    fecha_inicio AS FECHA_INICIO_PERIODO,
    fecha_fin AS FECHA_FIN_PERIODO,
    EXTRACT(ISOWEEK FROM fecha_fin) AS SEMANA,
    AGRUPACION,
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
    '' AS D1,
    '' AS D2

    FROM BASE

    WHERE comision <> 0 
    )
;

END