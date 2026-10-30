BEGIN
    /* PREVIO
    DECLARE
      DESDE_DT,
      HASTA_DT,
      DESDE_1M_DT,
      HASTA_1M_DT,      
      DESDE_6M_DT date;
    DECLARE MES_DECOMISION,DESDE_1M, HASTA_1M INT64;
    --- LOCAL
    --DECLARE DESDE, HASTA INT64;SET DESDE=20230601;SET HASTA=20230623;    

    SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
    SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
    SET DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);
    SET DESDE_1M_DT=DATE_SUB(DESDE_DT, INTERVAL 1 MONTH);     
    SET DESDE_1M= CAST(FORMAT_DATE("%Y%m%d",DESDE_1M_DT) AS INT64);     
    SET HASTA_1M_DT= LAST_DAY(DESDE_1M_DT);   
    SET HASTA_1M=CAST(FORMAT_DATE("%Y%m%d",HASTA_1M_DT) AS INT64);    
    SET MES_DECOMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);

    FIN PREVIO*/


    DECLARE DESDE_DT, HASTA_DT, DESDE_1M_DT, HASTA_1M_DT, DESDE_6M_DT, DESDE_24M_DT date;
    DECLARE MES_DECOMISION,DESDE_1M, HASTA_1M INT64;
    --- LOCAL
    --DECLARE DESDE, HASTA INT64;SET DESDE=20230901;SET HASTA=20230930;    

    SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
    SET HASTA_1M_DT= LAST_DAY(DESDE_1M_DT);    
    SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
    SET DESDE_1M_DT=DATE_SUB(DESDE_DT, INTERVAL 1 MONTH);       
    SET DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);    
    SET DESDE_24M_DT=DATE_SUB(DESDE_DT, INTERVAL 24 MONTH);     
     
    SET DESDE_1M= CAST(FORMAT_DATE("%Y%m%d",DESDE_1M_DT) AS INT64);
    SET HASTA_1M=CAST(FORMAT_DATE("%Y%m%d",HASTA_1M_DT) AS INT64);    
    SET MES_DECOMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);




  --- PASO 3: INTEGRAR LAS DECOMISIONES DE R

    --- PASO 3.1: IDENTIFICO PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO
    --DECLARE DESDE_1M, DESDE, HASTA INT64;SET DESDE_1M=20230401;SET DESDE=20230501;SET HASTA=20230531;    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_PRODUCTOS_BAJAS_Y_CAMBIOS_R` AS      
    select p.row_id, p.TIPOENTIDAD, p.CODIGO, p.CODIGOPADRE,p.IDPRODUCTO,p.IDPRODUCTOPADRE, p.CREATED,p.LAST_UPD, p.ACCION, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.IDEXTERNO,p.IDINTERNO,c.categoria_servicio_ds, c.concepto_ds, c.tecnologia_detalle_ds    
    from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` as p    
    inner join  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` c   on c.catalogo_id=p.CODIGO
    where contains_substr(p.accion,'baja')
    and contains_substr(c.tipo_identificacion_ds,'catalogo')
        -- Condicion basada en fecha de flujo
        --and CAST(FORMAT_DATE("%Y%m%d",f.LAST_UPD) as INTEGER) BETWEEN DESDE_1M AND HASTA
        -- Condicion basada en fecha de baja producto
    --and CAST(FORMAT_DATE("%Y%m%d",p.CREATED) as INTEGER) BETWEEN DESDE_1M AND HASTA;
    and CAST(FORMAT_DATE("%Y%m%d",p.LAST_UPD) as INTEGER) BETWEEN DESDE_1M AND HASTA;  

    --- PASO 3.2: ENRIQUEZCO LOS PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO, CON LA CARACTERIZACION DE LOS FLUJOS CON LOS QUE SE HAN PROVISIONADO
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` AS      
    select "11" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO as FLJ_IDCONTRATO,f.IDEXPEDIENTE as FLJ_IDEXPEDIENTE, f.OPERACION AS FLJ_OPERACION,f.IDPRODUCTONEW as FLJ_IDPRODUCTONEW, f.IDPRODUCTOOLD as FLJ_IDPRODUCTOOLD, f.TIPOEVENTO as FLJ_TIPO_EVENTO, f.ESTADO as FLJ_ESTADO, f.ESTADOPRODUCTO AS FLJ_ESTADO_PRODUCTO,
    p.*
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
    inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD=p.IDPRODUCTO and f.IDPRODUCTONEW=p.IDPRODUCTO;

  
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
    select "10" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO as FLJ_IDCONTRATO,f.IDEXPEDIENTE as FLJ_IDEXPEDIENTE, f.OPERACION AS FLJ_OPERACION,f.IDPRODUCTONEW as FLJ_IDPRODUCTONEW, f.IDPRODUCTOOLD as FLJ_IDPRODUCTOOLD, f.TIPOEVENTO as FLJ_TIPO_EVENTO, f.ESTADO as FLJ_ESTADO, f.ESTADOPRODUCTO AS FLJ_ESTADO_PRODUCTO,
    p.*
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
    inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD=p.IDPRODUCTO and f.IDPRODUCTONEW!=p.IDPRODUCTO;


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
    select "01" as CRUCE,f.created as FLJ_CREATED, f.last_upd as FLJ_LAST_UPD, f.IDCONTRATO as FLJ_IDCONTRATO,f.IDEXPEDIENTE as FLJ_IDEXPEDIENTE, f.OPERACION AS FLJ_OPERACION,f.IDPRODUCTONEW as FLJ_IDPRODUCTONEW, f.IDPRODUCTOOLD as FLJ_IDPRODUCTOOLD, f.TIPOEVENTO as FLJ_TIPO_EVENTO, f.ESTADO as FLJ_ESTADO, f.ESTADOPRODUCTO AS FLJ_ESTADO_PRODUCTO,
    p.*
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p    
    inner join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` f on f.IDPRODUCTOOLD!=p.IDPRODUCTO and f.IDPRODUCTONEW=p.IDPRODUCTO;


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R`
    select "00" as CRUCE,NULL, NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    p.*
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_PRODUCTOS_BAJAS_Y_CAMBIOS_R` as p
    where not exists(
      select 1
      from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` f
      where f.row_id=p.row_id and f.IDPRODUCTO=p.IDPRODUCTO and f.FLJ_CREATED=p.CREATED and f.FLJ_LAST_UPD=p.LAST_UPD
    ) ;   
    

    

    --- PASO 3.3: ENRIQUEZCO LOS PRODUCTOS QUE SE HAN DADO DE BAJA O HAN CAMBIADO DESDE 1 MES ANTES DEL EN PERIODO DE COMISIONADO, CON LA CARACTERIZACION DE LOS CONTRATOS Y EXPEDIOENTESCON LOS QUE SE HAN PROVISIONADO

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R` AS
    with pob as (
      SELECT  ctr.SR_NUM as CTR_SR_NUM, ctr.SR_CAT_TYPE_CD as CTR_SR_CAT_TYPE_CD, ctr.SR_TYPE_CD as CTR_SR_TYPE_CD, ctr.SR_SUBTYPE_CD as CTR_SR_SUBTYPE_CD,ctr.PAR_SR_ID as CTR_PAR_SR_ID, ctr.SR_STAT_ID as CTR_SR_STAT_ID, ctr.CREATED as CTR_CREATED ,CTR.LAST_UPD as CTR_LAST_UPD, CTR.X_R_ID_CUENTA as IDCUENTA, CTR.X_R_CAUSA as CTREXP_CAUSA, CTR.desc_text as CTR_DESC,
      ef.SR_NUM as EXP_SR_NUM, ef.SR_TYPE_CD as EF_SR_TYPE_CD, ef.SR_SUBTYPE_CD as EF_SR_SUBTYPE_CD,
      cl.ou_num as CLIENTE_ID,
      f.* 
      FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_FLUJOSxPRODUCTOS_BAJAS_Y_CAMBIOS_R` f
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



    --- PASO 3.4: IDENTIFICO LOS PRODUCTOS CONTENIDOS EN FLUJOS 
    ---             CON ULTIMA ACTUALIZACION PREVIA A VENTANA DE COMISIONADO
    ---             CON FLUJOS NO FINALIZADOS EN MES DE COMISIONADO
    ---             QUE DEPENDEN DE CONTRATOS DE REESTRUCTURACION

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R_FLUJO_MES_PREVIO` AS
    select p.*  
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R` as p  
    where p.FLJ_LAST_UPD<DESDE_DT;  


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R_FLUJO_NO_FINALIZADO_MES_COMISIONADO` AS
    select p.*
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R` as p
    where p.FLJ_ESTADO!='5';
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R_REESTRUCTURACION` as 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R` 
    WHERE contains_substr(CTR_SR_SUBTYPE_CD,'reestructuracion');
    

    --- PASO 3.5: CREO TABLA DE BAJAS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` AS
    select p.*
    from   `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_Y_CAMBIOS_R` as p;

    --- PASO 3.6: ELIMINO BAJAS 
    ---             CON ULTIMA ACTUALIZACION PREVIA A VENTANA DE COMISIONADO
    ---             CON FLUJOS NO FINALIZADOS EN MES DE COMISIONADO
    ---             QUE DEPENDEN DE CONTRATOS DE REESTRUCTURACION
    ---             QUE NO ESTAN RELACIONADOS OPERACIONES DE BAJA EN FLUJO 

    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` where FLJ_LAST_UPD<DESDE_DT;  
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` where COALESCE(CAST(FLJ_ESTADO AS INT64),0)!=5;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` WHERE contains_substr(CTR_SR_SUBTYPE_CD,'reestructuracion');
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` WHERE not contains_substr(FLJ_OPERACION,"BAJA") ;
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_PREVIAS_PROMOCIONES_R`  AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R`;


/*PREVIO

    --- PASO 3.2: CALCULO DECOMISIONES DE PRODUCTOS DADOS DE BAJA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK` AS
    with p as (
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO`
        where EXTRACT(DATE FROM fecha_rfb_dt) >= DESDE_6M_DT and  EXTRACT(DATE FROM fecha_rfb_dt) < DESDE_DT
    )
    select p.* except(importe,mes_comision_id, desc_mm_com,clase_mm_com),
    `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), EXTRACT(DATE FROM p.fecha_rfb_dt), p.importe) as importe,
    p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE) as FechaDesinstalacion, 
    coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
    --coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
    mes_decomision as mes_decomision_id, 
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisiones`(b.categoria_servicio_ds, b.concepto_ds, CAST(FORMAT_DATE("%Y%m%d",date_trunc(FLJ_LAST_UPD,day)) as integer),desde,hasta) as desc_mm
    --DATE_DIFF(CAST(b.CREATED AS date), p.fecha_rfb_dt, DAY) as ndays 
    from p
    inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` as b on CAST(p.servicio_id AS STRING )= CAST(b.IDINTERNO AS STRING ) or  CAST(p.servicio_id AS STRING )= CAST(b.IDEXTERNO AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` as f on CAST(b.idproducto AS STRING)=cast(f.IDPRODUCTONEW AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ct on ct.sr_num=f.idcontrato;
    --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ef on ef.sr_num=f.idexpediente;
    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK` AS
    SELECT *,`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK`;


    --- PASO 3.2.1 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_FECHA_DESACTIVACION_INCORRECTA` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK` WHERE DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)<0;

    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK`  where DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)<0;


    --- PASO 3.2.2 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK` 
    WHERE marca_ds='R'
    AND contains_substr(categoria_servicio_ds,'TERMINAL') 
    AND DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)>15;

     
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK` c
    where exists (
        select 1 
        from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` d
        where d.marca_ds=c.marca_ds and d.cliente_id=c.cliente_id and d.servicio_id=c.servicio_id  and d.categoria_servicio_ds=c.categoria_servicio_ds and d.concepto_ds=c.concepto_ds
    );


    --- PASO 3.2.3: INTEGRO DECOMISIONES CALCULADAS EN REGISTRO DE DECOMISIONES DEL GRUPO


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_SVA_R` as
    select marca_ds, Cliente_id ,servicio_id ,detalle_servicio_ds ,concepto_ds ,fecha_rfb_id ,fecha_venta_neta_id ,fecha_rfb_dt ,fecha_venta_neta_dt ,canal_alta_ds ,subcanal_ds ,tipo_canal_alta_ds ,nombre_distribuidor_alta_ds ,agente_alta_id ,agente_creador_id ,categoria_servicio_ds ,cif_nif ,segmento_ds ,subsegmento_ds ,marca_cartera_ds ,Antiguedad_Cliente ,equipo_ds ,territorio_ds ,clave ,marco_retributivo_ds ,flag_marca_cartera ,grupo_rappel_ds ,orden_sap ,importe ,decomisionable ,CAST(FechaDesinstalacion as timestamp)  as fecha_baja_dt, CAST(FORMAT_DATE("%Y%m%d",FechaDesinstalacion) As INT64) as fecha_baja_id ,CausaBaja ,CausaBajaGeneral,MES_DECOMISION,
 `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisionesv1`(categoria_servicio_ds, concepto_ds, CAST(FORMAT_DATE("%Y%m%d",FechaDesinstalacion) As INT64), desde, hasta) as desc_mm
 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK`;

  
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_SVA_R` as 
    select *, 
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_SVA_R`;


    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_SVA_R`;



  FIN PREVIO  */


    --- PASO 4.1: CALCULO DECOMISIONES DE PRODUCTOS DADOS DE BAJA

    --- PASO 4.1.1: CALCULO DECOMISIONES DE 24M

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M` AS
    with p as (
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO`
        where EXTRACT(DATE FROM fecha_rfb_dt) >= DESDE_24M_DT and  EXTRACT(DATE FROM fecha_rfb_dt) < DESDE_DT
    )
    select p.* except(importe,mes_comision_id, desc_mm_com,clase_mm_com),
    `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), EXTRACT(DATE FROM p.fecha_rfb_dt), p.importe) as importe,
    p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE) as FechaDesinstalacion, 
    coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
    --coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
    mes_decomision as mes_decomision_id, 
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisiones`(b.categoria_servicio_ds, b.concepto_ds, CAST(FORMAT_DATE("%Y%m%d",date_trunc(FLJ_LAST_UPD,day)) as integer),desde,hasta) as desc_mm
    --DATE_DIFF(CAST(b.CREATED AS date), p.fecha_rfb_dt, DAY) as ndays 
    from p
    inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` as b on CAST(p.servicio_id AS STRING )= CAST(b.IDINTERNO AS STRING ) or  CAST(p.servicio_id AS STRING )= CAST(b.IDEXTERNO AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` as f on CAST(b.idproducto AS STRING)=cast(f.IDPRODUCTONEW AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ct on ct.sr_num=f.idcontrato;
    --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ef on ef.sr_num=f.idexpediente;
    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M` AS
    SELECT *,`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M`;


    --- PASO 4.1.1 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M_FECHA_DESACTIVACION_INCORRECTA` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M` WHERE DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)<0;

    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M`  where DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)<0;


    --- PASO 4.1.2 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M` 
    WHERE marca_ds='R'
    AND contains_substr(categoria_servicio_ds,'TERMINAL') 
    AND DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)>15;

     
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M` c
    where exists (
        select 1 
        from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` d
        where d.marca_ds=c.marca_ds and d.cliente_id=c.cliente_id and d.servicio_id=c.servicio_id  and d.categoria_servicio_ds=c.categoria_servicio_ds and d.concepto_ds=c.concepto_ds
    );


    --- PASO 4.1.1: CALCULO DECOMISIONES DE 6M

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M` AS
    with p as (
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        from `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO`
        where EXTRACT(DATE FROM fecha_rfb_dt) >= DESDE_6M_DT and  EXTRACT(DATE FROM fecha_rfb_dt) < DESDE_DT
    )
    select p.* except(importe,mes_comision_id, desc_mm_com,clase_mm_com),
    `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE), EXTRACT(DATE FROM p.fecha_rfb_dt), p.importe) as importe,
    p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,CAST(COALESCE(b.FLJ_LAST_UPD,b.LAST_UPD ) AS DATE) as FechaDesinstalacion, 
    coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
    --coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBaja, coalesce(ct.X_R_CAUSA, ef.X_R_CAUSA, CAST(NULL as string)) as CausaBajaGeneral,
    mes_decomision as mes_decomision_id, 
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisiones`(b.categoria_servicio_ds, b.concepto_ds, CAST(FORMAT_DATE("%Y%m%d",date_trunc(FLJ_LAST_UPD,day)) as integer),desde,hasta) as desc_mm
    --DATE_DIFF(CAST(b.CREATED AS date), p.fecha_rfb_dt, DAY) as ndays 
    from p
    inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R` as b on CAST(p.servicio_id AS STRING )= CAST(b.IDINTERNO AS STRING ) or  CAST(p.servicio_id AS STRING )= CAST(b.IDEXTERNO AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_provision` as f on CAST(b.idproducto AS STRING)=cast(f.IDPRODUCTONEW AS STRING)
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ct on ct.sr_num=f.idcontrato;
    --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_s_srv_req` as ef on ef.sr_num=f.idexpediente;
    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M` AS
    SELECT *,`mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M`;


    --- PASO 4.1.1 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M_FECHA_DESACTIVACION_INCORRECTA` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M` WHERE DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)<0;

    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M`  where DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)<0;


    --- PASO 4.1.2 Elimino casos en los que la fecha de desinstalacion es previa a la de activación
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M` 
    WHERE marca_ds='R'
    AND contains_substr(categoria_servicio_ds,'TERMINAL') 
    AND DATE_DIFF(FechaDesinstalacion,EXTRACT(DATE FROM fecha_rfb_dt),DAY)>15;

     
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M` c
    where exists (
        select 1 
        from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M_TERMINALES_EXCLUIDOS_NO_DESESTIMIENTO` d
        where d.marca_ds=c.marca_ds and d.cliente_id=c.cliente_id and d.servicio_id=c.servicio_id  and d.categoria_servicio_ds=c.categoria_servicio_ds and d.concepto_ds=c.concepto_ds
    );




    --- PASO 4.2: INTEGRO DECOMISIONES CALCULADAS EN REGISTRO DE DECOMISIONES DEL GRUPO

    --- PASO 4.2.1: DECOMISIONES DE 24M
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_24M_SVA_R` as
    select marca_ds, Cliente_id ,servicio_id ,detalle_servicio_ds ,concepto_ds ,fecha_rfb_id ,fecha_venta_neta_id ,fecha_rfb_dt ,fecha_venta_neta_dt ,canal_alta_ds ,subcanal_ds ,tipo_canal_alta_ds ,nombre_distribuidor_alta_ds ,agente_alta_id ,agente_creador_id ,categoria_servicio_ds ,cif_nif ,segmento_ds ,subsegmento_ds ,marca_cartera_ds ,Antiguedad_Cliente ,equipo_ds ,territorio_ds ,clave ,marco_retributivo_ds ,flag_marca_cartera ,grupo_rappel_ds ,orden_sap ,importe ,decomisionable ,CAST(FechaDesinstalacion as timestamp)  as fecha_baja_dt, CAST(FORMAT_DATE("%Y%m%d",FechaDesinstalacion) As INT64) as fecha_baja_id ,CausaBaja ,CausaBajaGeneral,MES_DECOMISION,
 `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisionesv1`(categoria_servicio_ds, concepto_ds, CAST(FORMAT_DATE("%Y%m%d",FechaDesinstalacion) As INT64), desde, hasta) as desc_mm
 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_24M`;

  
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_24M_SVA_R` as 
    select *, 
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_24M_SVA_R`;


    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_24M` 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_24M_SVA_R`;


    --- PASO 4.2.1: DECOMISIONES DE 6M
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_6M_SVA_R` as
    select marca_ds, Cliente_id ,servicio_id ,detalle_servicio_ds ,concepto_ds ,fecha_rfb_id ,fecha_venta_neta_id ,fecha_rfb_dt ,fecha_venta_neta_dt ,canal_alta_ds ,subcanal_ds ,tipo_canal_alta_ds ,nombre_distribuidor_alta_ds ,agente_alta_id ,agente_creador_id ,categoria_servicio_ds ,cif_nif ,segmento_ds ,subsegmento_ds ,marca_cartera_ds ,Antiguedad_Cliente ,equipo_ds ,territorio_ds ,clave ,marco_retributivo_ds ,flag_marca_cartera ,grupo_rappel_ds ,orden_sap ,importe ,decomisionable ,CAST(FechaDesinstalacion as timestamp)  as fecha_baja_dt, CAST(FORMAT_DATE("%Y%m%d",FechaDesinstalacion) As INT64) as fecha_baja_id ,CausaBaja ,CausaBajaGeneral,MES_DECOMISION,
 `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisionesv1`(categoria_servicio_ds, concepto_ds, CAST(FORMAT_DATE("%Y%m%d",FechaDesinstalacion) As INT64), desde, hasta) as desc_mm
 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_BAJAS_R_CLAWBACK_6M`;

  
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_6M_SVA_R` as 
    select *, 
    `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_6M_SVA_R`;


    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_6M` 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0603_CLAWBACK_6M_SVA_R`;


    --- PASO 5: RECREO CLAWBACK
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`  as SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_6M`; 

END