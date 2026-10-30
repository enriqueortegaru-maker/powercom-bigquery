BEGIN


DECLARE mes_string, prefijo STRING;


SET mes_string = CAST(mes_int AS STRING);
SET prefijo = 'CIBER';


-- CALL `mm-commissions-reporting.COMISIONES.pr_cibe`(202410);



create or replace table TEMP.ciber as (

--___________________________________ CONCEPTO B- ALARMAS -- TODOS LOS CANALES-- EXCEPTO CROSSELLL____________________________
select 
-- id_mes_pr as id_mes,
mes_string AS id_mes,
prefijo||mes_string||'_'||c.canal||'_'||row_number () over () as commission_id,
c.canal,
C.agrupacion_canal,
d.cod_canal,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('B - Ciberseguridad')) as concepto,
'OTRS' as tipo_concepto,
1 as unidades,
case 

-- Agrupacion por canal D2D distribuidores top 

    -- when b.canal = 'D2N'and b.sfid_id in ('D2N01451','D2N01131','D2N01107')   THEN 200     -------- ha cambiado esta condicion --------
     --when b.canal = 'D2D'and b.sfid_id in ('D2D725')   THEN 200

--Agrupacion canal D2D

    --  when c.canal = 'D2N' OR c.canal = 'D2D' OR c.canal = 'DEM' THEN 150


--Agrupacion canal Exclusivo  

     when c.canal = 'EML' THEN 18
     when c.canal = 'EYG' THEN 18

--Agrupacion canal No Exclusivo  
    --  when b.canal = 'MP' THEN 100
    --  when b.canal = 'MI' THEN 90
    --  when b.canal = 'MR' THEN 90
    --  when b.canal = 'CA' THEN 90
    --  when b.canal = 'TPH' THEN 125
    --  when b.canal = 'PH' THEN 125
  
--canal Inbound
     when c.canal ='WA'THEN 10   
     when c.canal ='XI'THEN 10
     when c.canal ='XO'THEN 10
     when c.canal ='XOF'THEN 10
     when c.canal ='XS'THEN 20
     when c.canal ='DO'THEN 20
     when c.canal ='OU'THEN 20


               
END AS COMISION,

c.id_comisionista,
c.distribuidor,
c.id_comisionista as sfid_id,
b.user_store  as seller,                                                -- PROBADA, NO ES 
c.nombre_comercio,
c.razon_social,
c.cif,
c.zona_fiscal,
 a.brand_ds as marca,
'SECURITY' as service_type,
cast(a.phone_nm as string) as phone_nm,
sell_tariff_id AS tariff_id,
b.sell_tariff_ds as tariff_ds,
a.service_id,
a.account_id,
a.customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
b.order_date as sale_date,
a.activation_date,
a.deactivation_date,
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
    WHEN a.activation_date < '2024-07-22'
    THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(c.canal, a.brand_ds, b.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)

    ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(c.canal, a.brand_ds, b.sfid_id, 'SECURITY'))
END AS campaign_code,
cast ( null as string ) serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
'C_MANUAL' as facturador,
'calculado' as estado
FROM `mm-datamart-kd.SERVICES.service_base_sva_emysim` a
left join `mm-datamart-kd.SERVICES.ventas_base_telco_emysim`b
on a.service_id =b.service_id and b.service_type ='BROADBAND' and a.customer_id =b.customer_id and a.account_id =b.account_id 
and a.phone_nm=b.phone_nm and a.brand_ds=b.brand_ds AND  b.activation_date >= date_add (a.activation_date, interval -1 month)
left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` c
ON b.sfid_id = c.sfid_id  
OR B.current_sfid_id =c.sfid_id
OR substring(b.sfid_id,1,2) = c.sfid_id
OR b.user_store = c.sfid_id
OR UPPER((substring(b.user_store,1,2))) = c.id_comisionista
OR UPPER(split(b.seller,'@')[OFFSET(0)]) = c.sfid_id
OR UPPER(split(b.seller,'@')[OFFSET(0)]) = c.id_comisionista
left join `mm-commissions-reporting.GS.tlv_cross_sell_dealers` tlv_cross_sell
ON c.id_comisionista = tlv_cross_sell.id_comisionista
AND c.canal = tlv_cross_sell.canal
inner join `mm-commissions-reporting.GS.CANALES` d ON c.CANAL=d.CANAL
-- WHERE NOT (
--             c.canal = 'XS'
--             AND a.brand_ds = 'MASMOVIL'
--             AND c.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013')
--             AND CASE
--                     WHEN a.activation_date < '2024-07-22'
--                     THEN COALESCE(`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(c.canal, b.brand_ds, c.sfid_id, 'SECURITY'), tlv_cross_sell.campaign)
                
--                     ELSE COALESCE(tlv_cross_sell.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(c.canal, a.brand_ds, c.sfid_id, 'SECURITY'))
--                 END = 'Lineas adicionales OUT'
           
--             )
-- AND NOT (
--             c.canal in ('WA', 'OU', 'DO','XS','CIN','PDV','NR','EDB','WOP','XIN','OUN','STA','TF','AGE')
          
--           )

            
where  DATE_TRUNC(DATE(a.activation_date), MONTH) =  PARSE_DATE('%Y%m', CAST(202410 AS STRING))
and b.sfid_id is not null
and a.brand_ds in ('YOIGO', 'MASMOVIL')
and a.sva_modality IN ("Servicio Ciberayuda", "Servicio Ayuda Masmóvil")
and c.canal in ('XO','XI','XOF','EYG','EML','OU', 'DO','XS','WA')
QUALIFY ROW_NUMBER() OVER (PARTITION BY a.service_id,a.customer_id,a.phone_nm, a.brand_ds  ORDER BY c.id_mes  DESC) = 1
);


-- CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (
--                                                                 prefijo,
--                                                                 mes_int,
--                                                                 (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.ciber WHERE canal IS NOT NULL),
--                                                                 'TEMP.reex',
--                                                                 'ACTUALIZAR'
--                                                                 )
-- ;

END