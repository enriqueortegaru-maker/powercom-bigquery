BEGIN
    DECLARE
      DESDE_DT,
      HASTA_DT,
      DESDE_1M_DT,
      HASTA_1M_DT,      
      DESDE_6M_DT date;
    DECLARE MES_DECOMISION,DESDE_1M, HASTA_1M INT64;
    --- LOCAL
    --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;    

    SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
    SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
    SET DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);
    SET DESDE_1M_DT=DATE_SUB(DESDE_DT, INTERVAL 1 MONTH);     
    SET DESDE_1M= CAST(FORMAT_DATE("%Y%m%d",DESDE_1M_DT) AS INT64);     
    SET HASTA_1M_DT= LAST_DAY(DESDE_1M_DT);   
    SET HASTA_1M=CAST(FORMAT_DATE("%Y%m%d",HASTA_1M_DT) AS INT64);    
    SET MES_DECOMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);


  --- PASO 1: CREAR LA TABLA LOG_DECOMISIONES
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS
    SELECT
      DISTINCT a.* REPLACE(
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(importe) AS importe,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(importe_nivel) AS importe_nivel,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(bono_comercial) AS bono_comercial,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(bono_calidad) AS bono_calidad,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(total) AS total ),
      EXTRACT(DATE FROM COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion)) as FechaDesinstalacion,        
      COALESCE(cpt.swCausaBaja, cpk.swCausaBaja) CausaBaja,
      COALESCE(cpt.swNombreCausaGral, cpk.swNombreCausaGral) CausaBajaGeneral
    FROM(
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        FROM `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
    ) a
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` cpt
    ON
      a.IdProducto = cpt.swInstProdId
      AND a.idCatalogo = CAST(cpt.swProdReleaseId AS string)
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` cpk
    ON
      a.idProducto = cpk.swInstProdId
      AND a.idCatalogo = CAST(cpk.swProdReleaseId AS string)
    WHERE
      ((CAST(cpt.swFechaDesinstalacion AS date) BETWEEN DESDE_DT
          AND HASTA_DT
          AND cpt.swCopiaProdId IS NULL)
        OR (CAST(cpk.swFechaDesinstalacion AS date) BETWEEN DESDE_DT
          AND HASTA_DT
          AND cpk.swCopiaProdId IS NULL))
      AND Fecha_Activacion >= DESDE_6M_DT
      AND Fecha_Activacion < DESDE_DT
      AND NOT (CONTAINS_SUBSTR(a.TipoMovimiento,"Alta Equipamiento móvil") and NOT(CONTAINS_SUBSTR(COALESCE(cpt.swCausaBaja, cpk.swCausaBaja),"Desistimiento")));


    --- PASO 2: NEGATIVIZAR IMPORTE

    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET importe = SAFE_NEGATE(importe) where importe!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET importe_nivel = SAFE_NEGATE(importe_nivel) where importe_nivel!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET total = SAFE_NEGATE(total) where total!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET bono_comercial = SAFE_NEGATE(bono_comercial) where bono_comercial!=0;            
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET bono_calidad = SAFE_NEGATE(bono_calidad) where bono_calidad!=0;            

    --- PASO 2 : TIPIFICAR DECOMISIONES
--    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` ADD COLUMN mes_decomision_id INT64,  ADD COLUMN clase_mm_com STRING, ADD COLUMN desc_mm_com STRING;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC` AS
    SELECT d.*, 
    MES_DECOMISION as mes_decomision_id,
    `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(desc_mm_com) as desc_mm
    from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS
    SELECT f.*, 
    `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC` f;

    DROP TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC`;


  --- PASO 3: INTEGRAR LAS DECOMISIONES DE R

    --- PASO 3.1: IDENTIFICO PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO
    --DECLARE DESDE_1M, DESDE, HASTA INT64;SET DESDE_1M=20230401;SET DESDE=20230501;SET HASTA=20230531;    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` AS      
    select p.row_id, p.TIPOENTIDAD, p.CODIGO, p.CODIGOPADRE,p.IDPRODUCTO,p.IDPRODUCTOPADRE, p.CREATED,p.LAST_UPD, p.ACCION, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.IDEXTERNO,p.IDINTERNO,c.tipoproducto, c.concepto, c.tipo_movimiento
    from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` as p    
    inner join  `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c   on c.idprodcat=p.CODIGO
    where contains_substr(p.accion,'baja')
        -- Condicion basada en fecha de flujo
        --and CAST(FORMAT_DATE("%Y%m%d",f.LAST_UPD) as INTEGER) BETWEEN DESDE_1M AND HASTA
        -- Condicion basada en fecha de baja producto
    and CAST(FORMAT_DATE("%Y%m%d",p.CREATED) as INTEGER) BETWEEN DESDE_1M AND HASTA;
  

    --- PASO 3.2: ENRIQUEZCO LOS PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO, CON LA CARACTERIZACION DE LOS FLUJOS CON LOS QUE SE HAN PROVISIONADO
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` AS      
    select "11" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO,f.IDEXPEDIENTE, f.OPERACION,f.IDPRODUCTONEW, f.IDPRODUCTOOLD, f.TIPOEVENTO, f.ESTADO, f.ESTADOPRODUCTO,
    p.*
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
    inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD=p.IDPRODUCTO and f.IDPRODUCTONEW=p.IDPRODUCTO;

  
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
    select "10" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO,f.IDEXPEDIENTE, f.OPERACION,f.IDPRODUCTONEW, f.IDPRODUCTOOLD, f.TIPOEVENTO, f.ESTADO, f.ESTADOPRODUCTO,
    p.*
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
    inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD=p.IDPRODUCTO and f.IDPRODUCTONEW!=p.IDPRODUCTO;


    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
    select "01" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO,f.IDEXPEDIENTE, f.OPERACION,f.IDPRODUCTONEW, f.IDPRODUCTOOLD, f.TIPOEVENTO, f.ESTADO, f.ESTADOPRODUCTO,
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
      where f.row_id=p.row_id and f.IDPRODUCTO=p.IDPRODUCTO and f.CREATED=p.CREATED and f.LAST_UPD=p.LAST_UPD
    ) ;   
    

    --- PASO 3.3: ENRIQUEZCO LOS PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO, CON LA CARACTERIZACION DE LOS CONTRATOS Y EXPEDIOENTESCON LOS QUE SE HAN PROVISIONADO
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` AS
    with pob as (
      SELECT  ctr.SR_NUM as CTR_SR_NUM, ctr.SR_CAT_TYPE_CD as CTR_SR_CAT_TYPE_CD, ctr.SR_TYPE_CD as CTR_SR_TYPE_CD, ctr.SR_SUBTYPE_CD as CTR_SR_SUBTYPE_CD,ctr.PAR_SR_ID as CTR_PAR_SR_ID, ctr.SR_STAT_ID as CTR_SR_STAT_ID, ctr.CREATED as CTR_CREATED ,CTR.LAST_UPD as CTR_LAST_UPD, CTR.X_R_ID_CUENTA as IDCUENTA, CTR.X_R_CAUSA as CTREXP_CAUSA, CTR.desc_text as CTR_DESC,
      ef.SR_NUM as EXP_SR_NUM, ef.SR_TYPE_CD as EF_SR_TYPE_CD, ef.SR_SUBTYPE_CD as EF_SR_SUBTYPE_CD,
      cl.ou_num as CLIENTE_ID,
      f.* 
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` f
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` ctr on ctr.SR_NUM=f.idcontrato
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` ef on ef.SR_NUM=f.idexpediente
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_org_ext` cl on cl.row_id=ctr.cst_ou_id
    ) select distinct pob.*,
    P1.TIPOENTIDAD AS TIPOENTIDAD_POLD, P1.CODIGO AS CODIGO_POLD, P1.DESCRIPCION AS DESCRIPCION_POLD, P1.IDOPCION AS IDPCION_POLD, P1.ROW_ID AS ROW_ID_POLD, P1.IDPRODUCTO AS IDPRODUCTO_POLD,P1.CREATED AS CREATED_POLD, P1.ACCION AS ACCION_POLD, P1.IDOLD AS IDOLD_POLD, P1.IDINTERNO AS IDINTERNO_POLD, P1.IDEXTERNO AS IDEXTERNO_POLD, P1.IDTREESIEBEL AS IDTREESIEBEL_OLD, P1.IDTREEVOA AS IDTREEVOA_OLD,
    P2.TIPOENTIDAD AS TIPOENTIDAD_PNEW,  P2.CODIGO AS CODIGO_PNEW, P2.DESCRIPCION AS DESCRIPCION_PNEW, P2.IDOPCION AS IDPCION_PNEW, P2.ROW_ID AS ROW_ID_NEW, P2.IDPRODUCTO AS IDPRODUCTO_PNEW,P2.CREATED AS CREATED_PNEW,P2.ACCION AS ACCION_PNEW,P2.IDOLD AS IDOLD_PNEW, P2.IDINTERNO AS IDINTERNO_PNEW,P2.IDEXTERNO AS IDEXTERNO_PNEW,P2.IDTREESIEBEL AS IDTREESIEBEL_PNEW, P2.IDTREEVOA AS IDTREEVOA_PNEW,
    --- Producto, servicio, opción, cargo o promoción ha sido modificado
    --- VERIFICA SI IDTREED
    case when pob.IDPRODUCTONEW=pob.IDPRODUCTOOLD THEN 1 else 0 END as BMISMO_PRODUCTO,
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
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p1 on pob.IDPRODUCTOOLD=p1.IDPRODUCTO  and pob.tipoentidad=p1.tipoentidad and pob.idinterno=p1.IDINTERNO
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p2 on pob.IDPRODUCTONEW=p2.IDPRODUCTO and pob.tipoentidad=p2.tipoentidad and pob.idinterno=p2.IDINTERNO 
  --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` p3 on p3.IDOLD=p2.ROW_ID and p3.tipoentidad=p2.tipoentidad and p3.idinterno=p2.IDINTERNO 
--    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_td_identificadoresunicos` id on CAST(id.idunico as string)=pob.idinterno
--    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_service_history` svh on svh.service_id=id.IDSINGLEVIEW and CAST(svh.CUSTOMER_NODE_ID AS STRING)=pob.idcuenta
--    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sv_estadoservicios` svst on svst.REFERENCE_CODE = CAST(svh.SERVICE_STATUS_CODE AS STRING)
    order by pob.CTR_CREATED asc;



    --- PASO 3.4: EXCLUYO LOS PRODUCTOS  CON FLUJOS CON ULTIMA ACTUALIZACION PREVIA A VENTANA DE COMISIONADO
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R_FLUJO_MES_PREVIO` AS
    select p.*
--    select p.row_id,p.IDPRODUCTO, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.CODIGO, p.CODIGOPADRE, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.IDEXTERNO,p.IDINTERNO,p.IDCUENTA, p.tipoproducto, p.concepto, p.tipo_movimiento
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` as p;
   
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` p where p.FLJ_LAST_UPD<DESDE_DT;

    --- PASO 3.5: EXCLUYO LOS PRODUCTOS CON FLUJOS NO FINALIZADOS EN MES DE COMISIONADO
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R_FLUJO_NO_FINALIZADO_MES_COMISIONADO` AS
    select p.*
--    select p.row_id,p.IDPRODUCTO, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.CODIGO, p.CODIGOPADRE, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.IDEXTERNO,p.IDINTERNO,p.IDCUENTA, p.tipoproducto, p.concepto, p.tipo_movimiento
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` as p
    where p.ESTADO!='5';
    
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` p where p.ESTADO!='5';


    --- PASO 3.5: EXCLUYO LOS PRODUCTOS  QUE DEPENDEN DE CONTRATOS DE REESTRUCTURACION
    ---- PARCHE TEMPORAL DE PRUEBA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R_REESTRUCTURACION` as SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` WHERE contains_substr(CTR_SR_SUBTYPE_CD,'reestructuracion');
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` WHERE contains_substr(CTR_SR_SUBTYPE_CD,'reestructuracion');
    ---- FIN PARCHE


    --- PASO 3.6: CREO TABLA DE BAJAS
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` AS
    select p.*
--    select p.row_id,p.IDPRODUCTO, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.CODIGO, p.CODIGOPADRE, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.IDEXTERNO,p.IDINTERNO,p.IDCUENTA, p.tipoproducto, p.concepto, p.tipo_movimiento
    from   `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_Y_CAMBIOS_R` as p;


    --- PASO 3.5: EXCLUYO LOS PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO Y QEU DEPENDEN DE CONTRATOS DE REESTRUCTURACION.

    --- PASO 3.2: CALCULO DECOMISIONES DE PRODUCTOS DADOS DE BAJA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` AS
    with p as (
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        from `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
        where Fecha_Activacion >= DESDE_6M_DT and  Fecha_Activacion < DESDE_DT
    )
    select p.* except(importe,nivel,importe_nivel, bono_comercial,bono_calidad,total, campana_id, nombre_campana,decomisionable,mes_comision_id, desc_mm_com,clase_mm_com),
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe) as importe,
      p.nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe_nivel) as importe_nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_comercial) as bono_comercial,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_calidad) as bono_calidad,   
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total) as total,
    p.campana_id, p.nombre_campana,p.decomisionable,p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,CAST(b.CREATED AS DATE) as FechaDesinstalacion, 
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


    --- PASO 3.2.1 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK_FECHA_DESACTIVACION_INCORRECTA` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` WHERE DATE_DIFF(FechaDesinstalacion,Fecha_Activacion,DAY)<0;

    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK`  where DATE_DIFF(FechaDesinstalacion,Fecha_Activacion,DAY)<0;


    --- PASO 3.2.2 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
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



    --- PASO 3.2.3: INTEGRO DECOMISIONES CALCULADAS EN REGISTRO DE DECOMISIONES DEL GRUPO


    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
    select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK`;


    --- PASO 3.2.4: DESCUBRO HISTORICO DE COMISIONES SOBRE PRODUCTOS QUE TIENEN COMO HIJOS PROMOCIONES

      --- Promociones vinculadas a productos dados de baja
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R` AS
    with bprod as (SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where contains_substr(tipoentidad,'producto'))
    select p.row_id,p.idproducto, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.codigo, p.codigopadre, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.tiposervicio, p.idinterno, p.idexterno,p.IDCUENTA
    from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` as p
    inner join bprod on bprod.idproducto= p.IDPRODUCTO
    where contains_substr(p.TipoEntidad,"PROMOCION")
    order by p.idproducto, p.idinterno;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` AS
    with p as (
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        from `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
        where Fecha_Activacion >= DESDE_6M_DT  and  Fecha_Activacion < DESDE_DT
     )
    select p.* except(importe,nivel,importe_nivel, bono_comercial,bono_calidad,total, campana_id, nombre_campana,decomisionable,mes_comision_id, desc_mm_com,clase_mm_com),
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe) as importe,
      p.nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe_nivel) as importe_nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_comercial) as bono_comercial,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_calidad) as bono_calidad,   
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total) as total,
    p.campana_id, p.nombre_campana,p.decomisionable,p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,CAST(b.CREATED AS DATE) as FechaDesinstalacion, 
    coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,    
    --coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,    
    mes_decomision as mes_decomision_id, 
    `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(p.desc_mm_com) as desc_mm
    --DATE_DIFF(CAST(b.CREATED AS date), p.Fecha_Activacion, DAY) as ndays 
    from p
    inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R` as b
    on CAST(p.idproducto AS STRING )= CAST(b.IDINTERNO AS STRING ) or  CAST(p.idproducto AS STRING )= CAST(b.IDEXTERNO AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` as f on CAST(b.idproducto AS STRING)=cast(f.IDPRODUCTONEW AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ct on ct.sr_num=f.idcontrato;
    --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ef on ef.sr_num=f.idexpediente;



    --- PASO 3.2.5: GENERO DECOMISIONES SOBRE PRODUCTOS QUE TIENEN COMO HIJOS PROMOCIONES


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` AS
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK`;

    --- PASO 3.2.6: INTEGRO DECOMISIONES CALCULADAS EN REGISTRO DE DECOMISIONES DEL GRUPO
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
    select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` b
    where not exists(
      select 1 
      from  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d
      where d.marca_ds=b.marca_ds and d.idfijo=b.idfijo and d.IdProducto=b.idproducto
    );


    --- PASO 3.2.7: ELIMINO DUPLICADOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` as 
    select distinct * from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`;


  --- PASO 4: ELIMINAR DECOMISIONES PUBLICADAS EN MESES PREVIOS
    
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
 



  --- PASO 4:ACTUALIZO HISTORICO DE DECOMISIONES DUPLICADAS EN MESES PREVIOS
    --PASO TRASLADADO A MODULO SUBPROC_0701_ACTUALIZARHISTORICODECARTERAV1
    --DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    --WHERE mes_decomision_id=MES_DECOMISION;

    --INSERT  INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    --SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS`;


END