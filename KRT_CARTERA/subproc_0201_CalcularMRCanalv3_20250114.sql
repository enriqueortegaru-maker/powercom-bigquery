BEGIN


	---- PROVISIONALMENTE SE ELIMINA CAMPO EQUIPO A SALIDA

  --========================================================================================
  -- CTE 1: EVENTOS CON LA MEJOR REGLA ASIGNADA
  --========================================================================================

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0201_EVENTOSxMR` AS

	--- subcanal
	--- equipo
	--- agente

	SELECT
		distinct e.*,
		p.clave as clave_mr,
	--    p.pv2,
		-- Clave para particionar
		ROW_NUMBER() OVER (
		  PARTITION BY e.marca_ds, e.canal, e.subcanal, e.nombre_distribuidor, e.equipo, e.agente, e.idFijo, e.idProducto 
		  ORDER BY 
			-- Número de campos de parametrización con valor 'X'      
			(CASE WHEN p.subcanal = 'X' THEN 1 ELSE 0 END +
			 CASE WHEN p.equipo = 'X' THEN 1 ELSE 0 END +
			 CASE WHEN UPPER(TRIM(p.agente)) = 'X' THEN 1 ELSE 0 END) ASC,
			-- Sumatorio de índices de relaciones con valor 'X'
			(CASE WHEN p.subcanal = 'X' THEN 1 ELSE 0 END +
			 CASE WHEN p.equipo = 'X' THEN 2 ELSE 0 END +
			 CASE WHEN UPPER(TRIM(p.agente)) = 'X' THEN 3 ELSE 0 END) ASC
		) AS rn

	  FROM
		--`mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_DES` e
		`mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
	  LEFT JOIN
		`mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` p	  
	  ON
		p.marca_ds=UPPER(TRIM(e.marca_ds)) AND
		p.canal=UPPER(TRIM(e.canal)) AND
		(p.subcanal=UPPER(TRIM(e.subcanal)) or UPPER(TRIM(p.subcanal))='X' )AND
		p.nombre_distribuidor=UPPER(TRIM(e.nombre_distribuidor)) AND   
		(p.equipo = UPPER(TRIM(e.equipo)) OR UPPER(TRIM(p.equipo)) = 'X') AND
		(UPPER(TRIM(p.agente)) = UPPER(TRIM(e.agente)) OR UPPER(TRIM(p.agente)) = 'X') 

		--- Contabilidad de eventos descubiertos es superior a eventos que se obtienen en la salida de este paso, por condición QUALIRY RN=1 diferencia de unos 1K	eventos
		-- analizar casos en los que varios origenes se asignan a un unico destino
		-- where idPRoducto= 60122407886
		-- where idPRoducto= 79315236
    -- where idPRoducto= 38941861				

		QUALIFY ROW_NUMBER() OVER (
		  PARTITION BY e.marca_ds, e.canal, e.subcanal, e.nombre_distribuidor, e.equipo, e.agente, e.idFijo, e.idProducto 
		  ORDER BY 
			-- Número de campos de parametrización con valor 'X'      
			(CASE WHEN p.subcanal = 'X' THEN 1 ELSE 0 END +
			 CASE WHEN p.equipo = 'X' THEN 1 ELSE 0 END +
			 CASE WHEN UPPER(TRIM(p.agente)) = 'X' THEN 1 ELSE 0 END) ASC,
			-- Sumatorio de índices de relaciones con valor 'X'
			(CASE WHEN p.subcanal = 'X' THEN 1 ELSE 0 END +
			 CASE WHEN p.equipo = 'X' THEN 2 ELSE 0 END +
			 CASE WHEN UPPER(TRIM(p.agente)) = 'X' THEN 3 ELSE 0 END) ASC
		)=1 
	   order by marca_ds, idFijo, idProducto;
			
		---- Se eliminan eventos con NR>1


	/*
	Listado de distribuidores con ventas en distintos equipos en un mismo canal de ventas
	select distinct marca_ds, canal, subcanal, nombre_distribuidor,equipo 
	from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_DES`
	where canal!="PUNTO DE VENTA"
	QUALIFY count(distinct equipo) over(partition by marca_ds, canal, subcanal, nombre_distribuidor) >1
	order by 1,2,3,4;

	*/


  --========================================================================================
  -- CTE 2: Se asigna MR a los eventos de canales que no son televentas 
  --========================================================================================

	CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS
	SELECT ev.*
--	except(equipo,rn),
	except(rn),  
	mr.agrupador_mr MARCO_RETRIBUTIVO,  mr.tvt_ups_virgin,  mr.televenta
	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0201_EVENTOSxMR` ev
	LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr ON ev.clave_mr = mr.clave
	WHERE (    ( ev.CANAL <> 'PUNTO DE VENTA' AND (UPPER(ev.agente) <> 'BEN PDV PARQUE PRINCIPADO' OR ev.agente IS NULL ))
			    OR ((ev.CANAL =  'PUNTO DE VENTA'  OR (UPPER(ev.agente) =  'BEN PDV PARQUE PRINCIPADO'	)) AND UPPER(TRIM(ev.Marca_Cartera)) = 'CARTERA')
		    )
	AND CASE WHEN (UPPER(TRIM(coalesce(mr.marca_cartera,'NOINF')))='S' AND UPPER(TRIM(coalesce(ev.Marca_Cartera,"NOINF")))="CARTERA") or (UPPER(TRIM(coalesce(mr.marca_cartera,"NOINF")))='N') THEN TRUE ELSE FALSE END
	AND (UPPER(TRIM(mr.TELEVENTA))='N' OR mr.televenta IS NULL)		  
	AND UPPER(TRIM(tvt_ups_virgin)) <> 'S';



	CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL_EXCLUIDO` AS
	SELECT ev.*
--	except(equipo,rn),
	except(rn),  
	mr.agrupador_mr MARCO_RETRIBUTIVO,  mr.tvt_ups_virgin,  mr.televenta
	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0201_EVENTOSxMR` ev
	LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr ON ev.clave_mr = mr.clave
	WHERE (    ( ev.CANAL <> 'PUNTO DE VENTA' AND (UPPER(ev.agente) <> 'BEN PDV PARQUE PRINCIPADO' OR ev.agente IS NULL ))
			    OR ((ev.CANAL =  'PUNTO DE VENTA'  OR (UPPER(ev.agente) =  'BEN PDV PARQUE PRINCIPADO'	)) AND UPPER(TRIM(ev.Marca_Cartera)) = 'CARTERA')
		    )
	AND CASE WHEN (UPPER(TRIM(mr.marca_cartera))='S' AND UPPER(TRIM(coalesce(ev.Marca_Cartera,"NOINF")))!="CARTERA") THEN TRUE ELSE FALSE END			
	AND (UPPER(TRIM(mr.TELEVENTA))='N' OR mr.televenta IS NULL)		  
	AND UPPER(TRIM(tvt_ups_virgin)) <> 'S';



  --=========================================================================================
  -- CTE 3: Se asigna MR a los eventos de canales de televentas
  --========================================================================================


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS
	SELECT ev.* 
--	except(equipo, clave_mr, rn),
	except(clave_mr, rn),
	ev.clave_mr, 
	mr.agrupador_mr MARCO_RETRIBUTIVO,  mr.tvt_ups_virgin,  mr.televenta, nivel_tvt_ups_virgin
	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0201_EVENTOSxMR` ev
	LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr
	ON ev.clave_mr = mr.clave
	WHERE (mr.TELEVENTA='S' OR mr.tvt_ups_virgin = 'S');
--	AND CASE WHEN (UPPER(TRIM(mr.marca_cartera))='S' AND UPPER(TRIM(coalesce(ev.Marca_Cartera,"NOINF")))!="CARTERA") THEN TRUE ELSE FALSE END;




	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL_EXCLUIDO` AS
	SELECT ev.* 
--	except(equipo, clave_mr, rn),
	except(clave_mr, rn),
	ev.clave_mr, 
	mr.agrupador_mr MARCO_RETRIBUTIVO,  mr.tvt_ups_virgin,  mr.televenta, nivel_tvt_ups_virgin
	FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0201_EVENTOSxMR` ev
	LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr
	ON ev.clave_mr = mr.clave
	WHERE (mr.TELEVENTA='S' OR mr.tvt_ups_virgin = 'S')
	AND CASE WHEN (UPPER(TRIM(mr.marca_cartera))='S' AND UPPER(TRIM(coalesce(ev.Marca_Cartera,"NOINF")))!="CARTERA") THEN TRUE ELSE FALSE END;



  --========================================================================================
  -- CTE 4: Se filtran eventos a los que se aplica MR Fidelizacion generalista 
  --========================================================================================


	CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` AS
	SELECT *
	FROM 	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`  
	--WHERE contains_substr(marco_retributivo, 'fideliza') and contains_substr(marco_retributivo, 'generalis');
	WHERE equipo in (
		'INGECI',
		--'INWHCI',
		'INGEAT',
		'INGEUN',
		'IBE48FID05000',
		'LND48FID05000',
		'IBE48WB-02000'		
		
	);




  --========================================================================================
  -- CTE 5: Se eliminan de filtran eventos a los que se aplica MR Fidelizacion generalista 
  --========================================================================================

	CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS
	SELECT *
	FROM 	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`  
	--WHERE not contains_substr(marco_retributivo, 'fideliza') and not contains_substr(marco_retributivo, 'generalis');
	WHERE equipo not in(
		'INGECI',
		--'INWHCI',
		'INGEAT',
		'INGEUN',
		'IBE48FID05000',
		'LND48FID05000',
		'IBE48WB-02000'		
	);




  --========================================================================================
  -- CTE 6: Se vuelca log de MR de eventos de canales que no son de televentas
  --========================================================================================

	--- PASO 2: Creo LOG
	CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TIENDASxCANAL`  AS
	SELECT * 
	FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`;



  --========================================================================================
  -- CTE 7: Se vuelca log de MR de eventos de canales de televentas
  --========================================================================================

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;      


  --========================================================================================
  -- CTE 8: Se vuelca log de MR Fidelizacion Generalista
  --========================================================================================

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;      


END