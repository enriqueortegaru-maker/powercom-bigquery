BEGIN

-- =========================================================================================
-- PASO 1: CREAR TABLA DE COMISIONES EN PROCESO 
-- =========================================================================================
CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO_EN_PROCESO`
AS
WITH
  MAPEO_SIEBEL AS (
    SELECT CAST(agente_venta_id AS STRING) AS agente_venta_id_str, equipo_ds
    FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal`
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY CAST(agente_venta_id AS STRING) ORDER BY equipo_ds ASC
        )
      = 1
  ),
  MAPEO_EKTNET AS (
    SELECT
      p.swInstProdId AS servicio_id,
      CASE m.mmMarcaDesc
        WHEN 'Euskaltel' THEN 'EUSKALTEL'
        WHEN 'Virgin Telco' THEN 'VIRGIN'
        WHEN 'SIMple' THEN 'SIMPLE'
        WHEN 'RACCTEL+' THEN 'RACC'
        WHEN 'Telecable' THEN 'TELECABLE'
        ELSE
          CASE
            WHEN m.mmMarcaId = 7 THEN 'R'
            WHEN m.mmMarcaId = 1 THEN 'VIVA MOBILE'
            END
        END AS marca_calculada,
      p.swChnlPartnerId,
      c.swCoInterno,
      c.swVerticalFocus,
      p.swProviderGrpId,
      COALESCE(v.swNombre, '') AS nombre_personal,
      p.swCreatedBy
    FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swChnlPartnerId = p.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` v
      ON
        v.swPersonalId = p.swProviderGrpId
        AND v.swObjectType = 'CHANNEL_PARTNER'
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
      ON cl.swCustomerId = p.swCustomerId
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m
      ON m.mmMarcaId = cl.mmMarcaId
    QUALIFY
      ROW_NUMBER()
        OVER (PARTITION BY p.swInstProdId ORDER BY p.swChnlPartnerId DESC)
      = 1
  ),
  MAPEO_TCNET AS (
    SELECT
      p.swInstProdId AS servicio_id,
      p.swChnlPartnerId,
      c.swCoInterno,
      c.swVerticalFocus,
      p.swPedId,
      COALESCE(v.swNombre, '') AS swNombre,
      COALESCE(v.swNombreComercial, '') AS swNombreComercial,
      p.swCreatedBy
    FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` c
      ON c.swChnlPartnerId = p.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` v
      ON v.swPersonalId = p.swPedId AND v.swObjectType = 'CHANNEL_PARTNER'
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` cl
      ON cl.swCustomerId = p.swCustomerId
    QUALIFY
      ROW_NUMBER()
        OVER (PARTITION BY p.swInstProdId ORDER BY p.swChnlPartnerId DESC)
      = 1
  ),
  BASE_ELECTRICIDAD AS (
    SELECT
      Id,
      TRIM(UPPER(cups_code)) AS cups_code,
      activation_date,
      tenant_code,
      sfid_id,
      author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity`
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY Id, TRIM(UPPER(cups_code)), activation_date
          ORDER BY Id DESC
        )
      = 1
  ),
  BASE_GAS AS (
    SELECT
      Id,
      TRIM(UPPER(cups_code)) AS cups_code,
      activation_date,
      tenant_code,
      sfid_id,
      author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_gas`
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY Id, TRIM(UPPER(cups_code)), activation_date
          ORDER BY Id DESC
        )
      = 1
  ),
  BASE_SVE AS (
    SELECT
      SAFE_CAST(
        CONCAT(
          REGEXP_EXTRACT(cups_code, r'\d+'),
          CAST(FORMAT_DATE("%m%d", activation_date) AS STRING))
        AS INT64) AS Id_Calculado,
      TRIM(UPPER(cups_code)) AS cups_code,
      activation_date,
      tenant_code,
      sfid_id,
      author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-new-business-reporting.ENERGY.SVE`
    WHERE product = 'SVE'
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY TRIM(UPPER(cups_code)), activation_date
          ORDER BY sfid_id DESC
        )
      = 1
  ),
  BASE_SVG AS (
    SELECT
      SAFE_CAST(
        CONCAT(
          REGEXP_EXTRACT(e.cups_code, r'\d+'),
          CAST(FORMAT_DATE("%m%d", s.data_inici) AS STRING))
        AS INT64) AS Id_Calculado,
      TRIM(UPPER(e.cups_code)) AS cups_code,
      s.data_inici AS activation_date,
      split(e.tenant_code, '_')[OFFSET(0)] AS tenant_code_split,
      e.sfid_id,
      e.author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(e.author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(e.author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-new-business-reporting.ENERGY.ganancia_neta_energia` e
    INNER JOIN `mm-datamart-kd.ENERGY.lucera_gas_additional_services` s
      ON e.id = s.polissa_id
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY TRIM(UPPER(e.cups_code)), s.data_inici
          ORDER BY e.sfid_id DESC
        )
      = 1
  ),
  MAPEO_ELEC_R AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      TRIM(UPPER(c.equipo_ds)) AS equipo_ds,
      c.agente_venta_id,
      e.login_comun
    FROM BASE_ELECTRICIDAD e
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
      ON CAST(c.agente_venta_id AS STRING) = e.sfid_id
  ),
  MAPEO_GAS_R AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      TRIM(UPPER(c.equipo_ds)) AS equipo_ds,
      c.agente_venta_id,
      e.login_comun
    FROM BASE_GAS e
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
      ON CAST(c.agente_venta_id AS STRING) = e.sfid_id
  ),
  MAPEO_ELEC_EKT AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_ELECTRICIDAD e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  ),
  MAPEO_GAS_EKT AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_GAS e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  ),
  MAPEO_SVE_EKT AS (
    SELECT
      e.Id_Calculado AS Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_SVE e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  ),
  MAPEO_SVG_EKT AS (
    SELECT
      e.Id_Calculado AS Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code_split AS tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_SVG e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  )
SELECT
  f.*,
  CASE
    WHEN NOT CONTAINS_SUBSTR(f.claseProducto, "ENERGIA")
      THEN
        CASE
          WHEN
            f.marca_ds IN ("EUSKALTEL", "RACC", "VIRGIN", "SIMPLE")
            OR (
              CONTAINS_SUBSTR(f.marca_ds, "TELECABLE")
              AND (
                CONTAINS_SUBSTR(f.TipoProducto, "MOVIL")
                OR CONTAINS_SUBSTR(f.TipoProducto, "TERMINAL")
                OR CONTAINS_SUBSTR(f.TipoProducto, "DISPOSITIVO")
                OR CONTAINS_SUBSTR(f.TipoProducto, "SEGURO")
                OR CONTAINS_SUBSTR(f.TipoProducto, "SEGURIDAD")
                OR CONTAINS_SUBSTR(f.NombreProducto, 'HEGAN-COMBI')))
            THEN
              STRUCT(
                ekt.swChnlPartnerId AS equipoId,
                ekt.swCoInterno AS equipo,
                ekt.swVerticalFocus AS equipoDesc,
                SAFE_CAST(ekt.swProviderGrpId AS INT64) AS agenteId,
                ekt.nombre_personal AS agente,
                '' AS agenteComercial,
                CAST(NULL AS INT64) AS loginId,
                ekt.swCreatedBy AS login)
          WHEN CONTAINS_SUBSTR(f.marca_ds, "R")
            THEN
              STRUCT(
                CAST(NULL AS INT64) AS equipoId,
                sbl.equipo_ds AS equipo,
                sbl.equipo_ds AS equipoDesc,
                SAFE_CAST(f.agente AS INT64) AS agenteId,
                f.agente AS agente,
                '' AS agenteComercial,
                CAST(NULL AS INT64) AS loginId,
                f.usuarioCreador AS login)
          WHEN
            CONTAINS_SUBSTR(f.marca_ds, "TELECABLE")
            AND NOT (CONTAINS_SUBSTR(f.TipoProducto, "TERMINAL"))
            AND NOT (CONTAINS_SUBSTR(f.TipoProducto, "DISPOSITIVO"))
            AND NOT (
              (
                CONTAINS_SUBSTR(f.TipoProducto, "MOVIL")
                AND TRIM(f.claseProducto) != "SVA"))
            AND NOT (CONTAINS_SUBSTR(f.TipoProducto, "SEGURO"))
            AND NOT (CONTAINS_SUBSTR(f.TipoProducto, "SEGURIDAD"))
            AND NOT (CONTAINS_SUBSTR(f.NombreProducto, 'HEGAN-COMBI'))
            THEN
              STRUCT(
                tc.swChnlPartnerId AS equipoId,
                tc.swCoInterno AS equipo,
                tc.swVerticalFocus AS equipoDesc,
                SAFE_CAST(tc.swPedId AS INT64) AS agenteId,
                tc.swNombre AS agente,
                tc.swNombreComercial AS agenteComercial,
                CAST(NULL AS INT64) AS loginId,
                tc.swCreatedBy AS login)
          END
    WHEN CONTAINS_SUBSTR(f.claseProducto, "ENERGIA")
      THEN
        CASE
          WHEN CONTAINS_SUBSTR(f.marca_ds, "EUSKALTEL")
            THEN
              CASE
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "ELECTRICIDAD")
                  THEN
                    STRUCT(
                      elec_ekt.swChnlPartnerId AS equipoId,
                      elec_ekt.sfid_id AS equipo,
                      elec_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      elec_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      elec_ekt.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "GAS")
                  THEN
                    STRUCT(
                      gas_ekt.swChnlPartnerId AS equipoId,
                      gas_ekt.sfid_id AS equipo,
                      gas_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      gas_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      gas_ekt.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "SVE")
                  THEN
                    STRUCT(
                      sve_ekt.swChnlPartnerId AS equipoId,
                      sve_ekt.sfid_id AS equipo,
                      sve_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      sve_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      sve_ekt.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "SVG")
                  THEN
                    STRUCT(
                      svg_ekt.swChnlPartnerId AS equipoId,
                      svg_ekt.sfid_id AS equipo,
                      svg_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      svg_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      svg_ekt.login_comun AS login)
                END
          WHEN CONTAINS_SUBSTR(f.marca_ds, "R")
            THEN
              CASE
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "ELECTRICIDAD")
                  THEN
                    STRUCT(
                      CAST(NULL AS INT64) AS equipoId,
                      elec_r.equipo_ds AS equipo,
                      elec_r.equipo_ds AS equipoDesc,
                      SAFE_CAST(elec_r.agente_venta_id AS INT64) AS agenteId,
                      CAST(elec_r.agente_venta_id AS STRING) AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      elec_r.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "GAS")
                  THEN
                    STRUCT(
                      CAST(NULL AS INT64) AS equipoId,
                      gas_r.equipo_ds AS equipo,
                      gas_r.equipo_ds AS equipoDesc,
                      SAFE_CAST(gas_r.agente_venta_id AS INT64) AS agenteId,
                      CAST(gas_r.agente_venta_id AS STRING) AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      gas_r.login_comun AS login)
                END
          END
    END AS canalizacion
FROM
  `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO`
    f
LEFT JOIN MAPEO_SIEBEL sbl
  ON sbl.agente_venta_id_str = TRIM(f.agente)
LEFT JOIN MAPEO_EKTNET ekt
  ON ekt.servicio_id = f.idProducto AND ekt.marca_calculada = f.marca_ds
LEFT JOIN MAPEO_TCNET tc
  ON tc.servicio_id = f.idProducto
LEFT JOIN MAPEO_ELEC_R elec_r
  ON
    TRIM(UPPER(f.contrato)) = elec_r.cups_code
    AND f.Fecha_Activacion = elec_r.activation_date
    AND (
      elec_r.Id = f.idProducto
      OR elec_r.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(elec_r.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_GAS_R gas_r
  ON
    TRIM(UPPER(f.contrato)) = gas_r.cups_code
    AND f.Fecha_Activacion = gas_r.activation_date
    AND (
      gas_r.Id = f.idProducto
      OR gas_r.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(gas_r.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_ELEC_EKT elec_ekt
  ON
    TRIM(UPPER(f.contrato)) = elec_ekt.cups_code
    AND f.Fecha_Activacion = elec_ekt.activation_date
    AND (
      elec_ekt.Id = f.idProducto
      OR elec_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(elec_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_GAS_EKT gas_ekt
  ON
    TRIM(UPPER(f.contrato)) = gas_ekt.cups_code
    AND f.Fecha_Activacion = gas_ekt.activation_date
    AND (
      gas_ekt.Id = f.idProducto
      OR gas_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(gas_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_SVE_EKT sve_ekt
  ON
    TRIM(UPPER(f.contrato)) = sve_ekt.cups_code
    AND f.Fecha_Activacion = sve_ekt.activation_date
    AND (
      sve_ekt.Id = f.idProducto
      OR sve_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(sve_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_SVG_EKT svg_ekt
  ON
    TRIM(UPPER(f.contrato)) = svg_ekt.cups_code
    AND f.Fecha_Activacion = svg_ekt.activation_date
    AND (
      svg_ekt.Id = f.idProducto
      OR svg_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(svg_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
WHERE
  f.mes_factura_dt = DATE_TRUNC(
    PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING)), MONTH);

-- =========================================================================================
-- PASO 2: CREAR TABLA DE DECOMISIONES EN PROCESO 
-- =========================================================================================
CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO_EN_PROCESO`
AS
WITH
  MAPEO_SIEBEL AS (
    SELECT CAST(agente_venta_id AS STRING) AS agente_venta_id_str, equipo_ds
    FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal`
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY CAST(agente_venta_id AS STRING) ORDER BY equipo_ds ASC
        )
      = 1
  ),
  MAPEO_EKTNET AS (
    SELECT
      p.swInstProdId AS servicio_id,
      CASE m.mmMarcaDesc
        WHEN 'Euskaltel' THEN 'EUSKALTEL'
        WHEN 'Virgin Telco' THEN 'VIRGIN'
        WHEN 'SIMple' THEN 'SIMPLE'
        WHEN 'RACCTEL+' THEN 'RACC'
        WHEN 'Telecable' THEN 'TELECABLE'
        ELSE
          CASE
            WHEN m.mmMarcaId = 7 THEN 'R'
            WHEN m.mmMarcaId = 1 THEN 'VIVA MOBILE'
            END
        END AS marca_calculada,
      p.swChnlPartnerId,
      c.swCoInterno,
      c.swVerticalFocus,
      p.swProviderGrpId,
      COALESCE(v.swNombre, '') AS nombre_personal,
      p.swCreatedBy
    FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swChnlPartnerId = p.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` v
      ON
        v.swPersonalId = p.swProviderGrpId
        AND v.swObjectType = 'CHANNEL_PARTNER'
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl
      ON cl.swCustomerId = p.swCustomerId
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m
      ON m.mmMarcaId = cl.mmMarcaId
    QUALIFY
      ROW_NUMBER()
        OVER (PARTITION BY p.swInstProdId ORDER BY p.swChnlPartnerId DESC)
      = 1
  ),
  MAPEO_TCNET AS (
    SELECT
      p.swInstProdId AS servicio_id,
      p.swChnlPartnerId,
      c.swCoInterno,
      c.swVerticalFocus,
      p.swPedId,
      COALESCE(v.swNombre, '') AS swNombre,
      COALESCE(v.swNombreComercial, '') AS swNombreComercial,
      p.swCreatedBy
    FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_canal_asociado` c
      ON c.swChnlPartnerId = p.swChnlPartnerId
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_personal_externo` v
      ON v.swPersonalId = p.swPedId AND v.swObjectType = 'CHANNEL_PARTNER'
    INNER JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_cliente` cl
      ON cl.swCustomerId = p.swCustomerId
    QUALIFY
      ROW_NUMBER()
        OVER (PARTITION BY p.swInstProdId ORDER BY p.swChnlPartnerId DESC)
      = 1
  ),
  BASE_ELECTRICIDAD AS (
    SELECT
      Id,
      TRIM(UPPER(cups_code)) AS cups_code,
      activation_date,
      tenant_code,
      sfid_id,
      author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_electricity`
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY Id, TRIM(UPPER(cups_code)), activation_date
          ORDER BY Id DESC
        )
      = 1
  ),
  BASE_GAS AS (
    SELECT
      Id,
      TRIM(UPPER(cups_code)) AS cups_code,
      activation_date,
      tenant_code,
      sfid_id,
      author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-datamart-kd.ENERGY.lucera_polissas_gas`
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY Id, TRIM(UPPER(cups_code)), activation_date
          ORDER BY Id DESC
        )
      = 1
  ),
  BASE_SVE AS (
    SELECT
      SAFE_CAST(
        CONCAT(
          REGEXP_EXTRACT(cups_code, r'\d+'),
          CAST(FORMAT_DATE("%m%d", activation_date) AS STRING))
        AS INT64) AS Id_Calculado,
      TRIM(UPPER(cups_code)) AS cups_code,
      activation_date,
      tenant_code,
      sfid_id,
      author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-new-business-reporting.ENERGY.SVE`
    WHERE product = 'SVE'
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY TRIM(UPPER(cups_code)), activation_date
          ORDER BY sfid_id DESC
        )
      = 1
  ),
  BASE_SVG AS (
    SELECT
      SAFE_CAST(
        CONCAT(
          REGEXP_EXTRACT(e.cups_code, r'\d+'),
          CAST(FORMAT_DATE("%m%d", s.data_inici) AS STRING))
        AS INT64) AS Id_Calculado,
      TRIM(UPPER(e.cups_code)) AS cups_code,
      s.data_inici AS activation_date,
      split(e.tenant_code, '_')[OFFSET(0)] AS tenant_code_split,
      e.sfid_id,
      e.author_id,
      COALESCE(
        SPLIT(UPPER(SPLIT(e.author_id, "@")[OFFSET(0)]), '.')[OFFSET(0)], '')
        AS agente_euskaltel,
      COALESCE(UPPER(SPLIT(e.author_id, "@")[OFFSET(0)]), '') AS login_comun
    FROM `mm-new-business-reporting.ENERGY.ganancia_neta_energia` e
    INNER JOIN `mm-datamart-kd.ENERGY.lucera_gas_additional_services` s
      ON e.id = s.polissa_id
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY TRIM(UPPER(e.cups_code)), s.data_inici
          ORDER BY e.sfid_id DESC
        )
      = 1
  ),
  MAPEO_ELEC_R AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      TRIM(UPPER(c.equipo_ds)) AS equipo_ds,
      c.agente_venta_id,
      e.login_comun
    FROM BASE_ELECTRICIDAD e
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
      ON CAST(c.agente_venta_id AS STRING) = e.sfid_id
  ),
  MAPEO_GAS_R AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      TRIM(UPPER(c.equipo_ds)) AS equipo_ds,
      c.agente_venta_id,
      e.login_comun
    FROM BASE_GAS e
    LEFT JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_r_30_maestro_canal` c
      ON CAST(c.agente_venta_id AS STRING) = e.sfid_id
  ),
  MAPEO_ELEC_EKT AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_ELECTRICIDAD e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  ),
  MAPEO_GAS_EKT AS (
    SELECT
      e.Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_GAS e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  ),
  MAPEO_SVE_EKT AS (
    SELECT
      e.Id_Calculado AS Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_SVE e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  ),
  MAPEO_SVG_EKT AS (
    SELECT
      e.Id_Calculado AS Id,
      e.cups_code,
      e.activation_date,
      e.tenant_code_split AS tenant_code,
      c.swChnlPartnerId,
      e.sfid_id,
      TRIM(UPPER(c.swVerticalFocus)) AS swVerticalFocus,
      e.agente_euskaltel,
      e.login_comun
    FROM BASE_SVG e
    LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` c
      ON c.swCoInterno = e.sfid_id
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_personal_externo` p
      ON
        TRIM(UPPER(p.swNombre)) = e.agente_euskaltel
        AND p.swObjectType = "CHANNEL_PARTNER"
  )
SELECT
  f.*,
  CASE
    WHEN NOT CONTAINS_SUBSTR(f.claseProducto, "ENERGIA")
      THEN
        CASE
          WHEN
            NOT CONTAINS_SUBSTR(f.marca_ds, "R")
            AND (
              (NOT CONTAINS_SUBSTR(f.marca_ds, "TELECABLE"))
              OR (
                CONTAINS_SUBSTR(f.marca_ds, "TELECABLE")
                AND (
                  CONTAINS_SUBSTR(f.claseProducto, "MOVILES")
                  OR CONTAINS_SUBSTR(f.claseProducto, "TERMINAL")
                  OR CONTAINS_SUBSTR(f.NombreProducto, 'HEGAN-COMBI'))))
            THEN
              STRUCT(
                ekt.swChnlPartnerId AS equipoId,
                ekt.swCoInterno AS equipo,
                ekt.swVerticalFocus AS equipoDesc,
                SAFE_CAST(ekt.swProviderGrpId AS INT64) AS agenteId,
                ekt.nombre_personal AS agente,
                '' AS agenteComercial,
                CAST(NULL AS INT64) AS loginId,
                ekt.swCreatedBy AS login)
          WHEN CONTAINS_SUBSTR(f.marca_ds, "R")
            THEN
              STRUCT(
                CAST(NULL AS INT64) AS equipoId,
                sbl.equipo_ds AS equipo,
                sbl.equipo_ds AS equipoDesc,
                SAFE_CAST(f.agente AS INT64) AS agenteId,
                f.agente AS agente,
                '' AS agenteComercial,
                CAST(NULL AS INT64) AS loginId,
                f.usuarioCreador AS login)
          WHEN
            (
              CONTAINS_SUBSTR(f.marca_ds, "TELECABLE")
              AND NOT (
                CONTAINS_SUBSTR(f.claseProducto, "MOVILES")
                OR CONTAINS_SUBSTR(f.claseProducto, "TERMINAL")
                OR CONTAINS_SUBSTR(f.NombreProducto, 'HEGAN-COMBI')))
            THEN
              STRUCT(
                tc.swChnlPartnerId AS equipoId,
                tc.swCoInterno AS equipo,
                tc.swVerticalFocus AS equipoDesc,
                SAFE_CAST(tc.swPedId AS INT64) AS agenteId,
                tc.swNombre AS agente,
                tc.swNombreComercial AS agenteComercial,
                CAST(NULL AS INT64) AS loginId,
                tc.swCreatedBy AS login)
          END
    WHEN CONTAINS_SUBSTR(f.claseProducto, "ENERGIA")
      THEN
        CASE
          WHEN CONTAINS_SUBSTR(f.marca_ds, "EUSKALTEL")
            THEN
              CASE
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "ELECTRICIDAD")
                  THEN
                    STRUCT(
                      elec_ekt.swChnlPartnerId AS equipoId,
                      elec_ekt.sfid_id AS equipo,
                      elec_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      elec_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      elec_ekt.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "GAS")
                  THEN
                    STRUCT(
                      gas_ekt.swChnlPartnerId AS equipoId,
                      gas_ekt.sfid_id AS equipo,
                      gas_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      gas_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      gas_ekt.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "SVE")
                  THEN
                    STRUCT(
                      sve_ekt.swChnlPartnerId AS equipoId,
                      sve_ekt.sfid_id AS equipo,
                      sve_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      sve_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      sve_ekt.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "SVG")
                  THEN
                    STRUCT(
                      svg_ekt.swChnlPartnerId AS equipoId,
                      svg_ekt.sfid_id AS equipo,
                      svg_ekt.swVerticalFocus AS equipoDesc,
                      CAST(NULL AS INT64) AS agenteId,
                      svg_ekt.agente_euskaltel AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      svg_ekt.login_comun AS login)
                END
          WHEN CONTAINS_SUBSTR(f.marca_ds, "R")
            THEN
              CASE
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "ELECTRICIDAD")
                  THEN
                    STRUCT(
                      CAST(NULL AS INT64) AS equipoId,
                      elec_r.equipo_ds AS equipo,
                      elec_r.equipo_ds AS equipoDesc,
                      SAFE_CAST(elec_r.agente_venta_id AS INT64) AS agenteId,
                      CAST(elec_r.agente_venta_id AS STRING) AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      elec_r.login_comun AS login)
                WHEN CONTAINS_SUBSTR(f.TipoProducto, "GAS")
                  THEN
                    STRUCT(
                      CAST(NULL AS INT64) AS equipoId,
                      gas_r.equipo_ds AS equipo,
                      gas_r.equipo_ds AS equipoDesc,
                      SAFE_CAST(gas_r.agente_venta_id AS INT64) AS agenteId,
                      CAST(gas_r.agente_venta_id AS STRING) AS agente,
                      '' AS agenteComercial,
                      CAST(NULL AS INT64) AS loginId,
                      gas_r.login_comun AS login)
                END
          END
    ELSE NULL
    END AS canalizacion
FROM
  `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_FACTURADO`
    f
LEFT JOIN MAPEO_SIEBEL sbl
  ON sbl.agente_venta_id_str = TRIM(f.agente)
LEFT JOIN MAPEO_EKTNET ekt
  ON ekt.servicio_id = f.idProducto AND ekt.marca_calculada = f.marca_ds
LEFT JOIN MAPEO_TCNET tc
  ON tc.servicio_id = f.idProducto
LEFT JOIN MAPEO_ELEC_R elec_r
  ON
    TRIM(UPPER(f.contrato)) = elec_r.cups_code
    AND f.Fecha_Activacion = elec_r.activation_date
    AND (
      elec_r.Id = f.idProducto
      OR elec_r.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(elec_r.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_GAS_R gas_r
  ON
    TRIM(UPPER(f.contrato)) = gas_r.cups_code
    AND f.Fecha_Activacion = gas_r.activation_date
    AND (
      gas_r.Id = f.idProducto
      OR gas_r.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(gas_r.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_ELEC_EKT elec_ekt
  ON
    TRIM(UPPER(f.contrato)) = elec_ekt.cups_code
    AND f.Fecha_Activacion = elec_ekt.activation_date
    AND (
      elec_ekt.Id = f.idProducto
      OR elec_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(elec_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_GAS_EKT gas_ekt
  ON
    TRIM(UPPER(f.contrato)) = gas_ekt.cups_code
    AND f.Fecha_Activacion = gas_ekt.activation_date
    AND (
      gas_ekt.Id = f.idProducto
      OR gas_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(gas_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_SVE_EKT sve_ekt
  ON
    TRIM(UPPER(f.contrato)) = sve_ekt.cups_code
    AND f.Fecha_Activacion = sve_ekt.activation_date
    AND (
      sve_ekt.Id = f.idProducto
      OR sve_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(sve_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
LEFT JOIN MAPEO_SVG_EKT svg_ekt
  ON
    TRIM(UPPER(f.contrato)) = svg_ekt.cups_code
    AND f.Fecha_Activacion = svg_ekt.activation_date
    AND (
      svg_ekt.Id = f.idProducto
      OR svg_ekt.cups_code LIKE CONCAT('%', CAST(f.idProducto AS STRING), '%'))
    AND UPPER(TRIM(svg_ekt.tenant_code)) = UPPER(TRIM(f.marca_ds))
WHERE
  f.mes_factura_dt = DATE_TRUNC(
    PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING)), MONTH);

-- =========================================================================================
-- PASO 3: ACTUALIZAR TABLAS HISTÓRICAS FINALES
-- =========================================================================================
DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO`
WHERE mes_factura_dt = PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));

INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO`
SELECT *
FROM
  `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO_EN_PROCESO`;

DELETE FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO`
WHERE mes_factura_dt = PARSE_DATE("%Y%m%d", CAST(VDESDE AS STRING));

INSERT INTO `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO`
SELECT *
FROM
  `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO_EN_PROCESO`;

END