BEGIN

-- DECLARE mes_string STRING;

-- SET mes_string = FORMAT_DATE('%Y%m',id_mes_pr); 
DECLARE prefijo STRING;
SET prefijo = 'ARCAL';

-- call `mm-commissions-reporting.COMISIONES.pr_comisiones_alea`(202609);

DELETE `mm-commissions-reporting.B2B.comisiones_ALEA` 
WHERE id_mes_pr = CAST(id_mes_pr AS INT64)
;

INSERT INTO  `mm-commissions-reporting.B2B.comisiones_ALEA`

  WITH 
    base AS (
      SELECT 
        invoice_id,
        DATE_TRUNC(invoice_date, MONTH) AS invoice_date,
        customer_id,
        CASE
          WHEN b.ASOMA_T != 0
            AND billing_tier_1 LIKE '%FACTURACION MANUAL%'
          THEN SUM(imp_without_tax)
          WHEN b.TPBS != 0
            AND billing_tier_2 LIKE '%TARIFA PLANA%'
          THEN SUM(imp_without_tax)
          WHEN b.SLRV != 0 
            AND billing_tier_2 LIKE '%TELEFONIA FIJA%' 
          THEN SUM(imp_without_tax)
          WHEN b.DATOS != 0
            AND a.Billing_Tier_2 NOT LIKE '%TARIFA PLANA%' 
            AND a.Billing_Tier_2 NOT LIKE '%TELEFONIA FIJA%'
            AND a.Billing_Tier_2 IS NOT NULL
          THEN SUM(imp_without_tax )
        END AS tax_base,
        CASE
          WHEN b.ASOMA_T != 0
            AND billing_tier_1 LIKE '%FACTURACION MANUAL%'
          THEN 'ASOMA_T'
          WHEN b.TPBS != 0
            AND billing_tier_2 LIKE '%TARIFA PLANA%'
          THEN 'TPBS'
          WHEN b.SLRV != 0 
            AND billing_tier_2 LIKE '%TELEFONIA FIJA%' 
          THEN 'SLRV'
          WHEN b.DATOS != 0
            AND a.Billing_Tier_2 NOT LIKE '%TARIFA PLANA%' 
            AND a.Billing_Tier_2 NOT LIKE '%TELEFONIA FIJA%'
            AND a.Billing_Tier_2 IS NOT NULL
          THEN 'DATOS'
        END AS referencia,
        CASE
          WHEN b.ASOMA_T != 0
            AND billing_tier_1 LIKE '%FACTURACION MANUAL%'
          THEN b.ASOMA_T
          WHEN b.TPBS != 0
            AND billing_tier_2 LIKE '%TARIFA PLANA%'
          THEN b.TPBS
          WHEN b.SLRV != 0 
            AND billing_tier_2 LIKE '%TELEFONIA FIJA%' 
          THEN b.SLRV
          WHEN b.DATOS != 0
            AND a.Billing_Tier_2 NOT LIKE '%TARIFA PLANA%' 
            AND a.Billing_Tier_2 NOT LIKE '%TELEFONIA FIJA%'
            AND a.Billing_Tier_2 IS NOT NULL
          THEN b.DATOS
        END AS porcentaje_comision
  
      FROM `mm-datamart-kd.BILLING.billing_detail_xena` a
      JOIN `mm-commissions-reporting.GS.B2BC_COM_ALEA` b ON a.customer_id = b.id_comisionista
      WHERE 1=1
        AND invoice_id LIKE 'A/%'
        AND CAST(FORMAT_DATE('%Y%m', init_date) AS INT64) = id_mes_pr
        AND company_id = '01'
      GROUP BY invoice_id, invoice_date, customer_id,datos,billing_tier_2,SLRV,TPBS,ASOMA_T,billing_tier_1
        )

  SELECT 
    id_mes_pr as id_mes,
    invoice_id,
    invoice_date,
    customer_id AS id_comisionista,
    'F25152' AS id_comisionista_a_pagar,
    referencia,
    SUM(tax_base) AS tax_base,
    porcentaje_comision,
    SUM(tax_base) * (porcentaje_comision/100) AS comision
  FROM base
  WHERE 1=1
    AND tax_base IS NOT NULL
  GROUP BY ALL

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.comisiones_ALEA_transacc` AS(
  
  SELECT 
    prefijo||'_'||CAST(id_mes_pr AS STRING)||'_'||canal||'_'||row_number () over() AS commission_id
    ,'calculado'  AS estado
    ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
    ,id_mes_pr  AS id_mes
    ,'B2B - Cablemovil'  AS agrupacion_canal
    ,dealer.canal  AS canal
    ,'C - Gestion Cartera'||' - '||alea.referencia||' ('||alea.porcentaje_comision||'%)' AS concepto
    ,'AIRT'  AS tipo_concepto
    ,1  AS unidades
    ,comision AS comision
    ,id_comisionista_a_pagar AS id_comisionista
    ,id_comisionista_a_pagar AS distribuidor
    ,id_comisionista_a_pagar AS sfid_id
    ,id_comisionista_a_pagar AS seller
    ,dealer.nombre_comercio  AS nombre_comercio
    ,dealer.razon_social AS razon_social
    ,dealer.documento  AS cif
    ,dealer.zona_fiscal  AS zona_fiscal
    ,dealer.cond_pago  AS cond_pago
    ,'CABLEMOVIL'  AS marca
    ,'MOBILE' AS service_type
    ,CAST(NULL AS STRING) AS phone_nm
    ,CAST(NULL AS STRING)AS tariff_id
    ,CAST(NULL AS STRING) AS tariff_ds
    ,CAST(NULL AS STRING)AS service_id
    , id_comisionista_a_pagar AS account_id
    , id_comisionista_a_pagar AS customer_id
    ,CAST(NULL AS STRING) AS line_type_ds
    , 'MO' AS bundle_type
    ,CAST(NULL AS STRING) AS technology_ds
    ,CAST(NULL AS STRING) AS billing_type_ds
    , CAST(NULL AS DATE) AS sale_date
    , CAST(NULL AS DATE) AS activation_date
    , CAST(NULL AS DATE) AS deactivation_date
    , CAST(NULL AS STRING) AS order_id
    , CAST(NULL AS STRING) AS order_type_agg
    , '42' AS cod_segmento
    , '05' AS cod_marca
    , '20' AS cod_tipo_contrato
    , '022' AS cod_producto
    , '30' AS cod_canal
    , CAST(NULL AS STRING) AS campaign_code
    , CAST(NULL AS STRING) AS serial_number
    , alea.tax_base AS tax_base
    , CAST(NULL AS STRING)  AS claim_code
    , alea.invoice_id||' - '||alea.id_comisionista||' - '||alea.referencia AS process_code
    , 'Autofactura' AS comments
    , 'C_MANUAL' AS facturador
    , CAST(NULL AS STRING) AS proceso_sap
    , CAST(NULL AS STRING) AS id_registro
    , CAST(NULL AS STRING) AS invoice_id
    , 'X001' AS sociedad
    , CAST(NULL AS STRING) AS bp
    , CAST(NULL AS STRING) AS cuenta_contable
    , CAST(NULL AS STRING) AS centro_coste
    , CAST(NULL AS STRING) AS documento_sap
    , CAST(NULL AS STRING) AS documento_sap_posicion
    , CAST(NULL AS STRING) AS fecha_contabilizacion
    , CURRENT_TIMESTAMP () AS creado
    , CURRENT_TIMESTAMP ()AS modificado
    , CAST(NULL AS STRING) AS id_factura_drive
  FROM `mm-commissions-reporting.B2B.comisiones_ALEA` alea

  LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` dealer
    ON alea.id_comisionista_a_pagar = dealer.id_comisionista
  WHERE comision != 0.0
    AND id_mes = id_mes_pr


  );
call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo,id_mes_pr,['CM','CALT'],'B2B.comisiones_ALEA_transacc','ACTUALIZAR');

END