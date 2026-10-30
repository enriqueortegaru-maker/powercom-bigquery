BEGIN

		--- PASO 1: VUELCO DATOS A TABLA MARCO_RETRIBUTIVO_TIENDASxCANAL	
		CREATE OR REPLACE TABLE
		`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` AS
		SELECT
		  a.*,
		  mr.agrupador_mr MARCO_RETRIBUTIVO,
		  tvt_ups_virgin,
		  televenta
		FROM (
		  SELECT
		    c.*,
		    CASE
		      WHEN ( SELECT COUNT(*) 
		                FROM 
		                  `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
		                WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = UPPER(c.agente) 
		      ) = 1 
		        THEN ( SELECT clave 
		                     FROM 
		                        `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 
		                       WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = UPPER(c.agente) 
		              )
		                ELSE
		                CASE
		                  WHEN ( SELECT COUNT(*) 
		                            FROM 
		                              `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' ) = 1 THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' )
		                ELSE
		                CASE
		                  WHEN ( SELECT COUNT(*) 
		                            FROM 
		                                `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' ) = 1 THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' )
		                ELSE
		                CASE
		                  WHEN ( SELECT COUNT(*) 
		                            FROM 
		                                `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = 'X' AND UPPER(mr2.agente) = 'X' ) = 1 THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = 'X' AND UPPER(mr2.agente) = 'X' )
		                ELSE
		                (
		                SELECT
		                  (-1))
		  END
		  END
		  END
		  END
		    clave_mr
		  FROM
		    `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` C
		  WHERE
		    (C.CANAL <> 'PUNTO DE VENTA'
		      AND (UPPER(C.agente) <> 'BEN PDV PARQUE PRINCIPADO'
		        OR c.agente IS NULL ))
		    OR ((UPPER(C.agente) = 'BEN PDV PARQUE PRINCIPADO'
		        OR C.CANAL = 'PUNTO DE VENTA')
		      AND Marca_Cartera = 'CARTERA') ) a
		LEFT JOIN
		  `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr
		ON
		  a.clave_mr = mr.clave
		WHERE
		  (TELEVENTA='N'
		    OR televenta IS NULL)
		  AND tvt_ups_virgin <> 'S';


		--- PASO 2: Creo LOG
		CREATE OR REPLACE TABLE
			`mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TIENDASxCANAL`  AS
		SELECT
			*
		FROM
			`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL`;

  END