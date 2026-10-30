BEGIN

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE_ACTUAL` AS

    SELECT *
    FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
    -- Se mantiene la lógica correcta para priorizar la última ejecución por proyecto/dataset
    QUALIFY DENSE_RANK() OVER (
        PARTITION BY source_project, source_dataset 
        ORDER BY extraction_timestamp DESC
    ) = 1;

/*
    SELECT * EXCEPT(rn)
    FROM (
        SELECT 
            *,
            -- Numeramos las filas por dataset, ordenando por fecha descendente
            ROW_NUMBER() OVER (
                PARTITION BY source_project, source_dataset 
                ORDER BY extraction_timestamp DESC
            ) as rn
        FROM `mm-commissions-reporting.KRT_MIG_PWC.INV_MAESTRO_LINAJE`
    )
    WHERE rn = 1; -- Nos quedamos solo con la versión más reciente de cada uno
*/

END