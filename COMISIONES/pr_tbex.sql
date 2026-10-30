BEGIN


/*
CALL COMISIONES.pr_tbex(202609, NULL, NULL, 0);
*/


/* Declara las variables que se van a usar a lo largo del procedimiento */
DECLARE mes_string, prefijo STRING;
DECLARE meses ARRAY <DATE>;
DECLARE m INT64 DEFAULT 0;
DECLARE id_mes_periodo_facturado_ini, id_mes_periodo_facturado_cambio, id_mes_periodo_facturado_ini_n6, id_mes_periodo_facturado_150d, id_mes_periodo_facturado_fin INT64;
DECLARE mes_periodo_facturado_ini, mes_periodo_facturado_cambio, mes_periodo_facturado_ini_n6, mes_periodo_facturado_150d, mes_periodo_facturado_fin  DATE;


SET mes_string = CAST(id_mes_pr AS STRING);

/* Si solo el valor de "id_mes_pr" está indicado, el procedimiento se ejecutara solo para ese mes. Pero si el valor de "mes_fin" es introducido, el procedimiento se ejecuta para el rango de meses entre y incluyendo los meses de "mes_inicio" y "mes_fin" */
IF mes_fin IS NULL THEN SET meses = ARRAY(SELECT PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)));
ELSE SET meses = GENERATE_DATE_ARRAY(PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)), PARSE_DATE('%Y%m', CAST(mes_fin AS STRING)), INTERVAL 1 MONTH);
END IF;


/* Borramos la tabla temporal de una ejecución previa */
IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = 'tbex_sin_filtro') > 0
THEN DROP TABLE `mm-commissions-reporting.TEMP.tbex_sin_filtro`;
END IF;


WHILE m < ARRAY_LENGTH(meses) DO -- Bucle mes

/* Contador bucle mes */
SET m = m + 1;

SET mes_periodo_facturado_fin = meses[ORDINAL(m)];
SET id_mes_periodo_facturado_fin = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_fin) AS INT64);
SET mes_periodo_facturado_cambio = DATE_ADD(meses[ORDINAL(m)], INTERVAL  - 1 MONTH);
SET id_mes_periodo_facturado_cambio = CAST(FORMAT_DATE('%Y%m',  mes_periodo_facturado_cambio ) AS INT64);
SET mes_periodo_facturado_ini = DATE_ADD(meses[ORDINAL(m)], INTERVAL  - 3 MONTH);
SET id_mes_periodo_facturado_ini = CAST(FORMAT_DATE('%Y%m',  mes_periodo_facturado_ini ) AS INT64);
SET mes_periodo_facturado_ini_n6 = DATE_ADD(meses[ORDINAL(m)], INTERVAL  - 6 MONTH);
SET id_mes_periodo_facturado_ini_n6 = CAST(FORMAT_DATE('%Y%m',  mes_periodo_facturado_ini_n6 ) AS INT64);
SET mes_periodo_facturado_150d = DATE_ADD(mes_periodo_facturado_ini_n6, INTERVAL 5 MONTH);
SET id_mes_periodo_facturado_150d = CAST(FORMAT_DATE('%Y%m',  DATE_ADD(mes_periodo_facturado_ini_n6, INTERVAL 5 MONTH) ) AS INT64);


/* Extraemos las líneas de Billing para el periodo deseado */
CREATE OR REPLACE TEMPORARY TABLE tbex_sin_filtro AS
(
(
SELECT
      mes_periodo_facturado_ini AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,*

FROM (
     SELECT
           TRANSACCIONES_DETALLE.agrupacion_canal
          ,DEALER.canal
          ,TRANSACCIONES.concepto
          ,DEALER.id_comisionista
          ,DEALER.distribuidor
          ,DEALER.id_comisionista AS sfid_id
          ,DEALER.id_comisionista AS seller
          ,DEALER.nombre_comercio
          ,DEALER.razon_social
          ,DEALER.cif
          ,DEALER.zona_fiscal
          ,TRANSACCIONES.marca
          ,TRANSACCIONES.service_type
          ,TRANSACCIONES.phone_nm
          ,TRANSACCIONES.tariff_id AS tariff_id_original
          ,TRANSACCIONES.tariff_ds AS tariff_ds_original
          ,VELOCIDAD_VENTA.technology||' '||VELOCIDAD_VENTA.internet_speed AS velocidad_original
          ,BILLING.tariff_id

          ,CASE 
               WHEN HUELLAS_INDIRECTAS.Tipo_Huella = 'INDIRECTA' AND TRANSACCIONES_DETALLE.canal != 'ENK' THEN BILLING.tariff_ds||' (INDIRECTA)'
               ELSE BILLING.tariff_ds
           END AS tariff_ds
          
          ,VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed AS velocidad
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
               WHEN HUELLAS_INDIRECTAS.Tipo_Huella = 'INDIRECTA' AND TRANSACCIONES_DETALLE.canal != 'ENK' THEN
                   CASE 
                       WHEN TRANSACCIONES_DETALLE.concepto = 'A - Servicio Fijo' THEN
                           CASE 
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 1000' THEN 90.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 800'  THEN 70.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 600'  THEN 70.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 500'  THEN 50.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 300'  THEN 50.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 100'  THEN 50.0
                           END
                       WHEN TRANSACCIONES_DETALLE.concepto IN ('A - Servicio Fijo Cambio de Domicilio','A - Servicio Fijo Cambio de Tecnologia') THEN
                           CASE 
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 1000' THEN 80.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 800'  THEN 60.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 600'  THEN 60.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 500'  THEN 40.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 300'  THEN 40.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 100'  THEN 40.0
                               WHEN VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed = 'FIBRA 50'   THEN 20.0
                           END
                   END
               ELSE TARIFAS.comision
           END AS comision_actualizada

          ,HUELLAS_INDIRECTAS.Tipo_Huella AS huella
          
     FROM (
          SELECT *
          FROM (
               SELECT
                     service_id
                    ,phone_nm
                    ,marca
                    ,service_type
                    ,tariff_id
                    ,concepto
                    ,MAX(tariff_ds) AS tariff_ds
                    ,MIN(activation_date) AS activation_date
                    ,MIN(deactivation_date) AS deactivation_date
                    ,MIN(commission_id) AS commission_id
                    ,ARRAY_AGG(commission_id) AS process_code
                    ,SUM(CASE WHEN concepto LIKE 'P%' THEN 1 ELSE 0 END) AS penalizacion
                    ,SUM(CASE WHEN UPPER(comments) LIKE '%INTRAGRUPO%' THEN 1 ELSE 0 END) AS penalizacion_intragrupo
                    ,SUM(comision) AS comision
               
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE agrupacion_canal = 'Exclusivo'
                     AND (
                         (
                         mes_liquidado = mes_periodo_facturado_ini
                        --  AND concepto IN ('A - Servicio Fijo Cambio de Domicilio', 'A - Servicio Fijo Cambio de Tecnologia', 'A - Servicio Fijo')
                         AND SUBSTR(concepto, 5) IN ('Servicio Fijo Cambio de Domicilio', 'Servicio Fijo Cambio de Tecnologia', 'Servicio Fijo')
                         )
                        --  OR
                        --  (
                        --  mes_liquidado BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin
                        --  AND (commission_id NOT LIKE 'TBEX%' AND estado = 'calculado')
                        --  AND concepto IN (
                        --       'E - Clawback Servicio Fijo Cambio de Domicilio'
                        --      ,'E - Clawback Servicio Fijo Cambio de Tecnologia'
                        --      ,'P - Servicio Fijo Cambio de Domicilio'
                        --      ,'P - Servicio Servicio Fijo Cambio de Tecnologia'
                        --      ,'Z - Clawback Servicio Fijo Cambio de Domicilio'
                        --      ,'Z - Clawback Servicio Fijo Cambio de Tecnologia'
                        --      ,'Z - Servicio Fijo Cambio de Domicilio'
                        --      ,'Z - Servicio Fijo Cambio de Tecnologia'
                        --      ,'E - Clawback Servicio Fijo'
                        --      ,'P - Servicio Fijo'
                        --      ,'Z - Clawback Servicio Fijo'
                        --      ,'Z - Servicio Fijo'
                        --      )
                        --  )
                         )
               
               GROUP BY 1,2,3,4,5,6
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
                    ,CASE WHEN service_type = 'BROADBAND' THEN 'INTERNET' ELSE service_type END AS service_type

                    ,CASE WHEN service_type = 'MOBILE' THEN tariff_id ELSE bundle_id END AS tariff_id

                    ,CASE WHEN service_type = 'MOBILE' THEN tariff_ds ELSE bundle_name END AS tariff_ds
               
               FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
               
               WHERE data_month_id = id_mes_periodo_facturado_fin
                     AND phone_nm IS NOT NULL
                     AND brand_ds IN ('MASMOVIL', 'YOIGO')
                     AND service_type IN ('INTERNET', 'MOBILE', 'BROADBAND')
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
     
               WHERE id_mes = id_mes_periodo_facturado_fin
                     AND canal IN ('ECI', 'EDB', 'EML', 'ENX','ENK', 'EYG', 'MP')
                     AND comision > 0.0
     
               QUALIFY ROW_NUMBER() OVER (PARTITION BY canal, marca,service_type, tariff_id, COALESCE(line_type_ds, 'L') ORDER BY id_mes ASC,creado DESC) = 1
               ) TARIFAS
              ON TRANSACCIONES.marca = TARIFAS.marca
                 AND TRANSACCIONES.service_type = TARIFAS.service_type
                 AND BILLING.tariff_id = TARIFAS.tariff_id
                 AND TRANSACCIONES_DETALLE.canal = TARIFAS.canal
                 AND COALESCE(TRANSACCIONES_DETALLE.line_type_ds, 'L') = COALESCE(TARIFAS.line_type_ds, TRANSACCIONES_DETALLE.line_type_ds, 'L')
          
     LEFT JOIN `mm-datamart-kd.SERVICES.service_base_telco` SERVICE_BASE_TELCO
              ON TRANSACCIONES.phone_nm = CAST(SERVICE_BASE_TELCO.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = SERVICE_BASE_TELCO.comm_brand_ds
                 AND DATE_TRUNC(SERVICE_BASE_TELCO.activation_date, MONTH) BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin
          
     LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
              ON UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)]) = DEALER.sfid_id
                 AND TRANSACCIONES_DETALLE.agrupacion_canal = DEALER.agrupacion_canal
                 AND LENGTH(UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)])) > 2
     
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
   

     LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS
              ON TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = VENTAS.brand_ds
                 AND TRANSACCIONES.activation_date = VENTAS.activation_date
                 AND SERVICE_BASE_TELCO.service_id = VENTAS.service_id

     LEFT JOIN (
               SELECT
                     brand_ds,
                     bundle_id,
                     name,
                     technology,
                     internet_speed
               FROM `mm-datamart-kd.SERVICES.mascatalogue_package_base`,
                 UNNEST(mandatory_products) AS product
               WHERE is_actual = 1 AND init_date >= "2024-08-01"
               GROUP BY ALL
               ) VELOCIDAD_VENTA
              ON VENTAS.sell_bundle_id = VELOCIDAD_VENTA.bundle_id

     LEFT JOIN (
               SELECT
                     brand_ds,
                     bundle_id,
                     name,
                     technology,
                     internet_speed
               FROM `mm-datamart-kd.SERVICES.mascatalogue_package_base`,
                 UNNEST(mandatory_products) AS product
               WHERE is_actual = 1 AND init_date >= "2024-08-01"
               GROUP BY ALL
               ) VELOCIDAD_BILLING
              ON BILLING.tariff_id = VELOCIDAD_BILLING.bundle_id
     
     LEFT JOIN (
               SELECT  
                 prov.ftth_territoryowner, 
                 ventas.phone_nm,
                 MAESTRO.Tipo_Huella,
                 prov.workorder_closed_date
               
               FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` AS ventas
               
               LEFT JOIN `mm-datamart-kd.ACCESS_PROVISION.provision_base` AS prov
                     ON prov.workorder_id = ventas.order_fix_id
               
               LEFT JOIN `mm-commissions-reporting.COMISIONES.maestro_territoyowner` MAESTRO
                     ON prov.ftth_territoryowner = MAESTRO.Territory_Owner
               
               WHERE 
                  ventas.service_type = "INTERNET"
                 AND ventas.activation_date >= '2025-05-01' 
                 AND ventas.sale_date >= DATE_SUB(mes_periodo_facturado_ini, INTERVAL 3 MONTH)
                 AND prov.ftth_territoryowner IN (SELECT Territory_Owner FROM `mm-commissions-reporting.COMISIONES.maestro_territoyowner` WHERE Tipo_Huella = 'INDIRECTA')
                 AND prov.workorder_closed_date IS NOT NULL
                 AND (
                        DATE_TRUNC(mes_periodo_facturado_ini, MONTH) = DATE_TRUNC(DATE(prov.workorder_closed_date), MONTH)
                      OR
                        DATE_ADD(DATE_TRUNC(mes_periodo_facturado_ini, MONTH), INTERVAL 1 MONTH) = DATE_TRUNC(DATE(prov.workorder_closed_date), MONTH)
                      )
               QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm, Tipo_Huella ORDER BY workorder_closed_date DESC) = 1
               ) HUELLAS_INDIRECTAS
               ON CAST(BILLING.phone_nm AS STRING) = HUELLAS_INDIRECTAS.phone_nm 
               AND BILLING.tariff_ds NOT LIKE '%INDIRECTA%'               
     
     LEFT JOIN (SELECT *
                 FROM `mm-commissions-reporting.COMISIONES.transacciones`
                 WHERE id_mes BETWEEN id_mes_periodo_facturado_ini AND id_mes_pr
                 AND SUBSTR(concepto, 5) LIKE 'Clawback Servicio Fijo%'
                ) CLAWBACKS
              ON TRANSACCIONES.phone_nm = CLAWBACKS.phone_nm
              AND TRANSACCIONES.marca = CLAWBACKS.marca
              AND TRANSACCIONES.activation_date = CLAWBACKS.activation_date
              AND '"'||TRANSACCIONES.commission_id||'"' = CLAWBACKS.process_code

     WHERE TRANSACCIONES.phone_nm IS NOT NULL
      --      AND TRANSACCIONES.tariff_id != BILLING.tariff_id
           AND VELOCIDAD_VENTA.technology||' '||VELOCIDAD_VENTA.internet_speed != VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed
           AND DEALER.comisiona
           AND DEALER.id_comisionista NOT LIKE 'DBL%'
           AND TRANSACCIONES.service_type = 'INTERNET'
           AND DEALER.canal = 'EML'
           AND CLAWBACKS.phone_nm IS NULL
           /*AND (
               (TRANSACCIONES.service_type = 'INTERNET' AND CAMPAIGN_FIBRA.campaign_category_name IS NOT NULL)
               OR
               (TRANSACCIONES.service_type = 'MOBILE' AND CAMPAIGN_TARIFA.campaign_category_name IS NOT NULL)
               )*/
     
     QUALIFY RANK() OVER (
                         PARTITION BY TRANSACCIONES.commission_id
                         ORDER BY BILLING.data_month_id DESC,
                                  SERVICE_BASE_TELCO.activation_date DESC,
                                  COALESCE(SERVICE_BASE_TELCO.deactivation_date, '9999-12-31') DESC,
                                  SERVICE_BASE_TELCO.service_id DESC,
                                  CASE WHEN CAMPAIGN_FIBRA.user_profile_role = 'GENERICO' THEN 2 ELSE 1 END ASC,
                                  -- CASE WHEN CAMPAIGN_TARIFA.user_profile_role = 'GENERICO' THEN 2 ELSE 1 END ASC
                                  CAMPAIGN_FIBRA.subscriptioncampaignid ASC
                         ) = 1
     )
)

UNION ALL


/************************************
      T&B 150 DÍAS
*************************************/
(
SELECT
      mes_periodo_facturado_ini_n6 AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,*

FROM (
     SELECT
           TRANSACCIONES_DETALLE.agrupacion_canal
          ,DEALER.canal
          ,TRANSACCIONES.concepto
          ,DEALER.id_comisionista
          ,DEALER.distribuidor
          ,DEALER.id_comisionista AS sfid_id
          ,DEALER.id_comisionista AS seller
          ,DEALER.nombre_comercio
          ,DEALER.razon_social
          ,DEALER.cif
          ,DEALER.zona_fiscal
          ,TRANSACCIONES.marca
          ,TRANSACCIONES.service_type
          ,TRANSACCIONES.phone_nm
          ,TRANSACCIONES.tariff_id AS tariff_id_original
          ,TRANSACCIONES.tariff_ds AS tariff_ds_original
          ,VELOCIDAD_VENTA.technology||' '||VELOCIDAD_VENTA.internet_speed AS velocidad_original
          ,BILLING.tariff_id
          ,BILLING.tariff_ds AS tariff_ds
          ,VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed AS velocidad
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
               WHEN TRANSACCIONES.concepto NOT LIKE '%Domicilio' AND TARIFAS.tramo = 'tramo_1'    THEN TARIFAS.comision
               WHEN TRANSACCIONES.concepto LIKE '%Domicilio' AND TARIFAS.tramo = 'traslados'      THEN TARIFAS.comision 
               WHEN TRANSACCIONES.concepto LIKE '%2da Vivienda' AND TARIFAS.tramo = 'traslados'   THEN TARIFAS.comision 
           END AS comision_actualizada
          
          ,CAST(null AS STRING) AS huella
          
     FROM (
          SELECT *
          FROM (
               SELECT
                     service_id
                    ,phone_nm
                    ,marca
                    ,service_type
                    ,tariff_id
                    ,concepto
                    ,MAX(tariff_ds) AS tariff_ds
                    ,MIN(activation_date) AS activation_date
                    ,MIN(deactivation_date) AS deactivation_date
                    ,MIN(commission_id) AS commission_id
                    ,ARRAY_AGG(commission_id) AS process_code
                    ,SUM(CASE WHEN concepto LIKE 'P%' THEN 1 ELSE 0 END) AS penalizacion
                    ,SUM(CASE WHEN UPPER(comments) LIKE '%INTRAGRUPO%' THEN 1 ELSE 0 END) AS penalizacion_intragrupo
                    ,SUM(comision) AS comision
               
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE agrupacion_canal = 'Exclusivo'
                     AND (
                         (
                         mes_liquidado = mes_periodo_facturado_ini_n6
                        --  AND concepto IN ('A - Servicio Fijo Cambio de Domicilio', 'A - Servicio Fijo Cambio de Tecnologia', 'A - Servicio Fijo','A - Servicio Fijo 2da Vivienda')
                         AND SUBSTR(concepto, 5) IN ('Servicio Fijo Cambio de Domicilio', 'Servicio Fijo Cambio de Tecnologia', 'Servicio Fijo','Servicio Fijo 2da Vivienda')
                         )
                        --  OR
                        --  (
                        --  mes_liquidado BETWEEN mes_periodo_facturado_ini_n6 AND mes_periodo_facturado_150d
                        --  AND (commission_id NOT LIKE 'TBEX%' AND estado = 'calculado')
                        --  AND concepto IN (
                        --       'E - Clawback Servicio Fijo Cambio de Domicilio'
                        --      ,'E - Clawback Servicio Fijo Cambio de Tecnologia'
                        --      ,'P - Servicio Fijo Cambio de Domicilio'
                        --      ,'P - Servicio Servicio Fijo Cambio de Tecnologia'
                        --      ,'Z - Clawback Servicio Fijo Cambio de Domicilio'
                        --      ,'Z - Clawback Servicio Fijo Cambio de Tecnologia'
                        --      ,'Z - Servicio Fijo Cambio de Domicilio'
                        --      ,'Z - Servicio Fijo Cambio de Tecnologia'
                        --      ,'E - Clawback Servicio Fijo'
                        --      ,'P - Servicio Fijo'
                        --      ,'Z - Clawback Servicio Fijo'
                        --      ,'Z - Servicio Fijo'
                        --      ,'E - Clawback Servicio Fijo 2da Vivienda'
                        --      ,'P - Servicio Fijo 2da Vivienda'
                        --      ,'Z - Clawback Servicio Fijo 2da Vivienda'
                        --      ,'Z - Servicio Fijo 2da Vivienda'
                        --      )
                        --  )
                         )
               
               GROUP BY 1,2,3,4,5,6
               )
          
          WHERE comision > 0.0
                AND (penalizacion = 0 OR (penalizacion = 1 AND penalizacion_intragrupo = 1))
                AND DATE_TRUNC(activation_date, MONTH) = mes_periodo_facturado_ini_n6
                AND deactivation_date = '9999-12-31'
          ) TRANSACCIONES
     
     LEFT JOIN (
               SELECT
                     data_month_id
                    ,phone_nm
                    ,brand_ds
                    ,CASE WHEN service_type = 'BROADBAND' THEN 'INTERNET' ELSE service_type END AS service_type

                    ,CASE WHEN service_type = 'MOBILE' THEN tariff_id ELSE bundle_id END AS tariff_id

                    ,CASE WHEN service_type = 'MOBILE' THEN tariff_ds ELSE bundle_name END AS tariff_ds
               
               FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
               
               WHERE data_month_id = id_mes_periodo_facturado_150d
                     AND phone_nm IS NOT NULL
                     AND brand_ds IN ('MASMOVIL', 'YOIGO')
                     AND service_type IN ('INTERNET', 'MOBILE', 'BROADBAND')
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

     LEFT JOIN (
               SELECT
                     canal
                    ,marca
                    ,service_type
                    ,tariff_id
                    ,tariff_ds
                    ,line_type_ds
                    ,comision
                    ,tramo
               
               FROM `mm-commissions-reporting.COMISIONES.v_tarifas`
               UNPIVOT (comision FOR tramo IN (tramo_1, traslados))
     
               WHERE id_mes = id_mes_periodo_facturado_ini_n6
                     AND canal IN ('EML', 'ENK', 'EYG')
                     AND comision > 0.0
     
               QUALIFY ROW_NUMBER() OVER (PARTITION BY canal, marca,service_type, tariff_id, tramo, COALESCE(line_type_ds, 'L') ORDER BY id_mes ASC,creado DESC) = 1
               ) TARIFAS
              ON TRANSACCIONES.marca = TARIFAS.marca
                 AND TRANSACCIONES.service_type = TARIFAS.service_type
                 AND BILLING.tariff_id = TARIFAS.tariff_id
                 AND TRANSACCIONES_DETALLE.canal = TARIFAS.canal
                 AND COALESCE(TRANSACCIONES_DETALLE.line_type_ds, 'L') = COALESCE(TARIFAS.line_type_ds, TRANSACCIONES_DETALLE.line_type_ds, 'L')
          
     LEFT JOIN `mm-datamart-kd.SERVICES.service_base_telco` SERVICE_BASE_TELCO
              ON TRANSACCIONES.phone_nm = CAST(SERVICE_BASE_TELCO.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = SERVICE_BASE_TELCO.comm_brand_ds
                 AND DATE_TRUNC(SERVICE_BASE_TELCO.activation_date, MONTH) BETWEEN mes_periodo_facturado_ini_n6 AND mes_periodo_facturado_150d
          
     LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
              ON UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)]) = DEALER.sfid_id
                 AND TRANSACCIONES_DETALLE.agrupacion_canal = DEALER.agrupacion_canal
                 AND LENGTH(UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)])) > 2
     
     LEFT JOIN (
               SELECT *
               FROM `mm-datamart-kd.SERVICES.campaign_base_emysim`
               WHERE campaign_category_name = 'TRY & BUY FIBRA'
                     AND DATE_DIFF(DATE(end_date_ts), DATE(init_date_ts), DAY) <= 150
                  --    AND campaignname LIKE '%T&B%'
                  --    AND campaign_id IN (822,823,2847,2848)
                     AND init_date_ts >= '2026-03-01'
                     AND service_type IN ('BROADBAND','INTERNET')
                  --    AND NOT (UPPER(campaign_description) LIKE '%SEGUNDA%' 
                  --             OR UPPER(campaignname) LIKE '%SEGUNDA%' 
                  --             OR UPPER(campaign_description) LIKE '%MULTISEDE%' 
                  --             OR UPPER(campaignname) LIKE '%MULTISEDE%' 
                  --             OR UPPER(campaign_description) LIKE '%ADICIONAL%' 
                  --             OR UPPER(campaignname) LIKE '%ADICIONAL%'
                  --            ) -- 20260918 Laura González Rey confirma que se debe aplicar también a segundas residencias
               ) CAMPAIGN_FIBRA
              ON CASE WHEN TRANSACCIONES_DETALLE.marca = 'PEPEPHONE' THEN TRANSACCIONES_DETALLE.service_id ELSE TRANSACCIONES_DETALLE.phone_nm END
                 =
                 CASE WHEN CAMPAIGN_FIBRA.brand_ds = 'PEPEPHONE' THEN CAMPAIGN_FIBRA.service_id ELSE CAST(CAMPAIGN_FIBRA.phone_nm AS STRING) END
                 AND TRANSACCIONES_DETALLE.marca = CAMPAIGN_FIBRA.brand_ds
                 AND TRANSACCIONES_DETALLE.activation_date BETWEEN DATE(CAMPAIGN_FIBRA.init_date_ts) AND DATE(CAMPAIGN_FIBRA.end_date_ts)    

     LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS
              ON TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = VENTAS.brand_ds
                 AND TRANSACCIONES.activation_date = VENTAS.activation_date
                 AND SERVICE_BASE_TELCO.service_id = VENTAS.service_id

     LEFT JOIN (
               SELECT
                     brand_ds,
                     bundle_id,
                     name,
                     technology,
                     internet_speed
               FROM `mm-datamart-kd.SERVICES.mascatalogue_package_base`,
                 UNNEST(mandatory_products) AS product
               WHERE is_actual = 1 AND init_date >= "2024-08-01"
               GROUP BY ALL
               ) VELOCIDAD_VENTA
              ON VENTAS.sell_bundle_id = VELOCIDAD_VENTA.bundle_id

     LEFT JOIN (
               SELECT
                     brand_ds,
                     bundle_id,
                     name,
                     technology,
                     internet_speed
               FROM `mm-datamart-kd.SERVICES.mascatalogue_package_base`,
                 UNNEST(mandatory_products) AS product
               WHERE is_actual = 1 AND init_date >= "2024-08-01"
               GROUP BY ALL
               ) VELOCIDAD_BILLING
              ON BILLING.tariff_id = VELOCIDAD_BILLING.bundle_id
        
     LEFT JOIN (SELECT *
                FROM `mm-commissions-reporting.COMISIONES.transacciones`
                WHERE DATE_TRUNC(activation_date, MONTH) = mes_periodo_facturado_ini_n6
                AND commission_id LIKE 'AJSEM%'
                AND estado IN ('facturado','calculado','validado')
               ) AJUSTE_SEMESTRAL
           ON AJUSTE_SEMESTRAL.phone_nm = TRANSACCIONES.phone_nm  
     
     LEFT JOIN (SELECT *
              FROM `mm-commissions-reporting.COMISIONES.transacciones`
              WHERE id_mes BETWEEN id_mes_periodo_facturado_ini_n6 AND id_mes_pr
              AND SUBSTR(concepto, 5) LIKE 'Clawback Servicio Fijo%'
             ) CLAWBACKS
           ON TRANSACCIONES.phone_nm = CLAWBACKS.phone_nm
           AND TRANSACCIONES.marca = CLAWBACKS.marca
           AND TRANSACCIONES.activation_date = CLAWBACKS.activation_date
           AND '"'||TRANSACCIONES.commission_id||'"' = CLAWBACKS.process_code           

     WHERE TRANSACCIONES.phone_nm IS NOT NULL
           AND VELOCIDAD_VENTA.technology||' '||VELOCIDAD_VENTA.internet_speed != VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed
           AND DEALER.comisiona
           AND TRANSACCIONES.service_type = 'INTERNET'
           AND DEALER.canal = 'ENK'
           AND AJUSTE_SEMESTRAL.phone_nm IS NULL
           AND CLAWBACKS.phone_nm IS NULL
           AND DATE_TRUNC(DATE(CAMPAIGN_FIBRA.init_date_ts), MONTH) = DATE_TRUNC(TRANSACCIONES.activation_date, MONTH)
           AND VENTAS.service_status_ds != 'TERMINADO'
           AND TARIFAS.tramo = CASE 
                                   WHEN TRANSACCIONES.concepto LIKE '%Domicilio'    THEN 'traslados'
                                   WHEN TRANSACCIONES.concepto LIKE '%2da Vivienda' THEN 'traslados'
                                   ELSE 'tramo_1'
                                END
     
     QUALIFY RANK() OVER (
                         PARTITION BY TRANSACCIONES.commission_id
                         ORDER BY BILLING.data_month_id DESC,
                                  SERVICE_BASE_TELCO.activation_date DESC,
                                  COALESCE(SERVICE_BASE_TELCO.deactivation_date, '9999-12-31') DESC,
                                  SERVICE_BASE_TELCO.service_id DESC,
                                  CASE WHEN CAMPAIGN_FIBRA.user_profile_role = 'GENERICO' THEN 2 ELSE 1 END ASC,
                                  CAMPAIGN_FIBRA.subscriptioncampaignid ASC
                         ) = 1
     )
)

UNION ALL


(
SELECT
      mes_periodo_facturado_cambio AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,*

FROM (
     SELECT
           TRANSACCIONES_DETALLE.agrupacion_canal
          ,DEALER.canal
          ,TRANSACCIONES.concepto
          ,DEALER.id_comisionista
          ,DEALER.distribuidor
          ,DEALER.id_comisionista AS sfid_id
          ,DEALER.id_comisionista AS seller
          ,DEALER.nombre_comercio
          ,DEALER.razon_social
          ,DEALER.cif
          ,DEALER.zona_fiscal
          ,TRANSACCIONES.marca
          ,TRANSACCIONES.service_type
          ,TRANSACCIONES.phone_nm
          ,TRANSACCIONES.tariff_id AS tariff_id_original
          ,TRANSACCIONES.tariff_ds AS tariff_ds_original
          ,CAST(null AS STRING) AS velocidad_original
          ,BILLING.tariff_id
          ,BILLING.tariff_ds
          ,CAST(null AS STRING) AS velocidad
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
               WHEN TRANSACCIONES.penalizacion_intragrupo = 1                                                         THEN TARIFAS.comision * .5
               WHEN TRANSACCIONES_DETALLE.canal = 'ENK' AND BILLING.tariff_id IN ('8205','8212','7108','7115','8145') THEN COMPARTIDAS_COSTE.comision
               ELSE TARIFAS.comision
           END AS comision_actualizada
          
          ,CAST (null AS STRING) AS huella
          
     FROM (
          SELECT *
          FROM (
               SELECT
                     service_id
                    ,phone_nm
                    ,marca
                    ,service_type
                    ,tariff_id
                    ,concepto
                    ,MAX(tariff_ds) AS tariff_ds
                    ,MIN(activation_date) AS activation_date
                    ,MIN(deactivation_date) AS deactivation_date
                    ,MIN(commission_id) AS commission_id
                    ,ARRAY_AGG(commission_id) AS process_code
                    ,SUM(CASE WHEN concepto LIKE 'P%' THEN 1 ELSE 0 END) AS penalizacion
                    ,SUM(CASE WHEN UPPER(comments) LIKE '%INTRAGRUPO%' THEN 1 ELSE 0 END) AS penalizacion_intragrupo
                    ,SUM(comision) AS comision
               
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE agrupacion_canal = 'Exclusivo'
                     AND (
                         (
                         mes_liquidado = mes_periodo_facturado_cambio
                        --  AND concepto IN ('A - Servicio Movil Pospago') -- JOHANNA: ¿EL SERVICIO FIJO DEBE IR AQUÍ O JUNTO A LOS CAMBIOS DE DOMICILIO Y TECNOLOGÍA PARA QUE EL MES_LIQUIDADO SEA DATE_ADD -3 MONTH?. ¿LA CONDICIÓN ES QUE TODOS LOS FIJOS SON A 3 MESES O SÓLO LOS CD Y CT?
                        AND SUBSTR(concepto, 5) IN ('Servicio Movil Pospago')
                         )
                        --  OR
                        --  (
                        --  mes_liquidado BETWEEN mes_periodo_facturado_cambio AND mes_periodo_facturado_fin
                        --  AND (commission_id NOT LIKE 'TBEX%' AND estado = 'calculado')
                        --  AND concepto IN (
                        --        'E - Clawback Servicio Movil Pospago'
                        --      ,'P - Servicio Movil Pospago'
                        --      ,'Z - Clawback Servicio Movil Pospago'
                        --      ,'Z - Servicio Movil Pospago'
                        --      )
                        --  )
                         )
               
               GROUP BY 1,2,3,4,5,6
               )
          
          WHERE comision > 0.0
                AND (penalizacion = 0 OR (penalizacion = 1 AND penalizacion_intragrupo = 1))
                AND DATE_TRUNC(activation_date, MONTH) = mes_periodo_facturado_cambio
                AND deactivation_date = '9999-12-31'
          ) TRANSACCIONES
     
     LEFT JOIN (
               SELECT
                     data_month_id
                    ,phone_nm
                    ,brand_ds
                    ,CASE WHEN service_type = 'BROADBAND' THEN 'INTERNET' ELSE service_type END AS service_type

                    ,CASE WHEN service_type = 'MOBILE' THEN tariff_id ELSE bundle_id END AS tariff_id

                    ,CASE WHEN service_type = 'MOBILE' THEN tariff_ds ELSE bundle_name END AS tariff_ds
               
               FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
               
               WHERE data_month_id = id_mes_periodo_facturado_fin
                     AND phone_nm IS NOT NULL
                     AND brand_ds IN ('MASMOVIL', 'YOIGO')
                     AND service_type IN ('INTERNET', 'MOBILE', 'BROADBAND')
                     AND bundle_id IS NOT NULL
                     AND imp_without_tax > 0.0
               
               QUALIFY ROW_NUMBER() OVER (
                                         PARTITION BY data_month_id, phone_nm, brand_ds, service_type
                                         ORDER BY service_id DESC, movement_date DESC, CAST(imp_without_tax AS STRING) DESC
                                         ) = 1
               ) BILLING
              ON TRANSACCIONES.phone_nm = CAST(BILLING.phone_nm AS STRING) AND TRANSACCIONES.marca = BILLING.brand_ds
                 AND TRANSACCIONES.service_type = BILLING.service_type

     LEFT JOIN `mm-datamart-kd.SERVICES.service_base_telco` SERVICE_BASE_TELCO
              ON TRANSACCIONES.phone_nm = CAST(SERVICE_BASE_TELCO.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = SERVICE_BASE_TELCO.comm_brand_ds
                 AND DATE_TRUNC(SERVICE_BASE_TELCO.activation_date, MONTH) BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin

     LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES_DETALLE
              ON TRANSACCIONES.commission_id = TRANSACCIONES_DETALLE.commission_id

     LEFT JOIN (
               SELECT A.service_id, B.main_mobile_tariff_id, B.main_mobile_tariff_name, T.tramo_1 AS comision, A.phone_nm, A.marca, F.data_month_id

               FROM `mm-commissions-reporting.COMISIONES.activaciones` A
               
               LEFT JOIN `mm-datamart-kd.BILLING.billing_detail_emysim` F
                  ON A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds /*AND A.id_mes = F.data_month_id AND A.tariff_id = F.tariff_id*/
   
               LEFT JOIN `mm-commissions-reporting.TEMP.disgregacion_bundles_exc` B
                  ON B.bundle_id = F.bundle_id 
               
               LEFT JOIN (SELECT * EXCEPT(creado, creado_por) FROM `mm-commissions-reporting.COMISIONES.tarifas` GROUP BY ALL) T
                  ON T.tariff_id = B.main_mobile_tariff_id    
               
               WHERE 1= 1 
                    AND F.tariff_id IN ('8205','8212','7108','7115','8145')
                    AND A.agrupacion_canal = 'Exclusivo'
                    AND A.canal = 'ENK'
                    AND F.data_month_id = id_mes_pr
                    AND F.concept_type_ds = 'Cuotas'
                    AND A.service_id NOT IN (SELECT service_id FROM `mm-commissions-reporting.TEMP.compartidas_gratuitas_exc` ) -- LA TABLA DE COMPARTIDAS GRATUITAS DEBE HABER SIDO LANZADA EN EL ID_MES_PR
                    AND T.canal = 'ENK'
                    AND T.id_mes = id_mes_pr
               QUALIFY ROW_NUMBER() OVER(PARTITION BY F.phone_nm ORDER BY DATE_DIFF(end_date,init_date,DAY) DESC) = 1
               ) COMPARTIDAS_COSTE
              ON  COMPARTIDAS_COSTE.phone_nm = TRANSACCIONES.phone_nm AND COMPARTIDAS_COSTE.marca = TRANSACCIONES.marca

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
     
               WHERE id_mes = id_mes_periodo_facturado_fin
                     AND canal IN ('ECI', 'EDB', 'EML', 'ENX', 'ENK', 'EYG', 'MP')
                     AND comision > 0.0
     
               QUALIFY ROW_NUMBER() OVER (PARTITION BY canal, marca,service_type, tariff_id, COALESCE(line_type_ds, 'L') ORDER BY id_mes ASC,creado DESC) = 1
               ) TARIFAS
              ON TRANSACCIONES.marca = TARIFAS.marca
                 AND TRANSACCIONES.service_type = TARIFAS.service_type
                 AND BILLING.tariff_id = TARIFAS.tariff_id
                 AND TRANSACCIONES_DETALLE.canal = TARIFAS.canal
                 AND COALESCE(SERVICE_BASE_TELCO.line_type_ds, 'L') = COALESCE(TARIFAS.line_type_ds, TRANSACCIONES_DETALLE.line_type_ds, 'L')
          
     LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
              ON UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)]) = DEALER.sfid_id
                 AND TRANSACCIONES_DETALLE.agrupacion_canal = DEALER.agrupacion_canal
                 AND LENGTH(UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)])) > 2
    
     LEFT JOIN (
               SELECT *
               FROM `mm-datamart-kd.SERVICES.campaign_base_emysim`
               WHERE campaign_category_name = 'TRY & BUY TARIFA'
                     AND DATE_DIFF(DATE(end_date_ts), DATE(init_date_ts), DAY) <= 30
               ) CAMPAIGN_TARIFA
              ON TRANSACCIONES_DETALLE.phone_nm = CAST(CAMPAIGN_TARIFA.phone_nm AS STRING)
                 AND TRANSACCIONES_DETALLE.marca = CAMPAIGN_TARIFA.brand_ds
                 AND TRANSACCIONES_DETALLE.activation_date BETWEEN DATE(CAMPAIGN_TARIFA.init_date_ts) AND DATE(CAMPAIGN_TARIFA.end_date_ts)
    
     LEFT JOIN (SELECT *
              FROM `mm-commissions-reporting.COMISIONES.transacciones`
              WHERE id_mes BETWEEN id_mes_periodo_facturado_cambio AND id_mes_pr
              AND SUBSTR(concepto, 5) LIKE 'Clawback Servicio Movil Pospago'
             ) CLAWBACKS
           ON TRANSACCIONES.phone_nm = CLAWBACKS.phone_nm
           AND TRANSACCIONES.marca = CLAWBACKS.marca
           AND TRANSACCIONES.activation_date = CLAWBACKS.activation_date
           AND '"'||TRANSACCIONES.commission_id||'"' = CLAWBACKS.process_code 

     WHERE TRANSACCIONES.phone_nm IS NOT NULL
           AND TRANSACCIONES.tariff_id != BILLING.tariff_id
           AND DEALER.comisiona
           AND DEALER.id_comisionista NOT LIKE 'DBL%'
           AND TRANSACCIONES.service_type = 'MOBILE'
           AND DEALER.canal = 'EML'
           AND CLAWBACKS.phone_nm IS NULL
     
     QUALIFY RANK() OVER (
                         PARTITION BY TRANSACCIONES.commission_id
                         ORDER BY BILLING.data_month_id DESC,
                                  SERVICE_BASE_TELCO.activation_date DESC,
                                  COALESCE(SERVICE_BASE_TELCO.deactivation_date, '9999-12-31') DESC,
                                  SERVICE_BASE_TELCO.service_id DESC,
                                  /*CASE WHEN CAMPAIGN_FIBRA.user_profile_role = 'GENERICO' THEN 2 ELSE 1 END ASC, */ -- JOHANNA: RELACIONADO A PREGUNTA LÍNEA 441
                                  CASE WHEN CAMPAIGN_TARIFA.user_profile_role = 'GENERICO' THEN 2 ELSE 1 END ASC,
                                  CAMPAIGN_TARIFA.subscriptioncampaignid ASC
                                  
                         ) = 1
     )
)
)
;



IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = "tbex_sin_filtro") = 0
THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tbex_sin_filtro` CLUSTER BY mes_liquidado OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS SELECT * FROM tbex_sin_filtro;

ELSE
INSERT INTO `mm-commissions-reporting.TEMP.tbex_sin_filtro` (SELECT * FROM tbex_sin_filtro);
END IF;


END WHILE;


/* Se ejecuta el proceso en modo estándar */
IF ajuste = 0

THEN

SET prefijo = 'TBEXC';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tbex` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      prefijo || 'R_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal
--      ,concepto

     ,CASE 
          WHEN canal != 'ENK' AND concepto = 'A - Servicio Fijo'                        THEN 'P - Cambio Tarifa Fijo 3M Recalculo'
          WHEN canal != 'ENK' AND concepto = 'A - Servicio Fijo Cambio de Domicilio'    THEN 'P - Cambio Tarifa Fijo CD 3M Recalculo' 
          WHEN canal != 'ENK' AND concepto = 'A - Servicio Fijo Cambio de Tecnologia'   THEN 'P - Cambio Tarifa Fijo CT 3M Recalculo' 
          WHEN canal != 'ENK' AND concepto = 'A - Servicio Movil Pospago'               THEN 'P - Cambio Tarifa Movil 1M Recalculo'
          WHEN canal  = 'ENK' AND concepto = 'A - Servicio Fijo'                        THEN 'P - Cambio Tarifa Fijo 150d Recalculo'
          WHEN canal  = 'ENK' AND concepto = 'A - Servicio Fijo 2da Vivienda'           THEN 'P - Cambio Tarifa Fijo 2da Vivienda 150d Recalculo'
          WHEN canal  = 'ENK' AND concepto = 'A - Servicio Fijo Cambio de Domicilio'    THEN 'P - Cambio Tarifa Fijo CD 150d Recalculo'
          
           
      END AS concepto

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
     
     ,CASE 
          WHEN huella = 'INDIRECTA' THEN 'Huella indirecta'
          ELSE CAST(NULL AS STRING)  
      END AS comments
     
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.tbex_sin_filtro`

WHERE comision_original != comision_actualizada

UNION ALL

SELECT
      prefijo || 'D_' || mes_string || '_' || TBEX.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,TBEX.mes_liquidado
     ,TBEX.id_mes
     ,TBEX.agrupacion_canal
     ,TBEX.canal
--      ,TBEX.concepto

     ,CASE 
          WHEN TBEX.canal != 'ENK' AND TBEX.concepto = 'A - Servicio Fijo'                        THEN 'P - Cambio Tarifa Fijo 3M Deduccion'
          WHEN TBEX.canal != 'ENK' AND TBEX.concepto = 'A - Servicio Fijo Cambio de Domicilio'    THEN 'P - Cambio Tarifa Fijo CD 3M Deduccion' 
          WHEN TBEX.canal != 'ENK' AND TBEX.concepto = 'A - Servicio Fijo Cambio de Tecnologia'   THEN 'P - Cambio Tarifa Fijo CT 3M Deduccion' 
          WHEN TBEX.canal != 'ENK' AND TBEX.concepto = 'A - Servicio Movil Pospago'               THEN 'P - Cambio Tarifa Movil 1M Deduccion' 
          WHEN TBEX.canal  = 'ENK' AND TBEX.concepto = 'A - Servicio Fijo'                        THEN 'P - Cambio Tarifa Fijo 150d Deduccion'
          WHEN TBEX.canal  = 'ENK' AND TBEX.concepto = 'A - Servicio Fijo 2da Vivienda'           THEN 'P - Cambio Tarifa Fijo 2da Vivienda 150d Deduccion'
          WHEN TBEX.canal  = 'ENK' AND TBEX.concepto = 'A - Servicio Fijo Cambio de Domicilio'    THEN 'P - Cambio Tarifa Fijo CD 150d Deduccion' 
      END AS concepto

     ,'UPFR' AS tipo_concepto
     ,1 as unidades
     ,TBEX.comision_original * -1 AS comision
     ,TBEX.id_comisionista
     ,TBEX.distribuidor
     ,TBEX.sfid_id
     ,TBEX.seller
     ,TBEX.nombre_comercio
     ,TBEX.razon_social
     ,TBEX.cif
     ,TBEX.zona_fiscal
     ,TBEX.marca
     ,TBEX.service_type
     ,TBEX.phone_nm
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
     ,TBEX.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,TBEX.process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.tbex_sin_filtro` TBEX

LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
         ON REPLACE(TBEX.process_code, '"', '') = TRANSACCIONES.commission_id

WHERE comision_original != comision_actualizada
)
;

-- VALIDACIÓN DUPLICADOS
ASSERT NOT EXISTS
(
SELECT *
FROM `mm-commissions-reporting.TEMP.tbex` 
WHERE 1 = 1
QUALIFY COUNT(phone_nm) OVER(PARTITION BY phone_nm, concepto) > 1
) AS 'Hay duplicados en el cálculo'
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.tbex), 'TEMP.tbex', 'ACTUALIZAR');

END IF;


/* Se ejecuta el proceso en modo ajuste. Se generan automáticamente el ajuste y la retrotracción */
/*
IF ajuste = 1

THEN

SET prefijo = 'TBEXAJ';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tbex` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
SELECT
      prefijo || 'R_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_liquidado
     ,id_mes
     ,agrupacion_canal
     ,canal
     ,concepto
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

     ,CASE 
          WHEN huella = 'INDIRECTA' THEN 'Huella indirecta'
          ELSE CAST(NULL AS STRING)  
      END AS comments
     
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.tbex_sin_filtro`

WHERE comision_original != comision_actualizada

UNION ALL

SELECT
      prefijo || 'D_' || mes_string || '_' || TBEX.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,TBEX.mes_liquidado
     ,TBEX.id_mes
     ,TBEX.agrupacion_canal
     ,TBEX.canal
     ,TBEX.concepto
     ,'UPFR' AS tipo_concepto
     ,1 as unidades
     ,TBEX.comision_original * -1 AS comision
     ,TBEX.id_comisionista
     ,TBEX.distribuidor
     ,TBEX.sfid_id
     ,TBEX.seller
     ,TBEX.nombre_comercio
     ,TBEX.razon_social
     ,TBEX.cif
     ,TBEX.zona_fiscal
     ,TBEX.marca
     ,TBEX.service_type
     ,TBEX.phone_nm
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
     ,TBEX.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,TBEX.process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.tbex_sin_filtro` TBEX

LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
         ON REPLACE(TBEX.process_code, '"', '') = TRANSACCIONES.commission_id

WHERE comision_original != comision_actualizada

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
     
LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER
         ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista
            AND BILLING.agrupacion_canal = DEALER.agrupacion_canal

WHERE TRANSACCIONES.agrupacion_canal = 'Exclusivo'
      AND mes_liquidado BETWEEN PARSE_DATE('%Y%m', CAST(mes_inicio AS STRING)) AND PARSE_DATE('%Y%m', CAST(mes_fin AS STRING))
      AND estado = 'facturado'
      AND commission_id LIKE 'TBEX%'
      AND DEALER.comisiona
)
;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.tbex), 'TEMP.tbex', 'ACTUALIZAR');

END IF;
*/

END