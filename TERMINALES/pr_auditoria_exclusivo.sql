BEGIN

--CALL `mm-commissions-reporting.TERMINALES.pr_auditoria_exclusivo`();

  --Tabla temporal para RAUL RUIZ CASAS
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.auditoria_exclusivo`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 45 DAY)) AS

  SELECT commission_id, estado, mes_liquidado, id_mes, agrupacion_canal, canal, concepto, tipo_concepto, unidades
    , ROUND(comision,2) AS comision, id_comisionista, distribuidor, sfid_id, seller, cif, zona_fiscal, marca
    , service_type, phone_nm, tariff_id, tariff_ds, service_id, account_id, customer_id, line_type_ds, bundle_type
    , technology_ds, billing_type_ds, sale_date, activation_date, deactivation_date, order_id, order_type_agg
    , cod_segmento, cod_marca, cod_tipo_contrato, cod_producto, cod_canal, tra.serial_number
    , ROUND(tax_base,2) AS tax_base, claim_code, comments, facturador
  FROM `mm-commissions-reporting.COMISIONES.transacciones` tra
  WHERE claim_code like 'Auditoria Exclusivo%'
    AND tra.id_mes >= 202601
    AND tra.tipo_concepto IN ('FINT','SRCI','SUTS','SUBS','UPFR','AIRT','TJTS')
    AND estado = 'facturado';

END