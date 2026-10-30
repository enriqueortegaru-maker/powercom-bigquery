BEGIN
    
    -- 1. DECLARACIÓN Y ASIGNACIÓN DE VARIABLES
    DECLARE VOPERATION ARRAY<STRING>;
    DECLARE VMES_FACTURA_DT DATE;
		--- LOCAL
		--DECLARE VTIPO STRING;	DECLARE VDESDE INT64; SET VTIPO="CARTERA"; SET VDESDE=20260101;
		--- FIN LOCAL
    SET VMES_FACTURA_DT = DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING)), MONTH);
    
    IF UPPER(TRIM(VTIPO)) = "CAPTACION" THEN 
        SET VOPERATION = ["ALTA", "BAJA"]; 
    ELSEIF UPPER(TRIM(VTIPO)) = "CARTERA" THEN 
        SET VOPERATION = ["ALTA", "BAJA", "CAMBIO"];
    END IF;

    ----------------------------------------------------------------------------
    -- 2. PREPARACIÓN DE PARÁMETROS (Temp Table)
    --    Aquí hacemos el SPLIT y la limpieza de texto UNA SOLA VEZ.
    ----------------------------------------------------------------------------
    CREATE OR REPLACE TEMP TABLE tmp_params_sap AS
    SELECT DISTINCT
        UPPER(TRIM(p.tipo)) AS tipo,
        UPPER(TRIM(p.marca)) AS marca,
        UPPER(TRIM(canal_split)) AS canal,
        UPPER(TRIM(srv_split)) AS service_type,
        UPPER(TRIM(seg_split)) AS segmento,
        UPPER(TRIM(marc_split)) AS marco,
        UPPER(TRIM(op_split)) AS operacion,
        p.orden_previa AS orden_antigua,
        p.orden AS orden_nueva
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ORDENxCANAL` p
    CROSS JOIN UNNEST(SPLIT(p.canal)) canal_split
    CROSS JOIN UNNEST(SPLIT(p.service_type)) srv_split
    CROSS JOIN UNNEST(SPLIT(p.segmento)) seg_split
    CROSS JOIN UNNEST(SPLIT(p.marco)) marc_split
    CROSS JOIN UNNEST(SPLIT(p.operacion)) op_split
    WHERE p.tipo = VTIPO
      AND p.ESTADO = "PUBLICAR"
      -- Filtramos las operaciones aquí para reducir el tamaño de la tabla temporal
      AND UPPER(TRIM(op_split)) IN UNNEST(VOPERATION)
    
    -- [OPTIMIZACIÓN DE SEGURIDAD]: Deduplicación lógica
    -- Si existe una regla específica y una regla con marco="X", priorizamos la específica
    -- para evitar el error "matches at most one source row".
    QUALIFY ROW_NUMBER() OVER(
        PARTITION BY 
            UPPER(TRIM(p.tipo)), 
            UPPER(TRIM(p.marca)), 
            UPPER(TRIM(canal_split)), 
            UPPER(TRIM(srv_split)), 
            UPPER(TRIM(seg_split)), 
            UPPER(TRIM(op_split)),
            p.orden_previa
        ORDER BY 
            CASE WHEN UPPER(TRIM(marc_split)) != 'X' THEN 1 ELSE 0 END DESC
    ) = 1;

    ----------------------------------------------------------------------------
    -- 3. UPDATE DIRECTO
    --    Cruzamos la tabla target directamente con la temporal ya limpia.
    ----------------------------------------------------------------------------
    UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
    SET t.orden = p.orden_nueva
    FROM tmp_params_sap p
    WHERE t.mes_factura_dt = VMES_FACTURA_DT
      AND t.tipo = VTIPO -- Coincide con p.tipo por filtro previo, pero mantenemos para particionado
      
      -- Cruce por dimensiones (con limpieza en 't' si es necesaria)
      AND UPPER(TRIM(t.marca)) = p.marca
      AND UPPER(TRIM(t.canal_gekt)) = p.canal
      AND UPPER(TRIM(t.service_type)) = p.service_type
      AND UPPER(TRIM(t.segmento)) = p.segmento
      AND UPPER(TRIM(t.operation)) = p.operacion
      
      -- Lógica del comodín 'X' en Marco Retributivo
      AND (p.marco = 'X' OR UPPER(TRIM(t.marco)) = p.marco)
      
      -- Condición Clave: Solo actualizamos si la orden coincide con la "previa" configurada
      AND t.orden = p.orden_antigua
      
      -- Evitar re-escritura si ya tiene el valor nuevo
      AND t.orden != p.orden_nueva
      
      -- Filtros de negocio adicionales
      AND NOT CONTAINS_SUBSTR(t.concepto_ds_gekt, "POSTVENTA");

    -- Limpieza (Opcional, BigQuery lo hace solo al acabar, pero es buena práctica)
    DROP TABLE IF EXISTS tmp_params_sap;

END