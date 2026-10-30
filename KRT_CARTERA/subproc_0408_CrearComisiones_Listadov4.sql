BEGIN

  DECLARE VFECHA_ACTIVACION_DT DATE;
  DECLARE VMES_PREVIO DATE;

  SET VFECHA_ACTIVACION_DT = PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));
  SET VMES_PREVIO = DATE_SUB(DATE_TRUNC(VFECHA_ACTIVACION_DT, MONTH), INTERVAL 1 MONTH);


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES_LISTADO` AS 
	
		with 
		valid_conceptos AS (
            SELECT DISTINCT concepto 
            FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
            WHERE mes_factura_dt = VMES_PREVIO
						and tipo="CARTERA"
    ),
    	valid_clases AS (
          	SELECT DISTINCT clase_concepto 
            FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
            WHERE mes_factura_dt = VMES_PREVIO
						and tipo="CARTERA"						
    ),	

		 c as (
		
			---- B2B	
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo, Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento, ClaseProducto, TipoProducto, 
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"B2B" as concepto_lista,total as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where canal="B2B" and coalesce(total,0) !=0


			UNION ALL 


			---- Rappel
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto,  
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Rappel" as concepto_lista,total as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where contains_substr(TipoMovimiento, "Rappel") and coalesce(total,0) !=0

			UNION ALL 


			---- Reparto de horas
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto,  
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Bono_Extras" as concepto_lista,total as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where contains_substr(TipoMovimiento, "Reparto de horas") and coalesce(total,0) !=0


			UNION ALL 

			---- Traslado
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto,  
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Traslado" as concepto_lista,
			total as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where (contains_substr(TipoMovimiento, "traslado"))
			and coalesce(total,0) !=0

			UNION ALL

			---- Unitario
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto, 
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Unitario" as concepto_lista,
			importe as importe, desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "Rappel"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "traslado"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "reparto de"))			
			and not(canal="B2B")
			and importe !=0


		UNION ALL

		---- Unitarios procedentes de retrasos en los que solo se ha informado el total
		Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
		Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto,  
		clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
		"Unitario" as concepto_lista,
		total as importe, desc_mm
		--from `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_INFORME`
		from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`		
		where not(contains_substr(coalesce(TipoMovimiento,"NODEF"), "Rappel"))
		and not(contains_substr(coalesce(TipoMovimiento,"NODEF"), "traslado"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "reparto de"))		
		and not(canal="B2B")
		and coalesce(importe,0) =0	
		and coalesce(Bono_Calidad,0) =0
		and coalesce(Bono_Comercial,0) =0
		and coalesce(Bono_Extras,0) =0
		and total !=0


			UNION ALL 

			---- Bono Nivel
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,   ClaseProducto, TipoProducto, 
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Bono_Nivel" as concepto_lista,
			importe_nivel -importe as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "Rappel"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "traslado"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "reparto de"))			
			and not(canal="B2B")
			and (coalesce(importe_nivel,0) - coalesce(importe,0)) !=0


			UNION ALL

			---- Bono Comercial
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto,  
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Bono_Calidad" as concepto_lista,
			Bono_calidad as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "Rappel"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "traslado"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "reparto de"))			
			and not(canal="B2B")
			and Bono_Calidad !=0

			UNION ALL

			---- Bono Calidad
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto,  
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Bono_Comercial" as concepto_lista,
			Bono_Comercial as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "Rappel"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "traslado"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "reparto de"))			
			and not(canal="B2B")
			and Bono_Comercial !=0

			UNION ALL

			---- Bono Extras
			Select mes_comision_id, marca_ds,  IdCatalogo,  NombreProducto,  nombre_distribuidor, equipo,  Canal,  subcanal,  agente,  IdFijo,  Antiguedad,  DNI_CIF,  Marca_Cartera,  Fecha_Activacion,  Fecha_Creacion,  Segmento,  
			Subsegmento,  idCatalogoOrigen,  IdProductoOrigen,  NombreProductoOrigen,  TipoMovimiento,  IdProducto,  Contrato,  UsuarioCreador,  agente_creador_id,  concepto_ds,  concepto_origen_ds,  medio_conocimiento,  ClaseProducto, TipoProducto,  
			clave_mr,  MARCO_RETRIBUTIVO,  tvt_ups_virgin,  televenta,  nivel,  campana_id,  nombre_campana,  decomisionable,  decom_bono_extra,  orden_sap, 
			"Bono_Extras" as concepto_lista,
			Bono_Extras as importe, CAST(NULL as STRING) as desc_mm
			from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
			where not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "Rappel"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "traslado"))
			and not(contains_substr(coalesce(TipoMovimiento,"NOINF"), "reparto de"))			
			and not(canal="B2B")
			and Bono_Extras !=0
	
		), d as (
	    select distinct c.* except(desc_mm),
				CASE WHEN concepto_lista ="Unitario" and vc.concepto IS NOT NULL THEN c.desc_mm 
						ELSE 	
				    --`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_lista_comisiones`(TipoMovimiento, concepto_lista, concepto_ds, NombreProducto) as desc_mm
							`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_lista_comisionesv1`(c.TipoMovimiento, c.concepto_lista, c.concepto_ds, NombreProducto, c.TipoProducto) 
				END as desc_mm
	    from  c
			LEFT JOIN valid_conceptos vc ON vc.concepto = c.desc_mm

		)
		select d.* ,
	--	`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(p.desc_mm) as clase_mm
			`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisionesv1`(d.desc_mm) as clase_mm

		from d;

END