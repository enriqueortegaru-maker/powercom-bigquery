BEGIN


  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`  as 
  --SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0110_VENTAS_CAPTACION`;

  --DECLARE desde,hasta int64;
  --SET desde=20230101;
  --SET hasta=20230120;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` AS
  with pob as (
    select distinct marca_ds, cliente_id,
    CASE  WHEN categoria_servicio_ds="BANDA ANCHA" or (categoria_servicio_ds="DESCONOCIDO"and desc_mm="A - Servicio acceso BA")  THEN "BA" 
          WHEN categoria_servicio_ds="FIJA" THEN "TF" 
          WHEN categoria_servicio_ds="TELEVISION" THEN "TV" 
          WHEN categoria_servicio_ds="MOVILES POSTPAGO" THEN "MOVIL" 
    END as cat,
    categoria_servicio_ds,clase_mm, desc_mm, FECHA_RFB_ID 
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
    where (clase_mm='A - Servicio base' or (clase_mm='B - SVA' and desc_mm='B - Television acceso')) 
    --and marca_ds="R"
    order by 1,2,3 
  )
  SELECT marca_ds, cliente_id,
  coalesce(count(distinct cat),0) as NPLAYS, 
  coalesce(count(distinct if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,cat, NULL)),0 ) as NPLAYS_RFB, 
  ARRAY_TO_STRING(ARRAY_AGG(distinct cat order by cat),"/" ) as CAT_PLAYS,  
  --ARRAY_AGG(DISTINCT if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,cat, NULL) IGNORE NULLS) as pr,
  ARRAY_TO_STRING(ARRAY_AGG(DISTINCT if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,cat, NULL) IGNORE NULLS),"/" ) as CAT_PLAYS_RFB
  from pob
  group by 1,2;

  -- PENDIENTE RESOLVER ORDEN DE SERVICIOS EN CAT_PLAYS_RFB

  --having coalesce(count(distinct cat),0) !=coalesce(count(distinct if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,categoria_servicio_ds, NULL)),0 ) 
  --AND coalesce(count(distinct if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,categoria_servicio_ds, NULL)),0 )>0


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` AS
  with pob as (
    select distinct marca_ds, cliente_id,pedido,
    CASE  WHEN categoria_servicio_ds="BANDA ANCHA" or (categoria_servicio_ds="DESCONOCIDO"and desc_mm="A - Servicio acceso BA")  THEN "BA" 
          WHEN categoria_servicio_ds="FIJA" THEN "TF" 
          WHEN categoria_servicio_ds="TELEVISION" THEN "TV" 
          WHEN categoria_servicio_ds="MOVILES POSTPAGO" THEN "MOVIL" 
    END as cat,
    categoria_servicio_ds,clase_mm, desc_mm, FECHA_RFB_ID 
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` 
    where (clase_mm='A - Servicio base' or (clase_mm='B - SVA' and desc_mm='B - Television acceso')) 
    --and marca_ds="EUSKALTEL"
    order by 1,2,3,4 
  )
  SELECT marca_ds, cliente_id,pedido,
  coalesce(count(distinct cat),0) as NPLAYS, 
  coalesce(count(distinct if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,cat, NULL)),0 ) as NPLAYS_RFB, 
  ARRAY_TO_STRING(ARRAY_AGG(distinct cat order by cat),"/" ) as CAT_PLAYS,  
  --ARRAY_AGG(DISTINCT if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,cat, NULL) IGNORE NULLS) as pr,
  ARRAY_TO_STRING(ARRAY_AGG(DISTINCT if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,cat, NULL) IGNORE NULLS),"/" ) as CAT_PLAYS_RFB
  from pob
  group by 1,2,3;
  --having coalesce(count(distinct cat),0) !=coalesce(count(distinct if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,categoria_servicio_ds, NULL)),0 ) 
  --AND coalesce(count(distinct if( FECHA_RFB_ID>=desde and FECHA_RFB_ID<=hasta,categoria_servicio_ds, NULL)),0 )>0

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`  as 
  select v.*, 
  cxp.nplays, cxp.nplays_rfb, 
  cxp.cat_plays, cxp.cat_plays_rfb, 
  cpxp.nplays as nplays_p, cpxp.NPLAYS_RFB as nplays_rfb_p, 
  cpxp.cat_plays as cat_plays_p , cpxp.cat_plays_rfb as cat_plays_rfb_p
  from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  left join `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` cxp
  on cxp.marca_ds=v.marca_ds and cxp.cliente_id=v.Cliente_id and v.grid<5
  left join `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` cpxp
  on cpxp.marca_ds=v.marca_ds and cpxp.cliente_id=v.Cliente_id and cpxp.pedido=v.pedido; 


END