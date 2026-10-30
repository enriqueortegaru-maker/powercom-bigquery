BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'SVAP';

--SET agrupacion_canal_pr =  COALESCE(agrupacion_canal_pr, ['No Exclusivo']);
SET canales_pr =  COALESCE(canales_pr, ['MP', 'MI','MR', 'NR','CA','PH']);

/*
CALL COMISIONES.pr_sva_nex_pro(202405, ['No Exclusivo']);
*/


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_nex_pro` AS

---ACTIVACIONES---

  --Ciberseguridad--
  SELECT
      prefijo ||'B'|| '_A'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'B - Ciberseguridad' AS concepto
      ,tipo_concepto
      ,unidades
      ,3 AS comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1497','1498','1499','1500','1501','1502')
    AND concepto = 'A - Servicio Fijo'
    AND id_mes = id_mes_pr

UNION ALL

  --Asesores MM--
  SELECT
      prefijo ||'B'|| '_B'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'B - Asesores' AS concepto
      ,tipo_concepto
      ,unidades
      ,3 AS comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1497','1498','1499','1500','1501','1502')
    AND concepto = 'A - Servicio Fijo'
    AND id_mes = id_mes_pr

UNION ALL

  --Sitio Web--
  SELECT
      prefijo ||'B'|| '_C'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'B - Sitio Web' AS concepto
      ,tipo_concepto
      ,unidades
      ,3 AS comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1501','1502')
    AND concepto = 'A - Servicio Fijo'
    AND id_mes = id_mes_pr
   
UNION ALL

  --Perfil Online--
  SELECT
      prefijo ||'B'|| '_D'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'B - Perfil Online' AS concepto
      ,tipo_concepto
      ,unidades
      ,3 AS comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1501','1502')
    AND concepto = 'A - Servicio Fijo'
    AND id_mes = id_mes_pr
;

-- DESACTIVACIONES -- 

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.clawback_sva_nex_pro` AS

--Ciberseguridad--
  SELECT
      prefijo ||'E'|| '_A'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'E - Clawback Ciberseguridad' AS concepto
      ,tipo_concepto
      ,unidades
      ,CASE
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) < 60                THEN - 3
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) BETWEEN 61 AND 120  THEN (3 * -0.75)
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) <= 180              THEN (3 * -0.50)
    ELSE 0
  END as comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1497','1498','1499','1500','1501','1502')
    AND concepto = 'E - Clawback Servicio Fijo'
    AND id_mes = id_mes_pr

UNION ALL

  --Asesores--
SELECT
      prefijo ||'E'|| '_B'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'E - Clawback Asesores' AS concepto
      ,tipo_concepto
      ,unidades
      ,CASE
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) < 60                THEN - 3
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) BETWEEN 61 AND 120  THEN (3 * -0.75)
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) <= 180              THEN (3 * -0.50)
    ELSE 0
  END as comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1497','1498','1499','1500','1501','1502')
    AND concepto = 'E - Clawback Servicio Fijo'
    AND id_mes = id_mes_pr

UNION ALL

  --Sitio Web--
SELECT
      prefijo ||'E'|| '_C'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'E - Sitio Web' AS concepto
      ,tipo_concepto
      ,unidades
      ,CASE
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) < 60                THEN - 3
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) BETWEEN 61 AND 120  THEN (3 * -0.75)
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) <= 180              THEN (3 * -0.50)
    ELSE 0
  END as comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1501','1502')
    AND concepto = 'E - Clawback Servicio Fijo'
    AND id_mes = id_mes_pr

UNION ALL

  --Perfil Online--
SELECT
      prefijo ||'E'|| '_D'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,agrupacion_canal
      ,canal
      ,'E - Perfil Online' AS concepto
      ,tipo_concepto
      ,unidades
      ,CASE
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) < 60                THEN - 3
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) BETWEEN 61 AND 120  THEN (3 * -0.75)
    WHEN DATE_DIFF(DATE (deactivation_date), DATE (activation_date), DAY) <= 180              THEN (3 * -0.50)
    ELSE 0
  END as comision
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type 
      ,phone_nm
      ,tariff_id
      ,tariff_ds
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,'SVA Pro No Exclusivo'||' '||id_mes_pr AS comments
      ,facturador
      ,sociedad
      ,CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE agrupacion_canal = 'No Exclusivo'
    AND tariff_id IN ('1501','1502')
    AND concepto = 'E - Clawback Servicio Fijo'
    AND id_mes = id_mes_pr

/*
CREATE OR REPLACE TABLE TEMP.sva_nex_pro AS
(
SELECT
      *
     ,prefijo ||'B'|| '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id

FROM TEMP.sva_nex_pro
)
;

CREATE OR REPLACE TABLE TEMP.clawback_sva_nex_pro AS
(
SELECT
      *
     ,prefijo ||'E'|| '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id

FROM TEMP.clawback_sva_nex_pro
)*/
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('SVAPB', id_mes_pr, canales_pr, 'TEMP.sva_nex_pro' , 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('SVAPE', id_mes_pr, canales_pr , 'TEMP.clawback_sva_nex_pro' , 'ACTUALIZAR');



END