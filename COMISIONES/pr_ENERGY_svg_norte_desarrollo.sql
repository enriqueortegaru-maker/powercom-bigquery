begin

declare prefijo, mes_string string;

set mes_string = cast(id_mes_pr as string);

set prefijo = 'NENRG_';



--call COMISIONES.pr_ENERGY_svg_norte_desarrollo (202412, null);

create or replace table TEMP.ENERGY_svg_norte as

SELECT
 id_mes_pr AS id_mes,
prefijo||'BNSVG_'||mes_string||'_'||C.agrupacion_canal||'_'||row_number () OVER () AS commission_id,
C.agrupacion_canal ,
C.canaln as canal,
cast(null as string) as cod_canal,
  (
  SELECT
    concepto
  FROM
    `mm-commissions-reporting.GS.CONCEPTOS`
  WHERE
    CONCEPTO IN ('B - SVG')) AS concepto,
  'CSEN' AS tipo_concepto,
  1 AS unidades,
--   CASE
--      when agrupacion_canal =  'WEB' and C.canaln = 'WEB DISTRIBUIDOR' THEN 30               --Canal DOL
--      when agrupacion_canal =  'PUNTO DE VENTA' and C.canaln = 'PUNTO DE VENTA' THEN 15      --​Tiendas: Residencial y Empresa
--      when agrupacion_canal =  'TASK FORCE' and C.canaln IN('STANDS','TASK FORCE') THEN 30   --​Stands y task: Residencial y Empresa
--      when agrupacion_canal =  'TELEVENTA' and C.canaln = 'AGENTE VENTAS CARTERA' THEN 10       --Tvtas cartera: Residencial y Empresa
--      when agrupacion_canal =  'TELEVENTA' and C.canaln IN ('EROSKI','BBDD DISTRIBUIDOR','BBDD OPERADOR') THEN 10 --Tvtas captacion: Residencial y Empresa
--      when agrupacion_canal IN  ('WEB', 'INBOUND') and C.canaln = 'AGENTE VENTAS CARTERA' THEN 10    --INB/WEB cartera: Residencial y Empresa
--      when agrupacion_canal IN  ('WEB', 'INBOUND') and C.canaln IN ('AGENTE VENTAS CAPTACION','INBOUND','WEB OPERADOR') THEN 10  --INB/WEB captacion: Residencial y Empresa
   
--  END
--   AS COMISION,

  d.comision  as comision, 
  C.id_comisionista,
  C.distribuidor,
  C.sfid_id,
  upper(SPLIT(A.author_id, "@")[OFFSET (0)]) AS seller,
  C.nombre_comercio,
  C.razon_social,
  C.cif,
  C.zona_fiscal,
  'EUSKALTEL' AS marca,
  'ENERGY' AS service_type,
  CAST(NULL AS string) AS phone_nm,
  CAST(NULL AS STRING) AS tariff_id,
  CAST(NULL AS STRING) AS tariff_ds,
  CAST(NULL AS STRING) AS service_id,
  A.cups_code AS account_id,
  CAST(NULL AS STRING) AS customer_id,
  CAST(NULL AS STRING) AS line_type_ds,
  CAST(NULL AS STRING) AS bundle_type,
  CAST(NULL AS STRING) AS technology_ds,
  CAST(NULL AS STRING) AS billing_type_ds,
  A.signup_date_altas AS sale_date,
  B.data_inici AS activation_date,
  B.data_fi AS deactivation_date,
  CAST (NULL AS string) AS order_id,
  CAST (NULL AS string) AS order_type_agg,
  '10' AS cod_segmento,
  '99' AS cod_tipo_contrato,
  '014' AS cod_producto,
cast(null as string) cod_marca,
  CAST (NULL AS string) AS claim_code,
CAST(NULL AS STRING) AS campaign_code,
  A.cups_code AS serial_number,
  CAST ( NULL AS float64 ) tax_base,
  CAST (NULL AS string) AS process_code,
  CAST (NULL AS string) AS comments,
  'C_MANUAL' AS facturador,
  'calculado' AS estado
FROM
  `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
INNER JOIN
  `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
ON
  A.id = B.polissa_id
LEFT JOIN
  `mm-commissions-reporting.COMISIONES.v_dealer_krt`C
ON A.sfid_id = C.sfid_id
left join `mm-commissions-reporting.GS.krt_importe_energia` d
on C.canaln = d.CANAL and C.agrupacion_canal =d.AGRUPACION_CANAL AND D.CONCEPTO ='B - SVG'

WHERE
  DATE_TRUNC(DATE(B.data_inici), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND product = 'SVG'
  AND tenant_code = 'euskaltel_svg'
  and channel_ds not in ('PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
  and A.sfid_id is not null
  and state= 'activa'
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC ) = 1 

  UNION ALL

SELECT
 id_mes_pr AS id_mes,
prefijo||mes_string||'_'||C.agrupacion_canal||'_'||row_number () OVER () AS commission_id,
C.agrupacion_canal,
C.canaln as canal,
cast(null as string) as cod_canal,
  (
  SELECT
    concepto
  FROM
    `mm-commissions-reporting.GS.CONCEPTOS`
  WHERE
    CONCEPTO IN ('B - SVG')) AS concepto,
  'CSEN' AS tipo_concepto,
  1 AS unidades,
--   CASE
--      when agrupacion_canal =  'WEB' and C.canaln = 'WEB DISTRIBUIDOR' THEN 30               --Canal DOL
--      when agrupacion_canal =  'PUNTO DE VENTA' and C.canaln = 'PUNTO DE VENTA' THEN 15      --​Tiendas: Residencial y Empresa
--      when agrupacion_canal =  'TASK FORCE' and C.canaln IN('STANDS','TASK FORCE') THEN 30   --​Stands y task: Residencial y Empresa
--      when agrupacion_canal =  'TELEVENTA' and C.canaln = 'AGENTE VENTAS CARTERA' THEN 10       --Tvtas cartera: Residencial y Empresa
--      when agrupacion_canal =  'TELEVENTA' and C.canaln IN ('EROSKI','BBDD DISTRIBUIDOR','BBDD OPERADOR') THEN 10 --Tvtas captacion: Residencial y Empresa
--      when agrupacion_canal IN  ('WEB', 'INBOUND') and C.canaln = 'AGENTE VENTAS CARTERA' THEN 10    --INB/WEB cartera: Residencial y Empresa
--      when agrupacion_canal IN  ('WEB', 'INBOUND') and C.canaln IN ('AGENTE VENTAS CAPTACION','INBOUND','WEB OPERADOR') THEN 10  --INB/WEB captacion: Residencial y Empresa
   
--  END
--   AS COMISION,

  d.comision  as comision, 
  C.id_comisionista,
  C.distribuidor,
  C.sfid_id,
  upper(SPLIT(A.author_id, "@")[OFFSET (0)]) AS seller,
  C.nombre_comercio,
  C.razon_social,
  C.cif,
  C.zona_fiscal,
  'R' AS marca,
  'ENERGY' AS service_type,
  CAST(NULL AS string) AS phone_nm,
  CAST(NULL AS STRING) AS tariff_id,
  CAST(NULL AS STRING) AS tariff_ds,
  CAST(NULL AS STRING) AS service_id,
  A.cups_code AS account_id,
  CAST(NULL AS STRING) AS customer_id,
  CAST(NULL AS STRING) AS line_type_ds,
  CAST(NULL AS STRING) AS bundle_type,
  CAST(NULL AS STRING) AS technology_ds,
  CAST(NULL AS STRING) AS billing_type_ds,
  A.signup_date_altas AS sale_date,
  B.data_inici AS activation_date,
  B.data_fi AS deactivation_date,
  CAST (NULL AS string) AS order_id,
  CAST (NULL AS string) AS order_type_agg,
  '10' AS cod_segmento,
  '99' AS cod_tipo_contrato,
  '014' AS cod_producto,
cast(null as string) cod_marca,
  CAST (NULL AS string) AS claim_code,
CAST(NULL AS STRING) AS campaign_code,
  A.cups_code AS serial_number,
  CAST ( NULL AS float64 ) tax_base,
  CAST (NULL AS string) AS process_code,
  CAST (NULL AS string) AS comments,
  'C_MANUAL' AS facturador,
  'calculado' AS estado
FROM
  `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
INNER JOIN
  `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
ON
  A.id = B.polissa_id
LEFT JOIN  (

  SELECT 
  distinct 
  id_mes_pr,
  channel_ds as agrupacion_canal,
  CAST(sfid_id AS STRING) sfid_id,
  vertical_focus as id_comisionista,
  vertical_focus as nombre_comercio,  
  distributor as distribuidor,
  distributor as razon_social,  
  subchannel_ds as canaln,
  `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`('R', distributor)as cif,
  'PEN' as zona_fiscal 
  FROM `mm-commissions-reporting.KRT_MIG_PWC.PARAM_CANALES_R`

) C
ON A.sfid_id = C.sfid_id
left join `mm-commissions-reporting.GS.krt_importe_energia` d
on C.canaln = d.CANAL and C.agrupacion_canal =d.AGRUPACION_CANAL AND D.CONCEPTO ='B - SVG'

WHERE
  DATE_TRUNC(DATE(B.data_inici), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND product = 'SVG'
  AND tenant_code = 'r_svg'
  and channel_ds not in ('PENDIENTE DEFINIR','PLAT. FIDELIZACION/RETENCION','CANCELACIONES') 
  and A.sfid_id is not null
  and state= 'activa'
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC ) = 1 ;
  

  end