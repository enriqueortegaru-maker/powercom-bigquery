BEGIN

  DECLARE inicio_fecha_liquidacion DATE;
  SET inicio_fecha_liquidacion = DATE_SUB(inicio_mes_liquidacion, INTERVAL 3 MONTH);

  SELECT 
      'CABCAMP2'||'_'||CAST(id_mes_liquidacion AS STRING)||'_'||'CM_3403'||'_'||row_number () over () AS commission_id, *

  -- TENEMOS QUE METER UN UNION ALL CON LOS CLAWBACKS, PARA QUE LLEVEN UN ÚNICO commission_id

  FROM (

      --D - Camp. Cable ID: 3403
    SELECT
        'calculado' AS estado
      , inicio_mes_liquidacion AS mes_liquidado
      , id_mes_liquidacion AS id_mes
      , comm_brand_ds AS agrupacion_canal
      , 'CM' AS canal
      , CONCAT('D - Camp. Cable ID: ',CAST(GSC.ID_SUBCAMPANA AS STRING)) AS concepto
      , 'UPFR' AS tipo_concepto
      , CAST(1 AS INT64) AS unidades
      , (GSC.PxQ_MAXIMO * UBA.cuenta) AS comision
      , GSC.CODIGO_XENA AS id_comisionista
      , GSC.CODIGO_XENA AS distribuidor
      , GSC.CODIGO_XENA AS sfid_id
      , GSC.CODIGO_XENA AS seller
      , GSC.CLIENTE AS nombre_comercio
      , GSC.CLIENTE AS razon_social
      , 'TBD' AS cif
      , 'TBD' AS zona_fiscal
      , CAST(NULL AS STRING) AS cond_pago
      , UBA.comm_brand_ds AS marca
      , UBA.service_type AS service_type
      , CAST(NULL AS STRING) AS phone_nm
      , CAST(NULL AS STRING) AS tariff_id
      , CAST(NULL AS STRING) AS tariff_ds
      , CAST(NULL AS STRING) AS service_id
      , CAST(NULL AS STRING) AS account_id
      , CAST(NULL AS STRING) AS customer_id
      , CAST(NULL AS STRING) AS line_type_ds
      , CAST(NULL AS STRING) AS bundle_type
      , CAST(NULL AS STRING) AS technology_ds
      , UBA.billing_type_ds AS billing_type_ds
      , CAST(NULL AS STRING) AS sale_date
      , UBA.activation_date_main_line AS activation_date
      , CAST(NULL AS STRING) AS deactivation_date
      , CAST(NULL AS STRING) AS order_id
      , CAST(NULL AS STRING) AS order_type_agg
      , `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(NULL,UBA.comm_brand_ds) AS cod_segmento
      , `mm-commissions-reporting.COMISIONES.f_cod_marca`(UBA.brand_aggr,NULL) AS cod_marca
      , CASE WHEN UBA.billing_type_ds = 'PREPAID' THEN '10'
            WHEN UBA.bundle_type = 'FMC' AND UBA.line_type_ds = 'MAIN' THEN (CASE WHEN UBA.technology_ds = 'ADSL' THEN '60' ELSE '61' END)
            WHEN UBA.bundle_type = 'FMC' THEN (CASE WHEN UBA.technology_ds = 'ADSL' THEN '66' ELSE '67' END)
            WHEN UBA.bundle_type = 'MO' AND UBA.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND UBA.comm_brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
            ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(UBA.billing_type_ds, UBA.service_type, UBA.bundle_type, UBA.technology_ds, UBA.comm_brand_ds, UBA.line_type_ds)
            END AS cod_tipo_contrato
      , CASE WHEN UBA.comm_brand_ds IN ('ADAMO','CABLEMOVIL') THEN '022'
            WHEN UBA.comm_brand_ds IN ('MARBLANCA') THEN '039'
            WHEN UBA.comm_brand_ds IN ('EUSKALTEL') THEN '040'
            WHEN UBA.comm_brand_ds IN ('NASH','NETLLAR','OCEAN') THEN '999'
            ELSE '999' END AS cod_producto
      , CASE WHEN UBA.comm_brand_ds IN ('ADAMO','ALTERNA','CABLEMOVIL','HITS','MARBLANCA','NASH','NETLLAR','OCEAN','PARLEM') THEN '30'
            ELSE '999' END AS cod_canal
      , GSC.campana AS campaign_code
      , CAST(NULL AS STRING) AS serial_number
      , CAST(NULL AS STRING) AS tax_base
      , CAST(NULL AS STRING) AS claim_code
      , 'CABCAMP2'||'_'||CAST(id_mes_liquidacion AS STRING)||'_'||'CM' AS process_code
      , 'Autofactura' AS comments
      , 'C_MANUAL' AS facturador
      , CAST(NULL AS STRING) AS proceso_sap
      , CAST(NULL AS STRING) AS id_registro
      , CAST(NULL AS STRING) AS invoice_id
      , 'X001' AS sociedad
      , CAST(NULL AS STRING) AS bp
      , CAST(NULL AS STRING) AS cuenta_contable
      , CAST(NULL AS STRING) AS centro_coste
      , CAST(NULL AS STRING) AS documento_sap
      , CAST(NULL AS STRING) AS documento_sap_posicion
      , CAST(NULL AS STRING) AS fecha_contabilizacion
      , CURRENT_TIMESTAMP () AS creado
      , CAST(NULL AS STRING) AS modificado
      , CAST(NULL AS STRING) AS id_factura_drive
      , CAST(NULL AS STRING) AS emails_acceso_trazabilidad

    FROM(
      --D - Camp. Cable ID: 3403
        SELECT activation_date_main_line, cliente, comm_brand_ds, brand_aggr, service_type, billing_type_ds, bundle_type, line_type_ds, technology_ds, SUM(cuenta) AS cuenta
        FROM (
          SELECT 'Alta' AS tipo, DATE_TRUNC(activation_date_main_line, MONTH) AS activation_date_main_line, cliente, comm_brand_ds, brand_aggr
               , service_type, billing_type_ds, bundle_type, line_type_ds, technology_ds,  COUNT(1) AS cuenta
          FROM `mm-commissions-reporting.TEMP.upfronts_base_arca`
          WHERE cliente in ('F42152')  --CATEGORIZACIÓN
            --AND activation_date_main_line BETWEEN inicio_fecha_liquidacion AND fin_mes_liquidacion --DESDE	HASTA
            AND activation_date BETWEEN inicio_fecha_liquidacion AND fin_mes_liquidacion --DESDE	HASTA
            AND bundle_type = 'MO' --TIPO LINEA
            AND group_donor NOT IN ('GRUPO MASMOVIL','ORANGE')
          GROUP BY ALL

          UNION ALL

          SELECT 'Baja' AS tipo, DATE_TRUNC(deactivation_date_main_line, MONTH) AS deactivation_date_main_line, cliente, comm_brand_ds, brand_aggr
               , service_type, billing_type_ds, bundle_type, line_type_ds, technology_ds, (-1*COUNT(1)) AS cuenta
          FROM `mm-commissions-reporting.TEMP.upfronts_base_arca`
          WHERE cliente in ('F42152')  --CATEGORIZACIÓN
            --AND deactivation_date_main_line BETWEEN inicio_fecha_liquidacion AND fin_mes_liquidacion --DESDE	HASTA
            AND deactivation_date BETWEEN inicio_fecha_liquidacion AND fin_mes_liquidacion --DESDE	HASTA
            AND bundle_type = 'MO' --TIPO LINEA
            AND group_donor NOT IN ('GRUPO MASMOVIL','ORANGE')
          GROUP BY ALL
        )
        GROUP BY ALL
    ) UBA
    LEFT JOIN `mm-commissions-reporting.B2B.gs_global_subcampana` GSC
      ON  GSC.CODIGO_XENA = UBA.cliente
      AND GSC.MARCA = UBA.comm_brand_ds
      AND GSC.INICIO_SUBCAMPANA <= inicio_mes_liquidacion
      AND PARSE_DATE('%m/%d/%Y', GSC.FIN_SUBCAMPANA) >= fin_mes_liquidacion
      AND GSC.TIPO_CAMPANA = 'ESPECIALES'
      AND GSC.OBJETIVO_KPI_UPFRONT = 'NETAS'
      AND GSC.TIPO_ALTA = 'TODAS'
      AND GSC.OPERADOR_DONANTE = 'TODOS'
      AND GSC.ID_SUBCAMPANA NOT IN (3402)

  );

END