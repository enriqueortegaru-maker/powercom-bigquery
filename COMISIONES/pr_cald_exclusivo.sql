BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CALD';

SET canales_pr = COALESCE(canales_pr, ['EML']);

/*
CALL COMISIONES.pr_cald_exclusivo (202405,['EML']);
*/

---VALIDAR QUE LA ÚLTIMA FACTURA ESTA PAGADA----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_V3_FACTURA` AS (
  SELECT *
  FROM `COMISIONES.facturacion_linea_mes_phone_nm` BILLING
  LEFT JOIN  `mm-commissions-reporting.TEMP.cald_billing_status` STATUS
    ON BILLING.invoice_id =status.invoice_no
  WHERE BILLING.mes_facturado = '2024-04-01' ---- CAMBIAR -1 MES 
  AND STATUS.status IN ('PAID','RECOLLECTED')

) 

 ; 

---CONSUMO MEDIO DE LOS CLIENTES ULTIMOS 6 MESES---- 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_V3_PROM_FACT` AS (
  SELECT marca, service_id, service_type,phone_nm, sum(importe_facturado)/6 as importe_medio
  FROM `COMISIONES.facturacion_linea_mes_phone_nm` BILLING
  WHERE BILLING.mes_facturado BETWEEN '2023-11-01' AND '2024-05-01'
  GROUP BY 1,2,3,4
) 
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_EXCLUSIVO`  AS (
  SELECT

      TRANSACCIONES.agrupacion_canal
      ,TRANSACCIONES.canal
      ,TRANSACCIONES.concepto
      ,TRANSACCIONES.tipo_concepto
      ,TRANSACCIONES.unidades
      ,TRANSACCIONES.comision
      ,TRANSACCIONES.id_comisionista
      ,TRANSACCIONES.distribuidor
      ,TRANSACCIONES.seller
      ,TRANSACCIONES.marca
      ,TRANSACCIONES.service_type 
      ,TRANSACCIONES.phone_nm
      ,TRANSACCIONES.tariff_id
      ,TRANSACCIONES.tariff_ds
      ,TRANSACCIONES.service_id
      ,TRANSACCIONES.account_id
      ,TRANSACCIONES.customer_id
      ,TRANSACCIONES.line_type_ds
      ,TRANSACCIONES.bundle_type
      ,TRANSACCIONES.technology_ds
      ,TRANSACCIONES.billing_type_ds
      ,TRANSACCIONES.sale_date
      ,TRANSACCIONES.activation_date
      ,TRANSACCIONES.deactivation_date
      ,TRANSACCIONES.order_id
      ,TRANSACCIONES.order_type_agg
      ,TRANSACCIONES.cod_segmento
      ,TRANSACCIONES.cod_marca
      ,TRANSACCIONES.cod_tipo_contrato
      ,TRANSACCIONES.cod_producto
      ,TRANSACCIONES.cod_canal
      ,TRANSACCIONES.facturador
      ,TRANSACCIONES.sociedad

  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

--  LEFT JOIN `mm-commissions-reporting.COMISIONES.v_ventas_comisiones` VENTAS 
    -- ON TRANSACCIONES.phone_nm = VENTAS.phone_nm AND TRANSACCIONES.account_id = VENTAS.account_id

  WHERE TRANSACCIONES.agrupacion_canal in ('Exclusivo')
    AND TRANSACCIONES.concepto IN ('A - Servicio Movil Pospago', 'C - Calidad 6 meses', 'C - Calidad 12 meses', 'C - Calidad 24 meses','C - Calidad 36 meses')
--    AND VENTAS.deactivation_date = '9999-12-31'
    AND ( (TRANSACCIONES.concepto = 'A - Servicio Movil Pospago' AND TRANSACCIONES.id_mes = 202311)  --AND TRANSACCIONES.ACTIVATION_DATE BETWEEN '2023-11-01' AND '2023-11-30')
      OR  (TRANSACCIONES.concepto = 'C - Calidad 6 meses'        AND TRANSACCIONES.id_mes = 202305) --AND TRANSACCIONES.ACTIVATION_DATE BETWEEN '2023-05-01' AND '2023-05-31')
      OR  (TRANSACCIONES.concepto = 'C - Calidad 12 meses'       AND TRANSACCIONES.id_mes = 202305) --AND TRANSACCIONES.ACTIVATION_DATE BETWEEN '2022-05-01' AND '2022-05-31')
      OR  (TRANSACCIONES.concepto = 'C - Calidad 24 meses'       AND TRANSACCIONES.id_mes = 202305) --AND TRANSACCIONES.ACTIVATION_DATE BETWEEN '2021-05-01' AND '2021-05-31')
      OR  (TRANSACCIONES.concepto = 'C - Calidad 36 meses'       AND TRANSACCIONES.id_mes = 202305) --AND TRANSACCIONES.ACTIVATION_DATE BETWEEN '2020-05-01' AND '2020-05-31')
    )
    AND TRANSACCIONES.estado = 'facturado'
    AND TRANSACCIONES.comision > 0
    AND TRANSACCIONES.canal !='DBL'
    -- AND TRANSACCIONES.phone_nm not in (
    --       select distinct phone_nm
    --       from `mm-commissions-reporting.COMISIONES.transacciones` c
    --       where c.id_mes > 202401 and c.agrupacion_canal in ('Exclusivo') and c.concepto IN ('A - Servicio Movil Pospago', 'C - Calidad 6 meses', 'C - Calidad 12 meses', 'C - Calidad 24 meses','C - Calidad 36 meses') and comision > 0 
    --       )
GROUP BY 1,	2,	3,	4,	5,	6,	7,	8,	9,	10,	11,	12,	13,	14,	15,	16,	17,	18,	19,	20,	21,	22,	23,	24,	25,	26,	27,	28,	29,	30,	31,	32,33

);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CALIDAD_FINAL_EXCLUSIVO` AS (
SELECT 
      
    prefijo ||'_EXC'|| mes_string || '_' || A.canal || '_' || ROW_NUMBER() OVER() AS commission_id
    ,'calculado' AS estado
    ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
    ,id_mes_pr AS id_mes
    ,A.agrupacion_canal
    ,A.canal
    ,CASE 
      WHEN A.concepto = 'A - Servicio Movil Pospago' THEN 'C - Calidad 6 meses' 
      WHEN A.concepto = 'C - Calidad 6 meses' THEN 'C - Calidad 12 meses' 
      WHEN A.concepto = 'C - Calidad 12 meses' THEN 'C - Calidad 24 meses' 
      WHEN A.concepto = 'C - Calidad 24 meses' THEN 'C - Calidad 36 meses' 
      WHEN A.concepto = 'C - Calidad 36 meses' THEN 'C - Calidad 48 meses' 
    END AS concepto
    ,A.tipo_concepto
    ,A.unidades
    ,CASE 
      WHEN A.service_type = 'MOBILE' AND A.concepto in ('A - Servicio Movil Pospago','C - Calidad 6 meses') AND t.importe_medio >= 25 THEN 8 
      WHEN A.service_type = 'MOBILE' AND A.concepto in ('A - Servicio Movil Pospago','C - Calidad 6 meses') AND t.importe_medio >= 16 THEN 6
      WHEN A.service_type = 'MOBILE' AND A.concepto in ('A - Servicio Movil Pospago','C - Calidad 6 meses') AND t.importe_medio >= 8  THEN 3
      WHEN A.service_type = 'MOBILE' AND A.concepto in ('C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 12 meses') AND t.importe_medio >= 25 THEN 12
      WHEN A.service_type = 'MOBILE' AND A.concepto in ('C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 12 meses') AND t.importe_medio >= 16 THEN 10
      WHEN A.service_type = 'MOBILE' AND A.concepto in ('C - Calidad 24 meses','C - Calidad 36 meses','C - Calidad 12 meses') AND t.importe_medio >= 8  THEN 6 
    ELSE 0 END
    AS comision
    ,A.id_comisionista
    ,A.distribuidor
    ,D.sfid_id
    ,A.seller
    ,D.nombre_comercio
    ,D.razon_social
    ,D.cif
    ,D.zona_fiscal
    ,A.marca
    ,A.service_type 
    ,A.phone_nm
    ,A.tariff_id
    ,A.tariff_ds
    ,A.service_id
    ,A.account_id
    ,A.customer_id
    ,A.line_type_ds
    ,A.bundle_type
    ,A.technology_ds
    ,A.billing_type_ds
    ,A.sale_date
    ,A.activation_date
    ,A.deactivation_date
    ,A.order_id
    ,A.order_type_agg
    ,A.cod_segmento
    ,A.cod_marca
    ,A.cod_tipo_contrato
    ,A.cod_producto
    ,A.cod_canal
    ,CAST(NULL AS STRING)  AS campaign_code
    ,CAST(NULL AS STRING)  AS serial_number
    ,CAST(NULL AS FLOAT64) AS tax_base
    ,CAST(NULL AS STRING)  AS claim_code
    ,CAST(NULL AS STRING)  AS process_code
    ,'Calidad Exclusivo '||id_mes_pr AS comments
    ,A.facturador
    ,A.sociedad
    ,CURRENT_TIMESTAMP AS creado
  FROM `mm-commissions-reporting.TEMP.CALIDAD_EXCLUSIVO` A

  INNER JOIN `mm-commissions-reporting.COMISIONES.v_dealer` D 
  ON A.seller = D.sfid_id AND D.id_mes = id_mes_pr 

  
  LEFT JOIN `mm-commissions-reporting.TEMP.CALIDAD_V3_PROM_FACT` T 
  ON A.phone_nm = cast ( T.phone_nm AS STRING) AND A.service_id = T.service_id 


);

--- Insertar tabla final ----

--call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CALD_', mes_int, canales_pr , 'TEMP.CALIDAD_FINAL_EXCLUSIVO' , 'ACTUALIZAR')



END