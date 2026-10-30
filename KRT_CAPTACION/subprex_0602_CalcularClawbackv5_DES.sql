BEGIN 

  ------------------------------------------------------------------------------------
  ---
  --- EVOLUCION DE VERSION 2 PERO INFORMANDO EL TIPO DE OPERACION DE BAJA



      DECLARE vMES_DECOMISION_ID, DESDE_6M INT64;
      -- VAR LOCALES
      --DECLARE DESDE_BAJA, HASTA_BAJA INT64;SET DESDE_BAJA=20230701;SET HASTA_BAJA=20230731;
      -- FIN VAR LOCALES
      SET vMES_DECOMISION_ID= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE_BAJA AS string)),month)) AS INT64);
      SET DESDE_6M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE_BAJA AS string)), interval 6 month),month)) AS STRING) AS INT64);

    
      -- PASO 1: CREO TABLA DE BAJAS DE SERVICE BASE (LOG_0602_BAJAS_SB) 
    
      -- PASO 1.1: CREO TABLA DE BAJAS DE SERVICE BASE (FASE 10):

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB` AS
      SELECT b.marca_ds, b.cliente_id, b.servicio_id, b.servicio_id_origen, b.servicio_id_original, b.servicio_id_destino,  b.fecha_rfb_dt,  b.fecha_rfb_id, b.fecha_baja_dt,  b.fecha_baja_id,  b.motivo_baja_agrup_ds, b.motivo_baja_ds, b.catalogo_id, 
      b.operacion_baja_ds as operacion_baja_inicial_ds,   
      b.operacion_baja_ds, 
      10 as fase
      FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` b
      WHERE b.fecha_baja_id BETWEEN DESDE_BAJA AND HASTA_BAJA AND b.operacion_baja_ds IN ('BAJA', 'BAJA DOWNGRADE') AND b.fecha_rfb_id >=DESDE_6M; 
      

      --- PASO 1.2: SERVICIOS DE SERVICE BASE, QUE HAN CAUSADO BAJA, y QUE SE INSTANCIAN COMO CATALOGOS DE PRODUCTOS HIJOS  (FASE 15):
            --- EKTNET

      INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB`
      SELECT  DISTINCT CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'Telecable' THEN 'TELECABLE' END as marca_ds,
      p.swCustomerId as cliente_id,  sb.servicio_id as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, null as servicio_id_destino, p.swDateInstalled as fecha_rfb_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS STRING) as catalogo_id, 
      sb.operacion_baja_ds as operacion_baja_inicial_ds,   
      sb.operacion_baja_ds, 
      15 as fase 
      --FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` h 
      FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p --ON p.swInstProdId=h.swParentInstProdId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` sb on sb.servicio_id=p.swParentInstProdId and sb.catalogo_id=CAST(p.swProdReleaseId AS STRING)  
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm  ON c.mmMarcaId = mm.mmMarcaId
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` cat ON p.swProdReleaseId = CAST(CAST(cat.catalogo_id AS float64) AS int64) AND cat.tipo_identificacion_ds IN ('CATALOGO')  AND cat.Sistema_ds = 'EKTNET' AND cat.adicional_lg = 0
                and cat.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA   AND HASTA_BAJA  --AND p.swCopiaProdId IS NULL
      AND sb.fecha_baja_id BETWEEN DESDE_BAJA AND HASTA_BAJA AND sb.operacion_baja_ds IN ('BAJA', 'BAJA DOWNGRADE') AND sb.fecha_rfb_id >=DESDE_6M 
      AND NOT EXISTS (
        select 1 
        FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB` b
        where b.marca_ds in ('EUSKALTEL','RACC','VIRGIN') and b.servicio_id=sb.servicio_id 
        );
      
            --- TCNET

      INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB`
      SELECT  DISTINCT 'TELECABLE' as marca_ds,
      p.swCustomerId as cliente_id,  sb.servicio_id as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, null as servicio_id_destino, p.swDateInstalled as fecha_rfb_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS STRING) as catalogo_id, 
      sb.operacion_baja_ds as operacion_baja_inicial_ds,      
      sb.operacion_baja_ds, 
      15 as fase 
      --FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` h 
      FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p --ON p.swInstProdId=h.swParentInstProdId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` sb on sb.servicio_id=p.swParentInstProdId and sb.catalogo_id=CAST(p.swProdReleaseId AS STRING)     
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` cat ON p.swProdReleaseId = CAST(CAST(cat.catalogo_id AS float64) AS int64) AND cat.tipo_identificacion_ds IN ('CATALOGO')  AND cat.Sistema_ds = 'TCNET' AND cat.adicional_lg = 0 and cat.marca_ds='TELECABLE' 
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA   AND HASTA_BAJA  --AND p.swCopiaProdId IS NULL
      AND sb.fecha_baja_id BETWEEN DESDE_BAJA AND HASTA_BAJA AND sb.operacion_baja_ds IN ('BAJA', 'BAJA DOWNGRADE')  AND sb.fecha_rfb_id >=DESDE_6M 
      AND NOT EXISTS (
        select 1 
        FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB` b
        where b.marca_ds in ('TELECABLE') and b.servicio_id=sb.servicio_id 
        );


    -- PASO 1.3: CREO TABLA DE BAJAS DE SERVICE BASE (TABLA LOG_0602_BAJAS_SB_TOT) INCLUYENDO SECUENCIA DE MIGRACIONES DE LAS QUE PROCEDE CADA PRODUCTO (FASE 20):

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB_TOT` AS
      with recursive rec as (
        SELECT row_number() over(order by b.servicio_id) as idreg,1 as lvl,  b.marca_ds, b.cliente_id, b.servicio_id, b.servicio_id_origen, b.servicio_id_original, b.servicio_id_destino,  b.fecha_rfb_dt,  b.fecha_rfb_id, b.fecha_baja_dt,  b.fecha_baja_id,  b.motivo_baja_agrup_ds, b.motivo_baja_ds, b.catalogo_id, 
        b.operacion_baja_inicial_ds, 
        b.operacion_baja_ds, 
        b.fase  
        FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB` b
        UNION ALL 
        select r.idreg ,r.lvl+1 as lvl, s.marca_ds, s.cliente_id, s.servicio_id, s.servicio_id_origen, s.servicio_id_original, s.servicio_id_destino,   s.fecha_rfb_dt,   s.fecha_rfb_id, s.fecha_baja_dt,  s.fecha_baja_id,  s.motivo_baja_agrup_ds, s.motivo_baja_ds, s.catalogo_id, 
          r.operacion_baja_inicial_ds,
          s.operacion_baja_ds, 
          20 as fase
        FROM rec r
        inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`s 
        on r.marca_ds=s.marca_ds  and r.servicio_id=s.servicio_id_destino --and r.cliente_id=s.cliente_id
        --and not (s.servicio_id<0 and s.servicio_id_origen<0 and s.servicio_id_destino<0  and s.servicio_id_original<0) 
          --where (r.fecha_rfb_id >= DESDE_6M) and (s.fecha_rfb_id >= DESDE_6M)  and lvl<=10
        where lvl<=10 
          --and (r.fecha_baja_id >= DESDE_6M) 
          --and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) >= DESDE_6M)      
      ) select distinct * 
      from rec
      where fecha_baja_id BETWEEN DESDE_BAJA AND HASTA_BAJA AND fecha_rfb_id >=DESDE_6M 
      order by 1 asc, 2 asc;


      -- PASO 2: CREO TABLA DE BAJAS DE SVAS DE EKTNET (LOG_0602_BAJAS_SVA_EKTNET) (FASE 10)
      
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_EKTNET` AS
      SELECT  DISTINCT CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'Telecable' THEN 'TELECABLE' END as marca_ds,
      row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS STRING) as catalogo_Id, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_inicial_ds, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds, 
      10 as fase 
      FROM   `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p 
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm  ON c.mmMarcaId = mm.mmMarcaId
      --INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON cat.swProdReleaseId=p.swProdReleaseId
      --INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'EKTNET' and catalogo.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END -- AND adicional_lg = 0 
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA   AND HASTA_BAJA 
      AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M 
      AND not exists(
          select 1
          from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` d 
          where d.swProdOrigId= p.swInstProdId
        )
      --AND cat.swProductType='Servicio' and contains_substr(cat.swLineName,'televisi' )
      --AND p.swCopiaProdId IS NULL
      --- Cruce con producto padre -> Aplicar sólo a la linea de TV en marcas de GEKT ya que es allí donde aplica
      UNION ALL
      ----- PRODUCTOS DE TELEVISION REGISTRADOS COMO SBs
      SELECT  DISTINCT CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN'  WHEN 'RACCTEL+' THEN 'RACC'  WHEN 'Telecable' THEN 'TELECABLE' END as marca_ds,
      row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS STRING) as catalogo_Id, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_inicial_ds, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds, 
      15 as fase 
      FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` h 
      INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p ON p.swInstProdId=h.swParentInstProdId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` mm  ON c.mmMarcaId = mm.mmMarcaId
      --INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat ON cat.swProdReleaseId=p.swProdReleaseId
      --INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'EKTNET' AND adicional_lg = 0 and catalogo.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA   AND HASTA_BAJA  
      AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M
      AND not exists(
          select 1
          from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` d 
          where d.swProdOrigId= p.swInstProdId
        )

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
      ----INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'EKTNET' AND adicional_lg = 0 and catalogo.marca_ds=CASE mm.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL'  WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC'   WHEN 'Telecable' THEN 'TELECABLE' END
      --WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA  AND HASTA_BAJA  AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M; --AND p.swCopiaProdId IS NULL
      ;


    -- PASO 2.2: CREO TABLA DE BAJAS SVAS DE EKTNET (TABLA LOG_0602_BAJAS_SVA_EKTNET_TOT`) INCLUYENDO SECUENCIA DE MIGRACIONES DE LAS QUE PROCEDE CADA PRODUCTO (FASE 20):

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_EKTNET_TOT` AS
      with recursive rec as (
        SELECT b.idreg,1 as lvl,  b.marca_ds, b.cliente_id, b.servicio_id, b.servicio_id_origen, b.servicio_id_original, b.fecha_rfb_dt,   b.fecha_rfb_id, b.fecha_baja_dt,  b.fecha_baja_id,  b.motivo_baja_agrup_ds, b.motivo_baja_ds, b.catalogo_Id, 
          b.operacion_baja_inicial_ds, b.operacion_baja_ds, 
          b.fase  
          FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_EKTNET` b
          where not exists (
              select 1 
              from `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB_TOT` sb
              where sb.marca_ds=b.marca_ds and sb.servicio_id=b.servicio_id 
          )
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
          --INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON s.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'EKTNET' AND adicional_lg = 0 and r.marca_ds in ('EUSKALTEL','VIRGIN','RACC','TELECABLE')
        --and not (s.servicio_id<0 and s.servicio_id_origen<0 and s.servicio_id_destino<0  and s.servicio_id_original<0) 
    --   		where (r.fecha_rfb_id >= DESDE_6M) and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swDateInstalled) >= DESDE_6M)  and lvl<=10
          where lvl<=10 
          -- and (r.fecha_baja_id >= DESDE_6M)
          -- and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) >= DESDE_6M) 
      ) select distinct * 
      from rec
    --	where fecha_rfb_id >= DESDE_6M
      where fecha_baja_id BETWEEN DESDE_BAJA AND HASTA_BAJA AND fecha_rfb_id >=DESDE_6M 
      order by 1 asc, 2 asc;
      



      -- PASO 3: CREO TABLA DE BAJAS DE SVAS DE TCNET (LOG_0602_BAJAS_SVA_TCNET) (FASE 


      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_TCNET` AS
        ----- PRODUCTOS DESCUBIERTOS EN FASE 5 
      SELECT 'TELECABLE' as marca_ds,
      row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      CAST(p.swProdReleaseId AS STRING) as catalogo_Id, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_inicial_ds, 
      case when contains_substr(p.swCausaBaja,'baja') or contains_substr(p.swCausaBaja,'precio')  or contains_substr(p.swCausaBaja,' uso') then 'BAJA'  when contains_substr(p.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(p.swCausaBaja,'titular') or  contains_substr(p.swCausaBaja,'domicilio') or  contains_substr(p.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds, 
      10 as fase 
      FROM   `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p 
      --INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      --INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO') AND Sistema_ds = 'TCNET' AND adicional_lg = 0
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA   AND HASTA_BAJA AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M --AND p.swCopiaProdId IS NULL
      AND not exists(
          select 1
          from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` d 
          where d.swProdOrigId= p.swInstProdId
        )

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
      --INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO') AND Sistema_ds = 'TCNET' AND adicional_lg = 0
      WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA   AND HASTA_BAJA AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M  -- AND p.swCopiaProdId IS NULL
      AND not exists(
          select 1
          from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` d 
          where d.swProdOrigId= p.swInstProdId
        )

      --- Cruce con producto master -> Como se hace recurrencia creo que no es necesario
      --UNION ALL 
      --SELECT 'TELECABLE' as marca_ds,
      --row_number() over(order by p.swInstProdId) as idreg, p.swCustomerId as cliente_id,  p.swInstProdId as servicio_id,  p.swProdOrigId as servicio_id_origen, ifnull(p.swMasterInstProdId, 0) as servicio_id_original, p.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) fecha_rfb_id, p.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) fecha_baja_id,  p.swNombreCausaGral motivo_baja_agrup_ds,   p.swCausaBaja motivo_baja_ds, 
      --17 as fase 
      --FROM   `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` h 
      --INNER JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p ON p.swInstProdId=h.swMasterInstProdId
      ----INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` c ON p.swCustomerId = c.swCustomerId
      ----INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON p.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO') AND Sistema_ds = 'TCNET' AND adicional_lg = 0
      --WHERE   `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swFechaDesinstalacion) BETWEEN DESDE_BAJA   AND HASTA_BAJA  AND  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(p.swDateInstalled) >= DESDE_6M;--AND p.swCopiaProdId IS NULL
      ;


    -- PASO 3.2: CREO TABLA DE BAJAS SVAS DE EKTNET (TABLA LOG_0602_BAJAS_SVA_TCNET_TOT`) INCLUYENDO SECUENCIA DE MIGRACIONES DE LAS QUE PROCEDE CADA PRODUCTO (FASE 20):

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_TCNET_TOT` AS
      with recursive rec as (
        SELECT idreg, 1 as lvl,  b.marca_ds, b.cliente_id, b.servicio_id, b.servicio_id_origen, b.servicio_id_original,   b.fecha_rfb_dt,   b.fecha_rfb_id, b.fecha_baja_dt,  b.fecha_baja_id,  b.motivo_baja_agrup_ds, b.motivo_baja_ds, b.catalogo_id, 
          b.operacion_baja_inicial_ds, 
          b.operacion_baja_ds, 
          b.fase  
          FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_TCNET` b
          where not exists (
              select 1 
              from `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB_TOT` sb
              where sb.marca_ds=b.marca_ds and sb.servicio_id=b.servicio_id 
          )   
          UNION ALL 
          select r.idreg,r.lvl+1 as lvl, 
          'TELECABLE' as marca_ds,
          s.swCustomerId as cliente_id,  s.swInstProdId as servicio_id,  s.swProdOrigId as servicio_id_origen, ifnull(s.swMasterInstProdId, 0) as servicio_id_original, s.swDateInstalled as fecha_rfb_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swDateInstalled)  fecha_rfb_id, s.swFechaDesinstalacion fecha_baja_dt,  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) fecha_baja_id,  s.swNombreCausaGral motivo_baja_agrup_ds,  s.swCausaBaja motivo_baja_ds, CAST(s.swProdReleaseId AS STRING) as catalogo_Id,
          r.operacion_baja_inicial_ds, 
          case when contains_substr(s.swCausaBaja,'baja') or contains_substr(s.swCausaBaja,'precio')  or contains_substr(s.swCausaBaja,' uso') then 'BAJA'  when contains_substr(s.swCausaBaja,'migrac') then 'BAJA DOWN/UPGRADE'  when contains_substr(s.swCausaBaja,'titular') or  contains_substr(s.swCausaBaja,'domicilio') or  contains_substr(s.swCausaBaja,'segmento') then 'CAMBIO ADMINISTRATIVO' ELSE "" END as operacion_baja_ds,       
          20 as fase 
          FROM rec r
          inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto`s on r.servicio_id_origen=s.swInstProdId  --or r.servicio_id = s.swMasterInstProdId)-- and r.cliente_id=s.swCustomerId
          --INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` catalogo ON s.swProdReleaseId = CAST(CAST(catalogo_id AS float64) AS int64) AND tipo_identificacion_ds IN ('CATALOGO')  AND Sistema_ds = 'TCNET' AND adicional_lg = 0  and catalogo.marca_ds='TELECABLE'
        --and not (s.servicio_id<0 and s.servicio_id_origen<0 and s.servicio_id_destino<0  and s.servicio_id_original<0) 
    --      where (r.fecha_rfb_id >= DESDE_6M) and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swDateInstalled) >= DESDE_6M)  and lvl<=10
          where lvl<=10
          -- and (r.fecha_baja_id >= DESDE_6M) 
          -- and ( `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(s.swFechaDesinstalacion) >= DESDE_6M) 
      ) select distinct * 
      from rec
    --  where fecha_rfb_id >= DESDE_6M
      where fecha_baja_id BETWEEN DESDE_BAJA AND HASTA_BAJA AND fecha_rfb_id >=DESDE_6M 
    --  where fecha_baja_id >= DESDE_6M
      order by 1 asc, 2 asc;


      -- PASO 1.3: CREO TABLA DE BAJAS DE SVA DE R



      -- PASO 4: CREO TABLA INTEGRANDO TODAS LAS BAJAS DESCUBIERTAS


      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_TOT` AS
      With bajas as (
              select * except(servicio_id_destino), 'SB' as origendatos from `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB_TOT`
              union all select *, 'EKTNET' as origendatos from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_EKTNET_TOT`
              union all select *, 'TCNET' as origendatos from `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_TCNET_TOT`
      ) SELECT DISTINCT *
      FROM BAJAS;


      -- PASO 5: CREO TABLA DE CLAWBACK


      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` AS
      SELECT DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, 
      a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, 
      a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap, 
      `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),EXTRACT(DATE FROM a.fecha_rfb_dt), a.importe) as importe,
      a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds ,b.catalogo_id, b.origendatos, b.idreg, b.lvl,b.operacion_baja_inicial_ds, b.operacion_baja_ds, b.fase
      FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_TOT` b
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a ON a.servicio_id = b.servicio_id AND a.marca_ds = b.marca_ds
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c ON a.marca_ds = c.marca_ds AND a.nombre_distribuidor_alta_ds = c.nombre_distribuidor_ds AND a.canal_alta_ds = c.canal_ds 
      AND CASE  WHEN UPPER(c.subcanal_ds) <> 'X' THEN a.subcanal_ds = c.subcanal_ds ELSE 1=1 END 
      AND CASE   WHEN UPPER(c.equipo_ds) <> 'X' THEN a.equipo_ds = c.equipo_ds ELSE 1 = 1 END
      WHERE DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0 AND 180 AND a.decomisionable = 'S';

      INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES`
      SELECT DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, 
      a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, 
      a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap,
      `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),EXTRACT(DATE FROM a.fecha_rfb_dt), a.importe) as importe, 
      a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds ,b.catalogo_id, b.origendatos, b.idreg, b.lvl, b.operacion_baja_inicial_ds, b.operacion_baja_ds ,b.fase
      FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_TOT` b
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a ON a.servicio_id = b.servicio_id_original AND a.marca_ds = b.marca_ds
      INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca  ON a.marca_ds = ca.marca_ds AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds AND a.canal_alta_ds = ca.canal_ds 
      AND CASE   WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds ELSE 1=1 END 
      AND CASE   WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds ELSE 1 = 1 END
      where DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0 AND 180 AND a.decomisionable = 'S' 
      and not exists (
        select 1 
        from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` c
        where c.marca_ds=a.marca_ds and c.servicio_id=a.servicio_id 
      ); 




      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_CLAWBACK_HISTORIFICADO_DES` as  
      SELECT distinct  n.*, h.mes_decomision_id 
      FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` n 
      inner join `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO` h 
      on h.marca_ds=n.marca_ds and h.servicio_id=n.servicio_id and h.concepto_ds=n.concepto_ds  and h.fecha_baja_id=n.fecha_baja_id and h.mes_decomision_id<vmes_decomision_id;


      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` as  
      SELECT distinct * 
      FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` n 
      WHERE NOT EXISTS(
          SELECT 1
          FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_CLAWBACK_HISTORIFICADO_DES` h
          where h.marca_ds=n.marca_ds and h.servicio_id=n.servicio_id  and h.concepto_ds=n.concepto_ds  and h.fecha_baja_id=n.fecha_baja_id
        );



      SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` n 
      WHERE fecha_rfb_id>=DESDE_6M
      AND EXISTS(
          SELECT 1
          FROM  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO` h
          where h.marca_ds=n.marca_ds and h.servicio_id=n.servicio_id
        );





    ----- CONTROL -> Listado de decomisiones no descubiertas con metodo previo

      --- SB: 27
      with pob as (
        select s.*, lag(fecha_rfb_dt) over (partition by idreg order by lvl asc) as pr
        from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SB_TOT` s
        order by idreg, lvl)
      select pob.*, date_diff(pob.pr,pob.fecha_rfb_dt,DAY) as dif
      from pob
      where pr is not null;

      --- SVA EKTNET: 3853 16597 (452 con lvl>1)
      with pob as (
        select s.*, lag(fecha_rfb_dt) over (partition by idreg order by lvl asc) as pr
        from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_EKTNET_TOT` s
        order by idreg, lvl)
    select pob.*, date_diff(pob.pr,pob.fecha_rfb_dt,DAY) as dif
    from pob
    where pr is not null /*and lvl>1*/;


      --- SVA TCNET: 7936 1228 (15 con lvl>1)
    with pob as (
      select s.*, lag(fecha_rfb_dt) over (partition by idreg order by lvl asc) as pr
      from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_BAJAS_SVA_TCNET_TOT` s
      order by idreg, lvl)
    select pob.*, date_diff(pob.pr,pob.fecha_rfb_dt,DAY) as dif
    from pob
    where pr is not null /*and lvl>1*/;




    ---- AUDITORIA 

    -- coinciden 1116  CLAWBACK (1088) CLAWBACK_DES(1183)

    Select distinct  d.* except(fase,idreg, lvl)
    from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` d
    inner join `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
    on d.marca_ds=c.marca_ds  and d.servicio_id=c.servicio_id --and d.cliente_id=c.cliente_id
    ;


    --- En desarrollo no en producción 20

    Select  distinct d.* except(fase, idreg, lvl)
    from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` d
    inner join `mm-commissions-reporting.KRT_CAPTACION.AUDIT_CATALOGOSxMARCA` ct on ct.marca_ds= d.marca_ds and CAST(ct.catIdPr AS STRING)=d.catalogo_id
    where not exists (
      select 1 
      from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
      where d.marca_ds=c.marca_ds and d.servicio_id=c.servicio_id
    );



    --- En producción no en desarrollo 387 -> 205 ->0 -> 160 sobre todo en GEK, tras cambio de condiciones de SVAs e introducir cruce con param_catalogos ...71
    --- en Julio 1
    Select distinct  c.* 
    from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
    where not exists (
      select 1 
      from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` d
      --inner join `mm-commissions-reporting.KRT_CAPTACION.AUDIT_CATALOGOSxMARCA` ct on ct.marca_ds= d.marca_ds and CAST(ct.catIdPr AS STRING)=d.catalogo_id
      where d.marca_ds=c.marca_ds and d.servicio_id=c.servicio_id
    );



      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` as  
      SELECT distinct *  except(fase,idreg, lvl)
      FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_DES` n ;


      --- PASO 7 : CREAR TABLA DECOMISION y AÑADIR MES_DECOMISION_ID Y desc_mm

    --  DECLARE DESDE_BAJA, HASTA_BAJA INT64;SET DESDE_BAJA=20230401;SET HASTA_BAJA=20230430;
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES` AS
      SELECT c.*,vMES_DECOMISION_ID as mes_decomision_id, `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisiones`(c.categoria_servicio_ds, c.concepto_ds, c.fecha_baja_id, desde_baja, hasta_baja) as desc_mm
      FROM  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`c ;

    -- PASO 8: AÑADIR clase_mm
      --DECLARE DESDE_BAJA, HASTA_BAJA INT64;SET DESDE_BAJA=20230401;SET HASTA_BAJA=20230430;    
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES` AS
      SELECT c.*, `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(c.desc_mm) as clase_mm
      FROM `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES` c;


      -- PASO 10: RECREAR TABLA CLAWBACK

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` AS
      SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES`;

      

      -- PASO 11: BORRAR TABLA DECOMISIONES
      DROP TABLE  `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES`;



      --- PASO 12: ELIMINAR DECOMISIONES PUBLICADAS EN MESES PREVIOS

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` AS
      SELECT d.* 
      from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`d 
      inner join `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO` dh
      on d.marca_ds=dh.marca_ds and d.cliente_id=dh.cliente_id  and d.servicio_id =dh.servicio_id and d.mes_decomision_id!=dh.mes_decomision_id;


      DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` d
      WHERE EXISTS ( SELECT 1 FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` dp where  d.marca_ds=dp.marca_ds and d.cliente_id=dp.cliente_id  and d.servicio_id =dp.servicio_id
      );
    


    --- PASO 14: PUBLICAR COMISIONES DUPLICADAS EN MES DE COMISION  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_DUPLICADAS_MES_DECOMISION` AS with ncom as (select marca_ds, cliente_id, servicio_id, CONCEPTO_DS, count(importe) as ncom, sum(importe) as importe from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` as com where not contains_substr(concepto_ds,'cancela') group by 1,2,3,4)  select c.* from ncom inner join `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c on ncom.marca_ds=c.marca_ds and ncom.Cliente_id=c.Cliente_id and coalesce(ncom.servicio_id,0)=coalesce(c.servicio_id,0) and ncom.concepto_ds=c.concepto_ds where ncom.ncom>1  order by c.marca_ds, c.cliente_id, c.servicio_id, c.concepto_ds;
    



END