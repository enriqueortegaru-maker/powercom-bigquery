BEGIN
	
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` as 
	select * except(tipoProductoOrigen,subtipoProductoOrigen,tipoProducto, subtipoProducto) from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ;

 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS 
  SELECT distinct *,
    CASE
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos BA') THEN 'BANDA ANCHA'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'ip fija')  or CONTAINS_SUBSTR(concepto_ds,'segunda residencia')) THEN 'BANDA ANCHA'                    
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'wifi') or CONTAINS_SUBSTR(concepto_ds,'plc')) THEN 'BANDA ANCHA'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and  CONTAINS_SUBSTR(concepto_ds,'mifi') THEN 'BANDA ANCHA'

          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos telefonia') THEN 'ACCESO DIRECTO'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'portabilidad fijo') or CONTAINS_SUBSTR(concepto_ds,'terminal fijo')) THEN 'ACCESO DIRECTO'          
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'mantenimiento')  or CONTAINS_SUBSTR(concepto_ds,'ayuda') ) THEN 'ACCESO DIRECTO'          
          WHEN CONTAINS_SUBSTR(concepto_ds,'alarma')  or CONTAINS_SUBSTR(concepto_ds,'seguridad') THEN 'ACCESO DIRECTO'
          WHEN CONTAINS_SUBSTR(nombreproducto,'residencial') and CONTAINS_SUBSTR(nombreproducto,'internacion') THEN 'ACCESO DIRECTO'
          WHEN CONTAINS_SUBSTR(nombreproducto,'fixo no móbil residencial') THEN 'ACCESO DIRECTO'
          WHEN CONTAINS_SUBSTR(nombreproducto,'línea fijo') THEN 'ACCESO DIRECTO'

          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios m') THEN 'MOVILES POSTPAGO'     
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'portabilidad m')) THEN 'MOVILES POSTPAGO'        
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'tarjeta eco') or CONTAINS_SUBSTR(concepto_ds,'tarjeta sim') or CONTAINS_SUBSTR(concepto_ds,'multisim')) THEN 'MOVILES POSTPAGO'    
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'bono') ) THEN 'MOVILES POSTPAGO'  
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'tarifa') THEN 'MOVILES POSTPAGO'        
          WHEN CONTAINS_SUBSTR(concepto_ds,'seguro') THEN 'MOVILES POSTPAGO'          
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and (CONTAINS_SUBSTR(concepto_ds,'terminal') or CONTAINS_SUBSTR(concepto_ds,'gama') or CONTAINS_SUBSTR(concepto_ds,'smartwatch') ) THEN 'MOVILES POSTPAGO'   
          WHEN CONTAINS_SUBSTR(nombreproducto,'móvil') THEN 'MOVILES POSTPAGO'
          WHEN CONTAINS_SUBSTR(nombreproducto,'móbil') THEN 'MOVILES POSTPAGO'          

          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos televis') THEN 'TELEVISION'                      
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'netflix') or CONTAINS_SUBSTR(concepto_ds,'dazn') or CONTAINS_SUBSTR(concepto_ds,'tv') or CONTAINS_SUBSTR(concepto_ds,'opcion')  or CONTAINS_SUBSTR(concepto_ds,'tedi') ) THEN 'TELEVISION'                                      
          ELSE 'OTROS'   

    END as TipoProducto
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;



END