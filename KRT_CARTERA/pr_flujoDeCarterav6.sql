BEGIN

  DECLARE VERSION_FL, FECHAF, DIF_MFMC, NDIAF, MES_COMISION,DB_CTX_TB_UPD  INT64;
	DECLARE FECHA_CALC DATE;
	DECLARE TABLA STRING;
	--- VARIABLES LOCALES---
	--DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20230801;SET hasta=20230831;SET registro=1;SET binvocaciondesarrollo=1;
	SET VERSION_FL=6;
  SET FECHAF=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE()) as INT64);
  SET NDIAF=CAST(FORMAT_DATE("%d",CURRENT_DATE()) as INT64);
  SET DIF_MFMC=CAST(FECHAF/100 AS INT64)-CAST(HASTA/100 AS INT64);
	SET MES_COMISION=CAST(DESDE/100 AS INT64);
	SET DB_CTX_TB_UPD= `mm-commissions-reporting.KRT_CARTERA.checkContextualDataBaseTablesUpdated`();
	SET FECHA_CALC=CURRENT_DATE('Europe/Madrid');  
  --SELECT FECHAF,NDIAF,DIF_MFMC;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` as
  select "INICIO FLUJO" as FASE, 0 as IDFASE,  FECHA_CALC as FECHA, CURRENT_TIME('Europe/Madrid') as HORA, desde as DESDE, hasta as HASTA, version_fl as VERSION;

  if (DB_CTX_TB_UPD=1 OR DIF_MFMC>0)  then

		call `mm-commissions-reporting.KRT_CARTERA.subprex_0010_NormalizarParametrizacion_ConvertirCerosANulos`(); 

    /*CARGA DE EVENTOS CARTERA*/
		SET TABLA='EVENTOS_CARTERA';
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO EVENTOS_CARTERA",10,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
    case when `mm-commissions-reporting.KRT_CARTERA.checkTableLoaded`(TABLA, FECHA_CALC, desde, hasta, version_fl) =0 then     
      case when `mm-commissions-reporting.KRT_CARTERA.checkTableDiscovered`(TABLA, FECHA_CALC, desde, hasta, version_fl) =1 then
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("RECARGO EVENTOS_CARTERA",12,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_CARTERA` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version and a.desde=desde and a.hasta=hasta;     
					call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);					
          
      else 
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("DESCUBRO EVENTOS_CARTERA",14,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    

					/*DESCUBRIMENTO DE EVENTOS*/
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnetv3` (desde, hasta);
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0102_DescubrirEventosEktnet_Telecablev4` (desde, hasta);
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0103_DescubrirEventosEktNet_NoTelecablev4` (desde, hasta);
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0104_UnificarEventosv3` ();
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0105_DescubrirEventosRv2` (desde, hasta);
				-- De momento mantenemos compatibilidad hacia adelante	
				--  ADAPTACION 
				--  A FUTURO
				--	call `mm-commissions-reporting.KRT_CARTERA.subproc_0106_TipificarProductosv2`();	
				-- ACTUAL

					/*TIPIFICACION DE EVENTOS*/

					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` as 
					select * except(tipoProductoOrigen,subtipoProductoOrigen,tipoProducto,subtipoProducto) from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ;
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0106_TipificarProductos`();
				--- FIN ADAPTACION

					/*OPERACION DE EVENTOS*/

					INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO OPERACION DE EVENTOS_CARTERA",16,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
					/*TIPIFICACION DE SOMOS*/
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0107_CalcularSomos` ();

					/*FILTRADO DE EVENTOS*/					
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0108_GestionarMigracionesyAutomatizaciones` (desde, hasta);
					CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0109_GestionarExclusionesDeVentasDeAgentes`();

					/*REGISTRO DE EVENTOS*/
          call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv3`(TABLA,desde, hasta,version_fl);
          call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);    

      end case;
    end case;
		INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO EVENTOS_CARTERA",19,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
    /*FIN CARGA DE EVENTOS CARTERA*/

    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO CALCULO DE UNITARIOS DE VENTAS",20,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0201_CalcularMRCanal` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0202_BorrarComisionesCaptacionv1` (desde);
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0203_AplicarUnitario` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0204_NetearANivelClienteCanal` ();
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO CALCULO DE BONOS",30,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);				
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0205_AplicarNivelConseguido` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0206_AplicarBonosCalidadYComercial` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0301_CalcularInfoCanal` ();
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO DE CAMPAÑAS",40,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0303_CargarCampanasTC` (desde, hasta);
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0304_CargarCampanasKVRACC` (desde, hasta);
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO CALCULO DE UNITARIOS DE TELEVENTAS",40,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);				
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0306_CalcularCampanasyMRv1` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0307_AplicarUnitario` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0308_AplicarMultiplicadorUpgrade` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0309_InsertarRappelUpselling` ();
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv3`(desde,hasta); 

    /*CARGA DECOMISION*/
		SET TABLA='DECOMISIONES';
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO DECOMISIONES",70,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
    case when `mm-commissions-reporting.KRT_CARTERA.checkTableLoaded`(TABLA, FECHA_CALC, desde, hasta, version_fl) =0 then     
      case when `mm-commissions-reporting.KRT_CARTERA.checkTableDiscovered`(TABLA, FECHA_CALC, desde, hasta, version_fl) =1 then
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("RECARGO DECOMISIONES",72,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version and a.desde=desde and a.hasta=hasta;     
          --INSERT INTO `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` VALUES (FECHA_CALC, CURRENT_TIME('Europe/Madrid'), TABLA, desde, hasta, VERSION_FL);
					call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);
      else 
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("DESCUBRO DECOMISIONES",74,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv4`(desde,hasta);
          call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv3`(TABLA,desde, hasta,version_fl);
          call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);
      end case;
    end case;
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO DECOMISIONES",79,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
    /*FIN CARGA DECOMISION*/


    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO COMISIONES",80,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0402_Comisionarv3`(desde,hasta);	
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0403_EliminarMigracionesyAutomatizaciones`();

	--  ADAPTACION 
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportarv3`();
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO GENERACION DE INFORMES",90,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportarv2`();
		--- FIN ADAPTACION

		if (DIF_MFMC=0 or (DIF_MFMC=1 and NDIAF<=5) and registro=1 ) then	
		--	DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20230601;SET hasta=20230630;SET registro=1;SET binvocaciondesarrollo=1;
		  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO REGISTRO HISTORICO DE COMISIONES",100,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
			call `mm-commissions-reporting.KRT_CARTERA.subproc_0701_ActualizarHistoricoDeCarterav2`(desde,hasta); 
		  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO REGISTRO DIARIO DE TABLAS",110,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
			call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv3`('RESTO',desde, hasta,version_fl);					
		end if;

	
		if (DIF_MFMC>1 and registro=1 ) then	
		----- PARCHE ----
		--DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO_R` WHERE 1=1 ;
		--DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_HISTORICO_R` WHERE 1=1 ;

			DELETE FROM `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO_R` where mes_comision_id=MES_COMISION and marca_ds='R';	
			INSERT INTO `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO_R` select *  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`where marca_ds='R';

			DELETE FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_HISTORICO_R` where mes_decomision_id=MES_COMISION and marca_ds='R';
			INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_HISTORICO_R` select * from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`where marca_ds='R';	


		----- FIN ----	
		end if;	
	
	end if;

  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("FIN FLUJO",200,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    


END