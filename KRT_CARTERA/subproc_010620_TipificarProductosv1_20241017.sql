BEGIN

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` as select * from `mm-commissions-reporting.KRT_CARTERA.LOG_010610_EVENTOS_CARTERA`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` as 
	select * except(tipoProductoOrigen,subtipoProductoOrigen,subtipoProducto) from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ;

    -- PASO 2:Añado campo tipo producto
     
  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA`;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS 
  SELECT distinct * ,
      CASE
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos BA') THEN 'BANDA ANCHA'
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'ip fija') or CONTAINS_SUBSTR(concepto_ds,'segunda residencia')  or CONTAINS_SUBSTR(concepto_ds,'FTTR')) THEN 'BANDA ANCHA'                    

          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos telefonia') THEN 'FIJA'
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'portabilidad fijo') or CONTAINS_SUBSTR(concepto_ds,'terminal fijo')  or CONTAINS_SUBSTR(concepto_ds,'llamadas provincial')) THEN 'FIJA'          
          WHEN CONTAINS_SUBSTR(nombreproducto,'residencial') and CONTAINS_SUBSTR(nombreproducto,'internacion') THEN 'FIJA'
          WHEN CONTAINS_SUBSTR(nombreproducto,'fijo en el movil') THEN 'FIJA'
          WHEN CONTAINS_SUBSTR(nombreproducto,'línea fijo') THEN 'FIJA'
          WHEN CONTAINS_SUBSTR(nombreproducto,'amlt') THEN 'FIJA'          

          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios m') THEN 'MOVILES POSTPAGO'     
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'portabilidad m')) THEN 'MOVILES POSTPAGO'        
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'tarjeta eco') or CONTAINS_SUBSTR(concepto_ds,'tarjeta sim') or CONTAINS_SUBSTR(concepto_ds,'multisim')) THEN 'MOVILES POSTPAGO'    
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'bono') or CONTAINS_SUBSTR(concepto_ds,'konekta')  ) THEN 'MOVILES POSTPAGO'  
          WHEN CONTAINS_SUBSTR(NombreProducto,'Pintxo 4G') THEN 'MOVILES POSTPAGO'     
          WHEN CONTAINS_SUBSTR(NombreProducto,'Pintxo Prepago') THEN 'MOVILES PREPAGO'

          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos televis') THEN 'TELEVISION'
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(nombreproducto,'DESCODIFICADOR 4K V2') ) THEN 'TELEVISION'                                
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'tv') or CONTAINS_SUBSTR(concepto_ds,'opcion')  or CONTAINS_SUBSTR
          (concepto_ds,'tedi')  or CONTAINS_SUBSTR(concepto_ds,'edonon') ) THEN 'TELEVISION'              
          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'netflix') or CONTAINS_SUBSTR(concepto_ds,'dazn') or CONTAINS_SUBSTR(concepto_ds,'amazon') or contains_substr(concepto_ds,'max estandar') or contains_substr(concepto_ds,'hbo max')) THEN 'OTT'              
		  
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and (CONTAINS_SUBSTR(tipoProducto,'terminal') ) THEN 'TERMINAL MOVIL'

          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'mantenimiento')  or CONTAINS_SUBSTR(concepto_ds,'ayuda') ) THEN 'POSTVENTA'          
          WHEN CONTAINS_SUBSTR(concepto_ds,'seguro') THEN 'SEGUROS'
          WHEN CONTAINS_SUBSTR(concepto_ds,'alarma')  or CONTAINS_SUBSTR(concepto_ds,'seguridad')  or CONTAINS_SUBSTR(concepto_ds,'energia') THEN 'SEGURIDAD'

          WHEN (CONTAINS_SUBSTR(tipoProducto,'SVA') OR CONTAINS_SUBSTR(TipoMovimiento,'servicio valor')) and (CONTAINS_SUBSTR(concepto_ds,'wifi') or CONTAINS_SUBSTR(concepto_ds,'plc') or CONTAINS_SUBSTR(nombreproducto,'TELEFONO FIJO PROMOCION')) THEN 'CPE FIJO'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and  CONTAINS_SUBSTR(concepto_ds,'mifi') THEN 'CPE MOVIL'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and  CONTAINS_SUBSTR(nombreProducto,'router 4G') THEN 'CPE MOVIL'          
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and  CONTAINS_SUBSTR(nombreProducto,'Router doméstico gama alta') THEN 'CPE MOVIL'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and ((CONTAINS_SUBSTR(nombreProducto,'euskatel life') ) or contains_substr(nombreProducto,"Google Home")) THEN 'DOMOTICA'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') THEN 'DISPOSITIVOS'
          WHEN CONTAINS_SUBSTR(nombreproducto,'móvil') THEN 'MOVILES POSTPAGO'
          WHEN CONTAINS_SUBSTR(nombreproducto,'móbil') THEN 'MOVILES POSTPAGO'          

          ELSE 'OTROS'   
      END as ClaseProducto
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_010620_EVENTOS_CARTERA_CON_CLASE`AS
  SELECT *
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`AS
  SELECT * except(TipoProducto,ClaseProducto), ClaseProducto as TipoProducto
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_010620_EVENTOS_CARTERA`AS
  SELECT *
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;



END