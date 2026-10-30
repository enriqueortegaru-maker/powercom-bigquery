BEGIN

-- call `mm-commissions-reporting.B2B.pr_provision_global`();

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PROVISION_MENSUAL`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  SELECT 
    Periodo_YYYYMM AS id_mes,
    id_provision,
    b.ID_CAMPANA AS id_camp,
    a.Id_Subcampana AS id_subcamp,
    subcampana,
    cliente AS cuenta_cliente,
    marca AS segmento,
    producto AS tipo_servicio,
    subproducto AS tipo_paquete,
    tipo,
    estado,
    budget,
    IFNULL(REPLACE(CAST(Compromiso_Economico AS STRING),'.',','),'0') AS importe_origen,
    IFNULL(REPLACE(CAST(Compromiso_Economico AS STRING),'.',','),'0') AS importe_mod_controlling,
    CAST(NULL AS STRING) AS CONTABILIZACION,
    0 AS IMPORTE,
    0 AS EX_DEF,
    CAST(NULL AS STRING) AS COMENTARIOS,
    0 AS PROVISION,
    CAST(NULL AS STRING) AS COMENTARIOS_dos
  FROM `mm-commissions-reporting.GS.PROVISION_GLOBAL` a
  LEFT JOIN (
    SELECT ID_SUBCAMPANA,ID_CAMPANA
    FROM `mm-commissions-reporting.B2B.gs_global_subcampana`
    GROUP BY ALL
  ) b ON a.Id_Subcampana = CAST(b.ID_SUBCAMPANA AS STRING)
  WHERE 1=1
    AND Periodo_YYYYMM = '202604'
    AND marca NOT IN ('POPULOOS','CIRCUITO') 

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PROVISION_MENSUAL_HIST_INSERT_EXCEL`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS


  SELECT a.*
  FROM `mm-commissions-reporting.TEMP.PROVISION_MENSUAL` a
  LEFT JOIN `mm-commissions-reporting.GS.PROVISION_HIST` b ON a.Id_Provision = b.id_provision AND a.id_mes = b.id_mes AND a.id_subcamp = b.id_subcamp
  WHERE 1=1
    AND b.id_subcamp IS NULL
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.PROVISION_TRANSACCIONES_INSERT_EXCEL`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

 SELECT 
    id_mes,
    canal,
    STRING_AGG(DISTINCT concepto) AS concepto,
    REGEXP_EXTRACT(concepto, r'\d+$') AS id_subcamp_tr,
    SUM(unidades) AS uds_tr,
    IFNULL(REPLACE(CAST(SUM(comision) AS STRING),'.',','),'0') AS comision_tr
  FROM `mm-commissions-reporting.COMISIONES.transacciones`
  WHERE 1=1
    AND concepto LIKE 'D %'
    AND tipo_concepto = 'UPFR'
    AND id_mes >= 202601
    AND canal IN ('CM','CALT','MB','MBA')
    AND concepto NOT LIKE '%FDZ%'
  GROUP BY ALL
  ORDER BY id_mes ASC,canal
  ;
END