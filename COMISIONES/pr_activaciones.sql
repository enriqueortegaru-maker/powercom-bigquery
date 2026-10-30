begin

-- call `mm-commissions-reporting.COMISIONES.pr_activaciones`(202610)

call `mm-commissions-reporting.COMISIONES.pr_dealer_ultima_version`(id_mes_pr) ;
call `mm-commissions-reporting.COMISIONES.pr_tarifas_ultima_version`(id_mes_pr);

begin transaction;


delete `mm-commissions-reporting.COMISIONES.activaciones`
where id_mes = id_mes_pr;

insert into `mm-commissions-reporting.COMISIONES.activaciones`
select
  id_mes_pr as id_mes,
  CASE WHEN a.comisionamiento = 'Comisiona' AND NOT b.comisiona THEN CONCAT('No Comisiona - sfid: ', a.seller) ELSE a.comisionamiento END AS comisionamiento,
  a.marca ,
  a.brand_ds ,
  a.service_id ,
  a.account_id ,
  a.customer_id ,
  a.service_type ,
  a.line_type_ds ,
  a.bundle_type ,
  a.technology_ds ,
  a.billing_type_ds ,
  a.phone_nm ,
  a.sale_date ,
  a.activation_date ,
  COALESCE(a.deactivation_date, '9999-12-31') AS deactivation_date ,
  a.order_id ,
  CASE WHEN a.order_type_agg = 'ALTA POR CAMBIO DE DOMICLIO' THEN 'CAMBIO DOMICILIO' ELSE a.order_type_agg END AS order_type_agg ,
  a.tariff_id ,
  -- a.tariff_ds ,
  CASE WHEN PROV.ftth_territoryowner IN (SELECT Territory_Owner FROM `mm-commissions-reporting.COMISIONES.maestro_territoyowner` WHERE Tipo_Huella = 'INDIRECTA' AND  Territory_Owner NOT LIKE '%SURF') THEN 'INDIRECTA '||a.tariff_ds 
       ELSE a.tariff_ds --- AÑADIMOS FIBRAS INDIRECTAS A PARTIR DEL TO
    END AS tariff_ds,
  a.cod_segmento ,
  a.cod_marca ,
  a.cod_tipo_contrato ,
  a.cod_producto ,
  a.cod_canal ,

  ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
  TLV_CAMP.campaign AS campaign_code,

  CASE 
      WHEN A.marca = 'SIMYO' AND b.CANAL= 'ALTN' THEN a.sfid_id 
      WHEN A.marca IN ('ORANGE','JAZZTEL','SIMYO') AND b.CANAL IN ('ENKO','ENXO') THEN a.sfid_id 
      ELSE a.seller 
  END AS seller,

  
  a.order_fix_id ,
  a.claim_code ,
  a.comments ,
  a.data_source_ds ,
  a.sociedad ,
  a.seller_formato_tms ,
  a.agrupacion_canal as agrupacion_canal_ventas_base ,
  coalesce (b.agrupacion_canal , a.agrupacion_canal) as agrupacion_canal,
  b.id_comisionista,
  CASE WHEN B.CANAL = 'PH' THEN 'PHH00000' ELSE b.distribuidor END AS distribuidor,
  b.canal ,
  b.comisiona ,
  b.nombre_comercio ,
  b.razon_social ,
  b.cif ,
  b.zona_fiscal ,
  b.comentarios ,
  b.cif_gpv ,
  b.creado_por ,
  b.creado ,
  a.sfid_id as sfid_original,
  -- coalesce ( b.sfid_id , a.sfid_id) as sfid_id,
  CASE WHEN A.marca ='SIMYO' AND b.CANAL= 'ALTN' THEN a.user_store ELSE COALESCE ( b.sfid_id , a.sfid_id) END AS sfid_id,
  a.portability_group_donor ,
  a.portability_operator_donor ,
  a.billing_tier,
  CAST(NULL AS STRING) AS sfid_digo
-- from `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` a
from `mm-commissions-reporting.COMISIONES.ventas_comisiones` a
-- left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version`  b on
left join `mm-commissions-reporting.COMISIONES.dealer_ultima_version` b on
     ( a.sfid_id = b.sfid_id 
  -- or (a.seller_formato_tms = b.sfid_id AND a.agrupacion_canal NOT IN ('No Exclusivo'))
  or a.seller = b.sfid_id
  or a.sfid_id    || '-' || a.seller = replace ( b.sfid_id , ' ', '') 
  or a.user_store = b.sfid_id)

-- LEFT JOIN (SELECT * FROM `mm-commissions-reporting.GS.DIS_digo_unico` WHERE sfid_id != sfid_digo) DIGO
--          ON b.id_comisionista = DIGO.sfid_id

LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` TLV_CAMP
  ON b.id_comisionista = TLV_CAMP.id_comisionista 
  AND b.canal = TLV_CAMP.canal


LEFT JOIN `mm-datamart-kd.ACCESS_PROVISION.provision_base` AS PROV
      ON PROV.workorder_id = a.order_fix_id

LEFT JOIN `mm-sales-reporting.SPEEDUP.query_bundles_intragrupo` I
ON a.account_id = I.account_id
AND a.phone_nm = CAST(I.phone_nm AS STRING)
AND  I.mes_venta = id_mes_pr

where 1=1
and ( a.billing_type_ds = 'POSTPAID' or (a.billing_type_ds = 'PREPAID' and b.canal in ('DOT','WA','BO','CI','XI','XIBO','FNAC_NR','MKT_NR')))
and (COALESCE(a.seller, 'a') NOT LIKE 'MLV%' OR COALESCE(a.seller, 'a')  NOT LIKE '%RPORT' OR COALESCE(a.seller, 'a')  NOT LIKE '%RBAJA') --<----- sfid de baja que se coge sin querer cuando se sacan los dealers de Exclusivo
--and b.agrupacion_canal ='Guuk'
--and b.comisiona
and date_trunc (a.activation_date, month) = COMISIONES.f_mes_int ( id_mes_pr )

AND (
    b.agrupacion_canal IN ('TLV - Web', 'TLV - DO', 'TLV - Cross-sell','TLV - Negocios','TLV - Outbound','FFCC', 'ENDESA','NATIONAL RETAIL') AND MARCA IN ('ORANGE','JAZZTEL','SIMYO')
    OR (
        a.agrupacion_canal = b.agrupacion_canal
        OR b.canal = 'AVO'
        OR a.sfid_id = 'CARINWEB'
    )
)

AND NOT (order_type_agg = 'MIGRACION PREPAGO A POSTPAGO' AND b.canal IN ('ENX','EML','EYG','EDB'))
---- CONDICION PARA TLV OUTBOUND (Excluimos prepago procedente de +O para los códigos TLVOU012 Y TLVOU018)
AND NOT (b.CANAL = 'OU' and b.id_comisionista in ('TLVOU012','TLVOU018')AND I.billing_type_donor = 'PREPAID'AND I.grupo_operador_donante_unificado = 'MASORANGE' AND A.service_type = 'MOBILE')
qualify row_number () over (partition by service_id, service_type, brand_ds, activation_date order by case when id_comisionista = seller then 1 else 0 end desc, length(b.id_comisionista) desc nulls last, comisiona desc) = 1
-- and a.agrupacion_canal ='Exclusivo'  --eo
;

insert into `mm-commissions-reporting.COMISIONES.activaciones`
select
 a.id_mes
,a.comisionamiento
,a.marca
,a.brand_ds
,b.service_id
,a.account_id
,a.customer_id
,b.service_type
,b.sell_line_type_ds
,b.sell_bundle_type
,a.technology_ds
,b.billing_type_ds
,cast(b.phone_nm as string) as phone_nm
,b.order_day_id
,b.activation_date
,b.real_deactivation_date
,a.order_id
,a.order_type_agg
,b.sell_tariff_id
,b.sell_tariff_ds
,a.cod_segmento
,a.cod_marca
,a.cod_tipo_contrato
,a.cod_producto
,a.cod_canal

  ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
,tlv_cross_sell.campaign AS campaign_code

,a.seller
,a.order_fix_id
,a.claim_code
,a.comments
,a.data_source_ds
,a.sociedad
,a.seller_formato_tms
,a.agrupacion_canal_ventas_base
,a.agrupacion_canal
,a.id_comisionista
,a.distribuidor
,a.canal
,a.comisiona
,a.nombre_comercio
,a.razon_social
,a.cif
,a.zona_fiscal
,a.comentarios
,a.cif_gpv
,a.creado_por
,a.creado
,a.sfid_original
,a.sfid_id
,a.portability_group_donor
,a.portability_operator_donor
,a.billing_tier
,a.sfid_digo
from `mm-commissions-reporting.COMISIONES.activaciones` a
left join `mm-datamart-kd.SERVICES.ventas_base_net` b
on a.account_id=b.account_id and a.brand_ds = b.brand_ds and a.customer_id=b.customer_id and b.activation_date >= date_add (a.activation_date, interval -1 month)

LEFT JOIN  `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell 
  ON a.id_comisionista = tlv_cross_sell.id_comisionista 
  AND a.canal = tlv_cross_sell.canal


where a.service_type = 'INTERNET'
and a.brand_ds = 'YOIGO'
and a.canal in ('XSN','XIN','OUN','CIN','DON')
and a.id_mes = id_mes_pr
and b.service_type = 'MOBILE'
and b.sell_bundle_type = 'FMC'
and b.order_type_agg ='MIGRACION CONTRATO'
and b.sell_line_type_ds ='MAIN'
and a.order_type_agg not in ('CAMBIO DOMICILIO')
;
--meto d2d dynamics
insert into `mm-commissions-reporting.COMISIONES.activaciones`
SELECT 
      id_mes_pr as id_mes,
            comisionamiento,  marca, brand_ds, service_id, account_id, customer_id, service_type, 
        sell_line_type_ds AS line_type_ds, sell_bundle_type AS bundle_type, technology_ds, 
        billing_type_ds, phone_nm, sale_date, activation_date, deactivation_date, order_id, 
        order_type_agg,  tariff_id, tariff_ds, cod_segmento, cod_marca, 
        cod_tipo_contrato,
        
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
            service_type, brand_ds, order_type_agg, sell_type, cod_tipo_contrato
        ) AS cod_producto,
        
        '22' as cod_canal, '' as campaign_code, sfid_id as seller,  order_fix_id, claim_code, 
        comments,  data_source_ds, 'OSP' AS sociedad,
  SUBSTRING(seller,1,2) as seller_formato_tms ,
 'FFCC' as agrupacion_canal_ventas_base ,
  --coalesce (b.agrupacion_canal , a.agrupacion_canal) as agrupacion_canal,
  'FFCC' AS agrupacion_canal,
  sfid_id as id_comisionista,
  distribuidor ,
  canal ,
  Comisiona,
  nombre_comercio ,
  razon_social ,
  cif ,
  zona_fiscal ,
  comentarios ,
  cif_gpv ,
  creado_por ,
  creado ,
  sfid_id as sfid_original,
  sfid_id,
 port_in_operator_ds as portability_group_donor ,
 port_in_operator_ds as portability_operator_donor ,
  '' as billing_tier,
  '' as sfid_digo
      FROM (
          SELECT 
            'Comisiona' AS comisionamiento, OSP.brand_ds AS marca, OSP.brand_ds, OSP.service_id, OSP.account_id, OSP.customer_id,
            CASE 
                WHEN OSP.service_type = 'FIX' AND OSP.brand_ds = 'SIMYO' THEN 'INTERNET'
                WHEN OSP.service_type = 'BROADBAND' THEN 'INTERNET' 
                WHEN OSP.service_type is null and  SUBSTRING(cast(osp.phone_nm as string),1,1) in ('6','7') then 'MOBILE'
                ELSE OSP.service_type 
            END AS service_type,
            OSP.sell_line_type_ds, 
            CASE
                WHEN OSP.service_type = 'BROADBAND' THEN 'FMC'
             ELSE 'MO' END AS sell_bundle_type, 
            OSP.technology_ds, OSP.billing_type_ds, CAST(OSP.phone_nm AS STRING) AS phone_nm,
            OSP.order_date AS sale_date, OSP.activation_date, OSP.deactivation_date, OSP.order_id, 
            CASE 
             WHEN coalesce(mo.order_type_agg,OSP.order_type_agg) = 'NEW SIGN UP' THEN 'ALTA NUEVA'
             WHEN coalesce(mo.order_type_agg,OSP.order_type_agg) = 'SIGN UP DUE TO PORTABILITY' THEN 'PORTABILIDAD'
             ELSE coalesce(mo.order_type_agg,OSP.order_type_agg) 
             END as order_type_agg, 
            coalesce(mo.port_in_operator_ds,OSP.port_in_operator_ds) AS port_in_operator_ds,
            CASE 
                WHEN OSP.brand_ds = 'SIMYO' THEN OSP.sell_tariff_id 
                WHEN OSP.brand_ds = 'JAZZTEL' AND OSP.service_type = 'BROADBAND' THEN SUBSTRING(OSP.sell_tariff_id, 1 ,7) -- || COALESCE('-' || OSP.ID_PROMOCION, '')
                WHEN OSP.brand_ds = 'JAZZTEL' AND OSP.technology_ds = 'FIXED LTE' THEN SUBSTRING(OSP.sell_tariff_id, 1 ,7)-- || COALESCE('-' || OSP.ID_PROMOCION, '')
                WHEN OSP.brand_ds = 'JAZZTEL' AND OSP.service_type = 'MOBILE' THEN SUBSTRING(OSP.sell_tariff_id, 1 ,7)
                WHEN OSP.brand_ds = 'ORANGE' THEN CAST(MO.master_tariff_id AS STRING)
                WHEN OSP.brand_ds IN ('EUSKALTEL', 'R', 'TELECABLE') 
                --THEN COALESCE(CONCAT(CAST(OSP.tariff_key AS STRING),'-',CAST(OSP.SELL_BUNDLE_ID AS STRING)),
           --CAST(MO.master_tariff_id AS STRING))
                THEN COALESCE(CONCAT(CAST(OSP.tariff_key AS STRING), IF(OSP.SELL_BUNDLE_ID IS NOT NULL,CONCAT('-', CAST(OSP.SELL_BUNDLE_ID AS STRING)),'')),
            CAST(MO.master_tariff_id AS STRING))

                ELSE CAST(TARIFAS.master_tariff_id AS STRING) 
            END AS tariff_id,
            CASE
                WHEN OSP.brand_ds = 'SIMYO' THEN OSP.sell_tariff_ds 
                WHEN OSP.brand_ds = 'ORANGE' AND OSP.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO' THEN OSP.bundle_name
                WHEN OSP.brand_ds IN ('EUSKALTEL', 'R', 'TELECABLE') THEN coalesce(OSP.sell_bundle_name,TARIFAS.tariff_ds)
                ELSE OSP.sell_bundle_name 
            END AS tariff_ds,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(OSP.segment_ds, OSP.brand_ds) AS cod_segmento,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(OSP.brand_ds) AS cod_marca,
            
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
                OSP.billing_type_ds, OSP.service_type, OSP.sell_bundle_type, OSP.technology_ds, OSP.brand_ds, OSP.sell_line_type_ds
            ) AS cod_tipo_contrato,
            
           -- AGRUPACION.codigo_canal_sap AS cod_canal, AGRUPACION.agrupacion_canal,
            CASE WHEN OSP.brand_ds = 'SIMYO' THEN JERARQUIA.SFID_HIJO ELSE OSP.sfid_id END AS sfid_id,
            OSP.seller, OSP.channel_ds, OSP.order_fix_id, CAST(NULL AS STRING) AS claim_code, CAST(NULL AS STRING) AS comments,
            OSP.contract_id, OSP.data_source_ds, OSP.port_in_operator_ds AS portability_group_donor,
            OSP.port_in_operator_ds AS portability_operator_donor, CAST(NULL AS STRING) AS flag_order, OSP.segment_ds,
            OSP.user_store, OSP.subchannel_ds, OSP.cancellation_date AS cancellation_date, OSP.sell_type, OSP.province, OSP.zip_code,
            OSP.terminal_model, CAST(NULL AS STRING) AS sva_tv, OSP.channel_segment_ds, OSP.channel_ds AS master_channel_ds,
            OSP.channel_type_ds, CAST(NULL AS STRING) AS hash_document_number, OSP.cancellation_reason_agg,
            OSP.cancellation_subreason_agg, CAST(NULL AS DATE) AS max_appointment_date, CAST(NULL AS STRING) AS billing_tier,
            CAST(NULL AS STRING) AS qvantel_service_id, CAST(NULL AS INT64) AS post_pre_flag ,
             personal.document AS document,dealer.distribuidor ,
  dealer.canal ,
  dealer.comisiona ,
  dealer.nombre_comercio ,
  dealer.razon_social ,
  dealer.cif ,
  dealer.zona_fiscal ,
  dealer.comentarios ,
  dealer.cif_gpv ,
  dealer.creado_por ,
  dealer.creado 
         FROM `mm-datamart-kd.SERVICES.sales_mo` MO
          LEFT JOIN  `mm-datamart-kd.JV_ORANGE.ventas_base_telco_osp` OSP
          ON OSP.service_id = MO.service_id AND OSP.brand_ds = MO.brand_ds AND OSP.phone_nm = MO.phone_nm
          LEFT JOIN `mm-commissions-reporting.COMISIONES.jerarquia_tiendas_orange` JERARQUIA ON OSP.seller = JERARQUIA.AGENT_ID
            LEFT JOIN   `mm-datamart-kd.DIMENSIONS.dm_master_tariff_mo` TARIFAS 
  ON OSP.data_source_ds = TARIFAS.data_source_ds
  AND OSP.brand_ds = TARIFAS.brand_ds
  AND MO.master_tariff_id  = TARIFAS.master_tariff_id  

          --  LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tarifas_20260624` TARIFAS_2 
          --      ON TARIFAS_2.tariff_key = cast(OSP.tariff_key as int64) 

            left join `mm-datamart-kd.PERSONAL_INFO.hash_int_customer_personal_info` personal
                on OSP.customer_id = personal.customer_id and OSP.customer_document =personal.document_hash 
                -- left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` dealer on
                   left join `mm-commissions-reporting.COMISIONES.dealer_ultima_version` dealer on 
     ( OSP.sfid_id = dealer.sfid_id 
  or OSP.seller = dealer.sfid_id
  or OSP.sfid_id    || '-' || OSP.seller = replace ( dealer.sfid_id , ' ', '') )

         WHERE OSP.brand_ds IN ('EUSKALTEL', 'R', 'TELECABLE')
          and osp.data_source_ds ='DYNAMICS'
          and date_trunc (OSP.activation_date, month) = COMISIONES.f_mes_int ( id_mes_pr )
          GROUP BY ALL
      )





;
insert into COMISIONES.tarifas 
select 
distinct
a.canal,
a.id_mes,
a.marca,
a.service_type,
a.tariff_id, 
a.tariff_ds,
case when a.service_type = 'MOBILE' then a.line_type_ds end as line_type_ds,
c.pvp,
c.tramo_1,
c.tramo_2,
c.tramo_3,
c.tramo_4,
c.tramo_5,
c.migraciones,
c.traslados,
c.gestion_canal,
c.cuota,
c.consumo,
a.campaign_code,
'pr_activaciones', 
current_timestamp(),
case when a.service_type = 'INTERNET' then a.bundle_type else cast(null as string) end as bundle_type

from `mm-commissions-reporting.COMISIONES.activaciones` a
-- left join `mm-commissions-reporting.COMISIONES.v_tarifas` b 
left join `mm-commissions-reporting.COMISIONES.tarifas_ultima_version` b 
  on a.marca = b.marca and a.service_type=b.service_type and a.tariff_id=b.tariff_id  
  and a.id_mes=b.id_mes and a.canal=b.canal and a.tariff_ds = b.tariff_ds 
  and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (b.line_type_ds,'NA')
left join (select * 
           from `mm-commissions-reporting.COMISIONES.tarifas_ultima_version` 
           qualify row_number () over (partition by canal, marca, service_type, tariff_id, tariff_ds, line_type_ds, campaign_code 
                                       order by id_mes desc,creado desc) = 1 
          )c -- sin id_mes para que traiga los datos del último mes que tenga info
  on a.marca = c.marca and a.service_type = c.service_type and a.tariff_id = c.tariff_id  
  and a.canal = c.canal and a.tariff_ds = c.tariff_ds 
  and case when a.service_type = 'MOBILE' then a.line_type_ds else 'NA' end  = coalesce (c.line_type_ds,'NA')
where b.canal is null
and a.service_type in ('MOBILE','INTERNET')
and a.id_mes = id_mes_pr
-- and a.agrupacion_canal ='Exclusivo' --'eo'
;


UPDATE `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
SET tariff_id = CAST(MAESTRO.TARIFF_KEY AS STRING)
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` VENTAS
LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tarifas_20260123` MAESTRO
  ON VENTAS.sell_service_tariff_id = MAESTRO.TARIFF_ID
 AND VENTAS.sell_tariff_ds = MAESTRO.TARIFF_DES
WHERE ACTIVACIONES.service_id = VENTAS.service_id
  AND ACTIVACIONES.id_mes = id_mes_pr
  AND ACTIVACIONES.tariff_id IS NULL
  AND MAESTRO.TARIFF_KEY IS NOT NULL

;

--- AÑADIMOS INFO EN TARIFF_DS A TARIFAS QUE COMPARTEN DATOS PARA DOL, WEB Y XSELL IN --

UPDATE `mm-commissions-reporting.COMISIONES.activaciones` A
SET tariff_ds = CONCAT(
                  A.tariff_ds,
                  ' (COMPARTIDA CON ',
                  B.sell_tariff_ds,
                  ')'
                )
FROM (
  SELECT 
    A.service_id,
    A.customer_id,
    A.account_id,
    REGEXP_EXTRACT(B.sell_tariff_ds, r'\+\s*(.*)') AS sell_tariff_ds
      FROM `mm-commissions-reporting.COMISIONES.activaciones` A
  LEFT JOIN `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` B
    ON A.service_id = B.service_id
  WHERE A.canal IN ('DO','XI','WA')
    AND A.id_mes = id_mes_pr
    AND A.tariff_id IN ('8145','8187','7126','7115','7108')
    AND A.order_type_agg != 'MIGRACION CONTRATO'
  QUALIFY ROW_NUMBER() OVER (
            PARTITION BY A.customer_id, A.account_id, A.service_id
            ORDER BY B.activation_date DESC
          ) = 1
) B
WHERE A.service_id = B.service_id
  AND A.customer_id = B.customer_id
  AND A.account_id = B.account_id
  AND B.sell_tariff_ds IS NOT NULL

;
/*
--- AÑADIMOS INFO EN TARIFF_DS PARA TARIFAS DE INTERNET DOT (BUNDLE + TERRITORY OWNER NEBA)---
UPDATE `mm-commissions-reporting.COMISIONES.activaciones` ACT
SET tariff_ds = CONCAT(ACT.tariff_ds,' (',ACT.bundle_type,IF(VENTAS.territory_owner = 'FIBRA_NEBA', ' NEBA', ''),')')
FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` VENTAS
WHERE ACT.service_id = VENTAS.service_id
  AND ACT.phone_nm = CAST(VENTAS.phone_nm AS STRING)
  AND ACT.ID_MES = id_mes_pr
  AND ACT.CANAL = 'DOT'
  AND ACT.service_type = 'INTERNET'
  AND ACT.MARCA = 'SIMYO'

; 
*/

--- UPDATE A TARIFAS DE MIGRACIONES PRE A POST PARA VER LA TARIFA DE POSPAGO QUE SE ESTÁ FACTURANDO (ENK) + Añado XI (Ainhoa 20261022)
CREATE OR REPLACE TEMPORARY TABLE tarifas_migraciones_pre_post AS

WITH tarifas_migraciones_pre_post AS (
SELECT 
     VENTAS.phone_nm
     ,VENTAS.service_id
     ,VENTAS.service_type
     ,FACTURACION.tariff_id
     ,REGEXP_REPLACE(NORMALIZE(FACTURACION.tariff_ds, NFD), r'\pM', '') AS tariff_ds
     ,FACTURACION.brand_ds AS marca
     ,FACTURACION.data_month_id
     ,MIGRACIONES_CONTRATO.service_id AS service_id_migracion_contrato
     ,MIGRACIONES_CONTRATO.line_type_ds AS line_type_migracion_contrato

FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS

LEFT JOIN (SELECT  *
           FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` a
          --  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
          left join `mm-commissions-reporting.COMISIONES.dealer_ultima_version` b 
               ON a.seller = b.id_comisionista
               AND b.comisiona
           WHERE a.order_type_agg = 'MIGRACION CONTRATO'
           AND a.id_mes_activacion = id_mes_pr 
           AND b.canal IN ('ENK','XI')
           ) MIGRACIONES_CONTRATO 
           ON MIGRACIONES_CONTRATO.phone_nm = VENTAS.phone_nm
              AND DATE_TRUNC(MIGRACIONES_CONTRATO.activation_date, MONTH) = DATE_TRUNC(VENTAS.activation_date, MONTH)

INNER JOIN (
             SELECT 
               data_month_id,service_id,phone_nm,brand_ds,tariff_id,tariff_ds,bundle_id,init_date,end_date,concept_type_ds,movement_date
             FROM `mm-datamart-kd.BILLING.billing_detail_emysim`

             UNION ALL

             SELECT 
               CASE
                    WHEN brand_ds = 'YOIGO'    THEN CAST(FORMAT_DATE('%Y%m', DATE_SUB(invoice_cycle_date, INTERVAL 1 MONTH)) AS INT64) 
                    WHEN brand_ds = 'MASMOVIL' THEN CAST(FORMAT_DATE('%Y%m', DATE_TRUNC(invoice_cycle_date, MONTH)) AS INT64)
               END AS data_month_id,
               service_id,phone_nm,brand_ds,tariff_id,tariff_ds,bundle_id,init_date,end_date,concept_type_ds,movement_date
             FROM `mm-datamart-kd.BILLING.prebilling_detail_emysim`              
            )FACTURACION
     ON VENTAS.phone_nm = CAST(FACTURACION.phone_nm AS STRING)
     AND VENTAS.id_mes_activacion = FACTURACION.data_month_id 
     AND (VENTAS.service_id = FACTURACION.service_id
          OR
          MIGRACIONES_CONTRATO.service_id = FACTURACION.service_id)
     AND VENTAS.marca = FACTURACION.brand_ds

-- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
left join `mm-commissions-reporting.COMISIONES.dealer_ultima_version` DEALER 
     ON VENTAS.seller = DEALER.id_comisionista
     AND DEALER.comisiona

WHERE DEALER.canal IN ('ENK','XI')
     AND VENTAS.id_mes_activacion = id_mes_pr
     AND VENTAS.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO'

QUALIFY ROW_NUMBER() OVER(PARTITION BY VENTAS.phone_nm, VENTAS.brand_ds ORDER BY FACTURACION.movement_date ASC) = 1
)

SELECT *
FROM tarifas_migraciones_pre_post
;

UPDATE `mm-commissions-reporting.COMISIONES.activaciones` ACTIVACIONES
SET ACTIVACIONES.tariff_id = MIGRACIONES.tariff_id, ACTIVACIONES.tariff_ds = MIGRACIONES.tariff_ds
FROM tarifas_migraciones_pre_post MIGRACIONES
WHERE ACTIVACIONES.phone_nm = MIGRACIONES.phone_nm
     AND ACTIVACIONES.service_id = MIGRACIONES.service_id
     AND ACTIVACIONES.brand_ds = MIGRACIONES.marca
     AND ACTIVACIONES.id_mes = MIGRACIONES.data_month_id
    --  AND ACTIVACIONES.agrupacion_canal = 'Exclusivo'
     AND ACTIVACIONES.canal IN ('ENK','XI')
     AND ACTIVACIONES.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO'
;

commit transaction;

EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;

end