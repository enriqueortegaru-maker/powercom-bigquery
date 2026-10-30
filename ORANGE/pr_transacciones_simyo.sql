BEGIN

  --CALL `mm-commissions-reporting.ORANGE.pr_transacciones_simyo`()

  /*
    --CREACION ORIGINAL DE LA TABLA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.transacciones_simyo`
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS

      SELECT * EXCEPT (emails_acceso_trazabilidad)
      FROM `mm-commissions-reporting.COMISIONES.transacciones`
      WHERE marca = 'SIMYO'
      ORDER BY id_mes, commission_id;
  */

    --BORRADO DE LA TABLA PREVIO A LA ACTUALIZACION
  DELETE 
  FROM `mm-commissions-reporting.TEMP.transacciones_simyo`
  WHERE 1 = 1;

  INSERT INTO `mm-commissions-reporting.TEMP.transacciones_simyo`
    SELECT * EXCEPT (emails_acceso_trazabilidad)
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE marca = 'SIMYO'
    ORDER BY id_mes, commission_id;

END