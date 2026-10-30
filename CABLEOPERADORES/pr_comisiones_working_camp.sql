BEGIN

DECLARE clave STRING; 

SET clave = 'CAMP';

-- DECLARE mes_pr DATE DEFAULT '2022-11-01';

CREATE OR REPLACE TABLE `mm-commissions-reporting.CABLEOPERADORES.comisiones_working_camp` AS 
  
  WITH base AS(

    SELECT DISTINCT 
      'X001'                      AS sociedad,
      a.CLIENTE                   AS id_comisionista,
      'DEA'                       AS tipo_comisionista,
      COALESCE(b.CIF, c.CIF)      AS CIF,
      COALESCE(b.zona_fiscal, c.zona_fiscal)  AS zona_fiscal,
      CASE 
        WHEN b.id_comisionista IS NOT NULL OR c.id_comisionista IS NOT NULL THEN ('AIRT')
        ELSE NULL
      END                         AS tipo_concepto,
      CASE 
        WHEN b.id_comisionista IS NOT NULL OR c.id_comisionista IS NOT NULL THEN ('C - Gestion Cartera Campaña')
        ELSE NULL
      END                         AS descripcion_concepto,
      a.LINEAS                    AS uds,
      ROUND(a.COMISION,2)         AS importe_base,
      'EUR'                       AS moneda,
      'C'                         AS via_pago,
      'Z001'                      AS cond_pago,
      '30'                        AS cod_canal,
      CASE 
        WHEN TIPO_SERVICIO = 'FIX' THEN '041'
        ELSE '039'   
      END AS cod_producto,
      CASE 
        WHEN a.TIPO_SERVICIO = 'FIX'     THEN '61' 
        WHEN a.TIPO_SERVICIO = 'MOBILE' THEN '20' 
      END                         AS cod_tipo_contrato,
      '09'                        AS cod_marca,
      '999'                       AS cod_operador,
      '42'                        AS cod_segmento,
      'C_MANUAL'                  AS facturador,
      COALESCE(b.clasificacion_concepto, c.clasificacion_concepto) AS clasificacion_concepto,
      'CABLEOPERADORES'           AS canal,
      CAST(NULL AS STRING)        AS subscription_id,
      CAST(NULL AS STRING)        AS product_type,
      CASE
        WHEN a.TIPO_PAQUETE = 'MOBILE ONLY' THEN 'MO'   
        WHEN a.TIPO_PAQUETE = '3P'          THEN 'FMC'    
        ELSE a.TIPO_PAQUETE
      END AS bundle_type,
      CAST(NULL AS STRING)        AS msisdn,
      CAST(NULL AS DATE)          AS fecha_activacion,
      CAST(NULL AS DATE)          AS fecha_baja,
      CAST(NULL AS STRING)        AS account_id,
      a.CLIENTE                   AS customer_id,
      a.CLIENTE                   AS sfid_unico,
      a.CLIENTE                   AS tienda,
      a.CLIENTE                   AS distribuidor,
      mes_pr                      AS fecha,
      CASE
        WHEN a.TIPO_PAQUETE = 'MOBILE ONLY' THEN 'MO'   
        WHEN a.TIPO_PAQUETE = '3P'          THEN 'FMC'    
        ELSE a.TIPO_PAQUETE
      END                         AS agrupacion_cod_tipo_contrato,
      'Cableoperadores'           AS segmento,
      CAST(NULL AS STRING)        AS razon_social,
      a.CUENTA_CLIENTE            AS nombre_comercio,
      COALESCE(b.marca, c.marca)  AS marca,
      CAST(NULL AS STRING)        AS order_id,
      CAST(NULL AS STRING)        AS Product_id,
      CAST(NULL AS STRING)        AS Product,
      CAST(NULL AS STRING)        AS user_id,
      a.ID_CAMPANA                AS campaign_code,
      CAST(NULL AS STRING)        AS claim_code,
      CAST(NULL AS STRING)        AS process_code,
      CAST(NULL AS STRING)        AS comments,
      -- ROUND(a.COMISION,2)/a.LINEAS AS unitario,
      -- DATE_DIFF(a.fin_subcampana,a.inicio_subcampana,MONTH)+1 AS duracion_campana

    FROM `mm-commissions-reporting.CABLEOPERADORES.campañas` a
    LEFT JOIN `mm-commissions-reporting.CABLEOPERADORES.comisiones_working_arca` b ON a.CLIENTE = b.id_comisionista AND a.TIPO_CAMPANA IN('FACTURACION','MARKETING','EOP')
    LEFT JOIN `mm-commissions-reporting.CABLEOPERADORES.comisiones_working_arjo` c ON a.CLIENTE = c.id_comisionista AND a.TIPO_CAMPANA IN('FACTURACION','MARKETING','EOP')
    WHERE a.PERIODO_FACTURADO = mes_pr AND a.TIPO_CAMPANA IN ('FACTURACION','MARKETING','EOP')
  
  )

  SELECT
    'CAMP_CABL_'||format_date('%Y%m', mes_pr)||'_'||row_number () over() AS id_registro,
    *
  FROM base 
;

-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'CABLEOPERADORES.comisiones_working_camp',
  'CABLEOPERADORES.comisiones_working'
);

END