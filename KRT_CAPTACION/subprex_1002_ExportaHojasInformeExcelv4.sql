BEGIN
    -- Hoja COMISIONES y COMISIONES_DETALLE (version >=6)

  -- VARIABLES LOCALES  
  --DECLARE DESDE, HASTA, VERSION_FL INT64;SET DESDE=20240601;SET HASTA=20240630;SET VERSION_FL=14;

    /*
    if version_fl<=5 then    
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.OUT_COMISIONES` AS
      SELECT  marca_ds, Cliente_id, servicio_id, detalle_servicio_ds, CONCEPTO_DS, FECHA_RFB_ID, FECHA_VENTA_NETA_ID, fecha_rfb_dt, fecha_venta_neta_dt, canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds, agente_alta_id, agente_creador_id, categoria_servicio_ds, cif_nif, segmento_ds, subsegmento_ds, marca_cartera_ds, Antiguedad_Cliente, equipo_ds, territorio_ds, tecnologia_detalle_ds, portabilidad_in_lg, gb, expediente_id, clave, marco_retributivo_ds, flag_marca_cartera, grupo_rappel_ds, orden_sap, importe, decomisionable, plays as PLAYS 
      FROM`mm-commissions-reporting.KRT_CAPTACION.COMISIONES`;
    ELSE    
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.OUT_COMISIONES` AS
      SELECT  marca_ds, Cliente_id, servicio_id, detalle_servicio_ds, CONCEPTO_DS, FECHA_RFB_ID, FECHA_VENTA_NETA_ID, 
      -- PARCHE 20240213 POR VOLCADO DE FECHAS CON TIMEZONE
      case when coalesce(fecha_rfb_id,0) >0 then PARSE_TIMESTAMP("%Y%m%d",CAST(fecha_rfb_id AS STRING)) ELSE CAST(NULL as TIMESTAMP) END as fecha_rfb_dt,
      case when coalesce(fecha_venta_neta_id) >0 then PARSE_TIMESTAMP("%Y%m%d",CAST(fecha_venta_neta_id AS STRING)) ELSE CAST(NULL as TIMESTAMP) END as fecha_venta_neta_dt,     
      --fecha_rfb_dt, fecha_venta_neta_dt, 
      -- FIN PARCHE 20240213      
      canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds, agente_alta_id, agente_creador_id, categoria_servicio_ds, cif_nif, segmento_ds, subsegmento_ds, marca_cartera_ds, Antiguedad_Cliente, equipo_ds, territorio_ds, tecnologia_detalle_ds, portabilidad_in_lg, gb, expediente_id, clave, marco_retributivo_ds, flag_marca_cartera, grupo_rappel_ds, orden_sap, importe, decomisionable, nplays_p as PLAYS
      FROM`mm-commissions-reporting.KRT_CAPTACION.COMISIONES`;
    END IF;

    */
    -- Hoja COMISIONES_DETALLE (version >=6)
    if version_fl>=6 then
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.OUT_COMISIONES_DETALLE` AS
      -- PARCHE 20240213 POR VOLCADO DE FECHAS CON TIMEZONE
      --SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`;
      -- FIN PARCHE 20240213

      SELECT marca_ds, Cliente_id, servicio_id, detalle_servicio_ds, CONCEPTO_DS, FECHA_RFB_ID, FECHA_VENTA_NETA_ID, 
      -- PARCHE 20240213 POR VOLCADO DE FECHAS CON TIMEZONE
      case when coalesce(fecha_rfb_id,0) >0 then PARSE_TIMESTAMP("%Y%m%d",CAST(fecha_rfb_id AS STRING)) END as fecha_rfb_dt,
      case when coalesce(fecha_venta_neta_id) >0 then PARSE_TIMESTAMP("%Y%m%d",CAST(fecha_venta_neta_id AS STRING)) END as fecha_venta_neta_dt,     
      --fecha_rfb_dt, fecha_venta_neta_dt, 
      -- FIN PARCHE 20240213      
      canal_alta_ds, subcanal_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds, agente_alta_id, agente_creador_id, categoria_servicio_ds, cif_nif,
      segmento_ds, subsegmento_ds, marca_cartera_ds, Antiguedad_Cliente, equipo_ds, territorio_ds, tecnologia_detalle_ds, portabilidad_in_lg, gb,
      expediente_id, expediente_padre_id, contrato_id, tipo_pedido_ds, pedido_id, tipo_producto_pedido_re_ds, visibilidad_pedido_lg, catalogo_id, grid, 
      desc_mm, clase_mm, pedido, nplays, nplays_rfb, cat_plays, cat_plays_rfb, nplays_p, nplays_rfb_p, cat_plays_p, cat_plays_rfb_p, clave, 
      marco_retributivo_ds, flag_marca_cartera, grupo_rappel_ds, orden_sap, importe, decomisionable, mes_comision_id
      FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`;

    end If;

    -- Hoja REVISAR
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR` AS

    SELECT base.*, mm.nombre_distribuidor_ds,mm.tipo_canal_ds,mm.canal_ds
    FROM (
      SELECT
        *
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
      WHERE
        subcanal_ds = 'DESCONOCIDO'
        OR marco_retributivo_ds IS NULL) base
    LEFT JOIN
      --`dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_MM_CANALES` mm
      `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_CANALES` mm
    ON
      base.marca_ds = mm.marca_ds
      AND base.nombre_distribuidor_alta_ds = mm.nombre_distribuidor_ds
      AND base.canal_alta_ds = mm.canal_ds
      AND base.subcanal_ds = mm.subcanal_ds
    WHERE
      mm.marco_retributivo_ds IS NULL;


    -- Hoja DECOMISIONES
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_DECOMISIONES` AS
    SELECT
      * 
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`;

      -- #####PARCHE
      -- ##### Invertir signo de decomisiones

      ---UPDATE `mm-commissions-reporting.KRT_CAPTACION.OUT_DECOMISIONES`
      ---SET importe = SAFE_NEGATE(importe)
      ---where importe!=0;

      -- #####FIN PARCHE

      -- #####PARCHE
      -- ##### Borrar las decomisiones defechas posteriores a inicio de mes, analizar si trasladar a tabla CLAWBACK

      DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.OUT_DECOMISIONES`
      WHERE FECHA_RFB_ID >= DESDE;
      
      -- #####FIN PARCHE



    -- Hoja REVISAR_PARAM_VALOR

    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR_PARAM_VALOR` AS
      with noc as (
        select * 
        from `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR` cp
        where not exists (
          select 1 
          from `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` cr
          where cp.marca_ds=cr.marca_ds
          and cp.canal_alta_ds=cr.canal
          and cp.subcanal_ds=cr.subcanal
        ) and marca_ds !='R'
      ) select noc.* 
      from noc
      where not exists (
        select 1
        from  `mm-commissions-reporting.KRT_CARTERA.OUT_DETALLE` l
        where l.marca_ds=noc.marca_ds
        and (l.IdProducto=noc.servicio_id or l.IdProductoOrigen=noc.servicio_id)
        and l.IdFijo=noc.cliente_id
      )
      order by marca_ds, cliente_id;



--    CREATE OR REPLACE TABLE
--      `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR_PARAM_VALOR` AS
--    SELECT
--      DISTINCT marca_ds,
--      ba,
--      post,
--      tv,
--      fija
--    FROM
--      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
--    WHERE
--      plays IS NULL
--      OR pack = ''
--      OR valor = '';


    -- Hoja RAPPEL_OBJETIVOS_ALCANZADOS
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_RAPPEL_OBJETIVOS_ALCANZADOS` AS
    SELECT *
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL`;


    -- Hoja RAPPEL_VOLUMEN_ALCANZADO
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_RAPPEL_VOLUMEN_ALCANZADO` AS
    SELECT *
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL`;



    -- Hoja OUT_CARGA_EKTNET

    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_COM_TOTAL` AS

    With a as (
      with mig  as (
        select distinct c.servicio_id as servicio_id_comision, 
        --case when (coalesce(c.grid,0)>=0 and c.grid<20) then  p.swInstProdId else p.swProdOrigId END servicio_id_info_canal_comision,
        case when (coalesce(c.grid,0)>=0) then  p.swInstProdId else p.swProdOrigId END servicio_id_info_canal_comision,
        c.grid
        from  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
        left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on c.servicio_id = p.swInstProdId      
        --left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` por on por.swInstProdId = p.swProdOrigId
        where c.marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')
        --and c.servicio_id=135731551
        --and c.servicio_id=135270664
        --and grid not in(20,21)
        and not contains_substr(concepto_ds,'rappel')and not contains_substr(concepto_ds,'extra')and not contains_substr(concepto_ds,'postventa')
      )
      --- 
      select c.* , mig.servicio_id_info_canal_comision
      --select distinct c.grid
      from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
      left join mig on c.servicio_id = mig.servicio_id_comision
      where c.marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')
    )   

    select marca_ds MARCA, cliente_id IDCLIENTE, servicio_id IDPRODUCTO, categoria_servicio_ds NEGOCIO, case when segmento_ds = 'RESIDENCIAL' then concat(c.swName , ' '  , c.swSegundoApellido, ' ', c.swApellido ) else c.swName end CLIENTE,
    segmento_ds SEGMENTO, cif_nif  NIF , detalle_servicio_ds CONCEPTOINF, case when concepto_ds like 'Rappel%' then 'Alta Rappel' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then concepto_ds else concat('Alta Producto ', marca_ds) end DESCRIPCIONINF,
    p.swAni IDENTIFICATIVO, fecha_venta_neta_dt FECHAORIGEN, 0 PLAZODED1, 0 PLAZODED2, 0 PLAZODED3, 0 PORDEDUD1, 0 PORDEDUD2, 0 PORDEDUD3, sum(importe) IMPORTEREALTOTAL, sum(importe) IMPORTEREALUNITARIO, p.swProdReleaseId PRODRELEASE,
    --coalesce(por.swChnlPartnerId, 0) IDCANAL, 
    case when por.swChnlPartnerId is null then p.swChnlPartnerId else por.swChnlPartnerId End  IDCANAL, 
    por.swMarcaCartera  MARCACAPTCART, null IDPRODUCTOORIGEN, case when concepto_ds like 'Rappel%' then 'R' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then 'E' else 'A' end TIPOCOMISION,
    a.canal_alta_ds, a.subcanal_ds, a.nombre_distribuidor_alta_ds, a.servicio_id, a.servicio_id_info_canal_comision
        from  a
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on a.servicio_id = p.swInstProdId
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` por on a.servicio_id_info_canal_comision = por.swInstProdId    
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c on a.cliente_id = c.swCustomerId
    where marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')
    --and coalesce(por.swChnlPartnerId, 0)=0
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,24,25,26,27,28,29;


    CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_COM` AS
    SELECT * except (canal_alta_ds,subcanal_ds, nombre_distribuidor_alta_ds, servicio_id, servicio_id_info_canal_comision) 
    FROM `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_COM_TOTAL` where coalesce(Idcanal, 0)>0;

    CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAPTACION.REVISAR_CARGA_EKTNET_COM` AS
    SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_COM_TOTAL` where coalesce(Idcanal, 0)=0;


    CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_DECOM` AS
    select marca_ds MARCA,
    cliente_id IDCLIENTE,
    servicio_id IDPRODUCTO,
    categoria_servicio_ds NEGOCIO,
    concat(c.swName , ' '  , c.swSegundoApellido, ' ', c.swApellido )  CLIENTE,
    segmento_ds SEGMENTO,
    cif_nif  NIF ,
    detalle_servicio_ds CONCEPTOINF,
    case when concepto_ds like 'Rappel%' then 'Baja Rappel' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then concepto_ds else concat('Baja Producto ', marca_ds) end DESCRIPCIONINF,
    swAni IDENTIFICATIVO,
    fecha_venta_neta_dt FECHAORIGEN,
    0 PLAZODED1,
    0 PLAZODED2,
    0 PLAZODED3,
    0 PORDEDUD1,
    0 PORDEDUD2,
    0 PORDEDUD3,
    sum(importe) IMPORTEREALTOTAL,
    sum(importe) IMPORTEREALUNITARIO,
    swProdReleaseId PRODRELEASE,
    ifnull(p.swChnlPartnerId, 0) IDCANAL,
    p.swMarcaCartera  MARCACAPTCART,
    null IDPRODUCTOORIGEN,
    case when concepto_ds like 'Rappel%' then 'DR' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then 'DE' else 'DA' end TIPOCOMISION
    from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` a
    left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on a.servicio_id = p.swInstProdId
    left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c on a.cliente_id = c.swCustomerId
    where marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,24;



    CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET` AS
    SELECT * 
    FROM 
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_COM`
    UNION ALL 
    SELECT * 
    FROM 
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_DECOM`;



    -- Hoja OUT_PORTABILIDAD_INTRAGRUPO

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.OUT_PORTABILIDAD_INTRAGRUPOxCONTRATO` AS
    SELECT distinct p.* except(--cat_plays,cat_plays_rfb_p,
fecha_ventana_cambio_min,fecha_ventana_cambio_max,fecha_ventana_cambio_min_pint, fecha_ventana_cambio_min_fija_pint,fecha_ventana_cambio_max_fija_pint,fecha_ventana_cambio_min_pext, fecha_ventana_cambio_max_mov_pint, fecha_ventana_cambio_min_mov_pint),EXTRACT(DATE FROM c.fecha_rfb_dt) as fecha_rfb_dt
    FROM  `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPOxCONTRATO_DATAMARK_KD` p
    --FROM  `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` p
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c     
    --on c.marca_ds=p.marca_ds and c.cliente_id=p.cliente_id and p.pedido=c.pedido and p.servicio_id=c.servicio_id
    on c.marca_ds=p.marca_ds and c.cliente_id=p.cliente_id and p.contrato_id=coalesce(CAST(c.contrato_id AS STRING),c.expediente_padre_id) and p.servicio_id=c.servicio_id    
    where contains_substr(c.clase_mm, "P -" ) and contains_substr(c.desc_mm, "Portabilidad")
    --SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.PORTABILIDADES_INTRAGRUPO`
    order by marca_ds, cliente_id, contrato_id, categoria_servicio_ds, detalle_servicio_ds, servicio_id;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.OUT_PORTABILIDAD_INTRAGRUPOxPEDIDO` AS
    SELECT distinct p.* except(cat_plays,cat_plays_rfb_p,
fecha_ventana_cambio_min,fecha_ventana_cambio_max,fecha_ventana_cambio_min_pint, fecha_ventana_cambio_min_fija_pint,fecha_ventana_cambio_max_fija_pint,fecha_ventana_cambio_min_pext, fecha_ventana_cambio_max_mov_pint, fecha_ventana_cambio_min_mov_pint),EXTRACT(DATE FROM c.fecha_rfb_dt) as fecha_rfb_dt
    FROM  `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPOxPEDIDO_DATAMARK_KD` p
    --FROM  `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` p
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c     
    on c.marca_ds=p.marca_ds and c.cliente_id=p.cliente_id and p.pedido=c.pedido and p.servicio_id=c.servicio_id
    --on c.marca_ds=p.marca_ds and c.cliente_id=p.cliente_id and p.contrato_id=coalesce(CAST(c.contrato_id AS STRING),c.expediente_padre_id) and p.servicio_id=c.servicio_id    
    where contains_substr(c.clase_mm, "P -" ) and contains_substr(c.desc_mm, "Portabilidad")
    --SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.PORTABILIDADES_INTRAGRUPO`
    order by marca_ds, cliente_id, pedido, categoria_servicio_ds, detalle_servicio_ds, servicio_id;


  END