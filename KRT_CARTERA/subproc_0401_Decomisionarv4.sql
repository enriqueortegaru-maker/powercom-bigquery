BEGIN

    DECLARE DESDE_DT, HASTA_DT, DESDE_1M_DT, HASTA_1M_DT,DESDE_6M_DT date;
    DECLARE MES_DECOMISION,DESDE_1M, HASTA_1M INT64;
    DECLARE  vMES_DECOMISION_ID, DESDE_6M INT64;
    -- VAR LOCALES
    --DECLARE DESDE, HASTA INT64;SET DESDE=20230701;SET HASTA=20230731;
    -- FIN VAR LOCALES
    SET vMES_DECOMISION_ID= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);
    SET DESDE_6M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE AS string)), interval 6 month),month)) AS STRING) AS INT64);


    SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
    SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
    SET DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);
    SET DESDE_1M_DT=DATE_SUB(DESDE_DT, INTERVAL 1 MONTH);     
    SET DESDE_1M= CAST(FORMAT_DATE("%Y%m%d",DESDE_1M_DT) AS INT64);     
    SET HASTA_1M_DT= LAST_DAY(DESDE_1M_DT);   
    SET HASTA_1M=CAST(FORMAT_DATE("%Y%m%d",HASTA_1M_DT) AS INT64);    
    SET MES_DECOMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);



    -- PASO 1: CREO TABLA DE BAJAS DE SVAS DE EKTNET

      -- PASO 1.1: CREO TABLA DE BAJAS DE SVAS DE EKTNET EN MES DE COMISIONADO (LOG_0401_BAJAS_SVA_EKTNET) (FASE 10)
          -- PASO 1: CREO TABLA DE BAJAS DE SVAS DE EKTNET

      -- PASO 1.1: CREO TABLA DE BAJAS DE SVAS DE EKTNET EN MES DE COMISIONADO (LOG_0401_BAJAS_SVA_EKTNET) (FASE 10)
      
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_EKTNET` AS
      SELECT  DISTINCT CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'Telecable' THEN 'TELECABLE' END as marca_ds,
      row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS STRING) as catalogo_Id, 
      case  when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  
            when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' 
            ELSE "" 
      END as operacion_baja_inicial_ds, 
      case  when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  
            when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  
            when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' 
            ELSE "" 
      END as operacion_baja_ds, 
      10 as fase, 
      catalogo.TipoProducto
      FROM   `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p 
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm  ON c.mmMarcaId = mm.mmMarcaId
      --INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON cat.swProdReleaseId=p.swProdReleaseId
      left JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON p.swProdReleaseId = CAST( idProdCat AS int64) AND Sistema = 'EKTNET' and catalogo.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END -- AND adicional_lg = 0 
      WHERE `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE   AND HASTA 
      AND `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M 
      AND not exists( select 1 from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` d  where d.swProdOrigId= p.swInstProdId)
      --AND cat.swProductType='Servicio' and contains_substr(cat.swLineName,'televisi' )
      --AND p.swCopiaProdId IS NULL
      --- Cruce con producto padre -> Aplicar sólo a la linea de TV en marcas de GEKT ya que es allí donde aplica
      
      UNION ALL

      ----- PRODUCTOS DE TELEVISION REGISTRADOS COMO SBs
      SELECT  DISTINCT CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'Telecable' THEN 'TELECABLE' END as marca_ds,
      row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt,       
      `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  
      p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, CAST(p.swProdReleaseId AS STRING) as catalogo_Id, 
      case  when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  
            when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  
            when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' 
            ELSE "" 
      END as operacion_baja_inicial_ds, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  
           when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' 
           ELSE "" 
      END as operacion_baja_ds, 
      15 as fase,
      catalogo.TipoProducto       
      FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` h 
      INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p ON p.swInstProdId=h.swParentInstProdId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm  ON c.mmMarcaId = mm.mmMarcaId
      --INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON cat.swProdReleaseId=p.swProdReleaseId
      left JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` catalogo ON p.swProdReleaseId = CAST( idProdCat AS int64) AND Sistema = 'EKTNET' and catalogo.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END -- AND adicional_lg = 0 
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE   AND HASTA  
      AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M
      AND not exists(select 1 from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` d where d.swProdOrigId= p.swInstProdId);

      -- PASO 1.1.1: ELIMINO BAJAS DE TERMINAL CON CAUSA DISTINTA A DESISTIMIENTO

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_EKTNET` AS
      SELECT *  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_EKTNET` a
      where not exists (
            select 1 from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_EKTNET` b
            where contains_substr(b.TipoProducto,"terminal") and not contains_substr(b.motivo_baja_ds,"desistimiento") and a.marca_ds=b.marca_ds and a.servicio_id=b.servicio_id
      );
      
      --AND cat.swProductType='Servicio' and contains_substr(cat.swLineName,'televisi' )-- AND p.swCopiaProdId IS NULL


      --- Cruce con producto master -> Como se hace recurrencia creo que no es necesario
      --UNION ALL
      --SELECT  DISTINCT CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'Telecable' THEN 'TELECABLE' END as marca_ds,
      --row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      --17 as fase 
      --FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` h 
      --INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p ON p.swInstProdId=h.swMasterInstProdId
      --INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      --INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm  ON c.mmMarcaId = mm.mmMarcaId
      ----INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'EKTNET' AND adicional_lg = 0 and catalogo.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END
      --WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE  AND HASTA  AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M; --AND p.swCopiaProdId IS NULL
      


      -- PASO 1.2: CREO TABLA DE BAJAS SVAS DE EKTNET QUE FORMAN PARTE DE LA SECUENCIA DE MIGRACIONES DE LAS QUE PROCEDEN LOS PRODUCTOS DADOS DE BAJA EN EL MES DE COMISIONADO (TABLA LOG_0401_BAJAS_SVA_EKTNET_TOT) (FASE 20):

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_EKTNET_TOT` AS
      with recursive rec as (
        SELECT b.idreg,1 as lvl,  b.marca_ds, b.cliente_id, b.servicio_id, b.servicio_id_origen, b.servicio_id_original, b.fecha_rfb_dt,   b.fecha_rfb_id, b.fecha_baja_dt,  b.fecha_baja_id,  b.motivo_baja_agrup_ds, b.motivo_baja_ds, b.catalogo_Id, 
          b.operacion_baja_inicial_ds, b.operacion_baja_ds, 
          b.fase  
          FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_EKTNET` b
          UNION ALL 
          select r.idreg ,r.lvl+1 as lvl, r.marca_ds,
          s.swCustomerId as cliente_id,  s.swInstProdId as servicio_id,  s.swProdOrigId as servicio_id_origen, ifnull(s.swMasterInstProdId, 0) as servicio_id_original, s.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swDateInstalled) fecha_rfb_id, swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) fecha_baja_id,  s.swNombreCausaGral motivo_baja_agrup_ds,  s.swCausaBaja motivo_baja_ds, 
          CAST(s.swProdReleaseId AS STRING) as catalogo_Id, 
          r.operacion_baja_inicial_ds,
          case when contains_substr(s.swCausaBaja,'baja') or contains_substr(s.swCausaBaja,'precio')  or contains_substr(s.swCausaBaja,' uso') then 'BAJA'  when contains_substr(s.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(s.swCausaBaja,'titular') or  contains_substr(s.swCausaBaja,'domicilio') or  contains_substr(s.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds, 
          20 as fase 
          FROM rec r
        inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto`s on  r.servicio_id_origen=s.swInstProdId -- 
          --INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c ON c.swCustomerId=s.swCustomerId 
          --INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm  ON c.mmMarcaId = mm.mmMarcaId
          --INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGOS` catalogo ON s.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'EKTNET' AND adicional_lg = 0 and r.marca_ds in ('EUSKALTEL','VIRGIN','RACC','TELECABLE')
        --and not (s.servicio_id<0 and s.servicio_id_origen<0 and s.servicio_id_destino<0  and s.servicio_id_original<0) 
    --      where (r.fecha_rfb_id >= DESDE_6M) and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swDateInstalled) >= DESDE_6M)  and lvl<=10
          where lvl<=10 
          -- and (r.fecha_baja_id >= DESDE_6M)
          -- and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) >= DESDE_6M) 
      ) select distinct * 
      from rec
    --  where fecha_rfb_id >= DESDE_6M
      where fecha_baja_id BETWEEN DESDE AND HASTA AND fecha_rfb_id >=DESDE_6M 
      order by 1 asc, 2 asc;
      


    -- PASO 2: CREO TABLAS DE BAJAS DE SVAS DE TCNET

      -- PASO 2.1: CREO TABLA DE BAJAS DE SVAS DE TCNET EN MES DE COMISIONADO (LOG_0401_BAJAS_SVA_TCNET) (FASE 10)


      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_TCNET` AS
        ----- PRODUCTOS DESCUBIERTOS EN FASE 5 
      SELECT 'TELECABLE' as marca_ds,
      row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS STRING) as catalogo_Id, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_inicial_ds, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds, 
      10 as fase 
      FROM   `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p 
      --INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      --INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO') AND Sistema_ds = 'TCNET' AND adicional_lg = 0
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE   AND HASTA AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M --AND p.swCopiaProdId IS NULL
      AND not exists(select 1 from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` d where d.swProdOrigId= p.swInstProdId)

      ----- PRODUCTOS PADRE, PENDIENTE DE REVISAR
      UNION ALL 
      SELECT 'TELECABLE' as marca_ds,
      row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS string) as catalogo_Id, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_inicial_ds, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds, 
      15 as fase 
      FROM   `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` h 
      INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p ON p.swInstProdId=h.swParentInstProdId
      --INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      --INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO') AND Sistema_ds = 'TCNET' AND adicional_lg = 0
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE   AND HASTA AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M  -- AND p.swCopiaProdId IS NULL
      AND not exists(select 1 from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` d where d.swProdOrigId= p.swInstProdId)

      --- Cruce con producto master -> Como se hace recurrencia creo que no es necesario
      --UNION ALL 
      --SELECT 'TELECABLE' as marca_ds,
      --row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      --17 as fase 
      --FROM   `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` h 
      --INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p ON p.swInstProdId=h.swMasterInstProdId
      ----INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      ----INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO') AND Sistema_ds = 'TCNET' AND adicional_lg = 0
      --WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE   AND HASTA  AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M;--AND p.swCopiaProdId IS NULL
      ;


      -- PASO 2.2: CREO TABLA DE BAJAS SVAS DE TCNET QUE FORMAN PARTE DE LA SECUENCIA DE MIGRACIONES DE LAS QUE PROCEDEN LOS PRODUCTOS DADOS DE BAJA EN EL MES DE COMISIONADO (TABLA LOG_0401_BAJAS_SVA_TCNET_TOT) (FASE 20):

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_TCNET_TOT` AS
      with recursive rec as (
        SELECT idreg, 1 as lvl,  b.marca_ds, b.cliente_id, b.servicio_id, b.servicio_id_origen, b.servicio_id_original,   b.fecha_rfb_dt,   b.fecha_rfb_id, b.fecha_baja_dt,  b.fecha_baja_id,  b.motivo_baja_agrup_ds, b.motivo_baja_ds, b.catalogo_id, 
          b.operacion_baja_inicial_ds, 
          b.operacion_baja_ds, 
          b.fase  
          FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_TCNET` b
          UNION ALL 
          select r.idreg,r.lvl+1 as lvl, 
          'TELECABLE' as marca_ds,
          s.swCustomerId as cliente_id,  s.swInstProdId as servicio_id,  s.swProdOrigId as servicio_id_origen, ifnull(s.swMasterInstProdId, 0) as servicio_id_original, s.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swDateInstalled)  fecha_rfb_id, s.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) fecha_baja_id,  s.swNombreCausaGral motivo_baja_agrup_ds,  s.swCausaBaja motivo_baja_ds, CAST(s.swProdReleaseId AS STRING) as catalogo_Id,
          r.operacion_baja_inicial_ds, 
          case when contains_substr(s.swCausaBaja,'baja') or contains_substr(s.swCausaBaja,'precio')  or contains_substr(s.swCausaBaja,' uso') then 'BAJA'  when contains_substr(s.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(s.swCausaBaja,'titular') or  contains_substr(s.swCausaBaja,'domicilio') or  contains_substr(s.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds,       
          20 as fase 
          FROM rec r
          inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto`s on r.servicio_id_origen=s.swInstProdId  --or r.servicio_id = s.swMasterInstProdId)-- and r.cliente_id=s.swCustomerId
          --INNER JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGOS` catalogo ON s.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'TCNET' AND adicional_lg = 0  and catalogo.marca_ds='TELECABLE'
        --and not (s.servicio_id<0 and s.servicio_id_origen<0 and s.servicio_id_destino<0  and s.servicio_id_original<0) 
    --      where (r.fecha_rfb_id >= DESDE_6M) and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swDateInstalled) >= DESDE_6M)  and lvl<=10
          where lvl<=10
          -- and (r.fecha_baja_id >= DESDE_6M) 
          -- and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) >= DESDE_6M) 
      ) select distinct * 
      from rec
    --  where fecha_rfb_id >= DESDE_6M
      where fecha_baja_id BETWEEN DESDE AND HASTA AND fecha_rfb_id >=DESDE_6M 
    --  where fecha_baja_id >= DESDE_6M
      order by 1 asc, 2 asc;



    -- PASO 3: CREO TABLA INTEGRANDO TODAS LAS BAJAS DESCUBIERTAS EN TCNET y EKTNET
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_TOT` AS
      With bajas as (
              select *, 'EKTNET' as origendatos from  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_EKTNET_TOT`
              union all select *, 'TCNET' as origendatos from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_SVA_TCNET_TOT`
      ) SELECT DISTINCT *
      FROM BAJAS;



    -- PASO 4: CREO TABLA DE DECOMISIONES

        --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DES` AS
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS
        SELECT DISTINCT a.* REPLACE(
              `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),a.Fecha_Activacion, a.importe) as importe,
              `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),a.Fecha_Activacion, importe_nivel) as importe_nivel,
              `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),a.Fecha_Activacion, bono_comercial) as bono_comercial,
              `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),a.Fecha_Activacion, bono_calidad) as bono_calidad,
              case when coalesce(a.decom_bono_extra,'N')='S' THEN `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),a.Fecha_Activacion, bono_extras) ELSE NULL END as bono_extras,
              case when coalesce(a.decom_bono_extra,'N')='S' THEN `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),a.Fecha_Activacion, total)
                                                             ELSE `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),a.Fecha_Activacion, total - coalesce(bono_extras,0))    
              
              END as total

          ), --b.fecha_baja_dt  as FechaDesinstalacion,
          EXTRACT(DATE FROM b.fecha_baja_dt) as FechaDesinstalacion,
          b.fecha_baja_id as FechaDesinstalacion_id,        
          b.motivo_baja_ds as CausaBaja,
          b.motivo_baja_agrup_ds as CausaBajaGeneral
        FROM( select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com FROM `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`) a
        INNER JOIN `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_TOT` b ON a.marca_ds= b.marca_ds and a.IdProducto = b.servicio_id AND a.idCatalogo = b.catalogo_id
        WHERE Fecha_Activacion < DESDE_DT;

        /*
        SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DES`;
        SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`  where marca_ds!='R';

        select distinct a.*
        from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DES` as a
        inner join (SELECT distinct * FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`  where marca_ds!='R') as b on b.marca_ds=a.marca_ds and a.idProducto=b.idProducto;

        select distinct a.* from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DES` as a
        where not exists ( select 1 from (select * from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`  where marca_ds!='R') as b where b.marca_ds=a.marca_ds and a.idProducto=b.idProducto);
        */



        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC` AS
        SELECT d.*,  MES_DECOMISION as mes_decomision_id,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(desc_mm_com) as desc_mm
        from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d;

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS
        SELECT f.*,  `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
        from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC` f;

        DROP TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC`;


      --- PASO 5: INTEGRAR LAS DECOMISIONES DE R

        --- PASO 5.1: IDENTIFICO PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO
        --DECLARE DESDE_1M, DESDE, HASTA INT64;SET DESDE_1M=20230401;SET DESDE=20230501;SET HASTA=20230531;    




        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` AS      
        select p.row_id, p.TIPOENTIDAD, p.CODIGO, p.CODIGOPADRE,p.IDPRODUCTO,p.IDPRODUCTOPADRE, p.CREATED,p.LAST_UPD, p.ACCION, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.IDEXTERNO,p.IDINTERNO,c.tipoproducto, c.concepto, c.tipo_movimiento
        from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` as p    
        inner join  `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c   on c.idprodcat=p.CODIGO
        where contains_substr(p.accion,'baja')
            -- Condicion basada en fecha de flujo
            --and CAST(FORMAT_DATE("%Y%m%d",f.LAST_UPD) as INTEGER) BETWEEN DESDE_1M AND HASTA
            -- Condicion basada en fecha de baja producto
        --and CAST(FORMAT_DATE("%Y%m%d",p.CREATED) as INTEGER) BETWEEN DESDE_1M AND HASTA;
        and CAST(FORMAT_DATE("%Y%m%d",p.LAST_UPD) as INTEGER) BETWEEN DESDE_1M AND HASTA;  

        --- PASO 3.2: ENRIQUEZCO LOS PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO, CON LA CARACTERIZACION DE LOS FLUJOS CON LOS QUE SE HAN PROVISIONADO
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` AS      
        select "11" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO as FLJ_IDCONTRATO,f.IDEXPEDIENTE as FLJ_IDEXPEDIENTE, f.OPERACION AS FLJ_OPERACION,f.IDPRODUCTONEW as FLJ_IDPRODUCTONEW, f.IDPRODUCTOOLD as FLJ_IDPRODUCTOOLD, f.TIPOEVENTO as FLJ_TIPO_EVENTO, f.ESTADO as FLJ_ESTADO, f.ESTADOPRODUCTO AS FLJ_ESTADO_PRODUCTO,
        p.*
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
        inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD=p.IDPRODUCTO and f.IDPRODUCTONEW=p.IDPRODUCTO;

      
        INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
        select "10" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO as FLJ_IDCONTRATO,f.IDEXPEDIENTE as FLJ_IDEXPEDIENTE, f.OPERACION AS FLJ_OPERACION,f.IDPRODUCTONEW as FLJ_IDPRODUCTONEW, f.IDPRODUCTOOLD as FLJ_IDPRODUCTOOLD, f.TIPOEVENTO as FLJ_TIPO_EVENTO, f.ESTADO as FLJ_ESTADO, f.ESTADOPRODUCTO AS FLJ_ESTADO_PRODUCTO,
        p.*
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
        inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD=p.IDPRODUCTO and f.IDPRODUCTONEW!=p.IDPRODUCTO;


        INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
        select "01" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO as FLJ_IDCONTRATO,f.IDEXPEDIENTE as FLJ_IDEXPEDIENTE, f.OPERACION AS FLJ_OPERACION,f.IDPRODUCTONEW as FLJ_IDPRODUCTONEW, f.IDPRODUCTOOLD as FLJ_IDPRODUCTOOLD, f.TIPOEVENTO as FLJ_TIPO_EVENTO, f.ESTADO as FLJ_ESTADO, f.ESTADOPRODUCTO AS FLJ_ESTADO_PRODUCTO,
        p.*
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
        inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD!=p.IDPRODUCTO and f.IDPRODUCTONEW=p.IDPRODUCTO;


        INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
        select "00" as CRUCE,NULL, NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
        p.*
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p
        where not exists(
          select 1
          from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` f
          where f.row_id=p.row_id and f.IDPRODUCTO=p.IDPRODUCTO and f.FLJ_CREATED=p.CREATED and f.FLJ_LAST_UPD=p.LAST_UPD
        ) ;   
        

        

        --- PASO 5.2: ENRIQUEZCO LOS PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO, CON LA CARACTERIZACION DE LOS CONTRATOS Y EXPEDIOENTESCON LOS QUE SE HAN PROVISIONADO

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` AS
        with pob as (
          SELECT  ctr.SR_NUM as CTR_SR_NUM, ctr.SR_CAT_TYPE_CD as CTR_SR_CAT_TYPE_CD, ctr.SR_TYPE_CD as CTR_SR_TYPE_CD, ctr.SR_SUBTYPE_CD as CTR_SR_SUBTYPE_CD,ctr.PAR_SR_ID as CTR_PAR_SR_ID, ctr.SR_STAT_ID as CTR_SR_STAT_ID, ctr.CREATED as CTR_CREATED ,CTR.LAST_UPD as CTR_LAST_UPD, CTR.X_R_ID_CUENTA as IDCUENTA, CTR.X_R_CAUSA as CTREXP_CAUSA, CTR.desc_text as CTR_DESC,
          ef.SR_NUM as EXP_SR_NUM, ef.SR_TYPE_CD as EF_SR_TYPE_CD, ef.SR_SUBTYPE_CD as EF_SR_SUBTYPE_CD,
          cl.ou_num as CLIENTE_ID,
          f.* 
          FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` f
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` ctr on ctr.SR_NUM=f.FLJ_IDCONTRATO
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` ef on ef.SR_NUM=f.FLJ_IDEXPEDIENTE
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cl on cl.row_id=ctr.cst_ou_id 
        ) select distinct pob.*,
        P1.TIPOENTIDAD AS TIPOENTIDAD_POLD, P1.CODIGO AS CODIGO_POLD, P1.DESCRIPCION AS DESCRIPCION_POLD, P1.IDOPCION AS IDPCION_POLD, P1.ROW_ID AS ROW_ID_POLD, P1.IDPRODUCTO AS IDPRODUCTO_POLD,P1.CREATED AS CREATED_POLD, P1.ACCION AS ACCION_POLD, P1.IDOLD AS IDOLD_POLD, P1.IDINTERNO AS IDINTERNO_POLD, P1.IDEXTERNO AS IDEXTERNO_POLD, P1.IDTREESIEBEL AS IDTREESIEBEL_OLD, P1.IDTREEVOA AS IDTREEVOA_OLD,
        P2.TIPOENTIDAD AS TIPOENTIDAD_PNEW,  P2.CODIGO AS CODIGO_PNEW, P2.DESCRIPCION AS DESCRIPCION_PNEW, P2.IDOPCION AS IDPCION_PNEW, P2.ROW_ID AS ROW_ID_NEW, P2.IDPRODUCTO AS IDPRODUCTO_PNEW,P2.CREATED AS CREATED_PNEW,P2.ACCION AS ACCION_PNEW,P2.IDOLD AS IDOLD_PNEW, P2.IDINTERNO AS IDINTERNO_PNEW,P2.IDEXTERNO AS IDEXTERNO_PNEW,P2.IDTREESIEBEL AS IDTREESIEBEL_PNEW, P2.IDTREEVOA AS IDTREEVOA_PNEW,
        --- Producto, servicio, opción, cargo o promoción ha sido modificado
        --- VERIFICA SI IDTREED
        case when pob.FLJ_IDPRODUCTONEW=pob.FLJ_IDPRODUCTOOLD THEN 1 else 0 END as BMISMO_PRODUCTO,
        case when  p1.IDTREESIEBEL=p1.IDTREEVOA THEN 1 else 0 END as BSIEBEL_VOA_POLD,    
        case when  p2.IDTREESIEBEL=p2.IDTREEVOA THEN 1 else 0 END as BSIEBEL_VOA_PNEW,
        case when  p2.IDOLD=p1.ROW_ID THEN 1 else 0 END as BCAMBIO,
        case when  p1.IDOLD=p2.ROW_ID THEN 1 else 0 END as BCAMBIOINV,        
        --- Producto, servicio, opción, cargo o promoción es el final en la secuencia
        --p3.ROW_ID, case when coalesce(p3.row_id,'0')='0' THEN 1 else 0 END as bFinal,
    --    id.idunico,id.idsingleview,svh.base_product_instance_id,svh.active_date,  svh.service_subtype,
    --    svh.service_Status_code,svst.CODE_LABEL as EstadoServicio ,svh.effective_start_date,svh.effective_end_date,
    --    CAST(FORMAT_DATE('%Y%m%d',EXTRACT(DATE FROM parse_datetime('%d/%m/%Y %X',svh.effective_start_date ))) AS INT64) as fecha_inicio_id,
    --    CAST(FORMAT_DATE('%Y%m%d',EXTRACT(DATE FROM parse_datetime('%d/%m/%Y %X',svh.effective_end_date )))  AS INT64) as fecha_fin_id
        from pob 
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p1 on pob.FLJ_IDPRODUCTOOLD=p1.IDPRODUCTO  and pob.tipoentidad=p1.tipoentidad and pob.idinterno=p1.IDINTERNO
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p2 on pob.FLJ_IDPRODUCTONEW=p2.IDPRODUCTO and pob.tipoentidad=p2.tipoentidad and pob.idinterno=p2.IDINTERNO 
      --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p3 on p3.IDOLD=p2.ROW_ID and p3.tipoentidad=p2.tipoentidad and p3.idinterno=p2.IDINTERNO 
    --    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_td_identificadoresunicos` id on CAST(id.idunico as string)=pob.idinterno
    --    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_service_history` svh on svh.service_id=id.IDSINGLEVIEW and CAST(svh.CUSTOMER_NODE_ID AS STRING)=pob.idcuenta
    --    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_estadoservicios` svst on svst.REFERENCE_CODE = CAST(svh.SERVICE_STATUS_CODE AS STRING)
        order by pob.CTR_CREATED asc;



        --- PASO 5.3: IDENTIFICO LOS PRODUCTOS CONTENIDOS EN FLUJOS 
        ---             CON ULTIMA ACTUALIZACION PREVIA A VENTANA DE COMISIONADO
        ---             CON FLUJOS NO FINALIZADOS EN MES DE COMISIONADO
        ---             QUE DEPENDEN DE CONTRATOS DE REESTRUCTURACION

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R_FLUJO_MES_PREVIO` AS
        select p.*  
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` as p  
        where p.FLJ_LAST_UPD<DESDE_DT;  


        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R_FLUJO_NO_FINALIZADO_MES_COMISIONADO` AS
        select p.*
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` as p
        where p.FLJ_ESTADO!='5';
        
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R_REESTRUCTURACION` as 
        SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` 
        WHERE contains_substr(CTR_SR_SUBTYPE_CD,'reestructuracion');
        

        --- PASO 5.4: CREO TABLA DE BAJAS
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` AS
        select p.*
        from   `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` as p;

        --- PASO 5.5: ELIMINO BAJAS 
        ---             CON ULTIMA ACTUALIZACION PREVIA A VENTANA DE COMISIONADO
        ---             CON FLUJOS NO FINALIZADOS EN MES DE COMISIONADO
        ---             QUE DEPENDEN DE CONTRATOS DE REESTRUCTURACION
        ---             QUE NO ESTAN RELACIONADOS OPERACIONES DE BAJA EN FLUJO 

        DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where FLJ_LAST_UPD<DESDE_DT;  
        DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where COALESCE(CAST(FLJ_ESTADO AS INT64),0)!=5;
        DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` WHERE contains_substr(CTR_SR_SUBTYPE_CD,'reestructuracion');
        DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` WHERE not contains_substr(FLJ_OPERACION,"BAJA") and not contains_substr(tipo_movimiento,'vil');
        
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PREVIAS_PROMOCIONES_R`  AS SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R`;




        --- PASO 5.6: CALCULO DECOMISIONES DE PRODUCTOS DADOS DE BAJA

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` AS
        with p as (
            select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
            from `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
            where Fecha_Activacion >= DESDE_6M_DT and  Fecha_Activacion < DESDE_DT
        )
        select p.* except(decom_bono_extra, importe,nivel,importe_nivel, bono_comercial,bono_calidad,bono_extras,total, campana_id, nombre_campana,decomisionable,mes_comision_id, desc_mm_com,clase_mm_com),
          `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe) as importe,
            p.nivel,
          `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe_nivel) as importe_nivel,
          `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_comercial) as bono_comercial,
          `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_calidad) as bono_calidad,   
          --`mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total) as total,
          case when coalesce(p.decom_bono_extra,'N')='S' THEN `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_extras) ELSE NULL END as bono_extras,
          case when coalesce(p.decom_bono_extra,'N')='S' THEN `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total)
                                                          ELSE `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total - coalesce(p.bono_extras,0))
          END as total,        
        p.campana_id, p.nombre_campana,p.decomisionable,p.decom_bono_extra,p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,
        --CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE) as FechaDesinstalacion, 
        EXTRACT(DATE FROM TIMESTAMP(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ))) as FechaDesinstalacion,
        CAST(FORMAT_DATE("%Y%m%d",CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE)) AS INT64) as FechaDesinstalacion_id, 
        coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
        --coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
        mes_decomision as mes_decomision_id, 
        `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(p.desc_mm_com) as desc_mm
        --DATE_DIFF(CAST(b.CREATED AS date), p.Fecha_Activacion, DAY) as ndays 
        from p
        inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` as b on CAST(p.idproducto AS STRING )= CAST(b.IDINTERNO AS STRING ) or  CAST(p.idproducto AS STRING )= CAST(b.IDEXTERNO AS STRING)
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` as f on CAST(b.idproducto AS STRING)=cast(f.IDPRODUCTONEW AS STRING)
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ct on ct.sr_num=f.idcontrato;
        --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ef on ef.sr_num=f.idexpediente;
        


        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` AS
        SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK`;


        --- PASO 5.6.1 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK_FECHA_DESACTIVACION_INCORRECTA` AS
        SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` WHERE DATE_DIFF(FechaDesinstalacion,Fecha_Activacion,DAY)<0;

        DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK`  where DATE_DIFF(FechaDesinstalacion,Fecha_Activacion,DAY)<0;


        --- PASO 5.6.2 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` AS
        SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` 
        WHERE marca_ds='R'
        AND (contains_substr(TipoMovimiento,'equipamiento m') and contains_substr(TipoMovimiento, 'vil'))
        AND DATE_DIFF(FechaDesinstalacion,Fecha_Activacion,DAY)>15;

        DELETE  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` c
        where exists (
            select 1 from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` d
            where d.marca_ds=d.marca_ds and d.idfijo=c.idfijo and d.TipoProducto=c.TipoProducto and d.IdProducto=c.idProducto and d.TipoMovimiento=c.TipoMovimiento and d.concepto_ds=c.concepto_ds
        );



      --- PASO 5.7: INTEGRO DECOMISIONES DE PRODUCTOS DADOS DE BAJA EN EN R EN EL REGISTRO DE DECOMISIONES DEL GRUPO

        INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
        select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK`;


      --- PASO 6.8: DESCUBRO HISTORICO DE COMISIONES SOBRE PRODUCTOS QUE TIENEN COMO HIJOS PROMOCIONES

          --- Promociones vinculadas a productos dados de baja

          CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_BAJAS_SERVICIOS_MOVILES_CARTERA_R` AS 
          with psb as (
            select marca_ds, servicio_id, EXTRACT(DATETIME FROM sb.fecha_baja_dt) as fecha_baja_dt,sb.fecha_rfb_id,sb.fecha_baja_id
            from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` sb
            where sb.marca_ds='R'
            and sb.fecha_baja_id<99991201
            and sb.fecha_rfb_id<DESDE
            and sb.fecha_baja_id>=DESDE
            and categoria_servicio_ds='MOVILES POSTPAGO')
          select distinct psb.*, iu.idunico, s.person_id, s.CUSTOMER_NODE_ID, s.SERVICE_NAME, s.NETWORK_NAME, p.ROW_ID, p.TIPOENTIDAD, p.CODIGO, p.IDPRODUCTO, p.TIPOENTIDADPADRE,p.CODIGOPADRE,p.IDPRODUCTOPADRE, f.IDCONTRATO, f.OPERACION, f.IDPRODUCTONEW,f.IDPRODUCTOOLD,
          --svgpromo.idproducto as IDPROMO_EXPEDIENTE,svgpromo2.idproducto as IDPROMO_CONTRATO, 
          COALESCE(svgpromo.idproducto,svgpromo2.idproducto,CAST(NULL AS NUMERIC)) as IDPROMO
          from psb 
          inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_service_history` as s on psb.servicio_id=s.SERVICE_ID 
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_td_identificadoresunicos` iu  on iu.idsingleview=s.SERVICE_ID  
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p on p.idexterno=s.service_name  and CAST(p.idcuenta AS STRING)=CAST(s.CUSTOMER_NODE_ID AS STRING)
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD=p.IDPRODUCTO --and f.IDPRODUCTONEW=p.IDPRODUCTO--and f.ROW_ID=p.IDPROCESO
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` svgpromo on svgpromo.IDEXPEDIENTE=f.IDEXPEDIENTE
          left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_tr_promos_producto` svgpromo2 on svgpromo2.IDEXPEDIENTE=f.IDCONTRATO
          where contains_substr(f.OPERACION,'baja'); --and f.ROW_ID=p.IDPROCESO



        --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R` AS
          --    INICIAL
          --    with bprod as (SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where contains_substr(tipoentidad,'producto'))
          --    select p.row_id,p.idproducto, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.codigo, p.codigopadre, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.tiposervicio, p.idinterno, p.idexterno,p.IDCUENTA
          --    from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` as p
          --    inner join bprod on bprod.idproducto= p.IDPRODUCTO
          --    where contains_substr(p.TipoEntidad,"PROMOCION")
          --    order by p.idproducto, p.idinterno;
          --    POSTERIOR
          --select p.row_id,p.idproducto, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.codigo, p.codigopadre, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.tiposervicio, p.idinterno, p.idexterno,p.IDCUENTA
          --from `mm-commissions-reporting.KRT_CARTERA.LOG_0105_BAJAS_SERVICIOS_MOVILES_CARTERA_R` bs 
          --inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p on  p.idproducto=bs.IDPRODUCTO
          --inner join  `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c on c.idprodcat=p.CODIGO
          --where contains_substr(c.TipoProducto,'vil');


        -----PENDIENTE DE RESOLVER
        ----  COMISION CON IDENTIFICATIVO DE PROMOCION (campo numérico idproducto ci_sv_tr_promos_producto)
        ----  BAJA CON IDENTIFICATIVO DE FILA DE PROMOCION EN TABLA PRODUCTO, E IDENTIFICATIVO DE PRODUCTO 
        ----  

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` AS
        with p as (
            select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
            from `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
            where Fecha_Activacion >= DESDE_6M_DT  and  Fecha_Activacion < DESDE_DT
        )
        select p.* except(decom_bono_extra, importe,nivel,importe_nivel, bono_comercial,bono_calidad,bono_extras, total, campana_id, nombre_campana,decomisionable,mes_comision_id, desc_mm_com,clase_mm_com),
        `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe) as importe,
          p.nivel,
        `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe_nivel) as importe_nivel,
        `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_comercial) as bono_comercial,
        `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_calidad) as bono_calidad,   
        ---`mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total) as total,
        case when coalesce(p.decom_bono_extra,'N')='S' THEN `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_extras) ELSE NULL END as bono_extras,
        case when coalesce(p.decom_bono_extra,'N')='S' THEN `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total)
                                                          ELSE `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.fecha_baja_dt AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total - coalesce(p.bono_extras,0))
        END as total,        
        p.campana_id, p.nombre_campana,p.decomisionable,p.decom_bono_extra, p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,       
        EXTRACT(DATE FROM TIMESTAMP(CAST(b.fecha_baja_dt AS DATE))) as FechaDesinstalacion, 
        CAST(FORMAT_DATE("%Y%m%d",CAST(b.fecha_baja_dt AS DATE)) AS INT64) as FechaDesinstalacion_id,         
        coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,    
        --coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,    
        mes_decomision as mes_decomision_id, 
        `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(p.desc_mm_com) as desc_mm
        --DATE_DIFF(CAST(b.CREATED AS date), p.Fecha_Activacion, DAY) as ndays 
        from p
        inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0105_BAJAS_SERVICIOS_MOVILES_CARTERA_R` as b
        on CAST(p.idproducto AS STRING )= CAST(b.IDPROMO AS STRING )
        --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` as f on CAST(b.idproducto AS STRING)=cast(f.IDPRODUCTONEW AS STRING)
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ct on ct.sr_num=b.idcontrato;
        --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ef on ef.sr_num=f.idexpediente;




        --- PASO 5.8.1: GENERO DECOMISIONES SOBRE PRODUCTOS QUE TIENEN COMO HIJOS PROMOCIONES

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` AS
        SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
        from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK`;

      --- PASO 5.9: INTEGRO DECOMISIONES CALCULADAS EN REGISTRO DE DECOMISIONES DEL GRUPO
        INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
        select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` b
        where not exists(
          select 1 
          from  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d
          where d.marca_ds=b.marca_ds and d.idfijo=b.idfijo and d.IdProducto=b.idproducto
        );


      --- PASO 6: ELIMINO DECOMISIONES CON FECHA DE ACTIVACION MAYOR DE DESDE

        DELETE FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` WHERE Fecha_Activacion >= DESDE_DT;



      --- PASO 7: ELIMINO DECOMISIONES DUPLICADAS

        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` as 
        select distinct * except (FechaDesinstalacion_id) from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`;



      --- PASO 8: ELIMINAR DECOMISIONES PUBLICADAS EN MESES PREVIOS
        
        CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` AS
        SELECT d.* 
        from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`d 
        inner join `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_HISTORICO` dh
        on d.marca_ds=dh.marca_ds and d.IdFijo=dh.IdFijo  and d.IdProducto =dh.IdProducto and d.mes_decomision_id!=dh.mes_decomision_id;


        DELETE FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d
        WHERE EXISTS (
          SELECT 1
          FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` dp
          where d.marca_ds=dp.marca_ds and d.IdFijo=dp.IdFijo  and d.IdProducto =dp.IdProducto 
        );
    


      --- PASO 9: ELIMINO DECOMISIONES DE TERMINALES SIN DESISTIMIENTO

      DELETE  from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` 
      where (contains_substr(TipoMovimiento,"Alta Equipamiento móvil") or contains_substr(TipoMovimiento,"Alta Equipamiento movil") ) 
      and not contains_substr(coalesce(causaBaja,"NOINF"),"desistimiento")
      and date_diff(FechaDesinstalacion,Fecha_Activacion,DAY)>15;




      --- PASO 4:ACTUALIZO HISTORICO DE DECOMISIONES DUPLICADAS EN MESES PREVIOS
        --PASO TRASLADADO A MODULO SUBPROC_0701_ACTUALIZARHISTORICODECARTERAV1
        --DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
        --WHERE mes_decomision_id=MES_DECOMISION;

        --INSERT  INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
        --SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS`;

  

END