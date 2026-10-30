BEGIN

  -- ======================================================
  -- PROCEDIMENTO DE CREACION DE TABLA  ventas_comisiones
  -- ======================================================

  CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.ventas_comisiones_INTEGRACION` AS

  -- ==========================================
  -- 1. PRECALCULO DE TABLAS MAESTRAS Y CTEs
  -- ==========================================

  WITH maestro_agrupacion_canal AS (
      -- Eliminación previa de duplicados
      SELECT DISTINCT a.*, agrupacion_canal
      FROM `mm-commissions-reporting.30_DIMENSIONS_COMMISSIONS.gs_control_agrupacion_canal` a,
      UNNEST(SPLIT(agrupaciones_canal, ',')) AS agrupacion_canal
  ),

  promociones_jzz AS (
      -- Filtrado previo de promociones
      SELECT 
          CAST(ID_RELACION AS STRING) AS id_relacion_str,
          ID_PROMOCION,
          REPLACE(DE_PROMOCION,"\"","") AS DE_PROMOCION,
          CASE 
              WHEN ID_PROMOCION IN (19346,19347,19348,19349,19352,19353,19354,19355,19356,19357,19360,19361,
                                    19362,19363,19366,19367,19368,19371,19372,19373,19376,19377,19378,19381,19382,19383) 
              THEN 'YES' 
          END AS segundaresidencia
      FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.jzz_2102_ventas`
      WHERE FECHA_VENTA >= '2025-10-01'
      QUALIFY ROW_NUMBER() OVER (PARTITION BY ID_RELACION ORDER BY ID_PROMOCION) = 1
  ),

  canalizacion_krt AS (
      -- Precalcula y normaliza canalizacion para cruce con ventas krt
      SELECT 
          marca_ds,
          CAST(ct.sfid AS STRING) AS ct_sfid_str,
          CAST(agente.id AS STRING) AS agente_id_str
      FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mm`
  ),

  -- ==========================================
  -- 2. UNIFICAMOS TODOS LOS ORÍGENES DE DATOS
  -- ==========================================
  datos_unificados AS (
      -- [1] VENTAS BASE
      SELECT *
      FROM `mm-commissions-reporting.COMISIONES.v_ventas_base`
      WHERE brand_ds IN ('MASMOVIL', 'PEPEPHONE', 'YOIGO', 'LLAMAYA', 'GUUK')
        AND post_pre_flag <> 1

      UNION ALL

      -- [2] MIGRACIONES BASE (SFID NO NULO)
      SELECT *
      FROM `mm-commissions-reporting.COMISIONES.migraciones_base`
      WHERE sfid_id IS NOT NULL

      UNION ALL

      -- [3] MIGRACIONES BASE (CAMBIOS DOMICILIO)
      SELECT
        a.comisionamiento, a.marca, a.brand_ds, a.service_id, a.account_id, a.customer_id,
        a.service_type, a.line_type_ds, a.bundle_type, a.technology_ds, a.billing_type_ds,
        a.phone_nm, a.sale_date, a.activation_date, a.deactivation_date, a.order_id,
        a.order_type_agg, a.port_in_operator_ds, a.tariff_id, a.tariff_ds, a.cod_segmento,
        a.cod_marca, a.cod_tipo_contrato, a.cod_producto, a.cod_canal, c.agrupacion_canal,
        a.sfid_id, a.sfid_id AS seller, a.channel_ds, a.order_fix_id, a.claim_code, a.comments,
        a.contract_id, a.data_source_ds, a.portability_group_donor, a.portability_operator_donor,
        a.flag_order, a.segment_ds, a.user_store, a.subchannel_ds, a.cancellation_day_id,
        a.sell_type, a.province, a.zip_code, a.terminal_model, a.sva_tv, a.channel_segment_ds,
        a.master_channel_ds, a.channel_type_ds, a.hash_document_number, a.cancellation_reason_agg,
        a.cancellation_subreason_agg, a.max_appointment_date, a.billing_tier, a.qvantel_service_id,
        a.post_pre_flag
      FROM `mm-commissions-reporting.COMISIONES.migraciones_base` a
      LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` c
        ON a.sfid_id = c.sfid_id
      WHERE (a.sfid_id IS NULL OR a.sfid_id = 'C00001')

      UNION ALL

      -- [4] TELCO NET (KRT / MIG PWC) 
      SELECT 
        comisionamiento, marca, brand_ds, service_id, account_id, customer_id, service_type, 
        line_type_ds, bundle_type, technology_ds, billing_type_ds, phone_nm, sale_date, 
        activation_date, deactivation_date, order_id, order_type_agg, port_in_operator_ds, 
        tariff_id, tariff_ds, cod_segmento, cod_marca, cod_tipo_contrato,
        
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
            service_type, brand_ds, order_type_agg, sell_type, cod_tipo_contrato
        ) AS cod_producto,
        
        cod_canal, agrupacion_canal, sfid_id, seller, channel_ds, order_fix_id, claim_code, 
        comments, contract_id, data_source_ds, portability_group_donor, portability_operator_donor, 
        flag_order, segment_ds, user_store, subchannel_ds, cancellation_day_id, sell_type, 
        province, zip_code, terminal_model, sva_tv, channel_segment_ds, master_channel_ds, 
        channel_type_ds, hash_document_number, cancellation_reason_agg, cancellation_subreason_agg, 
        max_appointment_date, billing_tier, qvantel_service_id, post_pre_flag
      FROM (
          SELECT
            'Comisiona' AS comisionamiento, b.marca_ds AS marca, a.brand_ds, a.service_id, a.account_id,
            a.customer_id, a.service_type, a.line_type_ds,
            CASE
                WHEN a.sell_bundle_type IN ('2P', 'FMC', 'MO') THEN a.sell_bundle_type
                WHEN a.sell_bundle_type LIKE '%M%' AND a.sell_bundle_type LIKE '%B%' THEN 'FMC'
                WHEN a.sell_bundle_type LIKE '%M%' AND a.sell_bundle_type NOT LIKE '%B%' THEN 'MO'
                WHEN a.sell_bundle_type NOT LIKE '%M%' AND a.sell_bundle_type LIKE '%B%' THEN '2P'
                ELSE 'OTROS'
            END AS bundle_type,
            a.technology_ds, a.billing_type_ds, CAST(a.phone_nm AS STRING) AS phone_nm,
            a.order_date AS sale_date, a.activation_date, a.deactivation_date, a.order_id,
            a.order_type_agg, a.port_in_operator_ds, a.tariff_id, a.tariff_ds,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(a.segment_ds, a.brand_ds) AS cod_segmento,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(a.comm_brand_ds) AS cod_marca,
            
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
                billing_type_ds, a.service_type, COALESCE(CASE WHEN sell_bundle_type = 'DESC' THEN bundle_type ELSE sell_bundle_type END, bundle_type), 
                technology_ds, a.brand_ds, COALESCE(CASE WHEN sell_line_type_ds = 'DESC' THEN line_type_ds ELSE sell_line_type_ds END, line_type_ds)
            ) AS cod_tipo_contrato,
            
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(a.channel_ds, a.subchannel_ds) AS cod_canal,
            concat('KRT - ', initcap(b.marca_ds)) AS agrupacion_canal, a.sfid_id, a.seller, a.channel_ds, a.order_fix_id,
            CAST(NULL AS STRING) AS claim_code, CAST(NULL AS STRING) AS comments, a.contract_id, a.data_source_ds,
            CAST(NULL AS STRING) AS portability_group_donor, CAST(NULL AS STRING) AS portability_operator_donor,
            a.flag_order, a.segment_ds, a.user_store, a.subchannel_ds, a.cancellation_date AS cancellation_day_id,
            a.sell_type, CAST(a.province AS STRING) AS province, a.zip_code, a.terminal_model, CAST(NULL AS STRING) AS sva_tv,
            a.channel_segment_ds, a.master_channel_ds, a.channel_type_ds, CAST(NULL AS STRING) AS hash_document_number,
            a.cancellation_reason_agg, a.cancellation_subreason_agg, CAST(NULL AS DATE) AS max_appointment_date,
            CAST(NULL AS STRING) AS billing_tier, CAST(NULL AS STRING) AS qvantel_service_id, CAST(NULL AS INT64) AS post_pre_flag
          
          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` a
          INNER JOIN canalizacion_krt b 
            ON a.brand_ds = b.marca_ds 
          
          WHERE (
              (a.brand_ds IN ("TELECABLE", "EUSKALTEL", "R", "RACC", "SIMPLE", "VIRGIN") 
               AND (b.ct_sfid_str = a.sfid_id OR b.ct_sfid_str = a.user_store))
              OR 
              (a.brand_ds = "R" AND b.agente_id_str = a.sfid_id)
          )
      )

      -- [5] TELCO NET (KRT / AGENTS) 


      UNION ALL

      -- [6] TELCO NET (PARLEM) 
      SELECT 
        comisionamiento, marca, brand_ds, service_id, account_id, customer_id, service_type, 
        line_type_ds, bundle_type, technology_ds, billing_type_ds, phone_nm, sale_date, 
        activation_date, deactivation_date, order_id, order_type_agg, port_in_operator_ds, 
        tariff_id, tariff_ds, cod_segmento, cod_marca, cod_tipo_contrato,
        
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
            service_type, brand_ds, order_type_agg, sell_type, cod_tipo_contrato
        ) AS cod_producto,
        
        cod_canal, agrupacion_canal, sfid_id, seller, channel_ds, order_fix_id, claim_code, 
        comments, contract_id, data_source_ds, portability_group_donor, portability_operator_donor, 
        flag_order, segment_ds, user_store, subchannel_ds, cancellation_day_id, sell_type, 
        province, zip_code, terminal_model, sva_tv, channel_segment_ds, master_channel_ds, 
        channel_type_ds, hash_document_number, cancellation_reason_agg, cancellation_subreason_agg, 
        max_appointment_date, billing_tier, qvantel_service_id, post_pre_flag
      FROM (
          SELECT
            'Comisiona' AS comisionamiento, 'PARLEM' AS marca, 'PARLEM' AS brand_ds, a.service_id, a.account_id,
            a.customer_id, a.service_type, a.line_type_ds,
            CASE
                WHEN a.sell_bundle_type IN ('2P', 'FMC', 'MO') THEN a.sell_bundle_type
                WHEN a.sell_bundle_type LIKE '%M%' AND a.sell_bundle_type LIKE '%B%' THEN 'FMC'
                WHEN a.sell_bundle_type LIKE '%M%' AND a.sell_bundle_type NOT LIKE '%B%' THEN 'MO'
                WHEN a.sell_bundle_type NOT LIKE '%M%' AND a.sell_bundle_type LIKE '%B%' THEN '2P'
                ELSE 'OTROS'
            END AS bundle_type,
            a.technology_ds, a.billing_type_ds, CAST(a.phone_nm AS STRING) AS phone_nm, order_date AS sale_date,
            a.activation_date, a.deactivation_date, a.order_id, a.order_type_agg, a.port_in_operator_ds, a.tariff_id, a.tariff_ds,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, a.brand_ds) AS cod_segmento,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(a.comm_brand_ds) AS cod_marca,
            
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
                billing_type_ds, a.service_type, COALESCE(CASE WHEN sell_bundle_type = 'DESC' THEN bundle_type ELSE sell_bundle_type END, bundle_type), 
                technology_ds, a.brand_ds, COALESCE(CASE WHEN sell_line_type_ds = 'DESC' THEN line_type_ds ELSE sell_line_type_ds END, line_type_ds)
            ) AS cod_tipo_contrato,
            
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(a.channel_ds, a.subchannel_ds) AS cod_canal,
            'B2B - Parlem' AS agrupacion_canal, a.sfid_id, a.seller, a.channel_ds, a.order_fix_id, CAST(NULL AS STRING) AS claim_code,
            CAST(NULL AS STRING) AS comments, a.contract_id, a.data_source_ds, CAST(NULL AS STRING) AS portability_group_donor,
            CAST(NULL AS STRING) AS portability_operator_donor, a.flag_order, a.segment_ds, a.user_store, a.subchannel_ds,
            cancellation_date AS cancellation_day_id, a.sell_type, CAST(a.province AS STRING) AS province, a.zip_code, a.terminal_model,
            CAST(NULL AS STRING) AS sva_tv, a.channel_segment_ds, a.master_channel_ds, a.channel_type_ds, CAST(NULL AS STRING) AS hash_document_number,
            a.cancellation_reason_agg, a.cancellation_subreason_agg, CAST(NULL AS DATE) AS max_appointment_date,
            CAST(NULL AS STRING) AS billing_tier, CAST(NULL AS STRING) AS qvantel_service_id, CAST(NULL AS INT64) AS post_pre_flag
          FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net` a
          LEFT JOIN `mm-commissions-reporting.GS.DEALERS_PARLEM` b 
            ON a.sfid_id = b.id_comisionista
          WHERE brand_ds = 'OPERADORES'
            AND comm_brand_ds = 'PARLEM'
            AND service_type IN ('BROADBAND', 'FIX', 'MOBILE', 'ONLY DATA MOBILE')
            AND b.id_comisionista IS NOT NULL 
      )

      UNION ALL

      -- [7] EMBOU 
      SELECT
        'Comisiona' AS comisionamiento, 'EMBOU' AS marca, 'EMBOU' AS brand_ds, CAST(NULL AS STRING) AS service_id,
        CAST(NULL AS STRING) AS account_id, customer_id, service_type,
        CASE WHEN tariff_ds LIKE '%ADICIONAL%' THEN 'ADDITIONAL' ELSE 'MAIN' END AS line_type_ds,
        CASE
            WHEN num_fibra >= 1 AND num_movil >= 1 THEN 'FMC'
            WHEN num_fibra >= 1 THEN '2P'
            WHEN num_movil >= 1 THEN 'MO'
        END AS bundle_type,
        CASE
            WHEN UPPER(tariff_ds) LIKE '%FIBRA%' THEN 'FTTH'
            WHEN UPPER(tariff_ds) LIKE 'INTERNET%' OR UPPER(tariff_ds) LIKE '%WIMAX%' THEN 'WIMAX'
            WHEN service_type IN ('MOBILE', 'TV') THEN service_type
        END AS technology_ds,
        'POSTPAID' AS billing_type_ds,
        CASE
            WHEN service_type = 'INTERNET' AND REGEXP_CONTAINS(phone_nm_1, '^[89]') THEN phone_nm_1
            WHEN service_type = 'INTERNET' AND REGEXP_CONTAINS(phone_nm_2, '^[89]') THEN phone_nm_2
            WHEN REGEXP_CONTAINS(UPPER(tariff_ds), 'INTERNET|WIMAX') AND REGEXP_CONTAINS(phone_nm_1, '^[67]') THEN phone_nm_1
            WHEN REGEXP_CONTAINS(UPPER(tariff_ds), 'INTERNET|WIMAX') AND REGEXP_CONTAINS(phone_nm_2, '^[67]') THEN phone_nm_2
            WHEN service_type = 'MOBILE' AND REGEXP_CONTAINS(phone_nm_1, '^[67]')
                 AND ROW_NUMBER() OVER(PARTITION BY customer_id, activation_date, service_type ORDER BY CASE WHEN tariff_ds NOT LIKE '%ADICIONAL%' THEN 1 ELSE 2 END) = 1 THEN phone_nm_1
            WHEN service_type = 'MOBILE' AND REGEXP_CONTAINS(phone_nm_2, '^[67]')
                 AND ROW_NUMBER() OVER(PARTITION BY customer_id, activation_date, service_type ORDER BY CASE WHEN tariff_ds NOT LIKE '%ADICIONAL%' THEN 1 ELSE 2 END) = 1 THEN phone_nm_2
            WHEN service_type = 'TV' AND REGEXP_CONTAINS(phone_nm_1, '^[67]') THEN phone_nm_1
            WHEN service_type = 'TV' AND REGEXP_CONTAINS(phone_nm_2, '^[67]') THEN phone_nm_2
        END AS phone_nm,
        sale_date, activation_date, CAST(NULL AS DATE) AS deactivation_date, order_id, 'ALTA NUEVA' AS order_type_agg,
        CAST(NULL AS STRING) AS port_in_operator_ds, CAST(NULL AS STRING) AS tariff_id, tariff_ds, cod_segmento, '07' AS cod_marca,
        CASE
            WHEN service_type = 'INTERNET' AND num_fibra >= 1 THEN '61'
            WHEN service_type = 'INTERNET' THEN '63'
            WHEN service_type = 'MOBILE' AND num_fibra >= 1 AND tariff_ds NOT LIKE '%ADICIONAL%' THEN '61'
            WHEN service_type = 'MOBILE' AND num_fibra >= 1 THEN '67'
            WHEN service_type = 'MOBILE' THEN '20' ELSE '99'
        END AS cod_tipo_contrato,
        '039' AS cod_producto, cod_canal, 'Exclusivo' AS agrupacion_canal, sfid_id, seller, CAST(NULL AS STRING) AS channel_ds,
        order_fix_id, CAST(NULL AS STRING) AS claim_code, servicios AS comments, contract_id, 'EX_DS_VENTAS_EMBOU' AS data_source_ds,
        CAST(NULL AS STRING) AS portability_group_donor, CAST(NULL AS STRING) AS portability_operator_donor, CAST(NULL AS STRING) AS flag_order,
        segment_ds, user_store, CAST(NULL AS STRING) AS subchannel_ds, CAST(NULL AS DATE) AS cancellation_day_id, CAST(NULL AS STRING) AS sell_type,
        CAST(NULL AS STRING) AS province, CAST(NULL AS STRING) AS zip_code, CAST(NULL AS STRING) AS terminal_model, CAST(NULL AS STRING) AS sva_tv,
        CAST(NULL AS STRING) AS channel_segment_ds, CAST(NULL AS STRING) AS master_channel_ds, CAST(NULL AS STRING) AS channel_type_ds,
        CAST(NULL AS STRING) AS hash_document_number, CAST(NULL AS STRING) AS cancellation_reason_agg, CAST(NULL AS STRING) AS cancellation_subreason_agg,
        CAST(NULL AS DATE) AS max_appointment_date, CAST(NULL AS STRING) AS billing_tier, CAST(NULL AS STRING) AS qvantel_service_id, CAST(NULL AS INT64) AS post_pre_flag
      FROM (
          SELECT 
              E.* EXCEPT(servicios),
              REPLACE(REPLACE(REGEXP_REPLACE(UPPER(E.servicios), r',?TARIFA PLANA ILIMITADA \((150|60|500|10\.000) MIN A MÓVILES\),?| - SOLO INTERNET', ''), 'SOLO INTERNET', 'INTERNET'), 'SERVICIO AGILE', 'AGILE') AS servicios,
              service_type
          FROM (
              SELECT
                  * EXCEPT(servicios), servicios, CAST(id_cliente AS STRING) AS customer_id, CAST(telefono_1 AS STRING) AS phone_nm_1,
                  CAST(telefono_2 AS STRING) AS phone_nm_2, fecha_contratacion AS sale_date, fecha_alta AS activation_date, contrato AS order_id,
                  CASE
                      WHEN UPPER(modalidad) LIKE '%RESIDENCIAL%' THEN '10'
                      WHEN UPPER(modalidad) LIKE '%SOHO%' THEN '12'
                      WHEN UPPER(modalidad) LIKE '%NEGOCIOS%' THEN '30'
                  END AS cod_segmento,
                  '27' AS cod_canal, sfid AS sfid_id, sfid AS seller, ot AS order_fix_id, contrato AS contract_id,
                  CASE
                      WHEN UPPER(modalidad) LIKE '%RESIDENCIAL%' THEN 'RESIDENCIAL'
                      WHEN UPPER(modalidad) LIKE '%SOHO%' THEN 'SOHO'
                      WHEN UPPER(modalidad) LIKE '%NEGOCIOS%' THEN 'NEGOCIOS'
                  END AS segment_ds,
                  sfid AS user_store, SUM(num_serv_fibra + num_serv_wimax) AS num_fibra, SUM(num_serv_movil) AS num_movil, SUM(num_serv_agiletv) AS num_tv
              FROM `mm-sales-reporting.SPEEDUP.ex_ds_ventas_embou`
              WHERE CAST(anio AS INT64) >= 2025
              GROUP BY ALL
          ) E
          LEFT JOIN UNNEST(['INTERNET', 'MOBILE', 'TV']) AS service_type
            ON (E.num_fibra >= 1 AND service_type = 'INTERNET') OR (E.num_movil >= 1 AND service_type = 'MOBILE') OR (E.num_tv >= 1 AND service_type = 'TV')
          WHERE E.servicios IS NOT NULL AND service_type IS NOT NULL
      ) AS EMBOU, UNNEST(SPLIT(EMBOU.servicios, ',')) AS tariff_ds
      WHERE EMBOU.service_type = COALESCE(
          CASE
              WHEN REGEXP_CONTAINS(UPPER(tariff_ds), 'FIBRA|INTERNET|WIMAX') THEN 'INTERNET'
              WHEN REGEXP_CONTAINS(UPPER(tariff_ds), 'GB|TARIFA INFINITA') THEN 'MOBILE'
              WHEN UPPER(tariff_ds) LIKE '%AGILE%' THEN 'TV'
          END, EMBOU.service_type
      )

      UNION ALL

      -- [8] VENTAS OSP 
      SELECT 
        comisionamiento, marca, brand_ds, service_id, account_id, customer_id, service_type, 
        sell_line_type_ds AS line_type_ds, sell_bundle_type AS bundle_type, technology_ds, 
        billing_type_ds, phone_nm, sale_date, activation_date, deactivation_date, order_id, 
        order_type_agg, port_in_operator_ds, tariff_id, tariff_ds, cod_segmento, cod_marca, 
        cod_tipo_contrato,
        
        `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_producto`(
            service_type, brand_ds, order_type_agg, sell_type, cod_tipo_contrato
        ) AS cod_producto,
        
        cod_canal, agrupacion_canal, sfid_id, seller, channel_ds, order_fix_id, claim_code, 
        comments, contract_id, data_source_ds, portability_group_donor, portability_operator_donor, 
        flag_order, segment_ds, user_store, subchannel_ds, cancellation_date AS cancellation_day_id, 
        sell_type, province, zip_code, terminal_model, sva_tv, channel_segment_ds, master_channel_ds, 
        channel_type_ds, hash_document_number, cancellation_reason_agg, cancellation_subreason_agg, 
        max_appointment_date, billing_tier, qvantel_service_id, post_pre_flag
      FROM (
          SELECT 
            'Comisiona' AS comisionamiento, a.brand_ds AS marca, a.brand_ds, a.service_id, a.account_id, a.customer_id,
            CASE 
                WHEN a.service_type = 'FIX' AND a.brand_ds = 'SIMYO' THEN 'INTERNET'
                WHEN a.service_type = 'BROADBAND' THEN 'INTERNET' 
                ELSE a.service_type 
            END AS service_type,
            a.sell_line_type_ds, a.sell_bundle_type, a.technology_ds, a.billing_type_ds, CAST(a.phone_nm AS STRING) AS phone_nm,
            a.order_day_id AS sale_date, a.activation_date, a.deactivation_date, a.order_id, a.order_type_agg, a.port_in_operator_ds,
            CASE 
                WHEN a.brand_ds = 'SIMYO' THEN a.sell_tariff_id 
                WHEN a.brand_ds = 'JAZZTEL' AND a.service_type = 'BROADBAND' THEN SUBSTRING(OSP.sell_tariff_id, 1 ,7) || COALESCE('-' || a.ID_PROMOCION, '')
                WHEN a.brand_ds = 'JAZZTEL' AND a.technology_ds = 'FIXED LTE' THEN SUBSTRING(OSP.sell_tariff_id, 1 ,7) || COALESCE('-' || a.ID_PROMOCION, '')
                WHEN a.brand_ds = 'JAZZTEL' AND a.service_type = 'MOBILE' THEN SUBSTRING(OSP.sell_tariff_id, 1 ,7)
                WHEN a.brand_ds = 'ORANGE' THEN CAST(MO.master_tariff_id AS STRING)
                ELSE CAST(TARIFAS.TARIFF_KEY AS STRING) 
            END AS tariff_id,
            CASE
                WHEN a.brand_ds = 'SIMYO' THEN a.sell_tariff_ds 
                WHEN a.brand_ds = 'ORANGE' AND a.order_type_agg = 'MIGRACION PREPAGO A POSTPAGO' THEN OSP.bundle_name
                ELSE OSP.sell_bundle_name 
            END AS tariff_ds,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(a.segment_ds, a.brand_ds) AS cod_segmento,
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(a.brand_ds) AS cod_marca,
            
            `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(
                a.billing_type_ds, a.service_type, a.sell_bundle_type, a.technology_ds, a.brand_ds, a.sell_line_type_ds
            ) AS cod_tipo_contrato,
            
            AGRUPACION.codigo_canal_sap AS cod_canal, AGRUPACION.agrupacion_canal,
            CASE WHEN a.brand_ds = 'SIMYO' THEN JERARQUIA.SFID_HIJO ELSE a.sfid_id END AS sfid_id,
            a.seller, a.channel_ds, a.order_fix_id, CAST(NULL AS STRING) AS claim_code, CAST(NULL AS STRING) AS comments,
            a.contract_id, a.data_source_ds, a.grupo_operador_donante_unificado AS portability_group_donor,
            a.operador_donante_unificado AS portability_operator_donor, CAST(NULL AS STRING) AS flag_order, a.segment_ds,
            a.user_store, a.subchannel_ds, a.cancellation_day_id AS cancellation_date, a.sell_type, a.province, a.zip_code,
            a.terminal_model, CAST(NULL AS STRING) AS sva_tv, a.channel_segment_ds, a.canal_n0 AS master_channel_ds,
            OSP.channel_type_ds, CAST(NULL AS STRING) AS hash_document_number, a.cancellation_reason_agg,
            a.cancellation_subreason_agg, CAST(NULL AS DATE) AS max_appointment_date, CAST(NULL AS STRING) AS billing_tier,
            CAST(NULL AS STRING) AS qvantel_service_id, CAST(NULL AS INT64) AS post_pre_flag 
          FROM `mm-sales-reporting.SPEEDUP.query_informe_multimarca_gmm` a
          LEFT JOIN `mm-datamart-kd.JV_ORANGE.ventas_base_telco_osp` OSP ON a.service_id = OSP.service_id
          LEFT JOIN `mm-commissions-reporting.COMISIONES.jerarquia_tiendas_orange` JERARQUIA ON a.seller = JERARQUIA.AGENT_ID
          LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tarifas_20260427` TARIFAS 
              ON TARIFAS.TARIFF_ID = OSP.sell_tariff_id AND TARIFAS.TARIFF_DES = OSP.sell_tariff_ds AND TARIFAS.TARIFF_LG_DES = OSP.sell_bundle_name
          LEFT JOIN maestro_agrupacion_canal AGRUPACION
              ON COALESCE(a.channel_segment_ds, 'channel_segment_ds') = COALESCE(AGRUPACION.channel_segment_ds, 'channel_segment_ds')
              AND a.canal_n0 = AGRUPACION.master_channel_ds AND a.canal_n1  = AGRUPACION.channel_ds AND a.canal_n2  = AGRUPACION.subchannel_ds AND a.brand_ds = AGRUPACION.comm_brand_ds
          LEFT JOIN promociones_jzz promojzz
              ON promojzz.id_relacion_str = osp.order_id
          LEFT JOIN `mm-datamart-kd.SERVICES.sales_mo` MO
              ON a.service_id = MO.service_id AND a.brand_ds = MO.brand_ds AND a.phone_nm = MO.phone_nm
          WHERE a.brand_ds IN ('ORANGE', 'SIMYO', 'JAZZTEL')
          GROUP BY ALL
      )
  )

  -- ==========================================
  -- 3. SELECT FINAL RESUELVE SOCIEDAD
  -- ==========================================
  SELECT
      *,
      CASE
          WHEN marca = 'PEPEPHONE' THEN '7000'
          WHEN marca IN ('TELECABLE', 'R') THEN 'R000'
          WHEN marca IN ('EUSKALTEL', 'RACC', 'SIMPLE', 'VIRGIN', 'VIVA MOBILE') THEN 'ET00'          
          ELSE 'X001'
      END AS sociedad,
      
      CAST(FORMAT_DATE('%Y%m', activation_date) AS INT64) AS id_mes_activacion,
      
      CASE
          WHEN (REGEXP_CONTAINS(seller, '^([0-9A-Z][A-Z][0-9]{6})') AND channel_ds IN ('MASLIFE','EXCLUSIVO'))
                OR data_source_ds IN ('QVANTEL', 'MYSIM', 'HEOS')
          THEN SUBSTR(seller, 1, 2)
          WHEN seller LIKE 'DBL%' AND channel_ds IN ('MASLIFE','EXCLUSIVO') AND marca = 'YOIGO'
          THEN SUBSTR(seller, 1, 2)
      END AS seller_formato_tms

  FROM datos_unificados;

END