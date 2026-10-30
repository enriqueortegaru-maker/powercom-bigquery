begin

declare prefijo, mes_string string;

set mes_string = cast(id_mes_pr as string);

set prefijo = 'SVRG_';
--set prefijo = 'PRUEBAMAYOSVE';

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU','WA', 'EDB', 'EML' ,'ENX', 'EYG','ENK', 'D2D', 'D2N', 'DEM', 'CIN', 'DON', 'OUN', 'XIN', 'XSN'];
END IF;

--call COMISIONES.pr_ENERGY_SVE (202508, NULL);

create or replace table TEMP.ENERGY_SVE as 


--__________________________________________________________________________ B - SVE ______________________________________________________________________
select 
id_mes_pr as id_mes,
prefijo||'B-sve'||mes_string||'_'||b.canal||'_'||row_number () over ()  as commission_id,
  case 

     when tenant_code = 'yoigo_svg' and A.sfid_id = 'SLE00001_OU' then 'DO'
     when tenant_code = 'masmovil_svg' and A.sfid_id = 'TLVOU001' then 'DO'
     else C.canal
     end

as canal,
  
  case 

     when tenant_code = 'yoigo_svg' and A.sfid_id = 'SLE00001_OU' then 'TLV - DO'
     when tenant_code = 'masmovil_svg' and A.sfid_id = 'TLVOU001' then 'TLV - DO'
     else C.agrupacion_canal
     end

as agrupacion_canal,
case 

     when tenant_code = 'yoigo_svg' and A.sfid_id = 'SLE00001_OU' then '15'
     when tenant_code = 'masmovil_svg' and A.sfid_id = 'TLVOU001' then '15'
     
     else C.cod_canal
     end

  as cod_canal,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - SVE')) as concepto,
'CSEN' as tipo_concepto,
1 as unidades,
case 
       when tenant_code = 'masmovil'and b.sfid_id =  'TLVOU001'  then  20                --revisar con belen
       when tenant_code = 'yoigo' and A.sfid_id = 'SLE00001_OU' then 20               --revisar con belen
       when tenant_code = 'yoigo' and A.sfid_id = 'TLVOU001' then 20
--  Cartera Inbound/Outbound

--ENERGYGO-MASMOVIL


    when tenant_code IN ('yoigo', 'masmovil') and b.canal IN ('XI','XIN','XO','XOF','XS','XSN') THEN 10


--  DOOR TO DOOR 

--yoigo --MASOVIL

     WHEN tenant_code IN ('yoigo', 'masmovil') and b.canal IN ('D2N','D2D','DEM') THEN 10





-- Outbound/Inbound/Distribucion Online

--ENERGYGO--MASMOVIL

     WHEN tenant_code IN ('yoigo','masmovil')and b.canal IN ('OU','OUN','DO','DON') THEN 20  
     WHEN tenant_code IN ('yoigo','masmovil')and b.canal IN ( 'WA','CIN') THEN 10

     

--Agrupacion canal Exclusivo  

--ENERGYGO--MASMOVIL--PEPE

     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('EML','EYG','ENX') THEN 10
     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal = 'ENK' THEN 15

--Agrupacion canal No Exclusivo

--ENERGYGO--MASMOVIL--PEPE
     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('MP','ALTN','ST','ALTNC','ALTNH','PH') THEN 10
     when tenant_code IN ('yoigo','pepe') and b.canal = 'PH' THEN 10
     when tenant_code IN ('masmovil')        and b.canal = 'PH' THEN 15
   
               
END AS COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
UPPER(split(author_id, "@")[offset(0)])  as seller,
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
CAST(NULL as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
initial_lucera_tariff_name as tariff_ds,
CAST(NULL AS STRING) AS service_id,
cups_code as account_id,
CAST(NULL AS STRING) AS customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
activation_date as sale_date,
activation_date,
A.churn_date as deactivation_date,
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
FROM `mm-new-business-reporting.ENERGY.SVE`  A
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
ON A.sfid_id = B.sfid_id  
OR (substring(A.sfid_id,1,2)) = B.sfid_id
OR A.author_id = B.sfid_id
OR (substring(A.author_id,1,2)) = B.id_comisionista
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.id_comisionista
LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
AND B.canal = TLV_CROSS_SELL.canal
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL 
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE
  A.product = 'SVE'

AND B.canal = canal_pr
and DATE_TRUNC(DATE(A.activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
and tenant_code in ('yoigo','masmovil','pepe') 
and b.canal not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES','ATENCION AL CLIENTE','RECUPERADAS_AN','OTROS')   
and not b.canal in ('XIN','XSN','CIN','DON','NR')
and B.comisiona is true
QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1 


--__________________________________________________________________________GESTION DE CANAL - SVE ______________________________________________________________________
UNION ALL
select 
id_mes_pr as id_mes,
prefijo||'G-sve'||mes_string||'_'||b.canal||'_'||row_number () over ()  as commission_id,

C.canal as canal,
C.agrupacion_canal as agrupacion_canal,
 C.cod_canal   as cod_canal,
 'F - Gestion de canal SVE' as concepto,
'CSEN' as tipo_concepto,
1 as unidades,
case 

     when tenant_code IN ('yoigo','masmovil','pepe') and b.canal IN ('EML','EYG', 'ENX') THEN 0

             
END AS COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
UPPER(split(author_id, "@")[offset(0)])  as seller,
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
CAST(NULL as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
initial_lucera_tariff_name as tariff_ds,
CAST(NULL AS STRING) AS service_id,
cups_code as account_id,
CAST(NULL AS STRING) AS customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
activation_date as sale_date,
activation_date,
A.churn_date as deactivation_date,
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
FROM `mm-new-business-reporting.ENERGY.SVE`  A
LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` B 
ON A.sfid_id = B.sfid_id  
OR (substring(A.sfid_id,1,2)) = B.sfid_id
OR A.author_id = B.sfid_id
OR (substring(A.author_id,1,2)) = B.id_comisionista
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.author_id,'@')[OFFSET(0)]) = B.id_comisionista
LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
ON B.id_comisionista = TLV_CROSS_SELL.id_comisionista
AND B.canal = TLV_CROSS_SELL.canal
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL 
CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE
  A.product = 'SVE'
and B.canal = canal_pr
and DATE_TRUNC(DATE(A.activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
and tenant_code in ('yoigo','masmovil','pepe') 
and b.canal not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES','ATENCION AL CLIENTE','RECUPERADAS_AN','OTROS')   
and b.canal in ('EYG','EML')
QUALIFY ROW_NUMBER() OVER (PARTITION BY cups_code ORDER BY sfid_id DESC ) =  1  



    ;
call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('SVRG_', id_mes_pr, canales_pr , 'TEMP.ENERGY_SVE' , 'ACTUALIZAR');
end