BEGIN


DECLARE mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

-- call `mm-commissions-reporting.COMISIONES.pr_armb_TUCA_G37`(202509)

--Actualizamos la tabla del grupo TUCA
CALL `mm-commissions-reporting.COMISIONES.pr_dealers_TUCA_CM_MB`();

-- SACAMOS LA POBLACION QUE HAY ENTRE PARENTESIS PARA QUEDARNOS CON LOS MUNICIPIOS
CREATE OR REPLACE TABLE `mm-commissions-reporting.GS.TUCA_G37_actualizada` AS
SELECT 
  t.* EXCEPT(poblacion),
  CASE
    -- Si contiene paréntesis, extrae el texto dentro
    WHEN REGEXP_CONTAINS(poblacion, r'\(.*\)') 
      THEN REGEXP_EXTRACT(poblacion, r'\(([^)]*)\)')
    ELSE poblacion
  END AS poblacion
FROM `mm-commissions-reporting.GS.TUCA_G37` t;



CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TUCA_G37_COMISION` AS
  
  WITH

  dealers_tuca AS (

    SELECT id_comisionista
    FROM `mm-commissions-reporting.B2B.DEALERS_TUCA_CM_MB`
    WHERE agrupacion_canal = 'B2B - Marblanca'

  ),


  gescal_12 AS (

    SELECT 
      a.tipo_via, 
      a.nombre_via as via, 
      a.ID_TECNICO_DE_LA_VIA AS g12, 
      a.PROVINCIA,
      a.POBLACION AS MUNICIPIO,
      b.comunidad_autonoma,
      a.POBLACION,
      b.capital_municipio_callejero_nombre,
      b.cod_provincia || b.cod_municipio AS ine_mun
    FROM `mm-commissions-reporting.GS.TUCA_G37_actualizada` a 
    LEFT JOIN `mm-datamart-kd.QOS.dm_gescal12_vias` b
    ON a.POBLACION = b.capital_municipio_callejero_nombre
    WHERE ID_TECNICO_DE_LA_VIA IS NOT NULL

    QUALIFY ROW_NUMBER() OVER(PARTITION BY g12 ORDER BY g12 ASC) = 1

  ), 

  bloques AS (
    SELECT 'Almacen' AS literal, 'A' AS cod_bloque
    UNION ALL SELECT 'Bloque', 'B'
    UNION ALL SELECT 'Casa', 'C'
    UNION ALL SELECT 'Edificio', 'E'
    UNION ALL SELECT 'Estacion', 'F'
    UNION ALL SELECT 'Garaje', 'G'
    UNION ALL SELECT 'Chalet', 'H'
    UNION ALL SELECT 'Pabellon', 'L'
    UNION ALL SELECT 'Nave', 'N'
    UNION ALL SELECT 'Parcela', 'P'
    UNION ALL SELECT 'Grupo', 'R'
    UNION ALL SELECT 'Sector', 'S'
    UNION ALL SELECT 'Torre', 'T'
    UNION ALL SELECT 'Zona', 'Z'
  ),
  plantas AS (
    SELECT 'AL' AS cod_planta, 'Altillo' AS literal
    UNION ALL SELECT 'AM', 'Almacen'
    UNION ALL SELECT 'AS', 'Ascensor'
    UNION ALL SELECT 'AT', 'Atico'
    UNION ALL SELECT 'BA', 'Bajo'
    UNION ALL SELECT 'BU', 'Bungalow'
    UNION ALL SELECT 'CH', 'Chalet'
    UNION ALL SELECT 'DU', 'Duplex'
    UNION ALL SELECT 'EN', 'Entresuelo'
    UNION ALL SELECT 'ET', 'Entreplanta'
    UNION ALL SELECT 'GA', 'Garaje'
    UNION ALL SELECT 'KI', 'Kiosco'
    UNION ALL SELECT 'MO', 'Modulo'
    UNION ALL SELECT 'LO', 'Local'
    UNION ALL SELECT 'NA', 'Nave'
    UNION ALL SELECT 'OF', 'Oficina'
    UNION ALL SELECT 'PR', 'Principal'
    UNION ALL SELECT 'PT', 'Puesto'
    UNION ALL SELECT 'SA', 'Sobreatico'
    UNION ALL SELECT 'SE', 'Semisotano'
    UNION ALL SELECT 'SO', 'Sotano'
    UNION ALL SELECT 'SS', 'Semisotano'
    UNION ALL SELECT 'S1', 'Sotano 1'
    UNION ALL SELECT 'S2', 'Sotano 2'
    UNION ALL SELECT 'S3', 'Sotano 3'
    UNION ALL SELECT 'S4', 'Sotano 4'
    UNION ALL SELECT 'S5', 'Sotano 5'
    UNION ALL SELECT 'S6', 'Sotano 6'
    UNION ALL SELECT 'S7', 'Sotano 7'
    UNION ALL SELECT 'S8', 'Sotano 8'
    UNION ALL SELECT 'S9', 'Sotano 9'
    UNION ALL SELECT 'TE', 'Terraza'
    UNION ALL SELECT 'TI', 'Tienda'
    UNION ALL SELECT 'X1', 'Semisotano 1'
    UNION ALL SELECT 'X2', 'Semisotano 2'
    UNION ALL SELECT 'X3', 'Semisotano 3'
    UNION ALL SELECT 'X4', 'Semisotano 4'
    UNION ALL SELECT 'X5', 'Semisotano 5'
    UNION ALL SELECT 'X6', 'Semisotano 6'
    UNION ALL SELECT 'X7', 'Semisotano 7'
    UNION ALL SELECT 'X8', 'Semisotano 8'
    UNION ALL SELECT 'X9', 'Semisotano 9'
  )
  SELECT DISTINCT
    a.gescal as g37,
    a.current_sfid_id,
    activation_date,
    c.g12,
    c.PROVINCIA,
    c.MUNICIPIO,
    c.POBLACION,
    c.COMUNIDAD_AUTONOMA,
    c.TIPO_VIA,
    c.VIA,
    SUBSTR(a.gescal, 13,5) AS NUMERO,
    SUBSTR(a.gescal, 18,1) AS BIS,
    COALESCE(b.literal, TRIM(SUBSTR(a.gescal, 19, 3))) AS BLOQUE,
    SUBSTR(a.gescal, 22,2) AS PORTAL_PUERTA,
    SUBSTR(a.gescal, 24,1) AS LETRA,
    SUBSTR(a.gescal, 25,2) AS ESCALERA,
    COALESCE(p.literal, TRIM(SUBSTR(a.gescal, 27, 3))) AS PLANTA,
    SUBSTR(a.gescal, 30,4) AS MANO1,
    SUBSTR(a.gescal, 34,4) AS MANO2
  FROM `mm-commissions-reporting.B2B.comisiones_base_armb_*` a 
  INNER JOIN gescal_12 c ON LEFT(a.gescal, 12) = c.g12
  LEFT JOIN bloques b
  ON UPPER(TRIM(SUBSTR(a.gescal, 19, 3))) = b.cod_bloque
  LEFT JOIN plantas p
  ON UPPER(TRIM(SUBSTR(a.gescal, 27, 3))) = p.cod_planta
  INNER JOIN dealers_tuca d
  ON a.current_sfid_id = d.id_comisionista
  WHERE 1=1
    AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
    AND activation_date >= '2025-07-01'
  QUALIFY ROW_NUMBER() OVER(PARTITION BY a.gescal) = 1
  ;


END