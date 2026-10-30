BEGIN


insert into `mm-commissions-reporting.RappelD2D.Rappel_Fijo` 
(

WITH 

RESULTADO AS(
 select   
  'RPD2'||'_'||MES_1||'_'||F1.CANAL||'_'||'LLAMADAS'||row_number () over () AS commission_id,
  'calculado' AS estado,
      CASE WHEN F1.CANAL IN ('D2N','DEM','EDB') THEN DATE_ADD(MES_INI,INTERVAL 1 MONTH)  
    ELSE MES_INI END AS mes_liquidado,
    CASE WHEN F1.CANAL IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER) 
    ELSE cast(MES_1 as INTEGER) END AS id_mes,
  F1.agrupacion_canal,
  F1.canal,
  'P – Penalización Venta Telefónica' AS concepto,
  F1.tipo_concepto,
  F1.unidades,
    CASE 
        WHEN  __Venta_Telef__nica / 100 between 15 AND 25 THEN (0.5 * F1.COMISION) * -1
        WHEN  __Venta_Telef__nica / 100 >= 25 THEN (1 * F1.COMISION) * -1
        ELSE 0
        END AS comision,
  F1.ID_COMISIONISTA AS id_comisionista,
  F1.ID_COMISIONISTA AS distribuidor,
  F1.ID_COMISIONISTA AS sfid_id,
  F1.ID_COMISIONISTA AS seller,
  F1.nombre_comercio AS nombre_comercio,
  F1.razon_social AS razon_social,
  F1.cif AS  cif,
  F1.zona_fiscal AS zona_fiscal,
  F1.MARCA as marca,
  F1.service_type,
  F1.phone_nm ,
  F1.tariff_id,
  F1.tariff_ds,
  F1.service_id,
  F1.account_id,
  F1.customer_id,
  F1.line_type_ds,
  F1.bundle_type,
  F1.technology_ds,
  F1.billing_type_ds,
  F1.sale_date,
  F1.activation_date,
  F1.deactivation_date,
  F1.order_id,
  F1.order_type_agg,
  F1.cod_segmento,
  F1.cod_marca,
  F1.cod_tipo_contrato,
  F1.cod_producto,
  F1.cod_canal,
  F1.claim_code,
  F1.campaign_code,
  'LLAMADAS_'||F1.CANAL||'_'||MES_1 AS process_code,
  F1.comments,
  F1.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  'X001' AS sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  CURRENT_TIMESTAMP() AS creado,
  CURRENT_TIMESTAMP() AS modificado,
  '' AS id_factura_drive,
  '' AS emails_acceso_trazabilidad


  FROM
    
    (SELECT * 
      FROM `mm-commissions-reporting.RappelD2D.Rappel_Fijo` R 
      where 
      UPPER(CONCEPTO) LIKE '%FIJO%' AND UPPER(CONCEPTO) NOT LIKE '%CLAW%' 
      AND CANAL = V_CANAL and id_mes =  CASE WHEN CANAL IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER)ELSE MES_1 END) F1

    LEFT JOIN `mm-commissions-reporting.RappelD2D.LLAMADA_CALIDAD` ca
          on ca.VENDEDOR = F1.id_comisionista AND   cast(ca.mes as integer) = MES_1

    inner join (SELECT  distinct B.ID_COMISIONISTA,b.nombre_comercio,b.razon_social,b.cif,b.zona_fiscal   FROM `mm-commissions-reporting.COMISIONES.activaciones` b) b 
    ON CA.VENDEDOR  = b.ID_COMISIONISTA
  
  )
SELECT * FROM RESULTADO WHERE COMISION <> 0

);

END