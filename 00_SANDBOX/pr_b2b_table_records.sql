BEGIN


-- HISTORIFICA LA TABLAS DE VENTAS Y SERVICIOS DE MYSIM Y XENA PARA LA IDENTIFICACION DE CAMBIOS EN EL DETALLE DE LOS SERVICIOS DE B2B2C --


/*
CALL `mm-commissions-reporting.00_SANDBOX.pr_b2b_table_records`()
*/


/* Declaramos las variables que se van a usar a lo largo del procedimiento */
DECLARE
  ultima_fecha_ventas_base_emysim,
  ultima_fecha_ventas_base_telco_emysim,
  ultima_fecha_service_base_emysim,
  ultima_fecha_service_base_telco_emysim,
  ultima_fecha_service_base_xena,
  ultima_fecha_service_base_telco_xena
INT64;


SET ultima_fecha_ventas_base_emysim = (SELECT MAX(table_date) FROM `mm-commissions-reporting.00_SANDBOX.ventas_base_emysim_b2b`);
SET ultima_fecha_ventas_base_telco_emysim = (SELECT MAX(table_date) FROM `mm-commissions-reporting.00_SANDBOX.ventas_base_telco_emysim_b2b`);
SET ultima_fecha_service_base_emysim = (SELECT MAX(table_date) FROM `mm-commissions-reporting.00_SANDBOX.service_base_emysim_b2b`);
SET ultima_fecha_service_base_telco_emysim = (SELECT MAX(table_date) FROM `mm-commissions-reporting.00_SANDBOX.service_base_telco_emysim_b2b`);
SET ultima_fecha_service_base_xena = (SELECT MAX(table_date) FROM `mm-commissions-reporting.00_SANDBOX.service_base_xena_b2b`);
SET ultima_fecha_service_base_telco_xena = (SELECT MAX(table_date) FROM `mm-commissions-reporting.00_SANDBOX.service_base_telco_xena_b2b`);


/* Crea la tabla, si no existe, con el detalle histórico de B2B2C con la información proveniente de la tabla legacy de ventas de MYSIM */
CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.00_SANDBOX.ventas_base_emysim_b2b`
CLUSTER BY table_date AS
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_type_agg
     ,order_fix_id
     ,order_date
     ,activation_date
     ,deactivation_date
     ,real_deactivation_date
     ,segment_ds
     ,sell_tariff_id
     ,sell_tariff_ds
     ,sell_line_type_ds
     ,sell_bundle_type
     ,billing_type_ds
     ,sfid_id
     ,user_store
     ,seller
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,province
     ,zip_code
     ,customer_document
     ,current_sfid_id
     ,current_user_store
     ,customer_document_type

FROM `mm-dwh-prod.60_EDW.ventas_base_emysim_*`

WHERE CAST(_table_suffix AS INT64) > 20230101
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34
)
;


/* Actualiza la tabla legacy de ventas de MYSIM filtrando por los servicios de B2B2C */
INSERT INTO `mm-commissions-reporting.00_SANDBOX.ventas_base_emysim_b2b`
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_type_agg
     ,order_fix_id
     ,order_date
     ,activation_date
     ,deactivation_date
     ,real_deactivation_date
     ,segment_ds
     ,sell_tariff_id
     ,sell_tariff_ds
     ,sell_line_type_ds
     ,sell_bundle_type
     ,billing_type_ds
     ,sfid_id
     ,user_store
     ,seller
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_type
     ,technology_ds
     ,province
     ,zip_code
     ,customer_document
     ,current_sfid_id
     ,current_user_store
     ,customer_document_type

FROM `mm-dwh-prod.60_EDW.ventas_base_emysim_*`

WHERE CAST(_table_suffix AS INT64) > ultima_fecha_ventas_base_emysim 
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34
)
;


/* Crea la tabla, si no existe, con el detalle histórico de B2B2C con la información proveniente de la tabla de ventas de MYSIM */
CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.00_SANDBOX.ventas_base_telco_emysim_b2b`
CLUSTER BY table_date AS
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_type_agg
     ,order_fix_id
     ,order_date
     ,activation_date
     ,deactivation_date
     ,real_deactivation_date
     ,segment_ds
     ,sell_tariff_id
     ,sell_tariff_ds
     ,sell_line_type_ds
     ,sell_bundle_id
     ,sell_bundle_name
     ,sell_bundle_type
     ,billing_type_ds
     ,sfid_id
     ,user_store
     ,seller
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_id
     ,bundle_name
     ,bundle_type
     ,technology_ds
     ,province
     ,zip_code
     ,customer_document
     ,current_sfid_id
     ,current_user_store
     ,customer_document_type
     ,order_id

FROM `mm-dwh-prod.60_EDW.ventas_base_telco_emysim_*`

WHERE CAST(_table_suffix AS INT64) > 20230101
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39
)
;


/* Historifica la tabla de ventas de MYSIM filtrando por los servicios de B2B2C */
INSERT INTO `mm-commissions-reporting.00_SANDBOX.ventas_base_telco_emysim_b2b`
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_type_agg
     ,order_fix_id
     ,order_date
     ,activation_date
     ,deactivation_date
     ,real_deactivation_date
     ,segment_ds
     ,sell_tariff_id
     ,sell_tariff_ds
     ,sell_line_type_ds
     ,sell_bundle_id
     ,sell_bundle_name
     ,sell_bundle_type
     ,billing_type_ds
     ,sfid_id
     ,user_store
     ,seller
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_id
     ,bundle_name
     ,bundle_type
     ,technology_ds
     ,province
     ,zip_code
     ,customer_document
     ,current_sfid_id
     ,current_user_store
     ,customer_document_type
     ,order_id

FROM `mm-dwh-prod.60_EDW.ventas_base_telco_emysim_*`

WHERE CAST(_table_suffix AS INT64) > ultima_fecha_ventas_base_telco_emysim
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39
)
;


/* Crea la tabla, si no existe, con el detalle histórico de B2B2C con la información proveniente de la tabla legacy de servicios de MYSIM */
CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.00_SANDBOX.service_base_emysim_b2b`
CLUSTER BY table_date AS
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_emysim_*`

WHERE CAST(_table_suffix AS INT64) > 20230101
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
)
;


/* Historifica la tabla legacy de servicios de MYSIM filtrando por los servicios de B2B2C */
INSERT INTO `mm-commissions-reporting.00_SANDBOX.service_base_emysim_b2b`
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_emysim_*`

WHERE CAST(_table_suffix AS INT64) > ultima_fecha_service_base_emysim 
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
)
;


/* Crea la tabla, si no existe, con el detalle histórico de B2B2C con la información proveniente de la tabla de servicios de MYSIM */
CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.00_SANDBOX.service_base_telco_emysim_b2b`
CLUSTER BY table_date AS
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_id
     ,bundle_name
     ,bundle_type
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_telco_emysim_*`

WHERE CAST(_table_suffix AS INT64) > 20230101
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


/* Historifica la tabla de servicios de MYSIM filtrando por los servicios de B2B2C */
INSERT INTO `mm-commissions-reporting.00_SANDBOX.service_base_telco_emysim_b2b`
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_id
     ,bundle_name
     ,bundle_type
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_telco_emysim_*`

WHERE CAST(_table_suffix AS INT64) > ultima_fecha_service_base_telco_emysim
      AND comm_brand_ds IN (
                           'AHIMAS',
                           'ALTERNA',
                           'JOI',
                           'MARBLANCA',
                           'MIGRADOS XENA',
                           'PARLEM',
                           'SWENO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


/* Crea la tabla, si no existe, con el detalle histórico de B2B2C con la información proveniente de la tabla legacy de servicios de XENA */
CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.00_SANDBOX.service_base_xena_b2b`
CLUSTER BY table_date AS
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_xena_*`

WHERE CAST(_table_suffix AS INT64) > 20230101
      AND comm_brand_ds IN (
                           'CABLEMOVIL',
                           'EMBOU',
                           'EURONA',
                           'HAPPYBUSINESS',
                           'HAPPYMOVIL',
                           'NETLLAR',
                           'XTRA TELECOM',
                           'YOIGO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
)
;


/* Historifica la tabla legacy de servicios de XENA filtrando por los servicios de B2B2C */
INSERT INTO `mm-commissions-reporting.00_SANDBOX.service_base_xena_b2b`
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_xena_*`

WHERE CAST(_table_suffix AS INT64) > ultima_fecha_service_base_xena
      AND comm_brand_ds IN (
                           'CABLEMOVIL',
                           'EMBOU',
                           'EURONA',
                           'HAPPYBUSINESS',
                           'HAPPYMOVIL',
                           'NETLLAR',
                           'XTRA TELECOM',
                           'YOIGO'
                           )

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
)
;


/* Crea la tabla, si no existe, con el detalle histórico de B2B2C con la información proveniente de la tabla de servicios de XENA */
CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.00_SANDBOX.service_base_telco_xena_b2b`
CLUSTER BY table_date AS
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_id
     ,bundle_name
     ,bundle_type
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_telco_xena_*`

WHERE CAST(_table_suffix AS INT64) > 20230101
      AND comm_brand_ds IN (
                           'CABLEMOVIL',
                           'EMBOU',
                           'EURONA',
                           'HAPPYBUSINESS',
                           'HAPPYMOVIL',
                           'NETLLAR',
                           'XTRA TELECOM',
                           'YOIGO'
                           )
                           

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


/* Historifica la tabla de servicios de XENA filtrando por los servicios de B2B2C */
INSERT INTO `mm-commissions-reporting.00_SANDBOX.service_base_telco_xena_b2b`
(
SELECT
      CAST(_table_suffix AS INT64) AS table_date
     ,brand_ds
     ,comm_brand_ds
     ,account_id
     ,customer_id
     ,service_id
     ,service_type
     ,phone_nm
     ,order_fix_id
     ,activation_date
     ,deactivation_date
     ,segment_ds
     ,billing_type_ds
     ,sfid_id
     ,tariff_id
     ,tariff_ds
     ,line_type_ds
     ,bundle_id
     ,bundle_name
     ,bundle_type
     ,technology_ds

FROM `mm-dwh-prod.60_EDW.service_base_telco_xena_*`

WHERE CAST(_table_suffix AS INT64) > ultima_fecha_service_base_telco_xena
      AND comm_brand_ds IN (
                           'CABLEMOVIL',
                           'EMBOU',
                           'EURONA',
                           'HAPPYBUSINESS',
                           'HAPPYMOVIL',
                           'NETLLAR',
                           'XTRA TELECOM',
                           'YOIGO'
                           )
                           

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
)
;


END