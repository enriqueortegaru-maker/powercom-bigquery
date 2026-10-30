BEGIN
    DECLARE
      DESDE_DT,
      HASTA_DT,
      DESDE_6M_DT date;
      DECLARE MES_DECOMISION INT64;
    --DECLARE DESDE, HASTA, MES_DECOMISION INT64;
    --SET DESDE=20221001;
    --SET HASTA=20221020;    

    SET
      HASTA_DT = parse_date ('%Y%m%d',
        CAST ( HASTA AS string) );
    SET
      DESDE_DT = parse_date ('%Y%m%d',
        CAST ( DESDE AS string) );
    SET
      DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);
    SET MES_DECOMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);


  --- PASO 1: CREAR LA TABLA CLAWBACK
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS
    SELECT
      DISTINCT a.* REPLACE(
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * importe AS importe,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * importe_nivel AS importe_nivel,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * bono_comercial AS bono_comercial,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * bono_calidad AS bono_calidad,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * total AS total ),
      COALESCE(cpt.swCausaBaja, cpk.swCausaBaja) CausaBaja,
      COALESCE(cpt.swNombreCausaGral, cpk.swNombreCausaGral) CausaBajaGeneral
    FROM
      `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO` a
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` cpt
    ON
      a.IdProducto = cpt.swInstProdId
      AND a.idCatalogo = CAST(cpt.swProdReleaseId AS string)
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` cpk
    ON
      a.idProducto = cpk.swInstProdId
      AND a.idCatalogo = CAST(cpk.swProdReleaseId AS string)
    WHERE
      ((CAST(cpt.swFechaDesinstalacion AS date) BETWEEN DESDE_DT
          AND HASTA_DT
          AND cpt.swCopiaProdId IS NULL)
        OR (CAST(cpk.swFechaDesinstalacion AS date) BETWEEN DESDE_DT
          AND HASTA_DT
          AND cpk.swCopiaProdId IS NULL))
      AND Fecha_Activacion >= DESDE_6M_DT
      AND Fecha_Activacion < DESDE_DT;


    --- PASO 2: NEGATIVIZAR IMPORTE

    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET importe = SAFE_NEGATE(importe) where importe!=0;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET importe_nivel = SAFE_NEGATE(importe_nivel) where importe_nivel!=0;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET total = SAFE_NEGATE(total) where total!=0;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET bono_comercial = SAFE_NEGATE(bono_comercial) where bono_comercial!=0;            
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET bono_calidad = SAFE_NEGATE(bono_calidad) where bono_calidad!=0;            

    --- PASO 2 : ENRIQUEZCO REGISTROS CON DATO DE MES DE DECOMISION
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` ADD COLUMN mes_decomision_id INT64;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET mes_decomision_id = MES_DECOMISION WHERE mes_decomision_id is null;




END