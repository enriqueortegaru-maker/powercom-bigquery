BEGIN

  DECLARE VFECHA_CALC_CAP_DT, VFECHA_CALC_CAR_DT DATE;
  --DECLARE VDESDE INT64 DEFAULT 20260901;

  SET VFECHA_CALC_CAP_DT = (
    SELECT MAX(fecha_calc_dt)
    FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES`
    WHERE desde = VDESDE
  );
  SET VFECHA_CALC_CAR_DT = (
    SELECT MAX(fecha_calc_dt)
    FROM `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CANALES`
    WHERE desde = VDESDE
  );

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_COMISIONES_CANALIZADAS_CTX` AS

  WITH

  -- CAPTACION parametric channel catalog (latest snapshot for VDESDE)
  cap AS (
    SELECT
      marca_ds,
      canal_ds,
      subcanal_ds,
      nombre_distribuidor_ds,
      ARRAY_TO_STRING(
        ARRAY_AGG(DISTINCT marco_retributivo_ds ORDER BY marco_retributivo_ds), ','
      ) AS marco
    FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES`
    WHERE fecha_calc_dt = VFECHA_CALC_CAP_DT
      AND desde = VDESDE
    GROUP BY 1, 2, 3, 4
  ),

  -- CARTERA parametric channel catalog (latest snapshot for VDESDE)
  car AS (
    SELECT
      marca_ds,
      canal,
      subcanal,
      nombre_distribuidor,
      ARRAY_TO_STRING(
        ARRAY_AGG(DISTINCT agrupador_mr ORDER BY agrupador_mr), ','
      ) AS marco
    FROM `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CANALES`
    WHERE fecha_calc_dt = VFECHA_CALC_CAR_DT
      AND desde = VDESDE
    GROUP BY 1, 2, 3, 4
  ),

  -- Canonical commercial hierarchy keyed by (crm, marca_ds, sfid_id).
  -- Rule A — EKTNET | SIEBEL | TCNET : join on ct.sfid; extract ct.canal_ds / ct.subcanal_ds / ct.distribuidor_ds
  --          ('SIEBEL' is the crm value for R-brand in tr_crm_norte_canalizacion_ct_mo; 'R' is marca_ds, not crm)
  -- Rule B — MYSIM                   : join on mo.sfid; extract mo.N1 / mo.N2 / mo.nombre_acreedor_ds
  sfid_hier AS (
    SELECT
      crm,
      marca_ds,
      CASE UPPER(TRIM(crm)) WHEN 'MYSIM' THEN mo.sfid              ELSE ct.sfid             END AS sfid_id,
      CASE UPPER(TRIM(crm)) WHEN 'MYSIM' THEN mo.N1                ELSE ct.canal_ds         END AS canal_h,
      CASE UPPER(TRIM(crm)) WHEN 'MYSIM' THEN mo.N2                ELSE ct.subcanal_ds      END AS subcanal_h,
      CASE UPPER(TRIM(crm)) WHEN 'MYSIM' THEN mo.nombre_acreedor_ds ELSE ct.distribuidor_ds END AS distribuidor_h
    FROM `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mo`
    WHERE UPPER(TRIM(crm)) IN ('EKTNET', 'SIEBEL', 'TCNET', 'MYSIM')
      AND (
           (UPPER(TRIM(crm)) =  'MYSIM' AND mo.sfid IS NOT NULL)
        OR (UPPER(TRIM(crm)) != 'MYSIM' AND ct.sfid IS NOT NULL)
      )
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY crm, marca_ds,
                   CASE UPPER(TRIM(crm)) WHEN 'MYSIM' THEN mo.sfid ELSE ct.sfid END
      ORDER BY     CASE UPPER(TRIM(crm))
                     WHEN 'MYSIM' THEN CASE WHEN mo.sfid IS NOT NULL THEN 1 ELSE 2 END
                     ELSE              CASE WHEN ct.sfid IS NOT NULL THEN 1 ELSE 2 END
                   END
    ) = 1
  )

  /* ================================================================
     ENERGY_LUZ_norte
     ================================================================ */

  SELECT
    'CAPTACION' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    cap.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN cap
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(cap.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(cap.canal_ds))
    AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                             = UPPER(TRIM(cap.subcanal_ds)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))

  UNION ALL

  SELECT
    'CARTERA' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    car.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN car
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(car.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(car.canal))
    AND (UPPER(TRIM(car.subcanal)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                                = UPPER(TRIM(car.subcanal)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(car.nombre_distribuidor)))
  WHERE NOT EXISTS (
    SELECT 1 FROM cap
    WHERE UPPER(TRIM(e.marca))                                                                                                                        = UPPER(TRIM(cap.marca_ds))
      AND UPPER(TRIM(h.canal_h))                                                                                                                      = UPPER(TRIM(cap.canal_ds))
      AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                           = UPPER(TRIM(cap.subcanal_ds)))
      AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                    = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))
  )

  UNION ALL

  /* ================================================================
     ENERGY_GAS_norte
     ================================================================ */

  SELECT
    'CAPTACION' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    cap.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_GAS_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN cap
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(cap.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(cap.canal_ds))
    AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                             = UPPER(TRIM(cap.subcanal_ds)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))

  UNION ALL

  SELECT
    'CARTERA' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    car.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_GAS_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN car
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(car.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(car.canal))
    AND (UPPER(TRIM(car.subcanal)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                                = UPPER(TRIM(car.subcanal)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(car.nombre_distribuidor)))
  WHERE NOT EXISTS (
    SELECT 1 FROM cap
    WHERE UPPER(TRIM(e.marca))                                                                                                                        = UPPER(TRIM(cap.marca_ds))
      AND UPPER(TRIM(h.canal_h))                                                                                                                      = UPPER(TRIM(cap.canal_ds))
      AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                           = UPPER(TRIM(cap.subcanal_ds)))
      AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                    = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))
  )

  UNION ALL

  /* ================================================================
     ENERGY_sve_norte
     ================================================================ */

  SELECT
    'CAPTACION' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    cap.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_sve_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN cap
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(cap.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(cap.canal_ds))
    AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                             = UPPER(TRIM(cap.subcanal_ds)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))

  UNION ALL

  SELECT
    'CARTERA' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    car.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_sve_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN car
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(car.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(car.canal))
    AND (UPPER(TRIM(car.subcanal)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                                = UPPER(TRIM(car.subcanal)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(car.nombre_distribuidor)))
  WHERE NOT EXISTS (
    SELECT 1 FROM cap
    WHERE UPPER(TRIM(e.marca))                                                                                                                        = UPPER(TRIM(cap.marca_ds))
      AND UPPER(TRIM(h.canal_h))                                                                                                                      = UPPER(TRIM(cap.canal_ds))
      AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                           = UPPER(TRIM(cap.subcanal_ds)))
      AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                    = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))
  )

  UNION ALL

  /* ================================================================
     ENERGY_svg_norte
     ================================================================ */

  SELECT
    'CAPTACION' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    cap.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_svg_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN cap
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(cap.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(cap.canal_ds))
    AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                             = UPPER(TRIM(cap.subcanal_ds)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))

  UNION ALL

  SELECT
    'CARTERA' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    car.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_svg_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN car
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(car.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(car.canal))
    AND (UPPER(TRIM(car.subcanal)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                                = UPPER(TRIM(car.subcanal)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(car.nombre_distribuidor)))
  WHERE NOT EXISTS (
    SELECT 1 FROM cap
    WHERE UPPER(TRIM(e.marca))                                                                                                                        = UPPER(TRIM(cap.marca_ds))
      AND UPPER(TRIM(h.canal_h))                                                                                                                      = UPPER(TRIM(cap.canal_ds))
      AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                           = UPPER(TRIM(cap.subcanal_ds)))
      AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                    = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))
  )

  UNION ALL

  /* ================================================================
     ENERGY_LUZ_reparto_norte
     ================================================================ */

  SELECT
    'CAPTACION' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    cap.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_LUZ_reparto_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN cap
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(cap.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(cap.canal_ds))
    AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                             = UPPER(TRIM(cap.subcanal_ds)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))

  UNION ALL

  SELECT
    'CARTERA' AS tipo,
    `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) AS clase,
    e.*,
    car.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_LUZ_reparto_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN car
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(car.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(car.canal))
    AND (UPPER(TRIM(car.subcanal)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                                = UPPER(TRIM(car.subcanal)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(car.nombre_distribuidor)))
  WHERE NOT EXISTS (
    SELECT 1 FROM cap
    WHERE UPPER(TRIM(e.marca))                                                                                                                        = UPPER(TRIM(cap.marca_ds))
      AND UPPER(TRIM(h.canal_h))                                                                                                                      = UPPER(TRIM(cap.canal_ds))
      AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                           = UPPER(TRIM(cap.subcanal_ds)))
      AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                    = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))
  )

  UNION ALL

  /* ================================================================
     ENERGY_RAPPEL_OBJETIVO_norte
     clase comes pre-computed from the source table; extra fields
     (ratio, base, maximo, importe) are excluded to maintain the
     common output schema of ENERGIA_COMISIONES_CANALIZADAS_CTX.
     ================================================================ */

  SELECT
    'CAPTACION' AS tipo,
    e.clase,
    e.* EXCEPT (clase, distribuidor_norm, ratio, base, maximo, importe),
    cap.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_RAPPEL_OBJETIVO_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN cap
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(cap.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(cap.canal_ds))
    AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                             = UPPER(TRIM(cap.subcanal_ds)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))

  UNION ALL

  SELECT
    'CARTERA' AS tipo,
    e.clase,
    e.* EXCEPT (clase, distribuidor_norm, ratio, base, maximo, importe),
    car.marco,
    `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) AS distribuidor_norm
  FROM `mm-commissions-reporting.TEMP.ENERGY_RAPPEL_OBJETIVO_norte` e
  INNER JOIN sfid_hier h
    ON  UPPER(TRIM(e.crm))   = UPPER(TRIM(h.crm))
    AND UPPER(TRIM(e.marca)) = UPPER(TRIM(h.marca_ds))
    AND e.sfid_id            = h.sfid_id
  INNER JOIN car
    ON  UPPER(TRIM(e.marca))                                                                                                                          = UPPER(TRIM(car.marca_ds))
    AND UPPER(TRIM(h.canal_h))                                                                                                                        = UPPER(TRIM(car.canal))
    AND (UPPER(TRIM(car.subcanal)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                                = UPPER(TRIM(car.subcanal)))
    AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                      = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(car.nombre_distribuidor)))
  WHERE NOT EXISTS (
    SELECT 1 FROM cap
    WHERE UPPER(TRIM(e.marca))                                                                                                                        = UPPER(TRIM(cap.marca_ds))
      AND UPPER(TRIM(h.canal_h))                                                                                                                      = UPPER(TRIM(cap.canal_ds))
      AND (UPPER(TRIM(cap.subcanal_ds)) = 'X' OR UPPER(TRIM(h.subcanal_h))                                                                           = UPPER(TRIM(cap.subcanal_ds)))
      AND UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(h.distribuidor_h)))                                    = UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(cap.nombre_distribuidor_ds)))
  );

END