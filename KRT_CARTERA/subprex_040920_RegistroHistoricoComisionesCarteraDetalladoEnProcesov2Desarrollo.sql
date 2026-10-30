BEGIN
    
    -- =========================================================================================
    -- PASO 1: CREAR TABLA DE COMISIONES EN PROCESO (ENFOQUE SET-BASED SIN UDFs)
    -- =========================================================================================
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO_EN_PROCESO` AS 
    
    -- 1.1 CTEs DE MAPEO SEGURO (Reemplazan a las funciones f_canal_descubre...)
    
    -- Mapeo Siebel: Protegido contra múltiples equipos para un mismo agente
    WITH MAPEO_SIEBEL AS (
        SELECT 
            CAST(agente_venta_id AS STRING) AS agente_venta_id_str, 
            equipo_ds
        FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal`
        -- PROTECCIÓN: Si hay duplicados, nos quedamos con el primero por orden alfabético
        QUALIFY ROW_NUMBER() OVER(PARTITION BY CAST(agente_venta_id AS STRING) ORDER BY equipo_ds ASC) = 1
    ),
    
    -- Mapeo Ektnet: Protegido contra múltiples canales/productos para un mismo servicio_id
    MAPEO_EKTNET AS (
        SELECT 
            p.swInstProdId AS servicio_id,
            p.swChnlPartnerId,  
            c.swCoInterno,  
            c.swVerticalFocus, 
            p.swProviderGrpId, 
            COALESCE(v.swNombre, '') AS nombre_personal,
            p.swCreatedBy
        FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p  
        LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c 
            ON c.swChnlPartnerId = p.swChnlPartnerId
        LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` v  
            ON v.swPersonalId = p.swProviderGrpId AND v.swObjectType = 'CHANNEL_PARTNER'
        -- PROTECCIÓN: Un único registro por servicio_id (idProducto)
        QUALIFY ROW_NUMBER() OVER(PARTITION BY p.swInstProdId ORDER BY p.swChnlPartnerId DESC) = 1
    )
    
    -- (Aquí añadirías las CTEs para MAPEO_TC_NET, MAPEO_ELECTRICIDAD_EUSKALTEL, etc.)

    -- 1.2 CONSULTA PRINCIPAL (Reemplaza a f_vt_comisiones_detallado_en_proceso)
    SELECT 
        f.*,
        
        -- Construcción del Struct 'canalizacion' basado en los JOINs seguros
        CASE 
            -- LÓGICA NO ENERGÍA
            WHEN NOT CONTAINS_SUBSTR(f.claseProducto, "ENERGIA") THEN
                CASE 
                    -- Caso EKTNET
                    WHEN f.marca_ds IN ("EUSKALTEL","RACC","VIRGIN","SIMPLE") OR 
                         (CONTAINS_SUBSTR(f.marca_ds, "TELECABLE") AND 
                         (CONTAINS_SUBSTR(f.TipoProducto, "MOVIL") OR CONTAINS_SUBSTR(f.TipoProducto, "TERMINAL") OR CONTAINS_SUBSTR(f.TipoProducto, "DISPOSITIVO") OR CONTAINS_SUBSTR(f.TipoProducto, "SEGURO") OR CONTAINS_SUBSTR(f.TipoProducto, "SEGURIDAD") OR CONTAINS_SUBSTR(f.NombreProducto, 'HEGAN-COMBI'))) 
                    THEN 
                        STRUCT(
                            ekt.swChnlPartnerId AS equipoId,
                            ekt.swCoInterno AS equipo,
                            ekt.swVerticalFocus AS equipoDesc,
                            ekt.swProviderGrpId AS agenteId,
                            ekt.nombre_personal AS agente,
                            '' AS agenteComercial,
                            CAST(NULL AS INT64) AS loginId,
                            ekt.swCreatedBy AS login
                        )

                    -- Caso SIEBEL (R)
                    WHEN CONTAINS_SUBSTR(f.marca_ds, "R") THEN 
                        STRUCT(
                            CAST(NULL AS INT64) AS equipoId,  
                            sbl.equipo_ds AS equipo,  
                            sbl.equipo_ds AS equipoDesc,
                            CAST(f.agente AS INT64) AS agenteId, 
                            f.agente AS agente, 
                            '' AS agenteComercial, 
                            CAST(NULL AS INT64) AS loginId, 
                            f.usuarioCreador AS login
                        )
                        
                    -- (Aquí iría el CASE WHEN para TC_NET)
                    ELSE NULL
                END
                
            -- LÓGICA ENERGÍA (Aquí usarías las CTEs de electricidad/gas)
            WHEN CONTAINS_SUBSTR(f.claseProducto, "ENERGIA") THEN 
                -- (Aquí iría la lógica estructurada para Energía)
                NULL
                
        END AS canalizacion

    FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` f
    
    -- JOINs con las tablas de mapeo seguras
    LEFT JOIN MAPEO_SIEBEL sbl 
        ON sbl.agente_venta_id_str = TRIM(f.agente)
    LEFT JOIN MAPEO_EKTNET ekt 
        ON ekt.servicio_id = f.idProducto
        
    WHERE f.mes_factura_dt = DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING)), MONTH);


    -- =========================================================================================
    -- PASO 2: CREAR TABLA DE DECOMISIONES EN PROCESO 
    -- (Nota: Deberías aplicar la misma lógica a f_vt_decomisiones_detallado_en_proceso)
    -- =========================================================================================
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO_EN_PROCESO` AS 
    SELECT *
    FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_decomisiones_detallado_en_proceso`(vdesde, vhasta);


    -- =========================================================================================
    -- PASO 3: ACTUALIZO TABLAS HISTÓRICAS FINALES
    -- =========================================================================================
    
    -- Inserción Comisiones
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO` 
    WHERE mes_factura_dt = PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));
        
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO`  
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO_EN_PROCESO`;

    -- Inserción Decomisiones
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO` 
    WHERE mes_factura_dt = PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));
    
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO`  
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO_EN_PROCESO`;

END