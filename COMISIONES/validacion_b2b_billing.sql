BEGIN


DECLARE sql STRING;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.validacion_b2b_billing` AS

WITH conceptos_tr AS (

  SELECT canal, 
    CASE 
      WHEN canal = 'CM' AND LENGTH(campaign_code) - LENGTH(REPLACE(campaign_code, '-', '')) = 2  THEN REGEXP_EXTRACT(campaign_code, r'.* - .* - (.+)')
      WHEN canal = 'CM'  THEN REGEXP_EXTRACT(campaign_code, r'- (.+)')
      WHEN canal = 'PAR' THEN REGEXP_EXTRACT(campaign_code, r'/(.+)')
      ELSE campaign_code
    END AS campaign_code
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE canal IN ('PAR','ALT','JOI','MB','MBA','CM','CALT','SW')
    AND canal IN UNNEST (canales_pr)
    AND estado != 'calculado'
    AND NOT REGEXP_CONTAINS(CAST(campaign_code AS STRING), r'^-?\d+(\.\d+)?$')
    AND NOT REGEXP_CONTAINS(CAST(campaign_code AS STRING), r'^-?\d+(\,\d+)?$')
  GROUP BY ALL
)

SELECT billing_tier_1, billing_tier_2
FROM `mm-datamart-kd.BILLING.billing_detail_net` a
LEFT JOIN conceptos_tr b ON b.campaign_code = a.billing_tier_1
WHERE comm_brand_ds = 
                CASE
                  WHEN 'PAR' IN UNNEST (canales_pr) THEN 'PARLEM'
                  WHEN 'ALT' IN UNNEST (canales_pr) THEN 'ALTERNA'
                  WHEN 'JOI' IN UNNEST (canales_pr) THEN 'JOI'
                  WHEN 'MB'  IN UNNEST (canales_pr) THEN 'MARBLANCA'
                  WHEN 'CM'  IN UNNEST (canales_pr) THEN 'CABLEMOVIL'
                  WHEN 'SW'  IN UNNEST (canales_pr) THEN 'SWENO'
                  ELSE NULL
                END 
  AND invoice_date = DATE_TRUNC(CURRENT_DATE(), MONTH)
  AND imp_without_tax != 0
  AND NOT(billing_tier_1 LIKE '%RESTABLECIMIENTO DEL SERVICIO%'
        OR billing_tier_1 LIKE '%VISITA TECNICO%'
        OR billing_tier_1 LIKE '%SIM%'
        --OR billing_tier_1 LIKE '%IMPAGO%'
        OR billing_tier_1 LIKE '%CREDITO FACTURA SIGUIENTE%'
        OR billing_tier_1 LIKE '%ATC%'
        OR billing_tier_1 LIKE '%DUPLICADO%'
        OR billing_tier_1 LIKE '%AVERIA%'
        OR billing_tier_1 LIKE '%IMPAGO DE FACTURA%'
        OR billing_tier_1 LIKE "PENALIZACION %"
        OR bill_id        LIKE "PENALIZACION %"
        --SWENO
        OR billing_tier_1 LIKE '%TV%'
        OR billing_tier_1 LIKE '%CORTE DE SERVICIO%'
        OR billing_tier_1 LIKE '%VISITA TECNICO%'
        OR billing_tier_1 LIKE '%SIM%'
        OR billing_tier_1 LIKE '%7%'
        OR billing_tier_1 LIKE '%OPIT%'
        )
  AND b.campaign_code IS NULL
GROUP BY ALL
ORDER BY 1 
;

END