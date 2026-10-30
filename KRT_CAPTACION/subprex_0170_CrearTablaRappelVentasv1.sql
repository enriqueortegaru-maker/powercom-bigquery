BEGIN

  /*  PASO 1: CREO LISTADO DE VENTAS*/

  --DECLARE DESDE_ID, HASTA_ID INT64;SET DESDE_ID=20250901; SET HASTA_ID=20250930;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_LIST` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

  --DECLARE DESDE_ID, HASTA_ID INT64;SET DESDE_ID=20250901; SET HASTA_ID=20250930;
  ---================================================================================================================================================
  --- CTE 1: POBLACION DE VENTAS BRUTAS DE BAS EN MARCA. NO INCLUYE CONDICION DE EXCLUSION POR NOMBRE_DISTRIBUIDOR CANAL, SUBCANAL y AGENTE
  ---================================================================================================================================================


  WITH VBNOR AS (

    --DECLARE DESDE_ID AS INT64; SET DESDE_ID=20260101;
    SELECT S.marca_ds, s.cliente_id, s.servicio_id, s.servicio_unificado_id, concat(cast(servicio_id AS STRING),'_',cast(cliente_id as string),'_',coalesce(expediente_padre_id,"")) as idconcat, S.nombre_distribuidor_alta_ds, S.canal_alta_ds, S.subcanal_ds,S.tipo_canal_alta_ds, ca.grupo_rappel_ds
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
          
    INNER JOIN`mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` CA
    ON S.MARCA_DS = CA.MARCA_DS AND S.NOMBRE_DISTRIBUIDOR_ALTA_DS = CA.NOMBRE_DISTRIBUIDOR_DS AND S.CANAL_ALTA_DS = CA.CANAL_DS AND S.TIPO_CANAL_ALTA_DS = CA.TIPO_CANAL_DS
      AND S.SUBCANAL_DS = CA.SUBCANAL_DS
      AND CASE WHEN CA.SEGMENTO_DS <> 'X' THEN CA.SEGMENTO_DS = S.SEGMENTO_DS
                ELSE TRUE
          END
      AND CASE WHEN CA.territorio_ds <> 'X' THEN S.TERRITORIO_DS = CA.TERRITORIO_DS
               ELSE TRUE
          END
    WHERE fecha_venta_bruta_id BETWEEN DESDE_ID AND HASTA_ID
       AND servicio_id_origen < 0
       AND UPPER(agente_creador_id) <> 'MIGRAMASHFC_FTTH'
       AND (   (s.segmento_ds IN ('RESIDENCIAL', 'SOHO','PYME') AND s.marca_ds IN ('EUSKALTEL', 'RACC','VIRGIN'))
            OR (s.segmento_ds IN ('RESIDENCIAL','SOHO') AND s.marca_ds NOT IN ('EUSKALTEL','RACC','VIRGIN'))
           )
      AND s.fecha_venta_bruta_id < CAST(FORMAT_DATE("%Y%m%d", CURRENT_DATE()) AS int64)
      AND S.MARCA_DS!="R"

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