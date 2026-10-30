begin

declare sql , prefijo , mes_string string;

declare canales_pr ARRAY <STRING> DEFAULT ['DO','DOT'];

set prefijo = 'DORP';

set mes_string = cast(mes_int as string);

-- call `mm-commissions-reporting.COMISIONES.pr_dorp` (202609);

CREATE OR REPLACE TABLE
  `mm-commissions-reporting.TEMP.dorp` AS
SELECT
  a.* EXCEPT (concepto,
    comision,
    commission_id,
    mes_liquidado,
    facturador,
    tipo_concepto,
    comments,
    id_mes,
    sociedad,
    bp,
    cuenta_contable,
    centro_coste,
    documento_sap,
    documento_sap_posicion,
    fecha_contabilizacion,
    creado,
    modificado,
    id_factura_drive,
    emails_acceso_trazabilidad,
    id_registro,
    invoice_id


),
 
  -- 'DORP'||'_'||mes_string||'_'||a.canal||'_'||row_number () OVER () AS commission_id,
  CURRENT_TIMESTAMP() AS creado,
  CURRENT_TIMESTAMP() AS modificado,
  CASE
    WHEN c.concepto = 'D - Rappel'   
      and bundle_type = 'FMC'    AND a.marca IN ('MASMOVIL','YOIGO','ORANGE','JAZZTEL','SIMYO') then b.rappel
    WHEN c.concepto = 'D - Rappel'   
      AND a.marca IN ('JAZZTEL') 
      AND a.tariff_id like 'JZZ3347%' then b.rappel
    WHEN upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and c.concepto = 'D - Incentivo multimarca'        then b.incentivo_multimarca
    WHEN a.activation_date < '2024-02-01'
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and c.concepto = 'D - Incentivo televenta'         then b.incentivo_televenta
    WHEN a.activation_date >= '2024-02-01'
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and a.marca != 'YOIGO'
      and a.id_comisionista NOT IN ('TLVOU001','SL')
      and c.concepto = 'D - Incentivo televenta'         then b.incentivo_televenta
    WHEN c.concepto = 'D - Incentivo multimarca total'   then b.incentivo_multimarca_total
    WHEN a.activation_date >= '2024-05-01' 
      AND UPPER(tariff_ds) NOT LIKE '%INDIREC%' 
      AND UPPER(tariff_ds) NOT LIKE '%ADSL%' 
      AND a.bundle_type = 'FMC'
      AND a.marca != 'YOIGO'
      AND c.concepto = 'D - Incentivo 3p fibra directa'  then b.incentivo_3p_fibra_directa 
  end  AS comision,

  c.concepto,

  c.tipo_concepto,

  COMISIONES.f_mes_int (mes_int) AS mes_liquidado,
  mes_int AS id_mes, 
  'C_MANUAL' AS facturador,

  cast (null as string ) as comments

FROM
  `mm-commissions-reporting.COMISIONES.transacciones` a
INNER JOIN
  `mm-commissions-reporting.GS.MARCO_RAPPEL_DO` b
ON
  a.id_comisionista=b.id_comisionista
  AND b.id_mes = mes_int
  AND a.marca = b.marca
CROSS JOIN
  `mm-commissions-reporting.GS.CONCEPTOS` c
WHERE
  a.canal IN  ('DO','DOT')
  AND c.proceso like '%DORP%'
  AND a.concepto = 'A - Servicio Fijo'
  AND a.id_mes = mes_int
  and
  CASE
    WHEN c.concepto = 'D - Rappel'   
      and bundle_type = 'FMC'                            then b.rappel
    WHEN c.concepto = 'D - Rappel'   
      and tariff_id like 'JZZ3347%'                      then b.rappel
    WHEN upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and c.concepto = 'D - Incentivo multimarca'        then b.incentivo_multimarca
    WHEN a.activation_date < '2024-02-01'
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and c.concepto = 'D - Incentivo televenta'         then b.incentivo_televenta
    WHEN a.activation_date >= '2024-02-01'
      and upper(tariff_ds) not like '%INDIREC%' 
      and upper(tariff_ds) not like '%ADSL%' 
      and a.marca != 'YOIGO'
      and a.id_comisionista != 'TLVOU001'
      and c.concepto = 'D - Incentivo televenta'         then b.incentivo_televenta
    WHEN c.concepto = 'D - Incentivo multimarca total'   then b.incentivo_multimarca_total
    WHEN a.activation_date >= '2024-05-01' 
      AND UPPER(tariff_ds) NOT LIKE '%INDIREC%' 
      AND UPPER(tariff_ds) NOT LIKE '%ADSL%' 
      AND a.bundle_type = 'FMC'
      AND a.marca != 'YOIGO'
      AND c.concepto = 'D - Incentivo 3p fibra directa'  then b.incentivo_3p_fibra_directa
  end > 0
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.rappel_trimestral_DO` AS (
SELECT
    -- 'DORP' || '_' || 202605 || '_' || a.canal || '_' || ROW_NUMBER() OVER() AS commission_id,
    'calculado' AS estado,
    a.agrupacion_canal,
    a.canal,

    1 AS unidades,
    
    a.id_comisionista,
    a.distribuidor,
    a.sfid_id,
    a.seller,
    a.nombre_comercio,
    a.razon_social,
    a.cif,
    a.zona_fiscal,
    '' AS cond_pago,
    a.marca,
    a.service_type,
    a.phone_nm,
    a.tariff_id,
    a.tariff_ds,
    a.service_id,
    a.account_id,
    a.customer_id,
    a.line_type_ds,
    a.bundle_type,
    a.technology_ds,
    a.billing_type_ds,
    a.sale_date,
    a.activation_date,
    a.deactivation_date,
    a.order_id,
    a.order_type_agg,
    a.cod_segmento,
    a.cod_marca,
    a.cod_tipo_contrato,
    a.cod_producto,
    a.cod_canal,
    CAST(NULL AS STRING) AS campaign_code,
    CAST(NULL AS STRING) AS serial_number,
    CAST(NULL AS FLOAT64) AS tax_base,
    CAST(NULL AS STRING) AS claim_code,
    CAST(NULL AS STRING) AS process_code,
    a.sociedad,
    CURRENT_TIMESTAMP() AS creado,
    CURRENT_TIMESTAMP() AS modificado,
    RAPPEL.rappel_trimestral AS comision,--
    'D - Rappel Trimestral' AS concepto,--
    'UPFR' AS tipo_concepto,--
    COMISIONES.f_mes_int (mes_int) AS mes_liquidado,--
    mes_int AS id_mes,--
    'C_MANUAL' AS facturador,
    CAST(NULL AS STRING) AS comments,

FROM `mm-commissions-reporting.COMISIONES.activaciones` a

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` v
    ON a.service_id = v.service_id
   AND a.phone_nm = v.phone_nm
   AND a.service_type = v.service_type

LEFT JOIN `mm-commissions-reporting.GS.MARCO_RAPPEL_DO` RAPPEL
    ON a.id_comisionista = RAPPEL.id_comisionista
   AND a.marca = RAPPEL.marca
   AND RAPPEL.id_mes = mes_int

WHERE a.activation_date IS NOT NULL
  AND a.canal in ('DO','DOT')
  AND a.order_type_agg NOT LIKE '%MIGRACION%'
  AND a.sale_date BETWEEN '2026-04-01' AND '2026-06-30'
  AND (
        v.deactivation_date > DATE_ADD(a.activation_date, INTERVAL 30 DAY)
        OR v.deactivation_date IS NULL
      )
  AND a.marca IN ('YOIGO', 'MASMOVIL', 'ORANGE', 'JAZZTEL')
  AND a.service_type = 'INTERNET'
  AND a.billing_type_ds = 'POSTPAID'

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY service_id, service_type, marca
    ORDER BY
        activation_date DESC,
        CASE
            WHEN COALESCE(a.distribuidor, 'NA') != sfid_id THEN 1
            ELSE 2
        END ASC NULLS LAST
) = 1)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.dorp_final` AS (
SELECT
    'DORP' || '_' || mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id,
    *
FROM (

    SELECT *
    FROM `mm-commissions-reporting.TEMP.dorp`
    WHERE COMISION > 0

    UNION ALL

    SELECT *
    FROM `mm-commissions-reporting.TEMP.rappel_trimestral_DO`
    WHERE COMISION > 0

)
)
;
-- Inserta tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('DORP_', mes_int, canales_pr , 'TEMP.dorp_final' , 'ACTUALIZAR');

end