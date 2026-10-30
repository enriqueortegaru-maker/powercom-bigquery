BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CENT';

SET canales_pr =  ['OUN','DON','CIN','XIN','XSN'];

/*
CALL COMISIONES.pr_centralitas_otros_svas(202606, ['OUN']);
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.centralitas_otros_svas` AS

-- ACTIVACIONES --

SELECT DISTINCT
     'calculado' AS estado
     ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,b.agrupacion_canal
     ,b.canal
     ,CASE WHEN a.sva_modality = 'IP FIJA' THEN 'B - IP Fija'
           WHEN a.sva_modality = 'MASWIFI' THEN 'B - MasWifi'          
           WHEN a.sva_modality = 'MASWIFI PREMIUM' THEN 'B - MasWifi Premium'
     END AS concepto
     ,'OTRS' AS tipo_concepto
     ,1 AS unidades
     ,COMISIONES.f_comision_centralitas_otros_svas(b.canal,a.sva_modality) AS comision
     ,a.sfid_id AS id_comisionista
     ,b.distribuidor
     ,b.sfid AS sfid_id
     ,a.sfid_id AS seller
     ,b.nombre_comercio
     ,b.razon_social
     ,b.documento AS cif
     ,b.zona_fiscal
     ,a.brand_ds AS marca
     ,a.service_type
     ,a.phone_nm
     ,a.sva_service_id AS tariff_id
     ,a.sva_modality AS tariff_ds
     ,a.service_id
     ,a.account_id
     ,a.customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,a.contract_date AS sale_date
     ,a.activation_date
     ,a.deactivation_date
     ,a.order_fix_id AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,CASE 
            WHEN a.channel_segment_ds = 'NEGOCIOS' THEN '12'
            ELSE '10' 
      END AS cod_segmento
     ,CASE 
            WHEN a.brand_ds = 'YOIGO' THEN '01'
            ELSE '05' 
      END AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'999' AS cod_producto
     ,CASE 
            WHEN b.canal IN ('OUN','DON','XSN') THEN '15'
            WHEN b.canal IN ('CIN','XIN')       THEN '14'

      END AS cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad
     ,CURRENT_TIMESTAMP AS creado

FROM `mm-soho-reporting.TEMPORALES_SOHO.sva_unificado` a

CROSS JOIN UNNEST(canales_pr) canal_pr 

LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer` b
  ON a.sfid_id = b.id_comisionista AND b.id_mes = id_mes_pr

WHERE sva_modality IN ('IP FIJA', 'MASWIFI','MASWIFI PREMIUM')
AND sva_status_ds = 'ACTIVO'
AND DATE_TRUNC(DATE(a.activation_date), month) = COMISIONES.f_mes_int (id_mes_pr)
AND a.sfid_id NOT IN ('TLVN015','TLVN020','TLVN027') 
AND a.sfid_id NOT LIKE 'CANEGI%'
AND b.canal = canal_pr
;


-- DESACTIVACIONES --

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.clawbacks_centralitas_otros_svas` AS

SELECT *
FROM
      (SELECT DISTINCT
      'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,b.agrupacion_canal
      ,b.canal
      ,CASE WHEN a.sva_modality = 'IP FIJA'         THEN 'E - Clawback IP Fija'
            WHEN a.sva_modality = 'MASWIFI'         THEN 'E - Clawback MasWifi'          
            WHEN a.sva_modality = 'MASWIFI PREMIUM' THEN 'E - Clawback MasWifi Premium'
     END AS concepto
      ,'OTRS' AS tipo_concepto
      ,1 AS unidades
      ,COMISIONES.f_comision_clawback(DATE_DIFF(a.deactivation_date, a.activation_date, DAY)+1,b.canal,a.sva_modality) * COMISIONES.f_comision_centralitas_otros_svas(b.canal,a.sva_modality) AS comision
      ,a.sfid_id AS id_comisionista
     ,b.distribuidor
     ,b.sfid AS sfid_id
     ,a.sfid_id AS seller
     ,b.nombre_comercio
     ,b.razon_social
     ,b.documento AS cif
     ,b.zona_fiscal
     ,a.brand_ds AS marca
     ,a.service_type
     ,a.phone_nm
     ,a.sva_service_id AS tariff_id
     ,a.sva_modality AS tariff_ds
     ,a.service_id
     ,a.account_id
     ,a.customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,a.contract_date AS sale_date
     ,a.activation_date
     ,a.deactivation_date
     ,a.order_fix_id AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,CASE 
            WHEN a.channel_segment_ds = 'NEGOCIOS' THEN '12'
            ELSE '10' 
      END AS cod_segmento
     ,CASE 
            WHEN a.brand_ds = 'YOIGO' THEN '01'
            ELSE '05' 
      END AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'999' AS cod_producto
     ,CASE 
            WHEN b.canal IN ('OUN','DON','XSN') THEN '15'
            WHEN b.canal IN ('CIN','XIN')       THEN '14'

      END AS cod_canal
     ,CAST(NULL AS STRING)  AS campaign_code
     ,CAST(NULL AS STRING)  AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad
     ,CURRENT_TIMESTAMP AS creado

     FROM `mm-soho-reporting.TEMPORALES_SOHO.sva_unificado` a

      CROSS JOIN UNNEST(canales_pr) canal_pr 

      LEFT JOIN `mm-commissions-reporting.COMISIONES.dealer` b
        ON a.sfid_id = b.id_comisionista AND b.id_mes = id_mes_pr

      WHERE sva_modality IN ('IP FIJA', 'MASWIFI','MASWIFI PREMIUM')
      AND sva_status_ds = 'BAJA'
      AND DATE_TRUNC(a.activation_date, month) = COMISIONES.f_mes_int (id_mes_pr)
      AND DATE_TRUNC(a.deactivation_date, month) = COMISIONES.f_mes_int (id_mes_pr) -- COMENTAR SI SE NECESITA LANZAR UN MES ANTERIOR AL ID_MES_PR
      -- AND DATE_TRUNC(a.deactivation_date, month) >= COALESCE(COMISIONES.f_mes_int (id_mes_pr), a.activation_date) -- DESCOMENTAR SI SE NECESITA LANZAR UN MES ANTERIOR AL ID_MES_PR
      AND a.sfid_id NOT IN ('TLVN015','TLVN020','TLVN027') 
      AND a.sfid_id NOT LIKE 'CANEGI%'
      AND b.canal = canal_pr

      )
WHERE comision != 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.centralitas_otros_svas` AS
(
SELECT
      *
     ,prefijo ||'B'|| '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id

FROM TEMP.centralitas_otros_svas
)
;

CREATE OR REPLACE TABLE TEMP.clawbacks_centralitas_otros_svas AS
(
SELECT
      *
     ,prefijo ||'E'|| '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id

FROM TEMP.clawbacks_centralitas_otros_svas
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CENTB', id_mes_pr, canales_pr , 'TEMP.centralitas_otros_svas' , 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CENTE', id_mes_pr, canales_pr , 'TEMP.clawbacks_centralitas_otros_svas' , 'ACTUALIZAR');


END