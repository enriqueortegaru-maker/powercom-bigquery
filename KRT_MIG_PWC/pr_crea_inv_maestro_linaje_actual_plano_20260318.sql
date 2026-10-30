BEGIN

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE_ACTUAL_PLANO` AS
    WITH Ultimo_Inventario AS (
        SELECT *
        FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
        -- Se mantiene la lógica correcta para priorizar la última ejecución por proyecto/dataset
        QUALIFY DENSE_RANK() OVER (
            PARTITION BY source_project, source_dataset 
            ORDER BY extraction_timestamp DESC
        ) = 1
    )
    SELECT 
        extraction_timestamp,
        source_project,
        source_dataset,
        
        -- 1. objeto_padre (CORREGIDO: Renombrado desde "procedimiento" y añadido "tipo_objeto")
        STRUCT(
            objeto_padre.project_name,
            objeto_padre.dataset_name,
            objeto_padre.object_name,
            objeto_padre.tipo_objeto, -- Este campo es clave para aislar el CONTENEDOR_HUERFANAS
            objeto_padre.arguments,
            objeto_padre.definition,
            objeto_padre.metadata
        ) AS objeto_padre,

        -- 2. subprocedimiento
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas) WHERE tipo_relacion = 'CALL'
        ) AS objeto_hijo,

        -- 3. tabla_creada
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas) WHERE tipo_relacion = 'CREADA'
        ) AS tabla_creada,

        -- 3b. tabla_huerfana
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas) WHERE tipo_relacion = 'HUERFANA'
        ) AS tabla_huerfana,

        -- 4. tabla_modificada
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas) WHERE tipo_relacion = 'MODIFICADA'
        ) AS tabla_modificada,

        -- 5. tabla_leida
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas) WHERE tipo_relacion = 'LEIDA'
        ) AS tabla_leida,

        -- 6. table_function
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas) WHERE tipo_relacion = 'TABLE_FUNCTION'
        ) AS table_function,

        -- 7. funcion
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas) WHERE tipo_relacion = 'FUNCTION_CALL'
        ) AS funcion,

        -- NUEVO 8. Captura de Tablas Desconocidas (Para evitar pérdida de información)
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas) WHERE tipo_relacion = 'DESCONOCIDA'
        ) AS tabla_desconocida,

        -- NUEVO 9. Captura de Rutinas Atípicas (Para evitar pérdida de información)
        ARRAY(
            SELECT AS STRUCT 
                project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas) WHERE tipo_relacion = 'OTRA_RUTINA'
        ) AS otra_rutina,

        routine_definition_debug

    FROM Ultimo_Inventario;

END