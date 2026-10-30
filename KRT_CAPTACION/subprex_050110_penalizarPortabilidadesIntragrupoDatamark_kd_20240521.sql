BEGIN

  --- PASO 1: GENERO EL LISTADO DE COMISIONES PENALIZADAS POR PORTABILIDAD INTRAGRUPO

    --- OUT 1: LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_POTENCIALES_DATAMARK_KD
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_POTENCIALES_DATAMARK_KD` AS
  (SELECT distinct m.* FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` m
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` p on p.marca_ds=m.marca_ds and p.cliente_id=m.cliente_id and p.pedido=m.pedido and m.pedido!="666"
  ORDER by m.marca_ds, m.cliente_id, m.pedido, m.servicio_id, concepto_ds)
  UNION ALL
  (SELECT distinct m.* FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` m
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` p on p.marca_ds=m.marca_ds and p.cliente_id=m.cliente_id and p.pedido="666"
  ORDER by m.marca_ds, m.pedido, m.servicio_id, concepto_ds);

    --- OUT 1: LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS
  select distinct p.*
  from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_POTENCIALES_DATAMARK_KD` p
  inner join  `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_RAPPELxPENALIZACION_PORTABILIDAD_INTRAGRUPOxCANAL` r
  on p.marca_ds=r.marca_Ds 
  and case when UPPER(TRIM(r.canal))="X" THEN TRUE ELSE (TRIM(p.canal_alta_ds))=UPPER(TRIM(r.canal)) end  
  and case when UPPER(TRIM(r.subcanal))="X" THEN TRUE ELSE UPPER(TRIM(p.subcanal_ds))=UPPER(TRIM(r.subcanal)) end; 



  -- asigno grid propio a este grupo para posterior tipìficación de para penalización
  --select distinct marca_ds, sum(importe) over(partition by marca_ds) as imp from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` order by 2 desc;
  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` where marca_ds="EUSKALTEL" order by marca_ds, cliente_id, servicio_id;  
  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` where marca_ds="EUSKALTEL";

  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PEDIDOSxPORTABILIDAD_INTRAGRUPO` where marca_ds="EUSKALTEL";
  	
  -- select * from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` where pedido="8124173";

  


  --- PASO 2: ACTUALIZO EL GRID, TIPIFICACIONES E IMPORTE ASOCIADO A LAS PENALIZACIONES

    -- Campos: 
      -- Concepto_ds se actualiza con prefijo
      -- Grid: Asignamos valor 61 a penalizaciones intergrupo
      -- Clase_mm: Asignamos la denominación "P - Penalizacion"
      -- Desc_mm:  Asignamos el descriptivo: "P- Penalización por portabilidad intragrupo"
      -- Importe: Se multiplica por factor de ponderación y se negativiza    

      --select distinct grid from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` order by grid desc;


    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD`
    SET clase_mm="P - Penalizacion",
    desc_mm="P - Penalizacion por portabilidad intragrupo",
    importe=SAFE_NEGATE(SAFE_MULTIPLY(importe, 0.5)),
    concepto_ds= concat("Penalizacion por portabilidad intragrupo de concepto: ", concepto_ds)
    WHERE TRUE;

  --- PASO 3: CREO TABLA CON LISTADO DE PENALIZACIONES A INTRODUCIR EN MARCO RETRIBUTIVO
    --- OUT 3: PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD  

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD`;


  --- PASO 4: GENERO INFORME CON LISTADO DE SERVICOS ASOCIADOS A SERVICIOS VINCULADOS CON FLAG INTRAGRUPO =1 
      --- OUT 4: INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD          
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS 
    with ev as (
      SELECT marca_ds,cliente_id, pedido, cat_plays_p, servicio_id,categoria_servicio_ds,detalle_servicio_ds,concepto_ds, ani_serv as ani,tipo_portabilidad_fijo, OPERADOR_DONANTE_FIJO, tipo_portabilidad_movil,operador_donante_movil
      --FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` 
      FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD` v
      where exists(
        select 1 
        from  `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` p 
        where p.marca_ds=v.marca_ds and p.cliente_id=v.cliente_id and p.pedido=v.pedido 
      )
      order by 1,2,3
      
    )
    SELECT p.* except(vof, vom, nba, nba_an,nba_pint, nba_pext,nfija,nfija_an,nfija_pint, nfija_pext,nmov,nmov_an,nmov_pint, nmov_pext),
    ev.* except(marca_ds, pedido,cliente_id, cat_plays_p)
    FROM `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` p
    left join ev on p.marca_ds=ev.marca_ds and p.pedido=ev.pedido and p.pedido!="666"
    --where p.cat_plays_p= "BA/MOVIL/TF/TV" ---and p.cliente_id=7736575
    --where p.cliente_id=2345216
    order by marca_ds, pedido, servicio_id, concepto_ds;



  --- PASO 5: REVISAR LISTADO DE SERVICOS ASOCIADOS A SERVICIOS VINCULADOS CON FLAG INTRAGRUPO =1 
    --- OUT 5: LOG_050110_REVISAR_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD              
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_REVISAR_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` AS 
    select distinct * 
    from `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` p
    where not exists(
      select 1 from  `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD`  i where i.marca_Ds=p.marca_ds and i.cliente_id=p.cliente_id and p.servicio_id=p.servicio_id
    ); 



  --- PASO 6: AUDITAR PORTABILIDAD DE PENALIZACIONES RESPECTO A LOS MENSAJES DE PORTABILIDAD REGISTRADOS EN EKTNET
    --- OUT 6: LOG_050110_AUDIT_PENALIZACIONES_DATAMARK_KD_VS_PORTABILIDAD_EKNET              

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_AUDIT_PENALIZACIONES_DATAMARK_KD_VS_PORTABILIDAD_EKNET` AS 
    with p as (
      select distinct pn.*, pd.ani_serv as ani, pd.fecha_ventana_cambio_id, pd.fecha_ventana_cambio_id_fijo, pd.fecha_ventana_cambio_id_movil
      from  `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_DATAMARK_KD` pn
      left join  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD_DATAMARK_KD` pd using(marca_ds, cliente_id, servicio_id)
      order by pn.marca_ds, pn.cliente_id, pn.servicio_id
    )

    select p.*, 
    coalesce(pf.prOperDon_Id,pm.CodOperadorDonante) as COD_OPERADOR_DONANTE_EKTNET,
    coalesce(pf.prOperRec_Id, pm.pmovCodOperadorAct) as COD_OPERADOR_RECEPTOR_EKTNET, 
    coalesce(pf.prFechaIniVent,pm.pmovFechaVentana) as FECHA_VENTANA_CAMBIO_EKTNET, 
    pf.prOperDon_Id as COD_OPERADOR_DONANTE_FIJO_EKTNET, 
    pf.prOperRec_Id as COD_OPERADOR_RECEPTOR_FIJO_EKTNET, 
    pf.prFechaIniVent as FECHA_VENTANA_CAMBIO_FIJO_EKTNET,
    pm.CodOperadorDonante as COD_OPERADOR_DONANTE_MOVIL_EKTNET, 
    pm.pmovCodOperadorAct as COD_OPERADOR_RECEPTOR_MOVIL_EKTNET, 
    pm.pmovFechaVentana as FECHA_VENTANA_CAMBIO_MOVIL_EKTNET,
    from p
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_por_numeracion_portada` pf on pf.prNumAbonado=p.ani and CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM pf.prFechaIniVent)) as integer) between desde and hasta
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_pmov_num_portada` pm  on CAST(pm.pmovMSISDN as INT64)=p.ani and CAST(FORMAT_DATE("%Y%m%d",extract(DATE FROM pm.pmovFechaVentana)) as integer) between desde and hasta;



END