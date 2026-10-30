BEGIN


/*
CALL COMISIONES.pr_ajuste_semestral_DO (202607, NULL, NULL, 0);
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
IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = 'ajuste_semestral_sin_filtro') > 0
THEN DROP TABLE `mm-commissions-reporting.TEMP.ajuste_semestral_sin_filtro`;
END IF;


WHILE m < ARRAY_LENGTH(meses) DO -- Bucle mes

/* Contador bucle mes */
SET m = m + 1;

SET mes_periodo_facturado_fin = meses[ORDINAL(m)];
SET id_mes_periodo_facturado_fin = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado_fin) AS INT64);
SET mes_periodo_facturado_ini = DATE_ADD(meses[ORDINAL(m)], INTERVAL  - 6 MONTH);
SET id_mes_periodo_facturado_ini = CAST(FORMAT_DATE('%Y%m',  mes_periodo_facturado_ini ) AS INT64);


/* Extraemos las líneas de Billing para el periodo deseado */

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ajuste_semestral_billing` AS

(
  SELECT 
      phone_nm
      ,brand_ds
      ,CASE WHEN service_type = 'BROADBAND' THEN 'INTERNET' ELSE service_type END AS service_type
      ,tariff_id
      ,tariff_ds
      ,bundle_id
      ,bundle_name
      ,SUM(days) as days
      ,MAX(data_month_id) as month
      ,cnt_months
                
  FROM (
            SELECT 
                  phone_nm
                  ,brand_ds
                  ,service_type
                  ,CASE WHEN service_type = 'MOBILE' THEN tariff_id ELSE bundle_id END AS tariff_id
                  ,CASE WHEN service_type = 'MOBILE' THEN tariff_ds ELSE bundle_name END AS tariff_ds
                  ,bundle_id
                  ,bundle_name
      
                  ,CASE 
                        WHEN data_month = DATE_ADD(mes_periodo_facturado_ini, INTERVAL 7 MONTH) 
                           AND init_date BETWEEN mes_periodo_facturado_ini AND LAST_DAY(DATE_ADD(mes_periodo_facturado_ini, INTERVAL 6 MONTH)) 
                        THEN DATE_DIFF(LAST_DAY(init_date), init_date, DAY)
                        ELSE DATE_DIFF(end_date, init_date, DAY) 
                   END AS days
      
                  ,data_month_id
                  ,COUNT(DISTINCT DATE_TRUNC(end_date,MONTH)) OVER (PARTITION BY phone_nm, brand_ds,service_type) AS cnt_months
      
            FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
            WHERE 1=1
                  AND data_month BETWEEN mes_periodo_facturado_ini AND DATE_ADD(mes_periodo_facturado_ini, INTERVAL 6 MONTH) 
                  AND concept_type_ds IN ('Cuotas')
                  AND service_type IN ('INTERNET', 'MOBILE', 'BROADBAND')
                  AND brand_ds IN ('MASMOVIL', 'YOIGO')
                  AND bundle_id IS NOT NULL
                  AND phone_nm IS NOT NULL
                  AND imp_without_tax > 0.0 
            GROUP BY service_type,tariff_id,tariff_ds,data_month,mes_periodo_facturado_ini,init_date,end_date,phone_nm,brand_ds,data_month_id,bundle_id, bundle_name
            )
  WHERE cnt_months >= CASE WHEN brand_ds = 'MASMOVIL' THEN 7 ELSE 6 END
  GROUP BY ALL
  QUALIFY ROW_NUMBER() OVER (
                            PARTITION BY phone_nm, brand_ds
                            ORDER BY days DESC, month DESC
                            ) = 1
)
;

CREATE OR REPLACE TEMPORARY TABLE ajuste_semestral_sin_filtro AS
(
( -- SERVICIO FIJO
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
          ,BILLING.tariff_ds         
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
               WHEN TRANSACCIONES.concepto LIKE '%2da Vivienda%' THEN TARIFAS.traslados
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
                    ,concepto
                    ,MAX(tariff_ds) AS tariff_ds
                    ,MIN(activation_date) AS activation_date
                    ,MIN(deactivation_date) AS deactivation_date
                    ,id_mes
                    ,MIN(commission_id) AS commission_id
                    ,ARRAY_AGG(commission_id) AS process_code
                  --   ,SUM(CASE WHEN concepto LIKE 'P%' THEN 1 ELSE 0 END) AS penalizacion
                  --   ,SUM(CASE WHEN UPPER(comments) LIKE '%INTRAGRUPO%' THEN 1 ELSE 0 END) AS penalizacion_intragrupo
                    ,SUM(comision) AS comision
               
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE agrupacion_canal = 'TLV - DO'
                     AND (
                         (
                         mes_liquidado = mes_periodo_facturado_ini
                         AND concepto IN ('A - Servicio Fijo Cambio de Domicilio', 'A - Servicio Fijo Cambio de Tecnologia', 'A - Servicio Fijo', 'A - Servicio Fijo 2da Vivienda', 'Z - Servicio Fijo 2da Vivienda')
                         )
                         OR
                         (
                         mes_liquidado BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin
                         AND (/*commission_id NOT LIKE 'TBEX%' AND*/ estado = 'calculado')
                         AND concepto IN (
                              'E - Clawback Servicio Fijo Cambio de Domicilio'
                             ,'E - Clawback Servicio Fijo Cambio de Tecnologia'
                             ,'P - Servicio Fijo Cambio de Domicilio'
                             ,'P - Servicio Servicio Fijo Cambio de Tecnologia'
                             ,'Z - Clawback Servicio Fijo Cambio de Domicilio'
                             ,'Z - Clawback Servicio Fijo Cambio de Tecnologia'
                             ,'Z - Servicio Fijo Cambio de Domicilio'
                             ,'Z - Servicio Fijo Cambio de Tecnologia'
                             ,'E - Clawback Servicio Fijo'
                             ,'E - Clawback Servicio Fijo 2da Vivienda'
                             ,'P - Servicio Fijo'
                             ,'P - Servicio Fijo 2da Vivienda'
                             ,'Z - Clawback Servicio Fijo'
                             ,'Z - Clawback Servicio Fijo 2da Vivienda'
                             ,'Z - Servicio Fijo'
                             ,'Z - Servicio Fijo 2da Vivienda'
                             )
                         )
                         )
               
               GROUP BY 1,2,3,4,5,6,10
               )
          
          WHERE comision > 0.0
                -- AND (penalizacion = 0 OR (penalizacion = 1 AND penalizacion_intragrupo = 1))
                AND DATE_TRUNC(activation_date, MONTH) = mes_periodo_facturado_ini
                AND deactivation_date = '9999-12-31'
          QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm, marca, service_type
                                     ORDER BY id_mes DESC
                                    ) = 1
          ) TRANSACCIONES
     
     LEFT JOIN `mm-commissions-reporting.TEMP.ajuste_semestral_billing` BILLING
              ON TRANSACCIONES.phone_nm = CAST(BILLING.phone_nm AS STRING) 
                 AND TRANSACCIONES.marca = BILLING.brand_ds
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
                    ,traslados
               
               FROM `mm-commissions-reporting.COMISIONES.v_tarifas`
               UNPIVOT (comision FOR tramo IN (tramo_1, tramo_2, tramo_3, tramo_4, tramo_5))
     
               WHERE id_mes = id_mes_periodo_facturado_fin
                     AND canal IN ('DO')
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
          
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
            --   ON UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)]) = DEALER.sfid_id
            ON SERVICE_BASE_TELCO.sfid_id = DEALER.SFID_ID
                 AND TRANSACCIONES_DETALLE.agrupacion_canal = DEALER.agrupacion_canal
            --      AND LENGTH(UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)])) > 2 

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

     WHERE TRANSACCIONES.phone_nm IS NOT NULL
           AND VELOCIDAD_VENTA.technology||' '||VELOCIDAD_VENTA.internet_speed != VELOCIDAD_BILLING.technology||' '||VELOCIDAD_BILLING.internet_speed
           AND DEALER.comisiona
           AND TRANSACCIONES.service_type = 'INTERNET'
     
     QUALIFY RANK() OVER (
                         PARTITION BY TRANSACCIONES.commission_id
                         ORDER BY /*BILLING.data_month_id DESC,*/
                                  SERVICE_BASE_TELCO.activation_date DESC,
                                  COALESCE(SERVICE_BASE_TELCO.deactivation_date, '9999-12-31') DESC,
                                  SERVICE_BASE_TELCO.service_id DESC
                         ) = 1
     )
)

UNION ALL

-- SERVICIO MÓVIL
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
               WHEN TRANSACCIONES_DETALLE.canal = 'DO' AND BILLING.tariff_id IN ('8205','8212','7108','7115','8145') THEN COMPARTIDAS_COSTE.comision
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
                    ,concepto
                    ,MAX(tariff_ds) AS tariff_ds
                    ,MIN(activation_date) AS activation_date
                    ,MIN(deactivation_date) AS deactivation_date
                    ,MIN(commission_id) AS commission_id
                    ,ARRAY_AGG(commission_id) AS process_code
                  --   ,SUM(CASE WHEN concepto LIKE 'P%' THEN 1 ELSE 0 END) AS penalizacion
                  --   ,SUM(CASE WHEN UPPER(comments) LIKE '%INTRAGRUPO%' THEN 1 ELSE 0 END) AS penalizacion_intragrupo
                    ,SUM(comision) AS comision
               
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE agrupacion_canal = 'TLV - DO'
                     AND (
                         (
                         mes_liquidado = mes_periodo_facturado_ini
                         AND concepto IN ('A - Servicio Movil Pospago') 
                         )
                         OR
                         (
                         mes_liquidado BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin
                         AND (/*commission_id NOT LIKE 'TBEX%' AND*/ estado = 'calculado')
                         AND concepto IN (
                              'E - Clawback Servicio Movil Pospago'
                             ,'P - Servicio Movil Pospago'
                             ,'Z - Clawback Servicio Movil Pospago'
                             ,'Z - Servicio Movil Pospago'
                             )
                         )
                         )
               
               GROUP BY 1,2,3,4,5,6
               )
          
          WHERE comision > 0.0
            --     AND (penalizacion = 0 OR (penalizacion = 1 AND penalizacion_intragrupo = 1))
                AND DATE_TRUNC(activation_date, MONTH) = mes_periodo_facturado_ini
                AND deactivation_date = '9999-12-31'
          ) TRANSACCIONES
     
     LEFT JOIN `mm-commissions-reporting.TEMP.ajuste_semestral_billing` BILLING
              ON TRANSACCIONES.phone_nm = CAST(BILLING.phone_nm AS STRING) 
                 AND TRANSACCIONES.marca = BILLING.brand_ds
                 AND TRANSACCIONES.service_type = BILLING.service_type

     LEFT JOIN `mm-datamart-kd.SERVICES.service_base_telco` SERVICE_BASE_TELCO
              ON TRANSACCIONES.phone_nm = CAST(SERVICE_BASE_TELCO.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = SERVICE_BASE_TELCO.comm_brand_ds
                 AND DATE_TRUNC(SERVICE_BASE_TELCO.activation_date, MONTH) BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin

     LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES_DETALLE
              ON TRANSACCIONES.commission_id = TRANSACCIONES_DETALLE.commission_id

     LEFT JOIN (
               SELECT A.service_id, B.main_mobile_tariff_id, B.main_mobile_tariff_name, T.tramo_1 AS comision, A.phone_nm, A.marca, A.activation_date

               FROM `mm-commissions-reporting.COMISIONES.activaciones` A
               
               LEFT JOIN `mm-commissions-reporting.TEMP.ajuste_semestral_billing` F
                  ON A.phone_nm = CAST(F.phone_nm AS STRING) AND A.brand_ds = F.brand_ds
   
               LEFT JOIN `mm-commissions-reporting.TEMP.disgregacion_bundles_exc` B
                  ON B.bundle_id = F.bundle_id 
               
               LEFT JOIN (SELECT * EXCEPT(creado, creado_por) FROM `mm-commissions-reporting.COMISIONES.tarifas` GROUP BY ALL QUALIFY ROW_NUMBER() OVER (PARTITION BY canal,id_mes,marca,tariff_id,tariff_ds,/*line_type_ds,*/CAST(tramo_1 AS STRING)) = 1) T
                  ON T.tariff_id = B.main_mobile_tariff_id    
               
               WHERE 1= 1 
                    AND (
                          F.tariff_id IN ('8205','8212','7108','7115','8145')
                          OR
                          F.tariff_id = '7126' AND A.activation_date >= '2026-01-22'
                        )
                    AND A.agrupacion_canal = 'TLV - DO'
                    AND A.canal = 'DO'
                    AND A.order_type_agg != 'MIGRACION CONTRATO'
                    AND A.service_id NOT IN (SELECT service_id FROM `mm-commissions-reporting.TEMP.compartidas_gratuitas_exc` ) -- LA TABLA DE COMPARTIDAS GRATUITAS DEBE HABER SIDO LANZADA EN EL ID_MES_PR
                    AND T.canal = 'DO'
                    AND T.id_mes = id_mes_pr
               ) COMPARTIDAS_COSTE
              ON  COMPARTIDAS_COSTE.phone_nm = TRANSACCIONES.phone_nm AND COMPARTIDAS_COSTE.marca = TRANSACCIONES.marca AND COMPARTIDAS_COSTE.activation_date = TRANSACCIONES.activation_date

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
                     AND canal IN ('DO')
                     AND comision > 0.0
     
               QUALIFY ROW_NUMBER() OVER (PARTITION BY canal, marca,service_type, tariff_id, COALESCE(line_type_ds, 'L') ORDER BY id_mes ASC,creado DESC) = 1
               ) TARIFAS
              ON TRANSACCIONES.marca = TARIFAS.marca
                 AND TRANSACCIONES.service_type = TARIFAS.service_type
                 AND BILLING.tariff_id = TARIFAS.tariff_id
                 AND TRANSACCIONES_DETALLE.canal = TARIFAS.canal
                 AND COALESCE(SERVICE_BASE_TELCO.line_type_ds, 'L') = COALESCE(TARIFAS.line_type_ds, TRANSACCIONES_DETALLE.line_type_ds, 'L')
          
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
            --   ON UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)]) = DEALER.sfid_id
            ON SERVICE_BASE_TELCO.sfid_id = DEALER.SFID_ID
                 AND TRANSACCIONES_DETALLE.agrupacion_canal = DEALER.agrupacion_canal
            --      AND LENGTH(UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)])) > 2
     

    
     WHERE TRANSACCIONES.phone_nm IS NOT NULL
           AND TRANSACCIONES.tariff_id != BILLING.tariff_id
           AND DEALER.comisiona
           AND TRANSACCIONES.service_type = 'MOBILE'
     
     QUALIFY RANK() OVER (
                         PARTITION BY TRANSACCIONES.commission_id
                         ORDER BY /*BILLING.data_month_id DESC,*/
                                  SERVICE_BASE_TELCO.activation_date DESC,
                                  COALESCE(SERVICE_BASE_TELCO.deactivation_date, '9999-12-31') DESC,
                                  SERVICE_BASE_TELCO.service_id DESC                                  
                         ) = 1
     )
)

UNION ALL

-- DISPOSITIVO FINANCIADO
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
          ,CAST(null AS STRING) AS velocidad_original
          ,BILLING.bundle_id
          ,BILLING.bundle_name          
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

          ,`mm-commissions-reporting.COMISIONES.f_comision_financiaciones`(
                                                                           DEALER.canal
                                                                           ,TRANSACCIONES.marca
                                                                           ,1
                                                                           ,TRANSACCIONES_DETALLE.bundle_type
                                                                           ,PVP_BUNDLES.bundle_pre_tax_amount
                                                                          ) AS comision_actualizada
          
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
                    ,id_mes
                    ,MIN(commission_id) AS commission_id
                    ,ARRAY_AGG(commission_id) AS process_code
                    ,SUM(comision) AS comision
               
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE agrupacion_canal = 'TLV - DO'
                     AND (
                         (
                         mes_liquidado = mes_periodo_facturado_ini
                         AND concepto IN ('D - Dispositivo Financiado')
                         )
                         OR
                         (
                         mes_liquidado BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin
                         AND estado = 'calculado'
                         AND concepto IN (
                              'E - Clawback Dispositivo Financiado'
                             ,'Z - Clawback Dispositivo Financiado'
                             ,'Z - Dispositivo Financiado'
                             )
                         )
                         )
               
               GROUP BY 1,2,3,4,5,6,10
               )
          
          WHERE comision > 0.0
                AND DATE_TRUNC(activation_date, MONTH) = mes_periodo_facturado_ini
                AND deactivation_date = '9999-12-31'
          QUALIFY ROW_NUMBER() OVER (
                                     PARTITION BY phone_nm, marca, service_type
                                     ORDER BY id_mes DESC
                                    ) = 1
          ) TRANSACCIONES
     
     LEFT JOIN (
                SELECT 
                      phone_nm
                      ,brand_ds
                      ,service_type
                      ,bundle_id
                      ,bundle_name
                      ,SUM(days) as days
                      ,MAX(data_month_id) as month
                      ,cnt_months
                
                FROM (
                      SELECT 
                            phone_nm
                            ,brand_ds
                            ,service_type
                            ,bundle_id
                            ,bundle_name
                
                            ,CASE 
                                  WHEN data_month = DATE_ADD(mes_periodo_facturado_ini, INTERVAL 7 MONTH) 
                                     AND init_date BETWEEN mes_periodo_facturado_ini AND LAST_DAY(DATE_ADD(mes_periodo_facturado_ini, INTERVAL 6 MONTH)) 
                                  THEN DATE_DIFF(LAST_DAY(init_date), init_date, DAY)
                                  ELSE DATE_DIFF(end_date, init_date, DAY) 
                             END AS days
                
                            ,data_month_id
                            ,COUNT(DISTINCT DATE_TRUNC(end_date,MONTH)) OVER (PARTITION BY phone_nm, brand_ds,service_type) AS cnt_months
                
                      FROM `mm-datamart-kd.BILLING.billing_detail_emysim`
                      WHERE 1=1
                            AND data_month BETWEEN mes_periodo_facturado_ini AND DATE_ADD(mes_periodo_facturado_ini, INTERVAL 6 MONTH) 
                            AND concept_type_ds IN ('Cuotas')
                            AND service_type IN ('INTERNET', 'MOBILE')
                            AND brand_ds IN ('MASMOVIL', 'YOIGO')
                            AND bundle_id IS NOT NULL
                            AND phone_nm IS NOT NULL
                            AND imp_without_tax > 0.0 
                      GROUP BY service_type,bundle_id,bundle_name,data_month,mes_periodo_facturado_ini,init_date,end_date,phone_nm,brand_ds,data_month_id
                      )
                WHERE cnt_months >= CASE WHEN brand_ds = 'MASMOVIL' THEN 7 ELSE 6 END
                GROUP BY ALL
                QUALIFY ROW_NUMBER() OVER (
                                           PARTITION BY phone_nm, brand_ds
                                           ORDER BY days DESC, month DESC
                                           ) = 1
               ) BILLING
              ON TRANSACCIONES.phone_nm = CAST(BILLING.phone_nm AS STRING) AND TRANSACCIONES.marca = BILLING.brand_ds
                 AND TRANSACCIONES.service_type = BILLING.service_type

     LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES_DETALLE
              ON TRANSACCIONES.commission_id = TRANSACCIONES_DETALLE.commission_id

     LEFT JOIN  `mm-commissions-reporting.TEMP.pvp_bundles` PVP_BUNDLES
          ON PVP_BUNDLES.bundle_id = BILLING.bundle_id
          
     LEFT JOIN `mm-datamart-kd.SERVICES.service_base_telco` SERVICE_BASE_TELCO
              ON TRANSACCIONES.phone_nm = CAST(SERVICE_BASE_TELCO.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = SERVICE_BASE_TELCO.comm_brand_ds
                 AND DATE_TRUNC(SERVICE_BASE_TELCO.activation_date, MONTH) BETWEEN mes_periodo_facturado_ini AND mes_periodo_facturado_fin
          
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
            --   ON UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)]) = DEALER.sfid_id
            ON SERVICE_BASE_TELCO.sfid_id = DEALER.SFID_ID
                 AND TRANSACCIONES_DETALLE.agrupacion_canal = DEALER.agrupacion_canal
            --      AND LENGTH(UPPER(SPLIT(SERVICE_BASE_TELCO.sell_agent_ds, "@")[OFFSET(0)])) > 2 

     LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` VENTAS
              ON TRANSACCIONES.phone_nm = CAST(VENTAS.phone_nm AS STRING)
                 AND TRANSACCIONES.marca = VENTAS.brand_ds
                 AND TRANSACCIONES.activation_date = VENTAS.activation_date
                 AND SERVICE_BASE_TELCO.service_id = VENTAS.service_id

     WHERE TRANSACCIONES.phone_nm IS NOT NULL
           AND TRANSACCIONES.tariff_id != BILLING.bundle_id
           AND DEALER.comisiona
           AND TRANSACCIONES.service_type = 'MOBILE'
           
     
     QUALIFY RANK() OVER (
                         PARTITION BY TRANSACCIONES.commission_id
                         ORDER BY /*BILLING.data_month_id DESC,*/
                                  SERVICE_BASE_TELCO.activation_date DESC,
                                  COALESCE(SERVICE_BASE_TELCO.deactivation_date, '9999-12-31') DESC,
                                  SERVICE_BASE_TELCO.service_id DESC
                         ) = 1
     )
)
)
;



IF (SELECT COUNT(*) AS cnt FROM `mm-commissions-reporting.TEMP.INFORMATION_SCHEMA.TABLES` WHERE table_name = "ajuste_semestral_sin_filtro") = 0
THEN
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ajuste_semestral_sin_filtro` CLUSTER BY mes_liquidado OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS SELECT * FROM ajuste_semestral_sin_filtro;

ELSE
INSERT INTO `mm-commissions-reporting.TEMP.ajuste_semestral_sin_filtro` (SELECT * FROM ajuste_semestral_sin_filtro);
END IF;


END WHILE;


/* Se ejecuta el proceso en modo estándar */
IF ajuste = 0

THEN

SET prefijo = 'AJSEM';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ajuste_semestral` 
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
          WHEN concepto = 'A - Servicio Fijo'                        THEN 'P - Servicio Fijo 6M Recalculo'
          WHEN concepto = 'A - Servicio Fijo 2da Vivienda'           THEN 'P - Servicio Fijo 2da Vivienda 6M Recalculo'
          WHEN concepto = 'Z - Servicio Fijo 2da Vivienda'           THEN 'P - Servicio Fijo 2da Vivienda 6M Recalculo'
          WHEN concepto = 'A - Servicio Fijo Cambio de Domicilio'    THEN 'P - Servicio Fijo CD 6M Recalculo' 
          WHEN concepto = 'A - Servicio Fijo Cambio de Tecnologia'   THEN 'P - Servicio Fijo CT 6M Recalculo' 
          WHEN concepto = 'A - Servicio Movil Pospago'               THEN 'P - Servicio Movil 6M Recalculo' 
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
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.ajuste_semestral_sin_filtro`

WHERE comision_original != comision_actualizada

UNION ALL

SELECT
      prefijo || 'D_' || mes_string || '_' || AJSM.canal || '_' || ROW_NUMBER() OVER () AS commission_id
     ,'calculado' AS estado
     ,AJSM.mes_liquidado
     ,AJSM.id_mes
     ,AJSM.agrupacion_canal
     ,AJSM.canal

     ,CASE 
          WHEN AJSM.concepto = 'A - Servicio Fijo'                        THEN 'P - Servicio Fijo 6M Deduccion'
          WHEN AJSM.concepto = 'A - Servicio Fijo 2da Vivienda'           THEN 'P - Servicio Fijo 2da Vivienda 6M Deduccion'
          WHEN AJSM.concepto = 'Z - Servicio Fijo 2da Vivienda'           THEN 'P - Servicio Fijo 2da Vivienda 6M Deduccion'
          WHEN AJSM.concepto = 'A - Servicio Fijo Cambio de Domicilio'    THEN 'P - Servicio Fijo CD 6M Deduccion' 
          WHEN AJSM.concepto = 'A - Servicio Fijo Cambio de Tecnologia'   THEN 'P - Servicio Fijo CT 6M Deduccion' 
          WHEN AJSM.concepto = 'A - Servicio Movil Pospago'               THEN 'P - Servicio Movil 6M Deduccion' 
      END AS concepto

     ,'UPFR' AS tipo_concepto
     ,1 as unidades
     ,AJSM.comision_original * -1 AS comision
     ,AJSM.id_comisionista
     ,AJSM.distribuidor
     ,AJSM.sfid_id
     ,AJSM.seller
     ,AJSM.nombre_comercio
     ,AJSM.razon_social
     ,AJSM.cif
     ,AJSM.zona_fiscal
     ,AJSM.marca
     ,AJSM.service_type
     ,AJSM.phone_nm
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
     ,AJSM.cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,AJSM.process_code
     ,CAST(NULL AS STRING)  AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.ajuste_semestral_sin_filtro` AJSM

LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
         ON REPLACE(AJSM.process_code, '"', '') = TRANSACCIONES.commission_id

WHERE comision_original != comision_actualizada
)
;

-- VALIDACIÓN DUPLICADOS
ASSERT NOT EXISTS
(
SELECT *
FROM `mm-commissions-reporting.TEMP.ajuste_semestral` 
WHERE 1 = 1
QUALIFY COUNT(phone_nm) OVER(PARTITION BY phone_nm, concepto) > 1
) AS 'Hay duplicados en el cálculo'
;

-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.ajuste_semestral), 'TEMP.ajuste_semestral', 'ACTUALIZAR'); DESCOMENTAR

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
     ,CAST(NULL AS STRING) AS comments    
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.ajuste_semestral_sin_filtro`

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

FROM `mm-commissions-reporting.TEMP.ajuste_semestral_sin_filtro` TBEX

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
     
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista
            AND BILLING.agrupacion_canal = DEALER.agrupacion_canal

WHERE TRANSACCIONES.agrupacion_canal = 'TLV - DO'
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