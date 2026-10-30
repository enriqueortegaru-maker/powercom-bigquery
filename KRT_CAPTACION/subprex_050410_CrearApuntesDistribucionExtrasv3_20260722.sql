BEGIN

	 --- PASO 1: CREO TABLA EXTRAS NO DISTRIBUIDOS
	 -- OPTIMIZACIÓN: Combinamos CREATE + INSERT en un solo paso.
	 CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_NO_DIST` AS 
	 SELECT 
	 	 marca_ds, 
	 	 categoria_servicio_ds, 	 	
	 	 case when UPPER(TRIM(canal_alta_ds)) in ("PUNTO DE VENTA", "TASK_FORCE", "CANALES ALTERNATIVOS") THEN "PRESENCIAL" ELSE "NO PRESENCIAL" END AS tipo_canal_alta_ds,
	 	 canal_alta_ds, 
	 	 subcanal_ds, 
	 	 nombre_distribuidor_ds AS nombre_distribuidor_alta_ds, 
	 	 marco_retributivo_ds,
	 	 CONCAT('Extra por concepto: ', concepto) AS concepto_ds,
	 	 'D - Extracomision' AS clase_mm,
	 	 CASE 	WHEN UPPER(TRIM(distribuir))='I' THEN 'D - Inicio Actividad'
	 	 	 	 	 WHEN UPPER(TRIM(distribuir))='T' THEN 'D - Trimestral'
	 	 	 	 	 WHEN UPPER(TRIM(distribuir))='A' THEN 'D - Anual' 	 	 	 	 
	 	 	 	 	 WHEN UPPER(TRIM(distribuir))='F' THEN 'D - Fin Actividad'
	 	 	 	 	 ELSE 'D - Mensual'
	 	 END AS desc_mm, 	 	 	 	 	
	 	 importe,
	 	 orden_sap, 
	 	 decomisionable
	 FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRA`
	 WHERE UPPER(TRIM(distribuir)) != 'S'
	 and coalesce(importe,0)!=0;


	 --- PASO 2: CREO TABLA EXTRAS DISTRIBUIDOS
	 CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_DIST` AS 
	 WITH
	 	 -- Paso 2.1: Filtrar los eventos válidos y PRE-NORMALIZAR claves de join
	 	 EventosFiltrados AS (
	 	 	 SELECT 
	 	 	 	 *,
	 	 	 	 -- OPTIMIZACIÓN: Añadimos claves de join pre-normalizadas
	 	 	 	 TRIM(UPPER(marca_ds)) AS k_marca_ds,
	 	 	 	 TRIM(UPPER(nombre_distribuidor_alta_ds)) AS k_distribuidor_ds,
	 	 	 	 TRIM(UPPER(canal_alta_ds)) AS k_canal_ds,
	 	 	 	 TRIM(UPPER(subcanal_ds)) AS k_subcanal_ds,
	 	 	 	 TRIM(UPPER(categoria_servicio_ds)) AS k_categoria_ds,
	 	 	 	 TRIM(UPPER(marco_retributivo_ds)) AS k_marco_ds
	 	 	 FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
	 	 	 WHERE
	 	 	 	 CASE
	 	 	 	 	 WHEN TRIM(categoria_servicio_ds) IN ("BANDA ANCHA", "FIJA", "MOVILES POSTPAGO") AND CONTAINS_SUBSTR(clase_mm, "A -") THEN TRUE
	 	 	 	 	 WHEN TRIM(categoria_servicio_ds) IN ("TELEVISION") AND CONTAINS_SUBSTR(desc_mm, "B - Television acceso") THEN TRUE
	 	 	 	 	 WHEN TRIM(categoria_servicio_ds) IN ("TERMINALES") AND CONTAINS_SUBSTR(clase_mm, "T - ") THEN TRUE
	 	 	 	 	 ELSE FALSE
	 	 	 	 END
	 	 ),
	 	 
	 	 -- Paso 2.2: Preparar las reglas y PRE-NORMALIZAR claves de join/filtro
	 	 ReglasFiltradas AS (
	 	 	 SELECT 
	 	 	 	 *,
        		-- OPTIMIZACIÓN: ROW_NUMBER() determinista (usando nombres de columna)
	 	 	 	 ROW_NUMBER() OVER (ORDER BY marca_ds, nombre_distribuidor_ds, canal_alta_ds, subcanal_ds, categoria_servicio_ds, marco_retributivo_ds, concepto) AS id_regla,
	 	 	 	 
	 	 	 	 -- OPTIMIZACIÓN: Añadimos claves de join/filtro pre-normalizadas
	 	 	 	 TRIM(UPPER(marca_ds)) AS k_marca_ds,
	 	 	 	 TRIM(UPPER(nombre_distribuidor_ds)) AS k_distribuidor_ds,
	 	 	 	 -- Clave 'X' (comodín) o el valor normalizado
	 	 	 	 CASE WHEN TRIM(UPPER(canal_alta_ds)) = 'X' THEN 'X' ELSE TRIM(UPPER(canal_alta_ds)) END AS k_canal_ds,
	 	 	 	 CASE WHEN TRIM(UPPER(subcanal_ds)) = 'X' THEN 'X' ELSE TRIM(UPPER(subcanal_ds)) END AS k_subcanal_ds,
	 	 	 	 CASE WHEN TRIM(UPPER(categoria_servicio_ds)) = 'X' THEN 'X' ELSE TRIM(UPPER(categoria_servicio_ds)) END AS k_categoria_ds,
	 	 	 	 CASE WHEN TRIM(UPPER(marco_retributivo_ds)) = 'X' THEN 'X' ELSE TRIM(UPPER(marco_retributivo_ds)) END AS k_marco_ds,
	 	 	 	 -- Normalizar campos de filtro
	 	 	 	 UPPER(TRIM(tiporegla)) AS k_tiporegla,
	 	 	 	 UPPER(TRIM(distribuir)) AS k_distribuir,
        		 TRIM(UPPER(poruni)) AS k_poruni
	 	 	 FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRA`
	 	 	 WHERE COALESCE(importe, 0) != 0
	 	 ),

	 	 -- Paso 2.3: Unir eventos y reglas (Incluir)
	 	 EventosDistribuidosConReglaIncluir AS (
	 	 	 SELECT e.servicio_id, p.id_regla, p.importe, p.k_poruni, p.decomisionable
	 	 	 FROM EventosFiltrados AS e
	 	 	 JOIN ReglasFiltradas AS p
	 	 	 	 -- OPTIMIZACIÓN: Usamos las claves k_... para un join mucho más rápido
	 	 	 	 ON e.k_marca_ds = p.k_marca_ds
	 	 	 	 AND e.k_distribuidor_ds = p.k_distribuidor_ds
	 	 	 	 AND (e.k_canal_ds = p.k_canal_ds OR p.k_canal_ds = 'X')
	 	 	 	 AND (e.k_subcanal_ds = p.k_subcanal_ds OR p.k_subcanal_ds = 'X')
	 	 	 	 AND (e.k_categoria_ds = p.k_categoria_ds OR p.k_categoria_ds = 'X')
	 	 	 	 AND (e.k_marco_ds = p.k_marco_ds OR p.k_marco_ds = 'X')
	 	 	 -- OPTIMIZACIÓN: Usamos claves k_... para filtrar
	 	 	 where p.k_tiporegla = 'I'
	 	 	 	 and p.k_distribuir = 'S'
	 	 ),

	 	 -- Paso 2.3b: Unir eventos y reglas (Excluir)
	 	 EventosDistribuidosConReglaExcluir AS (
	 	 	 SELECT e.servicio_id, p.id_regla, p.importe, p.k_poruni, p.decomisionable
	 	 	 FROM EventosFiltrados AS e
	 	 	 JOIN ReglasFiltradas AS p
	 	 	 	 -- CORRECCIÓN: La lógica de join aquí era inconsistente/incorrecta en el original.
	 	 	 	 -- Se asume que debe ser idéntica a 'Incluir'.
	 	 	 	 ON e.k_marca_ds = p.k_marca_ds
	 	 	 	 AND e.k_distribuidor_ds = p.k_distribuidor_ds
	 	 	 	 AND (e.k_canal_ds = p.k_canal_ds OR p.k_canal_ds = 'X')
	 	 	 	 AND (e.k_subcanal_ds = p.k_subcanal_ds OR p.k_subcanal_ds = 'X')
	 	 	 	 AND (e.k_categoria_ds = p.k_categoria_ds OR p.k_categoria_ds = 'X')
	 	 	 	 AND (e.k_marco_ds = p.k_marco_ds OR p.k_marco_ds = 'X')
	 	 	 where p.k_tiporegla = 'E' -- Filtro por Excluir
	 	 	 	 and p.k_distribuir = 'S'
	 	 ),

	 	 -- Paso 2.4: Calcular incentivos (Incluir)
	 	 IncentivosDistribuidosPorReglaIncluir AS (
	 	 	 SELECT servicio_id, id_regla, decomisionable,
	 	 	 	 CASE
	 	 	 	 	 WHEN k_poruni = 'S' THEN importe
	 	 	 	 	 WHEN k_poruni = 'N' THEN importe / COUNT(*) OVER (PARTITION BY id_regla, decomisionable)
	 	 	 	 	 ELSE 0
	 	 	 	 END AS incentivo_calculado
	 	 	 FROM EventosDistribuidosConReglaIncluir
	 	 ),

	 	 -- Paso 2.4b: Calcular incentivos (Excluir)
	 	 IncentivosDistribuidosPorReglaExcluir AS (
	 	 	 SELECT servicio_id, id_regla, decomisionable,
	 	 	 	 CASE
	 	 	 	 	 WHEN k_poruni = 'S' THEN importe -- Se asume que el importe en PARAM_EXTRA es negativo para exclusiones
	 	 	 	 	 WHEN k_poruni = 'N' THEN importe / COUNT(*) OVER (PARTITION BY id_regla, decomisionable)
	 	 	 	 	 ELSE 0
	 	 	 	 END AS incentivo_calculado
	 	 	 FROM EventosDistribuidosConReglaExcluir
	 	 ),

	 	 -- Paso 2.5: Sumar TODOS los incentivos (Inclusión y Exclusión) para cada evento
	 	 IncentivosAgregados AS (
	 	 	 -- CORRECCIÓN LÓGICA: Se añade una agrupación externa para sumar (netear) correctamente
      -- los importes de 'Incluir' y 'Excluir'.
	 	 	 SELECT 
	 	 	 	 servicio_id, 
	 	 	 	 decomisionable, 
	 	 	 	 SUM(incentivo_total_parcial) AS incentivo_total
	 	 	 FROM (
	 	 	 	 	 -- Suma de todas las reglas de Inclusión
	 	 	 	 	 SELECT servicio_id, decomisionable, SUM(incentivo_calculado) AS incentivo_total_parcial
	 	 	 	 	 FROM IncentivosDistribuidosPorReglaIncluir
	 	 	 	 	 GROUP BY servicio_id, decomisionable
	 	 	 	 	 
	 	 	 	 	 UNION ALL
	 	 	 	 	 
	 	 	 	 	 -- Suma de todas las reglas de Exclusión
	 	 	 	 	 SELECT servicio_id, decomisionable, SUM(incentivo_calculado) AS incentivo_total_parcial
	 	 	 	 	 -- CORRECCIÓN DE BUG: El UNION ALL original apuntaba a 'Incluir' dos veces.
	 	 	 	 	 FROM IncentivosDistribuidosPorReglaExcluir 
	 	 	 	 	 GROUP BY servicio_id, decomisionable
	 	 	 )
	 	 	 GROUP BY servicio_id, decomisionable
	 	 ),

	 	 -- Paso 2.6: Unir los resultados con la tabla de eventos YA FILTRADA
	 	 ResultadosFinales AS (
				--- Calculo resultado final
				with p as (					
					SELECT 
						e.* EXCEPT (importe, decomisionable, k_marca_ds, k_distribuidor_ds, k_canal_ds, k_subcanal_ds, k_categoria_ds, k_marco_ds), 
						agregados.incentivo_total AS importe, 
						agregados.decomisionable
					FROM EventosFiltrados AS e
					INNER JOIN IncentivosAgregados AS agregados
						ON e.servicio_id = agregados.servicio_id
						-- Opcional: Si 'decomisionable' puede variar, añadirlo al join
						-- AND e.decomisionable = agregados.decomisionable
				) 
				-- Reemplazo clase_mm y desc_mm 
				select * REPLACE ('D - Extracomision' AS clase_mm, 'D - Extra' AS desc_mm)
				from p
	 	 )

	 SELECT *
	 FROM ResultadosFinales
	 WHERE importe != 0; -- Se cambia a != 0 para incluir importes negativos si los hubiera


	 --- PASO 3: INSERTAR NUEVOS APUNTES DE DISTRIBUCION DE EXTRAS EN TABLA AJUSTES_EVENTOS_DEFINITIVOS
	 -- Esta lógica se mantiene, asumiendo que las tablas LOG son necesarias para auditoría.
	 INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` (marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, marco_retributivo_ds, concepto_ds, clase_mm, desc_mm, importe, orden_sap, decomisionable)
	 SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_NO_DIST`;


	 INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`
	 SELECT * FROM 	`mm-commissions-reporting.KRT_CAPTACION.LOG_050410_EXTRAS_CALCULADOS_DIST`;


	 --- PASO 4: CREO TABLA DE LOG DE SALIDA DE PASO
	 -- Se mantiene el paso final de snapshot.
	 CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_050410_AJUSTES_EVENTOS_DEFINITIVOS` AS
	 SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS`; 


END