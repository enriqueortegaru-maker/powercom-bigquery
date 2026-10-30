BEGIN

  /*  PASO 1: CREO LISTADO DE VENTAS*/

  --DECLARE DESDE_ID, HASTA_ID INT64; SET DESDE_ID=20260101;SET HASTA_ID=20260131;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_LIST` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  --DECLARE DESDE_ID, HASTA_ID INT64; SET DESDE_ID=20260101;SET HASTA_ID=20260131;

  WITH 

    ---================================================================================================================================================
    --- CTE SOPORTE CREACION VBNOR: POBLACION DE VENTAS BRUTAS DE BAS EN MARCAS DISTINTAS A R
    ---================================================================================================================================================

      -- 1. Filtrado temprano de SERVICIOS NO R (S)
      -- Aplicamos todos los filtros WHERE aquí para reducir el volumen de datos antes de los joins.

    servicios_filtrados AS (
        SELECT 
            s.marca_ds, 
            s.cliente_id, 
            s.servicio_id, 
            s.servicio_unificado_id,
            s.servicio_id_origen,
            s.nombre_distribuidor_alta_ds,
            s.canal_alta_ds,
            s.subcanal_ds,
            s.tipo_canal_alta_ds,
            s.categoria_servicio_ds,
            s.velocidad_mb,
            s.gb,
            s.tecnologia_detalle_ds,
            s.detalle_servicio_ds,
            s.segmento_ds,
            s.territorio_ds,
            s.agente_creador_id,
            s.fecha_venta_bruta_id,
            -- Generamos el ID concatenado aquí
            CONCAT(s.servicio_id, '_', s.cliente_id, '_', IFNULL(s.expediente_padre_id, '')) as idconcat
        FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
        WHERE s.fecha_venta_bruta_id BETWEEN DESDE_ID AND HASTA_ID
          AND s.servicio_id_origen < 0
          AND s.marca_ds != 'R'
          -- Filtro de fecha actual pre-calculado para evitar funciones por fila si es posible, 
          -- aunque BQ suele optimizar CURRENT_DATE constante.
          AND s.fecha_venta_bruta_id < CAST(FORMAT_DATE("%Y%m%d", CURRENT_DATE()) AS INT64)
          AND UPPER(s.agente_creador_id) <> 'MIGRAMASHFC_FTTH'
          AND (
              (s.segmento_ds IN ('RESIDENCIAL', 'SOHO', 'PYME') AND s.marca_ds IN ('EUSKALTEL', 'RACC', 'VIRGIN'))
            OR (s.segmento_ds IN ('RESIDENCIAL', 'SOHO') AND s.marca_ds NOT IN ('EUSKALTEL', 'RACC', 'VIRGIN'))
          )
    ),

    -- 2. Enriquecimiento con VENTAS NO R (V)
    -- Hacemos el LEFT JOIN una sola vez y calculamos los campos "finales" (coalesce).
    servicios_con_ventas AS (
        SELECT 
            s.*,
            -- Calculamos la dimensión final del canal una sola vez
            COALESCE(v.canal_alta_ds, s.canal_alta_ds) AS final_canal,
            COALESCE(v.subcanal_ds, s.subcanal_ds) AS final_subcanal,
            COALESCE(v.tipo_canal_alta_ds, s.tipo_canal_alta_ds) AS final_tipo_canal
        FROM servicios_filtrados s
        LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v 
            ON v.marca_ds = s.marca_ds 
            AND v.cliente_id = s.cliente_id 
            AND v.servicio_id = s.servicio_id 
            AND v.nombre_distribuidor_alta_ds = s.nombre_distribuidor_alta_ds
    ),

    -- 3. Cruce con CATALOGOS (C)
    -- Optimizamos el OR complejo separando la lógica o simplificando los predicados booleanos.
    -- Nota: Si PARAM_CATALOGOS es pequeña, este JOIN directo suele funcionar bien si limpiamos la sintaxis.
    servicios_catalogados AS (
        SELECT 
            sv.*
        FROM servicios_con_ventas sv
        INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` c
            ON c.marca_ds = sv.marca_ds 
            AND (
                -- LÓGICA 1: BLOQUE (Rango)
                (
                    c.tipo_identificacion_ds = 'BLOQUE' 
                    AND sv.categoria_servicio_ds = 'BANDA ANCHA'
                    AND c.categoria_servicio_ds = sv.categoria_servicio_ds 
                    AND c.adicional_lg = 0
                    AND c.tecnologia_detalle_ds = sv.tecnologia_detalle_ds
                    AND (
                        (c.campo_filtrado = 'VELOCIDAD_MB' AND sv.velocidad_mb BETWEEN c.valor_minimo AND c.valor_maximo)
                        OR 
                        (c.campo_filtrado = 'GB' AND sv.gb BETWEEN c.valor_minimo AND c.valor_maximo)
                    )
                )
                OR 
                -- LÓGICA 2: DETALLE (Exacto)
                (
                    CONTAINS_SUBSTR(c.tipo_identificacion_ds, 'DETALLE_SERVICIO') 
                    AND (CONTAINS_SUBSTR(c.detalle_servicio_ds, 'HEGAN-COMBI YES') OR CONTAINS_SUBSTR(c.detalle_servicio_ds, 'MAMBO AXIÑA'))
                    AND c.detalle_servicio_ds = sv.detalle_servicio_ds 
                )
            )
    )
    
    
    ---================================================================================================================================================
    --- CTE VBNOR: POBLACION DE VENTAS BRUTAS DE BAS EN MARCAS DISTINTAS A R
    ---================================================================================================================================================

    
    , VBNOR AS (

        -- 4. Cruce FINAL con CANALES (CA) para obtener el Rappel
        -- Eliminamos la subconsulta compleja y cruzamos directo con la tabla de parámetros
        SELECT 
            sc.marca_ds, 
            sc.cliente_id, 
            sc.servicio_id, 
            sc.servicio_unificado_id, 
            sc.idconcat, 
            sc.nombre_distribuidor_alta_ds,
            sc.final_canal AS canal_alta_ds, 
            sc.final_subcanal AS subcanal_ds,
            sc.final_tipo_canal AS tipo_canal_alta_ds, 
            ca.grupo_rappel_ds
        FROM servicios_catalogados sc
        INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca
            ON sc.marca_ds = ca.marca_ds 
            AND sc.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds 
            AND sc.final_canal = ca.canal_ds  
            AND sc.final_subcanal = ca.subcanal_ds
            AND sc.final_tipo_canal = ca.tipo_canal_ds
            -- Optimizamos la lógica del comodín 'X' usando OR en lugar de CASE
            AND (ca.segmento_ds = 'X' OR ca.segmento_ds = sc.segmento_ds)
            AND (ca.territorio_ds = 'X' OR sc.territorio_ds = ca.territorio_ds)


    ---================================================================================================================================================
    --- CTE VBR: POBLACION DE VENTAS BRUTAS DE BAS EN MARCA R
    ---================================================================================================================================================


    ), VBR AS (
        SELECT distinct S.marca_ds, s.cliente_id, s.servicio_id, s.servicio_unificado_id, concat(cast(s.servicio_id AS STRING),'_',cast(s.cliente_id as string),'_',coalesce(s.expediente_padre_id,"")) as idconcat, 
        coalesce(cn.distribuidor_ds,cnPadre.distribuidor_ds, S.nombre_distribuidor_alta_ds),
        coalesce(cn.canal_agrupado1_ds,cnPadre.canal_agrupado1_ds, S.canal_alta_ds),
        coalesce(cn.subcanal_ds, cnPadre.subcanal_ds, S.subcanal_ds),    
        coalesce(cn.canal_agrupado2_ds, cnPadre.canal_agrupado2_ds, S.tipo_canal_alta_ds),
        ca.grupo_rappel_ds
        FROM`dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S
        INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` C

        ON C.MARCA_DS = S.MARCA_DS 
          AND ( (C.tipo_identificacion_ds = 'BLOQUE' 
                AND s.categoria_servicio_ds = 'BANDA ANCHA'
                AND C.CATEGORIA_SERVICIO_DS = S.CATEGORIA_SERVICIO_DS 
                AND CASE WHEN campo_filtrado = 'VELOCIDAD_MB' THEN S.VELOCIDAD_MB BETWEEN C.VALOR_MINIMO AND C.VALOR_MAXIMO
                          WHEN campo_filtrado = 'GB' THEN S.GB BETWEEN C.VALOR_MINIMO AND C.VALOR_MAXIMO
                END
                AND adicional_lg = 0
                AND c.tecnologia_detalle_ds = s.tecnologia_detalle_ds
                )

                OR (contains_substr(C.tipo_identificacion_ds,'DETALLE_SERVICIO') 
                    and (contains_substr(C.detalle_servicio_ds,'HEGAN-COMBI YES') or contains_substr(C.detalle_servicio_ds,'MAMBO AXIÑA') ) 
                    and C.detalle_servicio_ds=s.detalle_servicio_ds 
                )    
              )   


        INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req`   exp       ON s.expediente_id = exp.row_id
        LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req`   expPadre  ON exp.PAR_SR_ID = expPadre.row_id
        LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`emp       ON exp.owner_emp_id=emp.row_id
        LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_employee_x`empPadre  ON expPadre.owner_emp_id=empPadre.row_id
        LEFT JOIN  `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal`     cn        ON CAST(cn.agente_venta_id AS string) = emp.attrib_07
        LEFT JOIN  `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal`     cnPadre   ON CAST(cnPadre.agente_venta_id AS string) = empPadre.attrib_07        
        INNER JOIN`mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` CA
        ON S.MARCA_DS = CA.MARCA_DS 
          AND coalesce(cn.distribuidor_ds,cnPadre.distribuidor_ds, S.nombre_distribuidor_alta_ds) = CA.NOMBRE_DISTRIBUIDOR_DS 
          AND coalesce(cn.canal_agrupado1_ds, cnPadre.canal_agrupado1_ds, S.canal_alta_ds) = CA.CANAL_DS 
          AND coalesce(cn.canal_agrupado2_ds, cnPadre.canal_agrupado2_ds, S.tipo_canal_alta_ds) = CA.TIPO_CANAL_DS
          AND coalesce(cn.subcanal_ds,cnPadre.subcanal_ds, S.subcanal_ds)  = CA.SUBCANAL_DS
          AND CASE WHEN CA.SEGMENTO_DS <> 'X' THEN CA.SEGMENTO_DS = S.SEGMENTO_DS ELSE TRUE END
          AND CASE WHEN CA.territorio_ds <> 'X' THEN S.TERRITORIO_DS = CA.TERRITORIO_DS ELSE TRUE END

        WHERE s.fecha_venta_bruta_id BETWEEN DESDE_ID AND HASTA_ID
          AND s.servicio_id_origen < 0
          AND UPPER(coalesce(emp.attrib_07,empPadre.attrib_07, s.agente_creador_id)) <> 'MIGRAMASHFC_FTTH'
          AND (   (s.segmento_ds IN ('RESIDENCIAL', 'SOHO','PYME') AND s.marca_ds IN ('EUSKALTEL', 'RACC','VIRGIN'))
                OR (s.segmento_ds IN ('RESIDENCIAL','SOHO') AND s.marca_ds NOT IN ('EUSKALTEL','RACC','VIRGIN'))
              )
          AND S.MARCA_DS="R"
    )

  select distinct * 
  from VBNOR
  UNION ALL 
  select distinct * 
  from VBR;



  /*  PASO 2: CREO CONTABILIDAD DE VENTAS*/

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_LIST_DISTINCT` AS
  --SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_LIST`;





  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTASxDIST_CONT` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT S.marca_ds, S.nombre_distribuidor_alta_ds, COUNT(distinct idconcat) BAS, COUNT(distinct servicio_unificado_id) BAS_SU_D, COUNT(servicio_unificado_id) BAS_SU, COUNT(distinct idconcat) BAS_CONCAT_D, COUNT(distinct servicio_id) BAS_SID_D, COUNT(servicio_id) BAS_SID  
  FROM  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_LIST` S
  GROUP BY S.marca_ds,S.nombre_distribuidor_alta_ds;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_CONT`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT S.marca_ds, S.nombre_distribuidor_alta_ds, S.canal_alta_ds, S.subcanal_ds,S.tipo_canal_alta_ds, s.grupo_rappel_ds, COUNT(distinct idconcat) BAS, COUNT(distinct servicio_unificado_id) BAS_SU_D, COUNT(servicio_unificado_id) BAS_SU, COUNT(distinct idconcat) BAS_CONCAT_D, COUNT(distinct servicio_id) BAS_SID_D, COUNT(servicio_id) BAS_SID  
  FROM  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_LIST` S
  GROUP BY S.marca_ds,S.nombre_distribuidor_alta_ds,S.canal_alta_ds,S.subcanal_ds,S.tipo_canal_alta_ds,s.grupo_rappel_ds;

  
  /*  PASO 4: CREO TABLAS DE SALIDA*/

  CREATE OR REPLACE TABLE`mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT * except(BAS_SU_D,BAS_SU,BAS_CONCAT_D,BAS_SID_D,BAS_SID) FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_CONT`;

  CREATE OR REPLACE TABLE`mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS`;

 
END