BEGIN

-- CALL`mm-commissions-reporting.TEMP.pr_carga_comisiones_osp`('MC_PREP0828.01','COMISIONES.confirmado_20260901');

  DECLARE sql_query, tabla_org_dest STRING;

  SET tabla_org_dest = REGEXP_REPLACE(tabla_sap, r'^COMISIONES\.', '');
  -- ,proceso_sap_pr,tabla_sap STRING;
  -- SET proceso_sap_pr = 'MC_PREP0828.01';
  -- SET tabla_sap = 'COMISIONES.confirmado_20260901';
  SET sql_query = FORMAT("""
    CREATE OR REPLACE TABLE `mm-commissions-reporting.BTP_COMISIONES.%s` AS
      SELECT
          @proceso_param            AS runId
        , id_registro               AS commissionId
        , sociedad                  AS sociedad
        , id_comisionista           AS id_comisionista
        , tipo_comisionista         AS tipo_comisionista
        , CIF                       AS CIF
        , zona_fiscal               AS zona_fiscal
        , tipo_concepto             AS tipo_concepto  -- Es fijo?
        , descripcion_concepto      AS descripcion_concepto
        , uds                       AS uds
        , importe_base              AS importe_base
        , moneda                    AS moneda
        , via_pago                  AS via_pago
        , cond_pago                 AS cond_pago
        , cod_canal                 AS cod_canal
        , cod_producto              AS cod_producto
        , cod_tipo_contrato         AS cod_tipo_contrato
        , cod_marca                 AS cod_marca
        , cod_operador              AS cod_operador
        , cod_segmento              AS cod_segmento
        , 'P'                       AS documentStage -- PTD desarrollar
        , 'OSP'                     AS facturador
        , CAST(NULL AS STRING)      AS campo_1
        , CAST(NULL AS STRING)      AS campo_2
        , CAST(NULL AS STRING)      AS campo_3
        , CAST(NULL AS STRING)      AS campo_4
        , 'ONE'                     AS targetSystem
        , CAST(NULL AS STRING)      AS invoice_id
        , CAST(NULL AS STRING)      AS documento_SAP
        , CAST(NULL AS STRING)      AS posicion_SAP
      FROM `mm-commissions-reporting.COMISIONES.%s`
  """, tabla_org_dest,tabla_org_dest);

  EXECUTE IMMEDIATE sql_query USING proceso_sap_pr AS proceso_param;

END