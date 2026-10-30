BEGIN

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0108_VENTAS_CAPTACION`;  
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS 
  SELECT *,
    CASE
      WHEN  categoria_servicio_ds='BANDA ANCHA' and (grid<=4 or grid=7)  and CONTAINS_SUBSTR(concepto_ds,'fibra') THEN 'A - Servicio acceso BA'
      WHEN  categoria_servicio_ds='BANDA ANCHA' and (grid>4 and grid<>7) and CONTAINS_SUBSTR(concepto_ds,'fibra') THEN 'B - Servicio acceso BA'      
      WHEN  categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'mambo axi') THEN 'A - Servicio acceso BA'      
      WHEN  categoria_servicio_ds='DESCONOCIDO' and CONTAINS_SUBSTR(concepto_ds,'mambo axi') THEN 'A - Servicio acceso BA'            
      WHEN  categoria_servicio_ds='BANDA ANCHA' and CONTAINS_SUBSTR(concepto_ds,'descuento') THEN 'Z - Cancelacion'
      WHEN  categoria_servicio_ds='FIJA' and grid<=4 and portabilidad_in_lg=0 THEN 'A - Servicio Fijo'      
      WHEN  categoria_servicio_ds='FIJA' and grid<=4 and portabilidad_in_lg=1 THEN 'A - Portabilidad Fijo'
      WHEN  categoria_servicio_ds='FIJA' and grid>4 THEN 'B - Servicio adicional Fijo'
      WHEN  categoria_servicio_ds='MOVILES POSTPAGO' and portabilidad_in_lg=0 THEN 'A - Servicio Movil Postpago'      
      WHEN  categoria_servicio_ds='MOVILES POSTPAGO' and portabilidad_in_lg=1 THEN 'A - Portabilidad Movil Postpago'      
      WHEN  categoria_servicio_ds='TELEVISION' and grid <=4 THEN 'B - Television acceso' 
      --and not CONTAINS_SUBSTR(concepto_ds,'etflix')    
      --and not CONTAINS_SUBSTR(concepto_ds,'canal') 
      --and not CONTAINS_SUBSTR(concepto_ds,'estrenos')     
      --and not CONTAINS_SUBSTR(concepto_ds,'tbol')
      --and not CONTAINS_SUBSTR(concepto_ds,'segundo deco')
      --and not CONTAINS_SUBSTR(concepto_ds,'prueba tv')                  

--    and (CONTAINS_SUBSTR(concepto_ds,'total') or CONTAINS_SUBSTR(concepto_ds,'ocio') or CONTAINS_SUBSTR(concepto_ds,'pack tv')  or CONTAINS_SUBSTR(concepto_ds,'tv premium') or CONTAINS_SUBSTR(concepto_ds,'segunda tv') or CONTAINS_SUBSTR(concepto_ds,'deco') )  
      WHEN  categoria_servicio_ds='TELEVISION' and grid > 4 and not CONTAINS_SUBSTR(concepto_ds,'netflix') THEN 'B - Television contenido'
      --and (CONTAINS_SUBSTR(concepto_ds,'etflix')    
      --or CONTAINS_SUBSTR(concepto_ds,'canal') 
      --or CONTAINS_SUBSTR(concepto_ds,'estrenos')           
      --or CONTAINS_SUBSTR(concepto_ds,'tbol')) 
      --or CONTAINS_SUBSTR(concepto_ds,'segundo deco')
      --or CONTAINS_SUBSTR(concepto_ds,'prueba tv')                 
                            
--       and (CONTAINS_SUBSTR(concepto_ds,'opcion') or CONTAINS_SUBSTR(concepto_ds,'prueba tv')  or CONTAINS_SUBSTR(concepto_ds,'futbol')  or CONTAINS_SUBSTR(concepto_ds,'bar')   or CONTAINS_SUBSTR(concepto_ds,'estrenos'))  
      WHEN  categoria_servicio_ds='TELEVISION'  and CONTAINS_SUBSTR(concepto_ds,'netflix') THEN 'B - Netflix' 
      WHEN  categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'alarma') THEN 'B - Alarma'
      WHEN  categoria_servicio_ds='TERMINALES' and CONTAINS_SUBSTR(concepto_ds,'gama') THEN 'B - Terminales'
      WHEN  CONTAINS_SUBSTR(concepto_ds,'ayud') THEN 'B - Mantenimiento'
      WHEN  CONTAINS_SUBSTR(concepto_ds,'modulo pro') THEN 'B - Mantenimiento'            
      ELSE 'OTROS'                   
    end as desc_mm
    FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;



    -- PASO 2: AÑADIR clase_mm
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS 
  SELECT *,
    CASE
      WHEN STARTS_WITH(desc_mm,'A -') THEN 'A - Servicio base'
      WHEN CONTAINS_SUBSTR(desc_mm,'B -') THEN 'B - SVA'
      WHEN STARTS_WITH(desc_mm,'D -') THEN 'D - Extracomision'
      WHEN STARTS_WITH(desc_mm,'F -') THEN 'F - Gestion de canal'
      WHEN STARTS_WITH(desc_mm,'R -') THEN 'R - Recalculo periodo anterior'
      WHEN STARTS_WITH(desc_mm,'Z -') THEN 'Z - Ajustes'
    END  as clase_mm
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0109_VENTAS_CAPTACION`	AS 
	SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;


END