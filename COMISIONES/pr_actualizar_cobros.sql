BEGIN
-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_cobros`('');

----paso 1 recrear permisos

CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.permisos_cif_email_compensacion` AS

WITH cablemovil AS (
  SELECT
    cif,
    email,
    'B2B2C' AS agrupacion_canal,
    'CABLEMOVIL' AS origen
  FROM `mm-commissions-reporting.GS.b2b_cablemovil_acceso_trazabilidad`,
  UNNEST(SPLIT(emails, ',')) AS email   
),

marblanca AS (
  SELECT
    cif,
    email,
    'B2B2C' AS agrupacion_canal,
    'MARBLANCA' AS origen
  FROM `mm-commissions-reporting.TEMP.gs_B2B_Marblanca_ACCESO_TRAZA`,
  UNNEST(SPLIT(emails, ',')) AS email  
),
interno AS (
  SELECT
  c.cif,
  LOWER(TRIM(a.email)) AS email,
  'B2B2C' AS agrupacion_canal,
  'interno' AS origen
FROM (
  SELECT DISTINCT cif
  FROM `mm-commissions-reporting.GS.compensacion`
) c
CROSS JOIN (
  SELECT DISTINCT
    email,
   'B2B2C' AS  agrupacion_canal
  FROM `mm-commissions-reporting.COMISIONES.accesos_comisiones`
  WHERE email IS NOT NULL
  -- and agrupacion_canal like 'B2B%'
) a
)


SELECT DISTINCT
  cif,
  LOWER(TRIM(email)) AS email,
  'B2B2C' AS agrupacion_canal,
  -- origen
FROM (
  SELECT * FROM cablemovil
  UNION ALL
  SELECT * FROM marblanca
  union all
  SELECT * FROM interno
)
WHERE email IS NOT NULL
  AND email != ''

;


--paso 2 recrear tabla..


BEGIN

-- 1. BORRAR mes actual
DELETE FROM `mm-commissions-reporting.COMISIONES.visualizacion_compensacion`
WHERE fecha_mes >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 2 MONTH) 
  AND Id_registro NOT IN (
    SELECT
      CONCAT(
      CAST(id_mes AS STRING), '_',
      COALESCE(CAST(email AS STRING), ''), '_',
      COALESCE(CAST(a.cif AS STRING), ''), '_',
      REGEXP_REPLACE(CAST(Imp_a_remesar AS STRING), r'[€., ]', '')) 
    FROM `mm-commissions-reporting.GS.compensacion` a
      LEFT JOIN `mm-commissions-reporting.COMISIONES.permisos_cif_email_compensacion` b
      ON a.cif = b.cif
  ) ;


-- 2. INSERTAR mes actual
INSERT INTO `mm-commissions-reporting.COMISIONES.visualizacion_compensacion`

WITH nuevos_datos AS (
  SELECT
--    b.email,
    a.*, -- Recomiendo cambiar a.* por los campos específicos que necesites para evitar conflictos
    PARSE_DATE('%Y%m', a.id_mes) AS fecha_mes,
    b.agrupacion_canal,
    m.*, -- Recomiendo cambiar m.* por los campos específicos de maestro_grupo
    CONCAT(
      CAST(a.id_mes AS STRING), '_',
      COALESCE(CAST(b.email AS STRING), ''), '_',
      COALESCE(CAST(a.cif AS STRING), ''), '_',
--      REGEXP_REPLACE(CAST(a.Imp_a_remesar AS STRING), r'[€., ]', ''), '_',
      id_comisionista, '_', canal, '_', PROVINCIA, '_', fra_cliente
    ) AS Id_registro,
    CURRENT_TIMESTAMP() AS fecha_modificacion
  FROM `mm-commissions-reporting.GS.compensacion` a
  JOIN `mm-commissions-reporting.COMISIONES.permisos_cif_email_compensacion` b
    ON a.cif = b.cif
  LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` m
    ON a.cif = m.documento
--  WHERE PARSE_DATE('%Y%m', a.id_mes) >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 2 MONTH)
)

SELECT * 
FROM nuevos_datos
WHERE Id_registro NOT IN (
  -- Comprobamos contra la tabla DESTINO para no duplicar inserciones pasadas
  SELECT Id_registro 
  FROM `mm-commissions-reporting.COMISIONES.visualizacion_compensacion`
  WHERE Id_registro IS NOT NULL
);


--3. Tabla para QUOTTA
  --CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.visualizacion_compensacion_quotta` AS

  DELETE
  FROM `mm-commissions-reporting.COMISIONES.visualizacion_compensacion_quotta`
  WHERE 1 = 1;

  INSERT INTO `mm-commissions-reporting.COMISIONES.visualizacion_compensacion_quotta`
  SELECT CAST (NULL AS STRING) AS email, 
        id_mes, servicios, cif, fra_cliente, Fra_proveedor, Imp_fra_cli, Imp_fra_prov, Imp_a_remesar, fecha_remesa,
        fecha_mes, agrupacion_canal, id_comisionista, canal, comisiona, nombre_comercio, razon_social,
        documento, zona_fiscal, GERENTE_CUENTA, CUENTA_CLIENTE, GRUPO, PROVINCIA, SEGMENTO, 
        CONCAT (
          CAST(id_mes AS STRING), '_',
            COALESCE(CAST(cif AS STRING), ''), '_',
            fra_cliente, '_',
            Fra_proveedor
            --, '_', REPLACE(REPLACE(CAST(Imp_a_remesar AS STRING),'€',''),' ','')
        ) AS Id_registro, 
        fecha_modificacion
  FROM `mm-commissions-reporting.COMISIONES.visualizacion_compensacion`
  WHERE Imp_a_remesar IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY id_mes, servicios, fra_cliente, Fra_proveedor, Imp_fra_cli, Imp_fra_prov, Imp_a_remesar, fecha_remesa ORDER BY fecha_modificacion DESC) = 1;

END;
END