BEGIN


insert into `mm-commissions-reporting.RappelD2D.Rappel_Fijo` 
(

with 

coches as (
  select 
  c.codigo,
  count(c.gerente) as coches
  from
  mm-commissions-reporting.RappelD2D.COCHES c
  WHERE
  C.MES = MES_1
  group by 1
  ),

RESULTADO AS (
  SELECT  
  C.CODIGO,
  c2.servicios,
  'RPD2'||'_'||MES_1||'_'||S.CANAL||'_'||'COCHES'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN DATE_ADD(mes_liquidado,INTERVAL 1 MONTH)  
    ELSE S.mes_liquidado END AS mes_liquidado,
  CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER) 
    ELSE S.ID_MES END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Apoyo Coche' as concepto,
  S.tipo_concepto,
  S.unidades,
  CASE 
    WHEN S.CANAL = 'DEM' AND C2.SERVICIOS < 10 THEN 0 
    WHEN S.CANAL = 'DEM' AND C2.servicios >= 10 THEN (10 * S.UNIDADES)
  ELSE (10 * S.UNIDADES) END AS comision,
  s.id_comisionista,
  S.distribuidor,
  S.sfid_id,
  S.seller,
  S.nombre_comercio,
  S.razon_social,
  S.cif,
  S.zona_fiscal,
  S.marca,
  S.service_type,
  S.phone_nm,
  S.tariff_id,
  S.tariff_ds,
  S.service_id,
  S.account_id,
  S.customer_id,
  S.line_type_ds,
  S.bundle_type,
  S.technology_ds,
  S.billing_type_ds,
  S.sale_date,
  S.activation_date,
  S.deactivation_date,
  S.order_id,
  S.order_type_agg,
  S.cod_segmento,
  S.cod_marca,
  S.cod_tipo_contrato,
  S.cod_producto,
  S.cod_canal,
  'COCHES = '||C.COCHES AS claim_code,
  S.campaign_code,
  'COCHES_'||S.CANAL||'_'||MES_1 AS process_code,
  S.comments,
  S.facturador,
  S.proceso_sap,
  S.id_registro,
  S.invoice_id,
  S.sociedad,
  S.bp,
  S.cuenta_contable,
  S.centro_coste,
  S.documento_sap,
  S.documento_sap_posicion,
  S.fecha_contabilizacion,
  S.creado,
  S.modificado,
  S.id_factura_drive,
  '' as emails_acceso_trazabilidad


  FROM
  `mm-commissions-reporting.RappelD2D.V_SERVICIOS_FIJO` S

  left join coches C
    ON S.ID_COMISIONISTA = C.codigo
  
  LEFT JOIN `mm-commissions-reporting.RappelD2D.HISTO_CONTADOR`  C2
  
    ON S.ID_COMISIONISTA = C2.ID_COMISIONISTA
  
  WHERE
  S.id_mes = MES_1
  AND S.AGRUPACION_CANAL = 'D2D'
  AND S.CANAL = V_CANAL
  AND S.activation_date BETWEEN MES_INI AND MES_FINAL
  ),

resul_desc as (
  select 
  sfid_id,
  substr(claim_code,9,2) as coches,
  sum(comision) as tot_comi 
  from resultado r 
  WHERE 
  COMISION IS NOT NULL 
  and COMISION <> 0 
  AND CODIGO IS NOT NULL 
  group by 1,2
  )

SELECT  
  r.commission_id,
  r.estado,
  r.mes_liquidado,
  r.id_mes,
  'D2D' as agrupacion_canal,
  r.canal,
  r.concepto,
  r.tipo_concepto,
  r.unidades,
  CASE
    WHEN r2.tot_comi / cast(r2.coches as integer) >= 300 THEN (300 * cast(r2.coches as integer) ) /  r.servicios
  ELSE r.comision
  END AS comision,
  r.id_comisionista,
  r.distribuidor,
  r.sfid_id,
  r.seller,
  r.nombre_comercio,
  r.razon_social,
  r.cif,
  r.zona_fiscal,
  r.marca,
  r.service_type,
  r.phone_nm,
  r.tariff_id,
  r.tariff_ds,
  r.service_id,
  r.account_id,
  r.customer_id,
  r.line_type_ds,
  r.bundle_type,
  r.technology_ds,
  r.billing_type_ds,
  r.sale_date,
  r.activation_date,
  r.deactivation_date,
  r.order_id,
  r.order_type_agg,
  r.cod_segmento,
  r.cod_marca,
  r.cod_tipo_contrato,
  r.cod_producto,
  r.cod_canal,
  r.claim_code,
  r.campaign_code,
  r.process_code,
  r.comments,
  r.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  r.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  R.creado,
  R.modificado,
  '' AS id_factura_drive,
  r.emails_acceso_trazabilidad


  from RESULTADO r 

  LEFT JOIN resul_desc r2 
    on r.sfid_id = r2.sfid_id 

  WHERE COMISION IS NOT NULL 
  and COMISION <> 0 
  AND CODIGO IS NOT NULL
);

END