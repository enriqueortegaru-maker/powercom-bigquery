BEGIN 

  --call `mm-commissions-reporting.KRT_MASIVO.pr_fl_calcula_rappel`(202607);
  ---================================================================
  --- INVENTARIO DE VENTAS QUE CONTABILIZAN PARA OBJETIVO
  ---=================================================================

  --DECLARE VID_MES INT64;SET VID_MES=202608;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_LIST` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS 	
  select distinct v.brand_ds, v.customer_id, v.service_id, b.distribuidor.ds as distribuidor, v.channel_type_ds, v.channel_ds, v.subchannel_ds, b.mo.N0, b.mo.N1, b.mo.N2, c.grupo_rappel
  FROM `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT` v
  INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` b 
  ON b.marca_ds = v.brand_ds 
  AND (
          (v.brand_ds IN ("TELECABLE", "EUSKALTEL", "R","RACC", "SIMPLE", "VIRGIN") 
          AND (CAST(b.ct.sfid AS STRING) = v.sfid_id OR CAST(b.ct.sfid AS STRING) = v.user_store  OR b.mo.sfid = v.sfid_id OR b.mo.sfid = v.user_store))
          OR 
          (v.brand_ds = "R" AND CAST(b.agente.id AS STRING) = v.sfid_id)
  )
  LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_CANALES` c on c.brand_ds=v.brand_ds and c.N0=b.mo.N0 and c.N1=b.mo.N1 and c.N2=b.mo.N2 and c.distribuidor=b.distribuidor.ds
  where v.service_type="BROADBAND"
  and sell_type="NEW SALE"
  and data_source_ds="MYSIM"
  and CAST(CAST(FORMAT_DATE('%Y%m',v.sale_date) AS STRING) AS INT64)=vid_mes;
  

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_CONT`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
  SELECT S.brand_ds, S.distribuidor, S.N0, S.N1, S.N2, s.grupo_rappel, COUNT(distinct service_id) BAS 
  FROM  `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_LIST` S
  GROUP BY S.brand_ds,S.distribuidor,S.N0,S.N1,S.N2,s.grupo_rappel;



  ---================================================================
  --- NIVEL DE RAPPEL ALCANZADO (CRITERIO: PORCENTUAL)
  ---=================================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.RAPPEL_NIVEL_ALCANZADO` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS   

  --DECLARE VID_MES INT64;SET VID_MES=202608;
  WITH 

  ratio_marca as (
    --DECLARE VID_MES INT64;SET VID_MES=202608;  
    select marca_ds as brand_ds, lc.nlaborables, lt.nlaborables as nlaborablesTotal, coalesce(SAFE_DIVIDE(lt.nlaborables,lc.nlaborables),0) as ratio,
    --lc.marca_ds as brand_ds, tt.
    from `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesTranscurrido`(CAST(FORMAT_DATE("%Y%m%d", PARSE_DATE("%Y%m", CAST(vid_mes AS STRING))) AS INT64)) as lc 
    inner join `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesCompleto`(CAST(FORMAT_DATE("%Y%m%d", PARSE_DATE("%Y%m", CAST(vid_mes AS STRING))) AS INT64)) lt using(marca_ds)

  ),   

  ventas_porcentual_subcanal AS (
      SELECT a.brand_ds, a.distribuidor, a.N1, a.N2, a.N0, a.grupo_rappel,
             a.BAS, ROUND(a.BAS * rm.ratio) AS proyeccion, obj.objetivo,
             IFNULL((SAFE_DIVIDE(ROUND(a.BAS * rm.ratio), obj.objetivo)), 0) * 100 AS consecucion
      FROM `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_CONT` a
      INNER JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_RAPPEL_OBJETIVO` obj 
          ON a.brand_ds = obj.brand_ds
          AND UPPER(TRIM(a.distribuidor)) = UPPER(TRIM(obj.distribuidor)) 
          AND UPPER(TRIM(a.N1)) = UPPER(TRIM(obj.N1)) 
          AND UPPER(TRIM(a.N2)) = UPPER(TRIM(obj.N2))
      INNER JOIN ratio_marca rm on  rm.brand_ds=a.brand_ds
      WHERE UPPER(TRIM(obj.N2)) <> 'X'
  ),
  ventas_porcentual_canal AS (
      SELECT a.brand_ds, a.distribuidor, a.N1, a.N0,
             SUM(a.BAS) AS BAS, SUM(ROUND(a.BAS * rm.ratio)) AS proyeccion, MAX(obj.objetivo) as objetivo,
             IFNULL(SAFE_DIVIDE(SUM(ROUND(a.BAS * rm.ratio)), MAX(obj.objetivo)), 0) * 100 AS consecucion
      FROM `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_CONT` a
      INNER JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_RAPPEL_OBJETIVO` obj 
          ON a.brand_ds = obj.brand_ds 
          AND UPPER(TRIM(a.distribuidor)) = UPPER(TRIM(obj.distribuidor)) 
          AND UPPER(TRIM(a.N1)) = UPPER(TRIM(obj.N1))
      INNER JOIN ratio_marca rm on  rm.brand_ds=a.brand_ds          
      WHERE UPPER(TRIM(obj.N2)) = 'X'
      GROUP BY 1, 2, 3, 4
   ),
   rappel_porcentual_final AS (
      -- Resolución a nivel SUBCANAL
      SELECT vps.brand_ds, vps.distribuidor, vps.N1, vps.N2, vps.N0, vps.grupo_rappel, 
             vps.BAS, vps.proyeccion, vps.objetivo, vps.consecucion, np.nivel, 
             'porcentual' AS criterio_rappel
      FROM ventas_porcentual_subcanal vps
      LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_RAPPEL_TRAMO` np 
          ON vps.brand_ds = np.brand_ds AND vps.consecucion >= np.minimo AND vps.consecucion < np.maximo
      
      UNION ALL
      
      -- Resolución a nivel CANAL (Fallback con Anti-Join estricto)
      SELECT vpc.brand_ds, vpc.distribuidor, vpc.N1, rv.N2, vpc.N0, rv.grupo_rappel, 
             vpc.BAS, vpc.proyeccion, vpc.objetivo, vpc.consecucion, np.nivel, 
             'porcentual' AS criterio_rappel
      FROM ventas_porcentual_canal vpc
      INNER JOIN `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_CONT` rv 
          ON vpc.brand_ds = rv.brand_ds 
          AND UPPER(TRIM(vpc.distribuidor)) = UPPER(TRIM(rv.distribuidor)) 
          AND UPPER(TRIM(vpc.N1)) = UPPER(TRIM(rv.N1))
      LEFT JOIN ventas_porcentual_subcanal vps_check 
          ON vpc.brand_ds = vps_check.brand_ds 
          AND UPPER(TRIM(vpc.distribuidor)) = UPPER(TRIM(vps_check.distribuidor)) 
          AND UPPER(TRIM(rv.N1)) = UPPER(TRIM(vps_check.N1))
          AND UPPER(TRIM(rv.N2)) = UPPER(TRIM(vps_check.N2))
      LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_RAPPEL_TRAMO` np 
          ON vpc.brand_ds = np.brand_ds AND vpc.consecucion >= np.minimo AND vpc.consecucion < np.maximo
      WHERE vps_check.N2 IS NULL
  )

  SELECT DISTINCT 
      brand_ds, distribuidor, N1, N2, N0, grupo_rappel, 
      BAS, proyeccion, objetivo, consecucion, nivel, criterio_rappel
  FROM rappel_porcentual_final;



  ---==================================================================
  --- CALCULO DE IMPORTE DE RAPPEL TEORICO Y ALCANZADO (CRITERIO: PORCENTUAL)
  ---==================================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_CALCULADO`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS


  --DECLARE VID_MES INT64;SET VID_MES=202607;
  WITH base_filtrada AS (
      -- 1.1 Extraemos la base comisionable aplicando los filtros compartidos de 0402 y 0403
      SELECT 
          t.*,
          r.n1, r.n2, r.n3, r.n4, r.n5, r.n6, r.n7, r.n8, r.n9, r.n10, 
          r.n11, r.n12, r.n13, r.n14, r.n15, r.n16, r.n17, r.n18, r.n19, r.n20,
          CAST(a.nivel AS INT64) AS nivel_teorico,
          CAST(ra.nivel_asignado AS INT64) AS nivel_asignado
      FROM `mm-commissions-reporting.KRT_MASIVO.COMISIONES` t
      INNER JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_RAPPEL_IMPORTE` r
          ON t.brand_ds = r.brand_ds AND t.grupo_rappel = r.grupo_rappel
      INNER JOIN `mm-commissions-reporting.KRT_MASIVO.RAPPEL_NIVEL_ALCANZADO` a
          ON t.brand_ds = a.brand_ds AND t.distribuidor = a.distribuidor
          AND t.channel_ds = a.N1 AND t.subchannel_ds = a.N2 AND t.grupo_rappel = a.grupo_rappel
      LEFT JOIN `mm-commissions-reporting.KRT_MASIVO.PARAM_KRT_MAS_RAPPEL_NIVEL_ASIGNADO` ra
          ON t.brand_ds = ra.brand_ds AND t.distribuidor = ra.distribuidor
          AND t.channel_ds = ra.N1 AND t.subchannel_ds = ra.N2 AND t.grupo_rappel = ra.grupo_rappel
      WHERE t.grupo_rappel IS NOT NULL
        AND t.service_type = 'BROADBAND'
        -- Excluimos rappels ya calculados para asegurar IDEMPOTENCIA
        AND t.concepto_marco NOT IN ('Descuento plataforma cancelación', 'Rappel Teorico', 'Rappel Diferencia')
        --AND UPPER(TRIM(t.tecnologia_detalle_ds)) <> 'FTTR'
        ---AND UPPER(t.tariff_ds) NOT LIKE 'DESCUENTO%'
        --AND UPPER(t.tariff_ds) NOT LIKE '%ESTUDIANTE%'

  ), importes_calculados AS (
      -- 1.2 Vectorizamos el CASE masivo convirtiéndolo en un ARRAY de acceso directo
      SELECT 
          *,
          COALESCE(
            [n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18,n19,n20]
            [SAFE_OFFSET(nivel_teorico - 1)], 0.0
          ) AS importe_teorico,
          
          COALESCE(
            [n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18,n19,n20]
            [SAFE_OFFSET(nivel_asignado - 1)], 0.0
          ) AS importe_asignado
      FROM base_filtrada
  ),  rappel_teorico AS (
      -- 1.3 Preparamos los registros de Rappel Teórico
      SELECT 
        mes_id,
        data_source_ds,
        brand_ds,
        channel_segment_ds,
        channel_type_ds,
        master_channel_ds,
        channel_ds,
        subchannel_ds,
        agrupacion_canal_ventas_base,
        agrupacion_canal,
        canal,
        distribuidor,
        id_comisionista,
        nombre_comercio,
        user_store,
        sfid_id,
        service_type,
        technology_ds,
        tariff_id,
        tariff_ds,
        segment_ds,
        sub_segment_ds,
        customer_id,
        contract_id,
        account_id,
        hash_document_number,
        province,
        zip_code,
        line_type_ds,
        service_id,
        id,
        id_subscription_terminal,
        terminal_model,
        total_pay_value_without_vat,
        total_pay_value,
        phone_nm,
        sell_type,
        bundle_type,
        order_type_agg,
        flag_order,
        order_fix_id,
        order_id,
        campaign_code,
        tipo,
        operacion,
        seller,
        creado,
        creado_por,
        port_in_operator_ds,
        portability_group_donor,
        portability_operator_donor,
        comisiona,
        'Rappel Teorico' as  concepto_marco,
        'D - Rappel Teorico' as concepto,
        marco,
        grupo_rappel,
        orden,
        importe_teorico as importe,
        sale_date,
        cancellation_day_id,
        activation_date,
        deactivation_date,
        deactivation_reason_ds,
        CAST(NULL AS INT64) grid
      FROM importes_calculados
  ),  rappel_diferencia AS (
      -- 1.4 Preparamos los registros de Rappel Diferencia (Aplicando la lógica original del 0403)
      SELECT 
        mes_id,
        data_source_ds,
        brand_ds,
        channel_segment_ds,
        channel_type_ds,
        master_channel_ds,
        channel_ds,
        subchannel_ds,
        agrupacion_canal_ventas_base,
        agrupacion_canal,
        canal,
        distribuidor,
        id_comisionista,
        nombre_comercio,
        user_store,
        sfid_id,
        service_type,
        technology_ds,
        tariff_id,
        tariff_ds,
        segment_ds,
        sub_segment_ds,
        customer_id,
        contract_id,
        account_id,
        hash_document_number,
        province,
        zip_code,
        line_type_ds,
        service_id,
        id,
        id_subscription_terminal,
        terminal_model,
        total_pay_value_without_vat,
        total_pay_value,
        phone_nm,
        sell_type,
        bundle_type,
        order_type_agg,
        flag_order,
        order_fix_id,
        order_id,
        campaign_code,
        tipo,
        operacion,
        seller,
        creado,
        creado_por,
        port_in_operator_ds,
        portability_group_donor,
        portability_operator_donor,
        comisiona,
        'Rappel Diferencia' as  concepto_marco,
        'D - Rappel Diferencia' as concepto,
        marco,
        grupo_rappel,
        orden,
        (importe_asignado - importe_teorico) as importe,
        sale_date,
        cancellation_day_id,
        activation_date,
        deactivation_date,
        deactivation_reason_ds,
        CAST(NULL AS INT64) grid
      FROM importes_calculados
      WHERE (nivel_teorico <> nivel_asignado) OR (nivel_teorico IS NULL)
  )

  -- 1.5 Ensamblamos todo y mandamos a insertar
  SELECT * FROM rappel_teorico where coalesce(importe,0)!=0
  UNION ALL
  SELECT * FROM rappel_diferencia where coalesce(importe,0)!=0;


  ---==================================================================
  --- INTEGRACION DEL IMPORTE DE RAPPEL TEORICO Y ALCANZADO (CRITERIO: PORCENTUAL)
  ---==================================================================

  INSERT INTO `mm-commissions-reporting.KRT_MASIVO.COMISIONES`
  (
    mes_id,
    data_source_ds,
    brand_ds,
    channel_segment_ds,
    channel_type_ds,
    master_channel_ds,
    channel_ds,
    subchannel_ds,
    agrupacion_canal_ventas_base,
    agrupacion_canal,
    canal,
    distribuidor,
    id_comisionista,
    nombre_comercio,
    user_store,
    sfid_id,
    service_type,
    technology_ds,
    tariff_id,
    tariff_ds,
    segment_ds,
    sub_segment_ds,
    customer_id,
    contract_id,
    account_id,
    hash_document_number,
    province,
    zip_code,
    line_type_ds,
    service_id,
    id,
    id_subscription_terminal,
    terminal_model,
    total_pay_value_without_vat,
    total_pay_value,
    phone_nm,
    sell_type,
    bundle_type,
    order_type_agg,
    flag_order,
    order_fix_id,
    order_id,
    campaign_code,
    tipo,
    operacion,
    seller,
    creado,
    creado_por,
    port_in_operator_ds,
    portability_group_donor,
    portability_operator_donor,
    comisiona,
    concepto_marco,
    concepto,
    marco,
    grupo_rappel,
    orden,
    importe,
    sale_date,
    cancellation_day_id,
    activation_date,
    deactivation_date,
    deactivation_reason_ds,
    grid
  ) select
      mes_id,
      data_source_ds,
      brand_ds,
      channel_segment_ds,
      channel_type_ds,
      master_channel_ds,
      channel_ds,
      subchannel_ds,
      agrupacion_canal_ventas_base,
      agrupacion_canal,
      canal,
      distribuidor,
      id_comisionista,
      nombre_comercio,
      user_store,
      sfid_id,
      service_type,
      technology_ds,
      tariff_id,
      tariff_ds,
      segment_ds,
      sub_segment_ds,
      customer_id,
      contract_id,
      account_id,
      hash_document_number,
      province,
      zip_code,
      line_type_ds,
      service_id,
      id,
      id_subscription_terminal,
      terminal_model,
      total_pay_value_without_vat,
      total_pay_value,
      phone_nm,
      sell_type,
      bundle_type,
      order_type_agg,
      flag_order,
      order_fix_id,
      order_id,
      campaign_code,
      tipo,
      operacion,
      seller,
      creado,
      creado_por,
      port_in_operator_ds,
      portability_group_donor,
      portability_operator_donor,
      comisiona,
      concepto_marco,
      concepto,
      marco,
      grupo_rappel,
      orden,
      importe,
      sale_date,
      cancellation_day_id,
      activation_date,
      deactivation_date,
      deactivation_reason_ds,
      grid
    from `mm-commissions-reporting.KRT_MASIVO.RAPPEL_VENTAS_CALCULADO`;
END