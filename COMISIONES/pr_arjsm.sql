BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARJSM';

SET canales_pr = ['JSM'];

-- call `mm-commissions-reporting.COMISIONES.pr_arjsm`(202606,['JSM']);

ASSERT EXISTS(--No está en App Script

    SELECT DISTINCT  data_month_id
    FROM  `mm-datamart-kd.COMMISSIONS.commissions_jsm_*`
    WHERE data_month_id = mes_string

  ) AS 'Todavía no está creada la tabla origen del mes correspondiente'
  ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_comisiones_arjsm` AS 

-- -- Verificar antes de ejecutar que está cargado el sueldo Nescafé en NOMBRE_PRODUCTO = 'Acuerdo comercial por supervision y gestion'

WITH 
  distribuidores AS (
    SELECT DISTINCT sfid, documento
    FROM `mm-commissions-reporting.JUNTOS_SOMOS_MAS.DISTRIBUIDORES`
    WHERE Comisiona = TRUE
  )

  SELECT a.* EXCEPT(IMPORTE_COMISION, SERVICIO, OPERADORA, TELEFONO, NUMERO_FIJO, fecha_instalacion,TIPO_COMISION,TIPO_CAMBIO),
    CAST(REPLACE(a.IMPORTE_COMISION,',','.') as FLOAT64) AS IMPORTE_COMISION_NUM,
    CASE 
      WHEN a.SERVICIO = 'MÓVIL' THEN 'MOVIL'
      WHEN a.SERVICIO = 'TELEVISIÓN' THEN 'TV'
      WHEN a.NOMBRE_PRODUCTO = 'ACUERDO COMERCIAL POR SUPERVISIÓN Y GESTIÓN' THEN 'WIMAX'
      ELSE UPPER(a.SERVICIO)
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
      WHEN a.cif_entidad = 'B23759319' THEN 'SI'
      WHEN a.cif_entidad = 'B23615461' THEN 'SI'
      -- WHEN a.cif_entidad IN ('B23759319','B23733645','75101118T','B23615461') THEN 'AMR'        
      WHEN c.TIPO_CONCEPTO IN ('AIR1','AIR3','CUR1','CUR3') AND a.cif_entidad = '75101118T' THEN 'AMR'
      --WHEN c.TIPO_CONCEPTO IN ('AIR1','AIR3','CUR1','CUR3') AND a.cif_entidad = 'B23615461' AND a.sfid != 'BV123450' THEN 'AMR'
      WHEN a.cif_entidad = 'B40629958'                                        THEN 'NO-IMPAGO'
      WHEN a.cif_entidad = 'B86978905'                                        THEN 'NO-SPFTARIFA'
      WHEN a.operadora = 'SCHEDIA' AND a.ENTIDAD = 'CENTRAL SCHEDIA 2'        THEN 'NO-SCHEDIA'
      WHEN a.operadora = 'BETISMOVIL'                                         THEN 'NO-BETISMOVIL'
    ELSE 'SI'
    END AS AUTOFACTURA,
    e.SOCIEDAD AS SOCIEDAD,
    -- CASE
    --   WHEN a.OPERADORA IN ('SUROESTE', 'DCOOP', 'ASC229200') THEN '8311'
    --   WHEN a.cif_entidad ='B86978905'THEN '8322'
    --   ELSE '8300'
    -- END AS SOCIEDAD,
    COALESCE(TELEFONO,NUMERO_FIJO) AS TELEFONO,
    b.* EXCEPT(OPERADORA,CECO),
    c.* EXCEPT(TIPO_CONCEPTO),
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
      WHEN a.TIPO_COMISION = "CAPTACION TIENDA RETRO"           THEN "RETROACCION CAPTACION" --MIRAR SI RETRO SON EN NEGATIVO, VERIFICAR
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
    -- CASE
    --   WHEN a.entidad LIKE 'DOMOCOR%' THEN 'DISTRIBUCIÓN'
    --   WHEN UPPER(e.canal) IS NULL THEN 'NO CRUZA'
    --   ELSE UPPER(e.canal)
    -- END AS CANAL

  --ACTUALIZAR EL FROM TODOS LOS MESES A LA NUEVA TABLA

  FROM `mm-datamart-kd.COMMISSIONS.commissions_jsm_*`  a
  LEFT JOIN `mm-commissions-reporting.JUNTOS_SOMOS_MAS.MAPEO_CECO` b ON A.OPERADORA = b.OPERADORA
  LEFT JOIN `mm-commissions-reporting.JUNTOS_SOMOS_MAS.MAPEO_COMISIONES` c ON (c.CECO = b.CECO AND c.TIPO_COMISION = a.TIPO_COMISION AND c.TIPO_CAMBIO = a.TIPO_CAMBIO) OR (c.CECO = b.CECO AND c.TIPO_COMISION = a.TIPO_COMISION AND c.TIPO_CAMBIO = '-')
  LEFT JOIN (SELECT documento, 
              CASE
                WHEN UPPER(billing_dealer) IN ("SAC BLAVEO","SAC AHIMAS","SAC BLAVEO","CENTRAL ALMA","SAC TVALCANTARILLA","CENTRAL ASTRONETZ","CENTRAL REBELOAK","CENTRAL BLU",          "CENTRAL  BLAVEO","SAC CLM","SAC ECONECTIA","SAC LAJANDA","SAC NEXT","SAC OLACABLE","SAC ORIOLFIBRA","SAC POPULOOS","SAC SCH","SAC SUROESTE","CENTRAL VINFORTEL","CENTRAL WOL")             THEN "GESTELCOM"
              ELSE UPPER(billing_dealer)
            END AS  billing_dealer, 
            sfid,
            SOCIEDAD,
            canal 
            FROM `mm-commissions-reporting.JUNTOS_SOMOS_MAS.DISTRIBUIDORES`
            --WHERE comisiona IS TRUE  Esta comentado porque no hacemos un JOIN para los que no comisionan
            GROUP BY ALL
          ) e ON(e.documento = a.cif_entidad AND e.sfid = a.sfid) --e.billing_dealer= UPPER(a.entidad)
  WHERE a.cif_entidad IS NOT NULL 
    AND a.sfid != 'SVINTCENTRAL'
    AND a.data_month_id = mes_string
    --AND a.data_month_id = '202410'
  ;

  ASSERT NOT EXISTS(
    SELECT cif_entidad, entidad, sfid
    FROM `mm-commissions-reporting.TEMP.base_comisiones_arjsm`
    WHERE canal LIKE '%NO CRUZA'
    GROUP BY ALL
  ) AS 'Faltan distribuidores por definir'
  ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pre_comisiones_arjsm` AS 

  WITH base_8300 AS (
      
    SELECT 
     'calculado' AS estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AS mes_liquidado, 
      CAST(mes_string AS INT64)AS id_mes, 
      'Populoos'               AS agrupacion_canal,
      'JSM'                    AS canal,
      -- CONCAT(SUBSTR(data_month_id, (LENGTH(data_month_id)-3)),' ',base.SFID,' Comisiones ', CASE WHEN TIPO_CONCEPTO LIKE 'AIR%' THEN 'Cartera' ELSE 'Upfront' END) AS concepto,
      CASE
        WHEN tipo_concepto LIKE 'AIR%' THEN
          CASE 
            WHEN servicio = 'FIBRA' OR TIPO_CONTRATO IN ('60','61','66','67') THEN 'C - Gestion Cartera 3P'
            WHEN servicio = 'FIJO'  OR TIPO_CONTRATO LIKE '6%'                THEN 'C - Gestion Cartera 2P'
            WHEN servicio = 'MOVIL' OR TIPO_CONTRATO = '20'                   THEN 'C - Gestion Cartera Movil'
            WHEN servicio = 'TV'                                              THEN 'C - Gestion Cartera TV'
            --TV -- tipo_contrato = 20 MOVIL Que empiece 6% Cartera de fibra, LA 61 ES 3P y restO 2P. MIX BUndle type y cod_contrato.
            ELSE 'C - Gestion Cartera'
          END
        WHEN tipo_concepto LIKE 'UPF%' OR tipo_concepto IS NULL THEN 'D - Upfront'
        ELSE NULL
      END AS concepto,
      CASE
        WHEN tipo_concepto IS NULL THEN 'UPF1'
        ELSE tipo_concepto
      END AS tipo_concepto,
      1                        AS unidades,
      IMPORTE_COMISION_NUM     AS comision,
      base.SFID                AS id_comisionista,
      base.OPERADORA           AS distribuidor,
      base.SFID                AS sfid_id,
      base.SFID                AS seller,
      ENTIDAD                  AS nombre_comercio,
      ENTIDAD                  AS razon_social, 
      base.cif_entidad         AS cif,
      'PEN'                    AS zona_fiscal,
      CAST(NULL AS STRING)     AS cond_pago,
      CASE
        WHEN base.sociedad = '8311' THEN 'JUNTOS_SOMOS_8311'
        WHEN base.sociedad = '8322' THEN 'JUNTOS_SOMOS_8322'
        ELSE 'JUNTOS_SOMOS_8300'        
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
        WHEN SERVICIO = 'OTROS' THEN 'OTRS'
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
      IF(CAST(SUBSTR(FECHA_BAJA,1,10) AS DATE) IS NULL,'9999-12-31',CAST(SUBSTR(FECHA_BAJA,1,10) AS DATE))           AS deactivation_date,
      CAST(NULL AS STRING)     AS order_id,
      CAST(NULL AS STRING)     AS order_type_agg,
      '42'                     AS cod_segmento,
      MARCA                    AS cod_marca,
      TIPO_CONTRATO            AS cod_tipo_contrato,
      '27'                     AS cod_canal,
      '039'                    AS cod_producto,
      CASE
        WHEN TIPO_COMISION IS NULL AND IMPORTE_COMISION_NUM < 0 THEN 'RETRO'
        ELSE TIPO_COMISION            
      END AS campaign_code,
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
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad,
      CONCAT(SERVICIO,'/',comision_agrupada,'/',subtipo,'/',CANAL) AS info_ds
    FROM `mm-commissions-reporting.TEMP.base_comisiones_arjsm` base
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
      -- CASE
      --   WHEN (concepto LIKE '%Upfront%' and tipo_concepto IS NULL) OR tipo_concepto = 'UPF1' THEN 'UPF1'
      --   WHEN (concepto LIKE '%Cartera%' and tipo_concepto IS NULL) OR tipo_concepto = 'AIR1' THEN 'AIR1'
      --   ELSE tipo_concepto
      -- END AS tipo_concepto,
      tipo_concepto,
      unidades,
      comision,
      -- SUM(comision)   AS comision,
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
      id_factura_drive,
      emails_acceso_trazabilidad,
      info_ds
      FROM base_8300
      -- GROUP BY ALL
  )

  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
  FROM final
  WHERE comision != 0 AND claim_code NOT IN ('NO-IMPAGO','NO-SCHEDIA','NO-SPFTARIFA')
;

-- Creamos la tabla que será insertada en transacciones

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arjsm` AS

  SELECT * EXCEPT(info_ds)
  FROM `mm-commissions-reporting.TEMP.pre_comisiones_arjsm`

;

-- Eliminamos e insertamos la informacións histórica que se presenta en el DS de JSM con las especificaciones especiales de agrupación

  DELETE `mm-commissions-reporting.COMISIONES.commissions_jsm_b2b_new`
  WHERE id_mes = CAST(mes_string AS INT64)
  ;
  
  INSERT INTO `mm-commissions-reporting.COMISIONES.commissions_jsm_b2b_new`

    SELECT * EXCEPT(info_ds,emails_acceso_trazabilidad, commission_id),
      SPLIT(info_ds,'/') [OFFSET(0)] AS servicio,
      SPLIT(info_ds,'/') [OFFSET(1)] AS comision_agrupada,
      SPLIT(info_ds,'/') [OFFSET(2)] AS subtipo,
      SPLIT(info_ds,'/') [OFFSET(3)] AS canal_jsm
    FROM `mm-commissions-reporting.TEMP.pre_comisiones_arjsm`
;


--Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_arjsm',
  'ACTUALIZAR'
);

END