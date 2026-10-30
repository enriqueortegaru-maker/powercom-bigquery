BEGIN

	--- Inserto los apuntes en la tabla de comisiones
  --DECLARE VDESDE, VFECHA_CALC_OR, VFECHA_CALC_DE INT64;SET VDESDE=20260201;SET VFECHA_CALC_OR=20260305;SET VFECHA_CALC_DE=20260304; 

    IF (select count(marca) from  `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` where coalesce(importe,0)>0 and desde=vdesde ) > 0 then 
		---DECLARE VDESDE, VFECHA_CALC_OR, VFECHA_CALC_DE INT64;SET VDESDE=20260201;SET VFECHA_CALC_OR=20260305;SET VFECHA_CALC_DE=20260304; 


      	CREATE OR REPLACE TEMP TABLE tmp_apuntes AS     	
      	with top as (
	        --- Descubro catalogo de servicio predominante para asignar la comision a ese catalogo y posteriormente poder generar el concepto SAP  
	        SELECT 
	          ag.marca_ds, 
	          ag.TipoProducto, 
	          ag.ClaseProducto,
	          ag.NombreProducto
	        FROM `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` ag
	        INNER JOIN `mm-commissions-reporting.KRT_CARTERA.V_FLUJO_MESxVERSION` vr on vr.mes=parse_Date("%Y%m%d" ,cast(vdesde as string))    
	        WHERE ag.desde=vdesde
	        and ag.fecha_calc_dt=parse_Date("%Y%m%d" ,cast(vfecha_calc_or as string))
	        and ag.version=vr.version
	        GROUP BY 
	          ag.marca_ds, 
	          ag.ClaseProducto,
	          ag.TipoProducto, 
	          ag.NombreProducto
	        QUALIFY ROW_NUMBER() OVER (PARTITION BY ag.marca_ds, ag.TipoProducto ORDER BY SUM(ag.importe) DESC) = 1
		  ) 
	    --- Creo tabla temporal de pauntes integrar
	      select PARSE_DATE("%Y%m%d",CAST(vfecha_calc_de AS STRING)) as fecha_calc_dt, c.marca, c.canal, c.subcanal, c.distribuidor as nombre_distribuidor, top.ClaseProducto, c.categoria_servicio as TipoProducto, top.NombreProducto, c.concepto as concepto_ds,
      		`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisionesv1`(c.desc_mm) as clase_mm,
      		c.desc_mm, 
      		c.orden as orden_sap, 
      		CAST(VDESDE/100 AS INT64) as mes_comision_id,
      		c.importe 
      		from `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` c
      		left join top ON c.marca = top.marca_ds  AND c.categoria_servicio = top.TipoProducto  
      		where c.tipo="CARTERA"
      		and c.desde=VDESDE;




		  insert `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` (fecha_calc_dt, marca_ds, canal, subcanal, nombre_distribuidor, ClaseProducto, TipoProducto, NombreProducto, concepto_ds, clase_mm,desc_mm, orden_sap, mes_comision_id,importe, importe_nivel, total, decomisionable)
	    select fecha_calc_dt, marca, canal, subcanal, nombre_distribuidor, ClaseProducto, TipoProducto, NombreProducto, concepto_ds,
	      clase_mm, desc_mm, orden_sap, mes_comision_id
	      importe, importe, importe ,'N'
	    from tmp_apuntes; 


      	---- Integro apuntes en AGG_Comisiones_Listado 
		  --insert `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES_LISTADO` (fecha_calc_dt, marca_ds, canal, subcanal, nombre_distribuidor, ClaseProducto, TipoProducto, NombreProducto, concepto_lista, concepto_ds, clase_mm,desc_mm, orden_sap, mes_comision_id, importe, decomisionable)
	    select fecha_calc_dt, marca, canal, subcanal, nombre_distribuidor, ClaseProducto, TipoProducto, NombreProducto, 
	    'PAD' as concepto_lista,
	    concepto_ds,
	    clase_mm,
	    desc_mm, orden_sap, mes_comision_id, 
			importe, 'N'
	    from tmp_apuntes; 

  END IF;

END