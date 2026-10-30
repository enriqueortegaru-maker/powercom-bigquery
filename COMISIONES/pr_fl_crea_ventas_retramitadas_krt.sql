BEGIN

  --DECLARE ID_MES_PR INT64; SET ID_MES_PR=202609;  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.VENTAS_RETRAMITADAS_KRT` AS
  --DECLARE ID_MES_PR INT64; SET ID_MES_PR=202609;  
  WITH r AS (
    --- Ventas que retramita el grupo de cancelaciones 
    --- y se recuperan (activación) --- OPCIONAL
    SELECT 
      *,
      -- Número de servicios por service_type
      COUNT(DISTINCT phone_nm) OVER(
        PARTITION BY data_source_ds, brand_ds, hash_document_number, customer_id, service_type
      ) AS nm_st,
      -- Índice de producto por service_type
      ROW_NUMBER() OVER(
        PARTITION BY data_source_ds, brand_ds, hash_document_number, customer_id, service_type 
        ORDER BY COALESCE(deactivation_date, '2099-12-31') DESC, service_id ASC
      ) AS ind_st
    FROM `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_MAS_BAJAS_KRT`
    WHERE subchannel_ds = "CANCELACIONES"
      AND data_source_ds = "MYSIM"
      AND brand_ds IN ("EUSKALTEL", "R", "TELECABLE", "RACC", "SIMPLE")
      AND activation_date IS NOT NULL
      --AND customer_id = "21009448"
  ),

  v AS (
    --- Ventas por canales normales cruzadas contra claves existentes en r
    SELECT 
      v.*,
      -- Número de servicios por service_type
      COUNT(DISTINCT v.phone_nm) OVER(
        PARTITION BY v.data_source_ds, v.brand_ds, v.hash_document_number, v.customer_id, v.service_type
      ) AS nm_st
    FROM `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_MAS_BAJAS_KRT` v
    WHERE v.data_source_ds = "MYSIM"
      AND v.cancellation_day_id IS NOT NULL
      AND v.subchannel_ds != "CANCELACIONES"
      --AND v.customer_id = "21009448"
      AND EXISTS (
        SELECT 1 
        FROM r
        WHERE r.data_source_ds = v.data_source_ds
          AND r.brand_ds = v.brand_ds
          AND r.customer_id = v.customer_id
          AND r.service_type = v.service_type
          AND r.hash_document_number = v.hash_document_number
      )
  )

  SELECT 
    CAST("retramita" AS STRING) comisionamiento,
    r.marca,
    r.brand_ds,
    r.service_id,
    r.account_id,
    r.customer_id,
    r.service_type,
    r.line_type_ds,
    r.bundle_type,
    r.technology_ds,
    r.billing_type_ds,
    r.phone_nm,
    v.sale_date,
    r.activation_date,
    r.deactivation_date,
    r.order_id,
    r.order_type_agg,
    r.port_in_operator_ds,
    r.tariff_id,
    r.tariff_ds,
    r.cod_segmento,
    r.cod_marca,
    r.cod_tipo_contrato,
    r.cod_producto,
    v.cod_canal,
    r.agrupacion_canal,
    v.sfid_id,
    v.seller,
    v.channel_ds,
    r.order_fix_id,
    r.claim_code,
    r.comments,
    r.contract_id,
    r.data_source_ds,
    r.portability_group_donor,
    r.portability_operator_donor,
    r.flag_order,
    r.segment_ds,
    v.user_store,
    v.subchannel_ds,
    r.cancellation_day_id,
    v.sell_type,
    r.province,
    r.zip_code,
    r.terminal_model,
    r.sva_tv,
    r.channel_segment_ds,
    r.master_channel_ds,
    r.channel_type_ds,
    r.hash_document_number,
    r.cancellation_reason_agg,
    r.cancellation_subreason_agg,
    r.max_appointment_date,
    r.billing_tier,
    r.qvantel_service_id,
    r.post_pre_flag,
    r.deactivation_reason_ds,
    r.sub_segment_ds,
    r.sociedad,
    r.id_mes_activacion,
    r.id_mes_desactivacion,
    r.seller_formato_tms
  FROM r 
  INNER JOIN v 
    ON v.data_source_ds = r.data_source_ds
  AND v.brand_ds = r.brand_ds 
  AND v.customer_id = r.customer_id   
  AND v.service_type = r.service_type 
  AND v.hash_document_number = r.hash_document_number 
  AND (v.service_type != "MOBILE" OR v.nm_st <= 1 OR v.phone_nm = r.phone_nm)

  QUALIFY 
    (r.service_type NOT IN ("TV", "NETFLIX", "AMAZON", "DISNEY") 
    AND ROW_NUMBER() OVER(PARTITION BY r.data_source_ds, r.brand_ds, r.customer_id, r.service_type, r.service_id ORDER BY r.sale_date ASC) = 1)
    OR 
    (r.service_type IN ("TV", "NETFLIX", "AMAZON", "DISNEY") 
    AND ROW_NUMBER() OVER(PARTITION BY r.data_source_ds, r.brand_ds, r.customer_id, r.service_type ORDER BY r.ind_st DESC) = 1)

  ORDER BY r.data_source_ds, r.brand_ds, r.hash_document_number, r.customer_id, r.service_type, r.ind_st ASC;


  INSERT INTO `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_MAS_BAJAS_KRT`
  SELECT r.* 
  FROM `mm-commissions-reporting.COMISIONES.VENTAS_RETRAMITADAS_KRT` r
  WHERE NOT EXISTS (
    select 1
    from `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_MAS_BAJAS_KRT` v
    where v.data_source_ds=r.data_source_ds and v.brand_ds=r.brand_ds and v.channel_ds=r.channel_ds  and v.subchannel_ds=r.subchannel_ds and v.customer_id=r.customer_id and v.service_id=r.service_id
  );


  INSERT INTO `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT`
  SELECT r.* 
  FROM `mm-commissions-reporting.COMISIONES.VENTAS_RETRAMITADAS_KRT` r
  WHERE NOT EXISTS (
    select 1
    from `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT` v
    where v.data_source_ds=r.data_source_ds and v.brand_ds=r.brand_ds and v.channel_ds=r.channel_ds  and v.subchannel_ds=r.subchannel_ds and v.customer_id=r.customer_id and v.service_id=r.service_id
  );


END