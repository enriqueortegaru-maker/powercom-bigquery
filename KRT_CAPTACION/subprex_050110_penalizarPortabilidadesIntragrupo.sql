BEGIN

  --- PASO 1: GENERO EL LISTADO DE COMISIONES PENALIZADAS POR PORTABILIDAD INTRAGRUPO

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_POTENCIALES` AS
  (SELECT distinct m.* FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` m
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO` p on p.marca_ds=m.marca_ds and p.cliente_id=m.cliente_id and p.pedido=m.pedido and m.pedido!="666"
  ORDER by m.marca_ds, m.cliente_id, m.pedido, m.servicio_id, concepto_ds)
  UNION ALL
  (SELECT distinct m.* FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL` m
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO` p on p.marca_ds=m.marca_ds and p.cliente_id=m.cliente_id and p.pedido="666"
  ORDER by m.marca_ds, m.pedido, m.servicio_id, concepto_ds);


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` AS
  select distinct p.*
  from `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO_POTENCIALES` p
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

  


  --- PASO 3: ACTUALIZO EL GRID, TIPIFICACIONES E IMPORTE ASOCIADO A LAS PENALIZACIONES

    -- Campos: 
      -- Concepto_ds se actualiza con prefijo
      -- Grid: Asignamos valor 61 a penalizaciones intergrupo
      -- Clase_mm: Asignamos la denominación "P - Penalizacion"
      -- Desc_mm:  Asignamos el descriptivo: "P- Penalización por portabilidad intragrupo"
      -- Importe: Se multiplica por factor de ponderación y se negativiza    

      --select distinct grid from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` order by grid desc;


    UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO`
    SET clase_mm="P - Penalizacion",
    desc_mm="P - Penalizacion por portabilidad intragrupo",
    importe=SAFE_NEGATE(SAFE_MULTIPLY(importe, 0.5)),
    concepto_ds= concat("Penalizacion por portabilidad intragrupo de concepto: ", concepto_ds)
    WHERE TRUE;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` AS 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO`;


  --- PASO 4: INSERTO LOS UNITARIOS EN EL MARCO RETRIBUTIVO
  INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
  SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO`;


  --- PASO 5: GENERO INFORME CON LISTADO DE SERVICOS ASOCIADOS A SERVICIOS VINCULADOS CON FLAG INTRAGRUPO =1 
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` AS 
    with ev as (
      SELECT marca_ds,cliente_id, pedido, cat_plays_p, servicio_id,categoria_servicio_ds,detalle_servicio_ds,concepto_ds, ani_serv as ani,tipo_portabilidad_fijo, OPERADOR_DONANTE_FIJO, tipo_portabilidad_movil,operador_donante_movil
      --FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_EVENTOSxPORTABILIDAD` 
      FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACIONxPORTABILIDAD` v
      where exists(
        select 1 
        from  `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` p 
        where p.marca_ds=v.marca_ds and p.cliente_id=v.cliente_id and p.pedido=v.pedido 
      )
      order by 1,2,3
      
    )
    SELECT p.* except(vof, vom, nba, nba_an,nba_pint, nba_pext,nfija,nfija_an,nfija_pint, nfija_pext,nmov,nmov_an,nmov_pint, nmov_pext),
    ev.* except(marca_ds, pedido,cliente_id, cat_plays_p)
    FROM `mm-commissions-reporting.KRT_CAPTACION.PEDIDOS_VENTAS_CAPTACIONxPORTABILIDAD_INTRAGRUPO` p
    left join ev on p.marca_ds=ev.marca_ds and p.pedido=ev.pedido and p.pedido!="666"
    --where p.cat_plays_p= "BA/MOVIL/TF/TV" ---and p.cliente_id=7736575
    order by marca_ds, pedido, servicio_id, concepto_ds;



  --- PASO 6: REVISAR LISTADO DE SERVICOS ASOCIADOS A SERVICIOS VINCULADOS CON FLAG INTRAGRUPO =1 
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050110_REVISAR_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` AS 
    select distinct * 
    from `mm-commissions-reporting.KRT_CAPTACION.INFORME_PENALIZACIONESxPORTABILIDAD_INTRAGRUPO` p
    where not exists(
      select 1 from  `mm-commissions-reporting.KRT_CAPTACION.PENALIZACIONESxPORTABILIDAD_INTRAGRUPO`  i where i.marca_Ds=p.marca_ds and i.cliente_id=p.cliente_id and p.servicio_id=p.servicio_id
    ); 


END