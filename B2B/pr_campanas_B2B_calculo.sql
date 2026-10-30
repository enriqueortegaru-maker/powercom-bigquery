BEGIN

--CALL `mm-commissions-reporting.B2B.pr_campanas_B2B_calculo` ('2025-08-01','2025-08-31')

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_campana_aplica_lista_volumen`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

    SELECT ID_SUBCAMPANA
      , Id_Campana
      , Tramo_desde
      , Upfront
      , ventas
      , APLICA_CAMPANA
      , PRODUCTO
      , SUBPRODUCTO
      , tipo
      , TIPO_CAMPANA  --tipo
      , cliente
      , bundle_type
    FROM (
      SELECT *
        , CASE WHEN (ventas - SAFE_CAST(Tramo_desde AS INT64)) > 0 THEN 'APLICA' ELSE 'NO_APLICA' END AS APLICA_CAMPANA
        , RANK () OVER (PARTITION BY ID_SUBCAMPANA, bundle_type ORDER BY SAFE_CAST(Tramo_desde AS INT64) DESC) AS rank         
      FROM(
          SELECT cam_nav.ID_SUBCAMPANA, cam_nav.Tramo_desde, cam_nav.Upfront--, ven.sfid_id
            , cam_nav.PRODUCTO, cam_nav.SUBPRODUCTO, cam_nav.tipo, cam_nav.TIPO_CAMPANA, cam_nav.Id_Campana
            , cam_nav.CLIENTE AS cliente, ven.bundle_type
            , ven.total_ventas as ventas
        FROM `mm-commissions-reporting.TEMP.B2B_total_ventas_campana` ven
          INNER JOIN `mm-commissions-reporting.TEMP.B2B_campanas_Navision` cam_nav
--            ON  cam_nav.CODIGO_NAVISION = ven.CODIGO_NAVISION
            ON  cam_nav.ID_SUBCAMPANA = ven.ID_SUBCAMPANA
            AND cam_nav.PROXIMO_CIERRE like '2025%'
        WHERE cam_nav.TIPO_CAMPANA = 'VOLUMEN'
          AND cam_nav.Tipo_Rango = 'VOLUMEN'
          AND ven.technology_ds = 'FTTH'
--          AND ven.ID_SUBCAMPANA = 2830
          AND ven.service_type IN ('BROADBAND','FIX') 
/*
          AND cam_nav.PRODUCTO IN ('BANDA ANCHA') AND ven.service_type IN ('BROADBAND','FIX') 
          AND (
               (cam_nav.PRODUCTO IN ('BANDA ANCHA') AND cam_nav.SUBPRODUCTO IN ('2P') AND ven.bundle_type IN ('2P'))
            OR (cam_nav.PRODUCTO IN ('BANDA ANCHA') AND UPPER(cam_nav.SUBPRODUCTO) IN ('2P Y 3P') AND ven.bundle_type IN ('2P'))
            OR (cam_nav.PRODUCTO IN ('BANDA ANCHA') AND cam_nav.SUBPRODUCTO IN ('2P Y 3P','2P y 3P') AND ven.bundle_type NOT IN ('2P') AND ven.service_type IN ('BROADBAND'))
            OR (cam_nav.PRODUCTO IN ('BANDA ANCHA') AND cam_nav.SUBPRODUCTO IN ('3P') AND ven.bundle_type NOT IN ('2P') AND ven.service_type IN ('BROADBAND'))
            OR (cam_nav.PRODUCTO IN ('BANDA ANCHA') AND cam_nav.SUBPRODUCTO IN ('FIJA') AND ven.service_type IN ('FIX'))
          )
*/
        GROUP BY ALL
      )
      QUALIFY rank = 1
    )
  ORDER BY 1
  ;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_transacciones_campana`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) ) AS
    
      -------------------------------------------
      -- PRIMER TIPO DE CAMPAÑA                --
      -- ESTADO_CIERRE IN ('ACTIVA','CERRADA') --
      -------------------------------------------

    SELECT 
        SUBSTRING(scmp.marca,1,3)||'CAMP' || '_' || '20250501' '_' || 'CANAL' || '_' || ROW_NUMBER () OVER () AS commission_id
      , 'calculado' AS estado
      , '2025-05-01' AS mes_liquidado
      , 20250501 AS id_mes
      , CASE WHEN scmp.marca = 'ADAMO' THEN 'B2B - Adamo'
             WHEN scmp.marca = 'ALTERNA' THEN 'B2B - Alterna'
             WHEN scmp.marca = 'CABLEMOVIL' THEN 'B2B - Cablemovil'
             WHEN scmp.marca = 'HITS' THEN 'B2B - Hits'
             WHEN scmp.marca = 'MARBLANCA' THEN 'B2B - Marblanca'
             WHEN scmp.marca = 'NASH' THEN 'B2B - Nash'
             WHEN scmp.marca = 'NETLLAR' THEN 'B2B - Netllar'
             WHEN scmp.marca = 'PARLEM' THEN 'B2B - Parlem'
             WHEN scmp.marca = 'POPULOOS' THEN 'B2B - Populoos'
             WHEN scmp.marca = 'SWENO' THEN 'B2B - Sweno'             
        ELSE ('B2B - ' || scmp.marca) END AS agrupacion_canal
      , CASE WHEN scmp.marca = 'ADAMO' THEN 'ADA'
             WHEN scmp.marca = 'ALTERNA' THEN 'ALT'
             WHEN scmp.marca = 'CABLEMOVIL' THEN 'CM'
             WHEN scmp.marca = 'HITS' THEN 'HIT'
             WHEN scmp.marca = 'MARBLANCA' THEN 'MRB'
             WHEN scmp.marca = 'NASH' THEN 'NAS'
             WHEN scmp.marca = 'NETLLAR' THEN 'B2B - NET'
             WHEN scmp.marca = 'PARLEM' THEN 'PAR'
             WHEN scmp.marca = 'POPULOOS' THEN 'B2B - POP'
             WHEN scmp.marca = 'SWENO' THEN 'B2B - SWE'             
        ELSE UPPER(SUBSTR(scmp.marca,1,3)) END AS canal
      , 'D - Camp. Cable ' || cpn.id_subcampana AS concepto
      , 'UPF' AS tipo_concepto
--      , vr.n_ventas AS UNIDADES
      , cpn.ventas AS UNIDADES
--      , ROUND((vr.n_ventas * cpn.upfront),6) AS comision
      , ROUND((cpn.ventas * cpn.upfront),6) AS comision
      , SFID_NAVISION AS id_comisionista
      , CAST (NULL AS STRING) AS distribuidor
      , SFID_NAVISION AS sfid_id
      , SFID_NAVISION AS seller
      , cpn.cliente AS nombre_comercio
      , cpn.cliente AS razon_social
      , 'TBD' AS cif
      , 'TBD' AS zona_fiscal
      , scmp.marca AS marca
      , 'TBD' AS service_type
      , CAST(NULL AS STRING) AS phone_nm
      , CAST(NULL AS STRING) AS tariff_id
      , CAST(NULL AS STRING) AS tariff_ds
      , CAST(NULL AS STRING) AS service_id
      , CAST(NULL AS STRING) AS account_id
      , CAST(NULL AS STRING) AS customer_id
      , CAST(NULL AS STRING) AS line_type_ds
      , CAST(NULL AS STRING) AS bundle_type
      , CAST(NULL AS STRING) AS technology_ds
      , 'TBD' AS billing_type_ds
      , CAST(NULL AS STRING) AS sale_date
      , '2025-05-01' AS activation_date
      , CAST(NULL AS STRING) AS deactivation_date
      , CAST(NULL AS STRING) AS order_id
      , 'TBD' AS order_type_agg
      , 'TBD' AS cod_segmento
      , CASE WHEN UPPER(scmp.marca) IN ('ADAMO','CABLEMOVIL','NASH','NETLLAR') THEN '05'
             WHEN UPPER(scmp.marca) IN ('ALTERNA','HITS','MARBLANCA','PARLEM','POPULOOS') THEN '09'
             WHEN UPPER(scmp.marca) IN ('SWENO') THEN '20'
                         ELSE CAST(NULL AS STRING) END AS cod_marca
      , 'TBD' AS cod_tipo_contrato
      , CASE WHEN UPPER(scmp.marca) IN ('ADAMO','CABLEMOVIL') THEN '022'
             WHEN UPPER(scmp.marca) IN ('POPULOOS') THEN '039'
             WHEN UPPER(scmp.marca) IN ('HITS','NASH','NETLLAR') THEN '999'
             WHEN UPPER(scmp.marca) IN ('ALTERNA','SWENO') THEN '39'
             WHEN UPPER(scmp.marca) IN ('MARBLANCA','PARLEM') THEN '39'
             ELSE 'TBD' END AS cod_producto --PENDIENTE DETALLE
      , CASE WHEN scmp.marca IN ('SWENO') THEN '25' ELSE '30' END AS cod_canal
      , (scmp.ID_SUBCAMPANA || ' ' || scmp.SUBCAMPANA) AS campaign_code
      , CAST(NULL AS STRING) AS serial_number
      , CAST(10 AS INT64) AS tax_base
      , CAST(NULL AS STRING) AS claim_code
      , CAST(NULL AS STRING) AS process_code
      , CAST(NULL AS STRING) AS comments
      , 'C_CAMPANAS' AS facturador  ---- FALTA FACTURADOR - ENRIQUE ----
      , CAST(NULL AS STRING) AS proceso_sap
      , CAST(NULL AS STRING) AS id_registro
      , CAST(NULL AS STRING) AS invoice_id
      , 'X001' AS sociedad, CAST(NULL AS STRING) AS bp
      , CAST(NULL AS STRING) AS cuenta_contable
      , CAST(NULL AS STRING) AS centro_coste
      , CAST(NULL AS STRING) AS documento_sap
      , CAST(NULL AS STRING) AS documento_sap_posicion
      , CAST(NULL AS STRING) AS fecha_contabilizacion
      ,  CURRENT_TIMESTAMP() AS creado
      , CAST(NULL AS STRING) AS modificado
      , CAST(NULL AS STRING) AS id_factura_drive
      , CAST(NULL AS STRING) AS emails_acceso_trazabilidad

      FROM `mm-commissions-reporting.TEMP.B2B_ventas_campana` vc, UNNEST (SPLIT(REPLACE(CODIGO_NAVISION,' ',''),',')) AS SFID_NAVISION

      INNER JOIN `mm-commissions-reporting.TEMP.B2B_campana_aplica_lista_volumen` cpn
        ON  vc.ID_SUBCAMPANA = cpn.ID_SUBCAMPANA

      INNER JOIN `mm-commissions-reporting.B2B.gs_global_subcampana` scmp
        ON  scmp.ID_CAMPANA = cpn.Id_Campana
        AND cpn.ID_SUBCAMPANA = scmp.ID_SUBCAMPANA
        AND scmp.OBJETIVO_KPI_UPFRONT IN ('BRUTAS','NETAS')               
        AND scmp.TIPO_ALTA IN ('TODAS','PORTABILIDAD','FIDELIZACION'
                              ,'MIGRACIÓN','PORTABILIDADES')              

      -- LEFT JOIN `mm-commissions-reporting.TEMP.B2B_ventas_resumen` vr
      --   ON  vr.sfid_id = SFID_NAVISION
  ;

END