BEGIN

--Procedimiento que realiza la actualización de los porcentaje de cablemovil.
--Se ejecuta desde el menú del google sheet de cablemovil.

-- call `mm-commissions-reporting.COMISIONES.pr_arca_actualizacion_porcentajes`()

--Eliminamos del histórico la información del mes en curso que se haya subido con anterioridad y que haya tenido errores.
  DELETE `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores_historico_nuevo`
  WHERE MES = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH)
;

--Creamos la tabla temporal mesActual que tendrá la información de los porcentajes del mes en curso 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.maestro_comisiones_cableoperadores_mesActual` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS (

  WITH
    nueva_info AS (
      SELECT *,
          CONCAT(codigo_cableoperador,ID_TARIFA) AS clave
      FROM `mm-commissions-reporting.TEMP.nuevos_porcentajes_cablemovil`
      WHERE codigo_cableoperador IS NOT NULL
      QUALIFY ROW_NUMBER() OVER(PARTITION BY codigo_cableoperador,id_tarifa) = 1 
  ),
    viejo_df AS (
      SELECT *,
        CONCAT(CODIGO_CABLEOPERADOR,ID_TARIFA) AS clave
      FROM `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores_historico_nuevo`
      WHERE MES = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 MONTH),MONTH)
      QUALIFY ROW_NUMBER() OVER(PARTITION BY CODIGO_CABLEOPERADOR,id_tarifa) = 1
  ),
  --Realizamos un cruce para quedarnos con los cableros/porcentajes que no han tenido modificación
    datos_combinados_sinCambios AS (
      SELECT 
        viejo_df.* 
      FROM viejo_df
      LEFT JOIN nueva_info ON viejo_df.clave = nueva_info.clave
      WHERE nueva_info.clave IS NULL
  ),
  --Realizamos un cruce para quedarnos con los cableros/porcentajes que han tenido modificación
    datos_combinados_conCambios AS (
      SELECT nueva_info.*
      FROM viejo_df
      LEFT JOIN nueva_info ON viejo_df.clave = nueva_info.clave
      WHERE nueva_info.clave IS NOT NULL
  ),
  --Realizamos un cruce para quedarnos con los NUEVOS cableros/porcentajes 
    datos_combinados_nuevos AS (
      SELECT nueva_info.*
      FROM nueva_info
      LEFT JOIN viejo_df ON viejo_df.clave = nueva_info.clave
      WHERE viejo_df.clave IS NULL
  ),
  --Se realiza la integración/unión de las 3 sub consultas anteriores
    datos_finales AS (
      SELECT 
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH) AS MES,
        * EXCEPT(MES, clave)
      FROM datos_combinados_sinCambios

      UNION ALL

      SELECT 
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH) AS MES,
        * EXCEPT(clave)
      FROM datos_combinados_conCambios

      UNION ALL

      SELECT 
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH),MONTH) AS MES,
        * EXCEPT(clave)
      FROM datos_combinados_nuevos
    )

    SELECT *
    FROM datos_finales
  )
;
--Realizamos un ASSERT para determinar que la media del count de las tarifas es igual al count de las tarifas por cableoperador. En dado caso que no sean saltá el ASSERT. 
  ASSERT NOT EXISTS (--Si se modifica el ASSERT hay que hacerlo también en el google
    WITH cuenta_base AS (
      SELECT CODIGO_CABLEOPERADOR, COUNT(*) AS cantidad
      FROM `mm-commissions-reporting.TEMP.maestro_comisiones_cableoperadores_mesActual` a
      GROUP BY ALL
    )
    SELECT *
    FROM cuenta_base a
    LEFT JOIN(
      SELECT COUNT(DISTINCT ID_TARIFA) AS cantidad 
      FROM `mm-commissions-reporting.TEMP.maestro_comisiones_cableoperadores_mesActual` 
      GROUP BY ALL
    ) b ON a.cantidad = b.cantidad
    WHERE b.cantidad IS NULL
    ) AS 'Existe un descuadre en la cantidad de bonos por cableoperador'
;
--Realizamos la inserción de la información una vez realizada previamente la validación
INSERT `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores_historico_nuevo` 

SELECT *
FROM `mm-commissions-reporting.TEMP.maestro_comisiones_cableoperadores_mesActual` 
;

END