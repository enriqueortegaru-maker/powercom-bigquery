BEGIN

DECLARE clave STRING;

SET clave = 'ARCA';

CREATE OR REPLACE TABLE `mm-commissions-reporting.CABLEOPERADORES.comisiones_working_arca` AS 

--DECLARE mes_pr DATE DEFAULT '2022-11-01';

  WITH 
  svc AS(

      SELECT
        s.*,
        IF(service_type = 'FIX', IF(activation_tariff_ds LIKE '%+%', 'FMC', '2P'),service_type) AS bundle_type,
      FROM `mm-datamart-kd.SERVICES.service_base_net` s
      WHERE true
        AND activation_date <= '2023-01-31' 
        AND (deactivation_date IS NULL OR ((deactivation_date >= '2023-01-31' AND kpi_fin_tramo_eop = 1) OR (deactivation_date > '2023-01-31' AND kpi_fin_tramo_eop = 0))) 
        -- AND brand_ds = 'OPERADORES'
        AND brand_ds IN ('OPERADORES','EURONA') AND data_source_ds = 'XENA' 
        -- AND sub_brand_ds = 'CABLEOPERADORES' 
        -- AND kpi_gross_add = 1 

  ),
  
  base AS (

    SELECT DISTINCT 
      * EXCEPT(tipo_paquete),
      CASE
        WHEN service_type = 'FIX' THEN IF(tariff_ds LIKE '%+%'OR bono_name LIKE '%+%', 'FMC', '2P')
        WHEN tipo_paquete =  'MOBILE ONLY' THEN 'MO'
        ELSE service_type
      END AS tipo_paquete
    FROM `mm-b2b-reporting.BILLING.facturacion` 
    WHERE PERIODO_FACTURADO_REAL = '2023-01-01' AND CRM = 'XENA' AND (SEGMENTO IN ('Cableoperador','GGCC') OR GRUPO IN ('Ahí+','Populoos')) AND TIPO != 'TRAFICO' AND tipo_paquete = 'MOBILE ONLY' AND service_type ='MOBILE'
    --AND TIPO_PAQUETE != 'OTROS'

  ),

  ventas_pers_mobile AS(
    SELECT DISTINCT
      document AS CIF,
      dealer_customer_id,
      comm_brand_ds,
      account_id,
      IF(company_name IS NULL, CONCAT(first_name, surnames), company_name) AS company_name
    FROM `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info`
    WHERE datasource_ds = 'XENA'
  ),

  ventas_pers_fibra AS(
    SELECT DISTINCT
      svc.service_id,
      svc.service_type,
      v.document AS CIF,
      v.dealer_customer_id,
      v.comm_brand_ds,
      v.phone_nm,
      IF(v.company_name IS NULL, CONCAT(v.first_name, v.surnames), v.company_name) AS company_name
    FROM  `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info` v
    JOIN svc
      ON svc.customer_id = v.dealer_customer_id
      AND svc.phone_nm = v.phone_nm
      AND svc.comm_brand_ds = 'MARBLANCA'

  ),

  b AS(
    SELECT DISTINCT
      'X001' AS sociedad,
      base.CLIENTE AS id_comisionista,
      'DEA' AS tipo_comisionista,
      COALESCE(ventas_pers_mobile.CIF, ventas_pers_fibra.CIF) AS CIF,
      -- zona_fiscal.zona_fiscal,
      COALESCE(zona_fiscal.zona_fiscal,
        CASE 
          WHEN UPPER(COALESCE(b2b_xena.provincia, b2b_marblanca.provincia)) LIKE '%TENERIFE%' THEN 'CAN'
          WHEN UPPER(COALESCE(b2b_xena.provincia, b2b_marblanca.provincia)) LIKE '%PALMAS%' THEN 'CAN'
          WHEN UPPER(COALESCE(b2b_xena.provincia, b2b_marblanca.provincia)) LIKE '%CANARIA%' THEN 'CAN'
          WHEN UPPER(COALESCE(b2b_xena.provincia, b2b_marblanca.provincia)) LIKE '%CEUTA%' THEN 'CEU'
          WHEN UPPER(COALESCE(b2b_xena.provincia, b2b_marblanca.provincia)) LIKE '%MELILLA%' THEN 'MEL'
          ELSE 'PEN'
        END) AS zona_fiscal,
      'AIRT' AS tipo_concepto,
      CASE 
        WHEN base.TIPO_PAQUETE LIKE 'MO' THEN CONCAT('C - Gestion Cartera Movil ','(', CASE
        WHEN base.CLIENTE IN ('F10968','F10973','F10961','F33987','F34028','F10967','F45631','F45389','F10971','F46100','F40288','F10965','F10964','216496','F10974','F10966','F10978','F10980','F43594','F91832') THEN 40
        WHEN comisiones.COMISION IS NULL THEN 20
        ELSE CAST(REPLACE(comisiones.COMISION,',','.') AS NUMERIC)
      END ,'%)')
        WHEN base.TIPO_PAQUETE = 'FMC' THEN CONCAT('C - Gestion Cartera 3P ', '(', CASE
        WHEN base.CLIENTE IN ('F10968','F10973','F10961','F33987','F34028','F10967','F45631','F45389','F10971','F46100','F40288','F10965','F10964','216496','F10974','F10966','F10978','F10980','F43594','F91832') THEN 40
        WHEN comisiones.COMISION IS NULL THEN 20
        ELSE CAST(REPLACE(comisiones.COMISION,',','.') AS NUMERIC)
      END,'%)')
        WHEN base.TIPO_PAQUETE = '2P' THEN CONCAT('C - Gestion Cartera 2P ', '(', CASE
        WHEN base.CLIENTE IN ('F10968','F10973','F10961','F33987','F34028','F10967','F45631','F45389','F10971','F46100','F40288','F10965','F10964','216496','F10974','F10966','F10978','F10980','F43594','F91832') THEN 40
        WHEN comisiones.COMISION IS NULL THEN 20
        ELSE CAST(REPLACE(comisiones.COMISION,',','.') AS NUMERIC)
      END,'%)')
      END AS descripcion_concepto,
      -- CASE 
      --   WHEN base.TIPO_PAQUETE LIKE 'MOBILE%' THEN CONCAT('Com Cartera Movil ', base.CLIENTE, ' Ene 23')
      --   WHEN base.TIPO_PAQUETE = '3P' THEN CONCAT('Com Cartera 3P ', base.CLIENTE, ' Ene 23')
      --   WHEN base.TIPO_PAQUETE = '2P' THEN CONCAT('Com Cartera 2P ', base.CLIENTE, ' Ene 23')
      -- END AS descripcion_concepto,
      CAST(NULL AS INT64) AS uds,
      /*base.FACTURADO      AS base_imponible,
      CASE
        WHEN base.CLIENTE IN ('F10968','F10973','F10961','F33987','F34028','F10967','F45631','F45389','F10971','F46100','F40288','F10965','F10964','216496','F10974','F10966','F10978','F10980','F43594','F91832') THEN 40
        WHEN comisiones.COMISION IS NULL THEN 20
        ELSE CAST(REPLACE(comisiones.COMISION,',','.') AS NUMERIC)
      END AS porcentaje_comision,*/
      CASE
        WHEN base.bono_name = 'Cuota Mantenimiento Linea' THEN 0
        WHEN base.CLIENTE IN ('F10968','F10973','F10961','F33987','F34028','F10967','F45631','F45389','F10971','F46100','F40288','F10965','F10964','216496','F10974','F10966','F10978','F10980','F43594','F91832') THEN base.FACTURADO*0.40
        WHEN comisiones.COMISION IS NULL THEN base.FACTURADO*0.20
        ELSE base.FACTURADO*(CAST(REPLACE(comisiones.COMISION,',','.') AS NUMERIC)/100)
      END AS importe_base,
      -- IF(base.FACTURADO*(CAST(REPLACE(IF(comisiones.COMISION IS NULL, '20,0', comisiones.COMISION), ',', '.') AS NUMERIC)/100) IS NULL, 0, base.FACTURADO*(CAST(REPLACE(IF(comisiones.COMISION IS NULL, '20,0', comisiones.COMISION), ',', '.') AS NUMERIC)/100))  AS importe_base,
      'EUR'     AS moneda,
      'C'       AS via_pago,
      'Z001'    AS cond_pago,
      '30'      AS cod_canal,
      '039'     AS cod_producto, -- 022 antes??
      CASE 
        WHEN base.service_type = 'FIX' THEN '61' 
        WHEN base.service_type LIKE 'MOBILE%' THEN '20' 
      END                      AS cod_tipo_contrato,
      '09'                     AS cod_marca,
      '999'                    AS cod_operador,
      '42'                     AS cod_segmento,
      'C_MANUAL'               AS facturador,
      'C - Calidad'            AS clasificacion_concepto,
      'CABLEOPERADORES'        AS canal,
      CAST(NULL AS STRING)     AS subscription_id,
      base.service_type        AS product_type,
      base.TIPO_PAQUETE        AS bundle_type,
      CAST(NULL AS STRING)     AS msisdn,
      CAST(NULL AS DATE)       AS fecha_activacion,
      CAST(NULL AS DATE)       AS fecha_baja,
      CAST(NULL AS STRING)     AS account_id,
      base.CLIENTE             AS customer_id,
      base.CLIENTE             AS sfid_unico,
      base.CLIENTE             AS tienda,
      base.CLIENTE             AS distribuidor,
      mes_pr AS fecha,
      base.TIPO_PAQUETE        AS agrupacion_cod_tipo_contrato,
      'Cableoperadores'        AS segmento,
      zona_fiscal.vendor_name  AS razon_social, --COALESCE(ventas_pers_mobile.company_name, ventas_pers_fibra.company_name) AS razon_social,
      COALESCE(base.cuenta_cliente, base.cuenta_cliente) AS nombre_comercio,
      'CABLEMOVIL'             AS marca,
      CAST(NULL AS STRING)     AS order_id,
      CASE
        WHEN base.bono_id != ''   OR base.bono_id IS NOT NULL   THEN base.bono_id
        WHEN base.tariff_id != '' OR base.tariff_id IS NOT NULL THEN base.tariff_id 
        ELSE NULL
      END AS Product_id,
      CASE
        WHEN (base.bono_id != '' AND base.tariff_id = '')  OR (base.bono_id IS NOT NULL AND base.tariff_id IS NULL) THEN base.bono_name 
        WHEN (base.bono_id = ''  AND base.tariff_id != '') OR (base.bono_id IS NULL AND base.tariff_id IS NOT NULL) THEN base.tariff_ds 
        ELSE NULL
      END AS Product,
      CAST(NULL AS STRING) AS user_id,
      -- CAST(REPLACE(IF(comisiones.COMISION IS NULL, '20,0', comisiones.COMISION), ',', '.') AS NUMERIC) AS porcentaje_comision
      -- bil.imp_without_tax*(CAST(REPLACE(comisiones.COMISION, ',', '.') AS NUMERIC)/100) AS importe_comision, --TRASPASAR ESTE CALCULO A importe_base
      -- COUNT(DISTINCT bil.phone_nm) AS Clientes,
    FROM base
    LEFT JOIN 
      (
        SELECT * EXCEPT(ID_TARIFA),
          CASE 
            WHEN DESCRIPCION LIKE 'MA_CABL%' THEN '6'
            ELSE ID_TARIFA
          END AS ID_TARIFA
        FROM `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores`) comisiones
      ON base.CLIENTE = comisiones.CODIGO_CABLEOPERADOR AND 
      (base.tariff_id = comisiones.ID_TARIFA OR base.bono_id = comisiones.ID_TARIFA)
    LEFT JOIN ventas_pers_mobile 
      ON ventas_pers_mobile.account_id = base.CLIENTE -- ventas_pers.service_id = svc.service_id       
    LEFT JOIN ventas_pers_fibra 
      ON ventas_pers_fibra.dealer_customer_id = base.CLIENTE 
    LEFT JOIN `mm-commissions-reporting.SAP.vendor_list` zona_fiscal 
      ON zona_fiscal.tax_code = COALESCE(ventas_pers_mobile.CIF, ventas_pers_fibra.CIF)
    LEFT JOIN (
        SELECT 
          cuenta_cliente,
          customer_id_xena,
          provincia,
          segmento
        FROM `mm-b2b-reporting.MAESTROS.Maestro_B2B`
        WHERE segmento = 'Cableoperador' OR segmento = 'GGCC' OR segmento = 'Marcas Propias'
      ) b2b_xena ON base.CLIENTE = b2b_xena.customer_id_xena
    LEFT JOIN (
        SELECT 
          cuenta_cliente,
          customer_id_mysim,
          customer_id_xena,
          provincia,
          segmento
        FROM `mm-b2b-reporting.MAESTROS.Maestro_B2B`
        WHERE segmento = 'Cableoperador' OR segmento = 'GGCC' OR segmento = 'Marcas Propias'
      ) b2b_marblanca ON IF(base.SEGMENTO = 'Marca Blanca', base.CLIENTE, NULL) = COALESCE(b2b_marblanca.customer_id_mysim, b2b_marblanca.customer_id_xena)
     WHERE b2b_xena.segmento = 'Cableoperador' OR b2b_marblanca.segmento='Cableoperador' OR b2b_xena.segmento = 'GGCC' OR b2b_marblanca.segmento = 'GGCC' OR b2b_xena.segmento = 'Marcas Propias' OR b2b_marblanca.segmento = 'Marcas Propias'

      -- GROUP BY 1,2,3,4,5,6,7,8,COMISION,11,12,13,14,15,16,17,18,19,20--,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44
  ),

  final AS (

    SELECT DISTINCT
      sociedad,
      id_comisionista,
      tipo_comisionista,
      b.CIF,
      zona_fiscal,
      tipo_concepto,
      descripcion_concepto,
      uds,
      --SUM(ROUND(base_imponible,2)) AS base_imponible,
      --porcentaje_comision,
      SUM(ROUND(importe_base,2))   AS importe_base,
      moneda,
      via_pago,
      cond_pago,
      cod_canal,
      cod_producto,
      cod_tipo_contrato,
      cod_marca,
      cod_operador,
      cod_segmento,
      facturador,
      clasificacion_concepto,
      canal,
      subscription_id,
      product_type,
      bundle_type,
      msisdn,
      fecha_activacion,
      fecha_baja,
      account_id,
      customer_id,
      sfid_unico,
      tienda,
      distribuidor,
      fecha,
      agrupacion_cod_tipo_contrato,
      segmento,
      razon_social,
      nombre_comercio,
      marca,
      order_id,
      Product_id,
      Product,
      -- user_id
      -- IF(autofactura.CIF IS NOT NULL, 'SI', 'NO') AS autofactura
    FROM b
    -- LEFT JOIN `mm-commissions-reporting.CABLEOPERADORES.maestro_autofactura` autofactura
    --   ON autofactura.CIF = b.CIF
    GROUP BY 1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41
   
  )

  SELECT 
    'ARCA_CABL_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
    -- CONCAT('CABCOM','202211-',ROUND(0001 + RAND() * (9999 - 0001))) AS id_registro,
    *,
    CAST(NULL AS STRING) AS user_id,
    CAST(NULL AS STRING) AS campaign_code,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    CAST(NULL AS STRING) AS comments
  FROM final
;

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'CABLEOPERADORES.comisiones_working_arca',
  'CABLEOPERADORES.comisiones_working'
);

END