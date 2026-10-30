begin

declare prefijo, mes_string string;

set mes_string = cast(id_mes_pr as string);

set prefijo = 'GARG_';
--set prefijo = 'PRUEBAMAYOGAS';

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU','WA', 'EDB', 'EML' ,'ENX', 'EYG','ENK', 'D2D', 'D2N', 'DEM', 'CIN', 'DON', 'OUN', 'XIN', 'XSN'];
END IF;

--call COMISIONES.pr_ENERGY_GAS (202508, ['EML','ENX','EYG','ENK']);


create or replace table TEMP.ENERGY_GAS as 


-- __________________________________________________________________________ Gas ______________________________________________________________________
select 
id_mes_pr as id_mes,
prefijo||'B-g'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
 case 

     when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 'DO'
     else C.canal
     end

as canal,
  
  case 

     when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 'TLV - DO'
     else C.agrupacion_canal
     end

as agrupacion_canal,
case 

     when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then '15'
     else C.cod_canal
     end

  as cod_canal,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Gas')) as concepto,
'CSEN' as tipo_concepto,
1 as unidades,
case 
       when tenant_code = 'masmovil'and b.sfid_id =  'TLVOU001'  then  90                --revisar con belen
       when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 90               --revisar con belen
       when tenant_code = 'yoigo' and A.sfid_id = 'TLVOU001' then 90 


 ---- TLV OU DESDE JULIO 25

     WHEN tenant_code IN ('yoigo','masmovil') 
          and b.canal IN ( 'OU') 
          and b.sfid_id IN ('TLVOU022','TLVOU024','TLVOU028') THEN 50 

--  Cartera Inbound/Outbound

     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ( 'XS') and b.sfid_id IN ('CAROUT026','CAROUT031','CAROUT035','CAROUT036','CAROUT037','CAROUT038','CAROUT039','CAROUT040') THEN 45 
     when  tenant_code = 'yoigo' and b.canal = 'XSO'  then 50
     when  tenant_code = 'yoigo' and b.canal IN ('XS','XSN') and lower(author_id) not like '%_eg%' then 50
     when  tenant_code= 'masmovil' and b.canal IN ('XS','XSN') and lower(author_id) not like '%_me%' then 50
     when  tenant_code IN ('yoigo','masmovil')and b.canal IN ('XS','XSN')THEN 16 


     WHEN tenant_code IN ('yoigo', 'masmovil')and b.canal IN ('D2N','D2D','DEM') THEN 20

     WHEN tenant_code IN ('yoigo','masmovil')and b.canal IN ('OU','OUN') THEN 90

     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL011','DONL020','DONL024') and affiliate_code like '%batman%'  THEN 45 
     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL011','DONL020','DONL024') THEN 60 

     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL001','DONL002','DONL004','DONL010') and affiliate_code like '%batman%'  THEN 55 
     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL001','DONL002','DONL004','DONL010') THEN 70 

     WHEN tenant_code IN ('yoigo','masmovil')and b.canal IN ('WA','CIN','XI','XIN','XO','CIN','XOF')  THEN 15

     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('MP','ALTN','ST','ALTNC','ALTNH','EML','EYG','ENX') THEN 35
     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal = 'ENK' THEN 40
     when tenant_code IN ('yoigo','pepe') and b.canal IN ('PH') THEN 35
     when tenant_code IN ('masmovil','pepe') and b.canal IN ('PH') THEN 40
     
  

               
END AS COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
upper(split(author_id, "@")[offset(0)])  as seller,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,

 case
     when tenant_code = 'masmovil' then 'MASMOVIL'
     when tenant_code = 'yoigo' then 'ENERGYGO'
     when tenant_code = 'pepe'     then 'PEPEENERGY'
    
     end 
     
     as marca,
'ENERGY' as service_type,
cast(phone as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
affiliate_code as tariff_ds,
cast(id as string) AS service_id,
cups_code as account_id,
CAST(NULL AS STRING) AS customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
signup_date as sale_date,
activation_date,
churn_date as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'014' as cod_producto,
CASE WHEN tenant_code ='yoigo' THEN '16'
     WHEN tenant_code ='masmovil' THEN '17' 
     WHEN tenant_code ='pepe' THEN '19'
     END AS cod_marca,
cast (null as string) as claim_code,
CASE
    WHEN A.activation_date < '2024-07-22'
    THEN coalesce(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY'), tlv_cross_sell.campaign)
    ELSE coalesce(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY'))
END AS campaign_code,
cups_code as serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from `mm-datamart-kd.ENERGY.lucera_polissas_gas` A
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
ON A.sfid_id = B.sfid_id  
OR (substring(A.sfid_id,1,2)) = B.sfid_id
LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
AND B.canal = TLV_CROSS_SELL.canal
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and tenant_code in ('yoigo','masmovil','pepe')
and B.canal = canal_pr
and not (b.canal= 'NR' and b.razon_social like '%GLOBALIA%')
and not b.canal IN ('DON','XIN')
and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES')
QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 



-- union all
-- ---------------------------------------------------------------gestion de canal -----------------------------------------------------------------------

-- select 
-- id_mes_pr as id_mes,
-- prefijo||'F-gc'||mes_string||'_'||b.canal||'_'||row_number () over ()  as commission_id,
-- C.canal,
-- C.agrupacion_canal,
-- C.cod_canal,
-- (SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('F - Gestion de canal gas')) as concepto, 
-- 'CSEN' as tipo_concepto,
-- 1 as unidades,
-- case 

-- --Agrupacion canal Exclusivo  

-- --ENERGYGO

--      when tenant_code IN ('yoigo','masmovil','pepe')and b.canal IN ('EML','EYG','ENX') THEN 0

                
-- END AS COMISION,

-- b.id_comisionista,
-- B.distribuidor,
-- b.id_comisionista as sfid_id,
-- upper(split(author_id, "@")[offset(0)])  as seller,
-- b.nombre_comercio,
-- b.razon_social,
-- b.cif,
-- b.zona_fiscal,

--  case
--      when tenant_code = 'masmovil' then 'MASMOVIL'
--      when tenant_code = 'yoigo' then 'ENERGYGO'
--      when tenant_code = 'pepe'     then 'PEPEENERGY'
    
--      end 
     
--      as marca,
-- 'ENERGY' as service_type,
-- cast(phone as string) as phone_nm,
-- CAST(NULL AS STRING) AS tariff_id,
-- affiliate_code as tariff_ds,
-- cast(id as string) AS service_id,
-- cups_code as account_id,
-- CAST(NULL AS STRING) AS customer_id,
-- CAST(NULL AS STRING) AS line_type_ds,
-- CAST(NULL AS STRING) AS bundle_type,
-- CAST(NULL AS STRING) AS technology_ds,
-- CAST(NULL AS STRING) AS billing_type_ds,
-- signup_date as sale_date,
-- activation_date,
-- churn_date as deactivation_date,
-- cast (null as string) as order_id,
-- cast (null as string) as order_type_agg,
-- '10' as cod_segmento,
-- '99' as cod_tipo_contrato,
-- '014' as cod_producto,
-- CASE WHEN tenant_code ='yoigo' THEN '16'
--      WHEN tenant_code ='masmovil' THEN '17' 
--      WHEN tenant_code ='pepe' THEN '19'
--      END AS cod_marca,
-- cast (null as string) as claim_code,
-- CASE
--     WHEN A.activation_date < '2024-07-22'
--     THEN coalesce(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY'), tlv_cross_sell.campaign)
--     ELSE coalesce(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY'))
-- END AS campaign_code,
-- cups_code as serial_number,
-- cast ( null as float64 ) tax_base,
-- cast (null as string) as process_code,
-- cast (null as string) as comments,
-- 'C_MANUAL' as facturador,
-- 'calculado' as estado
-- from `mm-datamart-kd.ENERGY.lucera_polissas_gas` A
-- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
-- ON A.sfid_id = B.sfid_id  
-- OR (substring(A.sfid_id,1,2)) = B.sfid_id
-- LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
-- ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
-- AND B.canal = TLV_CROSS_SELL.canal
-- inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL 
-- CROSS JOIN UNNEST(canales_pr) AS canal_pr

-- WHERE  (DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
-- and B.canal = canal_pr
-- and tenant_code in ('yoigo','masmovil','pepe')  
-- and B.canal in ('EML','EYG')
-- and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES'))
-- or (DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
-- and B.canal in ('MI','CA') 
-- and B.cif in (select documento from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`) 
-- and tenant_code in ('yoigo','masmovil','pepe') 
-- and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES'))
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 

 





-- -- -------------------------------------------------------------------------   MULTIPLICADOR --------------------------------------------------------------------
 union all 


SELECT 
id_mes,
prefijo||'D-mg'||mes_string||'_'||canal||'_'||row_number () over ()  as commission_id,
canal,
agrupacion_canal,
COD_CANAL,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('D - Multiplicador gas')) as concepto,    -----no aparece el concepto en control---- 
tipo_concepto,
unidades,
(T.COMISION * G.multiplicador) - T.COMISION AS  COMISION,
id_comisionista,
distribuidor,
T.sfid_id,
seller,
nombre_comercio,
T.razon_social,
T.cif,
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

from
(
     select 
     id_mes_pr as id_mes,
     prefijo||'B-g'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
     case 

          when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 'DO'
          else C.canal
          end

     as canal,
     
     case 

          when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 'TLV - DO'
          else C.agrupacion_canal
          end

     as agrupacion_canal,
     case 

          when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then '15'
          else C.cod_canal
          end

     as cod_canal,
     (SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Gas')) as concepto,
     'CSEN' as tipo_concepto,
     1 as unidades,
     case 
          when tenant_code = 'masmovil'and b.sfid_id =  'TLVOU001'  then  90                --revisar con belen
          when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 90               --revisar con belen
          when tenant_code = 'yoigo' and A.sfid_id = 'TLVOU001' then 90 
     --  Cartera Inbound/Outbound

     
          when tenant_code IN ('yoigo','masmovil')and b.canal ='XS'THEN 16 

          WHEN tenant_code IN ('yoigo', 'masmovil')and b.canal IN ('D2N','D2D','DEM') THEN 20

          WHEN tenant_code IN ('yoigo','masmovil')and b.canal IN ('OU','OUN','DO') THEN 90

          WHEN tenant_code IN ('yoigo','masmovil')and b.canal IN ('WA','XI','XO','CIN','XOF')  THEN 15

          when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('MP','ALTN','ST','ALTNC','ALTNH','TPH','PH','EML','EYG','ENX') THEN 35
          
     

                    
     END AS COMISION,

     b.id_comisionista,
     B.distribuidor,
     b.id_comisionista as sfid_id,
     upper(split(author_id, "@")[offset(0)])  as seller,
     b.nombre_comercio,
     b.razon_social,
     b.cif,
     b.zona_fiscal,

     case
          when tenant_code = 'masmovil' then 'MASMOVIL'
          when tenant_code = 'yoigo' then 'ENERGYGO'
          when tenant_code = 'pepe'     then 'PEPEENERGY'
     
          end 
          
          as marca,
     'ENERGY' as service_type,
     cast(phone as string) as phone_nm,
     CAST(NULL AS STRING) AS tariff_id,
     affiliate_code as tariff_ds,
     cast(id as string) AS service_id,
     cups_code as account_id,
     CAST(NULL AS STRING) AS customer_id,
     CAST(NULL AS STRING) AS line_type_ds,
     CAST(NULL AS STRING) AS bundle_type,
     CAST(NULL AS STRING) AS technology_ds,
     CAST(NULL AS STRING) AS billing_type_ds,
     signup_date as sale_date,
     activation_date,
     churn_date as deactivation_date,
     cast (null as string) as order_id,
     cast (null as string) as order_type_agg,
     '10' as cod_segmento,
     '99' as cod_tipo_contrato,
     '014' as cod_producto,
     CASE WHEN tenant_code ='yoigo' THEN '16'
          WHEN tenant_code ='masmovil' THEN '17' 
          WHEN tenant_code ='pepe' THEN '19'
          END AS cod_marca,
     cast (null as string) as claim_code,
     CASE
     WHEN A.activation_date < '2024-07-22'
     THEN coalesce(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY'), tlv_cross_sell.campaign)
     ELSE coalesce(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY'))
     END AS campaign_code,
     cups_code as serial_number,
     cast ( null as float64 ) tax_base,
     cast (null as string) as process_code,
     cast (null as string) as comments,
     'C_MANUAL' as facturador,
     'calculado' as estado
     
     from `mm-datamart-kd.ENERGY.lucera_polissas_gas` A
     
     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
          ON A.sfid_id = B.sfid_id  
          OR (substring(A.sfid_id,1,2)) = B.sfid_id
     
     LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
          ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
          AND B.canal = TLV_CROSS_SELL.canal
     
     inner join `mm-commissions-reporting.GS.CANALES` C 
          ON B.CANAL=C.CANAL 

     CROSS JOIN UNNEST(canales_pr) AS canal_pr

     WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
          AND B.canal = canal_pr
          and tenant_code in ('yoigo','masmovil','pepe')
          and not (b.canal= 'NR' and b.razon_social like '%GLOBALIA%')
          and not b.canal in ('XS','DON')
          and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES')
     QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 
) T

inner join `mm-commissions-reporting.COMISIONES.multiplicadores_luz` G   ----------> NOTA: 'Son los mismos multiplicadores de luz' <-----------
     on upper(T.seller) = G.sfid_id AND T.id_mes = G.ID_MES

WHERE multiplicador != 1
  ;

  DELETE 
  FROM `mm-commissions-reporting.TEMP.ENERGY_LUZ`
  WHERE COMISION = 0 OR COMISION IS NULL

;

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('GARG_', id_mes_pr, canales_pr , 'TEMP.ENERGY_GAS' , 'ACTUALIZAR');

end