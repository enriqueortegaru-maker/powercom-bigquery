BEGIN


DECLARE prefijo, mes_string STRING;
DECLARE mes_periodo_facturado DATE;
DECLARE id_mes_periodo_facturado INT64;


SET prefijo = 'CARTA';

SET mes_string = CAST(id_mes_pr AS STRING);

SET mes_periodo_facturado = DATE_ADD(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL  - 1 MONTH );

SET id_mes_periodo_facturado = CAST(FORMAT_DATE('%Y%m', mes_periodo_facturado) AS INT64);


/*
CALL COMISIONES.pr_cartera_alternativo_by(202511);
*/


-- TABLA TEMPORAL CON SFIDS QUE HAN MIGRADO A ALTERNATIVO ÚNICAMENTE

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cart_billing_alt_by` AS

SELECT *
FROM `mm-commissions-reporting.TEMP.cartx_billing`
WHERE seller IN ('LB110100','LB106900','LB139740')
;

-- CÁLCULO CARTERA 3% 

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cartera_alternativo_by` AS

SELECT *
FROM (
     SELECT 
           prefijo || '_' || mes_string || '_' || COALESCE(IFS_RET.canal, DEALER.canal) || '_' || ROW_NUMBER() OVER () AS commission_id
          ,'calculado' AS estado
          ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
          ,CAST(mes_string AS INT64) AS id_mes
          ,'No Exclusivo'AS agrupacion_canal
          ,'ALTN' AS canal
          ,CONCEPTOS.concepto
          ,CONCEPTOS.tipo_concepto
          ,1 as unidades
     
          ,CASE
               -- WHEN CONCEPTOS.concepto = 'C - Cartera 4%'                                       THEN importe_facturado * 0.04
               WHEN CONCEPTOS.concepto = 'C - Cartera 3%'                                       THEN importe_facturado * 0.03
               -- WHEN CONCEPTOS.concepto = 'C - Cartera' AND BILLING.billing_type_ds = 'POSTPAID' THEN importe_facturado * 0.040002
               -- WHEN CONCEPTOS.concepto = 'C - Cartera' AND BILLING.billing_type_ds = 'PREPAID'  THEN importe_facturado * 0.00
           END AS comision
     
          ,CASE
               WHEN BILLING.seller = 'LB110100' THEN 'MI100089'
               WHEN BILLING.seller = 'LB106900' THEN 'MI060170'
               WHEN BILLING.seller = 'LB139740' THEN 'MI390083'
           END AS id_comisionista

          ,COALESCE(IFS_RET.distribuidor, 'BYMOVIL') AS distribuidor -- 20250811 Johanna: Agrego BYMOVIL como distribuidor hardcodeado porque no viene en la GS SELLERS

          ,CASE
               WHEN BILLING.seller = 'LB110100' THEN 'MI100089'
               WHEN BILLING.seller = 'LB106900' THEN 'MI060170'
               WHEN BILLING.seller = 'LB139740' THEN 'MI390083'
           END AS sfid_id 

          ,COALESCE(IFS_RET.seller, DEALER.id_comisionista) AS seller -- 20250811 Johanna: Cambio BILLING.seller por DEALER.id_comisionista

          ,CASE
               WHEN BILLING.seller = 'LB110100' THEN 'EXTREPHONE SAT'
               WHEN BILLING.seller = 'LB106900' THEN 'MARIAMOBILE'
               WHEN BILLING.seller = 'LB139740' THEN 'PHONE FAMILY'
           END AS nombre_comercio

          ,CASE
               WHEN BILLING.seller = 'LB110100' THEN 'EXTREPHONE SAT ESPJ'
               WHEN BILLING.seller = 'LB106900' THEN 'MARIA OLIVAS COLCHON'
               WHEN BILLING.seller = 'LB139740' THEN 'CELAYA ARBIZU USUE'
           END AS razon_social

          ,CASE
               WHEN BILLING.seller = 'LB110100' THEN 'E19432368'
               WHEN BILLING.seller = 'LB106900' THEN '07256719N'
               WHEN BILLING.seller = 'LB139740' THEN '78944513A'
           END AS cif
           
          ,COALESCE(IFS_RET.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
          ,BILLING.marca
          ,BILLING.service_type
          ,BILLING.phone_nm
          ,BILLING.tariff_id
          ,BILLING.tariff_ds
          ,BILLING.service_id
          ,BILLING.account_id
          ,BILLING.customer_id
          ,BILLING.line_type_ds
          ,BILLING.bundle_type
          ,BILLING.technology_ds
          ,BILLING.billing_type_ds
          ,BILLING.sale_date

          ,CASE WHEN BILLING.activation_date = '9999-12-31' THEN BILLING.sale_date ELSE BILLING.activation_date END AS activation_date

          ,BILLING.deactivation_date
          ,BILLING.order_id
          ,BILLING.order_type_agg
          ,BILLING.cod_segmento
          ,BILLING.cod_marca
          ,BILLING.cod_tipo_contrato
          ,BILLING.cod_producto
          ,'29' AS cod_canal
          ,CAST(NULL AS STRING)  AS campaign_code
          ,CAST(NULL AS STRING)  AS serial_number
          ,CAST(NULL AS FLOAT64) AS tax_base
          ,CAST(NULL AS STRING)  AS claim_code
          ,CAST(NULL AS STRING)  AS process_code
          ,CAST(NULL AS STRING)  AS comments
          ,'C_MANUAL' AS facturador
     
     FROM (
          (
          SELECT *
          FROM `mm-commissions-reporting.TEMP.cart_billing_alt_by`
          WHERE data_source_ds IN ('MYSIM', 'QVANTEL')
          QUALIFY RANK() OVER (
                              PARTITION BY phone_nm, marca, service_type
                              ORDER BY CASE
                                           WHEN data_source_ds = 'MYSIM' THEN 1
                                           WHEN data_source_ds = 'QVANTEL' THEN 2
                                       END ASC
                              ) = 1
          )
          UNION ALL
          SELECT * FROM `mm-commissions-reporting.TEMP.cart_billing_alt_by` WHERE data_source_ds IN ('HEOS')
          ) BILLING
     
        LEFT JOIN `mm-commissions-reporting.GS.exclusivo_dealers` DEALER
                  ON (
                        CASE WHEN BILLING.sfid_id != 'LB' THEN 
                                                              (
                                                                BILLING.sfid_id = DEALER.id_comisionista 
                                                              OR 
                                                                BILLING.seller = DEALER.id_comisionista 
                                                              )
                             ELSE BILLING.seller = DEALER.id_comisionista 
                        END
                     )
                  AND BILLING.agrupacion_canal = 'Exclusivo'

--      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
--                   ON (
--                         CASE WHEN BILLING.sfid_id != 'LB' THEN 
--                                                       (BILLING.sfid_id = DEALER.sfid_id 
--                                                       OR BILLING.seller = DEALER.sfid_id)
--                         ELSE BILLING.seller = DEALER.sfid_id
--                         END
--                      ) -- 20250411 JOHANNA: CASE PARA CORREGIR ZONAS FISCALES ERRÓNEAS POR BILLING.SFID_ID = LB
            --   ON (
            --      BILLING.sfid_id = DEALER.sfid_id 
            --      OR BILLING.seller = DEALER.sfid_id
            --      )
            --      AND BILLING.agrupacion_canal = DEALER.agrupacion_canal
     
     LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
               ON CONCEPTOS.id_prefijo = 'CAREX'
                  AND CASE
                         --  WHEN DEALER.canal IN ('EYG')                                          THEN 'Cartera'
                         --  WHEN DEALER.canal IN ('ENK') AND DEALER.canal_procedencia IN ('EYG')  THEN 'Cartera' 
                         --  WHEN DEALER.canal IN ('ENK')                                          THEN 'Cartera 4%' -- A PARTIR DE LIQUI AGOSTO 2025
                          WHEN DEALER.canal IN ('EML','ENX','ENK')                                    THEN 'Cartera 3%'                           
                      END = SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) -- 20250424 JOHANNA: CAMBIO EL ELSE POR WHEN 'EYG' PARA QUE NO CALCULE CARTERA POSTPAGO A ENX -- 20250507 AGREGO ENX PARA CÁLCULO CARTERA 3%
     
     LEFT JOIN (
               SELECT phone_nm
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE id_mes <= 202309 AND agrupacion_canal = 'Exclusivo' AND canal = 'EYG' AND concepto = 'C - Cartera' AND activation_date < '2022-01-01'
               GROUP BY 1
               ) IFS
              ON BILLING.phone_nm = IFS.phone_nm AND BILLING.activation_date < '2023-10-01'
     
     LEFT JOIN (
               SELECT *
               FROM `mm-commissions-reporting.COMISIONES.transacciones`
               WHERE id_mes = 202309 AND agrupacion_canal = 'Exclusivo' AND canal = 'EYG' AND concepto = 'C - Cartera'
               ) IFS_RET
              ON BILLING.phone_nm = IFS_RET.phone_nm AND BILLING.marca = IFS_RET.marca AND BILLING.agrupacion_canal = 'No aplica'
     
     -- LEFT JOIN `mm-commissions-reporting.GS.BAJACARTERA` BLACKLIST
     --          ON COALESCE(IFS_RET.seller, DEALER.id_comisionista) = BLACKLIST.sfid AND BLACKLIST.pagar = 'NO'
     
     WHERE BILLING.status IN ('PAID', 'RECOLLECTED')
           AND BILLING.importe_facturado > 0
          --  AND BLACKLIST.sfid IS NULL
           AND DEALER.id_comisionista NOT LIKE 'DBL%'
           AND (
               --  (
               --  BILLING.service_type IN ('MOBILE')
               --  AND  (
               --         COALESCE(IFS_RET.canal, DEALER.canal) IN ('EYG') 
               --         OR
               --         (DEALER.canal = 'ENK' AND DEALER.canal_procedencia = 'EYG' AND DEALER.fecha_firma >= 202508)
               --       ) 
               --  AND BILLING.marca = 'YOIGO'
               --  AND (BILLING.billing_type_ds = 'POSTPAID' AND BILLING.importe_facturado >= 6.00)
               --  AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera'
               --  ) -- C - Cartera -- 1
               -- OR
          --       (
          --       BILLING.service_type IN ('MOBILE')
          --       AND COALESCE(IFS_RET.canal, DEALER.canal_procedencia) IN ('EYG')
          --   --     AND DEALER.canal = 'ENK'
          --       AND DEALER.fecha_firma = 202507
          --       AND BILLING.marca = 'YOIGO'
          --       AND DATE_TRUNC(BILLING.activation_date, MONTH) < DATE('2025-07-01')
          --       AND (BILLING.billing_type_ds = 'POSTPAID' AND BILLING.importe_facturado >= 6.00)
          --       AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera'
          --       ) -- C - Cartera -- 4 residual
          --      OR
                (
                BILLING.billing_type_ds = 'POSTPAID'
               --  AND COALESCE(IFS_RET.canal, DEALER.canal) IN ('EML','ENX') 
                AND DATE_TRUNC(BILLING.activation_date, MONTH) >= DATE('2023-01-01')
                AND BILLING.marca IN ('GUUK', 'LLAMAYA', 'MASMOVIL', 'PEPEPHONE', 'YOIGO')
                AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera 3%'
                ) -- C - Cartera 3% -- 2, 3
               -- OR
               --  (
               --  BILLING.billing_type_ds = 'POSTPAID'
               --  AND COALESCE(IFS_RET.canal, DEALER.canal_procedencia) IN ('EML','ENX') 
               --  AND DEALER.canal = 'ENK'
               --  AND DATE_TRUNC(BILLING.activation_date, MONTH) BETWEEN DATE('2023-01-01') AND DATE('2025-06-01')
               --  AND BILLING.marca IN ('GUUK', 'LLAMAYA', 'MASMOVIL', 'PEPEPHONE', 'YOIGO')
               --  AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera 4%'
               --  ) -- C - Cartera 3% QUE PASA A 4% A PARTIR DEL 01/07 -- 5, 6
               -- OR
               --  (
               --  BILLING.billing_type_ds = 'POSTPAID'
               --  AND COALESCE(IFS_RET.canal, DEALER.canal) IN ('ENK') 
               --  AND DATE_TRUNC(BILLING.activation_date, MONTH) >= DATE('2025-07-01')
               --  AND BILLING.marca IN ('GUUK', 'LLAMAYA', 'MASMOVIL', 'PEPEPHONE', 'YOIGO')
               --  AND SUBSTR(CONCEPTOS.concepto, 5, LENGTH(CONCEPTOS.concepto)) = 'Cartera 4%'
               --  ) -- C - Cartera 4% -- 4, 5, 6
               )
           --AND NOT (BILLING.activation_date < '2023-10-01' AND COALESCE(IFS_RET.canal, DEALER.canal) = 'EYG' AND IFS.phone_nm IS NULL)
     
     QUALIFY RANK() OVER (PARTITION BY service_id, phone_nm, marca, service_type, concepto, CAST(comision AS STRING) ORDER BY LENGTH(id_comisionista) DESC) = 1
     )
     
WHERE COALESCE(comision, 0.0) > 0.0
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`(prefijo, id_mes_pr, ['ALTN'], 'TEMP.cartera_alternativo_by', 'ACTUALIZAR');

END