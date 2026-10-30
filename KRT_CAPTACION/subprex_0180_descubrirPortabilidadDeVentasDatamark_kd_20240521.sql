BEGIN
  
--    DECLARE VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO INT64;
--    DECLARE DESDE, HASTA INT64; SET DESDE=20240401; SET HASTA=20240430;
--    SET VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO=20;

  
  --- PASO 1: IDENTIFICO EL ORIGEN DE LOS SERVICIOS VENDIDOS PROCEDENTES DE OTROS PROVEEDORES

    --- OUT 1: LOG_0180_MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD` AS
    select ROW_NUMBER() over(partition by phone_nm order by confirmation_date desc ) as ind, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM confirmation_date)) as integer) as fecha_confirmacion_portabilidad_id, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM transfer_date)) as integer) as fecha_ventana_cambio_id, 
    request_type as sentido_portabilidad_ds, 
    --CAST(operator_code_donor as INT64) as OPERADOR_DONANTE_ID,
    operator_code_donor as OPERADOR_DONANTE_ID,
    operator_donor as OPERADOR_DONANTE_DS, 
    state_reason as estado_portabilidad_fijo_ds, 
    --CAST(operator_code_receiver as INT64) as operador_receptor_id, 
    operator_code_receiver as operador_receptor_id,     
    operator_receiver as operador_receptor_ds, 
    if(regexp_contains(customer_id_receiver,r'/^[0-9]+$/'), CAST(customer_id_receiver AS INT64), NULL) as cliente_receptor_id, 
    if(regexp_contains(service_id_receiver,r'/^[0-9]+$/'), CAST(service_id_receiver AS INT64), NULL) as servicio_receptor_id,     
    --CAST(service_id_receiver AS INT64) as servicio_receptor_id,
    phone_nm as ani
    from `mm-datamart-kd.PORTABILITY.portability_fix_base`  fd --TABLESAMPLE SYSTEM(0.1 PERCENT)
    where CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM transfer_date)) as integer) between desde and hasta
    --and not exists (
    --   select 1 from `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_FIJA_ENTRANTE` fe where fe.ani=fd.phone_nm 
    --)
    QUALIFY ind=1;


    --- OUT 1: LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` AS
    select ROW_NUMBER() over(partition by msisdn order by confirmation_date desc ) as ind, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM confirmation_date)) as integer) as fecha_confirmacion_portabilidad_id, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM transfer_date)) as integer) as fecha_ventana_cambio_id, 
    request_type as sentido_portabilidad_ds, 
    --CAST(operator_code_donor as INT64) as OPERADOR_DONANTE_ID,
    operator_code_donor as OPERADOR_DONANTE_ID,
    operator_donor as OPERADOR_DONANTE_DS, 
    state_reason as estado_portabilidad_fijo_ds, 
    --CAST(operator_code_receiver as INT64) as operador_receptor_id, 
    operator_code_receiver as operador_receptor_id,     
    operator_receiver as operador_receptor_ds, 
    if(regexp_contains(customer_id_receiver,r'/^[0-9]+$/'), CAST(customer_id_receiver AS INT64), NULL) as cliente_receptor_id, 
    if(regexp_contains(service_id_receiver,r'/^[0-9]+$/'), CAST(service_id_receiver AS INT64), NULL) as servicio_receptor_id,     
    --CAST(service_id_receiver AS INT64) as servicio_receptor_id,
    msisdn as ani
    from `mm-datamart-kd.PORTABILITY.portability_mobile_base`  fd --TABLESAMPLE SYSTEM(0.1 PERCENT)
    where CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM transfer_date)) as integer) between desde and hasta
    --and  regexp_contains(service_id_receiver,r'[0-9]+')
    --and regexp_contains(customer_id_receiver,r'[0-9]+')
    --where confirmation_date between '2024-05-01'and '2024-05-31'
    --and ani=948388545
    --and not exists (
    --     select 1 from `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_MOVIL_ENTRANTE` fe where fe.ani=fd.msisdn
    --)
    QUALIFY ind=1;





  --- PASO 2: IDENTIFICO EL ORIGEN DE LOS SERVICIOS VENDIDOS PROCEDENTES DE OTROS PROVEEDORES

  /*select  distinct c.marca_Ds, c.cliente_id, c.fecha_venta_neta_id, s.ani
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` C
  LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S on s.marca_ds=c.marca_ds and s.cliente_id=c.cliente_id and s.servicio_id=c.servicio_id
  order by 1,2,3*/


    --- OUT 2: LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD` AS
    SELECT distinct C.*,s.ani as ani_serv, f.ani as ani_fijo, m.ani as ani_movil,
    coalesce(f.fecha_ventana_cambio_id, m.fecha_ventana_cambio_id) as fecha_ventana_cambio_id,
    F.OPERADOR_DONANTE_ID OPERADOR_FIJO_ID, F.OPERADOR_DONANTE_DS OPERADOR_DONANTE_FIJO,
    CASE WHEN not starts_with(c.categoria_servicio_ds,"MOVILES") and not starts_with(c.categoria_servicio_ds,"TERMINALES") THEN
      CASE WHEN F.OPERADOR_DONANTE_ID is NULL THEN "ALTA NUEVA" ELSE CASE WHEN pf.OPERADOR_FIJO_ID is not null then "INTRAGRUPO" ELSE "EXTRAGRUPO" END END 
    END as TIPO_PORTABILIDAD_FIJO,
    f.fecha_ventana_cambio_id as fecha_ventana_cambio_id_fijo,      
    
    CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN M.operador_donante_id END OPERADOR_MOVIL_ID, 
    M.operador_donante_ds OPERADOR_DONANTE_MOVIL,
    
    CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN  
      CASE WHEN M.OPERADOR_DONANTE_ID is NULL THEN "ALTA NUEVA" ELSE CASE WHEN pm.OPERADOR_MOVIL_ID is not null then "INTRAGRUPO" ELSE "EXTRAGRUPO"END END 
    END as TIPO_PORTABILIDAD_MOVIL,
    CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN m.fecha_ventana_cambio_id END as fecha_ventana_cambio_id_movil,
    --coalesce(f.ani,m.ani) as ani    
    
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` C
    LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S on s.marca_ds=c.marca_ds and s.cliente_id=c.cliente_id and s.servicio_id=c.servicio_id and s.ani>0
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD` F ON /*F.cliente_receptor_id=c.cliente_id and*/ f.ani=s.ani
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` M ON /*M.cliente_receptor_id =C.cliente_id and*/ m.ani=s.ani
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS` pf on CAST(pf.OPERADOR_FIJO_ID AS INT64)=CAST(f.operador_donante_id AS INT64)
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_MOVILES` pm on CAST(pm.OPERADOR_MOVIL_ID AS INT64)=CAST(m.operador_donante_id AS INT64)
    --where c.cliente_id=2345216
    --where c.cat_plays_p= "BA/MOVIL/TF/TV" and c.cliente_id=7736575
  --  where pf.version<=VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO
  --  and pm.version<=VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO
    order by 1,2,3,4,5; 

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD` TV
    SET TV.OPERADOR_FIJO_ID=TF.OPERADOR_FIJO_ID,
        TV.OPERADOR_DONANTE_FIJO=TF.OPERADOR_DONANTE_FIJO,  
        TV.TIPO_PORTABILIDAD_FIJO=TF.TIPO_PORTABILIDAD_FIJO
    FROM   `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD` TF 
    WHERE TF.marca_ds=TV.marca_ds
    AND TF.cliente_id=tv.cliente_id
    and TF.pedido_id=TV.pedido_id
    and contains_substr(TF.cat_plays_p,"TF")
    and contains_substr(TF.cat_plays_p,"TV")  
    and TF.categoria_servicio_ds="FIJA"
    and TV.categoria_servicio_ds="TELEVISION";


    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD` SET OPERADOR_DONANTE_FIJO="AVATEL" WHERE OPERADOR_FIJO_ID="00887";
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD` SET OPERADOR_FIJO_ID=CAST(NULL AS STRING) WHERE CONTAINS_SUBSTR(OPERADOR_FIJO_ID,"DESCONOCIDO"); 
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD` SET OPERADOR_MOVIL_ID=CAST(NULL AS STRING) WHERE CONTAINS_SUBSTR(OPERADOR_MOVIL_ID,"DESCONOCIDO"); 


  --- PASO 3: CREO TABLA CON VENTAS CAPTACION ENRIQUECIDAS CON EVENTOS DE PORTABILIDAD CONFRMADA EN MES DE COMISION
    --- OUT 3: VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD      


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD` AS
    select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD`;




  --- PASO 4: TIPIFICO LOS PAQUETES DE SERVICIOS  ME QUEDO CON AQUELLOS QUE CUMPLEN LOS REQUERIMIENTOS PARA QUE SUS SERVICIOS SE MARQUEN CON FLAG INTRAGRUPO
    --- OUT 4: PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS
    select marca_ds, cliente_id,
    pedido,
    --case when marca_ds!="R" then CAST(pedido_id AS STRING) else expediente_padre_id END as pedido_id, 
    cat_plays_p, cat_plays, cat_plays_rfb_p,
    array_to_string(array_agg(CASE WHEN OPERADOR_DONANTE_FIJO IS NOT NULL THEN OPERADOR_DONANTE_FIJO END ),",")  as vof,
    array_to_string(array_agg(CASE WHEN ani_fijo IS NOT NULL THEN CAST(ani_fijo AS STRING ) END ),",")  as vanif,
    array_to_string(array_agg(CASE WHEN OPERADOR_DONANTE_MOVIL IS NOT NULL THEN OPERADOR_DONANTE_MOVIL END ),",")  as vom,
    array_to_string(array_agg(CASE WHEN ani_movil IS NOT NULL THEN CAST(ani_movil AS STRING) END ),",")  as vanim,  
    --array_to_string(array_agg(COALESCE(OPERADOR_DONANTE_FIJO,"")),",") as vof,
    --array_to_string(array_agg(COALESCE(OPERADOR_DONANTE_MOVIL,"")),",") as vom,

    count(distinct if(categoria_servicio_ds="BANDA ANCHA", servicio_id, NULL )) as nba,
    count(distinct if(categoria_servicio_ds="BANDA ANCHA" and contains_substr(tipo_portabilidad_fijo,"ALTA NUEVA"), servicio_id, NULL )) as nba_an,
    count(distinct if(categoria_servicio_ds="BANDA ANCHA" and contains_substr(tipo_portabilidad_fijo,"INTRA"), servicio_id, NULL )) as nba_pint,
    count(distinct if(categoria_servicio_ds="BANDA ANCHA" and contains_substr(tipo_portabilidad_fijo,"EXTRA"), servicio_id, NULL )) as nba_pext,  

    count(distinct if(categoria_servicio_ds="FIJA", servicio_id, NULL )) as nfija,
    count(distinct if(categoria_servicio_ds="FIJA" and contains_substr(tipo_portabilidad_fijo,"ALTA NUEVA"), servicio_id, NULL )) as nfija_an,
    count(distinct if(categoria_servicio_ds="FIJA" and contains_substr(tipo_portabilidad_fijo,"INTRA"), servicio_id, NULL )) as nfija_pint,
    count(distinct if(categoria_servicio_ds="FIJA" and contains_substr(tipo_portabilidad_fijo,"EXTRA"), servicio_id, NULL )) as nfija_pext,  


    count(distinct if(categoria_servicio_ds="MOVILES POSTPAGO", servicio_id, NULL ))  as nmov,
    count(distinct if(categoria_servicio_ds="MOVILES POSTPAGO" and contains_substr(tipo_portabilidad_movil,"ALTA NUEVA"), servicio_id, NULL )) as nmov_an,
    count(distinct if(categoria_servicio_ds="MOVILES POSTPAGO" and contains_substr(tipo_portabilidad_movil,"INTRA"), servicio_id, NULL )) as nmov_pint,
    count(distinct if(categoria_servicio_ds="MOVILES POSTPAGO" and contains_substr(tipo_portabilidad_movil,"EXTRA"), servicio_id, NULL )) as nmov_pext,  

    min(fecha_ventana_cambio_id) as fecha_ventana_cambio_min,
    max(fecha_ventana_cambio_id) as fecha_ventana_cambio_max,

    min(if(contains_substr(tipo_portabilidad_movil,"EXTRA"), fecha_ventana_cambio_id, NULL )) as fecha_ventana_cambio_min_pext ,
    min(if(contains_substr(tipo_portabilidad_movil,"INTRA"), fecha_ventana_cambio_id, NULL )) as fecha_ventana_cambio_min_pint ,

    min(if(contains_substr(tipo_portabilidad_movil,"INTRA") and categoria_servicio_ds="MOVILES POSTPAGO", fecha_ventana_cambio_id, NULL )) as fecha_ventana_cambio_min_mov_pint ,
    max(if(contains_substr(tipo_portabilidad_movil,"INTRA") and categoria_servicio_ds="MOVILES POSTPAGO", fecha_ventana_cambio_id, NULL )) as fecha_ventana_cambio_max_mov_pint ,

    min(if(contains_substr(tipo_portabilidad_movil,"INTRA") and categoria_servicio_ds="FIJA", fecha_ventana_cambio_id, NULL )) as fecha_ventana_cambio_min_fija_pint ,
    max(if(contains_substr(tipo_portabilidad_movil,"INTRA") and categoria_servicio_ds="FIJA", fecha_ventana_cambio_id, NULL )) as fecha_ventana_cambio_max_fija_pint ,


    case when count(distinct if(categoria_servicio_ds="FIJA" and contains_substr(tipo_portabilidad_fijo,"INTRA"), servicio_id, NULL )) > 0
          or  count(distinct if(categoria_servicio_ds="BANDA ANCHA" and contains_substr(tipo_portabilidad_fijo,"INTRA"), servicio_id, NULL )) > 0
         then 1
         ELSE 
          case when count(distinct if(categoria_servicio_ds="MOVILES POSTPAGO" and contains_substr(tipo_portabilidad_movil,"INTRA"), servicio_id, NULL )) > 
                    count(distinct if(categoria_servicio_ds="MOVILES POSTPAGO" and contains_substr(tipo_portabilidad_movil,"EXTRA"), servicio_id, NULL )) 
               then 1
               else 0
          END
    END as flag_intragrupo
    from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD`
    --where cliente_id=2345216
    group by 1,2,3,4,5,6
    having flag_intragrupo>0
    order by 1,2,3;
  

END