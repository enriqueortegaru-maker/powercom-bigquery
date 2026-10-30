BEGIN


DECLARE prefijo, mes_string STRING;
--- LOCAL
--DECLARE id_mes_pr INT64; SET id_mes_pr=202502;
SET mes_string = CAST(id_mes_pr AS STRING);
SET prefijo = 'NENRG_';



--CALL COMISIONES.pr_energy_luz_norte(202502);



---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.enrgn_activations`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(

WITH CONCEPTOS AS (
           SELECT CONCEPTOS.* EXCEPT(proceso), proceso
           FROM `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS, UNNEST(SPLIT(proceso, ',')) proceso 
)

SELECT
     prefijo||'BNEN_'||mes_string ||'_'|| DEALER.canaln ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,IMPORTE.marco_energia
     ,DEALER.agrupacion_canal
     ,DEALER.canaln as canal
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,1 AS unidades
     ,IMPORTE.comision
     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,'EUSKALTEL' AS marca
     ,'ENERGY' AS service_type
     ,CAST(LUCERA.phone AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,LUCERA.initial_lucera_tariff_name AS tariff_ds
     ,CAST(LUCERA.id AS STRING) AS service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,LUCERA.signup_date AS sale_date
     ,LUCERA.activation_date
     ,LUCERA.churn_date AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,CAST(NULL AS STRING) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'014' AS cod_producto
     ,CAST(NULL AS STRING) AS cod_canal
     ,CAST(NULL AS STRING) AS campaign_code
     ,LUCERA.cups_code AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad


FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity` LUCERA

LEFT JOIN CONCEPTOS
          ON CONCEPTOS.proceso = 'ENRGN'
             AND SUBSTR(CONCEPTOS.concepto,1,1) = 'B'
             AND CASE WHEN (LUCERA.initial_lucera_tariff_name LIKE '%Batman%' or contains_substr(LUCERA.affiliate_code,'batman'))  THEN 'B - Energia Batman' 
                 ELSE 'B - Energia' 
                 END = CONCEPTOS.concepto

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_krt` DEALER
         ON LUCERA.sfid_id = DEALER.sfid_id --AND DEALER.id_mes = id_mes_pr

/*LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` IMPORTE
         ON DEALER.agrupacion_canal = IMPORTE.agrupacion_canal AND DEALER.canaln = IMPORTE.canal AND CONCEPTOS.concepto = IMPORTE.concepto
            AND id_mes_pr BETWEEN IMPORTE.id_mes_ini AND IMPORTE.id_mes_fin
            AND IMPORTE.duplicado = 1
*/

LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_CANALES` CANAL
         ON UPPER(TRIM(CANAL.agrupacion_canal))=UPPER(TRIM(DEALER.agrupacion_canal)) AND UPPER(TRIM(CANAL.canal))=UPPER(TRIM(DEALER.canaln))
LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` IMPORTE
         ON UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(IMPORTE.marco_energia)) AND UPPER(TRIM(CONCEPTOS.concepto)) = UPPER(TRIM(IMPORTE.concepto))
            AND id_mes_pr BETWEEN IMPORTE.id_mes_ini AND IMPORTE.id_mes_fin
            AND IMPORTE.duplicado = 1



WHERE UPPER(TRIM(LUCERA.tenant_code))='EUSKALTEL'
      AND LUCERA.churn_date IS NULL
      AND DATE_TRUNC(DATE(LUCERA.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      --AND state = 'activa'
      AND DEALER.sfid_id IS NOT NULL
      AND IMPORTE.comision IS NOT NULL


QUALIFY RANK() OVER (PARTITION BY LUCERA.cups_code ORDER BY LUCERA.sfid_id DESC) =  1

UNION ALL 

SELECT
     prefijo||'RNEN_'|| mes_string ||'_'|| DEALER.canaln ||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
     ,id_mes_pr AS id_mes
     ,IMPORTE.marco_energia     
     ,DEALER.agrupacion_canal
     ,DEALER.canaln
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,1 AS unidades
     ,IMPORTE.comision
     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,UPPER(SPLIT(author_id, "@")[OFFSET(0)]) AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal
     ,'R' AS marca
     ,'ENERGY' AS service_type
     ,CAST(LUCERA.phone AS STRING) AS phone_nm
     ,CAST(NULL AS STRING) AS tariff_id
     ,LUCERA.initial_lucera_tariff_name AS tariff_ds
     ,CAST(LUCERA.id AS STRING) AS service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,LUCERA.signup_date AS sale_date
     ,LUCERA.activation_date
     ,LUCERA.churn_date AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'10' AS cod_segmento
     ,CAST(NULL AS STRING) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'014' AS cod_producto
     ,CAST(NULL AS STRING) AS cod_canal
     ,CAST(NULL AS STRING) AS campaign_code
     ,LUCERA.cups_code AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador
     ,'X001' AS sociedad


FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity` LUCERA

LEFT JOIN CONCEPTOS
          ON CONCEPTOS.proceso = 'ENRGN'
             AND SUBSTR(CONCEPTOS.concepto,1,1) = 'B'
             AND CASE WHEN (LUCERA.initial_lucera_tariff_name LIKE '%Batman%' or contains_substr(LUCERA.affiliate_code,'batman'))  THEN 'B - Energia Batman' 
                 ELSE 'B - Energia' 
                 END = CONCEPTOS.concepto
                 

LEFT JOIN (

          SELECT 
          distinct 
          id_mes_pr,
          channel_ds as agrupacion_canal,
          CAST(sfid_id AS STRING) sfid_id,
          vertical_focus_ds as id_comisionista,
          vertical_focus_ds as nombre_comercio,  
          distributor_ds as distribuidor,
          distributor_ds as razon_social,  
          subchannel_ds as canaln,
          `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`('R', distributor_ds)as cif,
          'PEN' as zona_fiscal 
          FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_MM_DM_AUX_SIEBEL`

          ) DEALER
         ON LUCERA.sfid_id = DEALER.sfid_id --AND DEALER.id_mes = id_mes_pr

/*
LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` IMPORTE
         ON DEALER.agrupacion_canal = IMPORTE.agrupacion_canal AND DEALER.canaln = IMPORTE.canal AND CONCEPTOS.concepto = IMPORTE.concepto
            AND id_mes_pr BETWEEN IMPORTE.id_mes_ini AND IMPORTE.id_mes_fin
            AND IMPORTE.duplicado = 1
*/

LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_CANALES` CANAL
         ON UPPER(TRIM(CANAL.agrupacion_canal))=UPPER(TRIM(DEALER.agrupacion_canal)) AND UPPER(TRIM(CANAL.canal))=UPPER(TRIM(DEALER.canaln))
LEFT JOIN `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_MARCO` IMPORTE
         ON UPPER(TRIM(CANAL.marco_energia)) = UPPER(TRIM(IMPORTE.marco_energia)) AND UPPER(TRIM(CONCEPTOS.concepto)) = UPPER(TRIM(IMPORTE.concepto))
            AND id_mes_pr BETWEEN IMPORTE.id_mes_ini AND IMPORTE.id_mes_fin
            AND IMPORTE.duplicado = 1

WHERE UPPER(TRIM(LUCERA.tenant_code))='R'
      AND LUCERA.churn_date IS NULL
      AND DATE_TRUNC(DATE(LUCERA.activation_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
      --AND state = 'activa'
      AND DEALER.sfid_id IS NOT NULL
      AND IMPORTE.comision IS NOT NULL


QUALIFY RANK() OVER (PARTITION BY LUCERA.cups_code ORDER BY LUCERA.sfid_id DESC) =  1


)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
SELECT 
id_mes,
commission_id,
marco_energia,
agrupacion_canal,
canal,
COD_CANAL,
agrupacion_canal as canal_ds,
canal as subcanal_ds,
concepto,
tipo_concepto,
unidades,
COMISION,
id_comisionista,
distribuidor,
sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
zona_fiscal,
marca,
service_type,
phone_nm,
tariff_id,
tariff_ds,
service_id,
account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
sale_date,
activation_date,
deactivation_date,
order_id,
order_type_agg,
cod_segmento,
cod_tipo_contrato,
cod_producto,
cod_marca,
claim_code,
campaign_code,
serial_number,
tax_base,
process_code,
comments,
facturador,
estado,
FROM `mm-commissions-reporting.TEMP.enrgn_activations`;


----- CREA EXTRACOMISION REPARTO

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_LUZ_reparto_norte`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS

with rep as (
      select distinct a.agrupacion_canal,a.canal,a.distribuidor,a.sfid_id, 
      --F1
      case when UPPER(TRIM(r.sfid_id)) ='X' THEN  count(a.service_id) over(partition by a.agrupacion_canal,a.canal,a.distribuidor, a.sfid_id)  
      else count(a.service_id) over(partition by r.agrupacion_canal,r.canal,r.distribuidor)
      END as nprxsfid, 
      --F2
      SAFE_DIVIDE(
      avg(importe) over(partition by r.agrupacion_canal,r.canal,r.distribuidor),
      count(a.service_id) over(partition by r.agrupacion_canal,r.canal,r.distribuidor)
      ) as impxpr,

      SAFE_MULTIPLY(
            case when UPPER(TRIM(r.sfid_id)) ='X' THEN  count(a.service_id) over(partition by a.agrupacion_canal,a.canal,a.distribuidor, a.sfid_id)  
            else count(a.service_id) over(partition by r.agrupacion_canal,r.canal,r.distribuidor)
            END, 
            --F2
            SAFE_DIVIDE(
            avg(importe) over(partition by r.agrupacion_canal,r.canal,r.distribuidor),
            count(a.service_id) over(partition by r.agrupacion_canal,r.canal,r.distribuidor)
            )
      ) as impacxsfid

      FROM  `mm-commissions-reporting.TEMP.enrgn_activations` a 
      inner join `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_REPARTO` r
      on a.agrupacion_canal=r.agrupacion_canal 
      and a.canal=r.canal
      and case when not UPPER(TRIM(r.distribuidor))='X' THEN UPPER(TRIM(r.distribuidor))=UPPER(TRIM(a.distribuidor)) ELSE TRUE END
      and case when not UPPER(TRIM(r.sfid_id))='X' THEN r.sfid_id=a.sfid_id ELSE TRUE END
      order by 1,2,3,4
)
SELECT 
id_mes,
--commission_id,
prefijo||'RPEN_'|| mes_string ||'_'|| a.canal ||'_'||ROW_NUMBER () OVER () AS commission_id,
a.marco_energia,
a.agrupacion_canal,
a.canal,
COD_CANAL,
a.agrupacion_canal as canal_ds,
a.canal as subcanal_ds,
--concepto,
'D - Extra' as concepto,
-- tipo_concepto a actualizar desconozco el asociado a D - Extra
tipo_concepto,
unidades,
ROUND(r.impxpr,4) as comision,
id_comisionista,
a.distribuidor,
a.sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
zona_fiscal,
marca,
service_type,
phone_nm,
tariff_id,
tariff_ds,
service_id,
account_id,
customer_id,
line_type_ds,
bundle_type,
technology_ds,
billing_type_ds,
sale_date,
activation_date,
deactivation_date,
order_id,
order_type_agg,
cod_segmento,
cod_tipo_contrato,
cod_producto,
cod_marca,
claim_code,
campaign_code,
serial_number,
tax_base,
process_code,
comments,
facturador,
estado,
FROM `mm-commissions-reporting.TEMP.enrgn_activations` a 
inner join rep r 
on a.agrupacion_canal=r.agrupacion_canal 
and a.canal=r.canal
and a.distribuidor=r.distribuidor
and a.sfid_id=r.sfid_id
;




END