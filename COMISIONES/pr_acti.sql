BEGIN

declare sql, prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'ACTI_';
 
SET canales_pr = COALESCE (canales_pr, 
(SELECT ARRAY_AGG (canal) FROM `mm-commissions-reporting.GS.CANALES` WHERE plantilla_activaciones IN  ('Sin tramos', 'Con tramos'))
);

/*
CALL  COMISIONES.pr_acti (202609, ['MKT_NR']);
*/


/* Generates KPIs to facilitate commission calculations */
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.activationes_kpi` AS
(
SELECT
      * EXCEPT(kpi_d2d_pack_mobile_additional)

     ,CASE
          WHEN kpi_d2d_pack_mobile_additional IS NOT NULL
               AND SUM(COALESCE(kpi_d2d_pack_mobile_additional, 0)) OVER (PARTITION BY id_mes, id_comisionista, customer_id) >= 5
          THEN SUM(COALESCE(kpi_d2d_pack_mobile_additional, 0)) OVER (PARTITION BY id_mes, id_comisionista, customer_id)
      END AS kpi_d2d_pack_mobile_additional

FROM (
     SELECT
           *
     
          ,CASE
               WHEN comisionamiento = 'Comisiona'
                    AND (
                         (
                         canal IN ('D2D','D2N')
                         AND marca IN ('MASMOVIL')
                         AND (
                             tariff_ds LIKE '%60%'
                             OR tariff_ds LIKE '%35%'
                             OR tariff_ds LIKE '%20%'
                             )
                         )
                        OR
                         (
                         canal IN ('D2D','D2N')
                         AND marca IN ('YOIGO')
                         AND (
                             UPPER(tariff_ds) LIKE '%INFINITA%'
                             OR tariff_ds LIKE '%60%'
                             OR tariff_ds LIKE '%30%'
                             )
                         )
                        OR
                         (
                         canal IN ('DEM')
                         AND marca IN ('YOIGO')
                         AND (
                             UPPER(tariff_ds) LIKE '%INFINITA%'
                             OR tariff_ds LIKE '%60%'
                             OR tariff_ds LIKE '%30%'
                             )
                         )
                        )
                    AND bundle_type = 'FMC'
                    AND line_type_ds = 'ADDITIONAL'
                    AND cod_segmento = '12'
               THEN 1
           END AS kpi_d2d_pack_mobile_additional

     FROM `mm-commissions-reporting.COMISIONES.activaciones`

     WHERE (campaign_code IS NULL
            OR
            campaign_code NOT IN /*EXCLUIMOS CAMPAÑAS DE PONDERACION DE OUTBOUND */
                            (--- MR POSPAGO FIJO Y MOVIL RES Y EMPRESA --- 
                            'COLD CALLING CAPTA SOHO',
                            'COLD CALLING CARTERA SOHO',
                            'COLD CALLING CAPTA RES',
                            'COLD CALLING CAPTA RES T EXTERNOS',
                            'COLD CALLING CAPTA RES NEW',
                            'COLD CALLING CAPTACION IA',


                            --- MR COLD CALLING CONTROLADO SOLO MARCA JAZZTEL ---

                            'COLD CALLING CONTROLADO CRECIMIENTOS OFFSHORE',
                            'COLD CALLING CONTROLADO OFFSHORE',
                            'COLD CALLING CONTROLADO',
                            'COLD CALLING CONTROLADO TEMPL',
                            'COLD CALLING CONTROLADO CRECIMIENTOS',
                            'COLD CALLING CONTROLADO JE ',
                            'COLD CALLING CONTROLADO PL_EX',

                            --- MR LINEAS ADICIONALES SOLO MARCA JAZZTEL ---
                            'LINEAS ADICIONALES',


                            --- MR XSELLING SOLO MARCA JAZZTEL ---

                            'CROSS SELLING_MV',
                            'CROSS SELLING',
                            'CROSELLING_SEGUNDA RESIDENCIA'
                            )
            )

     
)
)
;


-- Actualizar tarifas en el maestro --

INSERT INTO COMISIONES.tarifas
SELECT DISTINCT
    a.canal,
    a.id_mes,
    a.marca,
    a.service_type,
    a.tariff_id,
    a.tariff_ds,
    CASE
        WHEN a.service_type = 'MOBILE' THEN a.line_type_ds
    END AS line_type_ds,
    b.pvp,
    b.tramo_1,
    b.tramo_2,
    b.tramo_3,
    b.tramo_4,
    b.tramo_5,
    b.migraciones,
    b.traslados,
    b.gestion_canal,
    b.cuota,
    b.consumo,
    CASE
        WHEN a.canal IN ('XS','XSO','OSPNIN','OSPNXSN','OUO','OSPNOUN') THEN a.campaign_code
        ELSE CAST(NULL AS STRING)
    END AS campaign_code,
    'ACTI',
    CURRENT_TIMESTAMP(),
    CASE WHEN a.CANAL = 'MKT_NR' AND a.SERVICE_TYPE = 'INTERNET' THEN a.bundle_type ELSE NULL END AS bundle_type
-- FROM `mm-commissions-reporting.COMISIONES.activaciones` a
FROM `mm-commissions-reporting.TEMP.activationes_kpi` a
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_tarifas` b
    ON  a.marca = b.marca
    AND a.service_type = b.service_type
    AND a.tariff_id = b.tariff_id
    AND a.id_mes = b.id_mes
    AND a.canal = b.canal
    AND CASE
            WHEN a.service_type = 'MOBILE' THEN a.line_type_ds
            ELSE 'NA'
        END = COALESCE(b.line_type_ds, 'NA')
    AND (a.canal != 'MKT_NR' OR a.service_type = 'MOBILE' OR  (a.service_type = 'INTERNET'AND a.bundle_type = b.bundle_type))
    AND a.tariff_ds = b.tariff_ds
    AND (
            (a.canal IN ('XS','XSO','OSPNIN','OSPNXSN','OUO','OSPNOUN') AND a.campaign_code = b.campaign_code)
         OR (a.canal NOT IN ('XS','XSO','OSPNIN','OSPNXSN','OUO','OSPNOUN'))
        )
CROSS JOIN UNNEST(canales_pr) AS canal_pr
WHERE a.canal = canal_pr
  AND b.canal IS NULL
  AND a.service_type IN ('MOBILE', 'INTERNET')
  AND a.id_mes = id_mes_pr

;

-- TABLA CONCEPTOS -- 

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_conceptos` AS
WITH tarifas_tramos AS (
    SELECT
        canal,
        marca,
        service_type,
        tariff_id,
        tariff_ds,
        line_type_ds,
        bundle_type,
        tramo,
        comision,
        traslados,
        migraciones,
        gestion_canal,
        campaign_code
    FROM `mm-commissions-reporting.COMISIONES.v_tarifas`
    UNPIVOT (
        comision FOR tramo IN (
            tramo_1,
            tramo_2,
            tramo_3,
            tramo_4,
            tramo_5
        )
    )
    WHERE id_mes = id_mes_pr
),

marco AS (

    -- =====================================================
    -- Servicio fijo y móvil
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        CASE
            WHEN service_type = 'MOBILE' THEN 'A - Servicio Movil Pospago'
            ELSE 'A - Servicio Fijo'
        END AS concepto,
        'UPFR' AS tipo_concepto,
        comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.service_type IN ('MOBILE', 'INTERNET')
      AND COALESCE(a.line_type_ds, 'a') <> 'MULTISIM'

    UNION ALL

    -- =====================================================
    -- Servicio Multisim
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        'B - Multisim' AS concepto,
        'UPFR' AS tipo_concepto,
        comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.line_type_ds = 'MULTISIM'

    UNION ALL

    -- =====================================================
    -- Portabilidad
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        CASE
            WHEN service_type = 'MOBILE'
                THEN 'A - Portabilidad Movil Pospago'
            ELSE 'A - Portabilidad Fijo'
        END AS concepto,
        'UPFR' AS tipo_concepto,
        `mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(
            a.marca,
            a.service_type,
            a.tariff_id,
            a.tariff_ds,
            a.line_type_ds,
            a.canal,
            FALSE,
            a.campaign_code
        ) AS comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.canal NOT IN ('ENK')

    UNION ALL

    -- =====================================================
    -- Portabilidad gestión canal
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        CASE
            WHEN service_type = 'MOBILE'
                THEN 'F - Portabilidad Movil Pospago'
            ELSE 'F - Portabilidad Fijo'
        END AS concepto,
        'UPFR' AS tipo_concepto,
        `mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(
            a.marca,
            a.service_type,
            a.tariff_id,
            a.tariff_ds,
            a.line_type_ds,
            a.canal,
            TRUE,
            a.campaign_code
        ) AS comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.canal NOT IN ('AVO','ECI', 'EDB', 'EML', 'EYG', 'ENX', 'ENK')

    UNION ALL

    -- =====================================================
    -- Traslados
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        'A - Servicio Fijo Cambio de Domicilio' AS concepto,
        'UPFR' AS tipo_concepto,
        CASE
            WHEN traslados > 1 THEN traslados
            ELSE comision * traslados
        END AS comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.service_type = 'INTERNET'
      AND a.canal NOT IN ('XI', 'XO', 'XOF')

    UNION ALL

    -- =====================================================
    -- Migraciones
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        'A - Servicio Fijo Cambio de Tecnologia' AS concepto,
        'UPFR' AS tipo_concepto,
        CASE
            WHEN migraciones > 1 THEN migraciones
            ELSE comision * migraciones
        END AS comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.service_type = 'INTERNET'
      AND a.canal NOT IN ('XI', 'XO', 'XOF')

    UNION ALL

    -- =====================================================
    -- Gestión de canal
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        CASE
            WHEN service_type = 'MOBILE'
                 AND a.line_type_ds = 'MULTISIM'
                 AND a.canal IN ('ECI', 'EDB', 'EYG', 'EML', 'ENX')
                THEN 'F - Multisim'
            WHEN service_type = 'MOBILE'
                 AND a.line_type_ds <> 'MULTISIM'
                THEN 'F - Servicio Movil Pospago'
            WHEN service_type <> 'MOBILE'
                THEN 'F - Servicio Fijo'
        END AS concepto,
        'UPFR' AS tipo_concepto,
        gestion_canal AS comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.canal IN ('AVO','MI', 'CA', 'EML', 'GUUK', 'EYG', 'EDB', 'ECI', 'PH', 'ENX', 'ENK')

    UNION ALL

    -- =====================================================
    -- Gestión de canal GPV
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        CASE
            WHEN service_type = 'MOBILE'
                THEN 'G - Servicio Movil Pospago'
            ELSE 'G - Servicio Fijo'
        END AS concepto,
        'UPFR' AS tipo_concepto,
        gestion_canal AS comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.canal IN ('MI', 'CA')

    UNION ALL

    -- =====================================================
    -- Portabilidad gestión canal GPV
    -- =====================================================
    SELECT
        a.canal,
        a.marca,
        a.service_type,
        a.campaign_code,
        tariff_id,
        tariff_ds,
        a.line_type_ds,
        bundle_type,
        id_comisionista,
        CASE
            WHEN service_type = 'MOBILE'
                THEN 'G - Portabilidad Movil Pospago'
            ELSE 'G - Portabilidad Fijo'
        END AS concepto,
        'UPFR' AS tipo_concepto,
        `mm-commissions-reporting.COMISIONES.f_comision_portabilidad`(
            a.marca,
            a.service_type,
            a.tariff_id,
            a.tariff_ds,
            a.line_type_ds,
            a.canal,
            TRUE,
            a.campaign_code
        ) AS comision
    FROM tarifas_tramos a
    LEFT JOIN `mm-commissions-reporting.COMISIONES.v_actr_tramos` b
        ON a.marca = b.marca
       AND a.canal = b.canal
       AND b.mes = mes_string
    CROSS JOIN UNNEST(canales_pr) AS canal_pr
    WHERE a.canal = canal_pr
      AND a.tramo = COALESCE('tramo_' || CAST(b.tramo AS STRING), 'tramo_1')
      AND a.canal IN ('MI', 'CA')
)

SELECT *
FROM marco
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        canal,
        marca,
        service_type,
        tariff_id,
        tariff_ds,
        line_type_ds,
        bundle_type,
        concepto,
        id_comisionista,
        campaign_code
) = 1

;

--- Calcular tabla de comisiones ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones` AS
SELECT

    prefijo || '_' || mes_string || '_' || b.canal || '_' ||ROW_NUMBER() OVER () AS commission_id,
    'calculado' AS estado,
    id_mes_pr AS id_mes,
    b.agrupacion_canal,
    b.canal,
    CASE
        WHEN b.billing_type_ds = 'PREPAID'
            THEN REPLACE(concepto, 'Pospago', 'Prepago')
        ELSE concepto
    END AS concepto,
    tipo_concepto,
    1 AS unidades,

    ---- IMPORTE COMISION ---

        CASE
            -- =====================================================
            -- NATIONAL RETAIL FNAC_NR Y MKT_NR SIMYO MOVIL
            -- =====================================================
            WHEN b.agrupacion_canal = 'NATIONAL RETAIL'
                 AND b.canal = 'FNAC_NR'
                 AND concepto IN ('A - Servicio Movil Pospago','A - Servicio Movil Prepago')
                 AND order_type_agg = 'ALTA NUEVA'
                 AND b.marca = 'SIMYO'
                THEN 3.4 *  comision

            WHEN b.agrupacion_canal = 'NATIONAL RETAIL'
                 AND b.canal = 'FNAC_NR' 
                 AND concepto IN ('A - Servicio Movil Pospago','A - Servicio Movil Prepago')
                 AND order_type_agg = 'PORTABILIDAD'
                 AND b.marca = 'SIMYO'
                THEN 5.7 *  comision

            WHEN b.agrupacion_canal = 'NATIONAL RETAIL'
                 AND b.canal = 'MKT_NR'
                 AND concepto IN ('A - Servicio Movil Pospago')
                 AND order_type_agg = 'ALTA NUEVA'
                 AND b.marca = 'SIMYO'
                 AND b.billing_type_ds = 'POSTPAID'
                THEN 3.5 *  comision

            WHEN b.agrupacion_canal = 'NATIONAL RETAIL'
                 AND b.canal = 'MKT_NR'
                 AND concepto IN ('A - Servicio Movil Pospago')
                 AND order_type_agg = 'PORTABILIDAD'
                 AND b.marca = 'SIMYO'
                 AND b.billing_type_ds = 'POSTPAID'
                THEN 8 * comision

            WHEN b.agrupacion_canal = 'NATIONAL RETAIL'
                 AND b.canal = 'MKT_NR'
                 AND concepto IN ('A - Servicio Movil Prepago')
                 AND b.marca = 'SIMYO'
                 AND b.billing_type_ds = 'PREPAID'
                THEN 1 * comision


            WHEN b.agrupacion_canal = 'NATIONAL RETAIL'
                 AND b.canal = 'MKT_NR'
                 AND concepto IN ('A - Servicio Movil Pospago')
                 AND order_type_agg = 'PORTABILIDAD'
                 AND b.marca = 'JAZZTEL'
                THEN CASE WHEN COMISION = 6 THEN 20
                          WHEN COMISION = 10 THEN 35
                          WHEN COMISION = 15 THEN 50
                          WHEN COMISION = 21 THEN 70
                          WHEN COMISION = 26 THEN 85
                          WHEN COMISION = 30 THEN 100
                          WHEN COMISION = 33 THEN 70
                          WHEN COMISION = 50 THEN 100
                          WHEN COMISION = 52 THEN 105
                     END
            -- =============================
            -- D2D
            -- =============================
            WHEN b.agrupacion_canal = 'D2D'
                 AND b.tariff_id = 'CONT29'
                 AND cod_segmento = '12'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 30.00

            WHEN b.agrupacion_canal = 'D2D'
                 AND b.tariff_id = 'CONT29'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 25.00

            WHEN b.agrupacion_canal = 'D2D'
                 AND b.tariff_id = 'CONT28'
                 AND cod_segmento = '12'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 10.00

            WHEN b.agrupacion_canal = 'D2D'
                 AND b.tariff_id = 'CONT28'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 25.00

            -- =============================
            -- NO EXCLUSIVO
            -- =============================
            WHEN b.agrupacion_canal = 'No Exclusivo'
                 AND b.canal = 'MP'
                 AND b.portability_group_donor = 'GRUPO MASMOVIL'
                 AND concepto LIKE '%Portabilidad%'
                THEN 0.00

            WHEN b.agrupacion_canal = 'No Exclusivo'
                 AND b.canal IN ('MP','MI','MR','CA','PH')
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id IN (
                     'AJUSTNETFLIX','TNH23GBILAUX','TNH23GBILIMI','TNH25GBILIM1'
                 )
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'MAIN'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 25.00

            WHEN b.agrupacion_canal = 'No Exclusivo'
                 AND b.canal IN ('MP','MI','MR','CA','PH')
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id = 'INIMINETFLIX'
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'MAIN'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 30.00

            WHEN b.agrupacion_canal = 'No Exclusivo'
                 AND b.canal IN ('MP','MI','MR','CA','PH')
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id IN ('AJUSTNETFLIX','TNH23GBILIMI')
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'MAIN'
                 AND technology_ds = 'ADSL'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 15.00

            WHEN b.agrupacion_canal = 'No Exclusivo'
                 AND b.canal = 'NR'
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id IN (
                     'AJUSTNETFLIX','TNH23GBILAUX','TNH23GBILIMI','TNH25GBILIM1'
                 )
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'MAIN'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 31.00

            WHEN b.agrupacion_canal = 'No Exclusivo'
                 AND b.canal = 'NR'
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id = 'INIMINETFLIX'
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'MAIN'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 36.00

            WHEN b.agrupacion_canal = 'No Exclusivo'
                 AND b.canal = 'NR'
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id IN ('AJUSTNETFLIX','TNH23GBILIMI')
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'MAIN'
                 AND technology_ds = 'ADSL'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 21.00
                
            -- =============================
            -- TLV - Web
            -- =============================
            WHEN b.agrupacion_canal = 'TLV - Web'
                 AND b.canal = 'WA'
                 AND b.id_comisionista LIKE 'OSP%'
                 AND concepto = 'A - Servicio Fijo'
               THEN comision - 5

            -- =============================
            -- TLV - DO
            -- =============================
            WHEN b.agrupacion_canal = 'TLV - DO'
                 AND b.canal = 'DOT'
                 AND b.bundle_type = '2P'
                 AND concepto = 'A - Servicio Fijo'
               THEN comision - 45
            
            WHEN b.agrupacion_canal = 'TLV - DO'
                 AND b.canal = 'DOT'
                 AND concepto = 'A - Portabilidad Movil Prepago'
               THEN 0

            -- =============================
            -- TLV - Outbound
            -- =============================
            WHEN b.agrupacion_canal = 'TLV - Outbound'
                 AND b.canal = 'OUO'
                 AND concepto = 'A - Servicio Movil Pospago'
                 AND order_type_agg = 'PORTABILIDAD'
                 AND a.marca IN ('JAZZTEL','SIMYO')
                 AND a.campaign_code = 'COLD CALLING'
               THEN comision * 2

            -- =============================
            -- TLV - Negocios
            -- =============================
            WHEN b.agrupacion_canal = 'TLV - Negocios'
                 AND b.canal = 'OSPNIN'
                 AND concepto = 'A - Servicio Movil Pospago'
                 AND order_type_agg = 'PORTABILIDAD'
               THEN comision * 2


            -- =============================
            -- EXCLUSIVO
            -- =============================
            WHEN b.agrupacion_canal = 'Exclusivo'
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id = 'AJUSTNETFLIX'
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'ADDITIONAL'
                 AND concepto = 'A - Servicio Movil Pospago'
                THEN 25.00

            WHEN b.agrupacion_canal = 'Exclusivo'
                 AND b.marca = 'PEPEPHONE'
                 AND b.tariff_id = 'AJUSTNETFLIX'
                 AND b.bundle_type = 'FMC'
                 AND a.line_type_ds = 'ADDITIONAL'
                 AND concepto = 'F - Servicio Movil Pospago'
                THEN 3.75

            WHEN b.agrupacion_canal = 'Exclusivo'
                 AND b.billing_tier IN (
                     'DESCUENTO 100% DUO PRINCIPAL',
                     'DESCUENTO 100% INDEFINIDO DUO PRINCIPAL PRO'
                 )
                 AND concepto NOT LIKE '%Portabilidad%'
                THEN 0.00

            WHEN b.agrupacion_canal = 'Exclusivo'
                 AND b.tariff_ds = 'DUO PRINCIPAL'
                 AND order_type_agg = 'ALTA NUEVA'
                 AND concepto NOT LIKE '%Portabilidad%'
                THEN 0.00

            ELSE comision
        END
     AS comision,

    CASE
        WHEN SUBSTR(concepto, 1, 1) IN ('F','H')
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN m.id_comisionista
        WHEN SUBSTR(concepto, 1, 1) = 'G'
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN g.id_comisionista
        ELSE b.id_comisionista
    END AS id_comisionista,

    CASE
        WHEN SUBSTR(concepto, 1, 1) IN ('F','H')
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN m.id_comisionista
        WHEN SUBSTR(concepto, 1, 1) = 'G'
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN g.id_comisionista
        ELSE COALESCE(distribuidor, b.id_comisionista)
    END AS distribuidor,

    sfid_id,
    seller,

    CASE
        WHEN SUBSTR(concepto, 1, 1) IN ('F','H')
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN m.nombre_comercio
        WHEN SUBSTR(concepto, 1, 1) = 'G'
            THEN g.nombre_comercio
        ELSE b.nombre_comercio
    END AS nombre_comercio,

    CASE
        WHEN SUBSTR(concepto, 1, 1) IN ('F','H')
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN m.razon_social
        WHEN SUBSTR(concepto, 1, 1) = 'G'
            THEN g.razon_social
        ELSE b.razon_social
    END AS razon_social,

    CASE
        WHEN SUBSTR(concepto, 1, 1) IN ('F','H')
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN m.cif
        WHEN SUBSTR(concepto, 1, 1) = 'G'
            THEN g.cif
        ELSE b.cif
    END AS cif,

    CASE
        WHEN SUBSTR(concepto, 1, 1) IN ('F','H')
             AND b.agrupacion_canal = 'No Exclusivo'
            THEN m.zona_fiscal
        WHEN SUBSTR(concepto, 1, 1) = 'G'
            THEN g.zona_fiscal
        ELSE b.zona_fiscal
    END AS zona_fiscal,

    b.marca,
    b.service_type,
    phone_nm,
    b.tariff_id,
    b.tariff_ds,
    b.service_id,
    account_id,
    customer_id,
    a.line_type_ds,
    b.bundle_type,
    technology_ds,
    billing_type_ds,
    sale_date,
    activation_date,
    deactivation_date,
    COALESCE(b.sfid_digo, order_id) AS order_id,
    order_type_agg,
    cod_segmento,
    cod_marca,
    cod_tipo_contrato,
    cod_producto,
    COALESCE(d.cod_canal, b.cod_canal) AS cod_canal,
    b.campaign_code,
    CAST(NULL AS STRING) AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    comments,
    'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.acti_conceptos` a

INNER JOIN `mm-commissions-reporting.TEMP.activationes_kpi` b
         ON a.canal=b.canal 
         AND a.marca = b.marca 
         AND a.service_type = b.service_type 
         AND a.tariff_id = b.tariff_id
         AND a.TARIFF_DS = b.TARIFF_DS
         AND
            COALESCE(CASE WHEN a.canal IN ('ALTN', 'ALTNC','ALTNH', 'XI','XO','XOF', 'WA','CI') THEN a.id_comisionista END, b.bundle_type,'1')
            =
            COALESCE(CASE WHEN b.canal IN ('XI','XO','XOF',  'WA','CI') THEN b.id_comisionista END, b.bundle_type,'1')
      
            AND (
              (b.canal IN ('OSPNIN','XS','XSO','OSPNXSN','OUO','OSPNOUN') AND a.campaign_code = b.campaign_code)
              OR
              (b.canal NOT IN ('OSPNIN','XS','XSO','OSPNXSN','OUO','OSPNOUN') )  
            ) --- 202507: Añadimos cruce por campaign code
            
        AND (a.canal != 'MKT_NR' 
            OR a.service_type = 'MOBILE' 
            OR (a.service_type = 'INTERNET'AND a.bundle_type = b.bundle_type)) --- cruzamos por bundle_type en canales que lo requieran


INNER JOIN `mm-commissions-reporting.GS.CANALES` d
    ON a.canal = d.canal

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m
    ON b.distribuidor = m.id_comisionista

LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` g
    ON b.cif_gpv = g.cif

-- LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
--     ON b.id_comisionista = tlv_cross_sell.id_comisionista
--    AND b.canal = tlv_cross_sell.canal

-- LEFT JOIN `mm-commissions-reporting.GS.exclusivo_dealers` e
--     ON b.id_comisionista = e.id_comisionista -- JOHANNA 20250513
-- LEFT JOIN  `mm-datamart-kd.00_SANDBOX_DWH_SIMYO.v_mo_tariffs` TARIFF_SIMYO
-- ON TARIFF_SIMYO.ID_TARIFA = a.tariff_id

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE 1 = 1

-- AND NOT (
--     b.canal IN ('EML','EDB','PH','EYG')
--     AND id_mes_pr = 202303
--     AND b.marca = 'YOIGO'
-- )

AND b.canal = canal_pr
AND b.id_mes = id_mes_pr
AND b.comisionamiento = 'Comisiona'

AND CASE
        WHEN a.service_type = 'MOBILE'
            THEN a.line_type_ds
        ELSE 'FIX'
    END
    =
    CASE
        WHEN b.service_type = 'MOBILE'
            THEN b.line_type_ds
        ELSE 'FIX'
    END

-- AND COALESCE(a.id_comisionista, b.id_comisionista) = b.id_comisionista

AND CASE
        WHEN concepto IN (
            'F - Portabilidad Movil Pospago',
            'F - Portabilidad Fijo',
            'A - Portabilidad Movil Pospago',
            'A - Portabilidad Fijo',
            'G - Portabilidad Movil Pospago',
            'G - Portabilidad Fijo'
        )
            THEN 'PORTABILIDAD'

        WHEN concepto = 'A - Servicio Fijo Cambio de Domicilio'
            THEN 'CAMBIO DOMICILIO'

        WHEN concepto = 'A - Servicio Fijo Cambio de Tecnologia'
            THEN 'CAMBIO TECNOLOGIA'
        WHEN concepto IN (
            'A - Servicio Fijo',
            'A - Servicio Movil Pospago',
            'B - Multisim',
            'F - Servicio Fijo',
            'F - Servicio Movil Pospago',
            'F - Multisim',
            'G - Servicio Fijo',
            'G - Servicio Movil Pospago'
        )
        AND B.CANAL IN ('XO','DO','WA','XI')
        AND b.order_type_agg IN (
            'ALTA NUEVA',
            'PORTABILIDAD',
            'STC',
            'MULTISIM',
            'MIGRACION PREPAGO A POSTPAGO'
        )
            THEN b.order_type_agg

        WHEN concepto IN (
            'A - Servicio Fijo',
            'A - Servicio Movil Pospago',
            'B - Multisim',
            'F - Servicio Fijo',
            'F - Servicio Movil Pospago',
            'F - Multisim',
            'G - Servicio Fijo',
            'G - Servicio Movil Pospago'
        )
        AND b.order_type_agg IN (
            'ALTA NUEVA',
            'PORTABILIDAD',
            'STC',
            'MULTISIM'
        )
            THEN b.order_type_agg
    END = b.order_type_agg

AND (
        NOT (
            COALESCE(b.distribuidor, 'NA') NOT IN (
                SELECT id_comisionista
                FROM `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`
            )
            AND SUBSTR(a.concepto, 1, 1) = 'F'
        )
        OR b.distribuidor = 'BYMOVIL'
    )

AND NOT (
    b.cif_gpv IS NULL
    AND SUBSTR(a.concepto, 1, 1) = 'G'
)

AND (
        b.order_type_agg IN (
            'ALTA NUEVA',
            'PORTABILIDAD',
            'STC',
            'CAMBIO DOMICILIO',
            'CAMBIO TECNOLOGIA',
            'MULTISIM',
            'HLR'
        )
     OR (
            b.canal IN ('ENK','XI','XO','WA','DO','DOT')
        AND b.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO'
        )
    )

AND b.cif IS NOT NULL

-- AND NOT (
--     b.canal IN ('XI','XO')
--     AND b.bundle_type = 'FMC'
--     AND b.service_type = 'MOBILE'
--     AND b.marca = 'YOIGO'
--     AND b.tariff_ds LIKE '%CONV%'
-- )

AND NOT (
    b.canal = 'EDB'
    AND b.bundle_type = 'FMC'
    AND b.service_type = 'MOBILE'
    AND b.marca = 'YOIGO'
    AND b.line_type_ds = 'MAIN'
    AND b.order_type_agg = 'MYSIM'
)

AND NOT (
    b.canal = 'XS'
    AND b.marca = 'MASMOVIL'
    AND b.id_comisionista IN (
        'CAROUT006',
        'CAROUT013',
        'CAROUT020',
        'CAROUT021',
        'CAROUT022'
    )
    AND CASE
            WHEN b.activation_date < '2024-07-22'
                THEN COALESCE(
                    `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(
                        a.canal,
                        b.marca,
                        b.seller,
                        b.service_type
                    ),
                    -- tlv_cross_sell.campaign
                    b.campaign_code
                )
            ELSE COALESCE(
                -- tlv_cross_sell.campaign,
                b.campaign_code,
                `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(
                    a.canal,
                    b.marca,
                    b.seller,
                    b.service_type
                )
            )
        END = 'Lineas adicionales OUT'
    AND b.activation_date >= '2023-10-01'
)

AND NOT (
    b.canal = 'XS'
    AND b.marca = 'YOIGO'
    AND b.id_comisionista IN ('CAROUT007', 'KO')
    AND CASE
            WHEN b.activation_date < '2024-07-22'
                THEN COALESCE(
                    `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(
                        a.canal,
                        b.marca,
                        b.seller,
                        b.service_type
                    ),
                    b.campaign_code
                )
            ELSE COALESCE(
                b.campaign_code,
                `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(
                    a.canal,
                    b.marca,
                    b.seller,
                    b.service_type
                )
            )
        END = 'Lineas adicionales OUT'
    AND b.activation_date BETWEEN '2023-12-01' AND '2024-02-29'
)

AND NOT (
    b.canal = 'XS'
    AND b.id_comisionista IN ('CAROUT032','CAROUT033')
)

;


ASSERT NOT EXISTS (
    SELECT *
    FROM `mm-commissions-reporting.TEMP.acti_comisiones`
    QUALIFY COUNT(*) OVER (
        PARTITION BY phone_nm,service_id,marca,service_type,concepto) > 1
)
; -- HAY DUPLICADOS EN ACTI


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones_final` AS
SELECT *
FROM `mm-commissions-reporting.TEMP.acti_comisiones`
WHERE comision IS NOT NULL
  AND (
        comision <> 0
        OR (
            agrupacion_canal = 'Exclusivo'
            AND tariff_ds = 'DUO PRINCIPAL'
            AND order_type_agg = 'ALTA NUEVA'
            AND concepto NOT LIKE '%Portabilidad%'
        )
      )
  AND canal NOT IN ('ALTN', 'ALTNC', 'ALTNH');


/*
----- 'DOT' --- Multiplicador Comisiones MÓVIL
 IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('DOT')) THEN

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.acti_comisiones_tramo_DOT` 
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)) AS(
WITH VENTAS_FIBRA AS (
SELECT COUNT(*) AS TOTAL
-- FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm`
FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones`
WHERE sfid_id = '19140503'
AND brand_ds = 'SIMYO'
AND FORMAT_DATE('%Y%m', sale_date) = mes_string
AND service_type = 'INTERNET'
)
SELECT *
FROM VENTAS_FIBRA VENTAS
LEFT JOIN `mm-commissions-reporting.GS.tramos_dot` TRAMOS
ON VENTAS.TOTAL BETWEEN TRAMOS.RANGO_INI AND TRAMOS.RANGO_FIN
 AND TRAMOS.id_mes = id_mes_pr
)
;
UPDATE `mm-commissions-reporting.TEMP.acti_comisiones_final` ACTI
SET ACTI.COMISION = CASE 
                    WHEN ACTI.BILLING_TYPE_DS = 'POSTPAID' AND ACTI.order_type_agg = 'PORTABILIDAD' THEN ACTI.COMISION/1.21*TRAMO.importe_pr 
                    WHEN ACTI.BILLING_TYPE_DS = 'PREPAID'  THEN ACTI.COMISION/1.21*TRAMO.importe_pre
                    ELSE ACTI.COMISION/1.21*TRAMO.importe_pos END
FROM `mm-commissions-reporting.TEMP.acti_comisiones_tramo_DOT` TRAMO

WHERE ACTI.concepto IN ('A - Servicio Movil Pospago' , 'A - Servicio Movil Prepago')
 AND ACTI.canal = 'DOT'

;
END IF;
*/

--- ACTUALIZAR PONDERACION PORTABILIDAD CANAL XSO ---
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('XSO')) THEN

UPDATE  `mm-commissions-reporting.TEMP.acti_comisiones_final` ACTI
SET ACTI.comision = TARIFAS.tramo_2
FROM `mm-commissions-reporting.COMISIONES.v_tarifas` TARIFAS
WHERE ACTI.campaign_code = TARIFAS.campaign_code
  AND ACTI.marca = TARIFAS.marca
  AND ACTI.canal = TARIFAS.canal
  AND ACTI.tariff_id = TARIFAS.tariff_id
  AND ACTI.tariff_ds = TARIFAS.tariff_ds
  AND TARIFAS.id_mes = id_mes_pr
  AND ACTI.CANAL = 'XSO'
  AND ACTI.campaign_code IN ( 'CROSS SELLING','CROSS SELLING_MV')
  AND ACTI.CONCEPTO = 'A - Servicio Movil Pospago'
  AND ACTI.order_type_agg = 'PORTABILIDAD'
;
END IF;


--APLICAR FACTOR DE SEGMENTACIÓN LIGA (SOLO D2D)
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN

UPDATE `mm-commissions-reporting.TEMP.acti_comisiones_final` v
SET comision = v.comision * f.porcentaje
FROM `mm-commissions-reporting.GS.gs_segmento_liga` f
WHERE v.cif = f.cif
  AND f.id_mes = id_mes_pr
  AND v.activation_date >= '2026-07-01'
  AND NOT CONTAINS_SUBSTR(v.concepto, 'Cartera')
  AND v.concepto NOT IN (
      'P - Bajada Tarifa Fijo 3M Recalculo',
      'P - Bajada Tarifa Fijo 3M Deduccion',
      'P - Cartera'
      )
  AND v.concepto NOT LIKE 'Z - %'
  AND v.estado = 'calculado'
  AND v.canal IN ('D2D','D2N','DEM');

END IF;

-- REDUCCION COMISION A FIBRAS INDIRECTAS SIMYO CANAL MKT_NR
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('MKT_NR')) THEN

UPDATE `mm-commissions-reporting.TEMP.acti_comisiones_final` ACTI
SET comision = CASE WHEN ACTI.COMISION = 125 THEN 112 
                    WHEN ACTI.COMISION = 115 THEN 98
                    ELSE ACTI.COMISION * 0.80 END
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` INF

WHERE ACTI.CONCEPTO = 'A - Servicio Fijo'
  AND ACTI.MARCA = 'SIMYO'
  AND ACTI.canal IN ('MKT_NR')
  AND ACTI.service_id = INF.service_id
  AND ACTI.phone_nm = CAST (INF.phone_nm AS STRING)
  AND INF.brand_ds = 'SIMYO'
  AND INF.tipo_Huella = 'INDIRECTA'
  AND INF.subtipo_Huella = 'INDIRECTA NEBA'
  ;

END IF;


--- Insertar tabla final ----

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr, 'TEMP.acti_comisiones_final'  , 'ACTUALIZAR');


-- Actualizar check de ventas base -- 
CALL `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`( FALSE );
call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base_prueba`(false);


END