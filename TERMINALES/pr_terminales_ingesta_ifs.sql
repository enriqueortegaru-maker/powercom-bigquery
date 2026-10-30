BEGIN

  insert into `mm-commissions-reporting.TERMINALES.TERMINALES`(

    select
    claim_code_pr||'_'||COALESCE(CAST(reporting_id_pr AS INT64),ID_MES_PR)||'_INGESTA'||'_'||'IFS'||'_'||transaction_id||'_'||row_number () over () AS commission_id,
    'calculado' as estado,	
    date((substr((cast(id_mes_pr as string)),1,4)||'-'||substr((cast(id_mes_pr as string)),5,2)||'-'||'01')) AS mes_liquidado,	
    COALESCE(CAST(reporting_id_pr AS INT64),ID_MES_PR) as id_mes,	
    agrupacion_canal,	
    canal,	
    concepto,	
    tipo_concepto,	
    unidades,	
    comision,	
    sfid_id as id_comisionista,	
    canal as distribuidor,	
    SUBSTR(sfid_id,1,2) as sfid_id,	
    sfid_id,	
    case 
      when agrupacion_canal = 'Exclusivo' then 'BYMOVIL' 
      when agrupacion_canal = 'No Exclusivo' then 'PHONE HOUSE' 
          end nombre_comercio,	
    case 
      when agrupacion_canal = 'Exclusivo' then 'THE BYMOVIL SPAIN, S.L.U.' 
      when agrupacion_canal = 'No Exclusivo' then 'THE PHONE HOUSE SPAIN, S.L.U.' 
          end razon_social,	
    case 
      when agrupacion_canal = 'Exclusivo' then 'B39688197' 
      when agrupacion_canal = 'No Exclusivo' then 'B81846206' 
          end cif,	
    REGION_CODE AS zona_fiscal,	
    marca,	
    'MOBILE' AS service_type,	
    phone_nm,	
    tariff_id,	
    tariff_ds,	
    service_id,	
    account_id,	
    customer_id,	
    cast(null as string) as line_type_ds,	
    bundle_type,	
    cast(null as string) as technology_ds,	
    billing_type_ds,	
        CAST((SUBSTR(SALES_DATE,1,10)) AS DATE) AS sale_date,	
    activation_date,	
    deactivation_date,	
    order_id,	
    order_type_agg,	
    cod_segmento,	
    cod_marca,	
    cod_tipo_contrato,	
    cod_producto,	
    cod_canal,	
    claim_code,	
    cast(null as string) AS campaign_code,	
    'INGESTA_2023_IFS' as process_code,	
    ADDON8 as comments,
    facturador,	
    cast(null as string) as proceso_sap,	
    cast(null as string) as id_registro,	
    cast(null as string) as invoice_id,	
    'X001' as sociedad,	
    cast(null as string) as bp,	
    cuenta_contable_ifs AS cuenta_contable,	
    CECO_ifs AS centro_coste,	
    cast(null as string) as documento_sap,	
    cast(null as string) as documento_sap_posicion,	
    cast(null as string) as fecha_contabilizacion,	
    CURRENT_TIMESTAMP() as creado,	
    CURRENT_TIMESTAMP() as modificado,	
    cast(null as string) as id_factura_drive,	
    [''] as emails_acceso_trazabilidad,
    IMEI AS IMEI,	
    DUPLICATED_IMEI, 
    AFTER_SALE,
    MODEL_ID AS PRODUCT_CODE,	
    MODEL_NAME AS TERMINAL_NAME,	
    CONTRACT_ID,
    CAST(PURCH_PRICE AS FLOAT64) AS PURCH_PRICE,
    CAST(NET_SUBSIDY AS FLOAT64) AS NET_SUBSIDY,
    CAST(END_USER_PRICE AS FLOAT64) AS END_USER_PRICE,
    cast(null as FLOAT64) AS COSTE_DEVICE,
    ADDON3 AS offer_segmentation

    from
    `mm-commissions-reporting.TERMINALES.v_ifs_terminales` 

    where
    simulation_code is null
    and (reporting_id = reporting_id_pr or claim_code = claim_code_pr)


  )
  ;

end