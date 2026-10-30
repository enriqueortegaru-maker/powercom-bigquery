BEGIN

    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE_ACTUAL_PLANO`
    AS

    -- F8: inner join suppresses ghost datasets (retired targets whose last
    --     snapshot survived in the raw layer after scanning stopped).
    WITH Targets_Activos AS (
        SELECT project_id, dataset_id
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_LINAJE_TARGETS`
        WHERE activo = TRUE
    ),

    Ultimo_Inventario AS (
        SELECT inv.*
        FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE` inv
        -- F8: restrict to active targets only
        INNER JOIN Targets_Activos t
          ON inv.source_project = t.project_id
         AND inv.source_dataset = t.dataset_id
        -- Keep only the most-recent snapshot per (project, dataset).
        -- If today's run failed, yesterday's snapshot is served transparently.
        QUALIFY DENSE_RANK() OVER (
            PARTITION BY source_project, source_dataset
            ORDER BY extraction_timestamp DESC
        ) = 1
    )

    SELECT
        extraction_timestamp,
        source_project,
        source_dataset,

        -- F8: expose snapshot age so BI can surface staleness instead of hiding it
        DATE_DIFF(CURRENT_DATE(), DATE(extraction_timestamp), DAY) AS dias_antiguedad_snapshot,

        -- 1. objeto_padre
        STRUCT(
            objeto_padre.project_name,
            objeto_padre.dataset_name,
            objeto_padre.object_name,
            objeto_padre.tipo_objeto,
            objeto_padre.arguments,
            objeto_padre.columns,
            objeto_padre.definition,
            objeto_padre.metadata
        ) AS objeto_padre,

        -- 2. subprocedimientos - F7: 'PROCEDIMIENTO_LLAMADO' (was 'CALL')
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas)
            WHERE tipo_relacion = 'PROCEDIMIENTO_LLAMADO'
        ) AS objeto_hijo,

        -- 3. tabla_creada - F7: 'TABLA_CREADA' (was 'CREADA')
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas)
            WHERE tipo_relacion = 'TABLA_CREADA'
        ) AS tabla_creada,

        -- 4. tabla_huerfana - unchanged token
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas)
            WHERE tipo_relacion = 'HUERFANA'
        ) AS tabla_huerfana,

        -- 5. tabla_modificada - F7: 'TABLA_MODIFICADA' (was 'MODIFICADA')
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas)
            WHERE tipo_relacion = 'TABLA_MODIFICADA'
        ) AS tabla_modificada,

        -- 6. tabla_leida - F7: 'TABLA_LEIDA' (was 'LEIDA')
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas)
            WHERE tipo_relacion = 'TABLA_LEIDA'
        ) AS tabla_leida,

        -- 7. vista_leida - F7: new bucket for VISTA_LEIDA (had no destination)
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas)
            WHERE tipo_relacion = 'VISTA_LEIDA'
        ) AS vista_leida,

        -- 8. table_function - unchanged token
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas)
            WHERE tipo_relacion = 'TABLE_FUNCTION'
        ) AS table_function,

        -- 9. funcion - F7: 'FUNCION_LLAMADA' (was 'FUNCTION_CALL')
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas)
            WHERE tipo_relacion = 'FUNCION_LLAMADA'
        ) AS funcion,

        -- 10. tabla_desconocida - unchanged token
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, columns, metadata
            FROM UNNEST(dependencias_tablas)
            WHERE tipo_relacion = 'DESCONOCIDA'
        ) AS tabla_desconocida,

        -- 11. otra_rutina - unchanged token
        ARRAY(
            SELECT AS STRUCT project_name, dataset_name, object_name, arguments, definition, metadata
            FROM UNNEST(dependencias_rutinas)
            WHERE tipo_relacion = 'OTRA_RUTINA'
        ) AS otra_rutina,

        routine_definition_debug

    FROM Ultimo_Inventario;

END