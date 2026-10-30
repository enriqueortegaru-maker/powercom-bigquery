BEGIN


/*
CALL COMISIONES.pr_tbxsell(202507, NULL, NULL, 0);
*/


/* Declara las variables que se van a usar a lo largo del procedimiento */
DECLARE mes_string, prefijo STRING;
DECLARE meses ARRAY <DATE>;
DECLARE m INT64 DEFAULT 0;
DECLARE id_mes_periodo_facturado_ini, id_mes_periodo_facturado_fin INT64;
DECLARE mes_periodo_facturado_ini, mes_periodo_facturado_fin  DATE;


SET mes_string = CAST(id_mes_pr AS STRING);

/* Si solo el valor de "id_mes_pr" está indicado, el procedimiento se ejecutara solo para ese mes. Pero si el valor de "mes_fin" es introducido, el procedimiento se ejecuta para el rango de meses entre y incluyendo los meses de "mes_inicio" y "mes_fin" */
IF mes_fin IS NULL THEN SET meses = ARRAY(SELECT PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)));
ELSE SET meses = GENERATE_DATE_ARRAY(PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)), PARSE_DATE('%Y%m', CAST(mes_fin AS STRING)), INTERVAL 1 MONTH);
END IF;


/* Borramos la tabla temporal de una ejecución previa */
IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = 'tbxsell_sin_filtro') > 0
THEN DROP TABLE `mm-commissions-reporting.TEMP.tbxsell_sin_filtro`;
END IF;


WHILE m < ARRAY_LENGTH(meses) DO -- Bucle mes

/* Contador bucle mes */
SET m = m + 1;

SET mes_periodo_facturado_fin = meses[ORDINAL(m)];
SET id_mes_periodo_facturado_fin = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_fin) AS INT64);
SET mes_periodo_facturado_ini = DATE_ADD(meses[ORDINAL(m)], INTERVAL  - 3 MONTH);
SET id_mes_periodo_facturado_ini = CAST(FORMAT_DATE('%Y%m',  mes_periodo_facturado_ini ) AS INT64);


/* Extraemos las líneas de Billing para el periodo deseado */
CREATE OR REPLACE TEMPORARY TABLE tbxsell_sin_filtro AS
(
SELECT
      mes_periodo_facturado_ini AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,*

FROM (
     SELECT
           TRANSACCIONES_DETALLE.agrupacion_canal
          ,DEALER.canal
          ,DEALER.id_comisionista
          ,DEALER.distribuidor
          ,TRANSACCIONES_DETALLE.sfid_id
          ,TRANSACCIONES_DETALLE.seller
          ,DEALER.nombre_comercio
          ,DEALER.razon_social
          ,DEALER.cif
          ,DEALER.zona_fiscal
          ,TRANSACCIONES.marca
          ,TRANSACCIONES.service_type
          ,TRANSACCIONES.phone_nm
          ,BILLING.tariff_id
          ,BILLING.tariff_ds
          ,TRANSACCIONES.service_id
          ,TRANSACCIONES_DETALLE.account_id
          ,TRANSACCIONES_DETALLE.customer_id
          ,TRANSACCIONES_DETALLE.line_type_ds
          ,TRANSACCIONES_DETALLE.bundle_type
          ,TRANSACCIONES_DETALLE.technology_ds
          ,TRANSACCIONES_DETALLE.billing_type_ds
          ,TRANSACCIONES_DETALLE.sale_date
          ,TRANSACCIONES_DETALLE.activation_date
          ,TRANSACCIONES_DETALLE.deactivation_date
          ,TRANSACCIONES_DETALLE.order_id
          ,TRANSACCIONES_DETALLE.order_type_agg
          ,TRANSACCIONES_DETALLE.cod_segmento
          ,TRANSACCIONES_DETALLE.cod_marca
          ,TRANSACCIONES_DETALLE.cod_tipo_contrato
          ,TRANSACCIONES_DETALLE.cod_producto
          ,TRANSACCIONES_DETALLE.cod_canal
          ,REPLACE(REPLACE(TO_JSON_STRING(TRANSACCIONES.commission_id), '[', ''), ']', '') AS process_code
          ,TRANSACCIONES.comision AS comision_original
     
          ,CASE
               WHEN TRANSACCIONES.penalizacion_intragrupo = 1 THEN TARIFAS.comision * .5
               ELSE TARIFAS.comision
           END AS comision_actualizada
          
     FROM (
          SELECT *
          FROM (
               SELECT
                     service_id
                    ,phone_nm
                    ,marca
                    ,service_type
                    ,tariff_id
                    ,MIN(activation_date) AS activation_date
                    ,MIN(deactivation_date) AS deactivation_date
                    ,MIN(commission_id) AS commission_id
                    ,ARRAY_AGG(commission_id) AS process_code
                    ,SUM(CASE WHEN concepto LIKE 'P%' THEN 1 ELSE 0 END) AS penalizacion
                    ,SUM(CASE WHEN UPPER(comments) LIKE '%INTRAGRUPO%' THEN 1 ELSE 0 END) AS penalizacion_intragrupo
                    ,SUM(comision) AS comision
               
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE CANAL = 'XS' AND campaign_code IN ('Camp. piloto','Blindaje')
                     AND (
                         (
                         mes_liquidado = mes_periodo_facturado_ini
                         AND concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
                         )
                         OR
                         (
                         mes_liquidado BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin
                         AND (commission_id NOT LIKE 'TBXELL%' AND estado = 'calculado')
                         AND concepto IN (
                              'E - Clawback Servicio Fijo'
                             ,'E - Clawback Servicio Movil Pospago'
                             ,'P - Servicio Fijo'
                             ,'P - Servicio Movil Pospago'
                             ,'Z - Clawback Servicio Fijo'
                             ,'Z - Clawback Servicio Movil Pospago'
                             ,'Z - Servicio Fijo'
                             ,'Z - Servicio Movil Pospago'
                             )
                         )
                         )
               
               GROUP BY 1,2,3,4,5
               )
          
          WHERE comision > 0.0
                AND (penalizacion = 0 OR (penalizacion = 1 AND penalizacion_intragrupo = 1))
                AND DATE_TRUNC(activation_date, MONTH) = mes_periodo_facturado_ini
                AND deactivation_date = '9999-12-31'
          ) TRANSACCIONES
     
     LEFT JOIN (
               SELECT
                     data_month_id
                    ,phone_nm
                    ,brand_ds
                    ,service_type
                    ,bundle_id AS tariff_id
                    ,bundle_name AS tariff_ds
               
               FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
               
               WHERE data_month_id = id_mes_periodo_facturado_fin
                     AND phone_nm IS NOT NULL
                     AND brand_ds IN ('MASMOVIL', 'YOIGO')
                     AND service_type IN ('INTERNET', 'MOBILE')
                     AND bundle_id IS NOT NULL
                     AND imp_without_tax > 0.0
               
               QUALIFY ROW_NUMBER() OVER (
                                         PARTITION BY data_month_id, phone_nm, brand_ds, service_type
                                         ORDER BY service_id DESC, movement_date DESC, CAST(imp_without_tax AS STRING) DESC
                                         ) = 1
               ) BILLING
              ON TRANSACCIONES.phone_nm = CAST(BILLING.phone_nm AS STRING) AND TRANSACCIONES.marca = BILLING.brand_ds
                 AND TRANSACCIONES.service_type = BILLING.service_type
     
     LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES_DETALLE
              ON TRANSACCIONES.commission_id = TRANSACCIONES_DETALLE.commission_id
          
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
              ON TRANSACCIONES_DETALLE.id_comisionista = DEALER.id_comisionista
                 AND TRANSACCIONES_DETALLE.agrupacion_canal = DEALER.agrupacion_canal
     
     LEFT JOIN (
               SELECT
                     canal
                    ,marca
                    ,service_type
                    ,tariff_id
                    ,tariff_ds
                    ,line_type_ds
                    ,comision
               
               FROM `mm-commissions-reporting.COMISIONES.v_tarifas`
               UNPIVOT (comision FOR tramo IN (tramo_1, tramo_2, tramo_3, tramo_4, tramo_5))
     
               WHERE id_mes BETWEEN id_mes_periodo_facturado_ini AND id_mes_periodo_facturado_fin
                     AND canal IN ('XS')
                     AND comision > 0.0
     
               QUALIFY ROW_NUMBER() OVER (PARTITION BY canal, marca,service_type, tariff_id, COALESCE(line_type_ds, 'L') ORDER BY id_mes ASC) = 1
               ) TARIFAS
              ON TRANSACCIONES.marca = TARIFAS.marca
                 AND TRANSACCIONES.service_type = TARIFAS.service_type
                 AND BILLING.tariff_id = TARIFAS.tariff_id
                 AND TRANSACCIONES_DETALLE.canal = TARIFAS.canal
                 AND COALESCE(TRANSACCIONES_DETALLE.line_type_ds, 'L') = COALESCE(TARIFAS.line_type_ds, TRANSACCIONES_DETALLE.line_type_ds, 'L')
     
     LEFT JOIN (
               SELECT *
               FROM `mm-datamart-kd.SERVICES.campaign_base_emysim`
               WHERE campaign_category_name = 'TRY & BUY FIBRA'
                     AND DATE_DIFF(DATE(end_date_ts), DATE(init_date_ts), DAY) <= 90
               ) CAMPAIGN_FIBRA
              ON CASE WHEN TRANSACCIONES_DETALLE.marca = 'PEPEPHONE' THEN TRANSACCIONES_DETALLE.service_id ELSE TRANSACCIONES_DETALLE.phone_nm END
                 =
                 CASE WHEN CAMPAIGN_FIBRA.brand_ds = 'PEPEPHONE' THEN CAMPAIGN_FIBRA.service_id ELSE CAST(CAMPAIGN_FIBRA.phone_nm AS STRING) END
                 AND TRANSACCIONES_DETALLE.marca = CAMPAIGN_FIBRA.brand_ds
                 AND TRANSACCIONES_DETALLE.activation_date BETWEEN DATE(CAMPAIGN_FIBRA.init_date_ts) AND DATE(CAMPAIGN_FIBRA.end_date_ts)
     
     LEFT JOIN (
               SELECT *
               FROM `mm-datamart-kd.SERVICES.campaign_base_emysim`
               WHERE campaign_category_name = 'TRY & BUY TARIFA'
                     AND DATE_DIFF(DATE(end_date_ts), DATE(init_date_ts), DAY) <= 90
               ) CAMPAIGN_TARIFA
              ON TRANSACCIONES_DETALLE.phone_nm = CAST(CAMPAIGN_TARIFA.phone_nm AS STRING)
                 AND TRANSACCIONES_DETALLE.marca = CAMPAIGN_TARIFA.brand_ds
                 AND TRANSACCIONES_DETALLE.activation_date BETWEEN DATE(CAMPAIGN_TARIFA.init_date_ts) AND DATE(CAMPAIGN_TARIFA.end_date_ts)
     
     WHERE TRANSACCIONES.phone_nm IS NOT NULL
           AND TRANSACCIONES.tariff_id != BILLING.tariff_id
           AND DEALER.comisiona
           AND (
               (TRANSACCIONES.service_type = 'INTERNET' AND CAMPAIGN_FIBRA.campaign_category_name IS NOT NULL)
               OR
               (TRANSACCIONES.service_type = 'MOBILE' AND CAMPAIGN_TARIFA.campaign_category_name IS NOT NULL)
               )
     
     QUALIFY RANK() OVER (
                         PARTITION BY TRANSACCIONES.commission_id
                         ORDER BY BILLING.data_month_id DESC,
                                  CASE WHEN CAMPAIGN_FIBRA.user_profile_role = 'GENERICO' THEN 2 ELSE 1 END ASC,
                                  CASE WHEN CAMPAIGN_TARIFA.user_profile_role = 'GENERICO' THEN 2 ELSE 1 END ASC
                         ) = 1
     )
)
;



IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = "tbxsell_sin_filtro") = 0
THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tbxsell_sin_filtro` CLUSTER BY mes_liquidado OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS SELECT * FROM tbxsell_sin_filtro;

ELSE
INSERT INTO `mm-commissions-reporting.TEMP.tbxsell_sin_filtro` (SELECT * FROM tbxsell_sin_filtro);
END IF;


END WHILE;


/* Se ejecuta el proceso en modo estándar */
IF ajuste = 0

THEN

SET prefijo = 'TBXSELL';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tbxsell` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      prefijo || 'R_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal
     ,'P - Bajada Tarifa Fijo 3M Recalculo' as concepto
--      ,CASE WHEN service_type = 'INTERNET' THEN 'P - Servicio Fijo' ELSE ' P - Servicio Movil Pospago' END AS concepto

     ,'UPFR' AS tipo_concepto
     ,1 as unidades
     ,comision_actualizada AS comision
     ,id_comisionista
     ,distribuidor
     ,sfid_id
     ,seller
     ,nombre_comercio
     ,razon_social
     ,cif
     ,zona_fiscal
     ,marca
     ,service_type
     ,phone_nm
     ,tariff_id
     ,tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,billing_type_ds
     ,sale_date
     ,activation_date
     ,deactivation_date
     ,order_id
     ,order_type_agg
     ,cod_segmento
     ,cod_marca
     ,cod_tipo_contrato
     ,cod_producto
     ,cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.tbxsell_sin_filtro`

WHERE comision_original > comision_actualizada

UNION ALL

SELECT
      prefijo || 'D_' || mes_string || '_' || TBXSELL.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,TBXSELL.mes_liquidado
     ,TBXSELL.id_mes
     ,TBXSELL.agrupacion_canal
     ,TBXSELL.canal
--      ,TBXSELL.concepto
     ,'P - Bajada Tarifa Fijo 3M Deduccion' as concepto
     ,'UPFR' AS tipo_concepto
     ,1 as unidades
     ,TBXSELL.comision_original * -1 AS comision
     ,TBXSELL.id_comisionista
     ,TBXSELL.distribuidor
     ,TBXSELL.sfid_id
     ,TBXSELL.seller
     ,TBXSELL.nombre_comercio
     ,TBXSELL.razon_social
     ,TBXSELL.cif
     ,TBXSELL.zona_fiscal
     ,TBXSELL.marca
     ,TBXSELL.service_type
     ,TBXSELL.phone_nm
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,TRANSACCIONES.technology_ds
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.order_id
     ,TRANSACCIONES.order_type_agg
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TBXSELL.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,TBXSELL.process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.tbxsell_sin_filtro` TBXSELL

LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
         ON REPLACE(TBXSELL.process_code, '"', '') = TRANSACCIONES.commission_id

WHERE comision_original > comision_actualizada
)
;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.tbxsell), 'TEMP.tbxsell', 'ACTUALIZAR');

END IF;


/* Se ejecuta el proceso en modo ajuste. Se generan automáticamente el ajuste y la retrotracción */
IF ajuste = 1

THEN

SET prefijo = 'TBXSELLAJ';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tbxsell` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      prefijo || 'R_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal

     ,CASE WHEN service_type = 'INTERNET' THEN 'P - Servicio Fijo' ELSE ' P - Servicio Movil Pospago' END AS concepto
     
     ,'UPFR' AS tipo_concepto
     ,1 as unidades
     ,comision_actualizada AS comision
     ,id_comisionista
     ,distribuidor
     ,sfid_id
     ,seller
     ,nombre_comercio
     ,razon_social
     ,cif
     ,zona_fiscal
     ,marca
     ,service_type
     ,phone_nm
     ,tariff_id
     ,tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,billing_type_ds
     ,sale_date
     ,activation_date
     ,deactivation_date
     ,order_id
     ,order_type_agg
     ,cod_segmento
     ,cod_marca
     ,cod_tipo_contrato
     ,cod_producto
     ,cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.tbxsell_sin_filtro`

WHERE comision_original > comision_actualizada

UNION ALL

SELECT
      prefijo || 'D_' || mes_string || '_' || TBXSELL.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,TBXSELL.mes_liquidado
     ,TBXSELL.id_mes
     ,TBXSELL.agrupacion_canal
     ,TBXSELL.canal
     ,TBXSELL.concepto
     ,'UPFR' AS tipo_concepto
     ,1 as unidades
     ,TBXSELL.comision_original * -1 AS comision
     ,TBXSELL.id_comisionista
     ,TBXSELL.distribuidor
     ,TBXSELL.sfid_id
     ,TBXSELL.seller
     ,TBXSELL.nombre_comercio
     ,TBXSELL.razon_social
     ,TBXSELL.cif
     ,TBXSELL.zona_fiscal
     ,TBXSELL.marca
     ,TBXSELL.service_type
     ,TBXSELL.phone_nm
     ,TRANSACCIONES.tariff_id
     ,TRANSACCIONES.tariff_ds
     ,TRANSACCIONES.service_id
     ,TRANSACCIONES.account_id
     ,TRANSACCIONES.customer_id
     ,TRANSACCIONES.line_type_ds
     ,TRANSACCIONES.bundle_type
     ,TRANSACCIONES.technology_ds
     ,TRANSACCIONES.billing_type_ds
     ,TRANSACCIONES.sale_date
     ,TRANSACCIONES.activation_date
     ,TRANSACCIONES.deactivation_date
     ,TRANSACCIONES.order_id
     ,TRANSACCIONES.order_type_agg
     ,TRANSACCIONES.cod_segmento
     ,TRANSACCIONES.cod_marca
     ,TRANSACCIONES.cod_tipo_contrato
     ,TRANSACCIONES.cod_producto
     ,TBXSELL.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,TBXSELL.process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.TBXSELL_sin_filtro` TBXSELL

LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
         ON REPLACE(TBXSELL.process_code, '"', '') = TRANSACCIONES.commission_id

WHERE comision_original > comision_actualizada

UNION ALL

SELECT
      prefijo || 'Z_' || mes_string || '_' || DEALER.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_liquidado
     ,id_mes_pr AS id_mes
     ,TRANSACCIONES.agrupacion_canal
     ,canal
     ,REPLACE(concepto, 'P -', 'Z -') AS concepto
     ,tipo_concepto
     ,0 as unidades
     ,importe_facturado * -1 AS comision
     ,DEALER.id_comisionista
     ,distribuidor
     ,sfid_id
     ,seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,marca
     ,service_type
     ,phone_nm
     ,tariff_id
     ,tariff_ds
     ,service_id
     ,account_id
     ,customer_id
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,billing_type_ds
     ,sale_date
     ,activation_date
     ,deactivation_date
     ,order_id
     ,order_type_agg
     ,cod_segmento
     ,cod_marca
     ,cod_tipo_contrato
     ,cod_producto
     ,cod_canal
     ,campaign_code
     ,serial_number
     ,tax_base
     ,claim_code
     ,commission_id AS process_code
     ,comments
     ,facturador

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
     
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista
            AND BILLING.agrupacion_canal = DEALER.agrupacion_canal

WHERE DEALER.CANAL = 'XS' AND TRANSACCIONES.campaign_code IN ('Camp. piloto','Blindaje')
      AND mes_liquidado BETWEEN PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)) AND PARSE_DATE('%Y%m', CAST(mes_fin AS STRING))
      AND estado = 'facturado'
      AND commission_id LIKE 'TBXSELL%'
      AND DEALER.comisiona
)
;

--CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.tbxsell), 'TEMP.tbxsell', 'ACTUALIZAR');

END IF;


END