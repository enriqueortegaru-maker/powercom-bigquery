BEGIN

-- CALL `mm-commissions-reporting.B2B.pr_marco_general_marblanca`();

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.MARCOS_MARBLANCA_NUEVAS_TARIFAS_PROCESADO`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 
    base AS (
      SELECT 
        b.marco,
        a.*,
        b.porcentaje,
        PVP_CON_IVA_PAQUETE*b.porcentaje AS comision_esperada_total,
        CAST(NULL AS STRING) AS comision_esperada_movil,
        CASE
          WHEN b.Tipo_paquete NOT IN ('2P','2P IP-FIJA','3P IP-FIJA') THEN 
            CASE
              WHEN marco LIKE 'ALT%' THEN 
                CASE
                  WHEN marco = 'ALTDIAMANTE' THEN (PVP_CON_IVA_PAQUETE*porcentaje)+(PVP_CON_IVA_FMC*0.37)
                  WHEN marco = 'ALTORO'      THEN (PVP_CON_IVA_PAQUETE*porcentaje)+(PVP_CON_IVA_FMC*0.35)
                  WHEN marco = 'ALTPLATA'    THEN (PVP_CON_IVA_PAQUETE*porcentaje)+(PVP_CON_IVA_FMC*0.30)
                  WHEN marco = 'ALTBRONCE'   THEN (PVP_CON_IVA_PAQUETE*porcentaje)+(PVP_CON_IVA_FMC*0.25)
                  WHEN marco = 'ALTESTANDAR' THEN (PVP_CON_IVA_PAQUETE*porcentaje)+(PVP_CON_IVA_FMC*0.20)
                  ELSE 0 
                END/PVP_CON_IVA_BA
              ELSE (PVP_CON_IVA_PAQUETE*b.porcentaje)/PVP_CON_IVA_BA 
            END
          ELSE b.porcentaje
        END AS PORCENTAJE_PAQUETE_PRORRATEADO,

      FROM `mm-commissions-reporting.GS.MARCOS_MARBLANCA_NUEVAS_TARIFAS` a
      LEFT JOIN `mm-commissions-reporting.GS.MARCOS_MARBLANCA_POR_TIPO` b ON 
      a.huella = b.huella 
      AND b.Tipo_paquete = a.tipo_paquete 
      AND a.Velocidad = b.velocidad
      AND b.tipo NOT IN ('ALTAS 2P','ALTAS 3P')
    )
    SELECT *,
      PVP_CON_IVA_BA*PORCENTAJE_PAQUETE_PRORRATEADO AS comision_final
    FROM base
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.MARCOS_MARBLANCA_NUEVAS_TARIFAS_PROCESADO_ALTAS`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 
    base AS (
      SELECT 
        b.marco,
        a.*,
        PORCENTAJE AS UPFRONT --No es porcentaje es un importe entero

      FROM `mm-commissions-reporting.GS.MARCOS_MARBLANCA_NUEVAS_TARIFAS` a
      LEFT JOIN `mm-commissions-reporting.GS.MARCOS_MARBLANCA_POR_TIPO` b ON 
      b.Tipo_paquete = a.tipo_paquete 
      AND b.tipo IN ('ALTAS 2P','ALTAS 3P')
    )
    SELECT *
    FROM base
    WHERE 1=1
      AND marco IS NOT NULL
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.MARCOS_MARBLANCA_NUEVAS_TARIFAS_PROCESADO_FINAL`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS
  SELECT 
    'MARBLANCA' AS marca,
    'INTERNET'  AS service_type,
    a.TARIFF_ID,
    a.TARIFF_DS,
    'MAIN' AS line_type,
    a.marco AS cod_tipo_comisionista,
    0 AS pvp,
    0 AS tramo_1,
    0 AS tramo_2,
    0 AS tramo_3,
    0 AS tramo_4,
    0 AS tramo_5,
    0 AS traslados,
    0 AS migraciones,
    0 AS gestion_canal,
    REPLACE(CAST(PORCENTAJE_PAQUETE_PRORRATEADO*100 AS STRING),'.',',') AS cuota,
    REPLACE(CAST(PORCENTAJE_PAQUETE_PRORRATEADO*100 AS STRING),'.',',') AS cuota_bst,
    0 AS porcentaje_extra_consumo,
    0 AS porcentaje_cartera_voz_y_datos,
    IFNULL(REPLACE(CAST(b.upfront AS STRING),'.',','),'0') AS upfront,
    IFNULL(REPLACE(CAST(b.upfront AS STRING),'.',','),'0') AS upfront_bst,
    '12' AS clawback,
    a.TIPO_PAQUETE AS PAQUETE,
    a.HUELLA AS TIPO,
    a.velocidad AS velocidad,
    a.marco AS marco
  FROM `mm-commissions-reporting.TEMP.MARCOS_MARBLANCA_NUEVAS_TARIFAS_PROCESADO` a
  LEFT JOIN `mm-commissions-reporting.TEMP.MARCOS_MARBLANCA_NUEVAS_TARIFAS_PROCESADO_ALTAS` b ON a.marco = b.marco AND a.tariff_id = b.tariff_id AND a.TIPO_PAQUETE = b.tipo_paquete AND a.huella = b.huella
  WHERE 1=1
    AND a.TARIFF_ID IS NOT NULL 
  ORDER BY a.TIPO_PAQUETE ASC,tariff_id, marco ASC
  ;
END