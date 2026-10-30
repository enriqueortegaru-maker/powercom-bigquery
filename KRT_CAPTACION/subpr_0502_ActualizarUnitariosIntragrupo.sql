BEGIN
  -- TABLA SALIDA
  --    `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`


  --- PASO 1: Actualizo MARCO_RETRIBUTIVOxCANAL

  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` A
  SET
    A.IMPORTE = A.IMPORTE/2
  FROM (
          SELECT DISTINCT marca_ds, cliente_id
          FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_PORTABILIDADES_INTRAGRUPO` a
          WHERE
            ( CAST(OPERADOR_FIJO_ID AS INT64) IN (SELECT OPERADOR_FIJO_ID FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS` where version=0 ) 
              OR (CAST(OPERADOR_MOVIL_ID AS INT64) IN (SELECT OPERADOR_MOVIL_ID FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_MOVILES` where version=0)
                  AND EXISTS ( SELECT 1
                                FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_PORTABILIDADES_INTRAGRUPO` b
                                WHERE b.marca_ds = a.marca_ds
                                AND a.cliente_id = b.cliente_id
                                AND CAST(OPERADOR_FIJO_ID AS INT64) IN ( SELECT OPERADOR_FIJO_ID FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS` where version=0)
                          ) 
                  )
            )
            AND fecha_venta_neta_id >= 20210901 )B
  WHERE
    A.MARCA_DS = B.MARCA_DS
    AND A.CLIENTE_ID = B.CLIENTE_ID
    AND (CANAL_ALTA_DS = 'TELEVENTA'
      OR (CANAL_ALTA_DS = 'TASK FORCE'
        AND SUBCANAL_DS <> 'STANDS'));
  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` A
  SET
    A.IMPORTE = A.IMPORTE/2
  FROM (
    SELECT
      DISTINCT marca_ds,
      cliente_id
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_PORTABILIDADES_INTRAGRUPO` a
    WHERE
      (CAST(OPERADOR_FIJO_ID AS INT64) IN (
        SELECT
          OPERADOR_FIJO_ID
        FROM
          `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS` where version=0 )
        AND EXISTS (
        SELECT
          1
        FROM
          `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_PORTABILIDADES_INTRAGRUPO` b
        WHERE
          b.marca_ds = a.marca_ds
          AND a.cliente_id = b.cliente_id
          AND CAST(OPERADOR_FIJO_ID AS INT64) IN (
          SELECT
            OPERADOR_FIJO_ID
          FROM
            `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS`  where version=0 )) )
      AND fecha_venta_neta_id >= 20210901 )B
  WHERE
    A.MARCA_DS = B.MARCA_DS
    AND A.CLIENTE_ID = B.CLIENTE_ID
    AND CANAL_ALTA_DS = 'TASK FORCE MM'
    AND a.categoria_servicio_ds NOT IN ('TERMINALES',
      'MOVILES POSTPAGO');
  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` A
  SET
    A.IMPORTE = A.IMPORTE/2
  FROM (
    SELECT
      DISTINCT marca_ds,
      cliente_id
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_PORTABILIDADES_INTRAGRUPO` a
    WHERE
      ((CAST(OPERADOR_MOVIL_ID AS INT64) IN (
          SELECT
            OPERADOR_MOVIL_ID
          FROM
            `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_MOVILES`  where version=0  )
          AND EXISTS (
          SELECT
            1
          FROM
            `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_PORTABILIDADES_INTRAGRUPO` b
          WHERE
            b.marca_ds = a.marca_ds
            AND a.cliente_id = b.cliente_id
            AND CAST(OPERADOR_FIJO_ID AS INT64) IN (
            SELECT
              OPERADOR_FIJO_ID
            FROM
              `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS`  where version=0 )) ))
      AND fecha_venta_neta_id >= 20210901 )B
  WHERE
    A.MARCA_DS = B.MARCA_DS
    AND A.CLIENTE_ID = B.CLIENTE_ID
    AND CANAL_ALTA_DS = 'TASK FORCE MM'
    AND a.categoria_servicio_ds IN ('TERMINALES',
      'MOVILES POSTPAGO');


  -- PASO 2: INSERTO REGISTROS DE LOG

    -- Log de fichero completo
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0502_MARCO_RETRIBUTIVOxCANAL` AS
    SELECT 
      * 
    FROM 
      `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`; 


    -- Log de incremento
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0502_MARCO_RETRIBUTIVOxCANAL_upd` AS
    SELECT 
      * 
    FROM 
      `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` 
    EXCEPT DISTINCT
    SELECT
      * 
    FROM  
      `mm-commissions-reporting.KRT_CAPTACION.LOG_0403_MARCO_RETRIBUTIVOxCANAL`;


  ----------------VERSIONES------------------------------------
  --
  -- V1: Se introducen logs
  -- V2: Se modifica origen de tablas OPERADORES_FIJOS y OPERADORES_MOVILES que pasan de dominio dw-cloud-euskaltel-prod-283409.D90_FINANCIERO a dominio mm-commissions-reporting.KRT_CAPTACION  

END