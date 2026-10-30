BEGIN

--EN DESUSO

--CALL `mm-commissions-reporting.COMISIONES.pr_commissions_jsm_b2b_new`()

CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.commissions_jsm_b2b_new` AS 

WITH 
  distribuidores AS (
    SELECT DISTINCT sfid, documento
    FROM `mm-commissions-reporting.JUNTOS_SOMOS_MAS.DISTRIBUIDORES`
    WHERE Comisiona = TRUE
  ),

  base AS (
    SELECT a.* EXCEPT(IMPORTE_COMISION, SERVICIO, OPERADORA, TELEFONO, NUMERO_FIJO, fecha_instalacion),
      CAST(REPLACE(a.IMPORTE_COMISION,',','.') as FLOAT64) AS IMPORTE_COMISION_NUM,
      CASE 
        WHEN a.SERVICIO = 'Móvil' THEN 'Movil'
        WHEN a.SERVICIO = 'Televisión' THEN 'TV'
        WHEN a.NOMBRE_PRODUCTO = 'Acuerdo comercial por supervision y gestion' THEN 'Wimax'
        ELSE a.SERVICIO
      END AS SERVICIO,
      CASE 
        WHEN a.NOMBRE_PRODUCTO = 'Acuerdo comercial por supervision y gestion' THEN 'SUROESTE'
        ELSE a.OPERADORA
      END AS OPERADORA,
      CASE
        WHEN a.cif_entidad = 'B23759319' AND a.SFID = 'BV123300' AND a.TIPO_COMISION  = 'CAPTACION' THEN 'SI'
        WHEN a.cif_entidad = 'B23733645' AND a.SFID = 'BV123320' AND a.TIPO_COMISION  = 'CAPTACION' THEN 'SI'
        WHEN a.cif_entidad = 'B23733645' AND a.SFID = 'BV223320' AND a.TIPO_COMISION  = 'CAPTACION' THEN 'SI'
        WHEN a.cif_entidad = 'B23759319' AND a.SFID = 'BV123338' AND a.TIPO_COMISION  = 'CAPTACION' THEN 'SI'
        WHEN a.cif_entidad = 'B23733645' AND a.SFID = 'BV123450'                                    THEN 'SI'
        WHEN a.cif_entidad = '75101118T' AND a.SFID = 'BV223660' AND a.TIPO_COMISION  = 'CAPTACION' THEN 'SI'
        WHEN a.cif_entidad = 'B23615461' AND a.SFID = 'BV123100' AND a.TIPO_COMISION  = 'CAPTACION' THEN 'SI'
        -- WHEN a.cif_entidad IN ('B23759319','B23733645','75101118T','B23615461') THEN 'AMR'        
        WHEN c.TIPO_CONCEPTO IN ('AIR1','AIR3','CUR1','CUR3') AND a.cif_entidad IN ('B23759319', '75101118T') THEN 'AMR'
        WHEN c.TIPO_CONCEPTO IN ('AIR1','AIR3','CUR1','CUR3') AND a.cif_entidad = 'B23615461' AND a.sfid != 'BV123450' THEN 'AMR'
        WHEN a.cif_entidad = 'B40629958'                                        THEN 'NO-IMPAGO'
        WHEN a.cif_entidad = 'B86978905'                                        THEN 'NO-SPFTARIFA'
        WHEN a.operadora = 'SCHEDIA' AND a.ENTIDAD = 'CENTRAL SCHEDIA 2'        THEN 'NO-SCHEDIA'
        WHEN a.operadora = 'BETISMOVIL'                                         THEN 'NO-BETISMOVIL'
      ELSE 'SI'
      END AS AUTOFACTURA,
        CASE
        WHEN a.OPERADORA IN ('SUROESTE', 'DCOOP', 'ASC229200') THEN '8311'
        WHEN a.cif_entidad ='B86978905'THEN '8322'
        ELSE '8300'
      END AS SOCIEDAD,
      COALESCE(TELEFONO,NUMERO_FIJO) AS TELEFONO,
      b.* EXCEPT(OPERADORA),
      c.* EXCEPT(TIPO_CONCEPTO, tipo_comision, tipo_cambio,ceco),
      CASE
        WHEN c.TIPO_CONCEPTO IN ('AIR1','AIR3','CUR1','CUR3') THEN 'AIR1'
        WHEN c.TIPO_CONCEPTO IN ('UPF1','UPF3') THEN 'UPF1'
      ELSE c.TIPO_CONCEPTO
      END AS TIPO_CONCEPTO,
      CASE
        WHEN a.fecha_instalacion = '0000-00-00' THEN NULL
        ELSE a.fecha_instalacion
      END AS fecha_instalacion,
      CASE
        WHEN a.TIPO_COMISION = "AMR NO FIRMADOS"                  THEN "CARTERA AMR (TECNICA + DISTRIBUCION)"
        WHEN a.TIPO_COMISION = "AMR SI FIRMADOS"                  THEN "CARTERA AMR (TECNICA + DISTRIBUCION)"
        WHEN a.TIPO_COMISION = "CAPTACION TIENDA"                 THEN "CAPTACION"
        WHEN a.TIPO_COMISION = "CAPTACION TIENDA RETRO"           THEN "RETROACCION CAPTACION"
        WHEN a.TIPO_COMISION = "EXTRA COMISION TIENDA"            THEN "CAPTACION"
        WHEN a.TIPO_COMISION = "EXTRA COMISION TIENDA RETRO"      THEN "RETROACCION CAPTACION"
        WHEN a.TIPO_COMISION = "GESTION DE CLIENTES CADENA"       THEN "CARTERA DISTRIBUCION"
        WHEN a.TIPO_COMISION = "GESTION DE CLIENTES CADENA RETRO" THEN "CARTERA DISTRIBUCION"
        WHEN a.TIPO_COMISION = "GESTION DE CLIENTES TIENDA"       THEN "CARTERA DISTRIBUCION"
        WHEN a.TIPO_COMISION = "OPERACIONES ACTUACION"            THEN "TECNICO"
        WHEN a.TIPO_COMISION = "OPERACIONES INSTALACION"          THEN "TECNICO"
        WHEN a.TIPO_COMISION = "OPERACIONES INSTALACION SLA"      THEN "TECNICO"
        WHEN a.TIPO_COMISION = "OPERACIONES MANTENIMIENTO"        THEN "CARTERA TECNICA"
        WHEN a.TIPO_COMISION = "PRODUCTIVIDAD TIENDA"             THEN "CAPTACION"
        WHEN a.TIPO_COMISION = "CALIDAD"                          THEN "CARTERA DISTRIBUCION"
        WHEN a.TIPO_COMISION = "CALIDAD RETRO"                    THEN "CARTERA DISTRIBUCION"
        WHEN a.TIPO_COMISION = "PRODUCTIVIDAD TIENDA RETRO"       THEN "RETROACCION CAPTACION"
        WHEN a.TIPO_COMISION = "CAPTACION"                        THEN "CAPTACION"
        WHEN a.TIPO_COMISION = "GESTION CLIENTES"                 THEN "CARTERA DISTRIBUCION"
        WHEN a.TIPO_COMISION = "REGULARIZACION GESTION CLIENTES"  THEN "CARTERA DISTRIBUCION"
        WHEN a.TIPO_COMISION = "PRODUCTIVIDAD"                    THEN "CAPTACION"
        WHEN a.TIPO_COMISION = "REGULARIZACION CAPTACION"         THEN "CAPTACION"
        WHEN a.TIPO_COMISION = "EXTRA COMISION"                   THEN "CAPTACION"
        ELSE 'DISTRIBUCION'
      END AS comision_agrupada,
      CASE
        WHEN (a.observaciones LIKE '%Importe fijo%') OR a.observaciones = 'Acuerdo comercial por supervision y gestion'THEN'IMPORTE FIJO'
        WHEN (a.Observaciones LIKE'%ampaña%') THEN 'CAMPAÑA'
        WHEN (a.Observaciones LIKE'%poyo%')THEN 'APOYO COMERCIAL'
        WHEN a.Entidad='CENTRAL SCHEDIA 2' THEN 'SIN COMISION'
        WHEN a.Entidad='Dream things S.L.'THEN 'CONTRATO'
        ELSE 'CONTRATO'
      END AS subtipo,
      CASE
        WHEN UPPER(a.entidad) IN ("SAC BLAVEO","SAC AHIMAS","SAC BLAVEO","CENTRAL ALMA","SAC TVALCANTARILLA","CENTRAL ASTRONETZ","CENTRAL REBELOAK","CENTRAL BLU",          "CENTRAL  BLAVEO","SAC CLM","SAC ECONECTIA","SAC LAJANDA","SAC NEXT","SAC OLACABLE","SAC ORIOLFIBRA","SAC POPULOOS","SAC SCH","SAC SUROESTE","CENTRAL VINFORTEL","CENTRAL WOL")    AND REGEXP_EXTRACT(a.fecha_solicitud, r'(\d{4}-\d{2}-\d{2})') < '2024-09-15'THEN "GESTELCOM" --TELEVENTA CENTRAL
        WHEN UPPER(a.entidad) IN ("SAC BLAVEO","SAC AHIMAS","SAC BLAVEO","CENTRAL ALMA","SAC TVALCANTARILLA","CENTRAL ASTRONETZ","CENTRAL REBELOAK","CENTRAL BLU",          "CENTRAL  BLAVEO","SAC CLM","SAC ECONECTIA","SAC LAJANDA","SAC NEXT","SAC OLACABLE","SAC ORIOLFIBRA","SAC POPULOOS","SAC SCH","SAC SUROESTE","CENTRAL VINFORTEL","CENTRAL WOL") AND REGEXP_EXTRACT(a.fecha_solicitud, r'(\d{4}-\d{2}-\d{2})') >= '2024-09-15'   THEN "INNOVACIONES TECNOLOGICAS DEL SUR"
        WHEN a.entidad LIKE 'DOMOCOR%' THEN 'DISTRIBUCIÓN'
        WHEN UPPER(e.canal) IS NULL THEN 'NO CRUZA'
        ELSE UPPER(e.canal)
      END AS CANAL,
      REGEXP_EXTRACT(fecha_solicitud, r'(\d{4}-\d{2}-\d{2})') AS fecha_solicitud_nueva

    --ACTUALIZAR EL FROM TODOS LOS MESES A LA NUEVA TABLA

    FROM `mm-datamart-kd.COMMISSIONS.commissions_jsm_*`  a
    LEFT JOIN `mm-commissions-reporting.JUNTOS_SOMOS_MAS.MAPEO_CECO` b ON A.OPERADORA = b.OPERADORA
    LEFT JOIN `mm-commissions-reporting.JUNTOS_SOMOS_MAS.MAPEO_COMISIONES` c ON (c.CECO = b.CECO AND c.TIPO_COMISION = a.TIPO_COMISION AND c.TIPO_CAMBIO = a.TIPO_CAMBIO) OR (c.CECO = b.CECO AND c.TIPO_COMISION = a.TIPO_COMISION AND c.TIPO_CAMBIO = '-')
    LEFT JOIN (SELECT DISTINCT documento, 
              canal 
              FROM `mm-commissions-reporting.JUNTOS_SOMOS_MAS.DISTRIBUIDORES`
              WHERE documento IS NOT NULL
              GROUP BY 1,2
            ) e ON(e.documento = a.cif_entidad) --SALVO ESTOS DE ARRIBA QUE SON TELEVENTA CENTRAL -- e.billing_dealer = UPPER(a.entidad) e.sfid = a.sfid 
    WHERE a.cif_entidad IS NOT NULL 
      AND a.sfid != 'SVINTCENTRAL'
  ),-- SELECT * FROM base --WHERE TIPO_CONCEPTO IS NULL
  --SELECT DISTINCT entidad, cif_entidad, sfid  FROM BASE WHERE canal = 'NO CRUZA'


  base_8300 AS (
      
    SELECT 
     'calculado' AS estado,
      PARSE_DATE('%Y%m',CAST(data_month_id AS STRING)) as mes_liquidado, 
      CAST(data_month_id AS INT64)AS id_mes, 
      'Populoos'               AS agrupacion_canal,
      'JSM'                    AS canal,
      CONCAT(SUBSTR(data_month_id, (LENGTH(data_month_id)-3)),' ',base.SFID,' Comisiones ', CASE WHEN TIPO_CONCEPTO LIKE 'AIR%' THEN 'Cartera' ELSE 'Upfront' END) AS concepto,
      tipo_concepto,
      1                        AS unidades,
      IMPORTE_COMISION_NUM     AS comision,
      base.SFID                AS id_comisionista,
      base.OPERADORA           AS distribuidor,
      base.SFID                AS sfid_id,
      base.SFID                AS seller,
      ENTIDAD                  AS nombre_comercio,
      ENTIDAD                  AS razon_social, 
      base.cif_entidad AS cif,
      --COALESCE(base.cif_entidad,base.dni_cliente)         AS cif,
      CAST(NULL AS STRING)     AS cond_pago,
      'PEN'                    AS zona_fiscal,
      CASE
        when base.sociedad = '8300' then 'JUNTOS_SOMOS_8300'
        when base.sociedad = '8311' then 'JUNTOS_SOMOS_8311'
        when base.sociedad = '8322' then 'JUNTOS_SOMOS_8322'
        ELSE 'X001'
      END                      AS marca,
      CASE
        WHEN SERVICIO = 'MÓVIL' THEN 'MOBILE'
        WHEN TIPO_CONCEPTO = 'UPFR' AND SERVICIO = 'FIJO' THEN 'INTERNET'
        WHEN SERVICIO = 'FIJO'  THEN 'INTERNET'
        WHEN SERVICIO = 'WIMAX' THEN 'INTERNET'
        WHEN SERVICIO = 'FIBRA' THEN 'INTERNET'
        WHEN SERVICIO = 'OTROS' AND nombre_producto LIKE '%CENTRALITA%' THEN 'CENTRAL'
        WHEN SERVICIO = 'OTROS' AND nombre_producto LIKE '%IP FIJA%' THEN 'INTERNET'
        WHEN SERVICIO = 'OTROS' AND nombre_producto LIKE '%BONO%' THEN 'MOBILE' 
        WHEN SERVICIO = 'OTROS' AND nombre_producto LIKE '%EXTENSIÓN SIN TERMINAL%' THEN 'EXTCENTRAL' 
        WHEN SERVICIO = 'OTROS' THEN 'OTROS'
        WHEN SERVICIO = 'FIX' THEN 'INTERNET'
        ELSE NULL
      END                      AS service_type,
      TELEFONO                 AS phone_nm,
      CAST(NULL AS STRING)     AS tariff_id,
      NOMBRE_PRODUCTO          AS tariff_ds,
      CAST(NULL AS STRING)     AS service_id,
      ID_CONTRATO              AS account_id,
      ID_CLIENTE               AS customer_id,
      CAST(NULL AS STRING)     AS line_type_ds,
      CASE
        WHEN TIPO_CONTRATO = '20' THEN 'MO'
        WHEN TIPO_CONTRATO = '62' THEN '2P'
        WHEN TIPO_CONTRATO = '63' THEN '2P'
        WHEN TIPO_CONTRATO = '64' THEN '2P'
        WHEN TIPO_CONTRATO = '66' THEN 'Adicional'
        WHEN TIPO_CONTRATO = '67' THEN 'Adicional'
        WHEN TIPO_CONTRATO = '60' THEN 'FMC'
        WHEN TIPO_CONTRATO = '61' THEN 'FMC'
        WHEN TIPO_CONTRATO = '98' THEN 'Pendiente'
      END AS bundle_type,
      CAST(NULL AS STRING)     AS technology_ds,
      CAST(NULL AS STRING)     AS billing_type_ds,
      CAST(SUBSTR(FECHA_PROCESAMIENTO,1,10) AS DATE)  AS sale_date,
      CAST(SUBSTR(FECHA_INSTALACION,1,10) AS DATE)    AS activation_date,
      CAST(SUBSTR(FECHA_BAJA,1,10) AS DATE)           AS deactivation_date,
      CAST(NULL AS STRING)     AS order_id,
      CAST(NULL AS STRING)     AS order_type_agg,
      '42'                     AS cod_segmento,
      MARCA                    AS cod_marca,
      TIPO_CONTRATO            AS cod_tipo_contrato,
      '27'                     AS cod_canal,
      '039'                    AS cod_producto,
      CONCAT(SERVICIO,'/',comision_agrupada,'/',subtipo,'/',CANAL) AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      CAST(NULL AS FLOAT64)    AS tax_base,
      base.AUTOFACTURA         AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CASE
        WHEN base.AUTOFACTURA IN ('NO-IMPAGO','NO-SCHEDIA','NO-SPFTARIFA','AMR') THEN 'rechazado'
        ELSE 'calculado'
      END                      AS comments,
      'C_MANUAL'               AS facturador,
      CAST(NULL AS STRING)     AS proceso_sap,
      CAST(NULL AS STRING)     AS id_registro,
      CAST(NULL AS STRING)     AS invoice_id,
      base.SOCIEDAD            AS sociedad,
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
    FROM base
  ), 

  final AS (
    SELECT
      -- CASE 
      --   WHEN comments = 'rechazado' THEN 'publicado'
      --   ELSE comments
      -- END AS estado,
      estado,
      mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      concepto,
      CASE
        WHEN (concepto LIKE '%Upfront%' and tipo_concepto IS NULL) OR tipo_concepto = 'UPF1' THEN 'UPF1'
        WHEN (concepto LIKE '%Cartera%' and tipo_concepto IS NULL) OR tipo_concepto = 'AIR1' THEN 'AIR1'
        ELSE tipo_concepto
      END AS tipo_concepto,
      unidades,
      SUM(ROUND(comision,2))   AS comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cif,
      zona_fiscal,
      cond_pago,
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
      deactivation_date,
      order_id,
      order_type_agg,
      cod_segmento,
      cod_marca,
      cod_tipo_contrato,
      cod_producto,
      cod_canal,
      campaign_code,
      serial_number,
      tax_base,
      claim_code,      
      process_code,
      comments,
      facturador,
      proceso_sap,
      id_registro,
      invoice_id,
      sociedad,
      bp,
      cuenta_contable,
      centro_coste,
      documento_sap,
      documento_sap_posicion,
      fecha_contabilizacion,
      creado,
      modificado,
      id_factura_drive
      FROM base_8300
      GROUP BY ALL
  )

  
  SELECT *,
    SPLIT(campaign_code,'/') [OFFSET(0)] AS servicio,
    SPLIT(campaign_code,'/') [OFFSET(1)] AS comision_agrupada,
    SPLIT(campaign_code,'/') [OFFSET(2)] AS subtipo,
    SPLIT(campaign_code,'/') [OFFSET(3)] AS canal_jsm,
  FROM final a
  WHERE a.comision != 0 
    AND a.claim_code NOT IN ('NO-IMPAGO','NO-SCHEDIA','NO-SPFTARIFA') 
    AND a.id_mes <= 202408
  
  UNION ALL

  SELECT *
  FROM `mm-commissions-reporting.TEMP.comisiones_jsm_transacciones`
  WHERE canal = 'JSM'
    AND id_mes >= 202409
    AND estado != 'calculado'
;

END