BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'RALTC3';

SET canales_pr = ['ALT'];

-- CALL `mm-commissions-reporting.COMISIONES.pr_raltc3`(202410,['ALT']);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_aral_cam_tri` AS 

WITH 
  base_num AS (
  SELECT a.* EXCEPT(commission_id), 
    CASE
      WHEN b.deactivation_date IS NULL OR b.deactivation_date > LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH)) THEN '9999-12-31'
      ELSE b.deactivation_date
    END AS deactivation_date_ventas,
    ROW_NUMBER() OVER(PARTITION BY a.phone_nm) AS n_control
  FROM `mm-commissions-reporting.COMISIONES.transacciones` a
  LEFT JOIN (
    SELECT phone_nm,account_id,customer_id,service_id,activation_date,deactivation_date
    FROM `mm-datamart-kd.SERVICES.ventas_base_net`
    WHERE comm_brand_ds = 'ALTERNA'
   ) b ON a.phone_nm = CAST(b.phone_nm AS STRING) AND a.account_id = b.account_id AND a.customer_id = b.customer_id AND a.service_id = b.service_id AND a.activation_date = b.activation_date
  WHERE canal ='ALT' 
    AND tipo_concepto = 'UPFR' 
    AND concepto = 'D - Upfront Acuerdo Alterna 2022'
    AND (bundle_type IN ('2P') OR tariff_ds = 'FIBRA 300MB INDIRECTA + TARIFA ALTERNA 35GB') 
  ),

  b_upfront AS (
    SELECT *
    FROM base_num
    WHERE id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH)) AS INT64)
  ),

  b_clawback AS (
    SELECT a.* EXCEPT(activation_date,deactivation_date,mes_liquidado),
      a.activation_date,
      a.deactivation_date,
      CASE 
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 0 AND 3  THEN DATE_ADD(a.activation_date, INTERVAL 3 MONTH)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 4 AND 7  THEN DATE_ADD(a.activation_date, INTERVAL 6 MONTH)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 8 AND 11 THEN DATE_ADD(a.activation_date, INTERVAL 9 MONTH)
        ELSE NULL
      END AS deactivation_date_teorica,
      CASE
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 4 AND 6 THEN DATE_DIFF(DATE_ADD(a.activation_date, INTERVAL 6 MONTH),DATE_ADD(a.activation_date, INTERVAL 3 MONTH),DAY)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 7 AND 9 THEN DATE_DIFF(DATE_ADD(a.activation_date, INTERVAL 9 MONTH),DATE_ADD(a.activation_date, INTERVAL 6 MONTH),DAY)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 10 AND 12 THEN DATE_DIFF(DATE_ADD(a.activation_date, INTERVAL 12 MONTH),DATE_ADD(a.activation_date, INTERVAL 9 MONTH),DAY)
        ELSE DATE_DIFF(DATE_ADD(a.activation_date, INTERVAL 3 MONTH),a.activation_date,DAY)
      END AS ndias_tri_deact,
      b.mes_liquidado
    FROM base_num a
    LEFT JOIN (
      SELECT mes_liquidado,phone_nm, activation_date
      FROM `mm-commissions-reporting.COMISIONES.transacciones` 
      WHERE canal = 'ALT'
        AND concepto IN ('E - Camp Servicio 2P ID:2658','E - Camp Servicio 3P ID:2658')
        --AND phone_nm = '856546556'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1
    ) b ON a.phone_nm = b.phone_nm AND a.activation_date = b.activation_date AND a.mes_liquidado = DATE_SUB(b.mes_liquidado, INTERVAL 1 MONTH) --AND a.mes_liquidado = b.mes_liquidado --
    WHERE 
      deactivation_date_ventas < DATE_TRUNC(CURRENT_DATE(),MONTH)
      --deactivation_date_ventas < DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
      AND id_mes >= 202409 --Inicio de la campaña
      AND b.mes_liquidado IS NULL
      --AND DATE_DIFF(deactivation_date_ventas,a.activation_date,MONTH) >= 1
    GROUP BY ALL
  ),

  b_clawback_antigua AS (
    SELECT a.* EXCEPT(activation_date,deactivation_date),
      CASE 
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 4 AND 6 THEN DATE_ADD(a.activation_date, INTERVAL 3 MONTH)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 7 AND 9 THEN DATE_ADD(a.activation_date, INTERVAL 6 MONTH)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 10 AND 12 THEN DATE_ADD(a.activation_date, INTERVAL 9 MONTH)
        ELSE a.activation_date
      END AS activation_date,
      a.deactivation_date,
      --IF(DATE_DIFF(deactivation_date_ventas,activation_date, MONTH) = 2, 2,1) AS dif_mes,
      CASE
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 4 AND 6 THEN DATE_DIFF(DATE_ADD(a.activation_date, INTERVAL 3 MONTH),DATE_ADD(a.activation_date, INTERVAL 6 MONTH),DAY)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 7 AND 9 THEN DATE_DIFF(DATE_ADD(a.activation_date, INTERVAL 6 MONTH),DATE_ADD(a.activation_date, INTERVAL 9 MONTH),DAY)
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) BETWEEN 10 AND 12 THEN DATE_DIFF(DATE_ADD(a.activation_date, INTERVAL 9 MONTH),DATE_ADD(a.activation_date, INTERVAL 12 MONTH),DAY)
        ELSE DATE_DIFF(a.activation_date,DATE_ADD(a.activation_date, INTERVAL 3 MONTH),DAY)
      END AS ndias_tri_deact,
      -- CASE
      --   WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date,DAY) >= 90 THEN DATE_DIFF(deactivation_date_ventas,b.max_mes_liquidado,DAY)
      --   ELSE DATE_DIFF(deactivation_date_ventas,a.activation_date,DAY)
      -- END AS dias_act,
      -- CASE
      --   WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) = 0 THEN DATE_DIFF(deactivation_date_ventas,a.activation_date, DAY)
      --   ELSE DATE_DIFF(deactivation_date_ventas,LAST_DAY(DATE_SUB(deactivation_date_ventas, INTERVAL 1 MONTH)), DAY) 
      -- END AS dias_act,
      b.mes_liquidado
    FROM base_num a
    LEFT JOIN (
      SELECT mes_liquidado,phone_nm, activation_date
      FROM `mm-commissions-reporting.COMISIONES.transacciones` 
      WHERE canal = 'ALT'
        AND concepto IN ('E - Camp Servicio 2P ID:2658','E - Camp Servicio 3P ID:2658')
        --AND phone_nm = '856546556'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1
    ) b ON a.phone_nm = b.phone_nm AND a.activation_date = b.activation_date AND a.mes_liquidado = DATE_SUB(b.mes_liquidado, INTERVAL 1 MONTH) --AND a.mes_liquidado = b.mes_liquidado --
    WHERE 
      deactivation_date_ventas < DATE_TRUNC(CURRENT_DATE(),MONTH)
      --deactivation_date_ventas < DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
      AND id_mes >= 202409 --Inicio de la campaña
      AND b.mes_liquidado IS NULL
      --AND DATE_DIFF(deactivation_date_ventas,a.activation_date,MONTH) >= 1
    GROUP BY ALL
  ),

  b_clawback_antiguo AS (
    SELECT a.*,
      CASE 
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) >= 3 THEN DATE_DIFF(deactivation_date_ventas,b.mes_liquidado, MONTH)
        ELSE DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH)
      END AS dif_mes,
      --IF(DATE_DIFF(deactivation_date_ventas,activation_date, MONTH) = 2, 2,1) AS dif_mes,
      DATE_DIFF(LAST_DAY(deactivation_date_ventas),DATE_TRUNC(deactivation_date_ventas, MONTH),DAY) + 1 AS ndias_mes_deact,
      -- CASE
      --   WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date,DAY) >= 90 THEN DATE_DIFF(deactivation_date_ventas,b.max_mes_liquidado,DAY)
      --   ELSE DATE_DIFF(deactivation_date_ventas,a.activation_date,DAY)
      -- END AS dias_act,
      CASE
        WHEN DATE_DIFF(deactivation_date_ventas,a.activation_date, MONTH) = 0 THEN DATE_DIFF(deactivation_date_ventas,a.activation_date, DAY)
        ELSE DATE_DIFF(deactivation_date_ventas,LAST_DAY(DATE_SUB(deactivation_date_ventas, INTERVAL 1 MONTH)), DAY) 
      END AS dias_act,
      b.mes_liquidado
    FROM base_num a
    LEFT JOIN (
      SELECT mes_liquidado,phone_nm, activation_date
      FROM `mm-commissions-reporting.COMISIONES.transacciones` 
      WHERE canal = 'ALT'
        AND concepto IN ('E - Camp Servicio 2P ID:2658','E - Camp Servicio 3P ID:2658')
        --AND phone_nm = '856546556'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1
    ) b ON a.phone_nm = b.phone_nm AND a.activation_date = b.activation_date AND a.mes_liquidado = DATE_SUB(b.mes_liquidado, INTERVAL 1 MONTH) --AND a.mes_liquidado = b.mes_liquidado --
    WHERE 
      deactivation_date_ventas < DATE_TRUNC(CURRENT_DATE(),MONTH)
      --deactivation_date_ventas < DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
      AND id_mes >= 202409 --Inicio de la campaña
      AND b.mes_liquidado IS NULL
      --AND DATE_DIFF(deactivation_date_ventas,a.activation_date,MONTH) >= 1
    GROUP BY ALL
  ), --SELECT * FROM b_clawback WHERE phone_nm = '856524474'
  --*,(8.263 /ndias_mes_deact)*dias_act
  
  base_num_mas_3_meses AS (

    SELECT a.* EXCEPT(deactivation_date), 
      b.deactivation_date AS deactivation_date_ventas,
      ROW_NUMBER() OVER(PARTITION BY a.phone_nm) AS n_control
    FROM `mm-commissions-reporting.COMISIONES.transacciones` a
    LEFT JOIN (
    SELECT phone_nm,account_id,customer_id,service_id,activation_date,IF(deactivation_date IS NULL,'9999-12-31',deactivation_date) AS deactivation_date
    FROM `mm-datamart-kd.SERVICES.ventas_base_net`
    WHERE comm_brand_ds = 'ALTERNA'
   ) b ON a.phone_nm = CAST(b.phone_nm AS STRING) AND a.account_id = b.account_id AND a.customer_id = b.customer_id AND a.service_id = b.service_id AND a.activation_date = b.activation_date
    WHERE a.canal ='ALT'
      AND a.id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH)) AS INT64)
        --OR a.id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)) AS INT64)
        --OR a.id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(), INTERVAL 9 MONTH)) AS INT64)
      AND a.tipo_concepto = 'UPFR' 
      AND a.concepto = 'D - Upfront Acuerdo Alterna 2022'--Sustituir por el concepto de la campaña en cuestión
      AND (a.bundle_type IN ('2P') OR a.tariff_ds = 'FIBRA 300MB INDIRECTA + TARIFA ALTERNA 35GB')
      AND b.deactivation_date = '9999-12-31' 
  ),

  upfront AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      agrupacion_canal,
      canal,
      CASE
        WHEN bundle_type = 'FMC' THEN 'D - Camp Servicio 3P ID:2658' 
        WHEN bundle_type = '2P' THEN  'D - Camp Servicio 2P ID:2658'
        ELSE 'X - NO CRUZA'
      END AS concepto,
      tipo_concepto,
      1  AS unidades,
      CASE
        WHEN bundle_type = '2P' THEN 24.79
        WHEN tariff_ds = 'FIBRA 300MB INDIRECTA + TARIFA ALTERNA 35GB' THEN 7.43
        ELSE 0
      END AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      IF(deactivation_date_ventas != '9999-12-31','9999-12-31',deactivation_date_ventas) AS deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      --'202409'     AS campaign_code,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM b_upfront
    --WHERE n_control = 1
  ),

  upfront_mas_3_meses AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      agrupacion_canal,
      canal,
      CASE
        WHEN bundle_type = 'FMC' THEN 'D - Camp Servicio 3P ID:2658' 
        WHEN bundle_type = '2P' THEN  'D - Camp Servicio 2P ID:2658'
        ELSE 'X - NO CRUZA'
      END AS concepto,
      tipo_concepto,
      1  AS unidades,
      CASE
        WHEN bundle_type = '2P' THEN 24.79
        WHEN tariff_ds = 'FIBRA 300MB INDIRECTA + TARIFA ALTERNA 35GB' THEN 7.43
        ELSE 0
      END AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      IF(deactivation_date_ventas != '9999-12-31','9999-12-31',deactivation_date_ventas) AS deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM base_num_mas_3_meses
    WHERE n_control = 1
  ),
  
  clawback AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) as mes_liquidado, 
      CAST(mes_string AS INT64) as id_mes,
      agrupacion_canal,
      canal,
      CASE
        WHEN bundle_type = 'FMC' THEN 'E - Camp Servicio 3P ID:2658' 
        WHEN bundle_type = '2P' THEN  'E - Camp Servicio 2P ID:2658'
        ELSE 'X - NO CRUZA'
      END AS concepto,
      tipo_concepto,
      1  AS unidades,
      CASE
        -- Si la línea tiene fecha de desactivación
        WHEN deactivation_date_ventas != '9999-12-31' THEN 
          CASE
            -- Si es un bundle de tipo '2P'
            WHEN bundle_type = '2P' THEN 
              -(24.79 / ndias_tri_deact) * DATE_DIFF(deactivation_date_teorica,deactivation_date_ventas,DAY) --dias_act
              

            WHEN tariff_ds = 'FIBRA 300MB INDIRECTA + TARIFA ALTERNA 35GB' THEN 
              -(7.43 / ndias_tri_deact) * DATE_DIFF(deactivation_date_teorica,deactivation_date_ventas,DAY) --dias_act
            
            ELSE 0 
          END
      END AS comision,
      -- CASE
      --   -- Si la línea tiene fecha de desactivación
      --   WHEN deactivation_date_ventas != '9999-12-31' THEN 
      --     CASE
      --       -- Si es un bundle de tipo '2P'
      --       WHEN bundle_type = '2P' THEN 
      --           --Sumamos 24.79 según los meses activo
      --           IF(dif_mes = 2, 16.526,IF(dif_mes = 1,8.263,0))+
      --           -- Se prorratea el importe en días
      --           (8.263 /ndias_mes_deact)*dias_act
      --           -24.79

      --       WHEN tariff_ds = 'FIBRA 300MB INDIRECTA + TARIFA ALTERNA 35GB' THEN 
      --         -- Misma lógica para esta tarifa
      --           IF(dif_mes = 2,4.953 ,IF(dif_mes = 1,2.476,0))+
      --           -- Se prorratea el importe en días
      --           (2.476 /ndias_mes_deact)*dias_act
      --           -7.43
      --       ELSE 0 
      --     END
      -- END AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
      tariff_id,
      tariff_ds,
      service_id,
      account_id,
      customer_id,
      line_type_ds,
      bundle_type,
      technology_ds,
      billing_type_ds,
      sale_date,
      activation_date,
      deactivation_date_ventas AS deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      --'202409'     AS campaign_code,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      'X001'                   AS sociedad,
      CAST(NULL AS STRING)     AS bp,
      CAST(NULL AS STRING)     AS cuenta_contable,
      CAST(NULL AS STRING)     AS centro_coste,
      CAST(NULL AS STRING)     AS documento_sap,
      CAST(NULL AS STRING)     AS documento_sap_posicion,
      CAST(NULL AS STRING)     AS fecha_contabilizacion,
      CAST(NULL AS TIMESTAMP)  AS creado,
      CAST(NULL AS TIMESTAMP)  AS modificado,
      CAST(NULL AS STRING)     AS id_factura_drive,
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM b_clawback
    --WHERE n_control = 1
  ),

  final AS (
    SELECT *
    FROM upfront
    
    UNION ALL

    SELECT*
    FROM clawback
    WHERE deactivation_date BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)

    UNION ALL

    SELECT *
    FROM upfront_mas_3_meses
  )

    SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
    FROM final
    WHERE comision IS NOT NULL
      AND concepto LIKE 'E -%'
      --ultimo mes que se lanzó el upfront 202503
      AND activation_date < '2025-04-01'; 

-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_base_aral_cam_tri',
  'ACTUALIZAR'
);


END