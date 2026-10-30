BEGIN
DECLARE
  sql string;

set id_proceso_pr = coalesce (id_proceso_pr, 1);

--- Validar proceso no ha sido creado ---
assert not exists (
  select 1
  from `mm-commissions-reporting.COMISIONES.transacciones`
  where ( split (commission_id,'_')[OFFSET(1)] = cast(id_proceso_pr as string) or process_code = descripcion_proceso_pr )
  and substr(commission_id,1,4) = 'CMAN'
)AS "Error: El proceso ya existe. Ya hay registros con este id_proceso_pr o descripcion_proceso_pr. Cambiar descripcion.";

--- Validar canales ---
assert (
  select count(1)-countif (b.canal is not null)
  from  `mm-commissions-reporting.GS.FACTURACION_MANUAL` a
  left join `mm-commissions-reporting.GS.CANALES` b using (canal)
  where b.agrupacion_canal = agrupacion_canal_pr
) = 0 
AS "Error: Existen canales no vlidos o no coinciden con la agrupacion canal especificada.";

--- Validar dealers ---
-- assert not exists(
-- SELECT
--   a.seller
-- FROM
--   `mm-commissions-reporting.GS.FACTURACION_MANUAL` a
-- LEFT JOIN
--   `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` b
-- ON
--   (a.seller = b.sfid_id OR SUBSTR(a.seller,1,2) = b.sfid_id)
--   -- AND b.id_mes = mes_pr
--   AND agrupacion_canal_pr = b.agrupacion_canal
-- WHERE b.sfid_id IS NULL
-- )AS "Error: Seller no valido, no tiene dealer asociado en v_dealer_ultima_version.";


/*--- Validar Duplicados ---
ASSERT NOT EXISTS
(
SELECT msisdn, service_id, concepto, comision
FROM `mm-commissions-reporting.GS.FACTURACION_MANUAL`
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1
);*/


BEGIN TRANSACTION;

if TIPo_pr = 'TELCO' then

--- Validar servicios ---

assert (
  select count(1)-countif (b.service_id is not null)
  from  `mm-commissions-reporting.GS.FACTURACION_MANUAL` a
--  left join `mm-commissions-reporting.COMISIONES.v_ifs` g on a.ifs_transaction_id = g.transaction_id  <--Eliminamos IFS sep/2023
  left join `mm-commissions-reporting.COMISIONES.ventas_comisiones` b on
  -- left join `mm-commissions-reporting.COMISIONES.v_ventas_base_net` b on
--  coalesce ( a.service_type , g.service_type ) =b.service_type 
--  and coalesce ( a.service_id , g.service_id ) =b.service_id  
   a.marca=b.marca 
  --  a.marca=b.brand_ds  -- v_ventas_base_net
   and a.service_type = b.service_type
   and a.service_id = b.service_id
  --  and parse_date('%Y%m%d', a.activation_date) = b.activation_date

  where a.service_type in ('INTERNET','MOBILE', 'FIX')
) = 0 ;

insert into
  `mm-commissions-reporting.COMISIONES.facturacion_manual`
select
  id_proceso_pr,
  agrupacion_canal_pr,  
  mes_pr,
  descripcion_proceso_pr,
  *
from
  `mm-commissions-reporting.GS.FACTURACION_MANUAL` 
; 

INSERT INTO
  `mm-commissions-reporting.COMISIONES.transacciones` (
    commission_id,
estado,
mes_liquidado,
id_mes,
agrupacion_canal,
canal,
concepto,
tipo_concepto,
unidades,
comision,
id_comisionista,
distribuidor,
sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
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
cod_marca,
cod_tipo_contrato,
cod_producto,
cod_canal,
campaign_code,
serial_number,
tax_base,
claim_code,
process_code,
comments,
facturador,
sociedad,
creado
    )
SELECT
    'CMAN'||'_'||cast(id_proceso_pr as string)||'_'||CAST(mes_pr AS string)||'_'||a.canal||'_'||ROW_NUMBER() OVER () as commission_id,
    'calculado' as estado,
    COMISIONES.f_mes_int(mes_pr) as mes_liquidado,
    mes_pr,
    agrupacion_canal_pr,
    a.canal,
    COMISIONES.f_limpiar_caracteres (a.concepto) as concepto,
    b.tipo_concepto,
    1 as unidades,
    a.comision,
    a.id_comisionista,
    e.distribuidor,
    a.seller as sfid_id,
    a.seller,
    e.nombre_comercio,
    e.razon_social,
    e.cif,
    e.zona_fiscal,
    a.marca,
    case when a.service_type= 'FIX' THEN 'INTERNET' ELSE a.service_type END AS service_type,
    coalesce (f.phone_nm, a.msisdn), -- v_ventas_base_net. CAST phone_nm a STRING
    coalesce ( f.tariff_id, a.tariff_id),
    coalesce ( f.tariff_ds, a.tariff_ds),
    coalesce ( f.service_id, a.service_id),
    coalesce ( f.account_id, a.account_id),
    coalesce ( f.customer_id, a.customer_id),
    f.line_type_ds,
    f.bundle_type,
    f.technology_ds,
    f.billing_type_ds,
    coalesce (parse_date('%Y%m%d',a.sale_date),f.sale_date) as sale_date,
    -- coalesce (parse_date('%Y%m%d',a.sale_date),f.order_day_id) as sale_date, -- v_ventas_base_net

    coalesce (parse_date('%Y%m%d',a.activation_date),f.activation_date) as activation_date,
    f.deactivation_date,
    f.order_id, -- v_ventas_base_net. CAST AS STRING
    order_type_agg,
    coalesce (f.cod_segmento,a.cod_segmento) as cod_segmento,
    -- a.cod_segmento, -- v_ventas_base_net
    d.cod_marca,
    coalesce (f.cod_tipo_contrato, '99'),
    -- '99' AS cod_tipo_contrato, -- v_ventas_base_net
    coalesce (f.cod_producto, '999'),
    -- '999' AS cod_producto, -- v_ventas_base_net
    c.cod_canal,
    cast(null as string) as campaign_code,
    cast(null as string) as serial_number,
    cast(null as float64) as tax_base,
    a.claim_code,
    descripcion_proceso_pr as process_code,
    cast (null as string) as comments,
    'C_MANUAL' as facturador,
    `mm-commissions-reporting.COMISIONES.f_sociedad`(a.marca) as sociedad,
    CURRENT_TIMESTAMP () as creado
FROM
  `mm-commissions-reporting.GS.FACTURACION_MANUAL` a
  left join `mm-commissions-reporting.GS.CONCEPTOS` b on a.concepto = b.concepto
  left join `mm-commissions-reporting.GS.CANALES` c on a.canal=c.canal
  left join `mm-commissions-reporting.COMISIONES.marca_service_type_cod_marca` d on a.marca = d.marca and a.service_type = d.service_type
  left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` e on (a.seller = e.sfid_id OR SUBSTR(a.seller,1,2) = e.sfid_id) 
  AND e.canal = a.canal
  -- and e.id_mes = mes_pr 
  and agrupacion_canal_pr = e.agrupacion_canal
  left join `mm-commissions-reporting.COMISIONES.ventas_comisiones` f on
  -- left join `mm-commissions-reporting.COMISIONES.v_ventas_base_net` f on
 a.service_type =f.service_type 
  and a.marca = f.marca
  -- and a.marca = f.brand_ds -- v_ventas_base_net
  and a.service_id = f.service_id 
  and parse_date('%Y%m%d', a.activation_date) = f.activation_date
  where a.service_type in ('INTERNET','MOBILE', 'FIX')
        and a.id_comisionista is not null

QUALIFY ROW_NUMBER() OVER (
                    PARTITION BY a.marca, a.msisdn, a.service_type, a.service_id, a.concepto, CAST(a.comision AS STRING)
                    ORDER BY CASE WHEN parse_date('%Y%m%d',a.activation_date) = f.activation_date THEN 1 ELSE 2 END
                    ) = 1
;

ASSERT NOT EXISTS
(
SELECT phone_nm, service_id, concepto, comision
FROM `mm-commissions-reporting.COMISIONES.transacciones`
WHERE id_mes = mes_pr
      AND agrupacion_canal = agrupacion_canal_pr
      AND process_code = descripcion_proceso_pr
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1
)AS "Error: Existen duplicados en las transacciones generadas para este proceso.";


-- Se añade Energía al facturador
IF tipo_pr = 'AJUSTES' THEN

insert into
  `mm-commissions-reporting.COMISIONES.facturacion_manual`
select
  id_proceso_pr,
  agrupacion_canal_pr,  
  mes_pr,
  descripcion_proceso_pr,
  *
from
  `mm-commissions-reporting.GS.FACTURACION_MANUAL` 
; 

INSERT INTO
  `mm-commissions-reporting.COMISIONES.transacciones` (
    commission_id,
estado,
mes_liquidado,
id_mes,
agrupacion_canal,
canal,
concepto,
tipo_concepto,
unidades,
comision,
id_comisionista,
distribuidor,
sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
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
cod_marca,
cod_tipo_contrato,
cod_producto,
cod_canal,
campaign_code,
serial_number,
tax_base,
claim_code,
process_code,
comments,
facturador,
sociedad,
creado
    )
SELECT
    'CMAN'||'_'||cast(id_proceso_pr as string)||'_'||CAST(mes_pr AS string)||'_'||a.canal||'_'||ROW_NUMBER() OVER () as commission_id,
    'calculado' as estado,
    COMISIONES.f_mes_int(mes_pr) as mes_liquidado,
    mes_pr,
    agrupacion_canal_pr,
    a.canal,
    COMISIONES.f_limpiar_caracteres (a.concepto) as concepto,
    b.tipo_concepto,
    1 as unidades,
    a.comision,
    a.id_comisionista,
    e.distribuidor,
    a.seller as sfid_id,
    a.seller,
    e.nombre_comercio,
    e.razon_social,
    e.cif,
    e.zona_fiscal,
    a.marca,
    a.service_type,
    a.msisdn,
    a.tariff_id,
    a.tariff_ds,
    a.service_id,
    a.account_id,
    a.customer_id,
    cast (null as string ) as line_type_ds,
    cast (null as string ) as bundle_type,
    cast (null as string ) as technology_ds,
    a.ifs_transaction_id as billing_type_ds,
    parse_date('%Y%m%d',a.sale_date) as sale_date,
    parse_date('%Y%m%d',a.activation_date) as activation_date,
    cast (null as date ) as deactivation_date,
    cast (null as string ) as order_id,
    cast (null as string ) as order_type_agg,
    a.cod_segmento,
    d.cod_marca,
    b.cod_tipo_contrato,
    b.cod_producto,
    c.cod_canal,
    cast(null as string) as campaign_code,
    cast(null as string) as serial_number,
    cast(null as float64) as tax_base,
    a.claim_code,
    descripcion_proceso_pr as process_code,
    cast (null as string) as comments,
    'C_MANUAL' as facturador,
    `mm-commissions-reporting.COMISIONES.f_sociedad`(a.marca) as sociedad,
    CURRENT_TIMESTAMP () as creado
    
FROM
  `mm-commissions-reporting.GS.FACTURACION_MANUAL` a
  left join `mm-commissions-reporting.GS.CONCEPTOS` b on a.concepto = b.concepto
  left join `mm-commissions-reporting.GS.CANALES` c on a.canal=c.canal
  left join `mm-commissions-reporting.COMISIONES.marca_service_type_cod_marca` d on a.marca = d.marca and a.service_type = d.service_type
  left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` e on (a.seller = e.sfid_id OR SUBSTR(a.seller,1,2) = e.sfid_id OR a.seller = e.id_comisionista) 
  --and e.id_mes = mes_pr 
  and agrupacion_canal_pr = e.agrupacion_canal
  where a.id_comisionista is not null

  QUALIFY ROW_NUMBER() OVER (
                    PARTITION BY a.marca, a.msisdn, a.service_type, a.seller, a.concepto,a.service_id, CAST(a.comision AS STRING)
                    ORDER BY CASE WHEN a.seller = e.sfid_id THEN 1 ELSE 2 END
                    ) = 1

  ;

END IF;

-- Se añade Energía al facturador
ELSEIF tipo_pr = 'ENERGY' THEN


 INSERT INTO
  `mm-commissions-reporting.COMISIONES.facturacion_manual`
 SELECT
  id_proceso_pr,
  agrupacion_canal_pr,  
  mes_pr,
  descripcion_proceso_pr,
  *
 FROM
  `mm-commissions-reporting.GS.FACTURACION_MANUAL` 
 ; 

 INSERT INTO `mm-commissions-reporting.COMISIONES.transacciones` (
  commission_id,
  estado,
  mes_liquidado,
  id_mes,
  agrupacion_canal,
  canal,
  concepto,
  tipo_concepto,
  unidades,
  comision,
  id_comisionista,
  distribuidor,
  sfid_id,
  seller,
  nombre_comercio,
  razon_social,
  cif,
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
  cod_marca,
  cod_tipo_contrato,
  cod_producto,
  cod_canal,
  campaign_code,
  serial_number,
  tax_base,
  claim_code,
  process_code,
  comments,
  facturador,
  sociedad,
  creado
    )
 SELECT
    'CMAN'||'_'||CAST(id_proceso_pr AS STRING)||'_'||CAST(mes_pr AS string)||'_'||MANUAL.canal||'_'||ROW_NUMBER() OVER () as commission_id,
    'calculado' as estado,
    COMISIONES.f_mes_int(mes_pr) as mes_liquidado,
    mes_pr,
    agrupacion_canal_pr,
    MANUAL.canal,
    COMISIONES.f_limpiar_caracteres (MANUAL.concepto) as concepto,
    CONCEPTOS.tipo_concepto,
    1 AS unidades,
    MANUAL.comision,
    CASE WHEN SUBSTR(MANUAL.concepto,1,1) IN ('F','H','Y') and agrupacion_canal_pr = 'No Exclusivo' THEN MASTER.id_comisionista 
     ELSE MANUAL.id_comisionista END AS id_comisionista,
    DEALER.distribuidor,
    MANUAL.seller AS sfid_id,
    MANUAL.seller,
    CASE WHEN SUBSTR (MANUAL.concepto,1,1) IN ('F','H','Y') AND agrupacion_canal_pr = 'No Exclusivo' THEN MASTER.nombre_comercio 
     ELSE DEALER.nombre_comercio END AS nombre_comercio,
    CASE WHEN SUBSTR (MANUAL.concepto,1,1) IN ('F','H','Y') AND agrupacion_canal_pr = 'No Exclusivo' THEN MASTER.razon_social
     ELSE DEALER.razon_social END AS razon_social,
    CASE WHEN SUBSTR (MANUAL.concepto,1,1) IN ('F','H','Y') AND agrupacion_canal_pr = 'No Exclusivo' THEN MASTER.cif 
     ELSE DEALER.cif END AS cif,
    CASE WHEN SUBSTR (MANUAL.concepto,1,1) IN ('F','H','Y') AND agrupacion_canal_pr = 'No Exclusivo' THEN MASTER.zona_fiscal
     ELSE DEALER.zona_fiscal END AS zona_fiscal,
    MANUAL.marca,
    'ENERGY' AS service_type,
    MANUAL.msisdn AS phone_nm,
    MANUAL.tariff_id,
    MANUAL.tariff_ds, 
    MANUAL.service_id,
    MANUAL.account_id,
    MANUAL.customer_id,
    CAST (NULL AS STRING) AS line_type_ds,
    CAST (NULL AS STRING) AS bundle_type,
    CAST (NULL AS STRING) AS technology_ds,
    CAST (NULL AS STRING) AS billing_type_ds,
    PARSE_DATE('%Y%m%d',MANUAL.sale_date) AS sale_date,
    PARSE_DATE('%Y%m%d',MANUAL.activation_date) AS activation_date,
    CAST (NULL AS DATE) AS deactivation_date,
    CAST (NULL AS STRING) AS order_id,
    CAST (NULL AS STRING) AS order_type_agg,
    MANUAL.cod_segmento,
    CASE WHEN MANUAL.marca ='MASMOVIL'               THEN '17'
         when MANUAL.marca IN ('ENERGYGO','YOIGO')   THEN '16'
         when MANUAL.marca ='PEPEENERGY'             THEN '19'
          ELSE '16'
    END AS cod_marca,
    COALESCE (CONCEPTOS.cod_tipo_contrato, '99'),
    COALESCE (CONCEPTOS.cod_producto, '999'),
    CANALES.cod_canal,
    CAST (NULL AS STRING) AS campaign_code,
    CAST (NULL AS STRING) AS serial_number,
    CAST (NULL AS FLOAT64) AS tax_base,
    MANUAL.claim_code,
    descripcion_proceso_pr as process_code,
    CAST (NULL AS STRING) AS comments,
    'C_MANUAL' as facturador,
    `mm-commissions-reporting.COMISIONES.f_sociedad`(MANUAL.marca) AS sociedad,
    CURRENT_TIMESTAMP () as creado

 FROM `mm-commissions-reporting.GS.FACTURACION_MANUAL` MANUAL
 
 LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS 
   ON MANUAL.concepto = CONCEPTOS.concepto
 
 LEFT JOIN `mm-commissions-reporting.GS.CANALES` CANALES 
   ON MANUAL.canal = CANALES.canal
 
 LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER 
   ON (MANUAL.seller = dealer.sfid_id OR SUBSTR(MANUAL.seller,1,2) = DEALER.sfid_id) 
   AND agrupacion_canal_pr = DEALER.agrupacion_canal
 
 LEFT JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER 
   ON DEALER.distribuidor = MASTER.id_comisionista
 
 
 WHERE MANUAL.id_comisionista IS NOT NULL
  AND CONCEPTOS.concepto IS NOT NULL
  AND CANALES.canal IS NOT NULL
  AND DEALER.sfid_id IS NOT NULL
 
  QUALIFY ROW_NUMBER() OVER (
                    PARTITION BY MANUAL.marca, MANUAL.msisdn, MANUAL.service_type, MANUAL.seller, MANUAL.concepto,MANUAL.claim_code, CAST(MANUAL.comision AS STRING),MANUAL.account_id
                    ORDER BY CASE WHEN MANUAL.seller = DEALER.sfid_id THEN 1 ELSE 2 END
                    ) = 1
                    
;
--
else

insert into
  `mm-commissions-reporting.COMISIONES.facturacion_manual`
select
  id_proceso_pr,
  agrupacion_canal_pr,  
  mes_pr,
  descripcion_proceso_pr,
  *
from
  `mm-commissions-reporting.GS.FACTURACION_MANUAL` 
; 

INSERT INTO
  `mm-commissions-reporting.COMISIONES.transacciones` (
    commission_id,
estado,
mes_liquidado,
id_mes,
agrupacion_canal,
canal,
concepto,
tipo_concepto,
unidades,
comision,
id_comisionista,
distribuidor,
sfid_id,
seller,
nombre_comercio,
razon_social,
cif,
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
cod_marca,
cod_tipo_contrato,
cod_producto,
cod_canal,
campaign_code,
serial_number,
tax_base,
claim_code,
process_code,
comments,
facturador,
sociedad,
creado
    )
SELECT
    'CMAN'||'_'||cast(id_proceso_pr as string)||'_'||CAST(mes_pr AS string)||'_'||a.canal||'_'||ROW_NUMBER() OVER () as commission_id,
    'calculado' as estado,
    COMISIONES.f_mes_int(mes_pr) as mes_liquidado,
    mes_pr,
    agrupacion_canal_pr,
    a.canal,
    COMISIONES.f_limpiar_caracteres (a.concepto) as concepto,
    b.tipo_concepto,
    1 as unidades,
    a.comision,
    a.id_comisionista,
    e.distribuidor,
    a.seller as sfid_id,
    a.seller,
    e.nombre_comercio,
    e.razon_social,
    e.cif,
    e.zona_fiscal,
    a.marca,
    a.service_type,
    a.msisdn,
    a.tariff_id,
    a.tariff_ds,
    a.service_id,
    a.account_id,
    a.customer_id,
    cast (null as string ) as line_type_ds,
    cast (null as string ) as bundle_type,
    cast (null as string ) as technology_ds,
    cast (null as string ) as billing_type_ds,
    parse_date('%Y%m%d',a.sale_date) as sale_date,
    parse_date('%Y%m%d',a.activation_date) as activation_date,
    cast (null as date ) as deactivation_date,
    cast (null as string ) as order_id,
    cast (null as string ) as order_type_agg,
    a.cod_segmento,
    d.cod_marca,
    b.cod_tipo_contrato,
    b.cod_producto,
    c.cod_canal,
    cast(null as string) as campaign_code,
    cast(null as string) as serial_number,
    cast(null as float64) as tax_base,
    a.claim_code,
    descripcion_proceso_pr as process_code,
    cast (null as string) as comments,
    'C_MANUAL' as facturador,
    `mm-commissions-reporting.COMISIONES.f_sociedad`(a.marca) as sociedad,
    CURRENT_TIMESTAMP () as creado
FROM
  `mm-commissions-reporting.GS.FACTURACION_MANUAL` a
  left join `mm-commissions-reporting.GS.CONCEPTOS` b on a.concepto = b.concepto
  left join `mm-commissions-reporting.GS.CANALES` c on a.canal=c.canal
  left join `mm-commissions-reporting.COMISIONES.marca_service_type_cod_marca` d on a.marca = d.marca and a.service_type = d.service_type
  left join `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` e on (a.seller = e.sfid_id OR SUBSTR(a.seller,1,2) = e.sfid_id OR a.seller = e.id_comisionista) 
  --and e.id_mes = mes_pr 
  and agrupacion_canal_pr = e.agrupacion_canal
  where a.service_type not in ('INTERNET','MOBILE', 'FIX')
  and a.id_comisionista is not null

  QUALIFY ROW_NUMBER() OVER (
                    PARTITION BY a.marca, a.msisdn, a.service_type, a.seller, a.concepto,a.service_id, CAST(a.comision AS STRING)
                    ORDER BY CASE WHEN a.seller = e.sfid_id THEN 1 ELSE 2 END
                    ) = 1

  ;

end if;

assert not exists (
select commission_id
from `mm-commissions-reporting.COMISIONES.transacciones`
group by 1
having count(1) > 1 )
AS "Error: Se detectaron commission_id duplicados en transacciones.";

/*
--- Validar campañas Lisandro ---
assert not exists(
  select 1
  from  `mm-commissions-reporting.GS.FACTURACION_MANUAL` a
  where agrupacion_canal = "TLV - Cross-sell" and campaign_code is null )
);*/

COMMIT TRANSACTION;


EXCEPTION WHEN ERROR THEN
RAISE USING message = FORMAT("Error while executing %s at %s, it caused an error: %s.", @@error.statement_text, @@error.formatted_stack_trace, @@error.message);
ROLLBACK TRANSACTION;
    

  

END