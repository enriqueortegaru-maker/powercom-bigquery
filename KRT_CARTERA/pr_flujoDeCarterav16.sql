BEGIN

  DECLARE VERSION_FL, FECHAF, DIF_MFMC, NDIAF, MES_COMISION,DB_CTX_TB_UPD, VLOADED, VDISCOVERED  INT64;
	DECLARE FECHA_CALC DATE;
	DECLARE TABLA STRING;
	--- VARIABLES LOCALES---
	--DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20250201;SET hasta=20250228;SET registro=1;SET binvocaciondesarrollo=1;
	SET VERSION_FL=16;
  SET FECHAF=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE('Europe/Madrid')) as INT64);
  SET NDIAF=CAST(FORMAT_DATE("%d",CURRENT_DATE('Europe/Madrid')) as INT64);
  SET DIF_MFMC=DATE_DIFF(CURRENT_DATE('Europe/Madrid'),DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(DESDE AS STRING)),MONTH), MONTH);	
	SET MES_COMISION=CAST(DESDE/100 AS INT64);
	SET DB_CTX_TB_UPD= `mm-commissions-reporting.KRT_CARTERA.checkContextualDataBaseTablesUpdated`();
	---PARCHE PARA SALTAR RESTRICCION DE ACTUALIZACION
	--SET DB_CTX_TB_UPD=1;
	SET FECHA_CALC=CURRENT_DATE('Europe/Madrid');  
  --SELECT FECHAF,NDIAF,DIF_MFMC;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` as
  select "INICIO FLUJO" as FASE, 0 as IDFASE,  FECHA_CALC as FECHA, CURRENT_TIME('Europe/Madrid') as HORA, desde as DESDE, hasta as HASTA, version_fl as VERSION;

  if (DB_CTX_TB_UPD=1 OR DIF_MFMC>0)  then

		call `mm-commissions-reporting.KRT_CARTERA.subprex_0010_NormalizarParametrizacion_ConvertirCerosANulosv1`(); 

		--- PASO 1: DESCUBRO EVENTOS_CARTERA
    /*CARGA DE EVENTOS CARTERA*/
		SET TABLA='EVENTOS_CARTERA';
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO EVENTOS_CARTERA",10,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
		SET VLOADED=`mm-commissions-reporting.KRT_CARTERA.checkTableLoaded`(TABLA, FECHA_CALC, desde, hasta, version_fl);
    case when VLOADED=0 then     
			SET VDISCOVERED=`mm-commissions-reporting.KRT_CARTERA.checkTableDiscovered`(TABLA, FECHA_CALC, desde, hasta, version_fl);
      case when VDISCOVERED=1 then
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("RECARGO EVENTOS_CARTERA",12,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CARTERA.AGG_EVENTOS_CARTERA` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version_fl and a.desde=desde and a.hasta=hasta;     
					call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);					
          
      else 
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("DESCUBRO EVENTOS_CARTERA",14,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    

					/*DESCUBRIMENTO DE EVENTOS*/
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnetv3` (desde, hasta);
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0102_DescubrirEventosEktnet_Telecablev6` (desde, hasta);
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0103_DescubrirEventosEktNet_NoTelecablev4` (desde, hasta);
--					call `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnetv4` (desde, hasta);
--					call `mm-commissions-reporting.KRT_CARTERA.subproc_0102_DescubrirEventosEktnet_Telecablev7` (desde, hasta);
--					call `mm-commissions-reporting.KRT_CARTERA.subproc_0103_DescubrirEventosEktNet_NoTelecablev5` (desde, hasta);

					call `mm-commissions-reporting.KRT_CARTERA.subproc_0104_UnificarEventosv3` ();
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0105_DescubrirEventosRv2` (desde, hasta);
					--call `mm-commissions-reporting.KRT_CARTERA.subproc_010510_DescubrirEventosTrasladosRetencionR` (desde, hasta);
					call `mm-commissions-reporting.KRT_CARTERA.subproc_010510_DescubrirEventosTrasladosMRFidelizacionR` (desde, hasta);					


					/*TIPIFICACION DE EVENTOS*/
					call `mm-commissions-reporting.KRT_CARTERA.subproc_010610_NormalizarNombreDeCatalogoYTipoDeProductoDeCatalogosv1`();
					call `mm-commissions-reporting.KRT_CARTERA.subproc_010620_TipificarProductosv2`();

				-- De momento mantenemos compatibilidad hacia adelante	
				--  ADAPTACION 
				--  A FUTURO
				--	call `mm-commissions-reporting.KRT_CARTERA.subproc_010620_TipificarProductosv3`();	
				-- ACTUAL

				--- FIN ADAPTACION

					/*OPERACION DE EVENTOS*/

					INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO OPERACION DE EVENTOS_CARTERA",16,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
					/*TIPIFICACION DE SOMOS*/
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0107_CalcularSomos` ();

					/*FILTRADO DE EVENTOS*/					
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0108_GestionarMigracionesyAutomatizaciones` (desde, hasta);
					--CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0109_GestionarExclusionesDeVentasDeAgentes`();

					/*REGISTRO DE EVENTOS*/
					-----20250129 -> muevo registro AGG al punto final de case
          --call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv5`(TABLA,desde, hasta,version_fl);
          --call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);    

					/* PARCHE TEMPORAL*/


					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0109_ EVENTOS_CARTERA` AS 
					SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
					WHERE (canal="RETENCION" AND (subcanal="INBOUND" OR subcanal="AGENTE VENTAS CARTERA") )  
					AND contains_substr(nombre_distribuidor,"LANALDEN");

					update 	`mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
					SET canal="INBOUND"
					WHERE canal="RETENCION"
					AND subcanal="INBOUND"
					AND contains_substr(nombre_distribuidor,"LANALDEN");


					update 	`mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
					SET canal="INBOUND"
					WHERE canal="RETENCION"
					AND subcanal="AGENTE VENTAS CARTERA"
					AND contains_substr(nombre_distribuidor,"LANALDEN");


					/* FIN PARCHE TEMPORAL*/					

					/* DESCUBRO CAMPAÑAS DE T y KVRACC */
					INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("DESCUBRO CAMPAÑAS",17,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0303_CargarCampanasTCv3` (desde, hasta);
					--call `mm-commissions-reporting.KRT_CARTERA.subproc_0304_CargarCampanasKVRACCv1` (desde, hasta);
					call `mm-commissions-reporting.KRT_CARTERA.subproc_030410_CargarCampanasKVRACC_BIv4`(desde,hasta);		

					INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("ACTUALIZO MEDIO CONCIMIENTO",18,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
					CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0120_ActualizaMedioConocimientoConDatoCampana`();
					CALL  `mm-commissions-reporting.KRT_CARTERA.subproc_0130_creaTablaEventosTerminales`();

					/*	FIN DESCUBRO CAMPAÑAS DE T y KVRACC */

					-----20250129 -> muevo registro AGG al punto final de case
          call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv5`(TABLA,desde, hasta,version_fl);
          call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);    

      end case;
    end case;
		INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO EVENTOS_CARTERA",19,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
    /*FIN CARGA DE EVENTOS CARTERA*/

		/*UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
		set e.medio_conocimiento=c.NOMBRE_CAMPANA
		FROM `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c
		where c.marca_ds=e.marca_ds and c.cliente_id=e.idFijo and e.canal="TELEVENTA";


		UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
		set e.medio_conocimiento=c.NOMBRE_CAMPANA
		FROM `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c
		where c.marca_ds=e.marca_ds and c.cliente_id=e.idFijo  and e.canal="TELEVENTA";
		*/



		--- PASO 2: CALCULO UNITARIOS
		--- PASO 2.1: CALCULO UNITARIOS	VENTAS PRESENCIALES	
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO CALCULO DE UNITARIOS DE VENTAS",20,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
			--- Modificacion 20240223
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0201_CalcularMRCanal` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0201_CalcularMRCanalv1` ();		
			--- Fin Modificacion 

		--call `mm-commissions-reporting.KRT_CARTERA.subproc_020110_FiltrarEventosMR_Retencion_y_Atc`();	
		call `mm-commissions-reporting.KRT_CARTERA.subproc_020120_GestionarExclusionesDeVentasDeAgentes`();		
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0202_BorrarComisionesCaptacionv1` (desde);
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0203_AplicarUnitariov1` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0203_AplicarUnitario` ();
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_020310_AplicarRatioDeVenta_Unitario_SeguroMovil_MR_Retencion`();	
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_020310_AplicarRatioDeVenta_Unitario_SeguroMovil_MR_Fidelizacion`();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_020310_AplicarRatioDeVenta_Unitario_SeguroMovil_MR_Fidelizacionv1`();				
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0204_NetearANivelClienteCanalv2` ();
		CALL `mm-commissions-reporting.KRT_CARTERA.subproc_020410_AplicarImporteFijoAComision`();		
 
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO CALCULO DE BONOS",30,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);				
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0205_AplicarNivelConseguido` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0206_AplicarBonosCalidadYComercial` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0301_CalcularInfoCanal` ();

		--- PASO 2.2: CALCULO UNITARIOS	TELEVENTAS

    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO CALCULO DE UNITARIOS DE TELEVENTAS",40,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);				
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0306_CalcularCampanasyMRv3` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0307_AplicarUnitario` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0308_AplicarMultiplicadorUpgradev2` ();
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0309_InsertarRappelUpsellingv1` ();
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv3`(desde,hasta); 

		--- PASO 3: CALCULO DECOMISIONES
    /*CARGA DECOMISION*/
		SET TABLA='DECOMISIONES';
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO DECOMISIONES",70,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
		SET VLOADED=`mm-commissions-reporting.KRT_CARTERA.checkTableLoaded`(TABLA, FECHA_CALC, desde, hasta, version_fl);
    case when VLOADED=0 then     
			SET VDISCOVERED=`mm-commissions-reporting.KRT_CARTERA.checkTableDiscovered`(TABLA, FECHA_CALC, desde, hasta, version_fl);
      case when VDISCOVERED=1 then
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("RECARGO DECOMISIONES",72,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CARTERA.AGG_DECOMISIONES` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version_fl and a.desde=desde and a.hasta=hasta;     
          --INSERT INTO `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` VALUES (FECHA_CALC, CURRENT_TIME('Europe/Madrid'), TABLA, desde, hasta, VERSION_FL);
					call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);
      else 
          INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("DESCUBRO DECOMISIONES",74,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
					call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv5`(desde,hasta);
					CALL `mm-commissions-reporting.KRT_CARTERA.subproc_040101_IntegrarDecomisionesEnergia`(DESDE, HASTA);
					--call `mm-commissions-reporting.KRT_CARTERA.subproc_040110_PonderarDecomisionesMR_Retencion`();
					call `mm-commissions-reporting.KRT_CARTERA.subproc_040110_PonderarDecomisionesMR`();
					DELETE from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` where contains_Substr(MARCO_RETRIBUTIVO,"aprovecha");
          call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv5`(TABLA,desde, hasta,version_fl);
          call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);
      end case;
    end case;
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO DECOMISIONES",79,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
    /*FIN CARGA DECOMISION*/


		--- PASO 4: CALCULO COMISIONES
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO COMISIONES RESIDENCIALES",80,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0402_Comisionarv4`(desde,hasta);	
		
		--- PASO 4.1: CALCULO COMISIONES RESIDENCIAL
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0402_Comisionarv7`(desde,hasta);	
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0402_Comisionarv9`(desde,hasta);	
		call `mm-commissions-reporting.KRT_CARTERA.subproc_040210_GestionarComisionesDuplicadas`(desde,hasta);
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0403_EliminarMigracionesyAutomatizaciones`();

		--- PASO 4.2: CALCULO COMISIONES B2B

		if (DIF_MFMC>0 or (DIF_MFMC=0 and NDIAF>=22) and registro=1 ) then	
			SET TABLA='COMISIONES';
			INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO COMISIONES B2B",85,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
			SET VLOADED=`mm-commissions-reporting.KRT_CARTERA.checkTableLoaded`(TABLA, FECHA_CALC, desde, hasta, version_fl);
			case when VLOADED=0 then     
				SET VDISCOVERED=`mm-commissions-reporting.KRT_CARTERA.checkTableDiscovered`(TABLA, FECHA_CALC, desde, hasta, version_fl);
				case when VDISCOVERED=1 then
						INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("RECARGO COMISIONES B2B",86,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES_B2B` AS 
						--SELECT * except(fecha_calc_dt, desde, hasta,version) 
						SELECT * except(fecha_calc_dt, desde, hasta,version,orden_sap) 
						from  `mm-commissions-reporting.KRT_CARTERA.AGG_COMISIONES` a 
						where a.fecha_calc_dt=FECHA_CALC and a.version=version_fl and a.desde=desde and a.hasta=hasta;
						DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES_B2B` WHERE UPPER(TRIM(canal))="B2B";
						--INSERT INTO `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` VALUES (FECHA_CALC, CURRENT_TIME('Europe/Madrid'), TABLA, desde, hasta, VERSION_FL);
						call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);
				--- SI EL FLUJO NO SE HA EJECUTADO. CALCULO LAS COMISIONES B2B    				
				else 
						INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("DESCUBRO COMISIONES_B2B",87,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);   
						CALL `mm-commissions-reporting.KRT_CARTERA.subproc_040410_ComisionesB2B_Eroski_v2`(desde,hasta);
						CALL `mm-commissions-reporting.KRT_CARTERA.subproc_040420_ComisionesB2B_Racc_v2`(desde, hasta); 
						CALL `mm-commissions-reporting.KRT_CARTERA.subproc_040490_Genera_ComisionesB2B_v1`();
						DELETE FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` WHERE UPPER(TRIM(canal))="B2B";
						---call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv5`(TABLA,desde, hasta,version_fl);
						call `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);
				end case;
			end case;
			--- INSERTO LAS COMISIONES B2B EN LA TABLA COMISIONES
			INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES_B2B` WHERE 1=1;						
			--INSERT INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES` SELECT * except(claseProducto) FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES_B2B` WHERE 1=1;			

			--- REGISTRO PASO EN LOG DEL FLUJO
			INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("FINALIZO COMISIONES B2B",88,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
			/*FIN CARGA COMISIONES B2B*/

		end if;



		--- PASO 4.5: INTEGRO ORDENES SAP EN COMISIONES
			--- REGISTRO PASO EN LOG DEL FLUJO
		INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INTEGRO ORDENES SAP EN COMISIONES B2B",89,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
		
		CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0405_IntegrarOrdenesSAP_v1`();

		INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INTEGRO RETRASOS",90,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
		CALL `mm-commissions-reporting.KRT_CARTERA.subproc_040500_IntegroComisionesProcedentesDeRetrasosv1`(desde);	
		CALL `mm-commissions-reporting.KRT_CARTERA.subproc_040510_IntegrarComisionesEnergia`(DESDE, HASTA);	

		INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("APLICO CORRECTIVO ORDENES SAP",92,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
		CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0407_CorrectivoDeOrdenesSap`();

		INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("CREO COMISIONES LISTADO",94,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    				
		CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0408_CrearComisiones_Listadov1`();
		--CALL `mm-commissions-reporting.KRT_CARTERA.subprex_0409_RegistroHistoricoComisionesCarteraFacturadoEnProcesov1`(desde, hasta);

		--- PASO 5: GENERO INFORMES
	--  ADAPTACION 
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportarv3`();
    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO GENERACION DE INFORMES",100,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportarv2`();
		--- FIN ADAPTACION

		if (DIF_MFMC=0 or (DIF_MFMC=1 and NDIAF<=8) and registro=1 ) then	
		--	DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20230601;SET hasta=20230630;SET registro=1;SET binvocaciondesarrollo=1;
		  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO REGISTRO HISTORICO DE COMISIONES",100,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
			call `mm-commissions-reporting.KRT_CARTERA.subproc_0701_ActualizarHistoricoDeCarterav3`(desde,hasta); 

		  INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO REGISTRO DIARIO DE TABLAS",110,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
			call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv5`('RESTO',desde, hasta,version_fl);					
		end if;

    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("REGISTRO HISTORICO FACTURADO",120,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
		--CALL `mm-commissions-reporting.KRT_CARTERA.subprex_0409_RegistroHistoricoComisionesCarteraFacturadoEnProcesov1`(desde, hasta);
		CALL `mm-commissions-reporting.KRT_CARTERA.subprex_0409_RegistroHistoricoComisionesCarteraFacturadoEnProcesov2_DesarrolloIntegracion`(desde, hasta);

 
  	INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO ACTUALIZACION DE TRANSACCIONES",110,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
	 	CALL `mm-commissions-reporting.KRT_SAP.subproc_0110_ActualizarTablaTransaccionesv1`(desde,"CARTERA");
		CALL `mm-commissions-reporting.KRT_SAP.subproc_0115_ActualizarTablaAggTransaccionesv1`(desde);
		CALL `mm-commissions-reporting.KRT_SAP.subproc_0118_ActualizarTablaSapKpiCierrev1`(desde); 
		

		if (DIF_MFMC=0 or (DIF_MFMC=1 and NDIAF<=15)) then	

			INSERT INTO `mm-commissions-reporting.KRT_CARTERA.LOG_FLUJO` VALUES ("INICIO REGISTRO HISTORIOC DE TERMINALES",120,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
			CALL `mm-commissions-reporting.KRT_CARTERA.subprex_0410_RegistroHistoricoTerminalesEnProceso`(desde, hasta, version_fl);

		end if;


		if (DIF_MFMC>9999 and registro=1 ) then	
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