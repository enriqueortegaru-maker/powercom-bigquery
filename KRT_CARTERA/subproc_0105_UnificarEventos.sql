BEGIN

    -- PASO 1: Inserto registros en tabla EVENTOS_CARTERA
    INSERT INTO
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
    SELECT
      mmMarcaDesc,
      CatalogoId,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      cliente_id,
      Antiguedad,
      swNIE,
      MarcaCartera,
      Fecha_Activacion,
      Fecha_Creacion,
      swSegmento,
      Subsegmento,
      CatalogoIdOrigen,
      ProductoIdOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      ProductoId,
      Contrato,
      UsuarioCreador,
      concepto_ds,
      concepto_origen_ds,
    FROM
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`;


    -- PASO 2:Añado campo tipo producto
     
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ADD COLUMN TipoProducto STRING;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
    SET e.TipoProducto = 
    CASE
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos BA') THEN 'BANDA ANCHA'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'ip fija')  or CONTAINS_SUBSTR(concepto_ds,'segunda residencia')) THEN 'BANDA ANCHA'                    
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos telefonia') THEN 'FIJA'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'portabilidad fijo') or CONTAINS_SUBSTR(concepto_ds,'terminal fijo')) THEN 'FIJA'          
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios m') THEN 'MOVILES POSTPAGO'     
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'portabilidad m') or CONTAINS_SUBSTR(concepto_ds,'tarjeta eco') or CONTAINS_SUBSTR(concepto_ds,'tarjeta sim') or CONTAINS_SUBSTR(concepto_ds,'bono') or CONTAINS_SUBSTR(concepto_ds,'tarifa')) THEN 'MOVILES POSTPAGO'        
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicios fijos televis') THEN 'TELEVISION'                      
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'netflix') or CONTAINS_SUBSTR(concepto_ds,'tv') or CONTAINS_SUBSTR(concepto_ds,'opcion')  or CONTAINS_SUBSTR(concepto_ds,'tedi') ) THEN 'TELEVISION'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and CONTAINS_SUBSTR(concepto_ds,'alarma')  or CONTAINS_SUBSTR(concepto_ds,'seguridad') THEN 'SEGURIDAD' 
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'seguro movil') or CONTAINS_SUBSTR(concepto_ds,'mantenimiento')  or CONTAINS_SUBSTR(concepto_ds,'ayuda') ) THEN 'POSTVENTA'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and (CONTAINS_SUBSTR(concepto_ds,'terminal') or CONTAINS_SUBSTR(concepto_ds,'smartwatch') ) THEN 'TERMINALES'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'servicio valor') and (CONTAINS_SUBSTR(concepto_ds,'wifi') or CONTAINS_SUBSTR(concepto_ds,'plc')) THEN 'WIFI'
          WHEN CONTAINS_SUBSTR(TipoMovimiento,'equipamiento m') and  CONTAINS_SUBSTR(concepto_ds,'mifi') THEN 'WIFI'           
          ELSE 'OTROS'   
      END
      WHERE e.TipoProducto is Null;

END