BEGIN

  declare desde_id INT64;
  set desde_id=CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date ('%Y%m%d', CAST ( DESDE AS string) ), interval 1 month),month)) as integer);
  --set desde_id=CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date ('%Y%m%d', CAST ( 20220501 AS string) ), interval 1 month),month)) as integer);
  --set HASTA=20220531;


  ---  PASO 1:Borro registros en tabla  `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` 
  DELETE 
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` A
  WHERE
    EXISTS (
      SELECT
        *
      FROM (
              SELECT
                cliente_id,
                marca_ds,
                categoria_servicio_ds
              FROM
                `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
              WHERE                                            -- Condiciones para borrado en tabla MARCO_RETRIBUTIVOxCANAL 
                fecha_rfb_id < desde_id                           -- Fecha de Rfb anterior a primer día del mes anterior a nueva contratación
                AND fecha_baja_id BETWEEN desde_id AND HASTA      -- Fecha de baja entre primer día del mes anterior y ultimo día del periodo de comisionamiento
                AND fecha_rfb_id < fecha_baja_id                  -- Fecha de de Rfb anterior a fecha de baja
                AND servicio_id_destino < 0                    -- Servicio destino inferior a 0 (alta no relacionada con migración de servicio)  
                AND EXISTS(                                    -- Tripleta cliente_id, marca_ds, categoria_ds existe en tabla MARCO_RETRIBUTIVOxCANAL 
                  SELECT                                        
                    *
                  FROM (
                        SELECT
                          DISTINCT cliente_id,                  
                          marca_ds,
                          categoria_servicio_ds
                        FROM
                          `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`) t
                  WHERE
                    s.cliente_id = t.cliente_id
                    AND s.marca_ds = t.marca_ds
                    AND s.categoria_servicio_ds = t.categoria_servicio_ds 
                  )
            
            ) b  --- tripletas cliente_id, marca_ds y categoria_servicio_ds que forman parte del marco_retributivoxcanal y cumplen con condiciones de borrado
      WHERE
        a.cliente_id = b.cliente_id
        AND a.marca_ds = b.marca_ds
        AND a.categoria_servicio_ds = b.categoria_servicio_ds
    );

  ---  PASO 2: Vuelco LOGS 

    -- Log de fichero completo      
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0202_MARCO_RETRIBUTIVOxCANAL` AS
    SELECT 
    *
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` ;


    -- Log de incremento
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0202_MARCO_RETRIBUTIVOxCANAL_DEL` AS
    SELECT 
      * 
    FROM 
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0201_MARCO_RETRIBUTIVOxCANAL`
    EXCEPT DISTINCT
    SELECT
      * 
    FROM  
      `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`;



  ---  PASO 3: Creo tabla UNITARIOS

    -- Log de fichero completo      
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` AS
    SELECT 
    *
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` ;


    
END