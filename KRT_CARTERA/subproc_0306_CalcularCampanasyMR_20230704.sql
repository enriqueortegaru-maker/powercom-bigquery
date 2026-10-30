BEGIN

    --- PASO 1: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS
    SELECT 
      a.*
      FROM
      `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a,
      `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b,
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c,
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr
    WHERE
      a.idfijo = b.cliente_id
      AND UPPER(a.marca_ds) = UPPER(b.marca_ds)
      AND UPPER(a.marca_ds) = c.marca_ds
      AND b.id_campana = c.campana_id
      AND
      CASE
        WHEN c.nombre_distribuidor = 'X' THEN 1=1
      ELSE
      a.nombre_distribuidor = c.nombre_distribuidor
      END
      AND a.clave_mr = mr.clave;



    --- PASO 2: ACTUALIZO TABLA MARCO_RETRIBUTIVO_TELEVENTASxCANAL
    ALTER TABLE
      `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN campana_id string;
    ALTER TABLE
      `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN nombre_campana string;
    UPDATE
      `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    SET
      MARCO_RETRIBUTIVO = coalesce(mr_televenta,
        mr.agrupador_mr),
      a.campana_id = b.ID_CAMPANA,
      a.nombre_campana = b.NOMBRE_CAMPANA
    FROM
      `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b,
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c,
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr
    WHERE
      a.idfijo = b.cliente_id
      AND UPPER(a.marca_ds) = UPPER(b.marca_ds)
      AND UPPER(a.marca_ds) = c.marca_ds
      AND b.id_campana = c.campana_id
      AND
      CASE
        WHEN c.nombre_distribuidor = 'X' THEN 1=1
      ELSE
      a.nombre_distribuidor = c.nombre_distribuidor
      END
      AND a.clave_mr = mr.clave;

  END