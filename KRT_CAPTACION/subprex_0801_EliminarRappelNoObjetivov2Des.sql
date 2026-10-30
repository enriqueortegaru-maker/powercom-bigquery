BEGIN
    

      DECLARE VMES_COMISION_ID INT64;
      SET VMES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);



      -- PASO 1: CREAR TABLA COMISIONES 
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` AS
      SELECT v.*, NULL mes_comision_id, '' desc_mm,'' clase_mm  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` v;


      -- PASO 2: ACTUALIZO RAPPEL DE TODOS LOS  CANALES CUYO RAPPEL DEBE SER PONDERADO

      UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
      SET c.importe=c.importe*p.ponderacion
      FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p
      WHERE c.marca_ds=p.marca_ds
      AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
      AND c.plays=p.plays
      AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL');


      -- PASO 3: ELIMINO LAS COMISIONES ACTUALIZADAS CUYO RAPPEL ES DE VALOR 0

      DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
      WHERE EXISTS (
        select *
        from `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p
        WHERE c.marca_ds=p.marca_ds
        AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
        AND c.plays=p.plays
        AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL')
        AND c.importe=0
      );


      -- PASO 4: ACTUALIZO ATRIBUTO DE MES DE COMISION
    
    --ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` ADD COLUMN mes_comision_id INT64;
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    SET mes_comision_id=VMES_COMISION_ID
    WHERE 1=1;


      -- PASO 5: ACTUALIZO ATRIBUTO DESC_MM
    --ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` ADD COLUMN desc_mm STRING;
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
    SET desc_mm =
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
        ELSE 'OTROS'                   
      end 
    WHERE 1=1;


      -- PASO 6: ACTAULIZO ATRIBUTO CLASE_MM

    --ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` ADD COLUMN clase_mm STRING;
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'A - Servicio base' WHERE desc_mm like 'A - %';
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'B - SVA' WHERE desc_mm like 'B - %';
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'D - Extracomision' WHERE desc_mm like 'D - %';
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'F - Gestion de canal' WHERE desc_mm like 'F - %';
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'R - Recalculo periodo anterior' WHERE desc_mm like 'R - %';
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` SET clase_mm = 'Z - Ajustes' WHERE desc_mm like 'Z - %';



END