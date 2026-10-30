begin

declare prefijo, mes_string string;
declare Y_atakam,Y_bemore,Y_becall,M_Konecta,M_atakam,M_bemore int64;
--set Y_atakam = 29895;
--set Y_bemore = 43725;
--set Y_becall = 0;
--set M_konecta = 0;
--set M_atakam = 54210;
--set M_bemore = 74550;

set mes_string = cast(id_mes_pr as string);

set prefijo = 'ENRG_';

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU','WA', 'EDB', 'EML' ,'ENX', 'EYG','ENK', 'D2D', 'D2N', 'DEM', 'CIN', 'DON', 'OUN', 'XIN', 'XSN'];
END IF;

--call COMISIONES.pr_ENERGY_LUZ (202508, ['ENK']);

create or replace table TEMP.ENERGY_LUZ as 


--__________________________________________________________________________ B - Energia ______________________________________________________________________
select 
id_mes_pr as id_mes,
prefijo||'BE1'||mes_string||'_'||b.canal||'_'||row_number () over ()  as commission_id,
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
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Energia')) as concepto,
'CSEN' as tipo_concepto,
1 as unidades,
case 

     --- AÑADIMOS CAMP PILOTO NUEVO MARCO DESDE JULIO 25

     WHEN tenant_code IN ('yoigo','masmovil') and affiliate_code like '%batman%' 
          and b.canal IN ( 'XS') 
          and b.sfid_id IN ('CAROUT026','CAROUT031','CAROUT035','CAROUT036','CAROUT037','CAROUT038','CAROUT039','CAROUT040') THEN 30 
     WHEN tenant_code IN ('yoigo','masmovil') 
          and b.canal IN ( 'XS') 
          and b.sfid_id IN ('CAROUT026','CAROUT031','CAROUT035','CAROUT036','CAROUT037','CAROUT038','CAROUT039','CAROUT040') THEN 45 

       when tenant_code = 'masmovil'and b.sfid_id =  'TLVOU001'  then  20 -- son 262 registros  arreglo para los 'OU' que ahora son 'DO'
       when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 20
       when tenant_code = 'yoigo' and A.sfid_id = 'TLVOU001' then 20
       when tenant_code = 'masmovil' and A.sfid_id = 'DONL026' then 20
       when tenant_code = 'yoigo' and A.sfid_id = 'DONL026' then 20


     ---- TLV OU DESDE JULIO 25
     WHEN tenant_code IN ('yoigo','masmovil') and affiliate_code like '%batman%' 
          and b.canal IN ( 'OU') 
          and b.sfid_id IN ('TLVOU022','TLVOU024','TLVOU028') THEN 30 
     WHEN tenant_code IN ('yoigo','masmovil') 
          and b.canal IN ( 'OU') 
          and b.sfid_id IN ('TLVOU022','TLVOU024','TLVOU028') THEN 50 
--  Cartera Inbound/Outbound

--ENERGYGO
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT008' and affiliate_code like '%batman%' then  19
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT008' then  39
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT010' and affiliate_code like '%batman%' then  19
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT010' then  39


     when tenant_code IN ('yoigo','masmovil') and b.canal IN ('XI','XO','XIN','XOF') and affiliate_code like '%batman%'  THEN 20
     when tenant_code IN ('yoigo','masmovil')and b.canal IN ('XI','XO','XIN','XOF')THEN 30

     
     
    -- se hace por reparto por calculo (precio 15€ * nº horas) / nº total de activaciones (nuestras)
 /*    when tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and (substring(upper(author_id),1,2)) like '%AV%' then  ROUND((Y_atakam/(select count(id) from `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  
    where DATE_TRUNC(DATE(activation_date ), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and  tenant_code = 'yoigo' and lower(author_id) like '%_eg%' and (substring(upper(author_id),1,2)) like '%AV%')),2)    --ATAKAM   

    

     when tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and (substring(upper(author_id),1,2)) like '%BX%' then ROUND((Y_bemore/(select count(id) from `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  
    where DATE_TRUNC(DATE(activation_date ), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and  tenant_code = 'yoigo' and lower(author_id) like '%_eg%' and (substring(upper(author_id),1,2)) like '%BX%')),2)     --BEMORE   

     when tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and (substring(upper(author_id),1,2)) like '%LE%' then  ROUND((Y_becall/(select count(id) from `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  
    where DATE_TRUNC(DATE(activation_date ), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and  tenant_code = 'yoigo'  and lower(author_id) like '%_eg%' and (substring(upper(author_id),1,2)) like '%LE%')),2)    --BECALL   */

    -- campañas --

     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) not like '%_eg%' and affiliate_code like '%batman%' then 40 
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) not like '%_eg%' then 50
 
     
     
     -- se hace por reparto por calculo (precio 15€ * nº horas) / nº total de activacione
      
   /*  when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and A.sfid_id in ('CAROUT007','CAROUT018') then ROUND (M_konecta/ (select COUNT(id) from `mm-datamart-kd.ENERGY.lucera_polissas_electricity` where DATE_TRUNC(DATE(activation_date ), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AND tenant_code = 'masmovil' and lower(author_id) like '%_me%' and sfid_id in ('CAROUT007','CAROUT018')),2)    --KONECTA   
     
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and A.sfid_id = 'CAROUT008' then  round ((M_atakam/(select COUNT(id) from `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  where DATE_TRUNC(DATE(activation_date ), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AND tenant_code = 'masmovil'  and lower(author_id) like '%_me%' and sfid_id = 'CAROUT008' )),2) --ATAKAM       
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and A.sfid_id = 'CAROUT010' then  round((M_bemore/(select COUNT(id) from `mm-datamart-kd.ENERGY.lucera_polissas_electricity`  where DATE_TRUNC(DATE(activation_date ), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AND tenant_code = 'masmovil'  and lower(author_id) like '%_me%' and sfid_id = 'CAROUT010' )),2)     --BEMORE  */

     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT008' and affiliate_code like '%batman%' then  19
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT008' then  39
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT010' and affiliate_code like '%batman%' then  19
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT010' then  39


--campañas --

     when  tenant_code= 'masmovil' and b.canal = 'XS' and lower(author_id) not like '%_me%'and affiliate_code like '%batman%' then 40 
     when  tenant_code= 'masmovil' and b.canal = 'XS' and lower(author_id) not like '%_me%' then 50


     WHEN tenant_code = 'yoigo' and b.canal  = 'XSO' and affiliate_code like '%batman%' then 40 
     WHEN tenant_code = 'yoigo' and b.canal  = 'XSO'  then 50 
       

--  DOOR TO DOOR 

--ENERGYGO

     WHEN tenant_code IN ('yoigo','masmovil')and b.canal IN ('D2N','D2D','DEM') THEN 80

 --TLV - Inbound y Distribucion Online

     WHEN tenant_code IN ('yoigo','masmovil') and b.canal = 'WA' and b.sfid_id = 'RONL010' and affiliate_code like '%batman%' THEN 20
     WHEN tenant_code IN ('yoigo','masmovil') and b.canal = 'WA' and b.sfid_id = 'RONL010' THEN 30
     
     
     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('WA','CIN') and affiliate_code like '%batman%' THEN 20
     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('WA','CIN') THEN 30

     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL011','DONL020','DONL024') and affiliate_code like '%batman%'  THEN 45 
     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL011','DONL020','DONL024') THEN 60 


     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL001','DONL002','DONL004','DONL010') and affiliate_code like '%batman%'  THEN 55 
     WHEN tenant_code IN ('yoigo','masmovil') and b.canal IN ('DO','DON') and b.sfid_id in ('DONL001','DONL002','DONL004','DONL010') THEN 70 

     WHEN tenant_code IN ('yoigo','masmovil')and b.canal = 'OUN' THEN 60

     

--Agrupacion canal Exclusivo  

     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('EML', 'EYG', 'ENX','EDB') THEN 35
     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal = 'ENK' THEN 40

  

--Agrupacion canal No Exclusivo

--ENERGYGO
     when tenant_code IN ('yoigo','masmovil','pepe')and b.canal IN ('ALTN','ALTNC','ALTNH') THEN 35
     
     when tenant_code IN ('yoigo','masmovil','pepe')and b.canal = 'ST' THEN 60

     when tenant_code IN ('yoigo','pepe')and b.canal = 'PH' THEN 45
     when tenant_code IN ('masmovil')   and b.canal = 'PH' THEN 40
     
  
               
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
CAST(id AS STRING) AS service_id,
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
coalesce(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY')) as campaign_code,
cups_code as serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from `mm-datamart-kd.ENERGY.lucera_polissas_electricity` A
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
ON A.sfid_id = B.sfid_id  
OR substring(A.sfid_id,1,2) = B.sfid_id
OR A.dealer_code = B.sfid_id
OR A.user_store = B.sfid_id
OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.id_comisionista
LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
AND B.canal = TLV_CROSS_SELL.canal
--AND A.activation_date >= '2024-07-22'
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL 

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
and tenant_code in ('yoigo','masmovil','pepe') 
and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
and not b.canal in ('XIN','XSN','CIN','DON')
and not (b.canal= 'NR' and b.razon_social like '%GLOBALIA%')
AND B.canal = canal_pr
and not (tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and A.sfid_id = 'CAROUT004') 
QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 


UNION ALL

--------------------------------------------------------------- RAPPELL ENERGIA ------------------------------------------------------------------------

select * from (
select 
id_mes_pr as id_mes,
prefijo||'DR1'||mes_string||'_'||B.canal||'_'||row_number () over () as commission_id,
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
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('D - Rappel energia')) as concepto,
'CSEN' as tipo_concepto,
1 as unidades,

case 


--  Cartera Inbound/Outbound

--ENERGYGO
--ENERGIA PURA 

     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT008' and affiliate_code like '%batman%' then  0
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT008' then  0
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT010' and affiliate_code like '%batman%' then  0
     when  tenant_code = 'yoigo' and b.canal = 'XS' and lower(author_id) like '%_eg%' and B.sfid_id = 'CAROUT010' then  0


     when tenant_code = 'yoigo'and B.canal ='XI' and (substring(lower(lower(author_id)),1,2)) like '%ks%'and B.sfid_id = 'CARIN011'  THEN 0           -- esto nos lo da Santiago
     when tenant_code = 'yoigo'and B.canal ='XOF' and (substring(lower(lower(author_id)),1,2)) like '%ks%'and B.sfid_id = 'CARIN004'  THEN 0
     when tenant_code = 'yoigo'and B.canal ='XI' and (substring(lower(lower(author_id)),1,2)) like '%ab%'  THEN 5                                     -- este es CARIN007 
     when tenant_code = 'yoigo'and B.canal ='XI' and (substring(lower(lower(author_id)),1,2)) like '%ao%'  THEN 0                                    -- este es CARIN006/009 
   


     when  tenant_code= 'yoigo' and B.canal = 'XS' and lower(lower(author_id)) like '%_eg%' and (substring(lower(author_id),1,2)) like '%av%' and affiliate_code like '%batman%' then  0
     when  tenant_code= 'yoigo' and B.canal = 'XS' and lower(lower(author_id)) like '%_eg%' and (substring(lower(author_id),1,2)) like '%av%' then  0
     
     when  tenant_code= 'yoigo' and B.canal = 'XS' and lower(author_id) like '%_eg%' and (substring(lower(author_id),1,2)) like '%bx%' and affiliate_code like '%batman%' then  0
     when  tenant_code= 'yoigo' and B.canal = 'XS' and lower(author_id) like '%_eg%' and (substring(lower(author_id),1,2)) like '%bx%' then  0
     
     when  tenant_code= 'yoigo' and B.canal = 'XS' and lower(author_id) like '%_eg%' and (substring(lower(author_id),1,2)) like '%le%' and affiliate_code like '%batman%' then  0
     when  tenant_code= 'yoigo' and B.canal = 'XS' and lower(author_id) like '%_eg%' and (substring(lower(author_id),1,2)) like '%le%' then  0
     

-- campañas -------------------------------- 

     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_xs%' and substring(lower(author_id),1,2) like '%mv%'  THEN 0   
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_xs%' and substring(lower(author_id),1,2) like '%ae%'  THEN 0
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_xs%' and substring(lower(author_id),1,2) like '%ko%'  THEN 0 
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_xs%' and substring(lower(author_id),1,2) like '%av%'  THEN 10 
   
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_tv%' and substring(lower(author_id),1,2) like '%mv%'  THEN 0  
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_tv%' and substring(lower(author_id),1,2) like '%ae%'  THEN 0
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_tv%' and substring(lower(author_id),1,2) like '%ko%'  THEN 0 
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_tv%' and substring(lower(author_id),1,2) like '%le%'  THEN 0 

     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_mo%' and substring(lower(author_id),1,2) like '%mv%'  THEN 0   
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_mo%' and substring(lower(author_id),1,2) like '%ae%'  THEN 0
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_mo%' and substring(lower(author_id),1,2) like '%ko%'  THEN 0 
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_mo%' and substring(lower(author_id),1,2) like '%av%'  THEN 0 

     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_ce%' and substring(lower(author_id),1,2) like '%mv%'  THEN 0   
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_ce%' and substring(lower(author_id),1,2) like '%ae%'  THEN 0
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_ce%' and substring(lower(author_id),1,2) like '%ko%'  THEN 0 
     when tenant_code = 'yoigo'and B.canal ='XS' and lower(author_id) like '%_ce%' and substring(lower(author_id),1,2) like '%av%'  THEN 0 
     

---- Añadimos nuevo canal XSO --- (CAROUT019 Y CAROUT024 YOIGO)
     WHEN tenant_code = 'yoigo' and B.canal = 'XSO' then 10
     

--MASMOVIL

--ENERGIA PURA 
     

     when tenant_code = 'masmovil'and B.canal ='XO'    THEN 0                 -- esto nos lo da Santiago             CARIN003
     when tenant_code = 'masmovil'and B.canal ='XOF'   THEN 0                    -- esto nos lo da Santiago          CARIN004
    

     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and A.sfid_id in ('CAROUT007','CAROUT018') and affiliate_code like '%batman%' then  0
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id in ('CAROUT007','CAROUT018') then  0
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT008' and affiliate_code like '%batman%' then  0
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT008' then  0
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT010' and affiliate_code like '%batman%' then  0
     when  tenant_code = 'masmovil' and b.canal = 'XS' and lower(author_id) like '%_me%' and B.sfid_id = 'CAROUT010' then  0




     -- --campaña

 
-- outbound   

    

       when tenant_code = 'masmovil'and b.sfid_id =  'TLVOU001' and b.canal = 'DO'   then  40 -- son 262 registros  arreglo para los 'OU' que ahora son 'DO'
       when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' and b.canal = 'DO'  then 40
       when tenant_code = 'yoigo' and A.sfid_id = 'TLVOU001' and b.canal = 'DO' then 40 

-- AÑADIMOS DO 202507 
       when tenant_code = 'masmovil' and b.sfid_id in ('DONL026') and b.canal = 'DO'   then  40
       when tenant_code = 'yoigo' and b.sfid_id in ('DONL026') and b.canal = 'DO'   then  40


         

 else 0 
               
END 
AS COMISION,

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
CAST(id AS STRING) AS service_id,
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
coalesce(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(B.canal, tenant_code, a.sfid_id, 'ENERGY')) as campaign_code,
cups_code as serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from `mm-datamart-kd.ENERGY.lucera_polissas_electricity` A
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
ON A.sfid_id = B.sfid_id  
OR (substring(A.sfid_id,1,2)) = B.sfid_id
OR A.dealer_code = B.sfid_id
OR A.user_store = B.sfid_id
OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.id_comisionista
LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
AND B.canal = TLV_CROSS_SELL.canal
--AND A.activation_date >= '2024-07-22'
inner join `mm-commissions-reporting.GS.CANALES` C ON B.canal=C.CANAL 

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
AND B.CANAL = canal_pr
and tenant_code in ('yoigo','masmovil') 
and not B.canal in ('OU','XSN','CIN','XIN','DON')  
and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1)
where comision != 0 



-- union all
-- ---------------------------------------------------------------gestion de canal -----------------------------------------------------------------------

-- select 
-- id_mes_pr as id_mes,
-- prefijo||'FG'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
--  case 

--      when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 'DO'
--      else C.canal
--      end

-- as canal,
  
--   case 

--      when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 'TLV - DO'
--      else C.agrupacion_canal
--      end

-- as agrupacion_canal,
-- case 

--      when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then '15'
--      else C.cod_canal
--      end

--   as cod_canal,
-- (SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('F - Gestion de canal energia')) as concepto,
-- 'CSEN' as tipo_concepto,
-- 1 as unidades,
-- case 


-- --Agrupacion TODAS 

-- --ENERGYGO

--      when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('EML','EYG','ENX') THEN 0
     


  

--      else 0          
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
-- CAST(id AS STRING) AS service_id,
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
-- coalesce(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY')) as campaign_code,
-- cups_code as serial_number,
-- cast ( null as float64 ) tax_base,
-- cast (null as string) as process_code,
-- cast (null as string) as comments,
-- 'C_MANUAL' as facturador,
-- 'calculado' as estado
-- from `mm-datamart-kd.ENERGY.lucera_polissas_electricity` A
-- LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
-- ON A.sfid_id = B.sfid_id  
-- OR (substring(A.sfid_id,1,2)) = B.sfid_id
-- OR A.dealer_code = B.sfid_id
-- OR A.user_store = B.sfid_id
-- OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
-- OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.sfid_id
-- OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.id_comisionista
-- LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
-- ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
-- AND B.canal = TLV_CROSS_SELL.canal
-- --AND A.activation_date >= '2024-07-22'
-- inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL 
-- CROSS JOIN UNNEST(canales_pr) AS canal_pr
-- WHERE  (DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
-- AND B.CANAL = canal_pr
-- and tenant_code in ('yoigo','masmovil','pepe')  
-- and B.canal in ('EML','EYG')
-- and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES'))
-- or (DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
-- and B.canal in ('MI','CA') 
-- and B.cif in (select documento from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`) 
-- and tenant_code in ('yoigo','masmovil','pepe') 
-- and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES'))

-- QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 







-- -------------------------------------------------------------------------   MULTIPLICADOR --------------------------------------------------------------------
union all 


SELECT 
id_mes_pr AS id_mes,
prefijo||'DM'||mes_string||'_'||canal||'_'||row_number () over () as commission_id,
canal,
agrupacion_canal,
COD_CANAL,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('D - Multiplicador energia')) as concepto,
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
     prefijo||'BE1'||mes_string||'_'||b.canal||'_'||row_number () over ()  as commission_id,
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
     (SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Energia')) as concepto,
     'CSEN' as tipo_concepto,
     1 as unidades,
     case 





     --Agrupacion canal Exclusivo  

     --ENERGYGO

          when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('EML','EYG', 'ENX') THEN 35
          

                    
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
     CAST(id AS STRING) AS service_id,
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
     coalesce(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, tenant_code, a.sfid_id, 'ENERGY')) as campaign_code,
     cups_code as serial_number,
     cast ( null as float64 ) tax_base,
     cast (null as string) as process_code,
     cast (null as string) as comments,
     'C_MANUAL' as facturador,
     'calculado' as estado
     from `mm-datamart-kd.ENERGY.lucera_polissas_electricity` A

     LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
     ON A.sfid_id = B.sfid_id  
     OR (substring(A.sfid_id,1,2)) = B.sfid_id
     OR A.dealer_code = B.sfid_id
     OR A.user_store = B.sfid_id
     OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
     OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.sfid_id
     OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.id_comisionista

     LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
     ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
     AND B.canal = TLV_CROSS_SELL.canal
     --AND A.activation_date >= '2024-07-22'

     inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL 

     CROSS JOIN UNNEST(canales_pr) AS canal_pr

     WHERE  DATE_TRUNC(DATE(activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
     and tenant_code in ('yoigo','masmovil','pepe')  AND  channel_ds != 'WEB'
     and channel_ds not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
     and not b.canal in ('XIN','XSN','CIN','DON')
     and not (b.canal= 'NR' and B.razon_social like '%GLOBALIA%')
     AND B.canal = canal_pr
     QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 
) T

inner join `mm-commissions-reporting.COMISIONES.multiplicadores_luz` G
     on upper(T.seller) = G.sfid_id and G.id_mes = id_mes_pr

WHERE multiplicador != 1


  ;

  DELETE 
  FROM `mm-commissions-reporting.TEMP.ENERGY_LUZ`
  WHERE COMISION = 0 OR COMISION IS NULL
;

-- call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('ENRG_', id_mes_pr, canales_pr , 'TEMP.ENERGY_LUZ' , 'ACTUALIZAR');
 


end