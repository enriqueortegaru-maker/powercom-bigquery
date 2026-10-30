BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARSV';

SET canales_pr = ['SV'];

-- call `mm-commissions-reporting.COMISIONES.pr_arsv`(202410,['SV']);

ASSERT EXISTS((--No está en App Script

    SELECT DISTINCT  data_month_id
    FROM  `mm-datamart-kd.COMMISSIONS.commissions_jsm_*`
    WHERE data_month_id = mes_string

  )) AS 'Todavía no está creada la tabla origen del mes correspondiente'
  ;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.base_comisiones_arsv` AS 

-- -- Verificar antes de ejecutar que está cargado el sueldo Nescafé en NOMBRE_PRODUCTO = 'Acuerdo comercial por supervision y gestion'

WITH 
  distribuidores AS (
    SELECT DISTINCT * EXCEPT(autofactura)
    FROM `mm-commissions-reporting.GS.DEALERS_SVINT`
    WHERE Comisiona = TRUE AND check_duplicados = '1'
  )

  SELECT a.* EXCEPT(IMPORTE_COMISION, SERVICIO, OPERADORA, TELEFONO, NUMERO_FIJO, fecha_instalacion, TIPO_COMISION, TIPO_CAMBIO),
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
    d.*

  --ACTUALIZAR EL FROM TODOS LOS MESES A LA NUEVA TABLA

  FROM `mm-datamart-kd.COMMISSIONS.commissions_jsm_*`  a
  LEFT JOIN `mm-commissions-reporting.JUNTOS_SOMOS_MAS.MAPEO_CECO` b ON A.OPERADORA = b.OPERADORA
  LEFT JOIN `mm-commissions-reporting.JUNTOS_SOMOS_MAS.MAPEO_COMISIONES` c ON (c.CECO = b.CECO AND c.TIPO_COMISION = a.TIPO_COMISION AND c.TIPO_CAMBIO = a.TIPO_CAMBIO) OR (c.CECO = b.CECO AND c.TIPO_COMISION = a.TIPO_COMISION AND c.TIPO_CAMBIO = '-')
  LEFT JOIN distribuidores d ON a.sfid = d.id_comisionista AND a.cif_entidad = d.documento
  WHERE a.cif_entidad IS NOT NULL 
    AND sfid = 'SVINTCENTRAL'
    AND data_month_id = mes_string
  ;

  ASSERT NOT EXISTS(--Si se modifica hay que actualizarlo también en App Script
    
    SELECT DISTINCT a.sfid, a.cif_entidad, a.entidad
    FROM `mm-commissions-reporting.TEMP.base_comisiones_arsv` a
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_SVINT` b ON a.sfid = b.id_comisionista AND a.cif_entidad = b.documento
    WHERE b.id_comisionista IS NULL 
      AND a.sfid != 'NULL'

  ) AS 'Faltan dealers por definir'; 

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arsv` AS


  WITH base_8300 AS (
      
    SELECT 
     'calculado' AS estado,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) AS mes_liquidado, 
      CAST(mes_string AS INT64)AS id_mes, 
      'B2B - Svint'            AS agrupacion_canal,
      'SV'                     AS canal,
      CONCAT(SUBSTR(data_month_id, (LENGTH(data_month_id)-3)),' ',base.SFID,' Comisiones ', CASE WHEN TIPO_CONCEPTO LIKE 'AIR%' THEN 'Cartera' ELSE 'Upfront' END) AS concepto,
      tipo_concepto,
      1                        AS unidades,
      IMPORTE_COMISION_NUM     AS comision,
      id_comisionista          AS id_comisionista,
      base.OPERADORA           AS distribuidor,
      id_comisionista          AS sfid_id,
      id_comisionista          AS seller,
      nombre_comercio          AS nombre_comercio,
      nombre_comercio          AS razon_social, 
      documento                AS cif,
      zona_fiscal              AS zona_fiscal,
      'SVINT'                  AS marca,
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
      IF(CAST(SUBSTR(FECHA_BAJA,1,10) AS DATE) IS NULL,'9999-12-31',CAST(SUBSTR(FECHA_BAJA,1,10) AS DATE)) AS deactivation_date,
      CAST(NULL AS STRING)     AS order_id,
      CAST(NULL AS STRING)     AS order_type_agg,
      '42'                     AS cod_segmento,
      MARCA                    AS cod_marca,
      TIPO_CONTRATO            AS cod_tipo_contrato,
      '27'                     AS cod_canal,
      '039'                    AS cod_producto,
      base.SERVICIO            AS campaign_code,
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
      '6101'                   AS sociedad,
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
    FROM `mm-commissions-reporting.TEMP.base_comisiones_arsv` base
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
      comision,
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
      emails_acceso_trazabilidad
      FROM base_8300
      GROUP BY ALL
  )

  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    *
  FROM final
  WHERE comision != 0 AND claim_code NOT IN ('NO-IMPAGO','NO-SCHEDIA','NO-SPFTARIFA');

-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_arsv',
  'ACTUALIZAR'
);

END