BEGIN

    
    DECLARE DESDE_1M INT64;
    -- PARCHE LOCAL
    --DECLARE DESDE, HASTA INT64;SET DESDE=20240301;SET HASTA=20240331;    
    -- FIN PARCHE LOCAL
    SET DESDE_1M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE AS string)), interval 1 month),month)) AS STRING) AS INT64);


  --- PASO 1: IDENTIFICO EL ORIGEN DE LOS SERVICIOS VENDIDOS PROCEDENTES DE OTROS PROVEEDORES

  --- DECLARE DESDE, HASTA INT64; SET DESDE=20240301; SET HASTA=20240331;
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_MENSAJESxPORTABILIDAD_FIJA` AS
    select ROW_NUMBER() over(partition by ani order by fecha_confirmacion_portabilidad_id desc) as ind, fecha_confirmacion_portabilidad_id, fecha_ventana_cambio_id, sentido_portabilidad_ds, OPERADOR_DONANTE_ID, OPERADOR_DONANTE_DS, estado_portabilidad_fijo_ds, operador_receptor_id, operador_receptor_ds, cliente_receptor_id, servicio_receptor_id,ani
    from `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_120_portabilidad_fijo`  f
    where fecha_confirmacion_portabilidad_id between desde_1m and hasta
    --and ani=948388545
    QUALIFY ind=1;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_MENSAJESxPORTABILIDAD_MOVIL` AS
    select ROW_NUMBER() over(partition by ani order by fecha_confirmacion_portabilidad_id desc) as ind, fecha_confirmacion_portabilidad_id, fecha_ventana_cambio_id, sentido_portabilidad_ds, OPERADOR_DONANTE_ID, OPERADOR_DONANTE_DS, estado_portabilidad_movil_ds, operador_receptor_id, operador_receptor_ds,cliente_receptor_id, servicio_receptor_id,ani
    from `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_130_portabilidad_movil`  m
    where fecha_confirmacion_portabilidad_id between desde_1m and hasta
    QUALIFY ind=1;


  --- PASO 2: IDENTIFICO EL ORIGEN DE LOS SERVICIOS VENDIDOS PROCEDENTES DE OTROS PROVEEDORES

  /*select  distinct c.marca_Ds, c.cliente_id, c.fecha_venta_neta_id, s.ani
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` C
  LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S on s.marca_ds=c.marca_ds and s.cliente_id=c.cliente_id and s.servicio_id=c.servicio_id
  order by 1,2,3*/



  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` AS
  SELECT distinct C.*,s.ani as ani_serv, f.ani as ani_fijo, m.ani as ani_movil,
  F.OPERADOR_DONANTE_ID OPERADOR_FIJO_ID, F.OPERADOR_DONANTE_DS OPERADOR_DONANTE_FIJO,
  CASE WHEN not starts_with(c.categoria_servicio_ds,"MOVILES") and not starts_with(c.categoria_servicio_ds,"TERMINALES") THEN
    CASE WHEN F.OPERADOR_DONANTE_ID is NULL THEN "ALTA NUEVA" ELSE CASE WHEN pf.OPERADOR_FIJO_ID is not null then "INTRAGRUPO" ELSE "EXTRAGRUPO" END END 
  END as TIPO_PORTABILIDAD_FIJO,  
  
  CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN M.operador_donante_id END OPERADOR_MOVIL_ID, 
  M.operador_donante_ds OPERADOR_DONANTE_MOVIL,
  
  CASE WHEN starts_with(c.categoria_servicio_ds,"MOVILES") THEN  
    CASE WHEN M.OPERADOR_DONANTE_ID is NULL THEN "ALTA NUEVA" ELSE CASE WHEN pm.OPERADOR_MOVIL_ID is not null then "INTRAGRUPO" ELSE "EXTRAGRUPO"END END 
  END as TIPO_PORTABILIDAD_MOVIL,
  --coalesce(f.ani,m.ani) as ani
  
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` C
  LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` S on s.marca_ds=c.marca_ds and s.cliente_id=c.cliente_id and s.servicio_id=c.servicio_id and s.ani>0
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_MENSAJESxPORTABILIDAD_FIJA` F ON F.cliente_receptor_id=c.cliente_id and f.ani=s.ani
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_MENSAJESxPORTABILIDAD_MOVIL` M ON M.cliente_receptor_id =C.cliente_id and m.ani=s.ani
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_FIJOS` pf on CAST(pf.OPERADOR_FIJO_ID AS INT64)=CAST(f.operador_donante_id AS INT64)
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_AG_ESTATICO_OPERADORES_MOVILES` pm on CAST(pm.OPERADOR_MOVIL_ID AS INT64)=CAST(m.operador_donante_id AS INT64)
  --where c.cat_plays_p= "BA/MOVIL/TF/TV" and c.cliente_id=7736575
  order by 1,2,3,4,5; 

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` TV
  SET TV.OPERADOR_FIJO_ID=TF.OPERADOR_FIJO_ID,
      TV.OPERADOR_DONANTE_FIJO=TF.OPERADOR_DONANTE_FIJO,  
      TV.TIPO_PORTABILIDAD_FIJO=TF.TIPO_PORTABILIDAD_FIJO
  FROM   `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` TF 
  WHERE TF.marca_ds=TV.marca_ds
  AND TF.cliente_id=tv.cliente_id
  and TF.pedido_id=TV.pedido_id
  and contains_substr(TF.cat_plays_p,"TF")
  and contains_substr(TF.cat_plays_p,"TV")  
  and TF.categoria_servicio_ds="FIJA"
  and TV.categoria_servicio_ds="TELEVISION";


  UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` SET OPERADOR_DONANTE_FIJO="AVATEL" WHERE OPERADOR_FIJO_ID="00887";
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` SET OPERADOR_FIJO_ID=CAST(NULL AS STRING) WHERE CONTAINS_SUBSTR(OPERADOR_FIJO_ID,"DESCONOCIDO"); 
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` SET OPERADOR_MOVIL_ID=CAST(NULL AS STRING) WHERE CONTAINS_SUBSTR(OPERADOR_MOVIL_ID,"DESCONOCIDO"); 



  --- PASO 2: TIPIFICO LOS PAQUETES DE SERVICIOS  ME QUEDO CON AQUELLOS QUE CUMPLEN LOS REQUERIMIENTOS PARA QUE SUS SERVICIOS SE MARQUEN CON FLAG INTRAGRUPO

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PEDIDOSxPORTABILIDAD_INTRAGRUPO` AS
  select marca_ds, cliente_id,
  pedido,
  --case when marca_ds!="R" then CAST(pedido_id AS STRING) else expediente_padre_id END as pedido_id, 
  cat_plays_p, cat_plays, cat_plays_rfb_p,
  array_to_string(array_agg(CASE WHEN OPERADOR_DONANTE_FIJO IS NOT NULL THEN OPERADOR_DONANTE_FIJO END ),",")  as vof,
  array_to_string(array_agg(CASE WHEN OPERADOR_DONANTE_MOVIL IS NOT NULL THEN OPERADOR_DONANTE_MOVIL END ),",")  as vom,
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
  from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD`
  group by 1,2,3,4,5,6
  having flag_intragrupo>0
  order by 1,2,3;
  




  --- PASO 2: TIPIFICO LOS PAQUETES DE SERVICIOS  ME QUEDO CON AQUELLOS QUE CUMPLEN LOS REQUERIMIENTOS PARA QUE SUS SERVICIOS SE MARQUEN CON FLAG INTRAGRUPO E IDPEDIDO DISTINTO DE 1

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` AS
  (SELECT distinct m.* FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` m
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PEDIDOSxPORTABILIDAD_INTRAGRUPO` p on p.marca_ds=m.marca_ds and p.cliente_id=m.cliente_id and p.pedido=m.pedido and m.pedido!="666"
  ORDER by m.marca_ds, m.cliente_id, m.pedido, m.servicio_id, concepto_ds)
  UNION ALL
  (SELECT distinct m.* FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` m
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PEDIDOSxPORTABILIDAD_INTRAGRUPO` p on p.marca_ds=m.marca_ds and p.cliente_id=m.cliente_id and p.pedido="666"
  ORDER by m.marca_ds, m.pedido, m.servicio_id, concepto_ds);


  -- asigno grid propio a este grupo para posterior tipìficación de para penalización
  --select distinct marca_ds, sum(importe) over(partition by marca_ds) as imp from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` order by 2 desc;
  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` where marca_ds="EUSKALTEL" order by marca_ds, cliente_id, servicio_id;  
  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` where marca_ds="EUSKALTEL";

  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PEDIDOSxPORTABILIDAD_INTRAGRUPO` where marca_ds="EUSKALTEL";
  	
  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` where pedido="8124173";


   
  --- PASO 3: LISTO LOS PEDIDOS QUE TIPIFICO LOS SERVICIOS VINCULADOS A LOS PEDIDOS CON FLAG INTRAGRUPO =1 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PORTABILIDADES_INTRAGRUPO` AS
  with ev as (SELECT marca_ds,cliente_id, pedido, cat_plays_p, servicio_id,categoria_servicio_ds,detalle_servicio_ds,concepto_ds, ani_serv as ani,tipo_portabilidad_fijo, OPERADOR_DONANTE_FIJO, tipo_portabilidad_movil,operador_donante_movil
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` 
    order by 1,2,3
    
  )
  SELECT p.* except(vof, vom, nba, nba_an,nba_pint, nba_pext,nfija,nfija_an,nfija_pint, nfija_pext,nmov,nmov_an,nmov_pint, nmov_pext),
  ev.* except(marca_ds, pedido,cliente_id, cat_plays_p)
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PEDIDOSxPORTABILIDAD_INTRAGRUPO` p
  left join ev on p.marca_ds=ev.marca_ds and p.pedido=ev.pedido and p.pedido!="666"
  where p.cat_plays_p= "BA/MOVIL/TF/TV" ---and p.cliente_id=7736575
  order by marca_ds, pedido, servicio_id, concepto_ds;



END