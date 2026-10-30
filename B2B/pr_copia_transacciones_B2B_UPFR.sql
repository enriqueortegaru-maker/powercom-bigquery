BEGIN

--CALL `mm-commissions-reporting.B2B.pr_copia_transacciones_B2B_UPFR`(202501);


DELETE
FROM `mm-commissions-reporting.TEMP.transacciones_B2B`
WHERE 1=1;

INSERT INTO `mm-commissions-reporting.TEMP.transacciones_B2B` (
  SELECT *
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE id_mes >= initial_id_mes
    AND agrupacion_canal LIKE '%B2B%'
    AND tipo_concepto = 'UPFR'  
);

DELETE
FROM `mm-commissions-reporting.TEMP.gs_global_campana_B2B`
WHERE 1=1;

INSERT INTO `mm-commissions-reporting.TEMP.gs_global_campana_B2B`(
  SELECT *-- EXCEPT (FECHA_REGISTRO)
  FROM `mm-commissions-reporting.B2B.gs_global_campana`
  WHERE Id_Campana IS NOT NULL
);

DELETE
FROM `mm-commissions-reporting.TEMP.gs_global_subcampana_B2B`
WHERE 1=1;

INSERT INTO `mm-commissions-reporting.TEMP.gs_global_subcampana_B2B`(
  SELECT * EXCEPT (FECHA_REGISTRO, FECHA_REGISTRO_2)
  FROM `mm-commissions-reporting.B2B.gs_global_subcampana`
  WHERE ID_SUBCAMPANA IS NOT NULL
);

DELETE
FROM `mm-commissions-reporting.TEMP.gs_global_rangos_B2B`
WHERE 1=1;

INSERT INTO `mm-commissions-reporting.TEMP.gs_global_rangos_B2B`(
  SELECT *
  FROM `mm-commissions-reporting.B2B.gs_global_rangos`
  WHERE Id_SubCampana IS NOT NULL
);

DELETE
FROM `mm-commissions-reporting.TEMP.gs_global_subc_operador_B2B`
WHERE 1=1;

INSERT INTO `mm-commissions-reporting.TEMP.gs_global_subc_operador_B2B`(
  SELECT *
  FROM `mm-commissions-reporting.B2B.gs_global_subc_operador`
  WHERE ID_CAMPANA IS NOT NULL
);

DELETE
FROM `mm-commissions-reporting.TEMP.gs_global_cierres_B2B` 
WHERE 1=1;

INSERT INTO `mm-commissions-reporting.TEMP.gs_global_cierres_B2B` (
    SELECT *
    FROM `mm-commissions-reporting.B2B.gs_global_cierres`
    WHERE Id_SubCampana IS NOT NULL
);


/*
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.transacciones_B2B`
--    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 60 DAY)) 
    AS

    SELECT *
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE id_mes >= initial_id_mes
      AND agrupacion_canal LIKE '%B2B%'
      AND tipo_concepto = 'UPFR'
    ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.gs_global_campana_B2B`
--    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 60 DAY)) 
    AS

    SELECT * EXCEPT (FECHA_REGISTRO)
    FROM `mm-commissions-reporting.B2B.gs_global_campana`
    WHERE Id_Campana IS NOT NULL
    ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.gs_global_subcampana_B2B`
--    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 60 DAY)) 
    AS

    SELECT * EXCEPT (FECHA_REGISTRO, FECHA_REGISTRO_2)
    FROM `mm-commissions-reporting.B2B.gs_global_subcampana`
    WHERE ID_SUBCAMPANA IS NOT NULL
    ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.gs_global_rangos_B2B`
--    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 60 DAY)) 
    AS

    SELECT *
    FROM `mm-commissions-reporting.B2B.gs_global_rangos`
    WHERE Id_SubCampana IS NOT NULL
    ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.gs_global_subc_operador_B2B`
--    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 60 DAY)) 
    AS

    SELECT *
    FROM `mm-commissions-reporting.B2B.gs_global_subc_operador`
    WHERE ID_CAMPANA IS NOT NULL
    ;
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.gs_global_cierres_B2B`
--    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 60 DAY)) 
    AS

    SELECT *
    FROM `mm-commissions-reporting.B2B.gs_global_cierres`
    WHERE Id_SubCampana IS NOT NULL
    ;
*/

END