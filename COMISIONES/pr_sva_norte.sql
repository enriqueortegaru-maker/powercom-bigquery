BEGIN

---------------------------------------------------------
-- Procedimiento que calcula los SVA norte de FFCC
-- Se ejecuta desde el Google Sheet Multibrand. Link: https://docs.google.com/spreadsheets/d/1lkBnHWHxkS7eSueKrBxrRFvNmAmrVIybAVmiH8RzRDw/edit?usp=sharing
---------------------------------------------------------

-- CALL `mm-commissions-reporting.COMISIONES.pr_sva_norte`();

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.sva_norte` AS

  SELECT 
    sfid_id                                                      AS SFID,
    'C_SVA'                                                      AS IDConcepto,
    DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH) AS FechaCompensacion,
    CAST(tar.COMISION AS FLOAT64)                                AS Value,
    'LGARCIAZ'                                                   AS UsuarioCarga,
    'LGARCIAZ'                                                   AS UsuarioAjuste,
    COALESCE(ven.brand_ds, cus.brand_ds)                         AS Marca,
    'EMPRESA'                                                    AS Mercado,
    contract_type_ds                                             AS Contrato,
    service_type                                                 AS Tecnologia,
    ven.phone_nm                                                 AS MSISDN,
    CAST(NULL AS STRING)                                         AS IMEI,
    rel.dyn_service_id                                           AS NumPedido,
    sva.CONTRACT_ID                                              AS CodContrato,
    PRODUCT                                                      AS Comentario,
    'ALL'                                                        AS PEP,
    'EXCLUSIVO'                                                  AS Canal,
    'COM_EXT'                                                    AS IDEventoContexto,
    CAST(NULL AS STRING)                                         AS NumeroReclamacion,
    CAST(NULL AS STRING)                                         AS ReclamacionCasoID,
    CAST(NULL AS STRING)                                         AS NOTASADV,
    'M'                                                          AS TIPO,
    DOCUMENT                                                     AS IDFiscalCliente,
    CAST(NULL AS STRING)                                         AS PROCEDE,
    CAST(NULL AS STRING)                                         AS CAUSARAIZ,
    CAST(NULL AS STRING)                                         AS FechaActoComercial,
    'FIN DE PLANTILLA'                                           AS INFO,
    rel.* EXCEPT(activation_date,deactivation_date),
    CAST(rel.activation_date AS DATE)                            AS activation_date_serv,
    CAST(rel.deactivation_date AS DATE)                          AS deactivation_date_serv,
    prod.*,
    ven.* EXCEPT(order_date,activation_date,deactivation_date),
    CAST(ven.order_date AS DATE)                            AS order_date_ventas,
    CAST(ven.activation_date AS DATE)                            AS activation_date_ventas,
    CAST(ven.deactivation_date AS DATE)                          AS deactivation_date_ventas,
    cus.* EXCEPT(datasource_id,datasource_ds,brand_id,brand_ds,segment_ds,sub_segment_ds,customer_id,document_hash,phone_nm,insert_dt,update_dt),
    cus.datasource_id                                            AS datasource_id_customer,
    cus.datasource_ds                                            AS datasource_ds_customer,
    cus.brand_id                                                 AS brand_id_customer,
    cus.brand_ds                                                 AS brand_ds_customer,
    cus.segment_ds                                               AS segment_ds_customer,
    cus.sub_segment_ds                                           AS sub_segment_ds_customer,
    cus.customer_id                                              AS customer_id_customer,
    cus.document_hash                                            AS document_hash_customer,
    cus.phone_nm                                                 AS phone_nm_customer,
    tar.* EXCEPT(canal,marca,product_id),
    tar.canal                                                    AS canal_tarifas,
    tar.marca                                                    AS marca_tarifas,
    tar.product_id                                               AS product_id_tarifas
  FROM `mm-datamart-kd.SVA.osp_fc_sva_serv_add_stat` sva
  JOIN `mm-datamart-kd.SERVICES.tr_serv_dwh_dynamics` rel ON sva.SERVICE_KEY = rel.dwh_service_id
  JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_prod` prod ON sva.PRODUCT_KEY = prod.PRODUCT_KEY
  LEFT JOIN `mm-datamart-kd.SERVICES.ventas_base_telco_dynamics` ven ON ven.service_id = rel.dyn_service_id
  -- 1. Primero cruzamos con clientes para tener 'cus.brand_ds' disponible
  LEFT JOIN `mm-datamart-kd.PERSONAL_INFO.customer_dynamics` cus ON CAST(rel.dyn_customer_id AS STRING) = cus.customer_id
  -- 2. Ahora cruzamos las comisiones evaluando ambas marcas con COALESCE
  LEFT JOIN `mm-commissions-reporting.GS.SVA_TARIFAS_D2D` tar ON COALESCE(ven.brand_ds, cus.brand_ds) = tar.MARCA 
    AND prod.PRODUCT_ID = tar.PRODUCT_ID
  WHERE TRUE
    AND prod.PRODUCT_ID IN ('2117', '2073', '2071', '1614', '1613', '1612', '1611')
    AND service_status_ds ='Activo'
    AND SFID_KEY != -1
    AND DATE(SERVICE_ADD_STAT_INI_DT) BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
    AND LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
    --  and ven.phone_nm  ='620915415'
  GROUP BY ALL
;

END