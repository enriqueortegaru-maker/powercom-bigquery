BEGIN
  ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
  ADD COLUMN desc_mm STRING;

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
  SET desc_mm=
    CASE
      WHEN  categoria_servicio_ds='BANDA ANCHA' and (grid<=4 or grid=7)  and CONTAINS_SUBSTR(concepto_ds,'fibra') THEN 'A - Servicio acceso BA'
      WHEN  categoria_servicio_ds='BANDA ANCHA' and (grid>4 and grid<>7) and CONTAINS_SUBSTR(concepto_ds,'fibra') THEN 'B - Servicio acceso BA'      
      WHEN  categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'mambo axi') THEN 'A - Servicio acceso BA'      
      WHEN  categoria_servicio_ds='DESCONOCIDO' and CONTAINS_SUBSTR(concepto_ds,'mambo axi') THEN 'A - Servicio acceso BA'            
      WHEN  categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'descuento') THEN 'Z - Cancelacion'
      WHEN  categoria_servicio_ds='FIJA' and grid<=4 THEN 'A - Fijo'
      WHEN  categoria_servicio_ds='FIJA' and grid>4 THEN 'B - Fijo'      
      WHEN  categoria_servicio_ds='MOVILES POSTPAGO' THEN 'A - Movil'
      WHEN  categoria_servicio_ds='TELEVISION'  
      and not CONTAINS_SUBSTR(detalle_servicio_ds,'etflix')    
      and not CONTAINS_SUBSTR(detalle_servicio_ds,'canal') 
      and not CONTAINS_SUBSTR(detalle_servicio_ds,'estrenos')     
      and not CONTAINS_SUBSTR(detalle_servicio_ds,'liga')
      THEN 'B - Television acceso' 
--    and (CONTAINS_SUBSTR(concepto_ds,'total') or CONTAINS_SUBSTR(concepto_ds,'ocio') or CONTAINS_SUBSTR(concepto_ds,'pack tv')  or CONTAINS_SUBSTR(concepto_ds,'tv premium') or CONTAINS_SUBSTR(concepto_ds,'segunda tv') or CONTAINS_SUBSTR(concepto_ds,'deco') )  
      WHEN  categoria_servicio_ds='TELEVISION' 
      and (CONTAINS_SUBSTR(detalle_servicio_ds,'etflix')    
      or CONTAINS_SUBSTR(detalle_servicio_ds,'canal') 
      or CONTAINS_SUBSTR(detalle_servicio_ds,'estrenos')     
      or CONTAINS_SUBSTR(detalle_servicio_ds,'liga'))           
      THEN 'B - Television contenido'                      
--       and (CONTAINS_SUBSTR(concepto_ds,'opcion') or CONTAINS_SUBSTR(concepto_ds,'prueba tv')  or CONTAINS_SUBSTR(concepto_ds,'futbol')  or CONTAINS_SUBSTR(concepto_ds,'bar')   or CONTAINS_SUBSTR(concepto_ds,'estrenos'))  
      WHEN  categoria_servicio_ds='TELEVISION'  and CONTAINS_SUBSTR(concepto_ds,'netflix') THEN 'B - Netflix' 
      WHEN  categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'alarma') THEN 'B - Alarma'
      WHEN  categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'gama') THEN 'B - Terminales'
      WHEN  CONTAINS_SUBSTR(concepto_ds,'ayud') THEN 'B - Mantenimiento'
      WHEN  CONTAINS_SUBSTR(concepto_ds,'modulo pro') THEN 'B - Mantenimiento'            
      ELSE 'OTROS'                   
    end
  --where 1=1
  where desc_mm is null;


    -- PASO 2: AÑADIR clase_mm

  ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
  ADD COLUMN clase_mm STRING;


  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` SET clase_mm = 'A - Servicio base' WHERE desc_mm like 'A - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` SET clase_mm = 'B - SVA' WHERE desc_mm like 'B - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` SET clase_mm = 'D - Extracomision' WHERE desc_mm like 'D - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` SET clase_mm = 'F - Gestion de canal' WHERE desc_mm like 'F - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` SET clase_mm = 'R - Recalculo periodo anterior' WHERE desc_mm like 'R - %';
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` SET clase_mm = 'Z - Ajustes' WHERE desc_mm like 'Z - %';


END