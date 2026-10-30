begin

declare prefijo, mes_string string;
declare Y_atakam,Y_madison,M_madison,M_bemore int64;

set Y_atakam = 15040;

set Y_madison = 21856;

set M_madison = 12192;

set M_bemore = 19664;


set mes_string = cast(id_mes_pr as string);
SET canales_pr =["WA","XI", "XO", "XOF", "EML","EYG","ENX","EDB","MI","CA","MP","XS","D2D","D2N","MR","ALTN","ALTNC","DO","DEM"];

set prefijo = 'ALRM_';


--call COMISIONES.pr_alrm (202504, ["WA","EML","EYG","ENX","EDB","MI","CA","MP","XS","D2D","D2N","MR","ALTN","ALTNC","DEM","XI","DO","XO", "XOF"]);


create or replace table TEMP.leads_alarmas as --eta tabla ha sido creada para normalizar los sfids de exclusivo
 
  select * from (
select * except(sfid_LEAD,brand_ds) 
, case when  sfid_LEAD = 'LB' then upper(seller_LEAD) else sfid_LEAD end as sfid_LEAD1,
  case when tipo_alarma = 'MÁSMÓVIL ALARMAS' then 'MASMOVIL'
       when tipo_alarma = 'HOMEGO TELCO' then 'YOIGO' end as brand_ds  
from  `mm-sales-reporting.SPEEDUP.query_alarmas_multimarca` a
where  SMS_ok ='OK'
and tipo_lead = 'MASLEAD + BYSIDE' and duracion_BYSIDE >= 45 and destino_BYSIDE is not null AND DATE_TRUNC(DATE(fecha_lead), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) );

create or replace table TEMP.alrm as 

--___________________________________ CONCEPTO B- ALARMAS -- TODOS LOS CANALES-- EXCEPTO CROSSELLL____________________________
select 
id_mes_pr as id_mes,
prefijo||'B-al1'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
b.canal,
C.agrupacion_canal,
C.COD_CANAL,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Alarmas')) as concepto,
'ALRM' as tipo_concepto,
1 as unidades,
case 

-- Agrupacion por canal D2D distribuidores top 

    -- when b.canal = 'D2N'and b.sfid_id in ('D2N01451','D2N01131','D2N01107')   THEN 200     -------- ha cambiado esta condicion --------
     --when b.canal = 'D2D'and b.sfid_id in ('D2D725')   THEN 200

--Agrupacion canal D2D

     when b.canal = 'D2N' OR b.canal = 'D2D' OR b.canal = 'DEM' THEN 150


--Agrupacion canal Exclusivo  

     when b.canal = 'EML' THEN 130
     when b.canal = 'EYG' THEN 130
     when b.canal = 'ENX' THEN 130
     when b.canal = 'EDB' THEN 300
     when b.canal = 'MP' THEN 130

--Agrupacion canal No Exclusivo  

     --when b.canal = 'MI' THEN 90
     --when b.canal = 'MR' THEN 90
     --when b.canal = 'CA' THEN 90
     --when b.canal = 'ALTN' THEN 90
     --when b.canal = 'ALTNC' THEN 90
     when b.canal = 'TPH' THEN 125
     when b.canal = 'PH' THEN 125
  
--Agrupacion canal Distribcion Online 

     when b.canal = 'DO' THEN 300

--canal Inbound

     when b.canal ='XI'THEN 50
     when b.canal ='XO'THEN 50
     when b.canal ='XOF'THEN 50

               
END AS COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
upper(split(seller, "@")[offset(0)])  as seller,                                                -- PROBADA, NO ES 
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,
 brand_ds as marca,
'SECURITY' as service_type,
cast(phone_nm as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
a.kit as tariff_ds,
service_id,
installation_contract as account_id,
customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
a.request_date as sale_date,
a.installation_date as activation_date,
a.fecha_baja_contrato as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'012' as cod_producto,
CASE WHEN A.brand_ds ='YOIGO' THEN '01'
     WHEN A.brand_ds ='MASMOVIL' THEN '05'
     ELSE '01' END AS cod_marca,
cast (null as string) as claim_code,
CASE
    WHEN a.installation_date < '2024-07-22'
    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)

    ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
END AS campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` a
left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
ON A.sfid_id = B.sfid_id  
OR substring(A.sfid_id,1,2) = B.sfid_id
OR A.user_store = B.sfid_id
OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.id_comisionista
left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
ON b.id_comisionista = tlv_cross_sell.id_comisionista
AND b.canal = tlv_cross_sell.canal
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
WHERE NOT (
            b.canal = 'XS'
            AND brand_ds = 'MASMOVIL'
            AND b.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013')
            AND CASE
                    WHEN a.installation_date < '2024-07-22'
                    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)
                
                    ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
                END = 'Lineas adicionales OUT'
           
            )
AND NOT (
            b.canal in ('WA', 'OU', 'DO','CIN','XS','PDV','NR','WOP','XIN','OUN','STA','TF','AGE')
          
          )

            
AND DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
and b.sfid_id is not null
and brand_ds in ('YOIGO', 'MASMOVIL')
QUALIFY ROW_NUMBER() OVER (PARTITION BY installation_contract ORDER BY sfid_id, activation_date  DESC) = 1




union all


--_________________________________________________________________________________GESTION DE CANAL__________________________________________________________________

select 
id_mes_pr as id_mes,
prefijo||'F-gal'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
b.canal,
C.agrupacion_canal,
C.COD_CANAL,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('F - Gestion Canal Alarmas')) as concepto,
'ALRM' as tipo_concepto,
1 as unidades,
case 

--Agrupacion canal Exclusivo  
     when b.canal = 'EML' THEN 5
     when b.canal = 'EYG' THEN 5
     when b.canal = 'ENX' THEN 5

--Agrupacion canal No Exclusivo  
    
     -- when b.canal = 'MI' THEN 15
     -- when b.canal = 'PH' THEN 25
     -- when b.canal = 'ALTN' THEN 15
     -- when b.canal = 'ALTNC' THEN 15
     -- when b.canal = 'TPH' THEN 25
     -- when b.canal = 'CA' THEN 15
    
     end as COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
split(seller, "@")[offset(0)]  as seller,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,
 brand_ds as marca,
'SECURITY' as service_type,
cast(phone_nm as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
a.kit as tariff_ds,
service_id,
installation_contract as account_id,                                                                                              --PROBADA, NO DA VARIACION
customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
a.request_date as sale_date,
a.installation_date as activation_date,
a.fecha_baja_contrato as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'012' as cod_producto,
CASE WHEN A.brand_ds ='YOIGO' THEN '01'
     WHEN A.brand_ds ='MASMOVIL' THEN '05'
     ELSE '01' END AS cod_marca,
cast (null as string) as claim_code,
CASE
    WHEN a.installation_date < '2024-07-22'
    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)

    ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
END AS campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` a
left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
ON A.sfid_id = B.sfid_id  
OR substring(A.sfid_id,1,2) = B.sfid_id
OR A.user_store = B.sfid_id
OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.id_comisionista
left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
ON b.id_comisionista = tlv_cross_sell.id_comisionista
AND b.canal = tlv_cross_sell.canal
inner join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
left join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on b.distribuidor = m.id_comisionista
WHERE (DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))                       
and brand_ds in ('YOIGO','MASMOVIL')
and b.canal in ('EYG','EML')
and sfid_subchannel not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES')
)
or (DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) 
and brand_ds in ('YOIGO','MASMOVIL') 
and B.canal in ('MI','CA','PH')
and sfid_subchannel not in ('WEB', 'PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES')
and B.cif in (select documento from `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad`))
and b.sfid_id is not null

QUALIFY ROW_NUMBER() OVER (PARTITION BY installation_contract ORDER BY sfid_id, activation_date  DESC) = 1



  
union all

--____________________________________________________________________________SECCION CROSSELL_____________________________________________________________________





--____________________________________________________________________________CONCEPTO D - RAPPEL ALARMAS_CROSSELL______________________________________________________
select * 
from 
(
select 
id_mes_pr as id_mes,
prefijo||'D-ral'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
b.canal,
C.agrupacion_canal,
C.COD_CANAL,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('D - Rappel alarma')) as concepto, 
'ALRM' as tipo_concepto,
1 as unidades,
case 


      
      when b.canal = 'XS' and canal2 = 'CARTERA OUTBOUND' and lower(seller) like '%_al%' and b.sfid_id IN ('CARIN008','CAROUT016') then 90 --mm_madison
      when b.canal = 'XS' and canal2 = 'CARTERA OUTBOUND' and lower(seller)like '%_al%' and b.sfid_id IN ('CAROUT010','CAROUT023') then 100 --mm_bemore
         

      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and lower(substr(seller, 1,2))= 'mv' and seller like '%_hg%' and b.sfid_id IN ('CARIN008','CAROUT016') then 60 --yoigo_madison upfrom
      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and b.sfid_id = 'MV' then 60 --yoigo_madison -- no tienen seller se filtran diferente upfront

      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and lower(substr(seller, 1,2))= 'av' and seller like '%_hg%' and b.sfid_id IN ('CAROUT008','CAROUT027') then 90 --yoigo_atakam
      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and b.sfid_id = 'AV' then 90 --yoigo_atakam   -- no tienen seller, se filtra diferente


               
END AS COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
upper(split(seller, "@")[offset(0)])  as seller,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,

case 
-- 

      
      when b.canal = 'XS' and canal2 = 'CARTERA OUTBOUND' and seller like '%_al%' and b.sfid_id IN ('CARIN008','CAROUT016') then 'MASMOVIL' --mm_madison
      when b.canal = 'XS' and canal2 = 'CARTERA OUTBOUND' and upper(seller) like '%_AL' and b.sfid_id IN ('CAROUT010','CAROUT023') then 'MASMOVIL' --mm_bemore
      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and b.sfid_id = 'MV' then 'YOIGO' --yoigo_madison -- no tienen seler se filtran diferente
      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and b.sfid_id = 'AV' then 'YOIGO' --yoigo_atakam   -- no tienen seller, se filtra diferente 
      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and upper(substr(seller, 1,2))= 'MV' and upper(seller) like '%_HG%' and b.sfid_id IN ('CARIN008','CAROUT016') then 'YOIGO' --yoigo_madison
      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and upper(substr(seller, 1,2))= 'AV' and upper(seller) like '%_HG%' and b.sfid_id IN ('CAROUT008','CAROUT027') then 'YOIGO' --yoigo_atakam
      
else brand_ds
               
END AS marca,
'SECURITY' as service_type,
cast(phone_nm as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
a.kit as tariff_ds,
service_id,
installation_contract as account_id,
customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,                                                                                               --PROBADA NO VARIA
a.request_date as sale_date,
a.installation_date as activation_date,
a.fecha_baja_contrato as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'012' as cod_producto,
CASE WHEN A.brand_ds ='YOIGO' THEN '01'
     WHEN A.brand_ds ='MASMOVIL' THEN '05'
     ELSE '01' END AS cod_marca,
cast (null as string) as claim_code,
CASE
    WHEN a.installation_date < '2024-07-22'
    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)

    ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
END AS campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` a
left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version`b
ON A.sfid_id = B.sfid_id  
OR substring(A.sfid_id,1,2) = B.sfid_id
OR A.user_store = B.sfid_id
OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.id_comisionista
left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
ON b.id_comisionista = tlv_cross_sell.id_comisionista
AND b.canal = tlv_cross_sell.canal
left join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
WHERE Canal2 = 'CARTERA OUTBOUND'
and b.canal = 'XS'
AND b.sfid_id in ('CAROUT027','CAROUT023','CAROUT016','CAROUT013','CARIN008','CAROUT010','CAROUT008','AV','MV')
AND DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))   
and b.sfid_id is not null
and brand_ds in ('YOIGO', 'MASMOVIL')          
QUALIFY ROW_NUMBER() OVER (PARTITION BY installation_contract ORDER BY sfid_id, activation_date  DESC) = 1
)
where comision != 0


--___________________________________________________________________________ CONCEPTO B - ALARMAS_CROSSELL ______________________________________________________________
union all       

select 
id_mes_pr as id_mes,
prefijo||'B-al2'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
b.canal,
C.agrupacion_canal,
C.COD_CANAL,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Alarmas')) as concepto,  
'ALRM' as tipo_concepto,
1 as unidades,
case 


      
      when b.canal = 'XS' and canal2 = 'CARTERA OUTBOUND' and lower(seller) like '%_al%' and a.sfid_id IN ('CARIN008','CAROUT016') then ROUND (M_madison/(select count(sfid_id) from `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
    where DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and canal2 = 'CARTERA OUTBOUND' and lower(seller) like '%_al%' and sfid_id IN ('CARIN008','CAROUT016')),2)  --mm_madison   


      when b.canal = 'XS' and canal2 = 'CARTERA OUTBOUND' and lower(seller)like '%_al%' and a.sfid_id IN ('CAROUT010','CAROUT023') then ROUND (M_bemore/(select count(sfid_id) from `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
    where DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and canal2 = 'CARTERA OUTBOUND' and lower(seller)like '%_al%' and sfid_id IN ('CAROUT010','CAROUT023')),2) --mm_bemore  


      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and a.sfid_id IN ('CARIN008','CAROUT016') AND brand_ds = 'YOIGO' then ROUND (Y_madison/(select count(sfid_id) from `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
    where DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and Canal2 = 'CARTERA OUTBOUND' and sfid_id IN ('CARIN008','CAROUT016') AND brand_ds = 'YOIGO'),2)  --yoigo_madison  

      when b.canal = 'XS' and Canal2 = 'CARTERA OUTBOUND' and a.sfid_id IN ('CAROUT008','CAROUT027') then ROUND (Y_atakam/(select count(sfid_id) from `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` 
    where DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) and Canal2 = 'CARTERA OUTBOUND' and sfid_id IN ('CAROUT008','CAROUT027')),2) --yoigo_atakam   -- no tienen seller, se filtra diferente  



               
END AS COMISION,

b.id_comisionista,
b.distribuidor,
b.id_comisionista as sfid_id,
split(seller, "@")[offset(0)]  as seller,
b.nombre_comercio,
b.razon_social,
b.cif,
b.zona_fiscal,
brand_ds  as marca,
'SECURITY' as service_type,
cast(phone_nm as string) as phone_nm,
CAST(NULL AS STRING) AS tariff_id,
a.kit as tariff_ds,                                                                                                          --PROBADO NO VARIA 
service_id,
installation_contract as account_id,
customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
a.request_date as sale_date,
a.installation_date as activation_date,
a.fecha_baja_contrato as deactivation_date,
cast (null as string) as order_id,
cast (null as string) as order_type_agg,
'10' as cod_segmento,
'99' as cod_tipo_contrato,
'012' as cod_producto,
CASE WHEN A.brand_ds ='YOIGO' THEN '01'
     WHEN A.brand_ds ='MASMOVIL' THEN '05'
     ELSE '01' END AS cod_marca,
cast (null as string) as claim_code,
CASE
    WHEN a.installation_date < '2024-07-22'
    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)

    ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
END AS campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
from  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` a
left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
ON A.sfid_id = B.sfid_id  
OR substring(A.sfid_id,1,2) = B.sfid_id
OR A.user_store = B.sfid_id
OR UPPER((substring(A.user_store,1,2))) = B.id_comisionista
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.sfid_id
OR UPPER(split(a.seller,'@')[OFFSET(0)]) = B.id_comisionista
left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
ON b.id_comisionista = tlv_cross_sell.id_comisionista
AND b.canal = tlv_cross_sell.canal
left join `mm-commissions-reporting.GS.CANALES` C ON B.CANAL=C.CANAL
WHERE Canal2 = 'CARTERA OUTBOUND'
and b.canal = 'XS'
AND b.sfid_id in ('CAROUT027','CAROUT023','CAROUT016','CAROUT013','CARIN008','CAROUT010','CAROUT008','AV','MV')
AND DATE_TRUNC(DATE(installation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
and NOT (
            b.canal = 'XS' AND seller like ('%_xs%')) 
            and b.sfid_id is not null
and brand_ds in ('YOIGO', 'MASMOVIL')
and b.sfid_id is not null
QUALIFY ROW_NUMBER() OVER (PARTITION BY installation_contract ORDER BY sfid_id, activation_date  DESC) = 1



--_________________________________________________________________LEADS ___________________________________________________________________________________

 


-- union all

-- select * 
-- from( 
-- select 
-- id_mes_pr as id_mes,
-- prefijo||'B-lal'||mes_string||'_'||b.canal||'_'||row_number () over () as commission_id,
-- CASE WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN 'XO' ELSE  b.canal END as canal,
-- C.agrupacion_canal,
-- C.COD_CANAL,
-- (SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Leads Alarmas')) as concepto,
-- 'ALRM' as tipo_concepto,
-- 1 as unidades,
 
-- case
 
-- --Agrupacion canal Exclusivo  
 
--      when c.canal = 'EML' THEN 5
--      when c.canal = 'EYG' THEN 5
 
-- --canal cross sell

--       WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN (4*1.05)
      
--      else 0
 
-- END AS COMISION,
 
-- CASE WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN 'CARIN003' ELSE  b.id_comisionista END as id_comisionista,
 
-- CASE WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN 'CARIN003' ELSE  b.distribuidor END as distribuidor,
 
-- b.sfid_id as sfid_id,
  
-- upper(a.seller_LEAD) as seller,
 
-- CASE WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN 'MARKTEL IN' ELSE  b.nombre_comercio END as nombre_comercio,
 
-- CASE WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN 'MARKTEL SERVICIOS DE MARKETING TELE' ELSE  b.razon_social END as razon_social ,
 
-- CASE WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN 'A82236944' ELSE  b.cif END as cif,
 
-- CASE WHEN c.canal IN ('WA','XI','XO','XOF','XS') THEN 'PEN' ELSE  b.zona_fiscal END as zona_fiscal,
 
-- A.brand_ds as marca,
-- 'SECURITY' as service_type,
-- cast(contact_phone_LEAD as string) as phone_nm,
-- CAST(NULL AS STRING) AS tariff_id,
-- a.tipo_alarma as tariff_ds,
-- service_id,
-- installation_contract as account_id,
-- customer_id,
-- CAST(NULL AS STRING) AS line_type_ds,
-- CAST(NULL AS STRING) AS bundle_type,
-- CAST(NULL AS STRING) AS technology_ds,
-- CAST(NULL AS STRING) AS billing_type_ds,
-- a.request_date as sale_date,
-- a.fecha_lead as activation_date,
-- cast(null as date) as deactivation_date,
-- cast (null as string) as order_id,
-- cast (null as string) as order_type_agg,
-- '10' as cod_segmento,
-- '99' as cod_tipo_contrato,
-- '012' as cod_producto,

-- CASE WHEN A.brand_ds ='YOIGO' THEN '01'
 
--      WHEN A.brand_ds ='MASMOVIL' THEN '05'
 
--      ELSE '01' END AS cod_marca,
 
-- cast (null as string) as claim_code,
-- CASE
--     WHEN B.CANAL = 'XI' THEN 'Alarmas OUT'
    
--     WHEN a.fecha_lead < '2024-07-22'
--     THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)

--     ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
-- END AS campaign_code,
-- cast ( null as string ) serial_number,
-- cast ( null as float64 ) tax_base,
-- cast (null as string) as process_code,
-- cast (null as string) as comments,
-- 'C_MANUAL' as facturador,
-- 'calculado' as estado
-- from  TEMP.leads_alarmas a
-- left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b 
-- on upper(a.sfid_LEAD1) = upper(b.sfid_id) 

--    --on( upper(a.seller_LEAD) = b.sfid_id )
--    --or a.sfid_LEAD= b.sfid_id 
--    --or a.sfid_id    || '_' || a.seller = replace ( b.sfid_id , ' ', '') )

-- left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
-- ON b.id_comisionista = tlv_cross_sell.id_comisionista
-- AND b.canal = tlv_cross_sell.canal
 
-- inner join `mm-commissions-reporting.GS.CANALES` c
--            on b.canal = C.canal 
--           and  `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds_LEAD, channel_ds_LEAD, subchannel_ds_LEAD) = c.agrupacion_canal
  
-- WHERE NOT (
 
--             b.canal = 'XS' 
--             AND brand_ds = 'MASMOVIL' 
--             AND b.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013') 
--             AND CASE
--                     WHEN a.fecha_lead < '2024-07-22'
--                     THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)
                
--                     ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
--                 END = 'Lineas adicionales OUT'
 
--           ) 
-- AND NOT (
 
--             b.canal in ('OU', 'DO','CIN','PDV','NR','EDB','WOP','XIN') 
 
--             )
 
-- AND DATE_TRUNC(DATE(fecha_lead), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))  
-- and c.canal in ('WA','XI','XO','XOF','XS')
-- AND b.sfid_id is not null
-- AND a.SMS_ok ='OK'
-- and tipo_lead = 'MASLEAD + BYSIDE' and duracion_BYSIDE >= 60 and destino_BYSIDE is not null 
-- or 

--  NOT (
 
--             b.canal = 'XS' 
--             AND brand_ds = 'MASMOVIL' 
--             AND b.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013') 
--             AND CASE
--                     WHEN a.fecha_lead < '2024-07-22'
--                     THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)
                
--                     ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(b.canal, a.brand_ds, a.sfid_id, 'SECURITY'))
--                 END = 'Lineas adicionales OUT'
 
--           ) 
-- AND NOT (
 
--             b.canal in ('OU', 'DO','CIN','PDV','NR','EDB','WOP','XIN') 
 
--             )
-- AND DATE_TRUNC(DATE(fecha_lead), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))           
-- AND c.canal in ('EML','EYG')
-- AND b.sfid_id is not null
-- AND a.SMS_ok ='OK'

 
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY a.seller_LEAD, contact_phone_LEAD, a.fecha_lead ORDER BY a.fecha_lead DESC) = 1
-- )

-- qualify  count(*) over (partition by seller ) >= 3 




;

 --call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('ALRM_', id_mes_pr, (select array_agg(distinct canal) from TEMP.alrm) , 'TEMP.alrm' , 'ACTUALIZAR');


end