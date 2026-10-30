BEGIN

--CALL `mm-commissions-reporting.COMISIONES.pr_autofactura_sap_norte`('2026-08-01')

  -- ============================================================
  -- 1. ASSERTS
  -- ============================================================

  --Assert de unicidad, se usa para comprobar que a cada commission_id corresponde un solo invoice_id, relacion de 1:1
  ASSERT (
  SELECT COUNT(*) = 0
  FROM (
    SELECT
      commission_id_apunte,
      mes_factura_dt,
      COUNT(DISTINCT invoice_id) AS num_invoice_ids
    FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`,
    UNNEST(commission_id) AS commission_id_apunte
    WHERE mes_factura_dt = id_mes_pr
    GROUP BY
      commission_id_apunte,
      mes_factura_dt
    HAVING COUNT(DISTINCT invoice_id) > 1
  )
  ) AS 'ERROR: un commission_id tiene mas de un invoice_id';

  -- ============================================================
  -- 2. UPDATE
  -- ============================================================

  --Update para actualizar el invoice_id de KRT_SAP.TRANSACCIONES con los valores de KRT_SAP.SAP_FACTURA_APUNTES por comission_id
  MERGE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` AS trx
  USING (
    SELECT
      mes_factura_dt,
      commission_id_apunte,
      invoice_id
    FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`,
    UNNEST(commission_id) AS commission_id_apunte
    WHERE mes_factura_dt = id_mes_pr
  ) AS apt
  ON trx.commission_id = apt.commission_id_apunte
  AND trx.mes_factura_dt = apt.mes_factura_dt
  AND trx.invoice_id IS NULL

  WHEN MATCHED
    AND apt.invoice_id IS NOT NULL
    THEN
      UPDATE SET
        trx.invoice_id = apt.invoice_id;

END