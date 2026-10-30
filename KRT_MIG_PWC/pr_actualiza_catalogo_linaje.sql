BEGIN
    DECLARE targets ARRAY<STRUCT<project_id STRING, dataset_id STRING>>;
    DECLARE region  STRING;

    -- Materialise active target list from the parametrization table.
    -- Grouped by region so the subproc uses the correct INFORMATION_SCHEMA prefix.
    -- Current estate uses a single region (region-eu); extend if multi-region needed.
    SET targets = (
        SELECT ARRAY_AGG(STRUCT(project_id, dataset_id))
        FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_LINAJE_TARGETS`
        WHERE activo = TRUE
          AND region  = 'region-eu'
    );

    SET region = 'region-eu';

    -- Step 1: extract lineage for all active targets into INV_MAESTRO_LINAJE
    CALL `mm-commissions-reporting.KRT_MIG_PWC.subproc_actualiza_catalogo_linaje`(
        targets, region
    );

    -- Step 2: rebuild Gold flat layer from the fresh raw table
    CALL `mm-commissions-reporting.KRT_MIG_PWC.pr_crea_inv_maestro_linaje_actual_plano`();

    -- Note: V_GRAFO_MAESTRO_LINAJE is a VIEW - it reflects the new data
    -- immediately without an explicit refresh step.

END