BEGIN

    DECLARE FECHA_CALC, VMES_COMISION_DT,VFECHA_RFB_DESDE_DT,VFECHA_RFB_HASTA_DT DATE;
	DECLARE VMES_COMISION_ID INT64;

	-- LOCAL
	--DECLARE vTIPO STRING; DECLARE vDESDE, vHASTA, vVERSION INT64; SET vTIPO="EVENTOS_CARTERA";SET vDESDE=20241201;SET vHASTA=20241231;SET vVERSION=16;
    SET VMES_COMISION_ID=CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d',CAST(vDESDE AS string)),month)) AS INT64);	
	  SET VMES_COMISION_DT=parse_date ('%Y%m%d', CAST (vDESDE AS string));
    SET VFECHA_RFB_DESDE_DT=parse_date ('%Y%m%d', CAST (vDESDE AS string));
    SET VFECHA_RFB_HASTA_DT=parse_date ('%Y%m%d', CAST (vHASTA AS string));    
    SET FECHA_CALC=CURRENT_DATE('Europe/Madrid');



    if  CONTAINS_SUBSTR(vTIPO,'EVENTOS_CARTERA') then

        DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_CARTERA` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
        INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_CARTERA` 


        SELECT distinct fecha_calc, vdesde, vhasta,  vversion, marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, CAST(NULL AS STRING) as equipo, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, ClaseProducto,TipoProducto
        --c.* except(agente_creador_id)
        FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
        where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;	
 

        DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_TERMINALES` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
        INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_TERMINALES` 

        SELECT fecha_calc, vdesde, vhasta,  vversion,
        marca_ds,
        idFijo,
        idProducto,
        marcaModelo,
        marca,
        modelo,
        fecha_Creacion,
        Fecha_Activacion
        from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_TERMINALES`
        where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;

    elseif  CONTAINS_SUBSTR(vTIPO,'DECOMISIONES') then

--        DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
        DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` c where c.fecha_calc_dt=fecha_calc and c.desde=vdesde and c.hasta=vhasta;
        INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` 
        SELECT fecha_calc, vdesde, vhasta,  vversion, marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, CAST(NULL AS STRING) as equipo, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, ClaseProducto, TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe, nivel, importe_nivel, bono_comercial, bono_calidad, bono_extras, total, campana_id, nombre_campana, decomisionable, decom_bono_extra, mes_comision_id, desc_mm_com, clase_mm_com, FechaDesinstalacion, CausaBaja, CausaBajaGeneral, mes_decomision_id, desc_mm, clase_mm, orden_sap
        FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`;
        --where fechaDesinstalacion>=VFECHA_RFB_DESDE_DT and fechaDesinstalacion<=VFECHA_RFB_HASTA_DT;	
  
  
    elseif  CONTAINS_SUBSTR(vTIPO,'RESTO') then
      DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
      INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` 
      SELECT  fecha_calc, vdesde, vhasta,  vversion, marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, CAST(NULL AS STRING) as equipo, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, ClaseProducto,TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe, nivel, importe_nivel, bono_comercial, bono_calidad, bono_extras, total, campana_id, nombre_campana, decomisionable, decom_bono_extra, mes_comision_id, desc_mm, clase_mm, orden_sap
      FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;
      --where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;


      DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES_LISTADO` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
      INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES_LISTADO` 
      SELECT  fecha_calc, vmes_comision_dt, vmes_comision_id,vdesde, vhasta,  vversion, marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, CAST(NULL AS STRING) as equipo, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, ClaseProducto, TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, nivel, campana_id, nombre_campana, decomisionable, decom_bono_extra, orden_sap, concepto_lista, importe, desc_mm, clase_mm
      FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES_LISTADO`;
      --where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;	
	    

      DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_TELEVENTAS` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
      INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_TELEVENTAS` 
      SELECT  fecha_calc, vdesde, vhasta,  vversion, marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, CAST(NULL AS STRING) as equipo, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, nivel_tvt_ups_virgin, campana_id, nombre_campana, importe, importe_nivel
      --c.* except(agente_creador_id)
      FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS` c;
      --where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;		

      DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_VENTAS_TIENDAS`  c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
      INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_BONOS_VENTAS_TIENDAS` 
      SELECT  fecha_calc, vdesde, vhasta,  vversion, marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, CAST(NULL AS STRING) as equipo, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe, nivel, importe_nivel, bono_comercial, bono_calidad 
      --c.* except(agente_creador_id)
      FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS` c;
      --where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;	

      DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TELEVENTAS` c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
      INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TELEVENTAS` 
      SELECT fecha_calc, vdesde, vhasta,  vversion, marca_ds,	IdCatalogo,	NombreProducto,	nombre_distribuidor, CAST(NULL AS STRING) as equipo,	Canal,	subcanal,	agente,	IdFijo,	Antiguedad,	DNI_CIF,	Marca_Cartera,	Fecha_Activacion,	Fecha_Creacion,	Segmento,	Subsegmento,	idCatalogoOrigen,	IdProductoOrigen,	NombreProductoOrigen,	TipoMovimiento,	IdProducto,	Contrato,	UsuarioCreador,	agente_creador_id,	concepto_ds,	concepto_origen_ds,	medio_conocimiento,	TipoProducto,	clave_mr,	MARCO_RETRIBUTIVO,	tvt_ups_virgin,	televenta,	nivel_tvt_ups_virgin,	campana_id,	nombre_campana,	importe,
      --c.* except(agente_creador_id)
      FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` c;
      --where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;		

      DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TIENDAS`  c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
      INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_VENTAS_TIENDAS` 
      SELECT  fecha_calc, vdesde, vhasta,  vversion, marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, CAST(NULL AS STRING) as equipo, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, TipoProducto, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe      
      --c.* except(agente_creador_id)
      FROM `mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` c;
      --where fecha_Activacion>=VFECHA_RFB_DESDE_DT and fecha_Activacion<=VFECHA_RFB_HASTA_DT;	

/*
      DELETE  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_TERMINALES`  c where c.fecha_calc_dt=fecha_calc and c.version=vversion and c.desde=vdesde and c.hasta=vhasta;
      INSERT INTO  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_TERMINALES` 
      SELECT fecha_calc, vdesde, vhasta,  vversion, 
      marca_ds, IdProducto, marcaModelo, marca, modelo      
      --c.* except(agente_creador_id)
      FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_TERMINALES` c;	

*/


    end if;
    
  END