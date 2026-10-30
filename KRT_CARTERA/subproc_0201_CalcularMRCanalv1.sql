BEGIN

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0201_EVENTOSxMR` AS
		SELECT c.*,
		--combinacion mdcsa	11111	
		CASE  WHEN ( SELECT COUNT(*)FROM  `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
					WHERE TRIM(UPPER(mr2.marca_ds)) = TRIM(UPPER(c.marca_ds)) AND TRIM(UPPER(mr2.nombre_distribuidor)) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = TRIM(UPPER(c.subcanal)) AND TRIM(UPPER(mr2.agente)) = TRIM(UPPER(c.agente)) 
		) = 1 
		THEN ( SELECT clave FROM 	`mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 		  
					 WHERE TRIM(UPPER(mr2.marca_ds))= TRIM(UPPER(c.marca_ds)) AND UPPER(mr2.nombre_distribuidor) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = TRIM(UPPER(c.subcanal)) AND UPPER(mr2.agente) = TRIM(UPPER(c.agente)) 
		)
		ELSE
			--combinacion mdcsa	1111x	
			CASE WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
									WHERE TRIM(UPPER(mr2.marca_ds))= TRIM(UPPER(c.marca_ds)) AND UPPER(mr2.nombre_distribuidor) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = TRIM(UPPER(c.subcanal)) AND UPPER(mr2.agente) = 'X' 
			) = 1 
			THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
						 WHERE TRIM(UPPER(mr2.marca_ds))= TRIM(UPPER(c.marca_ds)) AND UPPER(mr2.nombre_distribuidor) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = TRIM(UPPER(c.subcanal)) AND UPPER(mr2.agente) = 'X' )
			ELSE
				--combinacion mdcsa	1111x	
				CASE WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
										WHERE TRIM(UPPER(mr2.marca_ds))= TRIM(UPPER(c.marca_ds)) AND UPPER(mr2.nombre_distribuidor) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = TRIM(UPPER(c.subcanal)) AND UPPER(mr2.agente) = 'X' 
				) = 1 
				THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
							 WHERE TRIM(UPPER(mr2.marca_ds))= TRIM(UPPER(c.marca_ds)) AND UPPER(mr2.nombre_distribuidor) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = TRIM(UPPER(c.subcanal)) AND UPPER(mr2.agente) = 'X' )
				ELSE
					--combinacion mdcsa	111xx	
					CASE WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
											WHERE TRIM(UPPER(mr2.marca_ds))= TRIM(UPPER(c.marca_ds)) AND UPPER(mr2.nombre_distribuidor) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = 'X' AND UPPER(mr2.agente) = 'X' 
					) = 1 
					THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
								 WHERE TRIM(UPPER(mr2.marca_ds))= TRIM(UPPER(c.marca_ds)) AND UPPER(mr2.nombre_distribuidor) = TRIM(UPPER(c.nombre_distribuidor)) AND TRIM(UPPER(mr2.canal)) = TRIM(UPPER(c.canal)) AND TRIM(UPPER(mr2.subcanal)) = 'X' AND UPPER(mr2.agente) = 'X' )
					ELSE	(	SELECT(-1))
						END
					END
				END
		END	clave_mr
		FROM	`mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` C;


		CREATE OR REPLACE TABLE	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS
		SELECT ev.*,  mr.agrupador_mr MARCO_RETRIBUTIVO,  mr.tvt_ups_virgin,  mr.televenta
		FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0201_EVENTOSxMR` ev
		LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr ON ev.clave_mr = mr.clave
		WHERE (     (TRIM(UPPER(ev.CANAL)) <> 'PUNTO DE VENTA' AND (TRIM(UPPER(ev.agente)) <> 'BEN PDV PARQUE PRINCIPADO'OR ev.agente IS NULL ))
						OR ((TRIM(UPPER(ev.agente)) = 'BEN PDV PARQUE PRINCIPADO'	OR TRIM(UPPER(ev.CANAL)) = 'PUNTO DE VENTA') AND UPPER(TRIM(ev.Marca_Cartera)) = 'CARTERA')
					)
		AND (TRIM(UPPER(mr.TELEVENTA))='N' OR mr.televenta IS NULL)		  
		AND TRIM(UPPER(tvt_ups_virgin)) <> 'S';


		--- PASO 2: Creo LOG
		CREATE OR REPLACE TABLE
			`mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TIENDASxCANAL`  AS
		SELECT
			*
		FROM
			`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`;





		





END