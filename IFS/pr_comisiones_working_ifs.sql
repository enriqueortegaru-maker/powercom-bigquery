begin

--call `mm-commissions-reporting.IFS.pr_comisiones_working_ifs` (['7233'], ['BY'],['Confirmed'],'IFS.test_comisiones_working', date('2023-01-01'));

declare sql, err string;

declare registros_iniciales, registros_finales int64;

declare importe_inicial, importe_final float64;



set err = (
select
STRING_AGG (distinct
case when left(a.sfid,2) in ('MP', 'D2','DE','MM') then coalesce ( a.addon11 , a.sfid ) else substr (a.sfid,1,2) end)
FROM `mm-datamart-kd.COMMISSIONS.customer_care_ifs_indirect_channel` a
left join `mm-commissions-reporting.IFS.v_dealers` d on case when left(a.sfid,2) in ('MP', 'D2','DE','MM') then coalesce ( a.addon11 , a.sfid ) else substr (a.sfid,1,2) end = d.id
cross join unnest(pr_calculation_id) calc_id
cross join unnest(pr_HIERARCHY_ID) hier_id
cross join unnest(pr_objstate) objstate_2
WHERE CALCULATION_ID = calc_id 
and HIERARCHY_ID = hier_id
and objstate = objstate_2
and d.id is null
);

if err is not null then RAISE USING MESSAGE = 'Dealers no cruzan: ' || err; end if;

SET (registros_iniciales, importe_inicial) =
(
select AS STRUCT count(1), sum (round(cast(REBATE_AMOUNT as float64),4)) as importe
FROM `mm-datamart-kd.COMMISSIONS.customer_care_ifs_indirect_channel` a
cross join unnest(pr_calculation_id) calc_id
cross join unnest(pr_HIERARCHY_ID) hier_id
cross join unnest(pr_objstate) objstate_2
WHERE CALCULATION_ID = calc_id 
and HIERARCHY_ID = hier_id
and objstate = objstate_2
and round(cast(REBATE_AMOUNT as float64),4) <> 0
);


create or replace temporary table ifs as
select 
'IFS_'||transaction_id AS id_registro,
'X001' as sociedad,
d.nombre as id_comisionista, --Enrique/Ismael REVISAR
'DEA' as tipo_comisionista,
d.CIF as CIF,
coalesce ( `mm-commissions-reporting.IFS.f_zona_fiscal_ifs` (a.TAX_PERC) , zona_fiscal ) as zona_fiscal, 
`mm-commissions-reporting.IFS.f_tipo_concepto_ifs` (SALES_PART_REBATE_GROUP, REBATE_TYPE, ADD_TYPE, ORDER_CHANNEL) as tipo_concepto,
IFS.f_descripcion_concepto_ifs (REBATE_TYPE, CLAIM_CODE, AFTER_SALE, ORDER_CHANNEL, CONTRACT_CATEGORY, CONTRACT_TYPE) as descripcion_concepto,
1 as uds,
round(cast(REBATE_AMOUNT as float64),4) as importe_base,
'EUR' as moneda,
'C' as via_pago,
'Z001' as cond_pago,
`mm-commissions-reporting.IFS.f_cod_canal_ifs` (SALES_PART_REBATE_GROUP, CHANNEL_ID) as cod_canal,
`mm-commissions-reporting.IFS.f_cod_producto`(SALES_PART_REBATE_GROUP, ORDER_CHANNEL, REBATE_TYPE, ADD_TYPE, HANDSET) as cod_producto,
`mm-commissions-reporting.IFS.f_cod_tipo_contrato_ifs`(SALES_PART_REBATE_GROUP, REBATE_TYPE, CONTRACT_TYPE_GROUP, ADD_TYPE) as cod_tipo_contrato,
'01' as cod_marca,
'999' as cod_operador,
`mm-commissions-reporting.IFS.f_cod_segmento` (SALES_PART_REBATE_GROUP, YOI_CUS_KATEGORY, REBATE_TYPE, CUSTOMER_TYPE) as cod_segmento,
'C_IFS' as facturador,
`mm-commissions-reporting.IFS.f_agrupacion_concepto` (IFS.f_descripcion_concepto_ifs (REBATE_TYPE, CLAIM_CODE, AFTER_SALE, ORDER_CHANNEL, CONTRACT_CATEGORY, CONTRACT_TYPE)) as clasificacion_concepto,
HIERARCHY_ID as canal, --d.canal
a.subscription_id as subscription_id,
`mm-commissions-reporting.IFS.f_product_type_ifs` (a.CONTRACT_TYPE, a.REBATE_TYPE, a.ADDON6) as product_type,
`mm-commissions-reporting.IFS.f_bundle_type_ifs` (a.CONTRACT_TYPE) as bundle_type,
a.msisdn as msisdn,
parse_date ('%Y-%m-%d', left( case when rebate_type in ('UPFR_FIJO','UP_CONVPOR','UP_RAPPEL','UP_EX_SJ21') then coalesce ( yoi_activation_date_fixed , activ_date) else activ_date end, 10) ) as fecha_activacion,
parse_date ('%Y-%m-%d', left( case when rebate_type in ('UPFR_FIJO','UP_CONVPOR','UP_RAPPEL','UP_EX_SJ21') then coalesce ( yoi_deactivation_date_fixed , deactiv_date) else deactiv_date end, 10) ) as fecha_baja,
a.subscription_id as account_id,
a.END_CUST_NO as customer_id,
a.sfid as sale_dealer,
a.sfid as tienda,
a.CHANNEL_NAME as distribuidor,
periodo_facturado as fecha,
`mm-commissions-reporting.IFS.f_agrupacion_cod_tipo_contrato`(`mm-commissions-reporting.IFS.f_cod_tipo_contrato_ifs`(SALES_PART_REBATE_GROUP, REBATE_TYPE, CONTRACT_TYPE_GROUP, ADD_TYPE)) as agrupacion_cod_tipo_contrato,
`mm-commissions-reporting.IFS.f_segmento`(`mm-commissions-reporting.IFS.f_cod_segmento` (SALES_PART_REBATE_GROUP, YOI_CUS_KATEGORY, REBATE_TYPE, CUSTOMER_TYPE)) as segmento,
d.razon_social as razon_social, 
d.nombre as nombre_comercio,
'YOIGO' as marca,
a.TMS_ORDER_NO as order_id,
a.CONTRACT_TYPE as Product_Id,
c.tariff_ds as product,
coalesce ( a.addon11 , a.sfid ) as user_id,  --Si televenta (<> pos) es addon11, si no SFID
HIERARCHY_ID||'-'||CALCULATION_ID campaign_code,
CLAIM_CODE claim_code,
SALES_PART_REBATE_GROUP||'-'||REBATE_TYPE process_code,
AFTER_SALE comments,
FROM `mm-datamart-kd.COMMISSIONS.customer_care_ifs_indirect_channel` a
left join `mm-commissions-reporting.IFS.campos_rebate_transaction` b using (transaction_id)
left join 
(
  select tariff_id, tariff_ds
  from `mm-datamart-kd.SERVICES.ventas_base_net`
  where data_source_ds = 'QVANTEL'
  qualify ROW_NUMBER() OVER (PARTITION BY TARIFF_ID ORDER BY activation_date DESC) = 1
) c on a.CONTRACT_TYPE = c.tariff_id
left join `mm-commissions-reporting.IFS.v_dealers` d on case when left(a.sfid,2) in ('MP', 'D2','DE','MM') then coalesce ( a.addon11 , a.sfid ) else substr (a.sfid,1,2) end = d.id
cross join unnest(pr_calculation_id) calc_id
cross join unnest(pr_HIERARCHY_ID) hier_id
cross join unnest(pr_objstate) objstate_2
WHERE CALCULATION_ID = calc_id 
and HIERARCHY_ID = hier_id
and objstate = objstate_2
and round(cast(REBATE_AMOUNT as float64),4) <> 0
;


SET (registros_finales, importe_final) =
(
select AS STRUCT count(1), sum (importe_base) as importe
FROM ifs
);

if abs (importe_inicial - importe_final) > 0.01
then RAISE USING MESSAGE = 'Error al cargar registros: faltan '||cast ( importe_final - importe_inicial as string)||' EUR';
end if;

set sql = 'create or replace table `';
set sql = sql || destination_table;
set sql = sql || '` as select * from ifs';

execute immediate (sql);

end