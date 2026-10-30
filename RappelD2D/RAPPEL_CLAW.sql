BEGIN

INSERT INTO `mm-commissions-reporting.RappelD2D.Rappel_Fijo`(

with 

servicios as (
  select B.*,R.concepto AS CONCEPTO_RAP,R.comision AS COMISION_RAP, 

  from 
  `mm-commissions-reporting.RappelD2D.V_CLAWBACK_FIX` B
  
    INNER JOIN `mm-commissions-reporting.RappelD2D.Rappel_Fijo` R
      ON B.PHONE_NM = R.phone_nm AND B.SERVICE_ID = R.service_id AND R.CONCEPTO LIKE 'D - Rappel Fijo_%'
  
  where 
  -- SE DESCARTAN LAS PORTABILIDADES ENTRE MARCAS DEL GRUPO
  (portability_group_donor not in ('MASMOVIL','YOIGO','LLAMAYA','Xtra Telecom S.A.','PEPEPHONE 3.0','JOI MOBILE','JOi Mobile','GUUK','EUSKALTEL','MÁSMÓVIL','MASMOVIL 2','XTRA TELECOM S.A.','LLAMAYA (MOREMINUTES)','LYCAMOBILE','XPHERA MOVILES','LLAMAYA_GMM') OR portability_group_donor IS NULL)
  AND B.agrupacion_canal = 'D2D'
  AND B.ID_MES = MES_1
  AND B.canal = V_CANAL
  and B.activation_date between MES_INI and MES_FINAL
  
  ),


RESULTADO AS (
  SELECT  
  'RPD2'||'_'||MES_1||'_'||S.CANAL||'_'||'CLAW'||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN DATE_ADD(mes_liquidado,INTERVAL 1 MONTH)  
    ELSE S.mes_liquidado END AS mes_liquidado,
  CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER) 
    ELSE S.ID_MES END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'E - Clawback Rappel Fijo_'||SUBSTR(S.CONCEPTO_RAP,17,1) as concepto,
  S.tipo_concepto,
  S.unidades,
  (S.COMISION_RAP) * -1 AS comision,
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
  S.claim_code,
  S.campaign_code,
  'RAPPEL_CLAWBACK'||S.CANAL||'_'||MES_1 AS process_code,
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
  servicios s
  
  )
SELECT * FROM RESULTADO WHERE commission_id IS NOT NULL AND COMISION IS NOT NULL
);

END