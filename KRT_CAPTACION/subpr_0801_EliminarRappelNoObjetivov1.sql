BEGIN
    
    DECLARE MES_COMISION_ID INT64;
    SET MES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);



    -- PASO 1: CREAR TABLA COMISIONES Y AÑADIR descripcion_comision_mm
    CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` AS

    WITH POB_OBJ AS(
      SELECT * 
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION`
      WHERE NOT (
        UPPER(concepto_ds) LIKE '%RAPPEL%'
        AND coalesce(plays,0) IN (1,
          2)
        AND ((canal_alta_ds='TELEVENTA'
            --PARCHE
            --BORRADO
            --AND marca_ds = 'V')
            --AÑADIDO              
            AND marca_ds = 'VIRGIN')            
            --FINPARCHE            
          OR (canal_alta_ds = 'WEB'
            AND subcanal_ds = 'WEB DISTRIBUIDOR'
            --PARCHE
            --BORRADO
            --AND marca_ds <> 'VIRGIN'
            --FIN PARCHE            
            ))
      )
    )
    SELECT *,MES_COMISION_ID as mes_comision_id,
    CASE
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'fibra') THEN 'A - Servicio acceso BA'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='DESCONOCIDO' and CONTAINS_SUBSTR(concepto_ds,'mambo axi') THEN 'A - Servicio acceso BA'      
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'descuento') THEN 'Z - Cancelacion'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='FIJA' and CONTAINS_SUBSTR(concepto_ds,'con portabilidad') THEN 'A - Portabilidad Fijo'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='FIJA' and  CONTAINS_SUBSTR(concepto_ds,'sin portabilidad') THEN 'A - Servicio Fijo'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='MOVILES POSTPAGO' and CONTAINS_SUBSTR(concepto_ds,'con portabilidad') THEN 'A - Portabilidad Movil Postpago'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='MOVILES POSTPAGO' and  CONTAINS_SUBSTR(concepto_ds,'sin portabilidad') THEN 'A - Servicio Movil Postpago'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='TELEVISION'  and (CONTAINS_SUBSTR(concepto_ds,'total') or CONTAINS_SUBSTR(concepto_ds,'ocio') or CONTAINS_SUBSTR(concepto_ds,'pack tv')  or CONTAINS_SUBSTR(concepto_ds,'tv premium') or CONTAINS_SUBSTR(concepto_ds,'segunda tv') or CONTAINS_SUBSTR(concepto_ds,'deco') )  THEN 'B - Television acceso'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='TELEVISION'  and (CONTAINS_SUBSTR(concepto_ds,'opcion') or CONTAINS_SUBSTR(concepto_ds,'prueba tv')  or CONTAINS_SUBSTR(concepto_ds,'futbol')  or CONTAINS_SUBSTR(concepto_ds,'bar')   or CONTAINS_SUBSTR(concepto_ds,'estrenos'))  THEN 'B - Television contenido'       
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='TELEVISION'  and CONTAINS_SUBSTR(concepto_ds,'netflix') THEN 'B - Netflix' 
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'alarma') THEN 'B - Alarma'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'gama') THEN 'B - Terminales'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and CONTAINS_SUBSTR(concepto_ds,'ayud') THEN 'B - Mantenimiento'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and CONTAINS_SUBSTR(concepto_ds,'modulo pro') THEN 'B - Mantenimiento'            
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and CONTAINS_SUBSTR(concepto_ds,'rappel teorico') THEN 'D - Rappel Teorico'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and CONTAINS_SUBSTR(concepto_ds,'rappel diferencia') THEN 'D - Rappel Diferencia'
      WHEN FECHA_RFB_ID >= DESDE and FECHA_RFB_ID <= HASTA and CONTAINS_SUBSTR(concepto_ds,'rappel llamada') THEN 'D - Multiplicador'

      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'fibra') THEN 'R - Servicio acceso BA'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='DESCONOCIDO' and CONTAINS_SUBSTR(concepto_ds,'mambo axi') THEN 'R - Servicio acceso BA'      
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'descuento') THEN 'R - Cancelacion'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='FIJA' and CONTAINS_SUBSTR(concepto_ds,'con portabilidad') THEN 'R - Portabilidad Fijo'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='FIJA' and  CONTAINS_SUBSTR(concepto_ds,'sin portabilidad') THEN 'R - Servicio Fijo'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='MOVILES POSTPAGO' and CONTAINS_SUBSTR(concepto_ds,'con portabilidad') THEN 'R - Portabilidad Movil Postpago'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='MOVILES POSTPAGO' and  CONTAINS_SUBSTR(concepto_ds,'sin portabilidad') THEN 'R - Servicio Movil Postpago'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='TELEVISION'  and (CONTAINS_SUBSTR(concepto_ds,'total') or CONTAINS_SUBSTR(concepto_ds,'ocio')  or CONTAINS_SUBSTR(concepto_ds,'tv premium') or CONTAINS_SUBSTR(concepto_ds,'pack tv') or CONTAINS_SUBSTR(concepto_ds,'segunda tv') or CONTAINS_SUBSTR(concepto_ds,'deco') )  THEN 'R - Television acceso'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='TELEVISION'  and (CONTAINS_SUBSTR(concepto_ds,'opcion') or CONTAINS_SUBSTR(concepto_ds,'prueba tv') or CONTAINS_SUBSTR(concepto_ds,'bar')   or CONTAINS_SUBSTR(concepto_ds,'estrenos'))  THEN 'R - Television contenidos'       
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='TELEVISION'  and CONTAINS_SUBSTR(concepto_ds,'netflix') THEN 'R - Netflix' 
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'alarma') THEN 'R - Alarmas'
      WHEN FECHA_RFB_ID < DESDE and categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'gama') THEN 'R - Terminales'
      WHEN FECHA_RFB_ID < DESDE and CONTAINS_SUBSTR(concepto_ds,'ayud') THEN 'B - Mantenimiento'
      WHEN FECHA_RFB_ID < DESDE and CONTAINS_SUBSTR(concepto_ds,'modulo pro') THEN 'B - Mantenimiento'      
      WHEN FECHA_RFB_ID < DESDE and CONTAINS_SUBSTR(concepto_ds,'rappel teorico') THEN 'R - Rappel Teorico'
      WHEN FECHA_RFB_ID < DESDE and CONTAINS_SUBSTR(concepto_ds,'rappel diferencia') THEN 'R - Rappel Diferencia'
      WHEN FECHA_RFB_ID < DESDE and CONTAINS_SUBSTR(concepto_ds,'rappel llamada') THEN 'R - Multiplicador'

      WHEN CONTAINS_SUBSTR(concepto_ds,'extra por concepto')  THEN 'F - Extra'
      WHEN  CONTAINS_SUBSTR(concepto_ds,'postventa por concepto') THEN 'F - Postventa' 
      ELSE 'O - Otros'                   
    end as desc_mm
    FROM POB_OBJ;

    -- PASO 2: AÑADIR clase_mm

  ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
  ADD COLUMN clase_mm STRING;


  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'A - Servicio base' WHERE desc_mm like 'A - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'B - SVA' WHERE desc_mm like 'B - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'D - Extracomision' WHERE desc_mm like 'D - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'F - Gestion de canal' WHERE desc_mm like 'F - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'O - Otros' WHERE desc_mm like 'O - %';  
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'R - Recalculo periodo anterior' WHERE desc_mm like 'R - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'Z - Ajustes' WHERE desc_mm like 'Z - %';
END