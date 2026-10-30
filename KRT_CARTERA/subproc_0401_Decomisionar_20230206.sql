BEGIN
    DECLARE
      DESDE_DT,
      HASTA_DT,
      DESDE_6M_DT date;
    DECLARE MES_DECOMISION INT64;
    --DECLARE DESDE, HASTA, MES_DECOMISION INT64;
    --SET DESDE=20221001;
    --SET HASTA=20221025;    

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
      EXTRACT(DATE FROM COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion)) as FechaDesinstalacion,        
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

    --- PASO 3 : AÑADO NUEVOS CAMPOS
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` ADD COLUMN mes_decomision_id INT64,  ADD COLUMN clase_mm_com STRING, ADD COLUMN desc_mm_com STRING;
    
    --- PASO 4 : ENRIQUEZCO REGISTROS CON DATO DE MES DE DECOMISION, CLASE_MM y DESC_MM
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET mes_decomision_id = MES_DECOMISION WHERE mes_decomision_id is null;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET clase_mm_com = clase_mm WHERE clase_mm is not null;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET desc_mm_com = desc_mm WHERE desc_mm is not null;

    --- PASO 5 : ACTUALIZO CAMPOS DE TIPIFICACION DE PARA REGISTRO DE TIPIFICACION DE DECOMISION 
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET clase_mm=NULL  WHERE clase_mm is not null;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET desc_mm=NULL  WHERE desc_mm is not null;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET desc_mm=
    CASE 
      WHEN desc_mm_com='A - Portabilidad Fijo' THEN 'E - Clawback Portabilidad Fijo'
      WHEN desc_mm_com='A - Portabilidad Movil Postpago' THEN 'E - Clawback Portabilidad Movil Postpago'
      WHEN desc_mm_com='A - Servicio Fijo' THEN 'E - Clawback Servicio Fijo'
      WHEN desc_mm_com='A - Servicio acceso BA' THEN 'E - Clawback Servicio acceso BA'
      WHEN desc_mm_com='A - Servicio Movil Postpago' THEN 'E - Clawback Servicio Movil Postpago'
      WHEN desc_mm_com='B - Alarma' THEN 'E - Clawback Alarma'
      WHEN desc_mm_com='B - Bono movil' THEN 'E - Clawback Bono movil'
      WHEN desc_mm_com='B - Ip Fija' THEN 'E - Clawback Ip Fija'
      WHEN desc_mm_com='B - Mantenimiento' THEN 'E - Clawback Mantenimiento'
      WHEN desc_mm_com='B - Mifi' THEN 'E - Clawback Mifi'
      WHEN desc_mm_com='B - Netflix' THEN 'E - Clawback Netflix'
      WHEN desc_mm_com='B - Seguridad' THEN 'E - Clawback Seguridad'
      WHEN desc_mm_com='B - Seguro movil' THEN 'E - Clawback Seguro movil'
      WHEN desc_mm_com='B - Smartwatch' THEN 'E - Clawback Smartwatch'
      WHEN desc_mm_com='B - Tarjeta Sim' THEN 'E - Clawback Tarjeta Sim'
      WHEN desc_mm_com='B - Television acceso' THEN 'E - Clawback Television acceso'
      WHEN desc_mm_com='B - Television contenido' THEN 'E - Clawback Television contenido'
      WHEN desc_mm_com='B - Terminales' THEN 'E - Clawback Terminales'
      WHEN desc_mm_com='B - Wifi' THEN 'E - Clawback Wifi'
      WHEN desc_mm_com='D - Rappel Teorico' THEN 'E - Clawback Rappel Teorico'
      ELSE 'E - Clawback Otros'
    END
    WHERE desc_mm is null;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET clase_mm = 'E - Clawback' WHERE desc_mm like 'E - %';
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET clase_mm = 'H - Clawback gestion de canal' WHERE desc_mm like 'H - %';
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET clase_mm = 'Z - Ajustes' WHERE desc_mm like 'Z - %';  
    UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET clase_mm = 'O - Otros' WHERE lower(desc_mm) like '%otros%';


END