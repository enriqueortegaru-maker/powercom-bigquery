begin

declare err, clave string;

declare importe_sheets, importe_calculado FLOAT64;

set clave = 'CMAN';

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_cman` (date_trunc(date_add (current_date (), interval -1 month), month));

-- Validacion de dealers --

SET err =
    ( 
    select
    STRING_AGG(DISTINCT a.dealer, " | ")
    FROM `mm-commissions-reporting.NO_EXCLUSIVO.SUBIDA_MANUAL`  a
    left join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto`  b on a.dealer = b.sfid
    where b.sfid is null
    );


if err is not null then RAISE USING MESSAGE = 'Dealers no cruzan con el maestro: '
|| err;
end if;

-- Validacion de conceptos --

SET err =
    ( 
    select
    STRING_AGG(DISTINCT a.concepto, " | ")
    FROM `mm-commissions-reporting.NO_EXCLUSIVO.SUBIDA_MANUAL`  a
    left join `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` c on a.concepto= c.concepto
    where c.concepto is null
    );


if err is not null then RAISE USING MESSAGE = 'Dealers no estan en el maestro: '
|| err;
end if;

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_cman` as
with 
calculo as 
(
select
concat (clave, '_NOEX_',FORMAT_DATE ('%Y%m',MES_PR),'_',row_number() over () ) as id_registro,
case
  when upper(marca) = 'PEPEPHONE' and c.tipo_concepto = 'ENRG' THEN '7100'
  when upper(marca) = 'PEPEPHONE' THEN '7000'
  else 'X001' end as sociedad,
 case comisionista
  when 'CIF PDV' then b.sfid_unico
  when 'CIF MASTER' then b.distribuidor
  when 'CIF GPV' then
  case 
  when b.CIF_GPV = 'B87430658' THEN 'MASTER01'
  when b.CIF_GPV = 'B94153343' THEN 'MASTER02'
  when b.CIF_GPV = 'B30898027' THEN 'MASTER03'
  when b.CIF_GPV = 'B14628440' THEN 'MASTER07'
  when b.CIF_GPV = 'E23773369' THEN 'MASTER08'
  when b.CIF_GPV = 'B90202623' THEN 'MASTER10'
  when b.CIF_GPV = 'B76754894' THEN 'MASTER12'
  when b.CIF_GPV = 'B26563676' THEN 'MASTER14'
  when b.CIF_GPV = 'B40643389' THEN 'MASTER18'
  when b.CIF_GPV = 'B52554821' THEN 'MASTER20'
  end 
end as id_comisionista,
'DEA' as tipo_comisionista,
 case comisionista
  when 'CIF PDV' then b.CIF_PDV
  when 'CIF MASTER' then b.CIF_MASTER
  when 'CIF GPV' then b.CIF_GPV    
  else comisionista
end as CIF,
case Provincia
  when 'Santa Cruz de Tenerife' then 'CAN'
  when 'Las Palmas' then 'CAN'
  when 'Melilla' then 'MEL'
  when 'Ceuta' then 'CEU'
else 'PEN' END as zona_fiscal,
c.tipo_concepto, 
a.concepto as descripcion_concepto,
case when upper(factura_con_unidades) = 'SI' then 1 else null end as uds,
round(importe,2) as importe_base, 
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
'29' as cod_canal,
case 
  when c.cod_producto is not null then c.cod_producto
  when c.tipo_concepto = 'ENRG' then '014' 
  when UPPER(c.concepto) like '%TV%' then '006'
  when UPPER(c.concepto) like '%TELEVI%' then '006'
  when origen_suscripcion like '%PORT%' then '040'
else '039'
end as cod_producto,
case
  when c.tipo_contrato = 'Prepago' THEN '10'
  when a.billing_type = 'PREPAID' THEN '10'
  when a.product_type in ('INTERNET', 'FIX') and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type in ('INTERNET', 'FIX') then (case when a.Technology = 'ADSL' then '62' else '63' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' and Line_Type = 'MAIN' then (case when a.Technology = 'ADSL' then '60' else '61' end)
  when a.product_type = 'MOBILE' and bundle_type = 'FMC' then (case when a.Technology = 'ADSL' then '66' else '67' end)
  when a.product_type = 'MOBILE' and bundle_type = 'MO' and line_type = 'ADDITIONAL' and upper(marca) = 'YOIGO' then '68'
  when a.product_type = 'MOBILE' then '20'
else '99' end as cod_tipo_contrato,
case
  when c.tipo_concepto = 'ENRG' and upper(marca) = 'PEPEPHONE' then '19'
  when c.tipo_concepto = 'ENRG' and upper(marca) = 'MASMOVIL' then '17'
  when c.tipo_concepto = 'ENRG' then '99'
  when upper(marca) = 'MASMOVIL' then '05'
  when upper(marca) = 'PEPEPHONE' then '06'
  when upper(marca) = 'GUUK' then '13'
  when upper(marca) = 'LLAMAYA' then '04'
  when upper(marca) = 'YOIGO' then '01'
end as cod_marca,
'999' as cod_operador,
case
  when upper(marca) = 'GUUK' then '10'
  when upper(marca) = 'LLAMAYA' then '10'
  else cod_segmento end as cod_segmento,
concat('C_MANUAL') as facturador,
------ TRAZABILIDAD ------
c.Bloque as clasificacion_concepto,
case subchannel
when 'MASINDIRECTO' then 'MI'
when 'NATIONAL RETAIL' then 'NR'
when 'MASPROXIMO' then 'MP'
when 'CANAL ALTERNATIVO' then 'NR'
when 'MASREGIONAL' then 'MR'
when 'CADENAS' then 'CA'
end as canal,
service_id,
product_type,
bundle_type,
msisdn,
upper(marca) as marca,
activation_date as fecha_activacion,
deactivation_date  as fecha_baja,
account_id,
customer_id,
Dealer as sfid_unico,
Dealer as tienda,
b.distribuidor as distribuidor,
mes_pr as fecha,
cast ( null  as string ) as order_id,
cast ( null  as string ) as  Product_Id,
Product,
cast ( null  as string ) as  user_id,
cast(null as string) campaign_code,
cast(null as string) claim_code,
cast(null as string) process_code,
cast(null as string) comments,
FROM `mm-commissions-reporting.NO_EXCLUSIVO.SUBIDA_MANUAL`  a
inner join `mm-commissions-reporting.NO_EXCLUSIVO.nex_optico_mas_indirecto`  b on a.dealer = b.sfid
inner join `mm-commissions-reporting.NO_EXCLUSIVO.CONCEPTOS_FACTURA` c on a.concepto= c.concepto
)
select
id_registro,
sociedad,
coalesce (b.codigo, id_comisionista  ) as id_comisionista,
a.* except(id_registro,sociedad, id_comisionista, marca,order_id,
Product_Id,
Product,
user_id,
campaign_code,
claim_code,
process_code,
comments),
case
  when cod_tipo_contrato = '10' then 'Prepago'
  when cod_tipo_contrato in ('60','61') then 'FMC'
  when cod_tipo_contrato in ('62','63') then '2P'
  when cod_tipo_contrato in ('66','67','68') then 'Adicional'
  when cod_tipo_contrato = '20' then 'MO'
else 'Otros servicios'
end as agrupacion_cod_tipo_contrato,
case cod_segmento
  when '10' then 'Residencial'
  when '12' then 'Negocios'
end as segmento,
b.razon_social as razon_social,
b.nombre_comercio as nombre_comercio,
marca,
order_id,
Product_Id,
Product,
user_id,
campaign_code,
claim_code,
process_code,
comments,
from calculo a
left join `mm-commissions-reporting.NO_EXCLUSIVO.v_detalle_cif` b on a.cif=b.cif
where a.cif is not null
and not (marca = 'YOIGO' and Distribuidor = 'PHONE HOUSE')
;


-- Cuadre de importes --

set importe_sheets = 
    (
    select sum(Importe)
    from `mm-commissions-reporting.NO_EXCLUSIVO.SUBIDA_MANUAL`
    );

set importe_calculado = 
    (
    select sum(Importe_base)
    from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_cman`
    where id_comisionista is not null
    );

SET err = cast((importe_sheets - importe_calculado) as string);

if abs(importe_sheets - importe_calculado) > 0 then RAISE USING MESSAGE = 'Importes no cuadran: '
|| err;
end if;


-- Actualización tabla final --

call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  clave,
  'NO_EXCLUSIVO.comisiones_working_cman',
  'NO_EXCLUSIVO.comisiones_working'
);


end