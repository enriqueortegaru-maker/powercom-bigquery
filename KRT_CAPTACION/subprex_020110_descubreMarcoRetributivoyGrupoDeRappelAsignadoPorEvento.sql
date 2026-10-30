BEGIN

  -- PASO 1: CREO TABLA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` AS
    SELECT
      tmp.*,
      CASE
        WHEN ( SELECT COUNT(*) 
              FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c
              WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds =UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND tmp.segmento_ds = UPPER(c.segmento_ds) AND tmp.territorio_ds = UPPER(c.territorio_ds)) = 1 
              THEN ( SELECT c.clave 
                    FROM 
                      `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                    WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds =UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND tmp.segmento_ds = UPPER(c.segmento_ds) AND tmp.territorio_ds = UPPER(c.territorio_ds))
      ELSE
      CASE
        WHEN ( SELECT COUNT(*) 
              FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
              WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds =UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND tmp.segmento_ds = UPPER(c.segmento_ds) AND UPPER(c.territorio_ds) = 'X') = 1 
              THEN ( SELECT c.clave 
                      FROM 
                      `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                      WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND tmp.segmento_ds = UPPER(c.segmento_ds) AND UPPER(c.territorio_ds) = 'X')
      ELSE
      CASE
        WHEN ( SELECT COUNT(*) 
              FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds =UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND UPPER(c.segmento_ds) = 'X' AND tmp.territorio_ds = UPPER(c.territorio_ds) ) = 1
        THEN ( SELECT c.clave 
              FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
              WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = c.subcanal_ds AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND UPPER(c.segmento_ds) = 'X' AND tmp.territorio_ds = UPPER(c.territorio_ds) )
      ELSE
        CASE
          WHEN ( SELECT COUNT(*) 
                  FROM 
                  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                  WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND UPPER(c.segmento_ds)= 'X' AND UPPER(c.territorio_ds) = 'X' ) = 1 
          THEN ( SELECT c.clave 
                  FROM 
                    `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                  WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = c.subcanal_ds AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND tmp.equipo_ds = UPPER(c.equipo_ds) AND UPPER(c.segmento_ds) = 'X' AND UPPER(c.territorio_ds) = 'X')
      ELSE
        CASE
          WHEN ( SELECT COUNT(*) 
                FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds) = 'X' AND tmp.segmento_ds = UPPER(c.segmento_ds) AND UPPER(c.territorio_ds)= 'X') = 1 
          THEN ( SELECT c.clave 
                  FROM 
                  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                  WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds) = 'X' AND tmp.segmento_ds = UPPER(c.segmento_ds) AND UPPER(c.territorio_ds) = 'X')
      ELSE
      CASE
        WHEN ( SELECT COUNT(*) 
                FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds)= 'X' AND UPPER(c.segmento_ds) = 'X' AND tmp.territorio_ds = UPPER(c.territorio_ds) ) = 1
        THEN ( SELECT c.clave 
                FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds) = 'X' AND UPPER(c.segmento_ds) = 'X' AND tmp.territorio_ds = UPPER(c.territorio_ds))
      ELSE
      CASE
        WHEN ( SELECT COUNT(*) 
                FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds) = 'X' AND UPPER(c.segmento_ds) = 'X' AND UPPER(c.territorio_ds) = 'X' ) = 1 
        THEN ( SELECT c.clave 
                FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds) = 'X' AND UPPER(c.segmento_ds) = 'X' AND UPPER(c.territorio_ds) = 'X')
      ELSE
      CASE
        WHEN ( SELECT COUNT(*) 
                FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds) = 'X' AND UPPER(c.segmento_ds) = tmp.segmento_ds AND UPPER(c.territorio_ds) = tmp.territorio_ds) = 1 
        THEN ( SELECT c.clave 
                FROM 
                `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c 
                WHERE tmp.marca_ds = c.marca_ds AND tmp.tipo_canal_alta_ds = c.tipo_canal_ds AND tmp.canal_alta_ds = UPPER(c.canal_ds) AND tmp.subcanal_ds = UPPER(c.subcanal_ds) AND tmp.nombre_distribuidor_alta_ds = UPPER(c.nombre_distribuidor_ds) AND UPPER(c.equipo_ds) = 'X' AND UPPER(c.segmento_ds) = tmp.segmento_ds AND UPPER(c.territorio_ds) = tmp.territorio_ds)
    END
    END
    END
    END
    END
    END
    END
    END
      clave --,importe
    FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` tmp;

  ---  PASO 2: Vuelco registros en tabla de log `mm-commissions-reporting.KRT_CAPTACION.LOG_0201_MARCO_RETRIBUTIVOxCANAL`
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_020110_MARCO_RETRIBUTIVOxCANAL` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` ;    

end