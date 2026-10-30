BEGIN

-- call `mm-commissions-reporting.TEMP.pr_staging_bronze_thadea`());

--El siguiente procedimiento tiene como finalidad el procesamiento de datos proveniente del script de python que se conecta la Dbeaver. Diariamente después de las 11 am se actualiza la información desde el origen haciendo un INSERT, por lo tanto se eliminan los datos del mes de ejecución y se insertan los nuevos. Como criterio de Idempontencia se a agregado dos columnas de control fecha_inserción y fecha_actualización.

  DECLARE mes_diario,mes_consumo, mes_ajustes STRING;

  SET mes_diario = 
    (SELECT DISTINCT FechaCalculo
    FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_diario_staging`
  );
  SET mes_consumo = 
    (SELECT DISTINCT FechaCalculo
    FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_consumo_staging`
  );
  SET mes_ajustes = 
    (SELECT DISTINCT RUN
    FROM `mm-commissions-reporting.TEMP.rpiq_manual_comissions_staging`
  )
  ;

  -----------------------------------------------
  --Tabla bronze_thadea_informe_detalle
  -----------------------------------------------

  --Aplicamos el criterio de Idempotencia

  DELETE `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle`
  WHERE FECHACALCULO = mes_diario

  ;  

  INSERT INTO `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle`
      SELECT
        *,
        CURRENT_TIMESTAMP() AS fecha_insercion,
        CURRENT_TIMESTAMP() AS fecha_actualizacion
      FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_diario_staging`
  ;
  -----------------------------------------------
  --Tabla bronze_thadea_informe_detalle_consumo
  -----------------------------------------------

  
  --Aplicamos el criterio de Idempotencia

  DELETE `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_consumo`
  WHERE FECHACALCULO = mes_consumo
  ;

  INSERT INTO `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_consumo`
      SELECT
        *,
        CURRENT_TIMESTAMP() AS fecha_insercion,
        CURRENT_TIMESTAMP() AS fecha_actualizacion
      FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_consumo_staging`
  ;

  -----------------------------------------------
  --Tabla bronze_thadea_informe_detalle_ajustes
  -----------------------------------------------

  --Aplicamos el criterio de Idempotencia

  DELETE `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_ajustes`
  WHERE RUN = mes_ajustes
  ;

  INSERT INTO `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_ajustes`
      SELECT
        *,
        CURRENT_TIMESTAMP() AS fecha_insercion,
        CURRENT_TIMESTAMP() AS fecha_actualizacion
      FROM `mm-commissions-reporting.TEMP.rpiq_manual_comissions_staging`
  ;

END