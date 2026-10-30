BEGIN
    
    -- 1. DECLARACIÓN Y ASIGNACIÓN DE VARIABLES
    DECLARE VOPERATION ARRAY<STRING>;
    DECLARE VMES_FACTURA_DT DATE;
    DECLARE tipos_a_procesar ARRAY<STRING>;
    DECLARE tipo_evaluado STRING;

    SET VMES_FACTURA_DT = DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING)), MONTH);
    
    -- Lógica para evaluar el parámetro de entrada y decidir qué procesar
    IF vtipo IS NULL OR UPPER(TRIM(vtipo)) IN ('TODOS', 'TODAS', 'TOTAL') THEN 
        SET tipos_a_procesar = ['CAPTACION', 'CARTERA'];
    ELSE 
        -- Si viene un tipo específico ('CAPTACION', 'CARTERA' u otro), lo metemos como único elemento
        SET tipos_a_procesar = [UPPER(TRIM(vtipo))];
    END IF;

    -- BUCLE FOR: Ejecuta la lógica tantas veces como elementos haya en 'tipos_a_procesar'
    FOR iterador IN (SELECT tipo FROM UNNEST(tipos_a_procesar) AS tipo)
    DO
        SET tipo_evaluado = iterador.tipo;

        -- Configurar VOPERATION para la iteración actual
        IF tipo_evaluado = 'CAPTACION' THEN 
            SET VOPERATION = ['ALTA', 'BAJA']; 
        ELSEIF tipo_evaluado = 'CARTERA' THEN 
            SET VOPERATION = ['ALTA', 'BAJA', 'CAMBIO'];
        ELSE
            -- Control por si se pasa un parámetro distinto no soportado
            SET VOPERATION = [];
        END IF;

        -- Solo continuamos si VOPERATION tiene elementos (es decir, si el tipo era válido)
        IF ARRAY_LENGTH(VOPERATION) > 0 THEN

            ----------------------------------------------------------------------------
            -- 2. PREPARACIÓN DE PARÁMETROS (Temp Table)
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
            WHERE p.tipo = tipo_evaluado
              AND p.ESTADO = 'PUBLICAR'
              AND UPPER(TRIM(op_split)) IN UNNEST(VOPERATION)
            
            -- [OPTIMIZACIÓN DE SEGURIDAD]: Deduplicación lógica
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
            -- 3. UPDATE DIRECTO (CORREGIDO - SIN TRIM EN INT64)
            ----------------------------------------------------------------------------
            UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
            SET 
                t.orden = p.orden_nueva,
                -- Asigna 'RESIDENCIAL' si el segmento viene vacío o nulo
                t.segmento = CASE 
                                WHEN TRIM(IFNULL(t.segmento, '')) = '' THEN 'RESIDENCIAL' 
                                ELSE t.segmento 
                             END
            FROM tmp_params_sap p
            WHERE t.mes_factura_dt = VMES_FACTURA_DT
              AND t.tipo = tipo_evaluado 
              AND UPPER(TRIM(t.marca)) = p.marca
              AND UPPER(TRIM(t.canal_gekt)) = p.canal
              AND UPPER(TRIM(t.service_type)) = p.service_type
              
              -- Trata los vacíos de la transacción como 'RESIDENCIAL' para que cruce con el Excel
              AND UPPER(TRIM(COALESCE(NULLIF(TRIM(t.segmento), ''), 'RESIDENCIAL'))) = p.segmento
              
              AND UPPER(TRIM(t.operation)) = p.operacion
              
              -- El marco de tu Excel es 'X', esto validará a TRUE
              AND (p.marco = 'X' OR UPPER(TRIM(t.marco)) = p.marco)
              
              -- CORRECCIÓN: Los campos numéricos (INT64) se comparan directamente
              AND t.orden IN (p.orden_antigua, p.orden_nueva)
              
              -- Ejecutar UPDATE si la orden no es la correcta O si el segmento está vacío
              AND (t.orden != p.orden_nueva OR TRIM(IFNULL(t.segmento, '')) = '')
              
              AND NOT CONTAINS_SUBSTR(t.concepto_ds_gekt, 'POSTVENTA');


            -- Limpieza: OBLIGATORIO hacerlo dentro del bucle para la siguiente iteración
            DROP TABLE IF EXISTS tmp_params_sap;

        END IF;

    END FOR;

END