BEGIN

DECLARE mes_int, mes_ant INT64;
DECLARE mes DATE;

SET mes = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH);
SET mes_int = CAST(FORMAT_DATE('%Y%m',DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)) AS INT64);
SET mes_ant = CAST(FORMAT_DATE('%Y%m',DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 2 MONTH)) AS INT64);

-- CALL`mm-commissions-reporting.B2B.pr_CALT_marco_porcentajes`()

-- Si no existen transacciones para el mes, generamos la tabla
  IF NOT EXISTS(
      SELECT *
      FROM `mm-commissions-reporting.COMISIONES.transacciones`
      WHERE canal IN ('CM','CALT')
        AND id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH)) AS INT64)
        AND (commission_id LIKE 'ARCA%'AND commission_id LIKE CONCAT("ARCA_",mes_int,"_%"))
        AND mes_liquidado = mes
      GROUP BY ALL
  ) THEN

  --Lanzamos la actualización de la tabla de DEALERS_ALTERNOS para tener la última foto
  CALL `mm-commissions-reporting.B2B.pr_dealers_ALTERNOS_CM_MB`();

  DELETE `mm-commissions-reporting.B2B.MARCO_PORCENTAJES_CALT`
  WHERE id_mes = mes_int
  ;

  INSERT INTO `mm-commissions-reporting.B2B.MARCO_PORCENTAJES_CALT`

    WITH info_base AS (
      SELECT 
        cif,
        `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(razon_social) AS razon_social,
        SUM(imp_without_tax) AS imp_without_tax 
      FROM (
        SELECT 
          cif, 
          b.razon_social,
          SUM(imp_without_tax) AS imp_without_tax
        FROM `mm-commissions-reporting.B2B.row_comisiones_base_arca_*` a
        JOIN `mm-commissions-reporting.B2B.DEALERS_ALTERNOS_CM_MB` b ON a.CLIENTE = b.id_comisionista
        WHERE 1=1
          AND _TABLE_SUFFIX = CONCAT(mes_int,'01')
          AND b.agrupacion_canal = 'B2B - Cablemovil' 
          AND a.origen_info = 'mes_actual'
        GROUP BY ALL

        UNION ALL

        SELECT 
          cif, 
          b.razon_social,
          SUM(imp_without_tax) AS imp_without_tax
        FROM `mm-commissions-reporting.B2B.row_comisiones_base_armb_*` a
        JOIN `mm-commissions-reporting.B2B.DEALERS_ALTERNOS_CM_MB` b ON a.current_sfid_id = b.id_comisionista
        WHERE 1=1
          AND _TABLE_SUFFIX = CONCAT(mes_int,'01')
          AND b.agrupacion_canal = 'B2B - Marblanca' 
        GROUP BY ALL
      )
      GROUP BY ALL
    )

    SELECT 
      mes_int AS id_mes,
      c.id_comisionista,
      d.canal,
      info_base.cif,
      info_base.razon_social,
      info_base.imp_without_tax,
      `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(b.tramo) AS tramo,
      b.porcentaje AS porcentaje_actual,
      e.porcentaje_actual AS porcentaje_anterior,
      CURRENT_TIMESTAMP() AS insert_dt
    FROM info_base 
    LEFT JOIN `mm-commissions-reporting.GS.MARCO_TARIFAS_B2B_CALT` b ON info_base.imp_without_tax BETWEEN b.facturacion_desde AND b.facturacion_hasta
    LEFT JOIN `mm-commissions-reporting.B2B.DEALERS_ALTERNOS_CM_MB` c ON info_base.cif = c.cif
    JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` d ON c.id_comisionista = d.id_comisionista AND d.canal = 'CALT'
    LEFT JOIN `mm-commissions-reporting.B2B.MARCO_PORCENTAJES_CALT` e ON e.id_comisionista = c.id_comisionista AND id_mes = mes_ant
    WHERE 1=1
      AND c.agrupacion_canal = 'B2B - Cablemovil'
    GROUP BY ALL
  ;
  END IF;
END