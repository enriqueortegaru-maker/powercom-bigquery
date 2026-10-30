BEGIN

--CALL `mm-commissions-reporting.B2B.pr_campanas_B2B_preparar_datos`('2025-08-01','2025-08-31');

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_campanas_Xena`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

    SELECT cmp.Id_Campana, cmp.CODIGO_XENA, SFID_XENA AS sfid_id, cmp.tipo, cmp.MAXIMO_UPFRONT, SAFE_CAST(cmp.INICIO_CAMPANA AS DATE) AS INICIO_CAMPANA, SAFE_CAST(cmp.FIN_CAMPANA AS DATE) AS FIN_CAMPANA, cmp.CLIENTE, cmp.PRODUCTO, cmp.SUBPRODUCTO
         , scmp.ID_SUBCAMPANA, scmp.TIPO_CAMPANA, SAFE_CAST(scmp.INICIO_SUBCAMPANA AS DATE) AS INICIO_SUBCAMPANA, SAFE_CAST(scmp.FIN_SUBCAMPANA AS DATE) AS FIN_SUBCAMPANA, scmp.MAXIMO_UPFRONT_SC, scmp.TIPO_ALTA, scmp.TIPO_CIERRE, scmp.PROXIMO_CIERRE
         , ran.Id_Rango, ran.Tipo_Rango, ran.Tipo_Calculo, ran.Tramo_desde, ran.tramo_desde_generico, ran.Upfront
         , CAST (NULL AS STRING) AS huella, CAST (NULL AS STRING) AS velocidad, CAST (NULL AS STRING) AS speed, ran.DosP_TresP
         , scmp.PRODUCTO AS PRODUCTO_SUBCAMPANA, scmp.SUBPRODUCTO AS SUBPRODUCTO_SUBCAMPANA, scmp.OBJETIVO_KPI_UPFRONT, scmp.OPERADOR_DONANTE
    FROM `mm-commissions-reporting.B2B.gs_global_campana` cmp, UNNEST (SPLIT(REPLACE(codigo_xena,' ',''),',')) AS SFID_XENA
      INNER JOIN `mm-commissions-reporting.B2B.gs_global_subcampana` scmp
        ON  scmp.ID_CAMPANA = cmp.Id_Campana
      INNER JOIN `mm-commissions-reporting.B2B.gs_global_rangos` ran
        ON  ran.id_subcampana = scmp.ID_SUBCAMPANA
    WHERE cmp.codigo_xena IS NOT NULL        --necesario para eliminar los registros en blanco
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_campanas_Navision_sin_velocidad`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

    SELECT cmp.Id_Campana, cmp.CODIGO_NAVISION, SFID_Navision AS sfid_id, cmp.tipo, cmp.MAXIMO_UPFRONT, SAFE_CAST(scmp.INICIO_CAMPANA AS DATE) AS INICIO_CAMPANA, SAFE_CAST(scmp.FIN_CAMPANA AS DATE) AS FIN_CAMPANA, cmp.CLIENTE, cmp.PRODUCTO, cmp.SUBPRODUCTO
         , scmp.ID_SUBCAMPANA, scmp.TIPO_CAMPANA, SAFE_CAST(scmp.INICIO_SUBCAMPANA AS DATE) AS INICIO_SUBCAMPANA, SAFE_CAST(scmp.FIN_SUBCAMPANA AS DATE) AS FIN_SUBCAMPANA, scmp.MAXIMO_UPFRONT_SC, scmp.TIPO_ALTA, scmp.TIPO_CIERRE, scmp.PROXIMO_CIERRE
         , ran.Id_Rango, ran.Tipo_Rango, ran.Tipo_Calculo, ran.Tramo_desde, ran.tramo_desde_generico, ran.Upfront
         , ran.HUELLA AS huella, ran.VELOCIDAD AS velocidad, ran.DosP_TresP
    FROM `mm-commissions-reporting.B2B.gs_global_campana` cmp, UNNEST (SPLIT(REPLACE(codigo_navision,' ',''),',')) AS SFID_Navision
      INNER JOIN `mm-commissions-reporting.B2B.gs_global_subcampana` scmp
        ON  scmp.ID_CAMPANA = cmp.Id_Campana
      INNER JOIN `mm-commissions-reporting.B2B.gs_global_rangos` ran--, UNNEST (SPLIT(REPLACE(velocidad,' ',''),',')) AS speed
        ON  ran.id_subcampana = scmp.ID_SUBCAMPANA
    WHERE cmp.codigo_navision IS NOT NULL        --necesario para eliminar los registros en blanco
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_campanas_Navision`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
    SELECT * 
    FROM `mm-commissions-reporting.TEMP.B2B_campanas_Navision_sin_velocidad`, UNNEST (SPLIT(REPLACE(velocidad,' ',''),',')) AS speed
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_tarifas`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
    SELECT marca
        , service_type
        , tariff_id
        , tariff_ds
        , line_type
        , paquete
        , huella
        , velocidad
        , RANK () OVER (PARTITION BY tariff_id  ORDER BY tariff_ds ASC) AS rank
    FROM  `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_MB`
    WHERE tariff_id IS NOT NULL
    GROUP BY ALL
    QUALIFY rank = 1

    UNION ALL

    SELECT marca
        , service_type
        , tariff_id
        , tariff_ds
        , line_type
        , paquete
        , huella
        , velocidad
        , RANK () OVER (PARTITION BY tariff_id  ORDER BY tariff_ds ASC) AS rank
    FROM  `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_PAR`
    WHERE tariff_id IS NOT NULL
    GROUP BY ALL
    QUALIFY rank = 1

    --UNION ALL

    --METER RESTO DE MARCAS
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_ventas`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

    SELECT 
      UPPER(brand_ds) AS marca, 
      brand_ds, 
      'Comisiona' AS comisionamiento,
      activation_date, phone_nm, customer_id, service_id, account_id, seller, service_type, line_type_ds, bundle_type, billing_type_ds, tariff_id, tariff_ds, 
      `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento,
      `mm-commissions-reporting.COMISIONES.f_cod_marca`(brand_ds, service_type) AS cod_marca,
      `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, service_type, bundle_type, technology_ds, brand_ds, line_type_ds) AS cod_tipo_contrato,
      `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(service_type, brand_ds, order_type_agg, sell_type, 
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(billing_type_ds, service_type, bundle_type, technology_ds, brand_ds, line_type_ds)
        ) AS cod_producto,
      `mm-commissions-reporting.CONTROL.f_ventas_base_cod_canal`(channel_ds, subchannel_ds) AS cod_canal,
      `mm-commissions-reporting.TERMINALES.f_AGRUPACION_CANAL`(CHANNEL_TYPE_DS, MASTER_CHANNEL_DS, CHANNEL_DS, SUBCHANNEL_DS) agrupacion_canal,
      data_source_ds,
      segment_ds,
      province,
      zip_code,
      order_type_agg,
      sfid_id,
--      seller,
      technology_ds
    FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
--    FROM `mm-commissions-reporting.TEMP.ventas_base_telco_comisiones`
--    WHERE activation_date >= mes_inicio --sale_date >= mes_inicio
--      AND activation_date <= mes_fin --sale_date <= mes_fin
    WHERE order_date BETWEEN mes_inicio AND mes_fin
      AND activation_date IS NOT NULL
  ;
/*
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_ventas_resumen`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

    SELECT vnt.marca
         , vnt.sfid_id
         , CASE WHEN SUBSTR(vnt.zip_code,1,2) IN ('35','38') THEN 'CAN' ELSE 'PEN' END AS zona_fiscal
         , vnt.service_type
         , vnt.billing_type_ds
         , vnt.cod_segmento
         , vnt.cod_tipo_contrato
         , vnt.order_type_agg
         , COUNT(DISTINCT vnt.phone_nm) AS n_ventas
    FROM `mm-commissions-reporting.TEMP.B2B_ventas` vnt
    WHERE sfid_id IS NOT NULL
    GROUP BY ALL
  ;
*/
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_ventas_campana`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  SELECT Id_Campana, ID_SUBCAMPANA, CODIGO_NAVISION, MAXIMO_UPFRONT, CLIENTE, PRODUCTO, SUBPRODUCTO
      , TIPO_CAMPANA, PROXIMO_CIERRE, Tipo_Rango, Tipo_Calculo, huella, velocidad, speed
      , activation_month
      , COUNT(1) AS ventas
  FROM (
    SELECT cn.Id_Campana, cn.ID_SUBCAMPANA, cn.CODIGO_NAVISION, cn.MAXIMO_UPFRONT, cn.CLIENTE, cn.PRODUCTO, cn.SUBPRODUCTO
      , cn.TIPO_CAMPANA, cn.PROXIMO_CIERRE, cn.Tipo_Rango, cn.Tipo_Calculo, cn.huella, cn.velocidad, cn.speed, cn.DosP_TresP
      , btn.order_id
      , DATE_TRUNC(btn.activation_date, MONTH) AS activation_month
      , RANK () OVER (PARTITION BY cn.ID_SUBCAMPANA  ORDER BY SAFE_CAST(cn.Tramo_desde AS INT64) DESC, SAFE_CAST(cn.Upfront AS INT64) DESC) AS rank_1
    FROM `mm-commissions-reporting.TEMP.B2B_campanas_Navision` cn
      INNER JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_net` btn
        ON  cn.sfid_id = btn.sfid_id
        AND cn.PROXIMO_CIERRE LIKE '2025%'  --PROBANDO PARA SUBCAMPAÑA = 2830
        AND btn.activation_date >= '2025-05-01' --sale_date >= mes_inicio
        AND btn.activation_date <= '2025-05-31'
        AND btn.order_id IS NOT NULL
        AND btn.service_type = 'BROADBAND'
    WHERE btn.order_id IS NOT NULL
      AND btn.service_type = 'BROADBAND'
  --    AND cn.ID_SUBCAMPANA = 1354
      QUALIFY rank_1 = 1
  )
  GROUP BY ALL
  ORDER BY 2,1
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_total_ventas_campana`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS


  SELECT ventas.*
    , CASE WHEN (vc.ventas - SAFE_CAST(Tramo_desde AS INT64)) > 0 THEN 'APLICA' ELSE 'NO_APLICA' END AS APLICA_CAMPANA
    , vc.ventas AS total_ventas
    , RANK () OVER (PARTITION BY ventas.ID_SUBCAMPANA  ORDER BY SAFE_CAST(ventas.Tramo_desde AS INT64) DESC, SAFE_CAST(ventas.Upfront AS INT64) DESC) AS rank_2
  FROM(
    SELECT cam_nav.ID_SUBCAMPANA, cam_nav.Tramo_desde, cam_nav.Upfront
        , cam_nav.PRODUCTO, cam_nav.SUBPRODUCTO, cam_nav.tipo, cam_nav.TIPO_CAMPANA, cam_nav.Id_Campana
        , cam_nav.CLIENTE AS cliente, cam_nav.CODIGO_NAVISION as CODIGO_NAVISION
        , ven.service_type, ven.technology_ds
        , cam_nav.DosP_TresP AS bundle_type

    FROM `mm-commissions-reporting.TEMP.B2B_ventas` ven
      INNER JOIN `mm-commissions-reporting.TEMP.B2B_campanas_Navision` cam_nav
        ON  cam_nav.sfid_id = ven.sfid_id
        AND cam_nav.PROXIMO_CIERRE like '2025%'  --Test
      LEFT JOIN `mm-commissions-reporting.TEMP.B2B_tarifas` tar
        ON  tar.tariff_id = ven.tariff_id
    WHERE cam_nav.TIPO_CAMPANA = 'VOLUMEN'
      AND ven.activation_date >= '2025-05-01'
      AND ven.activation_date <= '2025-05-31'
      AND cam_nav.PRODUCTO IN ('MOVIL')
      AND ven.service_type IN ('BROADBAND') 
      AND ven.technology_ds = 'FTTH'
--      AND cam_nav.ID_SUBCAMPANA in (2830)    
    GROUP BY ALL
  ) ventas
  LEFT JOIN `mm-commissions-reporting.TEMP.B2B_ventas_campana` vc
    ON vc.ID_SUBCAMPANA = ventas.ID_SUBCAMPANA
  QUALIFY rank_2 = 1
  ;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_campanas`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  SELECT 
      Id_Campana
    , CODIGO_XENA AS CODIGO
    , sfid_id
    , tipo
    , MAXIMO_UPFRONT
    , INICIO_CAMPANA
    , FIN_CAMPANA
    , CLIENTE
    , PRODUCTO
    , SUBPRODUCTO
    , ID_SUBCAMPANA
    , TIPO_CAMPANA
    , INICIO_SUBCAMPANA
    , FIN_SUBCAMPANA
    , MAXIMO_UPFRONT_SC
    , TIPO_ALTA
    , TIPO_CIERRE
    , PROXIMO_CIERRE
    , Id_Rango
    , Tipo_Rango
    , Tipo_Calculo
    , Tramo_desde
    , tramo_desde_generico
    , ROUND(Upfront,4) AS Upfront
    , 'XENA' AS origen

  FROM `mm-commissions-reporting.TEMP.B2B_campanas_Xena`

  UNION ALL

  SELECT 
      Id_Campana
    , CODIGO_NAVISION AS CODIGO
    , sfid_id
    , tipo
    , MAXIMO_UPFRONT
    , INICIO_CAMPANA
    , FIN_CAMPANA
    , CLIENTE
    , PRODUCTO
    , SUBPRODUCTO
    , ID_SUBCAMPANA
    , TIPO_CAMPANA
    , INICIO_SUBCAMPANA
    , FIN_SUBCAMPANA
    , MAXIMO_UPFRONT_SC
    , TIPO_ALTA
    , TIPO_CIERRE
    , PROXIMO_CIERRE
    , Id_Rango
    , Tipo_Rango
    , Tipo_Calculo
    , Tramo_desde
    , tramo_desde_generico
    , Upfront
    , 'NAVISION' AS origen
  FROM `mm-commissions-reporting.TEMP.B2B_campanas_Navision`
  ;

END