begin 

declare sql string;

create or replace temporary table  BYMOBILE

partition by recharge_month as (
with
total as (
select *

from 
(


--- ACTIVACIONES NO FIRMADOS

Select distinct 
0 num_recarga,
msisdn,
activationdate as recharge_date,
CASE WHEN
(case
	when operator_donor is not null then 1
end)=1 THEN 8 

ELSE 5 END  as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(activationdate as date),month) as recharge_month,
'A - Servicio Movil Prepago'	description, 
ROUND(CASE WHEN
(case
	when operator_donor is not null then 1
end)=1 THEN 8 

ELSE 5 END,2)

as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

left JOIN (Select distinct id_comisionista,canal,fecha_firma from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL IN ('ENK'))
ON REPLACE(SFID,"LB-","")=id_comisionista

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


where date_trunc(cast(activationdate as date), month)= mes 
AND date_diff(DATE_TRUNC(ifnull(deactivationdate,'9999-12-31'),MONTH),DATE_TRUNC(activationdate,day),MONTH)>0
and ifnull(operator_donor,'')<>brand_ds
and 

CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
 OR  A.SFID LIKE 'ML%' 
 OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
  OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
 OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(id_comisionista,'-')='-'
and ifnull(cod_producto_sim,'-') <>'P05407'


UNION ALL


  -- 1 RECARGA SIM NORMAL NUEVO MARCO

Select distinct 
1 num_recarga,
msisdn,
First_topup_date as recharge_date,
First_topup_amount  as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(First_topup_date as date),month) as recharge_month,
'A - Servicio Movil Prepago'	description, 
ROUND(CASE 
WHEN zona_fiscal='CAN' AND First_topup_amount/1.07*0.8>25 THEN 25 
WHEN zona_fiscal='MEL' AND First_topup_amount/1.08*0.8>25 THEN 25 
WHEN First_topup_amount/1.21*0.8>25 THEN 25 
WHEN zona_fiscal='CAN'  THEN First_topup_amount/1.07*0.8 
WHEN zona_fiscal='MEL'  THEN First_topup_amount/1.08*0.8 
ELSE First_topup_amount/1.21*0.8 END,2)  as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(SFID,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(Activationdate as date),month) OR comentarios = 'NUEVO PRELIQUI')



LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


where date_trunc(cast(First_topup_date as date), month)= mes 
AND Activationdate>='2025-07-01'

and 

CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
 OR  A.SFID LIKE 'ML%' 
  OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%'
  OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%'  
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 

) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(cod_producto_sim,'-') <>'P05407'
AND date_diff(First_topup_date,activationdate,day)<=30


UNION ALL

  -- 2 RECARGA SIM NORMAL

Select distinct 
2 num_recarga,
msisdn,
Second_topup_date as recharge_date,
Second_topup_amount  as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(Second_topup_date as date),month) as recharge_month,
'C - Recarga Sucesiva'	description, 
ROUND(CASE 
WHEN zona_fiscal='CAN' AND Second_topup_amount/1.07*0.25>25 THEN 25 
WHEN zona_fiscal='MEL' AND Second_topup_amount/1.08*0.25>25 THEN 25 

WHEN Second_topup_amount/1.21*0.25>25 THEN 25 

WHEN zona_fiscal='CAN' THEN Second_topup_amount/1.07*0.25 
WHEN zona_fiscal='MEL' THEN Second_topup_amount/1.08*0.25 

ELSE Second_topup_amount/1.21*0.25 END,2)  as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(SFID,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(Activationdate as date),month) OR comentarios = 'NUEVO PRELIQUI')


LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


where date_trunc(cast(Second_topup_date as date), month)= mes  
AND Activationdate>='2025-07-01'
and 

CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
  OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(cod_producto_sim,'-') <>'P05407'
AND date_diff(Second_topup_date,activationdate,day)<=180



UNION ALL

  -- 3 RECARGA SIM NORMAL

Select distinct 
3 num_recarga,
msisdn,
third_topup_date as recharge_date,
third_topup_amount  as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(third_topup_date as date),month) as recharge_month,
'C - Recarga Sucesiva'	description, 
ROUND(CASE 
WHEN zona_fiscal='CAN' AND third_topup_amount/1.07*0.25>25 THEN 25 
WHEN zona_fiscal='MEL' AND third_topup_amount/1.08*0.25>25 THEN 25 
WHEN third_topup_amount/1.21*0.25>25 THEN 25 
WHEN zona_fiscal='CAN' THEN third_topup_amount/1.07*0.25 
WHEN zona_fiscal='MEL' THEN third_topup_amount/1.08*0.25 
ELSE third_topup_amount/1.21*0.25 END,2)  as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(SFID,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(Activationdate as date),month) OR comentarios = 'NUEVO PRELIQUI')


LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


where date_trunc(cast(third_topup_date as date), month)= mes  
AND Activationdate>='2025-07-01'
and 

CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
  OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(cod_producto_sim,'-') <>'P05407'
AND date_diff(third_topup_date,activationdate,day)<=180


UNION ALL

  -- 4 RECARGA SIM NORMAL

Select distinct 
4 num_recarga,
msisdn,
fourth_topup_date as recharge_date,
fourth_topup_amount  as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(fourth_topup_date as date),month) as recharge_month,
'C - Recarga Sucesiva'	description, 
ROUND(CASE 
WHEN zona_fiscal='CAN' AND fourth_topup_amount/1.07*0.25>25 THEN 25 
WHEN zona_fiscal='MEL' AND fourth_topup_amount/1.08*0.25>25 THEN 25 
WHEN fourth_topup_amount/1.21*0.25>25 THEN 25 
WHEN zona_fiscal='CAN' THEN fourth_topup_amount/1.07*0.25 
WHEN zona_fiscal='MEL' THEN fourth_topup_amount/1.08*0.25 
ELSE fourth_topup_amount/1.21*0.25 END,2)  as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(SFID,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(Activationdate as date),month) OR comentarios = 'NUEVO PRELIQUI')

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


where date_trunc(cast(fourth_topup_date as date), month)= mes  
AND Activationdate>='2025-07-01'
and 

CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
  OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(cod_producto_sim,'-') <>'P05407'
AND date_diff(fourth_topup_date,activationdate,day)<=180



UNION ALL

  -- 5 RECARGA SIM NORMAL

Select distinct 
5 num_recarga,
msisdn,
fifth_topup_date as recharge_date,
fifth_topup_amount  as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(fifth_topup_date as date),month) as recharge_month,
'C - Recarga Sucesiva'	description, 
ROUND(CASE 
WHEN zona_fiscal='CAN' AND fifth_topup_amount/1.07*0.25>25 THEN 25 
WHEN zona_fiscal='MEL' AND fifth_topup_amount/1.08*0.25>25 THEN 25 
WHEN fifth_topup_amount/1.21*0.25>25 THEN 25 
WHEN zona_fiscal='CAN' THEN fifth_topup_amount/1.07*0.25 
WHEN zona_fiscal='MEL' THEN fifth_topup_amount/1.08*0.25 
ELSE fifth_topup_amount/1.21*0.25 END,2)  as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(SFID,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(Activationdate as date),month) OR comentarios = 'NUEVO PRELIQUI')


LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


where date_trunc(cast(fifth_topup_date as date), month)= mes  
AND Activationdate>='2025-07-01'
and 

CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
  OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(cod_producto_sim,'-') <>'P05407'
AND date_diff(fifth_topup_date,activationdate,day)<=180



UNION ALL

  -- 6 RECARGA SIM NORMAL

Select distinct 

6 num_recarga,
msisdn,
sixth_topup_date as recharge_date,
sixth_topup_amount  as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(sixth_topup_date as date),month) as recharge_month,
'C - Recarga Sucesiva'	description, 
ROUND(CASE 
WHEN zona_fiscal='CAN' AND sixth_topup_amount/1.07*0.25>25 THEN 25 
WHEN zona_fiscal='MEL' AND sixth_topup_amount/1.08*0.25>25 THEN 25 
WHEN sixth_topup_amount/1.21*0.25>25 THEN 25 
WHEN zona_fiscal='CAN' THEN sixth_topup_amount/1.07*0.25 
WHEN zona_fiscal='MEL' THEN sixth_topup_amount/1.08*0.25 
ELSE sixth_topup_amount/1.21*0.25 END,2)  as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(SFID,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(Activationdate as date),month) OR comentarios = 'NUEVO PRELIQUI')


LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


where date_trunc(cast(sixth_topup_date as date), month)= mes  
AND Activationdate>='2025-07-01'
and 

CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
  OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(cod_producto_sim,'-') <>'P05407'
AND date_diff(sixth_topup_date,activationdate,day)<=180




UNION ALL

-- COMISION DISPOSITIVOS

SELECT
1 num_recarga,
 CAST(phone_nm AS STRING) AS msisdn,
CAST(order_date AS DATE) as recharge_date,
(a.not_financed_price + a.q25_amount + a.financed_total_amount) as importe_con_iva,
CAST(serial_number AS STRING) AS iccid,
CAST(service_id AS STRING) as service_id,
user_store as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(order_date as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(order_date as date),month) as recharge_month,
'D - Extracomision Terminal'	description, 
CASE 
 WHEN (a.not_financed_price + a.q25_amount + a.financed_total_amount)/(1 + a.tax_value) < 40   THEN 2
         WHEN (a.not_financed_price +a.q25_amount + a.financed_total_amount)/(1 + a.tax_value) < 350  THEN 10
         WHEN (a.not_financed_price + a.q25_amount + a.financed_total_amount)/(1 + a.tax_value) >= 350 THEN 30
ELSE 0 END
 as	comision ,
CAST(NULL AS STRING) as portability_in_operator,
case WHEN (a.not_financed_price + a.q25_amount + a.financed_total_amount)/(1 + a.tax_value) < 40   THEN 'GAMA A'
         WHEN (a.not_financed_price +a.q25_amount + a.financed_total_amount)/(1 + a.tax_value) < 350  THEN 'GAMA B'
         WHEN (a.not_financed_price + a.q25_amount + a.financed_total_amount)/(1 + a.tax_value) >= 350 THEN 'GAMA C'
  END AS comments,

FROM `mm-datamart-kd.DEVICES.device_base_mysim` A

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(user_store,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(order_date as date),month) OR comentarios = 'NUEVO PRELIQUI')

left JOIN `mm-commissions-reporting.GS.exclusivo_canarias` e
ON REPLACE(user_store,"LB-","")=e.MATRICULA

WHERE DATE_TRUNC(CAST(order_date AS DATE),MONTH)= mes
AND UPPER(tariff_ds) NOT LIKE '%FIBRA%'
AND UPPER(tariff_ds) NOT LIKE '%SINF%N%'
AND UPPER(tariff_ds) NOT LIKE '%INTERNET%'
AND UPPER(tariff_ds) NOT LIKE '%TV PREMIUM%'
AND UPPER(tariff_ds) LIKE '%PREPAGO%'
--and order_type_agg='ALTA NUEVA'
AND case when
( A.user_store LIKE 'LB%' 
 OR A.user_store LIKE 'DX%' 
 OR A.user_store LIKE 'AX%' 
 OR A.user_store LIKE 'BY%' 
 OR A.user_store LIKE 'MD%' 
 OR A.user_store LIKE 'KH%' 
 OR A.user_store LIKE 'TA%' 
 OR A.user_store LIKE 'LM%' 
 OR A.user_store LIKE 'LY%' 
 OR A.user_store LIKE 'MB%' 
 OR A.user_store LIKE 'LM%' 
 OR A.user_store LIKE 'MY%' 
 OR A.user_store LIKE 'ML%' 
 OR A.user_store LIKE 'LX%' 
 OR A.user_store LIKE 'DBL%' 
 OR A.user_store LIKE 'DXE%' 
 OR A.user_store LIKE 'LME%' 
 OR A.user_store LIKE 'NY%'
 OR A.user_store LIKE 'LB%' 
 OR A.user_store LIKE 'LBE%' 
 OR A.user_store LIKE 'MY%' 
 OR A.user_store LIKE 'MB%'  
 OR A.user_store LIKE 'MO%' 
 OR A.user_store LIKE 'MEC%' 
) THEN 1 else 0 end=1
and terminal_status_ds not in ('CANCELADO')

union all


-- COMISION RENOVES

SELECT
1 num_recarga,
 CAST(phone_nm AS STRING) AS msisdn,
CAST(order_date AS DATE) as recharge_date,
5*1.21 as importe_con_iva,
CAST(serial_number AS STRING) AS iccid,
CAST(service_id AS STRING) as service_id,
user_store as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(order_date as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(order_date as date),month) as recharge_month,
'B - Renuevo'	description, 
5 as	comision ,
CAST(NULL AS STRING) as portability_in_operator,
'' AS comments,

FROM `mm-datamart-kd.DEVICES.device_base_mysim` A

INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,comentarios from `mm-commissions-reporting.GS.exclusivo_dealers` WHERE CANAL='ENK')
ON REPLACE(user_store,"LB-","")=id_comisionista and (fecha_firma<=date_trunc(cast(order_date as date),month) OR comentarios = 'NUEVO PRELIQUI')

left JOIN `mm-commissions-reporting.GS.exclusivo_canarias` e
ON REPLACE(user_store,"LB-","")=e.MATRICULA

WHERE DATE_TRUNC(CAST(order_date AS DATE),MONTH)= mes
AND UPPER(tariff_ds) NOT LIKE '%FIBRA%'
AND UPPER(tariff_ds) NOT LIKE '%SINF%N%'
AND UPPER(tariff_ds) NOT LIKE '%INTERNET%'
AND UPPER(tariff_ds) NOT LIKE '%TV PREMIUM%'
AND UPPER(tariff_ds) LIKE '%PREPAGO%'
AND sell_terminal_origin_ds='RENUEVO'
AND case when
( A.user_store LIKE 'LB%' 
 or A.user_store LIKE 'DX%' 
 OR A.user_store LIKE 'AX%' 
 OR A.user_store LIKE 'BY%' 
 OR A.user_store LIKE 'MD%' 
 OR A.user_store LIKE 'KH%' 
 OR A.user_store LIKE 'TA%' 
 OR A.user_store LIKE 'LM%' 
 OR A.user_store LIKE 'LY%' 
 OR A.user_store LIKE 'MB%' 
 OR A.user_store LIKE 'LM%' 
 OR A.user_store LIKE 'MY%' 
 OR A.user_store LIKE 'ML%' 
 OR A.user_store LIKE 'LX%' 
 OR A.user_store LIKE 'DBL%' 
 OR A.user_store LIKE 'DXE%' 
 OR A.user_store LIKE 'LME%' 
 OR A.user_store LIKE 'NY%'
 OR A.user_store LIKE 'LB%' 
 OR A.user_store LIKE 'LBE%' 
 OR A.user_store LIKE 'MY%' 
 OR A.user_store LIKE 'MB%' 
 OR A.user_store LIKE 'MO%' 
 OR A.user_store LIKE 'MEC%'  
) THEN 1 else 0 end=1
and terminal_status_ds not in ('CANCELADO')
union all

-- SIMS YOIGO MASMOVIL

Select distinct 
0 num_recarga,
msisdn,
activationdate as recharge_date,
1 as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(activationdate as date),month) as recharge_month,
case when  a.brand_ds in ('YOIGO') then 'B - Devolucion SIM Yoigo' else  'B - Devolucion SIM' end	description, 
case when a.brand_ds in ('YOIGO') and  zona_fiscal='CAN' THEN 1.07
 when a.brand_ds in ('YOIGO') and  zona_fiscal='MEL' THEN 1.08
 when a.brand_ds in ('YOIGO')  THEN 1.21 ELSE 
ROUND(1,2) END
as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a


LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid

 INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal from `mm-commissions-reporting.GS.exclusivo_dealers` )
ON REPLACE(a.SFID,"LB-","")=id_comisionista 

where date_trunc(cast(activationdate as date), month)= mes 


 and CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
   OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN a.SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1
and ifnull(cod_producto_sim,'-') <>'P05407'


union all

-- LEGACY 3 MESES

Select distinct 
2 AS  num_recarga,
msisdn,
Second_topup_date as recharge_date,
Second_topup_amount as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(activationdate as date),month) as recharge_month,
'C - Bonus 3 meses'	description, 
ROUND(5,2) as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

left JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma from `mm-commissions-reporting.GS.exclusivo_dealers`)
ON REPLACE(sfid,"LB-","")=id_comisionista

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid


left join (Select distinct service_id,case 
when cod_marca=11 then 'LEBARA'
when cod_marca=4 then 'LLAMAYA'
when cod_marca=5 then 'MASMOVIL'
when cod_marca=14 then 'LYCAMOBILE'
end AS MARCA, from `mm-commissions-reporting.PREPAGO.MM_PREPAID_COMMISSIONS_CANAL_202301*`a, unnest(detalle_trazabilidad_activacion) b where descripcion like '%Bonus 3 Meses%' and channel_code='BYMOBILE') d3
on d3.service_id=a.id_subscription AND MARCA=BRAND_DS

where (date_add(date_trunc(cast(activationdate as date),month), interval 3 month)= mes ) and
 date_trunc(cast(activationdate as date), month)>='2023-01-01' and

 case when CANAL='ENK'  and fecha_firma<=date_trunc(cast(activationdate as date),month)  then 0
 else 1 end=1


AND date_diff(Second_topup_date,activationdate,day)<=90
and ifnull(operator_donor,'')<>brand_ds
AND date_diff(DATE_TRUNC(ifnull(deactivationdate,'9999-12-31'),MONTH),DATE_TRUNC(activationdate,day),MONTH)>0
and d3.service_id is null
and 
CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
   OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1 
--and (deactivationdate is null or deactivationdate='9999-12-31')
and ifnull(cod_producto_sim,'-') <>'P05407'


UNION ALL

-- LEGACY 6 MESES

Select distinct 
3 AS  num_recarga,
msisdn,
Third_topup_date as recharge_date,
Third_topup_amount as importe_con_iva,
iccid,
id_subscription as service_id,
ifnull(ifnull(y.SFID,z.SFID),a.SFID) as	cod_store_crm,
'BYMOBILE' as		channel_code,
cast(activationdate as date) as sim_activation_date,
	case brand_ds
  when 'LEBARA' then 'Lebara'
  when 'LYCAMOBILE' then 'Lycamobile'
  when 'LLAMAYA' then 'Llamayá'
	when 'MASMOVIL' then 'Más Móvil'
	when 'YOIGO' then 'Yoigo'
end as marca,	
date_trunc(cast(activationdate as date),month) as recharge_month,
'C - Bonus 6 meses'	description, 
ROUND(12,2) as	comision ,
operator_donor as portability_in_operator,
'' as comments,
from `mm-prepaid-reporting.VENTAS_BASE.ventas_base_prepaid` a

left JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma from `mm-commissions-reporting.GS.exclusivo_dealers`)
ON REPLACE(sfid,"LB-","")=id_comisionista

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` y
on Cod_AX=a.sfid

LEFT JOIN `mm-prepaid-reporting.MASTER.prepaid_match` z
on z.Cod_LEBARA=a.sfid

left join (Select distinct service_id,case 
when cod_marca=11 then 'LEBARA'
when cod_marca=4 then 'LLAMAYA'
when cod_marca=5 then 'MASMOVIL'
when cod_marca=14 then 'LYCAMOBILE'
end AS MARCA,  from `mm-commissions-reporting.PREPAGO.MM_PREPAID_COMMISSIONS_CANAL_202301*`a, unnest(detalle_trazabilidad_activacion) b  where descripcion like '%Bonus 6 Meses%' and channel_code='BYMOBILE') d3
on d3.service_id=a.id_subscription AND MARCA=brand_ds

where (date_add(date_trunc(cast(activationdate as date),month), interval 6 month)= mes  ) and
 date_trunc(cast(activationdate as date), month)>='2023-01-01'
 and case when CANAL='ENK'  and fecha_firma<=date_trunc(cast(activationdate as date),month)  then 0
 else 1 end=1
 and ifnull(operator_donor,'')<>brand_ds
AND date_diff(Third_topup_date,activationdate,day)<=180
AND date_diff(DATE_TRUNC(ifnull(deactivationdate,'9999-12-31'),MONTH),DATE_TRUNC(activationdate,day),MONTH)>0
and d3.service_id is null
and CASE 
WHEN ( 
  A.SFID LIKE 'LB%' 
OR y.Cod_LEBARA like '%RETBY%' 
or A.SFID like '%RETBY%'
) THEN 1
WHEN BRAND_DS in ('YOIGO','LEBARA') AND 
(
 A.SFID LIKE 'DX%' 
 OR  A.SFID LIKE 'AX%' 
 OR  A.SFID LIKE 'BY%' 
 OR  A.SFID LIKE 'MD%' 
 OR  A.SFID LIKE 'KH%' 
 OR  A.SFID LIKE 'TA%' 
 OR  A.SFID LIKE 'LM%' 
 OR  A.SFID LIKE 'LY%' 
  OR  A.SFID LIKE 'ML%' 
   OR A.SFID LIKE 'LX%' 
 OR  A.SFID LIKE 'DBL%' 
 OR  A.SFID LIKE 'DXE%' 
 OR  A.SFID LIKE 'LME%' 
 OR  A.SFID LIKE 'NY%' 
   OR  A.SFID LIKE 'LB%' 
 OR  A.SFID LIKE 'LBE%' 
 OR  A.SFID LIKE 'MY%' 
 OR  A.SFID LIKE 'MB%' 
  OR  A.SFID LIKE 'MO%' 
 OR  A.SFID LIKE 'MEC%' 
) THEN 1 
WHEN SUBCHANNEL='TIENDAS YOIGO' THEN 1

ELSE 0 END=1  
-- and (deactivationdate is null or deactivationdate='9999-12-31')
and ifnull(cod_producto_sim,'-') <>'P05407'








) a


)
SELECT
concat("LIQ-",cod_marca,"-",replace(cast(current_date()-1 as string),"-",""),"-",row_number() over (order by descripcion)) as Id_Registro,
*
from (
  Select 
  'X001' as Sociedad,
REPLACE(cod_store_crm,"LB-","") as id_comisionista,
'DEA' as tipo_comisionista,
'B39688197' as cif,
zona_fiscal as zona_fiscal,
case 
when description='A - Servicio Movil Prepago' then 'UPFR' 
when description='B - Renuevo' then 'UPFR' 
WHEN description='D - Extracomision Terminal' then 'CURE'
when description='B - Devolucion SIM' then 'TJTS'
when description='B - Devolucion SIM Yoigo' then 'SUTS'
 
else 'AIRT' end as concepto,
description  as descripcion,
recharge_month,
count(1) as uds,
round(sum(comision),2) as importe,
'EUR' as moneda,
'C' as via_pago,
'29' as canal,
case when upper ( description ) like '%PORT%' then '040' 
WHEN description='D - Extracomision Terminal' then '050' 
else '039' end as producto,
'10' as tipo_contrato,
case substr(UPPER(MARCA),1,2)
when 'LY' then 14
when 'LE' then 11
when 'LL' then 4
when 'MÁ' then 5
when 'YO' then 1
end as cod_marca,
'999' as operador,
'10' as segmento,
cast(case WHEN zona_fiscal='CAN' THEN 35000
WHEN zona_fiscal='MEL' THEN 51000
else 28000 end as string) as codigo_postal,
array_agg (
struct
(
cast(service_id as string) as service_id,
cast(num_recarga as string) as num_recarga,
msisdn,
recharge_date,
channel_code,
importe_con_iva as importe_recarga,
cast(iccid as string) as iccid,
REPLACE(cod_store_crm,"LB-","") as codigo_tienda,
REPLACE(cod_store_crm,"LB-","")as codigo_unico,
sim_activation_date as sim_registration_date,
sim_activation_date,
portability_in_operator,
comision,
 comments
)
) as detalle_trazabilidad_activacion
FROM (


Select  * from total

where comision > 0 AND marca IN ('Llamayá','Más Móvil','Lebara','Yoigo') 

)  


 INNER JOIN (Select distinct id_comisionista,canal,parse_date('%Y%m%d',concat(cast(fecha_firma as string),"01")) as fecha_firma,zona_fiscal from `mm-commissions-reporting.GS.exclusivo_dealers` )
ON REPLACE(cod_store_crm,"LB-","")=id_comisionista 

 left join `mm-prepaid-reporting.COMISIONES.exclusivo_no_comisiona` g
 ON REPLACE(cod_store_crm,"LB-","")=g.SFID

 WHERE g.sfid is null

group by 1,2,3,4,5,6,7,8,11,12,13,14,15,16,17,18
)
);

set sql = concat (
    " create or replace table `mm-commissions-reporting.PREPAGO.PREPAID_DAILY_COMMISSIONS_CANAL_"
    , format_date ( '%Y%m%d',mes)
    , "` as select * from BYMOBILE ;"
);
execute immediate  sql;

end