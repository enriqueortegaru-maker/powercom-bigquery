BEGIN
    DECLARE  DESDE_DT, HASTA_DT, DESDE_6M_DT date;
	  DECLARE	MES_COMISION INT64;    
	--- VARIABLES LOCALES---
    --DECLARE desde, hasta INT64;SET desde=20241001;SET hasta=20241030;
    
    SET HASTA_DT = parse_date ('%Y%m%d', CAST ( HASTA AS string) );
    SET DESDE_DT = parse_date ('%Y%m%d', CAST ( DESDE AS string) );
    --SET DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);
	  SET	MES_COMISION= CAST(FORMAT_DATE("%Y%m",DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64); 



    -- PASO 1: ACTUALIZO HISTORICO DE COMISIONES
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
    WHERE mes_comision_id=MES_COMISION;
    --WHERE CAST(Fecha_Activacion AS date) BETWEEN DESDE_DT AND HASTA_DT;    

    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
    (
      marca_ds,
      IdCatalogo,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      IdFijo,
      Antiguedad,
      DNI_CIF,
      Marca_Cartera,
      Fecha_Activacion,
      Fecha_Creacion,
      Segmento,
      Subsegmento,
      idCatalogoOrigen,
      IdProductoOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      IdProducto,
      Contrato,
      UsuarioCreador,
      agente_creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento,
      ClaseProducto,
      TipoProducto,
      clave_mr,
      MARCO_RETRIBUTIVO,
      tvt_ups_virgin,
      televenta,
      importe,
      nivel,
      importe_nivel,
      bono_comercial,
      bono_calidad,
      bono_extras,
      total,
      campana_id,
      nombre_campana,
      decomisionable,
      decom_bono_extra,
      mes_comision_id,
      desc_mm,
      clase_mm,
      orden_sap
    )
    SELECT 
      marca_ds,
      IdCatalogo,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      IdFijo,
      Antiguedad,
      DNI_CIF,
      Marca_Cartera,
      Fecha_Activacion,
      Fecha_Creacion,
      Segmento,
      Subsegmento,
      idCatalogoOrigen,
      IdProductoOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      IdProducto,
      Contrato,
      UsuarioCreador,
      agente_creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento,
      ClaseProducto,
      TipoProducto,
      clave_mr,
      MARCO_RETRIBUTIVO,
      tvt_ups_virgin,
      televenta,
      importe,
      nivel,
      importe_nivel,
      bono_comercial,
      bono_calidad,
      bono_extras,
      total,
      campana_id,
      nombre_campana,
      decomisionable,
      decom_bono_extra,
      mes_comision_id,
      desc_mm,
      clase_mm,
      orden_sap    
    /*except(agente_creador_id,bono_extras)*/
    FROM
      `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;    


    --- PASO 2:ACTUALIZO HISTORICO DE COMISIONES DUPLICADAS EN MESES PREVIOS
    DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    WHERE mes_comision_id=MES_COMISION;

    INSERT  INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    (
      marca_ds,
      IdCatalogo,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      IdFijo,
      Antiguedad,
      DNI_CIF,
      Marca_Cartera,
      Fecha_Activacion,
      Fecha_Creacion,
      Segmento,
      Subsegmento,
      idCatalogoOrigen,
      IdProductoOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      IdProducto,
      Contrato,
      UsuarioCreador,
      --agente_creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento,
      TipoProducto,
      clave_mr,
      MARCO_RETRIBUTIVO,
      tvt_ups_virgin,
      televenta,
      importe,
      nivel,
      importe_nivel,
      bono_comercial,
      bono_calidad,
      --bono_extras,
      total,
      campana_id,
      nombre_campana,
      decomisionable,
      --decom_bono_extra,
      mes_comision_id,
      desc_mm,
      clase_mm
      --orden_sap
    )
    SELECT --* except(agente_creador_id) 
      marca_ds,
      IdCatalogo,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      IdFijo,
      Antiguedad,
      DNI_CIF,
      Marca_Cartera,
      Fecha_Activacion,
      Fecha_Creacion,
      Segmento,
      Subsegmento,
      idCatalogoOrigen,
      IdProductoOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      IdProducto,
      Contrato,
      UsuarioCreador,
      --agente_creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento,
      TipoProducto,
      clave_mr,
      MARCO_RETRIBUTIVO,
      tvt_ups_virgin,
      televenta,
      importe,
      nivel,
      importe_nivel,
      bono_comercial,
      bono_calidad,
      --bono_extras,
      total,
      campana_id,
      nombre_campana,
      decomisionable,
      --decom_bono_extra,
      mes_comision_id,
      desc_mm,
      clase_mm,
      --orden_sap    
    
    
    FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS`;


    -- PASO 3: ACTUALIZO HISTORICO DE DECOMISIONES
    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_HISTORICO`
    WHERE mes_decomision_id=MES_COMISION;    
    --WHERE CAST(Fecha_Activacion AS date) BETWEEN DESDE_DT AND HASTA_DT;

    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_HISTORICO`
    SELECT *  except(orden_sap),orden_sap
    FROM   `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`;    



  --- PASO 4:ACTUALIZO HISTORICO DE DECOMISIONES DUPLICADAS EN MESES PREVIOS
    DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    WHERE mes_decomision_id=MES_COMISION;

    INSERT  INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    SELECT * except(clasePRoducto, orden_sap),orden_sap
     FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS`;




END