BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo` AS 
  with p as (
    select * from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mo`
    union all 
    select * from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_tcnet_canalizacion_ct_mo`  
    union all 
    select * from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_siebel_canalizacion_ct_mo`
  ) select *
  from p 
  order by 1 asc,2 asc ,4 asc,6 asc ,8 asc;


  ---- ÑAPA PARA INTEGRAR CANCELACIONES
  INSERT INTO `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo`

  SELECT 
  -- 1 al 11. Campos planos (se pasan tal cual)
  "MYSIM" crm,
  "R" brand_ds,
  CAST(NULL AS INT64) canal_agrupado2_id,
  CAST(NULL AS STRING) canal_agrupado2_ds,
  CAST(NULL AS INT64) canal_agrupado1_id,
  CAST(NULL AS STRING) canal_agrupado1_ds,
  CAST(NULL AS INT64) subcanal_id,
  CAST(NULL AS STRING) subcanal_ds,
  CAST(NULL AS INT64) canal_id,
  CAST(NULL AS STRING) equipo_ds,
  CAST(NULL AS STRING) agente_venta_id,

  -- 12. distribuidor
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS distribuidor,

  -- 13. canal_asociado
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS canal_asociado,

  -- 14. equipo
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, -- Renombrado para no chocar con el campo plano equipo_ds
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja,
    CAST(NULL AS STRING)  AS param_ctx
  ) AS equipo,

  -- 15. agente
  STRUCT(
    CAST(NULL AS INT64)  AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS agente,

  -- 16. ct
  STRUCT(
    CAST(NULL AS STRING) AS tipo_canal_ds,
    CAST(NULL AS STRING) AS canal_ds,
    CAST(NULL AS STRING) AS subcanal_ds,
    CAST(NULL AS STRING) AS distribuidor_ds,
    CAST(NULL AS STRING) AS equipo_ds, -- Reutilizando campo plano si aplica
    CAST(NULL AS STRING) AS agente_venta_id, -- Reutilizando campo plano si aplica
    CAST(NULL AS STRING) AS sfid
  ) AS ct,

  -- 17. mm
  STRUCT(
    CAST(NULL AS STRING) AS channel_type_ds,
    CAST(NULL AS STRING) AS master_channel_ds,
    CAST(NULL AS STRING) AS superchannel_ds,
    CAST(NULL AS STRING) AS channel_ds,
    CAST(NULL AS STRING) AS subchannel_ds,
    CAST(NULL AS STRING) AS distribuidor_ds,
    CAST(NULL AS STRING) AS sfid,
    CAST(NULL AS INT64)  AS channel_id,
    CAST(NULL AS STRING) AS channel_segment_ds
  ) AS mm,

  -- 18. mo
  STRUCT(
    'SALES' AS origin_type,
    'CANCELACIONES' AS N0,
    'CANCELACIONES' AS N1,
    'CANCELACIONES' AS N2,
    'R000' AS sociedad,
    'A15740863' AS CIF,
    'PEN' AS zona_fiscal,
    CAST(9204 AS INT64) AS bp,
    'CENTRO DE ATENCION DE LLAMADAS, S.A' AS razon_social,
    'CENTRO DE ATENCION DE LLAMADAS, S.A' AS nombre_acreedor_ds,
    CAST(98904 AS INT64) AS channel_id,
    'RECANNORTE3' AS sfid,
    'CN' AS n2id
  ) AS mo


  UNION ALL


  SELECT 
  -- 1 al 11. Campos planos (se pasan tal cual)
  "MYSIM" crm,
  "EUSKALTEL" brand_ds,
  CAST(NULL AS INT64) canal_agrupado2_id,
  CAST(NULL AS STRING) canal_agrupado2_ds,
  CAST(NULL AS INT64) canal_agrupado1_id,
  CAST(NULL AS STRING) canal_agrupado1_ds,
  CAST(NULL AS INT64) subcanal_id,
  CAST(NULL AS STRING) subcanal_ds,
  CAST(NULL AS INT64) canal_id,
  CAST(NULL AS STRING) equipo_ds,
  CAST(NULL AS STRING) agente_venta_id,

  -- 12. distribuidor
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS distribuidor,

  -- 13. canal_asociado
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS canal_asociado,

  -- 14. equipo
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, -- Renombrado para no chocar con el campo plano equipo_ds
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja,
    CAST(NULL AS STRING)  AS param_ctx
  ) AS equipo,

  -- 15. agente
  STRUCT(
    CAST(NULL AS INT64)  AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS agente,

  -- 16. ct
  STRUCT(
    CAST(NULL AS STRING) AS tipo_canal_ds,
    CAST(NULL AS STRING) AS canal_ds,
    CAST(NULL AS STRING) AS subcanal_ds,
    CAST(NULL AS STRING) AS distribuidor_ds,
    CAST(NULL AS STRING) AS equipo_ds, -- Reutilizando campo plano si aplica
    CAST(NULL AS STRING) AS agente_venta_id, -- Reutilizando campo plano si aplica
    CAST(NULL AS STRING) AS sfid
  ) AS ct,

  -- 17. mm
  STRUCT(
    CAST(NULL AS STRING) AS channel_type_ds,
    CAST(NULL AS STRING) AS master_channel_ds,
    CAST(NULL AS STRING) AS superchannel_ds,
    CAST(NULL AS STRING) AS channel_ds,
    CAST(NULL AS STRING) AS subchannel_ds,
    CAST(NULL AS STRING) AS distribuidor_ds,
    CAST(NULL AS STRING) AS sfid,
    CAST(NULL AS INT64)  AS channel_id,
    CAST(NULL AS STRING) AS channel_segment_ds
  ) AS mm,

  -- 18. mo
  STRUCT(
    'SALES' AS origin_type,
    'CANCELACIONES' AS N0,
    'CANCELACIONES' AS N1,
    'CANCELACIONES' AS N2,
    'ET00' AS sociedad,
    'A15740863' AS CIF,
    'PEN' AS zona_fiscal,
    CAST(9204 AS INT64) AS bp,
    'ATECH BUSINESS OPERATION, S.L.' AS razon_social,
    'ATECH BUSINESS OPERATION, S.L.' AS nombre_acreedor_ds,
    CAST(13228 AS INT64) AS channel_id,
    'RECANNORTE2' AS sfid,
    'CN' AS n2id
  ) AS mo


  UNION ALL


  SELECT 
  -- 1 al 11. Campos planos (se pasan tal cual)
  "MYSIM" crm,
  "TELECABLE" brand_ds,
  CAST(NULL AS INT64) canal_agrupado2_id,
  CAST(NULL AS STRING) canal_agrupado2_ds,
  CAST(NULL AS INT64) canal_agrupado1_id,
  CAST(NULL AS STRING) canal_agrupado1_ds,
  CAST(NULL AS INT64) subcanal_id,
  CAST(NULL AS STRING) subcanal_ds,
  CAST(NULL AS INT64) canal_id,
  CAST(NULL AS STRING) equipo_ds,
  CAST(NULL AS STRING) agente_venta_id,

  -- 12. distribuidor
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS distribuidor,

  -- 13. canal_asociado
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS canal_asociado,

  -- 14. equipo
  STRUCT(
    CAST(NULL AS INT64) AS id, 
    CAST(NULL AS STRING) AS ds, -- Renombrado para no chocar con el campo plano equipo_ds
    CAST(NULL AS STRING) AS descripcion, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja,
    CAST(NULL AS STRING)  AS param_ctx
  ) AS equipo,

  -- 15. agente
  STRUCT(
    CAST(NULL AS INT64)  AS id, 
    CAST(NULL AS STRING) AS ds, 
    CAST(NULL AS STRING) AS estado, 
    CAST(NULL AS DATE) AS fechaCreacion, 
    CAST(NULL AS DATE) AS fechaAlta, 
    CAST(NULL AS DATE) AS fechaBaja
  ) AS agente,

  -- 16. ct
  STRUCT(
    CAST(NULL AS STRING) AS tipo_canal_ds,
    CAST(NULL AS STRING) AS canal_ds,
    CAST(NULL AS STRING) AS subcanal_ds,
    CAST(NULL AS STRING) AS distribuidor_ds,
    CAST(NULL AS STRING) AS equipo_ds, -- Reutilizando campo plano si aplica
    CAST(NULL AS STRING) AS agente_venta_id, -- Reutilizando campo plano si aplica
    CAST(NULL AS STRING) AS sfid
  ) AS ct,

  -- 17. mm
  STRUCT(
    CAST(NULL AS STRING) AS channel_type_ds,
    CAST(NULL AS STRING) AS master_channel_ds,
    CAST(NULL AS STRING) AS superchannel_ds,
    CAST(NULL AS STRING) AS channel_ds,
    CAST(NULL AS STRING) AS subchannel_ds,
    CAST(NULL AS STRING) AS distribuidor_ds,
    CAST(NULL AS STRING) AS sfid,
    CAST(NULL AS INT64)  AS channel_id,
    CAST(NULL AS STRING) AS channel_segment_ds
  ) AS mm,

  -- 18. mo
  STRUCT(
    'SALES' AS origin_type,
    'CANCELACIONES' AS N0,
    'CANCELACIONES' AS N1,
    'CANCELACIONES' AS N2,
    'ET00' AS sociedad,
    'A15740863' AS CIF,
    'PEN' AS zona_fiscal,
    CAST(9204 AS INT64) AS bp,
    'ATECH BUSINESS OPERATION, S.L.' AS razon_social,
    'ATECH BUSINESS OPERATION, S.L.' AS nombre_acreedor_ds,
    CAST(13228 AS INT64) AS channel_id,
    'RECANNORTE1' AS sfid,
    'CN' AS n2id
  ) AS mo;
  

END