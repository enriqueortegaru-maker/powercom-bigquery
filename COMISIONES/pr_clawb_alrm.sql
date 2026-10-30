begin

declare prefijo, mes_string string;

set mes_string = cast(id_mes_pr as string);

SET canales_pr =["WA","XI","EML","EYG","MI","CA","MP","XS","D2D","D2N","MR","DEM"];

set prefijo = 'ALRM_';

--call COMISIONES.pr_clawb_alrm (202404, ["WA","EML","EYG","MI","CA","MP","XS","D2D","D2N","MR","DEM","XI"]);
--call `mm-commissions-reporting.COMISIONES.pr_validar_agrupacion_canal`(null, 'ALRM', 125612.80)




--update `mm-commissions-reporting.COMISIONES.transacciones` set estado = 'calculado' where estado = 'validado' and id_mes = 202402 and commission_id like 'ALRM%';



create or replace table TEMP.clawb_alrm as 
select 
id_mes_pr as id_mes,
prefijo||'E-Clal'||mes_string||'_'||canal||'_'||row_number () over () as commission_id,
tr.canal,
tr.agrupacion_canal,
tr.COD_CANAL,
(SELECT concepto from `mm-commissions-reporting.GS.CONCEPTOS` WHERE CONCEPTO IN ('E - Clawback Alarmas')) as concepto,  
'ALRM' as tipo_concepto,
1 as unidades,
case 

when canal = 'XI'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal = 'XI'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.25) * -1
when canal = 'XI'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1
when canal = 'EYG' AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal = 'EYG' AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.25) * -1
when canal = 'EYG' AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1
when canal = 'MI'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal = 'MI'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.25) * -1
when canal = 'MI'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.50) * -1
when canal = 'MR'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal = 'MR'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.25) * -1
when canal = 'MR'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1
when canal = 'EML' AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal = 'EML' AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.25) * -1
when canal = 'EML' AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1
when canal = 'MP'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal = 'MP'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.25) * -1
when canal = 'MP'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1
when canal = 'PH'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal = 'PH'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.25) * -1
when canal = 'PH'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1

when canal = 'D2D'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 180 THEN comision * -1
when canal = 'D2N'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 180 THEN comision * -1
when canal = 'DEM'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 180 THEN comision * -1

END AS COMISION,


tr.id_comisionista,
tr.distribuidor,
tr.sfid_id,
tr.seller,
tr.nombre_comercio,
tr.razon_social,
tr.cif,
tr.zona_fiscal,
tr.marca,
tr.service_type,
tr.phone_nm,
tr.tariff_id,
tr.tariff_ds,
tr.service_id,
tr.account_id,
tr.customer_id,
tr.line_type_ds,
tr.bundle_type,
tr.technology_ds,
tr.billing_type_ds,
tr.sale_date,
tr.activation_date,
al.fecha_baja_contrato as deactivation_date,
tr.order_id,
tr.order_type_agg,
tr.cod_segmento,
tr.cod_tipo_contrato,
tr.cod_producto,
tr.cod_marca,
tr.claim_code,
tr.campaign_code,
cast ( null as string ) as serial_number,
cast ( null as float64 ) as tax_base,
tr.process_code,
tr.comments,
'C_MANUAL' as facturador,
'calculado' as estado
from  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` al
left join `mm-commissions-reporting.COMISIONES.transacciones` tr 
on tr.service_id = al.service_id
where tipo_concepto = 'ALRM'
and ot_status  in('INSTALADA')
AND DATE_TRUNC(DATE(fecha_baja_contrato), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
    and DATE_DIFF (fecha_baja_contrato, installation_date, DAY)< 180 
    and sfid_subchannel NOT IN ('PLAT. FIDELIZACION/RETENCION', 'CARTERA OUTBOUND')
    and comision is not null
    and canal !='XS'
    and not (concepto = 'E - Clawback Alarmas' and estado = 'facturado');


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, (select array_agg(distinct canal) from TEMP.alrm) , 'TEMP.clawb_alrm' , 'ACTUALIZAR'); 

end