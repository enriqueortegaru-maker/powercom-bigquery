BEGIN
 
-- CALL `mm-commissions-reporting.COMISIONES.pr_campana_fidelizacion_MB_no_listado`(202602)
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

--EXTRACTO DE TRANSACCIONES A ANALIZAR

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.FDZ_EXTRA_MB_transacciones` AS (

  WITH datos_a_extraer AS (
    SELECT DISTINCT(id_comisionista),id_mes_pr,id_subcampana
    FROM `mm-commissions-reporting.GS.B2B_CAMPANAS_FDZ_EXTRA_MB`
    WHERE ini_subcampana <= PARSE_DATE('%Y%m%d', CONCAT(CAST(id_mes_pr AS STRING), '01')) AND fin_subcampana >= PARSE_DATE('%Y%m%d', CONCAT(CAST(id_mes_pr AS STRING), '01'))
    GROUP BY ALL
  )

  SELECT gs.id_mes_pr,gs.id_subcampana,t.* except(emails_acceso_trazabilidad) ---Hay que reducir el nº de campos

  FROM `mm-commissions-reporting.COMISIONES.transacciones` t

  INNER JOIN datos_a_extraer AS gs
    ON t.id_comisionista = gs.id_comisionista
    AND t.id_mes = gs.id_mes_pr

  WHERE t.id_mes = id_mes_pr
    AND t.concepto LIKE 'C - Gestion%' AND t.concepto NOT LIKE '%Territorio%' AND t.campaign_code LIKE '%FIBRA%'
    AND t.canal IN ('MB','MBA')
    AND (t.campaign_code NOT LIKE '%TARIFA%FIJO%' OR t.campaign_code NOT LIKE 'IP%FIJA%')
  QUALIFY ROW_NUMBER() OVER (PARTITION BY phone_nm,cif ORDER BY activation_date DESC) = 1

)
;
-----TABLA INSERTAR TRANSACCIONES QUITANDO 1ª COLUMNA

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_CAMPANA_FDZ_MB` AS (

  SELECT
  CONCAT(
    -- IF(dealer.id_comisionista IS NULL, 'No cruza DEALERS. ', ''),
    -- IF(altas.cod_navision != base.current_sfid_id, 'No coincide sfid telco y terminal', ' '),
    -- IF(base.service_id IS NULL, 'No servicio telco ',''),
    -- IF(t.service_id is null, 'No transacciones ', ''),
    -- IF(t.tariff_id IN ('155','154'), 'Tariff_id 154 o 155 ', ''),
    -- IF(dealer.comisiona IS NOT TRUE, 'Dealer no comisiona ', ''),
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
    --,importe AS comision 
    ,altas.id_comisionista AS id_comisionista 
    ,altas.id_comisionista AS distribuidor
    ,altas.id_comisionista AS sfid_id
    ,altas.id_comisionista AS seller
    ,dealer.nombre_comercio AS nombre_comercio
    ,dealer.nombre_comercio AS razon_social
    ,dealer.documento AS cif
    ,dealer.zona_fiscal AS zona_fiscal
    ,dealer.cond_pago AS cod_pago
    ,'MARBLANCA' AS marca
    ,'INTERNET' AS service_type
    ,altas.phone_nm 
    ,altas.tariff_id 
    ,altas.tariff_ds 
    ,altas.service_id 
    ,altas.account_id
    ,altas.customer_id
    ,'MAIN' AS line_type_ds
    ,altas.bundle_type
    ,'FTTH' AS technology_ds
    ,'POSTPAID' AS billing_type_ds
    ,altas.sale_date
    ,altas.activation_date
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
 

  FROM `mm-commissions-reporting.TEMP.FDZ_EXTRA_MB_transacciones` altas

  LEFT JOIN `mm-commissions-reporting.GS.B2B_CAMPANAS_FDZ_EXTRA_MB` gs
    ON gs.id_comisionista = altas.id_comisionista
    AND gs.id_subcampana = altas.id_subcampana

  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_MARBLANCA` dealer
    ON altas.cod_navision = dealer.id_comisionista

  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_net` base
    ON CAST(base.phone_nm AS STRING) = altas.phone_nm
    AND altas.id_comisionista = base.current_sfid_id
    AND base.activation_date = altas.activation_date


-- WHERE dealer.comisiona IS TRUE
  WHERE dealer.zona_fiscal in ('PEN','CAN','MEL')
    -- AND DATE_ADD(altas.activacion_date, INTERVAL 1 MONTH) <=
    --DATE_ADD(fecha_inicio, INTERVAL meses MONTH) <= fecha_fin

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

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2B_CAMPANA_FDZ_MB` AS (

-- SELECT *,
--   'ARM21' ||'_'|| id_mes_pr ||'_'||row_number () over () AS commission_id
--  FROM `mm-commissions-reporting.TEMP.B2B_CAMPANA_FDZ_MB`

-- );

END