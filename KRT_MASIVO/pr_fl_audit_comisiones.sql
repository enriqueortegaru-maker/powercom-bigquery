BEGIN

  ---=============================================================================
  --- AUDITORIA ACTIVACIONES Y DESACTIVACIONES FRENTE A COMISIONES
  ---=============================================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.COMISIONES_AUDIT`
  OPTIONS (
    expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  )
  AS
  WITH fuente AS (
    SELECT 'COMISION'   AS tipo_origen, * FROM `mm-commissions-reporting.COMISIONES.ACTIVACIONES_KRT`    WHERE data_source_ds="MYSIM" and segment_ds not in("BUSINESS") and id_mes = vmes_id and id_mes_desactivacion is null
    UNION ALL
    SELECT 'DECOMISION' AS tipo_origen, * FROM `mm-commissions-reporting.COMISIONES.DESACTIVACIONES_KRT` WHERE data_source_ds="MYSIM" and segment_ds not in("BUSINESS") and id_mes = vmes_id  and id_mes_desactivacion!=id_mes_activacion
  )
  SELECT
    --CURRENT_TIMESTAMP() AS audit_ts,
    distinct f.*
  FROM fuente f
  WHERE NOT EXISTS (
    SELECT 1
    FROM `mm-commissions-reporting.KRT_MASIVO.HISTORICO_TOTAL` c
    WHERE c.mes_id     =vmes_id
      AND c.mes_id     =f.id_mes
      AND c.brand_ds   =f.brand_ds
      AND c.data_source_ds= f.data_source_ds
      AND c.channel_ds = f.channel_ds 
      AND c.segment_ds=f.segment_ds
      AND c.customer_id = f.customer_id
      AND c.service_type  = f.service_type
      AND c.service_id  = f.service_id
      AND c.clase = f.tipo_origen  
  );





END