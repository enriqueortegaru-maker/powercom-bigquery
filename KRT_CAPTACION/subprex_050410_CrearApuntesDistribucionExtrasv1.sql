BEGIN

		--- PASO 0: AJUSTES QUE NO SE DISTRIBUYEN
		---	OUT 0: LOG_050410_AJUSTES_EVENTOS_DEFINITIVOS_NO_DIST

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_NO_DIST` AS 
		SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` WHERE 1=0;

		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_NO_DIST` (marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, concepto_ds, clase_mm, desc_mm, importe, orden_sap, decomisionable)
		select marca_ds, 
		case when UPPER(TRIM(canal_alta_ds)) in ("PUNTO DE VENTA", "TASK_FORCE", "CANALES ALTERNATIVOS") THEN "PRESENCIAL" ELSE "NO PRESENCIAL" END,
		canal_alta_ds, subcanal_ds, nombre_distribuidor_ds, 
		CONCAT('Extra por concepto: ', concepto),
		'D - Extracomision',
		CASE  WHEN UPPER(TRIM(distribuir))='I' THEN 'D - Inicio Actividad'
					WHEN UPPER(TRIM(distribuir))='T' THEN 'D - Trimestral'
					WHEN UPPER(TRIM(distribuir))='A' THEN 'D - Anual'					
					WHEN UPPER(TRIM(distribuir))='F' THEN 'D - Fin Actividad'
					ELSE 'D - Mensual'
		END,					
		importe,
		orden_sap, 
		decomisionable
		from `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXTRAS_DESARROLLO_NUEVO_CRITERIO`
		where UPPER(TRIM(distribuir))!='S';


		UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_NO_DIST`
		SET	grid=case when coalesce(grid,0) >=0 Then 50 else -50 end
		WHERE TRUE;


	
	  --- PASO 1: IDENTIFICAR POBLACION DE EVENTOS SOBRE LOS QUE DISTRIBUIR EXTRAS

		--- PASO 1.1: IDENTIFICAR EVENTOS EXCLUIDOS DE REPARTO
		--- OUT 1.1: LOG_0504_AJUSTES_EVENTOS_EXCLUIDOS_DE_REPARTO     

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EVENTOS_EXCLUIDOS_DE_REPARTO` AS
		select distinct a.*,
		COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds) clientes_subcanal,
		COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds) clientes

		from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` a
		inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXTRAS_EXCLUSION_POR_DESC_MM` e
		on e.marca_Ds=a.marca_ds 
		and case when e.canal="X" or e.canal=a.canal_alta_ds then TRUE ELSE FALSE END
		and case when e.subcanal="X" or e.subcanal=a.subcanal_ds then TRUE ELSE FALSE END
		and case when e.marco_retributivo="X" or e.marco_retributivo=a.marco_retributivo_ds then TRUE ELSE FALSE END 
		and e.desc_mm=a.desc_mm 
		and a.categoria_servicio_ds = 'BANDA ANCHA' /*and a.marca_ds="EUSKALTEL"and contains_substr(a.desc_mm,'A - Servicio acceso BA') and contains_substr(a.clase_mm,'A - Servicio base')*/;      



		--- PASO 1.2: IDENTIFICAR EVENTOS INCLUIDOS EN REPARTO
		--- OUT 1.2: LOG_0504_AJUSTES_EVENTOS_INCLUIDOS_EN_REPARTO     

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EVENTOS_INCLUIDOS_EN_REPARTO` AS
		with ajTot as (
			SELECT *, 
			COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds, a.subcanal_ds) clientes_subcanal_tot,
			COUNT(*) OVER (PARTITION BY a.marca_ds, a.nombre_distribuidor_alta_ds, a.canal_alta_ds) clientes_tot

			FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` a
			WHERE categoria_servicio_ds = 'BANDA ANCHA'
			and contains_substr(desc_mm,'A - Servicio acceso BA') and contains_substr(clase_mm,'A - Servicio base')
			--and marca_ds="EUSKALTEL" and canal_Alta_ds="TASK FORCE"
		) 
		Select distinct ajTot.*,
		COUNT(*) OVER (PARTITION BY ajTot.marca_ds, ajTot.nombre_distribuidor_alta_ds, ajTot.canal_alta_ds, ajTot.subcanal_ds) clientes_subcanal,
		COUNT(*) OVER (PARTITION BY ajTot.marca_ds, ajTot.nombre_distribuidor_alta_ds, ajTot.canal_alta_ds) clientes
		from ajTot
		where not exists (
		  select 1 
		  from `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EVENTOS_EXCLUIDOS_DE_REPARTO`  as ajExc
		  where ajTot.marca_ds=ajExc.marca_ds and ajTot.cliente_id=ajExc.cliente_id and ajTot.servicio_id=ajExc.servicio_id
		)
		--and ajtot.marca_ds="EUSKALTEL" and ajtot.canal_Alta_ds="TASK FORCE"
		;



	  --- PASO 2: DESCUBRIR APUNTES COON DISTRIBUCION DE EXTRAS 
	  --- OUT 2:  LOG_0504_AJUSTES_EVENTOS_DEFINITIVOS_DIST   

		CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_DIST` AS
		with imp_extracom as (
		  ----- REGLA INCLUIR
		  select c.marca_ds, c.nombre_distribuidor_alta_ds, c.canal_alta_ds, c.subcanal_ds, p.importe, p.poruni, p.decomisionable, clase_mm, desc_mm, count(distinct c.servicio_id) as np, count(c.servicio_id) as npnd, 
		  CASE WHEN TRIM(UPPER(p.poruni))='N' THEN ROUND(p.importe/ count(distinct c.servicio_id),6) 
			   WHEN TRIM(UPPER(p.poruni))='Y' THEN p.importe
		  END as imp_extracom
		  from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`  c
		  --inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat on TRIM(UPPER(cat.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(cat.IdProdCat))=TRIM(UPPER(c.IdCatalogo))
		  inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXTRAS_DESARROLLO_NUEVO_CRITERIO` p on TRIM(UPPER(p.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(c.nombre_distribuidor_alta_ds))=TRIM(UPPER(p.nombre_distribuidor_ds))
		  and case when TRIM(UPPER(p.canal_Alta_ds))!='X' THEN  TRIM(UPPER(p.canal_alta_ds))= TRIM(UPPER(c.canal_alta_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.subcanal_ds))!='X' THEN  TRIM(UPPER(p.subcanal_ds))= TRIM(UPPER(c.subcanal_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.categoria_servicio_ds))!='X' THEN  TRIM(UPPER(p.categoria_servicio_ds))= TRIM(UPPER(c.categoria_servicio_ds)) ELSE 1=1 END
		  where UPPER(TRIM(p.tiporegla))='I'
		  and case when TRIM(c.categoria_servicio_ds) in ("BANDA ANCHA", "FIJA","MOVILES POSTPAGO" ) and contains_substr(c.clase_mm, "A -")  THEN TRUE 
				   when TRIM(c.categoria_servicio_ds) in ("TELEVISION") and contains_substr(c.desc_mm, "B - Television acceso")  THEN TRUE
				   when TRIM(c.categoria_servicio_ds) in ("TERMINALES") and contains_substr(c.clase_mm, "T - ")  THEN TRUE
				Else FALSE			
		  END
		  group by 1,2,3,4,5,6,7,8,9

		  UNION ALL
		  ----- REGLA EXCLUIR
		  select c.marca_ds, c.nombre_distribuidor_alta_ds, c.canal_alta_ds, c.subcanal_ds, p.importe, p.poruni, p.decomisionable, clase_mm, desc_mm, count(distinct c.servicio_id) as np, count(c.servicio_id) as npnd, 
		  CASE WHEN TRIM(UPPER(p.poruni))='N' THEN ROUND(p.importe/ count(distinct c.servicio_id),6) 
			   WHEN TRIM(UPPER(p.poruni))='Y' THEN p.importe
		  END as imp_extracom
		  from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`  c
		  --inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat on TRIM(UPPER(cat.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(cat.IdProdCat))=TRIM(UPPER(c.IdCatalogo))
		  inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXTRAS_DESARROLLO_NUEVO_CRITERIO` p on TRIM(UPPER(p.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(c.nombre_distribuidor_alta_ds))=TRIM(UPPER(p.nombre_distribuidor_ds))
		  and case when TRIM(UPPER(p.canal_Alta_ds))!='X' THEN  TRIM(UPPER(p.canal_alta_ds))= TRIM(UPPER(c.canal_alta_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.subcanal_ds))!='X' THEN  TRIM(UPPER(p.subcanal_ds))= TRIM(UPPER(c.subcanal_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.categoria_servicio_ds))!='X' THEN  TRIM(UPPER(p.categoria_servicio_ds))= TRIM(UPPER(c.categoria_servicio_ds)) ELSE 1=1 END
		  where UPPER(TRIM(p.tiporegla))='E'
		  and case when TRIM(c.categoria_servicio_ds) in ("BANDA ANCHA", "FIJA","MOVILES POSTPAGO" ) and contains_substr(c.clase_mm, "A -")  THEN TRUE 
				   when TRIM(c.categoria_servicio_ds) in ("TELEVISION") and contains_substr(c.desc_mm, "B - Television acceso")  THEN TRUE
				   when TRIM(c.categoria_servicio_ds) in ("TERMINALES") and contains_substr(c.clase_mm, "T - ")  THEN TRUE
				Else FALSE			
		  END
		  group by 1,2,3,4,5,6,7,8,9 

		), pob_extra_com as (

		  ----- REGLA INCLUIR
		  select distinct c.marca_ds, c.nombre_distribuidor_alta_ds, c.canal_alta_ds, c.subcanal_ds, c.Cliente_id, c.servicio_id, clase_mm, desc_mm
		  from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`  c
		  --inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat on TRIM(UPPER(cat.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(cat.IdProdCat))=TRIM(UPPER(c.IdCatalogo))
		  inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXTRAS_DESARROLLO_NUEVO_CRITERIO` p on TRIM(UPPER(p.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(c.nombre_distribuidor_alta_ds))=TRIM(UPPER(p.nombre_distribuidor_ds))
		  and case when TRIM(UPPER(p.canal_Alta_ds))!='X' THEN  TRIM(UPPER(p.canal_alta_ds))= TRIM(UPPER(c.canal_alta_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.subcanal_ds))!='X' THEN  TRIM(UPPER(p.subcanal_ds))= TRIM(UPPER(c.subcanal_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.categoria_servicio_ds))!='X' THEN  TRIM(UPPER(p.categoria_servicio_ds))= TRIM(UPPER(c.categoria_servicio_ds)) ELSE 1=1 END
		  where UPPER(TRIM(p.tiporegla))='I'
		  and case when TRIM(c.categoria_servicio_ds) in ("BANDA ANCHA", "FIJA","MOVILES POSTPAGO" ) and contains_substr(c.clase_mm, "A -")  THEN TRUE 
				   when TRIM(c.categoria_servicio_ds) in ("TELEVISION") and contains_substr(c.desc_mm, "B - Television acceso")  THEN TRUE
				   when TRIM(c.categoria_servicio_ds) in ("TERMINALES") and contains_substr(c.clase_mm, "T - ")  THEN TRUE
				Else FALSE			
		  END
		  
		  UNION ALL 
			
		  ----- REGLA EXCLUIR
		  select distinct c.marca_ds, c.nombre_distribuidor_alta_ds, c.canal_alta_ds, c.subcanal_ds, c.Cliente_id, c.servicio_id,clase_mm, desc_mm 
		  from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`  c
		  --inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat on TRIM(UPPER(cat.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(cat.IdProdCat))=TRIM(UPPER(c.IdCatalogo))
		  inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_EXTRAS_DESARROLLO_NUEVO_CRITERIO` p on TRIM(UPPER(p.marca_ds))=TRIM(UPPER(c.marca_ds)) and TRIM(UPPER(c.nombre_distribuidor_alta_ds))=TRIM(UPPER(p.nombre_distribuidor_ds))
		  and case when TRIM(UPPER(p.canal_Alta_ds))!='X' THEN  TRIM(UPPER(p.canal_alta_ds))= TRIM(UPPER(c.canal_alta_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.subcanal_ds))!='X' THEN  TRIM(UPPER(p.subcanal_ds))= TRIM(UPPER(c.subcanal_ds)) ELSE 1=1 END
		  and case when TRIM(UPPER(p.categoria_servicio_ds))!='X' THEN  TRIM(UPPER(p.categoria_servicio_ds))= TRIM(UPPER(c.categoria_servicio_ds)) ELSE 1=1 END
		  where UPPER(TRIM(p.tiporegla))='E'
		  and case when TRIM(c.categoria_servicio_ds) in ("BANDA ANCHA", "FIJA","MOVILES POSTPAGO" ) and contains_substr(c.clase_mm, "A -")  THEN TRUE 
				   when TRIM(c.categoria_servicio_ds) in ("TELEVISION") and contains_substr(c.desc_mm, "B - Television acceso")  THEN TRUE
				   when TRIM(c.categoria_servicio_ds) in ("TERMINALES") and contains_substr(c.clase_mm, "T - ")  THEN TRUE
				Else FALSE			
		  END
		  

		) select distinct c.*  except(importe, decomisionable), coalesce(i.imp_extracom,0) as importe, coalesce(i.decomisionable,'N') as decomisonable
		from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`  c
		inner join pob_extra_com p on p.marca_ds=c.marca_ds and p.canal_alta_ds=c.canal_alta_ds and p.subcanal_ds=c.subcanal_ds and p.nombre_distribuidor_alta_ds=c.nombre_distribuidor_alta_ds and p.cliente_id=c.cliente_id and p.servicio_id=c.servicio_id and p.clase_mm=c.clase_mm and p.desc_mm=c.desc_mm
		inner join imp_extracom i on i.marca_ds=p.marca_ds and  i.canal_alta_ds=c.canal_alta_ds and i.subcanal_ds=c.subcanal_ds and i.nombre_distribuidor_alta_ds=p.nombre_distribuidor_alta_ds  and p.clase_mm=c.clase_mm and p.desc_mm=c.desc_mm
		--where i.imp_extracom is not null  
		--and i.marca_ds='TELECABLE'
		--and i.decomisionable='N'
		--and p.idproducto=138391058
		--where p.idproducto=139370078    
		order by 1,4,5,6,7;



		UPDATE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_DIST`
		SET concepto_ds=CONCAT('Extra por concepto: ', CONCEPTO_DS),
		grid=case when grid >=0 Then 50 else -50 end,
		clase_mm='D - Extracomision',
		desc_mm='D - Extra'
		WHERE TRUE;
		

	  --- PASO 3: INSETAR NUEVO APUNTES DE DISTRIBUCION DE EXTRAS EN TABLA AJUSTES_EVENTOS_DEFINITIVOS

		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
		SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_NO_DIST`
		UNION ALL 
		SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_DIST`;



	  --- PASO 4: CREO TABLA DE LOG DE SALIDA DE PASO

		  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_AJUSTES_EVENTOS_DEFINITIVOS` AS
		  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`; 




END