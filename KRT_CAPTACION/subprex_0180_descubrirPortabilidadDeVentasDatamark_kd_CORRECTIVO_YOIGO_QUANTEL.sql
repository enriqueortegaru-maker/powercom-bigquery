BEGIN

  
    --DECLARE VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO, DDESDE_1M, DESDE, HASTA INT64; SET VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO=20; SET DESDE_1M=20250701; SET DESDE=20250801; SET HASTA=20250831;

  ----------------------------------------------------------------------------------------------------
  ---
  --- PASO 1: DESCUBRO MENSAJES 
  ---
  
    --- PASO 1.1: REGISTRO LOS MENSAJES DE PORTABILIDAD DE LOS SERVICIOS VENDIDOS PROCEDENTES DE OTROS PROVEEDORES

    --- OUT 1.1: LOG_0180_MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_TODOS_MENSAJES_xPORTABILIDAD_FIJA_DATAMARK_KD` AS
    select phone_nm as ani,
    ROW_NUMBER() over(partition by phone_nm order by confirmation_date desc ) as ind, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM confirmation_date)) as integer) as fecha_confirmacion_portabilidad_id, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM date_vc)) as integer) as fecha_ventana_cambio_id, 
    request_type as sentido_portabilidad_ds, 
    --CAST(operator_code_donor as INT64) as OPERADOR_DONANTE_ID,
    comm_brand_ds_donor   as MARCA_OPERADOR_DONANTE_DS,
    operator_code_donor as OPERADOR_DONANTE_ID,
    operator_donor as OPERADOR_DONANTE_DS, 
    state_reason as estado_portabilidad_fijo_ds, 
    --CAST(operator_code_receiver as INT64) as operador_receptor_id, 
    operator_code_receiver as operador_receptor_id,     
    operator_receiver as operador_receptor_ds, 
    comm_brand_ds_receiver as MARCA_OPERADOR_RECEPTOR_DS,    
    if(regexp_contains(customer_id_receiver,r'/^[0-9]+$/'), CAST(customer_id_receiver AS INT64), NULL) as cliente_receptor_id, 
    if(regexp_contains(service_id_receiver,r'/^[0-9]+$/'), CAST(service_id_receiver AS INT64), NULL) as servicio_receptor_id,     
    --CAST(service_id_receiver AS INT64) as servicio_receptor_id,
    datasource_donor AS  crm_donante,
    datasource_receiver AS  crm_receptor,    
    from `mm-datamart-kd.PORTABILITY.portability_fix_base`  fd --TABLESAMPLE SYSTEM(0.1 PERCENT)
    --where CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM date_vc)) as integer) between desde and hasta
    where CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM confirmation_date)) as integer) between desde_1m and hasta    
    --and not exists (
    --   select 1 from `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_FIJA_ENTRANTE` fe where fe.ani=fd.phone_nm 
    --)
    QUALIFY ind=1;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD` AS 
    SELECT * 
    FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_TODOS_MENSAJES_xPORTABILIDAD_FIJA_DATAMARK_KD`
    WHERE operador_receptor_id in ("00020","00015","00008");


    --- OUT 1.2: LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_TODOS_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` AS
    select msisdn as ani,
    ROW_NUMBER() over(partition by msisdn order by confirmation_date desc ) as ind, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM confirmation_date)) as integer) as fecha_confirmacion_portabilidad_id, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM vc_date)) as integer) as fecha_ventana_cambio_id, 
    request_type as sentido_portabilidad_ds, 
    --CAST(operator_code_donor as INT64) as OPERADOR_DONANTE_ID,
    comm_brand_ds_donor   as MARCA_OPERADOR_DONANTE_DS,    
    operator_code_donor as OPERADOR_DONANTE_ID,
    operator_donor as OPERADOR_DONANTE_DS, 
    state_reason as estado_portabilidad_fijo_ds, 
    --CAST(operator_code_receiver as INT64) as operador_receptor_id, 
    operator_code_receiver as operador_receptor_id,     
    operator_receiver as operador_receptor_ds, 
    comm_brand_ds_receiver as MARCA_OPERADOR_RECEPTOR_DS,    
    if(regexp_contains(customer_id_receiver,r'/^[0-9]+$/'), CAST(customer_id_receiver AS INT64), NULL) as cliente_receptor_id, 
    if(regexp_contains(service_id_receiver,r'/^[0-9]+$/'), CAST(service_id_receiver AS INT64), NULL) as servicio_receptor_id,     
    --CAST(service_id_receiver AS INT64) as servicio_receptor_id,
    datasource_donor AS  crm_donante,
    datasource_receiver AS  crm_receptor,    
    from `mm-datamart-kd.PORTABILITY.portability_mobile_base`  fd --TABLESAMPLE SYSTEM(0.1 PERCENT)
    --where CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM vc_date)) as integer) between desde and hasta
    where CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM confirmation_date)) as integer) between desde_1m and hasta    
    --and  regexp_contains(service_id_receiver,r'[0-9]+')
    --and regexp_contains(customer_id_receiver,r'[0-9]+')
    --where confirmation_date between '2024-05-01'and '2024-05-31'
    --and ani=948388545
    --and not exists (
    --     select 1 from `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_PORTABILIDAD_MOVIL_ENTRANTE` fe where fe.ani=fd.msisdn
    --)
    QUALIFY ind=1;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` AS
    SELECT * 
    FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_TODOS_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD`
    WHERE operador_receptor_id in("006","073","053");


  ----------------------------------------------------------------------------------------------------------------------------------------
  ---
  --- PASO 2: PROCESO MENSAJES DE PORTABILIDAD PARA DESCUBRIR ERRORES EN CRM DE MM A TRAVES DE HISTORIO DE MENSAJES DE PORTABILIDAD
  ---


    --- PASO 2.1: FILTRO LOS MENSAJES DE PORTABILIDAD QUE REGISTRAN 
    -----       COMM_BRAND_DS_DONOR YOIG0
    -----       DATASOURCE_DONOR QUANTEL 
    -----       OPERADOR_RECEPTOR_DS "EUSKALTEL" o "R" o "TELECABLE"

    --- OUT 2.1: LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD` AS
    SELECT m.* 
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` m
    inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_MOVILES` og on og.OPERADOR_MOVIL_ID=CAST(m.OPERADOR_DONANTE_ID AS INT64) 
    inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_MOVILES` de on de.OPERADOR_MOVIL_ID=CAST(m.OPERADOR_RECEPTOR_ID AS INT64) 
    WHERE contains_Substr(MARCA_OPERADOR_DONANTE_DS,"YOIGO") AND contains_substr(crm_donante,"QVANTEL") 
    AND (contains_substr(OPERADOR_RECEPTOR_DS,"EUSKALTEL") OR contains_substr(OPERADOR_RECEPTOR_DS,"TELECABLE")  OR contains_substr(OPERADOR_RECEPTOR_DS,"R CABLE"));
        

    --- PASO 2.2: RECUPERO EL HISTORICO DE MENSAJES DE PORTABILIDAD DE LOS MSISDNS REGISTRADOS EN TABLA LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD
    --- OUT 2.2: LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_HISTORICO_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD` AS
    select msisdn as ani, ROW_NUMBER() over(partition by msisdn order by confirmation_date desc) as ind, 
    confirmation_date,
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM confirmation_date)) as integer) as fecha_confirmacion_portabilidad_id, 
    CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM vc_date)) as integer) as fecha_ventana_cambio_id, 
    request_type as sentido_portabilidad_ds, 
    --CAST(operator_code_donor as INT64) as OPERADOR_DONANTE_ID,
    comm_brand_ds_donor   as MARCA_OPERADOR_DONANTE_DS,    
    operator_code_donor as OPERADOR_DONANTE_ID,
    operator_donor as OPERADOR_DONANTE_DS, 
    state_reason as estado_portabilidad_fijo_ds, 
    --CAST(operator_code_receiver as INT64) as operador_receptor_id, 
    operator_code_receiver as operador_receptor_id,     
    operator_receiver as operador_receptor_ds, 
    comm_brand_ds_receiver as MARCA_OPERADOR_RECEPTOR_DS,    
    if(regexp_contains(customer_id_receiver,r'/^[0-9]+$/'), CAST(customer_id_receiver AS INT64), NULL) as cliente_receptor_id, 
    if(regexp_contains(service_id_receiver,r'/^[0-9]+$/'), CAST(service_id_receiver AS INT64), NULL) as servicio_receptor_id,     
    --CAST(service_id_receiver AS INT64) as servicio_receptor_id,
    datasource_donor AS  crm_donante,
    datasource_receiver AS  crm_receptor,    
    from `mm-datamart-kd.PORTABILITY.portability_mobile_base`  fd --TABLESAMPLE SYSTEM(0.1 PERCENT)
    --where CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM vc_date)) as integer) between desde and hasta
    where exists (
        select 1 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD` p
        where p.ani= fd.msisdn
    )
    and CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM fd.confirmation_date)) as integer) <= hasta  
    order by 1,2; 


        
    --- PASO 2.3: RECUPERO EL HISTORICO DE MENSAJES DE PORTABILIDAD DE LOS MSISDNS REGISTRADOS EN TABLA LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD PREVIOS A VENTANA DE COMISIIONADO
    --- OUT 2.3: LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_PREVIO_VENTANA_COMSIONADO_DATAMARK_KD    


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_PREVIO_VENTANA_COMSIONADO_DATAMARK_KD` AS
    with p as (
        select * 
        from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_HISTORICO_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD`
        where fecha_confirmacion_portabilidad_id <= desde_1m
    )
    SELECT ani, ROW_NUMBER() over(partition by ani order by fecha_confirmacion_portabilidad_id desc) as ind, *  except( ani, ind)
    from p 
    order by 1,2 asc;


    --- PASO 2.4: RECUPERO EL MENSAJE PREVIO AL ULTIMO DEL HISTORICO 
    --- OUT 2.4: LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJES_DST_KRT_OR_YOIGO_CRM_PREVIO_XENA_DATAMARK_KD` AS
    select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_PREVIO_VENTANA_COMSIONADO_DATAMARK_KD` where ind=1 and CRM_RECEPTOR="XENA";
    --select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_HISTORICO_MENSAJESxPORTABILIDAD_MOVIL_OR_QVANTEL_DST_KRT_DATAMARK_KD` where ind=2 and CRM_RECEPTOR="XENA";


    --- PASO 2.5: ACTUALIZO EL OPERADOR_DONANTE_DS EN TABLA DE MENSAJES
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` m
    SET m.MARCA_OPERADOR_DONANTE_DS=x.MARCA_OPERADOR_RECEPTOR_DS
    FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJES_DST_KRT_OR_YOIGO_CRM_PREVIO_XENA_DATAMARK_KD` x
    where m.ani=x.ani;

 
    --- PASO 2.6: CREO TABLAS CON MENSAJES
  	CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAPTACION.MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD`;
  	CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAPTACION.MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD`;


  -------------------------------------------------------------------------------------------------------------------------------
  ---
  --- PASO 3: PROCESO NUMERACIONES REGISTRADAS EN XENA PARA DESCUBRIR ERRORES EN CRM DE MM A TRAVES DE NUMERACIONES PROPIAS
  ---

    --- PASO 3.1: DESCUBRO VENTAS ACTUALIZO EL OPERADOR_DONANTE_DS EN TABLA DE MENSAJES


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_VENTAS_CAPTACION_MOVIL_CON_ANI` AS
    SELECT  v.*, s.ani as ani 
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
    INNER JOIN  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S on s.marca_ds=v.marca_ds and s.cliente_id=v.cliente_id and s.servicio_id=v.servicio_id and s.ani>0;

    --- PASO 3.2: FILTRO VENTAS CON NUMERACION PROPIA DE XFERA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_VENTAS_CAPTACION_MOVIL_CON_NUMERACION_PROPIA_XFERA` AS
    SELECT distinct v.*
    FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_VENTAS_CAPTACION_MOVIL_CON_ANI` v
    INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_CNMC_NUMERACION_MOVIL_XFERA` n  on LEFT(CAST(v.ani as string),4)= CONCAT(CAST(n.rango as STRING),CAST(n.sr1 as STRING));

    --- PASO 3.3: DESCUBRO MARCA ASOCIADA A VENTAS DE GEKT CUYO ANI SE REGSITRA EN XENA, Y SE HA DADO DE BAJA EN ESTE CRM DURANTE EL MES DE COMISIONADO 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_VENTAS_CAPTACION_MOVIL_GEKT_Y_BAJA_NUM_PROPIA_XFERA_EN_XENA` AS
    SELECT distinct x.brand_id,SPLIT(brand_id,'_')[Offset(0)] as brand_ds, v.*
    from `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_VENTAS_CAPTACION_MOVIL_CON_NUMERACION_PROPIA_XFERA` v 
    inner join  `mm-datamart-kd.SERVICES.service_bundle_tramos_xena` x on x.phone_nm=v.ani 
    where CAST(FORMAT_DATE("%Y%m%d", x.end_date) as integer) between desde_1m and hasta;



    --- PASO 3.4: ACTUALIZO EL OPERADOR_DONANTE_DS EN TABLA DE MENSAJES
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` m
    SET m.MARCA_OPERADOR_DONANTE_DS=x.brand_ds
    FROM (select distinct   brand_ds, ani from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_VENTAS_CAPTACION_MOVIL_GEKT_Y_BAJA_NUM_PROPIA_XFERA_EN_XENA` ) x
    where m.ani=x.ani;


    --SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_VENTAS_CAPTACION_MOVIL_GEKT_Y_BAJA_NUM_PROPIA_XFERA_EN_XENA` pr
    --where not exists (select 1 from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJES_DST_KRT_OR_YOIGO_CRM_PREVIO_XENA_DATAMARK_KD` po  where  po.ani=x.ani)


    ---
    --- FIN PASO 3
    ---
    ----------------------------------------------------------------------------------------------------------------------------------------


  --- PASO 4: IDENTIFICO EL ORIGEN DE LOS SERVICIOS VENDIDOS PROCEDENTES DE OTROS PROVEEDORES

  /*select  distinct c.marca_Ds, c.cliente_id, c.fecha_venta_neta_id, s.ani
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` C
  LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S on s.marca_ds=c.marca_ds and s.cliente_id=c.cliente_id and s.servicio_id=c.servicio_id
  order by 1,2,3*/


    --- OUT 4: LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` AS
    SELECT distinct C.*,s.ani as ani_serv, f.ani as ani_fijo, m.ani as ani_movil,
    coalesce(f.fecha_ventana_cambio_id, m.fecha_ventana_cambio_id) as fecha_ventana_cambio_id,
    F.MARCA_OPERADOR_DONANTE_DS MARCA_OPERADOR_DONANTE_FIJO,    
    F.OPERADOR_DONANTE_ID OPERADOR_FIJO_ID, F.OPERADOR_DONANTE_DS OPERADOR_DONANTE_FIJO,

    CASE WHEN not starts_with(c.categoria_servicio_ds,"MOVILES") and not starts_with(c.categoria_servicio_ds,"TERMINALES") THEN
    --CASE WHEN not starts_with(c.categoria_servicio_ds,"FIJA")  THEN
      CASE WHEN F.OPERADOR_DONANTE_ID is NULL THEN "ALTA NUEVA" 
      ELSE 
        CASE WHEN pf.OPERADOR_FIJO_ID is not null then            
                CASE    WHEN TRIM(UPPER(coalesce(F.MARCA_OPERADOR_DONANTE_DS,"NOINF"))) NOT IN ("MARBLANCA")  then "INTRAGRUPO" 
                        ELSE "EXTRAGRUPO"
                        --WHEN TRIM(UPPER(M.MARCA_OPERADOR_DONANTE_DS)) ="LLAMAYA" AND M.TIPO_FACTURACION_DONANTE="PREPAID" then "PREPAGO"
                END       
            ELSE "EXTRAGRUPO" 
        END 
      END 
    END as TIPO_PORTABILIDAD_FIJO,

    f.fecha_ventana_cambio_id as fecha_ventana_cambio_id_fijo,      
     
    CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN M.operador_donante_id END OPERADOR_MOVIL_ID, 
    M.MARCA_OPERADOR_DONANTE_DS MARCA_OPERADOR_DONANTE_MOVIL,        
    M.operador_donante_ds OPERADOR_DONANTE_MOVIL,


    CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN  
      CASE WHEN M.OPERADOR_DONANTE_ID is NULL THEN "ALTA NUEVA" 
      ELSE 
          CASE WHEN pm.OPERADOR_MOVIL_ID is not null THEN 
                  CASE 
                            WHEN TRIM(UPPER(COALESCE(M.MARCA_OPERADOR_DONANTE_DS,"NOINF"))) NOT IN ("OPERADORES","CABLEOPERADORES","CABLEMOVIL", "LEBARA","LYCAMOBILE","LLAMAYA") then "INTRAGRUPO" 
                            WHEN TRIM(UPPER(COALESCE(M.MARCA_OPERADOR_DONANTE_DS,"NOINF"))) IN ("OPERADORES","CABLEOPERADORES","CABLEMOVIL") then "EXTRAGRUPO"
                            WHEN TRIM(UPPER(COALESCE(M.MARCA_OPERADOR_DONANTE_DS,"NOINF"))) IN ("LEBARA","LYCAMOBILE","LLAMAYA") then "PREPAGO"
                            --WHEN TRIM(UPPER(M.MARCA_OPERADOR_DONANTE_DS)) ="LLAMAYA" AND M.TIPO_FACTURACION_DONANTE="PREPAID" then "PREPAGO"
                  END       
               ELSE "EXTRAGRUPO"
          END 
      END 
    END as TIPO_PORTABILIDAD_MOVIL,


    /*CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN  
      CASE WHEN M.OPERADOR_DONANTE_ID is NULL THEN "ALTA NUEVA" ELSE CASE WHEN pm.OPERADOR_MOVIL_ID is not null then "INTRAGRUPO" ELSE "EXTRAGRUPO"END END 
    END as TIPO_PORTABILIDAD_MOVIL,*/
    CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN m.fecha_ventana_cambio_id END as fecha_ventana_cambio_id_movil,
    --coalesce(f.ani,m.ani) as ani    
    
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` C
    LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S on s.marca_ds=c.marca_ds and s.cliente_id=c.cliente_id and s.servicio_id=c.servicio_id and s.ani>0
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_FIJA_DATAMARK_KD` F ON /*F.cliente_receptor_id=c.cliente_id and*/ f.ani=s.ani
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_MENSAJESxPORTABILIDAD_MOVIL_DATAMARK_KD` M ON /*M.cliente_receptor_id =C.cliente_id and*/ m.ani=s.ani
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS` pf on CAST(pf.OPERADOR_FIJO_ID AS INT64)=CAST(f.operador_donante_id AS INT64)
    LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_MOVILES` pm on CAST(pm.OPERADOR_MOVIL_ID AS INT64)=CAST(m.operador_donante_id AS INT64)
    --where c.cliente_id=7768204 and 
    --where c.cat_plays_p= "BA/MOVIL/TF/TV" and c.cliente_id=7736575
  --  where pf.version<=VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO
  --  and pm.version<=VERSION_VIGENTE_TABLA_OPERADORES_INTRAGRUPO
    order by 1,2,3,4,5; 

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` TV
    SET TV.MARCA_OPERADOR_DONANTE_FIJO=TF.MARCA_OPERADOR_DONANTE_FIJO,
        TV.OPERADOR_FIJO_ID=TF.OPERADOR_FIJO_ID,
        TV.OPERADOR_DONANTE_FIJO=TF.OPERADOR_DONANTE_FIJO,  
        TV.TIPO_PORTABILIDAD_FIJO=TF.TIPO_PORTABILIDAD_FIJO

    --========================================================================================================
    -- PARCHE 20250916
        --- Población de pedidos en los que sólo hay un servicio de telefonía fija por perdido que integran servicios de TF y TV
        --- Es decir, excluimos pedidos  que integran servicios de telefonía y televisión y contienen más de 1 servicio de telefonía
    --========================================================================================================
    --FROM   `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` TF
    FROM  (
        --- NUEVO PARCHE Población de pedidos en los que las contabilidad de servicios de telefonía fija que están contenidos en paquetes que contienen servicios de TF y TV es 1
        --- Es decir, excluimos casos en los que el pedido contenga más de 1 servicio de telefonía
        select distinct TF.*
        from `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` TV
        inner join `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` TF 
        on  TF.marca_ds=TV.marca_ds
        AND TF.cliente_id=tv.cliente_id
        and TF.pedido_id=TV.pedido_id
        and contains_substr(TF.cat_plays_p,"TF")
        and contains_substr(TF.cat_plays_p,"TV")  
        -- PARCHE TEMPORAL
        and TF.cliente_id !=7774460
        -- FIN PARCHE TEMPORAL
        and TF.categoria_servicio_ds="FIJA"
        and TV.categoria_servicio_ds="TELEVISION"
        QUALIFY count(TV.SERVICIO_ID) over( partition by TV.marca_ds, tv.cliente_id, tv.pedido_id) =1
    ) TF
    --========================================================================================================
    -- FIN PARCHE 20250916
    --======================================================================================================== 

    WHERE TF.marca_ds=TV.marca_ds
    AND TF.cliente_id=tv.cliente_id
    and TF.pedido_id=TV.pedido_id
    and contains_substr(TF.cat_plays_p,"TF")
    and contains_substr(TF.cat_plays_p,"TV")  
    -- PARCHE TEMPORAL
    and TF.cliente_id !=7774460
    -- FIN PARCHE TEMPORAL
    and TF.categoria_servicio_ds="FIJA"
    and TV.categoria_servicio_ds="TELEVISION";


    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` SET OPERADOR_DONANTE_FIJO="AVATEL", MARCA_OPERADOR_DONANTE_FIJO="AVATEL" WHERE OPERADOR_FIJO_ID="00887";
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` SET OPERADOR_FIJO_ID=CAST(NULL AS STRING) WHERE CONTAINS_SUBSTR(OPERADOR_FIJO_ID,"DESCONOCIDO"); 
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` SET OPERADOR_MOVIL_ID=CAST(NULL AS STRING) WHERE CONTAINS_SUBSTR(OPERADOR_MOVIL_ID,"DESCONOCIDO"); 


-----
    --- PASO 5.1: IDENTIFICO LOS EVENTOS RELACIONADOS CON VENTAS PROCEDENTES DE CANALES NO PENALIZADOS
    --- OUT 5.1: LOG_0180_EVENTOS_CANALES_EXCLUIDOSxPORTABILIDAD_DATAMARK_KD    

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_CANALES_NO_PENALIZADOSxPORTABILIDAD_DATAMARK_KD` AS
    SELECT * 
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` e
    WHERE NOT EXISTS(
        select 1 
        from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_RAPPELxPENALIZACION_PORTABILIDAD_INTRAGRUPOxCANAL` r
        where r.marca_ds=e.marca_ds
        and case when UPPER(TRIM(r.canal))="X" THEN TRUE ELSE (TRIM(e.canal_alta_ds))=UPPER(TRIM(r.canal)) end  
        and case when UPPER(TRIM(r.subcanal))="X" THEN TRUE ELSE UPPER(TRIM(e.subcanal_ds))=UPPER(TRIM(r.subcanal)) end 
    );

    --- PASO 5.2: IDENTIFICO LOS EVENTOS RELACIONADOS CON VENTAS PROCEDENTES DE CANALES PENALIZADOS
    --- OUT 5.2: LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD` AS
    SELECT * 
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOS_TODOS_CANALESxPORTABILIDAD_DATAMARK_KD` e
    WHERE EXISTS(
        select 1 
        from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_RAPPELxPENALIZACION_PORTABILIDAD_INTRAGRUPOxCANAL` r
        where r.marca_ds=e.marca_ds
        and case when UPPER(TRIM(r.canal))="X" THEN TRUE ELSE (TRIM(e.canal_alta_ds))=UPPER(TRIM(r.canal)) end  
        and case when UPPER(TRIM(r.subcanal))="X" THEN TRUE ELSE UPPER(TRIM(e.subcanal_ds))=UPPER(TRIM(r.subcanal)) end 
    );




  --- PASO 6: CREO TABLA CON VENTAS CAPTACION ENRIQUECIDAS CON EVENTOS DE PORTABILIDAD CONFRMADA EN MES DE COMISION
    --- OUT 6: VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD      


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD` AS
    select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0180_EVENTOSxPORTABILIDAD_DATAMARK_KD`;




    --- PASO 7: TIPIFICO LOS PAQUETES DE SERVICIOS  ME QUEDO CON AQUELLOS QUE CUMPLEN LOS REQUERIMIENTOS PARA QUE SUS SERVICIOS SE MARQUEN CON FLAG INTRAGRUPO
    --- OUT 7: CONTRATOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CONTRATOS_VENTAS_CAPTACION_TOTALxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS
    WITH p as (
        select marca_ds, cliente_id,
        coalesce(CAST(contrato_id AS STRING),expediente_padre_id) as contrato_id,
        --case when marca_ds!="R" then CAST(pedido_id AS STRING) else expediente_padre_id END as pedido_id, 
        --cat_plays_p, cat_plays, cat_plays_rfb_p,
        --tipo_portabilidad_fijo,
        --tipo_portabilidad_movil,
        array_to_string(array_agg(CAST(pedido AS STRING) ),",")  as vpedido,
        array_to_string(array_agg(CAST(cat_plays_p AS STRING) ),",")  as cat_plays_p,        
        array_to_string(array_agg(CASE WHEN MARCA_OPERADOR_DONANTE_FIJO IS NOT NULL THEN MARCA_OPERADOR_DONANTE_FIJO END ),",")  as vmof, 
        array_to_string(array_agg(CASE WHEN OPERADOR_DONANTE_FIJO IS NOT NULL THEN OPERADOR_DONANTE_FIJO END ),",")  as vof,
        array_to_string(array_agg(CASE WHEN ani_fijo IS NOT NULL THEN CAST(ani_fijo AS STRING ) END ),",")  as vanif,
        array_to_string(array_agg(CASE WHEN MARCA_OPERADOR_DONANTE_MOVIL IS NOT NULL THEN MARCA_OPERADOR_DONANTE_MOVIL END ),",")  as vmom,     
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


        from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD`
        --where cliente_id=7765132
        --where cliente_id=4066128
        group by 1,2,3
        --,7,8
        --having flag_intragrupo>0
        order by 1,2,3
    ) select *,
        case when nfija_pext > 0 then 0
            when nfija_pint > 0 then 1         
        ELSE 
            Case when  nmov_pint > nmov_pext  then 1
                        else 0
            end    
        END as flag_intragrupo
    From p 
    order by 1,2,3;

    --- PASO 8: TIPIFICO LOS PAQUETES DE SERVICIOS  ME QUEDO CON AQUELLOS QUE CUMPLEN LOS REQUERIMIENTOS PARA QUE SUS SERVICIOS SE MARQUEN CON FLAG INTRAGRUPO
    --- OUT 8: PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACION_TOTALxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS
    WITH p as (
        select marca_ds, cliente_id,
        pedido,
        --case when marca_ds!="R" then CAST(pedido_id AS STRING) else expediente_padre_id END as pedido_id, 
        cat_plays_p, cat_plays, cat_plays_rfb_p,
        --tipo_portabilidad_fijo,
        --tipo_portabilidad_movil,
        array_to_string(array_agg(CASE WHEN MARCA_OPERADOR_DONANTE_FIJO IS NOT NULL THEN MARCA_OPERADOR_DONANTE_FIJO END ),",")  as vmof, 
        array_to_string(array_agg(CASE WHEN OPERADOR_DONANTE_FIJO IS NOT NULL THEN OPERADOR_DONANTE_FIJO END ),",")  as vof,
        array_to_string(array_agg(CASE WHEN ani_fijo IS NOT NULL THEN CAST(ani_fijo AS STRING ) END ),",")  as vanif,
        array_to_string(array_agg(CASE WHEN MARCA_OPERADOR_DONANTE_MOVIL IS NOT NULL THEN MARCA_OPERADOR_DONANTE_MOVIL END ),",")  as vmom,     
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


        from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD`
        --where cliente_id=7765132
        --where cliente_id=4066128
        group by 1,2,3,4,5,6
        --,7,8
        --having flag_intragrupo>0
        order by 1,2,3
    ) select *,
        case when nfija_pext > 0 then 0
            when nfija_pint > 0 then 1         
        ELSE 
            Case when  nmov_pint > nmov_pext  then 1
                        else 0
            end    
        END as flag_intragrupo
    From p 
    order by 1,2,3;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CONTRATOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS
    select * 
    from  `mm-commissions-reporting.KRT_CAPTACION.CONTRATOS_VENTAS_CAPTACION_TOTALxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` 
    where flag_intragrupo=1
    order by 1,2,3;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS
    select * 
    from  `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACION_TOTALxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` 
    where flag_intragrupo=1
    order by 1,2,3;


END