BEGIN

-- call `mm-commissions-reporting.RappelD2D.RAPPEL_PREMIO_TRIMESTRAL_DEM`(202309,'2023-07-01','2023-09-30','DEM')

insert into `mm-commissions-reporting.RappelD2D.Rappel_Fijo` 
(

with 
CONTADOR AS (
  SELECT 
  C.ID_COMISIONISTA,
  SUM(C.unidades) AS SERVICIOS
  
  FROM

  `mm-commissions-reporting.RappelD2D.V_SERVICIOS_FIJO`  C
  
  WHERE
  C.agrupacion_canal = 'D2D'
  AND C.CANAL = V_CANAL
  AND C.activation_date BETWEEN MES_INI AND MES_FINAL
  AND C.tipo_concepto <> 'CENT'
  GROUP BY 1
  ),
 
CONFI_2 AS (
  SELECT 
  *
  FROM

  CONTADOR C
  
  LEFT JOIN `mm-commissions-reporting.RappelD2D.RAP_MARCO` d

   ON C.SERVICIOS BETWEEN CAST(d.RANGO_INICIAL AS INTEGER) AND CAST(d.RANGO_FINAL AS INTEGER) 
      AND D.TIPO = 'DEM_TRIMESTRAL'
  
  WHERE
  d.MES = CAST(MES_1 AS STRING)
  ),
RESULTADO AS (
  SELECT  
  'RPD2'||'_'||MES_1||'_'||S.CANAL||'_'||('PREMIO_TRIMESTRAL') ||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN DATE_ADD(MES_FINAL,INTERVAL 1 MONTH)  
    ELSE MES_FINAL END AS mes_liquidado,
  CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER) 
    ELSE CAST(MES_1 AS INTEGER) END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Incentivo Trimestral 2023' as concepto,
  S.tipo_concepto,
  S.unidades,
  (CAST(C.IMPORTE AS INTEGER))/C2.SERVICIOS AS comision,
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
  S.claim_code AS CLAIM_CODE,
  S.campaign_code,
  'RAPPEL_'||S.CANAL||'_'||'PREMIO_TRIMESTRAL'||'_'||C.CLASIFICACION||'_'||MES_1 AS process_code,
  S.comments,
  S.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  S.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  S.creado,
  S.modificado,
  '' AS id_factura_drive,
  '' as emails_acceso_trazabilidad


  FROM
  `mm-commissions-reporting.RappelD2D.V_SERVICIOS_FIJO` s

  left join CONFI_2 C
    ON S.ID_COMISIONISTA = C.id_comisionista --AND C.CLASIFICACION IS NOT NULL

  left join CONTADOR C2
    ON S.ID_COMISIONISTA = C2.id_comisionista

  WHERE
  S.agrupacion_canal = 'D2D'
  AND S.CANAL = V_CANAL
  AND S.activation_date BETWEEN MES_INI AND MES_FINAL
  AND S.tipo_concepto <> 'CENT'
  )
SELECT * FROM RESULTADO WHERE comision is not null 
);

end