BEGIN

--Procedimiento que unifica dos ficheros enviados desde JSM. Su almacenamiento está pensado para tablas históricas.

DECLARE mes_string, mes_liqui, qry, tabla_nombre,tabla_resumen STRING;
DECLARE mes DATE;

-- call `mm-commissions-reporting.B2B.pr_JSM_BLAVEO_FINANCIERO`();

SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes); -- 202504;
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET tabla_nombre  = CONCAT('mm-commissions-reporting.B2B.','JSM_BLAVEO_FINANCIERO_', mes_liqui, '');
SET tabla_resumen = CONCAT('mm-commissions-reporting.B2B.','JSM_BLAVEO_RESUMEN_', mes_liqui, '');

--Unificamos todas las pestañas de los dos excels

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.JSM_BLAVEO_FINANCIERO_ROW` AS 

  SELECT 
    'AMR_NO_FIRMADO' AS info, 
    *
  FROM `mm-commissions-reporting.TEMP.JSM_02_AMR_NO_FIRMADO`
  WHERE id_mes = mes_string

  UNION ALL

  SELECT 
    'GESTION_DE_CLIENTES' AS info,
    *
  FROM `mm-commissions-reporting.TEMP.JSM_03_GESTION_DE_CLIENTES` 
  WHERE id_mes = mes_string

  UNION ALL

  SELECT 
    'PRODUCTIVIDAD' AS info,
    *
  FROM `mm-commissions-reporting.TEMP.JSM_05_PRODUCTIVIDAD`
  WHERE id_mes = mes_string

  UNION ALL

  SELECT 
    'EXTRA_COMISION' AS info,
    *
  FROM `mm-commissions-reporting.TEMP.JSM_06_EXTRA_COMISION`
  WHERE id_mes = mes_string

  UNION ALL

  SELECT 
    'CAPTACION' AS info,
  *
  FROM `mm-commissions-reporting.TEMP.JSM_07_CAPTACION`
  WHERE id_mes = mes_string

  UNION ALL

  SELECT 
    'BAJAS' AS info,
    * EXCEPT(fecha_solicitud,fecha_alta,fecha_baja,importe_comision,observaciones),
    CAST(NULL AS STRING) AS dias_facturados,
    CAST(NULL AS STRING) AS cuotalineafactdetalle,
    CAST(NULL AS STRING) AS descuentocuotalineafacturadetalle_hmrd,
    CAST(NULL AS STRING) AS importetotal,
    fecha_solicitud,
    fecha_alta,
    fecha_baja,
    importe_comision,
    observaciones
  FROM `mm-commissions-reporting.TEMP.JSM_09_BAJAS`
  WHERE id_mes = mes_string

  UNION ALL

  SELECT 
    'CADENA' AS info,
    * EXCEPT(cadena)
  FROM `mm-commissions-reporting.TEMP.JSM_11_CADENA`
  WHERE id_mes = mes_string

  UNION ALL

  SELECT 
    'CALIDAD'                       AS info,
    _codigo_hismrdist               AS codigo,
    razonsocial_hmrd                AS entidad,
    nif_empdist                     AS entidad_cif,
    sfid_hmrd                       AS sfid_tienda,
    razonsocial_hmrd_1              AS nombre_tienda,
    poblacion_hmrd                  AS poblacion,
    operadoramarca_hmrd             AS operadora,
    fechaprocesamiento_hmrd         AS fecha_procesamiento,
    CAST(NULL AS STRING)            AS n_de_contrato,
    codcli_hmrd                     AS codigo_cliente,
    dni_cli                         AS dni_cliente,
    nombre_cli                      AS nombre_cliente,
    CAST(NULL AS STRING)            AS tipo_de_comision,
    servicio                        AS servicio,
    nummovil_hmrd                   AS n_de_telefono,
    CAST(NULL AS STRING)            AS bono,
    CAST(NULL AS STRING)            AS numeracion_bono,
    codpas_hmrd                     AS codigo_pas,
    CAST(NULL AS STRING)            AS codigo_pas_anterior,
    nombre_pro                      AS nombre_del_producto,
    nombre_promo                    AS promocion,
    CAST(NULL AS STRING)            AS tipo_de_cambio,
    CAST(NULL AS STRING)            AS dias_facturados,
    CAST(NULL AS STRING)            AS cuotalineafactdetalle,
    CAST(NULL AS STRING)            AS descuentocuotalineafacturadetalle_hmrdc,
    CAST(NULL AS STRING)            AS importetotal,
    fechasolicitudproducto_hmrd     AS fecha_solicitud,
    fechaaltaproducto_hmrd          AS fecha_alta,
    fechabajaproducto_hmrd          AS fecha_baja,
    comisioncaptacioncalculada_hmrd AS importe_comision,
    CAST(NULL AS STRING)            AS observaciones,
    id_mes
  FROM `mm-commissions-reporting.TEMP.JSM_21_CALIDAD`
  WHERE id_mes = mes_string
;

--Damos formato a la tabla general usando funciones y casteando columnas

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.JSM_BLAVEO_FINANCIERO`  AS 

  SELECT 
    mes_string AS id_mes,
    info,
    codigo,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(entidad)             AS entidad,
    entidad_cif,
    sfid_tienda,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(nombre_tienda)       AS nombre_tienda,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(poblacion)           AS poblacion,
    operadora,
    CAST(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', fecha_procesamiento) AS DATE)      AS fecha_procesamiento,
    n_de_contrato,
    codigo_cliente,
    dni_cliente,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(nombre_cliente)      AS nombre_cliente,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(tipo_de_comision)    AS tipo_de_comision,
    UPPER(servicio)                                                              AS servicio,
    n_de_telefono,
    bono,
    numeracion_bono,
    codigo_pas,
    codigo_pas_anterior,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(nombre_del_producto) AS nombre_del_producto,
    promocion,
    tipo_de_cambio,
    CAST(dias_facturados AS FLOAT64)                                             AS dias_facturados,
    CAST(cuotalineafactdetalle AS FLOAT64)                                       AS cuotalineafactdetalle,
    CAST(descuentocuotalineafacturadetalle_hmrd AS FLOAT64)                      AS descuentocuotalineafacturadetalle_hmrd,
    CAST(importetotal AS FLOAT64) AS importetotal,
    CAST(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S',fecha_solicitud) AS DATE)           AS fecha_solicitud,
    CAST(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S',fecha_alta) AS DATE)                AS fecha_alta,
    CAST(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S',fecha_baja) AS DATE)                AS fecha_baja,
    CAST(importe_comision AS FLOAT64)                                            AS importe_comision,
    observaciones,
  FROM `mm-commissions-reporting.TEMP.JSM_BLAVEO_FINANCIERO_ROW`
  WHERE 1=1
    AND id_mes = mes_string 
    AND codigo IS NOT NULL
;

--Damos formato a la tabla resumen usando funciones y casteando columnas

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.JSM_00_RESUMEN_ROW` AS

  SELECT 
    mes_string AS id_mes,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(entidad) AS entidad,
    `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(cif) AS cif,
    sfid,
    tipo,
    CAST(amr_si_firmado AS FLOAT64)      AS amr_si_firmado,
    CAST(amr_no_firmado AS FLOAT64)      AS amr_no_firmado,
    CAST(gestion_de_clientes AS FLOAT64) AS gestion_de_clientes,
    CAST(objetivos AS FLOAT64)           AS objetivos,
    CAST(productividad AS FLOAT64)       AS productividad,
    CAST(extra_comision AS FLOAT64)      AS extra_comision,
    CAST(captacion AS FLOAT64)           AS captacion,
    CAST(captacion_tv AS FLOAT64)        AS captacion_tv,
    CAST(bajas AS FLOAT64)               AS bajas,
    CAST(bajas_tv AS FLOAT64)            AS bajas_tv,
    CAST(cadena AS FLOAT64)              AS cadena,
    CAST(bajas_cadena AS FLOAT64)        AS bajas_cadena,
    CAST(mantenimiento__i_m_ AS FLOAT64) AS mantenimiento__i_m_,
    CAST(instalacion__i_m_ AS FLOAT64)   AS instalacion__i_m_,
    CAST(actuacion__i_m_ AS FLOAT64)     AS actuacion__i_m_,
    CAST(sla__i_m_ AS FLOAT64)           AS sla__i_m_,
    CAST(mantenimiento__i_i_ AS FLOAT64) AS mantenimiento__i_i_,
    CAST(instalacion__i_i_ AS FLOAT64)   AS instalacion__i_i_,
    CAST(actuacion__i_i_ AS FLOAT64)     AS actuacion__i_i_,
    CAST(sla__i_i_ AS FLOAT64)           AS sla__i_i_,
    CAST(total AS FLOAT64)               AS total,
  FROM `mm-commissions-reporting.TEMP.JSM_00_RESUMEN`
  WHERE 1=1
    AND id_mes = mes_string
    AND cif IS NOT NULL
;
--Montamos la query de creación de la tabla mensual/
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.JSM_BLAVEO_FINANCIERO`';
  EXECUTE IMMEDIATE qry
;
--Montamos la query de creación de la tabla resumen mensual/
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_resumen ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.JSM_00_RESUMEN_ROW`';
  EXECUTE IMMEDIATE qry
;
END