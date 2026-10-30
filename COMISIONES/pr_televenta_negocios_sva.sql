BEGIN

DECLARE prefijo STRING;


SET prefijo = 'SVAN';


--CALL `mm-commissions-reporting.COMISIONES.pr_televenta_negocios_sva`(202304);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.televenta_negocios_sva extraccion` AS
(
SELECT
      sfid_id
     ,service_id
     ,CAST(ot_telefonos AS STRING) AS phone_nm
     ,DATE(fecha_venta) AS sale_date

     ,CASE
          WHEN UPPER(x_r_grupo_asignado) LIKE '%YOIGO%'    THEN 'YOIGO'
          WHEN UPPER(x_r_grupo_asignado) LIKE '%MASMOVIL%' THEN 'MASMOVIL'
      END AS marca

     ,idproducto AS tariff_id
     ,desccastellano AS tariff_ds
     
     ,CASE
          WHEN UPPER(desccastellano) LIKE '%CIBERSEGURIDAD%' THEN 'CIBERSEGURIDAD'
          WHEN UPPER(desccastellano) LIKE '%FACTURA%ELECT%'  THEN 'FACTURA ELECTRONICA'
          WHEN UPPER(desccastellano) LIKE '%PRESENCIA%'      THEN 'PRESENCIA ONLINE'
          WHEN UPPER(desccastellano) LIKE '%SOLUCIÓN%'       THEN 'SOLUCION DIGITAL'
          WHEN UPPER(desccastellano) LIKE '%WEB%'            THEN 'WEB PROFESIONAL'
          ELSE UPPER(desccastellano)
      END AS sva_type
     
     ,CASE
          WHEN UPPER(desccastellano) LIKE '%CIBERSEGURIDAD%' THEN 'SECURITY'
          WHEN UPPER(desccastellano) LIKE '%FACTURA%ELECT%'  THEN 'OTRS'
          WHEN UPPER(desccastellano) LIKE '%PRESENCIA%'      THEN 'OTRS'
          WHEN UPPER(desccastellano) LIKE '%SOLUCIÓN%'       THEN 'SOLUCION DIGITAL'
          WHEN UPPER(desccastellano) LIKE '%WEB%'            THEN 'OTRS'
          ELSE UPPER(desccastellano)
      END AS service_type

     ,CASE
          WHEN UPPER(desccastellano) LIKE '%CIBERSEGURIDAD%' THEN 27.00
          WHEN UPPER(desccastellano) LIKE '%FACTURA%ELECT%'  THEN 30.00
          WHEN UPPER(desccastellano) LIKE '%PRESENCIA%'      THEN 30.00
          WHEN UPPER(desccastellano) LIKE '%SOLUCIÓN%'       THEN 0.00
          WHEN UPPER(desccastellano) LIKE '%WEB%'            THEN 98.00
      END AS comision

FROM `mm-soho-reporting.TEMPORALES_SOHO.sva_siebel`

WHERE DATE_TRUNC(DATE(fecha_venta), MONTH) =  COMISIONES.f_mes_int(id_mes_pr)
      AND channel_ds NOT LIKE 'D2D%'
      AND estado = 'Finalizado'
)
;



CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.televenta_negocios_sva` AS
(
SELECT 
      id_mes_pr AS id_mes
     ,prefijo || '_' || CAST(id_mes_pr AS STRING) || '_' || DEALER.canal ||'_'|| ROW_NUMBER () OVER () AS commission_id
     ,DEALER.canal
     ,CANALES.agrupacion_canal
     ,CANALES.cod_canal

     ,CASE
          WHEN sva_type = 'CIBERSEGURIDAD'      THEN 'B - Ciberseguridad'
          WHEN sva_type = 'FACTURA ELECTRONICA' THEN 'B - Factura Electronica'
          WHEN sva_type = 'PRESENCIA ONLINE'    THEN 'B - Presencia Online'
          WHEN sva_type = 'SOLUCION DIGITAL'    THEN 'B - Solucion Digital'
          WHEN sva_type = 'WEB PROFESIONAL'     THEN 'B - Web Profesional'
      END AS concepto

     ,'OTRS' AS tipo_concepto
     ,1 AS unidades
     ,comision
     ,DEALER.id_comisionista
     ,distribuidor
     ,DEALER.sfid_id
     ,SVA.sfid_id AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,zona_fiscal
     ,marca
     ,service_type
     ,phone_nm
     ,tariff_id
     ,service_id
     ,CAST(NULL AS STRING) AS account_id
     ,CAST(NULL AS STRING) AS customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,CAST(NULL AS STRING) AS technology_ds
     ,CAST(NULL AS STRING) AS billing_type_ds
     ,sale_date
     ,CAST(NULL AS DATE) AS activation_date
     ,CAST(NULL AS DATE) AS deactivation_date
     ,CAST(NULL AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
     ,'12' AS cod_segmento
     ,'99' AS cod_tipo_contrato
     ,'999' AS cod_producto
     ,COMISIONES.f_cod_marca(marca, service_type) AS COD_MARCA
     ,CAST(NULL AS STRING) AS claim_code
     ,CAST(NULL AS STRING) AS campaign_code
     ,CAST(NULL AS STRING) AS process_code
     ,CAST(NULL AS STRING) AS comments
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.televenta_negocios_sva extraccion` SVA

INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
          ON (SVA.sfid_id = DEALER.sfid_id OR SUBSTR(SVA.sfid_id, 1, 2) = DEALER.sfid_id) AND DEALER.id_mes = id_mes_pr AND DEALER.agrupacion_canal = 'TLV - Negocios'

INNER JOIN `mm-commissions-reporting.GS.CANALES` CANALES
          ON DEALER.CANAL = CANALES.CANAL

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca ORDER BY DEALER.cif NULLS LAST) = 1
)
;


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, (SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.televenta_negocios_sva) , 'TEMP.televenta_negocios_sva' , 'ACTUALIZAR');


END