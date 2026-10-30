BEGIN

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` 
  --AS SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0301_MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

    --- PASO 1: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL CON TABLAS QUE SE ACTUALIZAN
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` AS
    SELECT a.*
      FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a 
      inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND UPPER(b.marca_ds) = UPPER(a.marca_ds)
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c on UPPER(c.marca_ds) = UPPER(a.marca_ds)  
      and CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE  a.nombre_distribuidor = c.nombre_distribuidor END and c.campana_id = b.id_campana
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave;


    --- PASO 2: ACTUALIZO TABLA MARCO_RETRIBUTIVO_TELEVENTASxCANAL

    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN campana_id string;
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN nombre_campana string;


    UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    SET
      MARCO_RETRIBUTIVO = coalesce(mr_televenta, mr.agrupador_mr),
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
      AND CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE a.nombre_distribuidor = c.nombre_distribuidor  END
      AND a.clave_mr = mr.clave;


    --- PASO 3: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL CON SALIDA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;


  END