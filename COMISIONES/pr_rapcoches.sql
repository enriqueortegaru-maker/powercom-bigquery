BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'RPD2';

SET canales_pr = COALESCE(canales_pr, ['D2D','D2N','DEM']);


/*
CALL COMISIONES.pr_rapcoches (202409,['D2N']);
*/



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_base` AS (

SELECT 
  TRANSACCIONES.*

  FROM
  `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

    LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo_activacion` INTRA --- EXCLUIMOS PORTABILIDADES INTRAGRUPO
    ON TRANSACCIONES.phone_nm = CAST (INTRA.phone_nm AS STRING) 
        AND TRANSACCIONES.id_mes = INTRA.mes_activacion
        AND TRANSACCIONES.account_id = INTRA.account_id 
        AND TRANSACCIONES.marca = INTRA.brand_ds

    LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
    ON TRANSACCIONES.service_id = VENTAS.service_id

  where TRANSACCIONES.CANAL IN UNNEST (canales_pr)
  AND cast(TRANSACCIONES.ID_MES as string) = mes_string
  AND TRANSACCIONES.CONCEPTO = 'A - Servicio Fijo' -- SE CONTABILIZAN LOS SERVICIOS FIJOS
  AND TRANSACCIONES.SERVICE_TYPE IN ('INTERNET') 
  AND TRANSACCIONES.tariff_ds NOT LIKE '%ADSL%' -- NO COMISIONA ADSL
  AND TRANSACCIONES.BUNDLE_TYPE IN ('2P','FMC')
  AND TRANSACCIONES.commission_id NOT LIKE '%ABONO%' --DESCARTAMOS PROCESOS POSTERIORES 
  AND TRANSACCIONES.commission_id NOT LIKE '%FACTURA%' --DESCARTAMOS PROCESOS POSTERIORES
  AND DATE_TRUNC(VENTAS.deactivation_date, MONTH) > PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND (INTRA.flag_bundle_intragroup = 'NO Intragrupo' OR INTRA.flag_bundle_intragroup is null)
  )


--- EXCLUIMOS HASTA QUE HAYA UN CAMBIO DE MR ----
/*; 
CREATE OR REPLACE TABLE mm-commissions-reporting.TEMP.rappel_fix_base AS (
   SELECT 
  BASE.*

  FROM
  mm-commissions-reporting.TEMP.rappel_fix_base BASE

  INNER JOIN (SELECT A.customer_id, B.order_type_agg  ----- EXCLUIMOS CLIENTES QUE SEAN TODO ALTAS NUEVAS
              FROM mm-commissions-reporting.TEMP.rappel_fix_base A

              LEFT JOIN mm-commissions-reporting.COMISIONES.v_ventas_comisiones B
                ON A.customer_id = B.customer_id

              WHERE B.order_type_agg NOT LIKE 'ALTA NUEVA' OR (B.order_type_agg NOT LIKE 'ALTA NUEVA' AND B.billing_type_ds NOT LIKE 'PREPAID')
              GROUP BY 1,2) ALTAS
      ON BASE.customer_id = ALTAS.customer_id
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BASE.phone_nm ORDER BY BASE.sale_date DESC) = 1 
      )
*/   
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_contador` AS (
  select 
  id_comisionista,
  sum(UNIDADES) AS SERVICIOS

  from 

  `mm-commissions-reporting.TEMP.rappel_coches_base` 

  group by 1

  order by 2 desc
)

;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_GS` as (
  select 
  c.codigo,
  count(c.gerente) as coches
  from
  mm-commissions-reporting.RappelD2D.RAP_COCHES c
  where
  cast(c.mes as string) =  mes_string 
  group by 1
  )

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches` AS (
  SELECT  
  C.CODIGO,
    c2.servicios,
  'RPD2'||'_'||mes_string||'_'||S.CANAL||'_'||'COCHES'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(CAST(mes_string AS STRING), 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)
    ELSE S.mes_liquidado 
    END AS mes_liquidado,
    CASE 
    WHEN S.CANAL IN ('D2N','DEM') THEN CAST(FORMAT_DATE('%Y%m', DATE_ADD(DATE(CONCAT(SAFE_CAST(SUBSTR(mes_string, 1, 4) AS STRING), '-', SAFE_CAST(SUBSTR(mes_string, 5, 2) AS STRING), '-01')), INTERVAL 1 MONTH)) AS INT64)
    ELSE id_mes_pr
  END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Apoyo Coche' as concepto,
  S.tipo_concepto,
  S.unidades,
  CASE 
    WHEN S.CANAL = 'DEM' AND C2.SERVICIOS < 10 THEN 0 
    WHEN S.CANAL = 'DEM' AND C2.servicios >= 10 THEN (10 * S.UNIDADES)
  ELSE (10 * S.UNIDADES) END AS comision,
  s.id_comisionista,
  S.distribuidor,
  S.sfid_id,
  S.seller,
  S.nombre_comercio,
  S.razon_social,
  S.cif,
  S.zona_fiscal,
  S.marca,
  S.service_type,
  S.phone_nm,
  S.tariff_id,
  S.tariff_ds,
  S.service_id,
  S.account_id,
  S.customer_id,
  S.line_type_ds,
  S.bundle_type,
  S.technology_ds,
  S.billing_type_ds,
  S.sale_date,
  S.activation_date,
  S.deactivation_date,
  S.order_id,
  S.order_type_agg,
  S.cod_segmento,
  S.cod_marca,
  S.cod_tipo_contrato,
  S.cod_producto,
  S.cod_canal,
  'COCHES = '||C.COCHES AS claim_code,
  S.campaign_code,
  'COCHES_'||S.CANAL||'_'|| mes_string  AS process_code,
  S.comments,
  S.facturador,
  S.proceso_sap,
  S.id_registro,
  S.invoice_id,
  S.sociedad,
  S.bp,
  S.cuenta_contable,
  S.centro_coste,
  S.documento_sap,
  S.documento_sap_posicion,
  S.fecha_contabilizacion,
  S.creado,
  S.modificado,
  S.id_factura_drive,
  '' as emails_acceso_trazabilidad


  FROM
  `mm-commissions-reporting.TEMP.rappel_coches_base` s

  left join `mm-commissions-reporting.TEMP.rappel_coches_GS` C
    ON S.ID_COMISIONISTA = C.codigo
  
  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_coches_contador` C2
    ON S.ID_COMISIONISTA = C2.ID_COMISIONISTA
  
  )
;
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches_resul_desc` as (
  select 
  sfid_id,
  substr(claim_code,9,2) as coches,
  sum(comision) as tot_comi 
  from `mm-commissions-reporting.TEMP.rappel_coches` r 
  WHERE 
  COMISION IS NOT NULL 
  and COMISION <> 0 
  AND CODIGO IS NOT NULL 
  group by 1,2)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_coches` AS(
SELECT  
  r.commission_id,
  r.estado,
  r.mes_liquidado,
  r.id_mes,
  'D2D' as agrupacion_canal,
  r.canal,
  r.concepto,
  r.tipo_concepto,
  r.unidades,
  CASE
    WHEN r2.tot_comi / cast(r2.coches as integer) >= 300 THEN (300 * cast(r2.coches as integer) ) /  r.servicios
  ELSE r.comision
  END AS comision,
  r.id_comisionista,
  r.distribuidor,
  r.sfid_id,
  r.seller,
  r.nombre_comercio,
  r.razon_social,
  r.cif,
  r.zona_fiscal,
  r.marca,
  r.service_type,
  r.phone_nm,
  r.tariff_id,
  r.tariff_ds,
  r.service_id,
  r.account_id,
  r.customer_id,
  r.line_type_ds,
  r.bundle_type,
  r.technology_ds,
  r.billing_type_ds,
  r.sale_date,
  r.activation_date,
  r.deactivation_date,
  r.order_id,
  r.order_type_agg,
  r.cod_segmento,
  r.cod_marca,
  r.cod_tipo_contrato,
  r.cod_producto,
  r.cod_canal,
  r.claim_code,
  r.campaign_code,
  r.process_code,
  r.comments,
  r.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  r.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  R.creado,
  R.modificado,
  '' AS id_factura_drive,
  r.emails_acceso_trazabilidad


  from `mm-commissions-reporting.TEMP.rappel_coches` r 

  LEFT JOIN `mm-commissions-reporting.TEMP.rappel_coches_resul_desc` r2 
    on r.sfid_id = r2.sfid_id 

  WHERE R.COMISION IS NOT NULL 
  and R.COMISION <> 0 
  AND R.CODIGO IS NOT NULL
)

;
  INSERT INTO `mm-commissions-reporting.RappelD2D.Rappel_Fijo` (

   SELECT *
   FROM `mm-commissions-reporting.TEMP.rappel_coches`
   )
;
END