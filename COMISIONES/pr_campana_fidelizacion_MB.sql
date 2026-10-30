BEGIN
 
-- CALL `mm-commissions-reporting.COMISIONES.pr_campana_fidelizacion_MB`(202602)
-- DECLARE id_mes_pr INT64;
DECLARE mes STRING;
DECLARE ano STRING;
DECLARE id_mes_pr_string STRING;
-- SET id_mes_pr = 202510;
SET id_mes_pr_string = CAST(id_mes_pr AS STRING);
SET mes = CASE RIGHT(CAST(id_mes_pr AS STRING), 2)
  WHEN '01' THEN 'ENE'
  WHEN '02' THEN 'FEB'
  WHEN '03' THEN 'MAR'
  WHEN '04' THEN 'ABR'
  WHEN '05' THEN 'MAY'
  WHEN '06' THEN 'JUN'
  WHEN '07' THEN 'JUL'
  WHEN '08' THEN 'AGO'
  WHEN '09' THEN 'SEP'
  WHEN '10' THEN 'OCT'
  WHEN '11' THEN 'NOV'
  WHEN '12' THEN 'DIC'
END;
SET ano = RIGHT(LEFT(id_mes_pr_string, 4), 2);

CREATE OR REPLACE  TABLE `mm-commissions-reporting.GS.B2B_CAMPANAS_FDZ_MB` AS (
 SELECT
  PARSE_DATE('%d/%m/%Y', fecha_registro) AS fecha_registro,
  CAST(CONCAT('20', RIGHT(fecha_ini, 2),LPAD(CAST(
            CASE
              WHEN fecha_ini LIKE 'ene.%' THEN 01
              WHEN fecha_ini LIKE 'feb.%' THEN 02
              WHEN fecha_ini LIKE 'mar.%' THEN 03
              WHEN fecha_ini LIKE 'abr.%' THEN 04
              WHEN fecha_ini LIKE 'may.%' THEN 05
              WHEN fecha_ini LIKE 'jun.%' THEN 06
              WHEN fecha_ini LIKE 'jul.%' THEN 07
              WHEN fecha_ini LIKE 'ago.%' THEN 08
              WHEN fecha_ini LIKE 'sep.%' THEN 09
              WHEN fecha_ini LIKE 'oct.%' THEN 10
              WHEN fecha_ini LIKE 'nov.%' THEN 11
              WHEN fecha_ini LIKE 'dic.%' THEN 12
            END AS STRING
          ), 2, '0')) AS INT64
    ) AS id_mes_ini,

    CAST(CONCAT('20', RIGHT(fecha_fin, 2),LPAD(CAST(
            CASE
              WHEN fecha_fin LIKE 'ene.%' THEN 1
              WHEN fecha_fin LIKE 'feb.%' THEN 2
              WHEN fecha_fin LIKE 'mar.%' THEN 3
              WHEN fecha_fin LIKE 'abr.%' THEN 4
              WHEN fecha_fin LIKE 'may.%' THEN 5
              WHEN fecha_fin LIKE 'jun.%' THEN 6
              WHEN fecha_fin LIKE 'jul.%' THEN 7
              WHEN fecha_fin LIKE 'ago.%' THEN 8
              WHEN fecha_fin LIKE 'sep.%' THEN 9
              WHEN fecha_fin LIKE 'oct.%' THEN 10
              WHEN fecha_fin LIKE 'nov.%' THEN 11
              WHEN fecha_fin LIKE 'dic.%' THEN 12
            END AS STRING
          ), 2, '0')) AS INT64
    ) AS id_mes_fin,
  id_subcampana,
  id_operador,
  phone_nm,
  importe,
  importe_total,
  duracion,
  clawback,
  concepto_literal,
  revisado ,
  firmado ,
  campana ,
  nombre_comercio,
  cod_navision,
  comisiones,
  a_corregir,
  origen_datos,
  comentarios,
  comentarios_extra,
  abonar

 FROM `mm-commissions-reporting.GS.B2B_CAMPANAS_FDZ_MB_raw`
--  WHERE phone_nm is not null
);

-----TABLA INSERTAR TRANSACCIONES QUITANDO 1ª COLUMNA

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_CAMPANA_FDZ_MB` AS (

SELECT
CONCAT(
    IF(dealer.id_comisionista IS NULL, 'No cruza DEALERS. ', ''),
    IF(altas.cod_navision != base.current_sfid_id, 'No coincide sfid telco y terminal', ' '),
    IF(base.service_id IS NULL, 'No servicio telco ',''),
    IF(t.service_id is null, 'No transacciones ', ''),
    IF(t.tariff_id IN ('155','154'), 'Tariff_id 154 o 155 ', ''),
    IF(dealer.comisiona IS NOT TRUE, 'Dealer no comisiona ', ''),
    IF(base.deactivation_date != '9999-12-31' 
       AND base.deactivation_date < DATE_ADD(
   PARSE_DATE('%Y%m%d', CONCAT(CAST(id_mes_pr AS STRING), '01')), INTERVAL 1 MONTH)
       AND base.deactivation_date IS NOT NULL,
       'Telf desactivado ', '')  
  ) AS ERRORES,

    'calculado' AS estado
    ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
    ,id_mes_pr AS id_mes
    ,CASE
    WHEN dealer.canal like 'ALT%' THEN 'MBA'
    ELSE 'MB'   
    END AS canal
    ,CASE
    WHEN dealer.canal like 'ALT%' THEN 'B2B - Marblanca Alterna'
    ELSE 'B2B - Marblanca'
    END AS agrupacion_canal
    ,'D - EXTRA FDZ '||mes||' '||ano||' SID:'||altas.id_subcampana AS concepto 
    ,'UPFR' AS tipo_concepto
    ,1 AS unidades
    ,importe AS comision
    ,altas.cod_navision AS id_comisionista 
    ,altas.cod_navision AS distribuidor
    ,altas.cod_navision AS sfid_id
    ,altas.cod_navision AS seller
    ,dealer.nombre_comercio AS nombre_comercio
    ,dealer.nombre_comercio AS razon_social
    ,dealer.documento AS cif
    ,dealer.zona_fiscal AS zona_fiscal
    ,dealer.cond_pago AS cod_pago
    ,'MARBLANCA' AS marca
    ,'INTERNET' AS service_type
    ,altas.phone_nm 
    ,t.tariff_id 
    ,t.tariff_ds 
    ,t.service_id 
    ,t.account_id
    ,t.customer_id
    ,'MAIN' AS line_type_ds
    ,t.bundle_type
    ,'FTTH' AS technology_ds
    ,'POSTPAID' AS billing_type_ds
    ,t.sale_date
    ,t.activation_date
    ,base.deactivation_date
    ,CAST(NULL AS STRING) AS order_id	
    ,CAST(NULL AS STRING) AS order_type_agg
    , '42' AS	cod_segmento
    , '9' AS cod_marca
    , CASE 
    WHEN t.bundle_type = 'FMC' THEN '61'
    WHEN t.bundle_type = '2P' THEN '63'
    END AS	cod_tipo_contrato
    , '039' AS cod_producto	
    , '30' AS cod_canal	
    ,'CAMP. FIDELIZACION' AS campaign_code 
    ,CAST(NULL AS STRING) AS	serial_number
    , CAST( NULL AS FLOAT64) tax_base
    ,CAST(NULL AS STRING) AS claim_code
    ,CAST( NULL AS STRING) AS process_code
    ,'Autofactura' AS comments
    ,'C_MANUAL' AS facturador
    ,'X001' AS sociedad	
 

FROM `mm-commissions-reporting.GS.B2B_CAMPANAS_FDZ_MB` altas

LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA` dealer
  ON altas.cod_navision = dealer.id_comisionista

LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` base
 ON CAST(base.phone_nm AS STRING) = altas.phone_nm
 AND altas.cod_navision = base.current_sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` t
 ON t.phone_nm = altas.phone_nm
 AND t.id_comisionista = altas.cod_navision
 AND t.activation_date = base.activation_date -- 20260310

-- WHERE dealer.comisiona IS TRUE
WHERE dealer.zona_fiscal in ('PEN','CAN','MEL')
 AND id_mes_pr <= altas.id_mes_fin
 AND altas.abonar IS TRUE

--  AND t.service_id IS NOT NULL
--  and (base.deactivation_date IS NULL OR base.deactivation_date = '9999-12-31')
-- AND base.deactivation_date >= DATE_ADD(
  -- PARSE_DATE('%Y%m%d', CONCAT(CAST(id_mes_pr AS STRING), '01')),
  -- INTERVAL 1 MONTH)
-- AND t.tariff_id not in ('155','154')

QUALIFY CASE
WHEN (base.phone_nm is not null AND base.phone_nm = 967854846) THEN ROW_NUMBER() OVER(PARTITION BY base.phone_nm ORDER BY base.activation_date ASC) = 1
WHEN (base.phone_nm is not null AND base.phone_nm != 967854846) THEN  ROW_NUMBER() OVER(PARTITION BY base.phone_nm ORDER BY base.activation_date DESC) = 1
WHEN base.phone_nm  is null and altas.abonar is true THEN ROW_NUMBER() OVER(PARTITION BY altas.phone_nm ORDER BY altas.fecha_registro DESC) = 1
END


);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_CAMPANA_FDZ_MB` AS (

SELECT *,
  'ARM20' ||'_'|| id_mes_pr ||'_'||row_number () over () AS commission_id
 FROM `mm-commissions-reporting.TEMP.B2B_CAMPANA_FDZ_MB`

);

END