BEGIN

DECLARE mes_string, prefijo STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'GCAN';

-- CALL `mm-commissions-reporting.COMISIONES.pr_gestion_canal_exc`(202607, ['ENK','EML','ENX','EYG','EDB']);

IF EXISTS(SELECT * FROM `mm-commissions-reporting.COMISIONES.transacciones` WHERE id_mes = id_mes_pr AND agrupacion_canal = 'Exclusivo' AND commission_id LIKE 'GCAN%') THEN
      DELETE FROM `mm-commissions-reporting.COMISIONES.transacciones` WHERE id_mes = id_mes_pr AND agrupacion_canal = 'Exclusivo' AND commission_id LIKE 'GCAN%';

END IF;

INSERT INTO `mm-commissions-reporting.COMISIONES.transacciones`
 
(
commission_id
,estado
,mes_liquidado
,id_mes
,agrupacion_canal
,canal
,concepto
,tipo_concepto
,unidades
,comision
,id_comisionista
,distribuidor
,sfid_id
,seller
,nombre_comercio
,razon_social
,cif
,zona_fiscal
,marca
,service_type
,phone_nm
,tariff_id
,tariff_ds
,service_id
,account_id
,customer_id
,line_type_ds
,bundle_type
,technology_ds
,billing_type_ds
,sale_date
,activation_date
,deactivation_date
,order_id
,order_type_agg
,cod_segmento
,cod_marca
,cod_tipo_contrato
,cod_producto
,cod_canal
,claim_code
,campaign_code
,process_code
,comments
,facturador
,sociedad
,creado
)
SELECT
prefijo || '_' || mes_string || '_' || 'ENK' || '_' || ROW_NUMBER() OVER() AS commission_id
,'validado' AS estado
, PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
,id_mes_pr as id_mes
,'Exclusivo' as agrupacion_canal
,'ENK' AS canal
,'F - Gestion Canal' as  concepto
,tipo_concepto
,1 as unidades
,comision
,'BYMOVIL' AS id_comisionista
,'BYMOVIL' distribuidor
,'BYMOVIL' sfid_id
,'BYMOVIL' seller
,'BYMOVIL' nombre_comercio
,'THE BYMOVIL SPAIN. S.L.U.' razon_social
,'B39688197' AS cif
,zona_fiscal
,marca
,'MOBILE' service_type
,CAST(null AS STRING) phone_nm
,CAST(null AS STRING) tariff_id
,CAST(null AS STRING) tariff_ds
,CAST(null AS STRING) service_id
,CAST(null AS STRING) account_id
,CAST(null AS STRING) customer_id
,CAST(null AS STRING) line_type_ds
,CAST(null AS STRING) bundle_type
,CAST(null AS STRING) technology_ds
,CAST(null AS STRING) billing_type_ds
,CAST(null AS DATE) sale_date
,CAST(null AS DATE) activation_date
,CAST(null AS DATE) deactivation_date
,CAST(null AS STRING) order_id
,CAST(null AS STRING) order_type_agg
,cod_segmento
,cod_marca
,cod_tipo_contrato
,cod_producto
,'27' cod_canal
,'GESTION_CANAL' AS claim_code
,CAST(null AS STRING) campaign_code
,CAST(null AS STRING) as process_code
,CAST(null AS STRING) comments
,'C_MANUAL' as facturador
,sociedad
,CURRENT_TIMESTAMP () as creado
FROM (SELECT tipo_concepto ,cod_producto, cod_tipo_contrato, cod_segmento,zona_fiscal,marca,cod_marca, (SUM(comision)*0.15) AS comision,sociedad
      FROM `mm-commissions-reporting.COMISIONES.transacciones` a
      WHERE id_mes = id_mes_pr
      AND agrupacion_canal = 'Exclusivo'
      AND tipo_concepto NOT IN ('FINT','SUBS','SRCI','TJTS','DUSI','SUTS','CATI','OPT1','SUM1','CSCP','CEXC')
      AND sociedad != '8000'
      AND estado != 'rechazado'
      AND concepto NOT IN ('F - Gestion Canal','Z - Gestion Canal')
      GROUP BY ALL
     )
;

ASSERT NOT EXISTS (
                  SELECT commission_id
                  FROM `mm-commissions-reporting.COMISIONES.transacciones`
                  GROUP BY ALL
                  HAVING COUNT(1) > 1
                  ) AS 'Hay duplicados en Transacciones' 
; 

END