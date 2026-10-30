BEGIN

    --- PASO 1: CREO TABLA MARCO_RETRIBUTIVO_TELEVENTASxCANAL
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS
    SELECT
      a.*,  mr.agrupador_mr MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, nivel_tvt_ups_virgin
    FROM (
      SELECT c.*,
        CASE
          WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = UPPER(c.agente) AND (TELEVENTA='S' OR tvt_ups_virgin = 'S') ) = 1 THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = UPPER(c.agente) AND (TELEVENTA='S' OR tvt_ups_virgin = 'S') )
        ELSE
        CASE
          WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' AND (TELEVENTA='S' OR tvt_ups_virgin = 'S')) = 1 THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' AND (TELEVENTA='S' OR tvt_ups_virgin = 'S') )
        ELSE
        CASE
          WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' AND (TELEVENTA='S' OR tvt_ups_virgin = 'S') ) = 1 THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = UPPER(c.subcanal) AND UPPER(mr2.agente) = 'X' AND (TELEVENTA='S' OR tvt_ups_virgin = 'S') )
        ELSE
        CASE
          WHEN ( SELECT COUNT(*) FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = 'X' AND UPPER(mr2.agente) = 'X' AND (TELEVENTA='S' OR tvt_ups_virgin = 'S') ) = 1 THEN ( SELECT clave FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` MR2 WHERE UPPER(mr2.marca_ds) = UPPER(c.marca_ds) AND UPPER(mr2.nombre_distribuidor) = UPPER(c.nombre_distribuidor) AND UPPER(mr2.canal) = UPPER(c.canal) AND UPPER(mr2.subcanal) = 'X' AND UPPER(mr2.agente) = 'X' AND (TELEVENTA='S' OR tvt_ups_virgin = 'S') )
        ELSE
        (
        SELECT
          (-1))
      END
      END
      END
      END
        clave_mr
      FROM
        `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` C
      WHERE (C.CANAL <> 'PUNTO DE VENTA' AND (UPPER(C.agente) <> 'BEN PDV PARQUE PRINCIPADO' OR c.agente IS NULL ))
        OR ((UPPER(C.agente) = 'BEN PDV PARQUE PRINCIPADO' OR C.CANAL = 'PUNTO DE VENTA') AND Marca_Cartera = 'CARTERA') ) a
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr
    ON a.clave_mr = mr.clave
    WHERE TELEVENTA='S' OR tvt_ups_virgin = 'S';


    --- PASO 2: CREO LOG 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0301_MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;      

  END