begin

--- call COMISIONES.pr_cargar_prepago ('20260901');

create or replace table TEMP.informacion_prepago as
select
      * EXCEPT(id_registro)
     ,'ETNICO_'||prefijo_tabla||'_'||id_registro||'_'||row_number () over () as commission_id

FROM (
     SELECT
           'calculado' AS estado
           ,cast(substr(prefijo_tabla,1,6) as int64) as id_mes
           ,'Etnico' as agrupacion_canal
           ,'ET' as canal
          --  ,d.concepto as concepto
           ,a.descripcion as concepto
          --  ,d.tipo_concepto as tipo_concepto
           ,a.concepto as tipo_concepto
           ,1 as unidades
           ,SUM(coalesce (b.comision, a.importe)) as comision
           ,split (id_comisionista,'-')[SAFE_OFFSET(0)] as id_comisionista
           ,id_comisionista as distribuidor
           ,codigo_unico as sfid_id
           ,coalesce (split (id_comisionista,'-')[SAFE_OFFSET(1)],split (id_comisionista,'-')[SAFE_OFFSET(0)]) as seller
           ,MAX(c.vendor_name) as nombre_comercio
           ,MAX(c.vendor_name) as razon_social
           ,a.cif
           ,a.zona_fiscal
           ,case cod_marca
                 when 14 then 'LYCAMOBILE'
                 when 11 then 'LEBARA'
                 when 4 then 'LLAMAYA'
                 when 5 then 'MASMOVIL'
                 when 1 then 'YOIGO'
                 when 29 then 'ORANGE'
            END AS marca
           ,cast (cod_marca as string format '00') as cod_marca
           ,'MOBILE' as service_type
           ,b.msisdn as phone_nm
           ,cast (null as string) as tariff_id
           ,cast (null as string) as tariff_ds
           ,b.service_id
           ,b.iccid as account_id
           ,cast (null as string) as customer_id
           ,'MAIN' as line_type_ds
           ,'MO' as bundle_type
           ,'MOBILE' as technology_ds
           ,'PREPAID' as billing_type_ds
           ,sim_registration_date as sale_date
           ,sim_activation_date as activation_date
           ,CAST (NULL AS DATE) as DEactivation_date
           ,cast (null as string) as order_id
           ,'ALTA NUEVA' as order_type_agg
           ,coalesce (segmento,'10') as  cod_segmento
           ,tipo_contrato as cod_tipo_contrato
           ,coalesce (producto,'040') as cod_producto
           ,canal as cod_canal
           ,cast (null as string) as claim_code
           ,cast (null as string) as process_code
           ,descripcion as campaign_code
           ,b.iccid as serial_number
           ,cast (null as float64) as tax_base
           ,case when importe_recarga is not null then 'Importe recarga: '|| cast(importe_recarga as string) end as comments
           ,'C_MANUAL' as facturador
           ,id_registro
      FROM `mm-commissions-reporting.PREPAGO.MM_PREPAID_COMMISSIONS_FINAL_*` a,
      unnest(detalle_trazabilidad_activacion) b
     --  left join `mm-prepaid-reporting.COMISIONES.MM_PREPAID_COMMISSIONS_VENDORS_GS_20240801`c on a.cif = c.cif_nif and a.id_comisionista =c.cod_cliente
       left join `mm-commissions-reporting.SAP.vendor_list` c on a.cif = c.tax_code
      left join `mm-commissions-reporting.GS.PREPAGO_CONCEPTOS` d on REPLACE(a.descripcion, ' ', '') = REPLACE(d.concepto_etnico, ' ', '') and a.concepto=d.tipo_concepto
     where _table_suffix = prefijo_tabla
     GROUP BY 1,2,3,4,5,6,7,9,10,11,12,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46
     )

 ;

-- select SUM(comision) from TEMP.informacion_prepago;

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('ETNICO' ,cast(substr(prefijo_tabla,1,6) as int64), ['ET'], 'TEMP.informacion_prepago', 'ACTUALIZAR');


end