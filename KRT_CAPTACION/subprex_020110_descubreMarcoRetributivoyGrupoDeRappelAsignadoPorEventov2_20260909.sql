BEGIN



  -- PASO 1: CREO TABLA MARCO_RETRIBUTIVOxCANAL 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` AS
  with u as (
    SELECT
      distinct tmp.*,
      c.clave as clave -- O clave_mr, según tu nomenclatura
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp
    
    -- Se cruza todo en un único JOIN. Los exactos van fijos, los flexibles llevan el OR 'X'
    LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c
      ON  tmp.marca_ds = c.marca_ds
      AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds
      AND tmp.canal_alta_ds = UPPER(c.canal_ds)
      AND tmp.subcanal_ds = UPPER(c.subcanal_ds)
      AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds)
      AND (tmp.equipo_ds = UPPER(c.equipo_ds) OR UPPER(c.equipo_ds) = 'X')
      AND (tmp.segmento_ds = UPPER(c.segmento_ds) OR UPPER(c.segmento_ds) = 'X')
      AND (tmp.territorio_ds = UPPER(c.territorio_ds) OR UPPER(c.territorio_ds) = 'X')
    where not contains_substr(concepto_ds,"cancela")
    QUALIFY ROW_NUMBER() OVER (
      -- IMPORTANTE: Añade al PARTITION BY el campo que hace única la fila en SERVICIOS_CAPTACION (ej. id_fijo, id_producto, contrato)
      PARTITION BY 
        tmp.marca_ds, tmp.tipo_canal_alta_ds, tmp.canal_alta_ds, tmp.subcanal_ds, 
        tmp.nombre_distribuidor_alta_ds, tmp.equipo_ds, tmp.segmento_ds, tmp.territorio_ds 
        --, tmp.concepto_ds
        , tmp.servicio_id -- AÑADIR CLAVE ÚNICA
        
      ORDER BY
        -- CRITERIO 1: Priorizar parametrizaciones con el menor número de 'X' (mayor nivel de exactitud)
        (CASE WHEN UPPER(c.equipo_ds) = 'X' THEN 1 ELSE 0 END +
        CASE WHEN UPPER(c.segmento_ds) = 'X' THEN 1 ELSE 0 END +
        CASE WHEN UPPER(c.territorio_ds) = 'X' THEN 1 ELSE 0 END) ASC,

        -- CRITERIO 2: Desempate por "Peso" del campo. 
        -- Si empatan en cantidad de 'X', penaliza más tener una 'X' en Equipo que en Territorio.
        (CASE WHEN UPPER(c.territorio_ds) = 'X' THEN 1 ELSE 0 END +
        CASE WHEN UPPER(c.segmento_ds) = 'X' THEN 2 ELSE 0 END +
        CASE WHEN UPPER(c.equipo_ds) = 'X' THEN 3 ELSE 0 END) ASC
    ) = 1
  ), c as (

    SELECT
      distinct tmp.*,
      u.clave as clave -- O clave_mr, según tu nomenclatura
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp
    inner join u on u.marca_ds = tmp.marca_ds and u.servicio_id = tmp.servicio_id
    where contains_substr(tmp.concepto_ds,"cancela")

  ) select distinct u.*
  from u
  union all
  select distinct c.*
  from c
  order by marca_ds, servicio_id, concepto_ds;



  -- PASO 2: Vuelco registros en tabla de log
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_020110_MARCO_RETRIBUTIVOxCANAL` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`;    

END