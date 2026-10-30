BEGIN

  --- DESACTIVA subprex_0202_EliminarEventosConBajaPreviav2
  --- ACTIVA    subprex_0202_EliminarEventosConBajaPreviav3

  


  DECLARE VERSION_FL, DESDE_1M, FECHAF, DIF_MFMC, NDIAF,DB_CTX_TB_UPD,NSERV, BRECALCULO, VLOADED, VDISCOVERED  INT64;
  DECLARE FECHA_CALC DATE;
  DECLARE TABLA STRING;
  --- VARIABLES LOCALES
  --DECLARE DESDE, HASTA, REGISTRO,BDESARROLLO INT64;SET DESDE=20251001;SET HASTA=20251031;SET REGISTRO=1;SET BDESARROLLO=1;
  ---- FIN VARIABLES LOCALES
  --DECLARE DESDE, HASTA, VERSION INT64;
  SET VERSION_FL=23;
  SET DESDE_1M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE AS string)), interval 1 month),month)) AS STRING) AS INT64);
  SET FECHAF=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE('Europe/Madrid')) as INT64);
  SET NDIAF=CAST(FORMAT_DATE("%d",CURRENT_DATE('Europe/Madrid')) as INT64);
  SET DIF_MFMC=DATE_DIFF(CURRENT_DATE('Europe/Madrid'),DATE_TRUNC(PARSE_DATE("%Y%m%d",CAST(DESDE AS STRING)),MONTH), MONTH);
  SET FECHA_CALC=CURRENT_DATE('Europe/Madrid');  
  SET DB_CTX_TB_UPD= `mm-commissions-reporting.KRT_CAPTACION.checkContextualDataBaseTablesUpdated`();
  SET NSERV=`mm-commissions-reporting.KRT_CAPTACION.getNserv_AGG_SERVICIOS_CAPTACION`(fecha_calc, desde, hasta, version_fl); 
  SET BRECALCULO=0;

  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` as
  select "INICIO FLUJO" as FASE, 0 as IDFASE,  FECHA_CALC as FECHA, CURRENT_TIME('Europe/Madrid') as HORA, desde as DESDE, hasta as HASTA, version_fl as VERSION;
  
  --PARCHE SALTARSE CONTROL ACTUALIZACION
  SET DB_CTX_TB_UPD=1;
  if (DB_CTX_TB_UPD=1 OR DIF_MFMC>0)  then
    --call `mm-commissions-reporting.KRT_CAPTACION.pr_servicios_captacion`(desde , hasta);
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0002_ConvierteStringVacioEnNuloEnTablasDeParametros`(); 
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0010_MormalizarParametrizacion_ConvertirCerosANulos`(); 
 
    /*CARGA DE VENTAS CAPTACION*/
    SET TABLA='VENTAS_CAPTACION';
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO VENTAS_CAPTACION",10,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde_1m,hasta, version_fl);
		SET VLOADED=`mm-commissions-reporting.KRT_CAPTACION.checkTableLoaded`(TABLA, FECHA_CALC, desde_1m, hasta, version_fl);
    case when VLOADED=0 then     
			SET VDISCOVERED=`mm-commissions-reporting.KRT_CAPTACION.checkTableDiscovered`(TABLA, FECHA_CALC, desde_1m, hasta, version_fl);
      case when VDISCOVERED=1 then
          INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("RECARGO VENTAS_CAPTACION",12,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde_1m,hasta, version_fl);
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CAPTACION.AGG_VENTAS_CAPTACION` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version_fl and a.desde=desde_1m and a.hasta=hasta;
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CAPTACION.AGG_RAPPEL_VENTAS` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version_fl and a.desde=desde_1m and a.hasta=hasta;
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS_NO_PRESENCIAL` AS SELECT * from  `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_VENTAS`;                         
          call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde_1m, hasta,version_fl);        
          --INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.FLUJO_ACTUALIZACION_TABLA_INTERMEDIA` VALUES (FECHA_CALC, CURRENT_TIME('Europe/Madrid'), TABLA, desde_1m, hasta, version_fl);
      else 
          INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("DESCUBRO VENTAS_CAPTACION",14,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde_1m,hasta, version_fl);      
          call `mm-commissions-reporting.KRT_CAPTACION.prex_VENTAS_CAPTACIONv14`(desde_1m , desde, hasta); 
          call `mm-commissions-reporting.KRT_CAPTACION.subprex_1003_ActualizarTablasAggExtraccionv5`(TABLA,desde_1m, hasta,version_fl);
          call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde_1m, hasta,version_fl);
      end case;
    end case;

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO VENTAS_CAPTACION",19,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    

    /*CARGA DE SERVICIOS CAPTACION*/
    SET TABLA='SERVICIOS_CAPTACION';
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO SERVICIOS_CAPTACION",20,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
		SET VLOADED=`mm-commissions-reporting.KRT_CAPTACION.checkTableLoaded`(TABLA, FECHA_CALC, desde, hasta, version_fl);
    case when VLOADED=0 then     
			SET VDISCOVERED=`mm-commissions-reporting.KRT_CAPTACION.checkTableDiscovered`(TABLA, FECHA_CALC, desde, hasta, version_fl);
      case when VDISCOVERED=1 then
          INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("RECARGO SERVICIOS_CAPTACION",22,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
          /*Recargo datos*/
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version_fl and a.desde=desde and a.hasta=hasta;
          call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde_1m, hasta,version_fl);               
          --INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.FLUJO_ACTUALIZACION_TABLA_INTERMEDIA` VALUES (FECHA_CALC, CURRENT_TIME('Europe/Madrid'),TABLA, desde, hasta, version_fl);
      else 
          INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("DESCUBRO SERVICIOS_CAPTACION",24,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);      
          call `mm-commissions-reporting.KRT_CAPTACION.prex_SERVICIOS_CAPTACIONv10`(desde , hasta); 
          call `mm-commissions-reporting.KRT_CAPTACION.subprex_1003_ActualizarTablasAggExtraccionv5`(TABLA,desde, hasta,version_fl);    
          call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde, hasta,version_fl);  
      end case;
    end case;
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO SERVICIOS_CAPTACION",29,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
     
    --call `mm-commissions-reporting.KRT_CAPTACION.prex_EVENTOS_CAPTACIONv1`(desde , hasta);     
    /*PARCHE HASTA INTEGRAR EN SERVICIOS_CAPTACION*/
    -- SE INTEGRA CUANDO INTEGREMOS subprex_0501_CargarAjustesPortabilidadesIntragrupov1
    -- PENDIENTE DE INTEGRAR EN SERVICIOS CAPTACION
    --call  `mm-commissions-reporting.KRT_CAPTACION.subprex_0180_DescubrirServiciosCaptadosConPortabilidadEntrantev1`(desde, hasta);
    /*FIN PARCHE HASTA INTEGRAR EN SERVICIOS_CAPTACION*/

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO UNITARIOS",30,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);            
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0201_CalcularMarcoRetributivo`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_020110_descubreMarcoRetributivoyGrupoDeRappelAsignadoPorEvento`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_020110_descubreMarcoRetributivoyGrupoDeRappelAsignadoPorEventov2`();    
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_020120_asignarImporteUnitarioPorEvento`(desde, hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0202_EliminarEventosConBajaPreviav3`(desde , hasta);

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO RAPPEL",40,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
    
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0203_IncluirMultiplicadorv2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0300_CalcularRappelAlcanzadov1`(hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0400_InsertarRappel_Integrado`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0420_ProcesaRappelv1`();
    
    /*
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0301_CalcularRappel_Ventasv1`(desde , hasta);                    
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0301_CalcularRappel_Ventasv2`(desde , hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0302_CalcularRappel_Subcanalv1`(hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0303_CalcularRappel_Canalv2`(hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0304_CalcularRappel_Presencialv1`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0305_CalcularRappel_Ventas_NoPresencialv1`(desde , hasta);    
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0305_CalcularRappel_Ventas_NoPresencialv2`(desde , hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0306_CalcularRappel_Subcanal_NoPresencialv1`(hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0307_CalcularRappel_Canal_NoPresencialv1`(hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_0308_CalcularRappel_Alcanzado`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0402_InsertarRappel_Teoricov2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0403_InsertarRappel_Diferenciav3`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0420_ExcluirComisionesDeRappelPorCatalogov2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0425_PonderarComisionesDeRappelPorCanalyCatalogo`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0430_ExcluirComisionesDeRappelPorOfertasyPromociones`();
    */


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO AJUSTES",50,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);                    
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0501_CargarAjustesPortabilidadesIntragrupo`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0501_CargarAjustesPortabilidadesIntragrupov1`();    
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0502_ActualizarUnitariosIntragrupo`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_050110_descubrirPortabilidadDeEventos`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_050110_penalizarPortabilidadesIntragrupo`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_050110_penalizarPortabilidadesIntragrupoContextual`(desde, hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_050110_penalizarPortabilidadesIntragrupoxPedido_Datamark_kd`(desde, hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_050110_penalizarPortabilidadesIntragrupoxContrato_Datamark_kd`(desde, hasta);    
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_050115_auditaOrigenesPenalizacionesPortabilidadesIntragrupo`();
    CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_050120_insertarPenalizacionesPorPortabilidadesIntragrupoEnMarcoRetributivo`("Contrato");
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_0503_CargarAjustesEventosDefinitivos`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0504_InsertarAjustesExtrasv3`();
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0504_InsertarAjustesExtrasv4`();  
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_050410_CrearApuntesDistribucionExtrasv3`();      
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0505_InsertarAjustesPostventav2`();
    CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0506_ActualizarConceptoOfertasYPromociones`();    
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0601_CargarRetrasosv3`(desde,hasta);
    -- modificación
    --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0602_CalcularClawbackv4`(desde , hasta);

    /*CARGA DE DECOMISIONES*/
    SET TABLA='DECOMISIONES';    
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO DECOMISONES",70,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
		SET VLOADED=`mm-commissions-reporting.KRT_CAPTACION.checkTableLoaded`(TABLA, FECHA_CALC, desde, hasta, version_fl);
    case when VLOADED=0 then     
			SET VDISCOVERED=`mm-commissions-reporting.KRT_CAPTACION.checkTableDiscovered`(TABLA, FECHA_CALC, desde, hasta, version_fl);
      case when VDISCOVERED=1 then
          INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("RECARGO DECOMISIONES",72,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
          /*Recargo datos*/
          CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` AS SELECT * except(fecha_calc_dt, desde, hasta,version) from  `mm-commissions-reporting.KRT_CAPTACION.AGG_DECOMISIONES` a 
          where a.fecha_calc_dt=FECHA_CALC and a.version=version_fl and a.desde=desde and a.hasta=hasta;
          call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`(TABLA,desde_1m, hasta,version_fl);     
          --INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.FLUJO_ACTUALIZACION_TABLA_INTERMEDIA` VALUES (FECHA_CALC, CURRENT_TIME('Europe/Madrid'), TABLA, desde, hasta, vversion_fl);
      else 
          INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("DESCUBRO DECOMISIONES",74,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);      
          CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0602_CalcularClawbackv9`(DESDE, HASTA);
          CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0603_CalcularClawback_SVA_Rv2`(DESDE, HASTA);
          CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0604_IntegrarDecomisionesEnergia`(DESDE, HASTA);
          CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0605_BorrarDecomisionesDeDistribuidoresNoCanalizados`();

          call `mm-commissions-reporting.KRT_CAPTACION.subprex_1003_ActualizarTablasAggExtraccionv5`('DECOMISIONES',desde, hasta,version_fl);
          call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('DECOMISIONES',desde, hasta,version_fl);
      end case;
    end case;
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO DECOMISIONES",79,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    

--- PARCHE TEMPORAL
    if ( DESDE>=202501 ) then
      DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` where marca_ds="EUSKALTEL" and canal_alta_ds="WEB" and subcanal_ds="WEB AUTOMATICA";  
    END IF;

     ---- MOVERLO AL CUERPO DE DECOMISIOES 
--- FIN PARCHE TEMPORAL

    --- fin modificación
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO PROCESAMIENTO COMISIONES",80,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0801_CrearComisionesv2`(desde, hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0803_PenalizarRappelDeComisionesv2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0804_ComisionarVentasStandsEnCentrosEroski_v2`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_080410_ComisionarVentasTeleribera`(desde);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0805_CorrectivoDeOrdenesSap`();
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0807_CorrectivoDeCategoriaServicio`();
    --CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0808_CorrectivoDeMarcoRetributivo`(desde);    
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0809_CorrectivoDeTecnologia`();    
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_0810_IntegroComisionesProcedentesDeRecalculoMesPrevio`(desde, hasta);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_082020_IntegrarComisionesEnergia`(desde, hasta);
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("FINALIZO PROCESAMIENTO COMISIONES",85,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);        

  --  if (DIF_MFMC=1 and NDIAF>=19) or (DIF_MFMC=2)  then
    if (((DIF_MFMC=1 OR DIF_MFMC=89 ) and NDIAF>=14)  OR BRECALCULO=1 ) then
      SELECT "ENTRO EN RECALCULO DE COMISIONADO", FECHAF,NDIAF,DIF_MFMC;
  	  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO RECALCULO DE COMISIONES MES PREVIO",88,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		

      --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0850_RecalculoComisionesMesPreviov3`(desde,hasta);
      CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0850_RecalculoComisionesMesPreviov3_EVOLUCIONADO_PENDIENTE_DE_CORREGIR_NUMERACION_TELECABLE`(desde, hasta);

      SET BRECALCULO=1;
  	  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("FINALIZO RECALCULO DE COMISIONES MES PREVIO",89,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		

    else 
      SELECT "ENTRO EN BORRADO DE TABLA DE RECALCULO DE COMISIONADO", FECHAF,NDIAF,DIF_MFMC;
      delete from `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` where 1=1;
    end if;

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO INTEGRACION DE OPEX VENTASº",100,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);        
    CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0862_IntegrarComisionesOpexVentas`(desde, hasta);



    if registro =1 and bdesarrollo >0 then  
  --  if registro >1000 then  
  
		  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO REGISTRO DIARIO DE TABLAS DE EXTRACCIONES",110,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
      call `mm-commissions-reporting.KRT_CAPTACION.subprex_1003_ActualizarTablasAggExtraccionv5`('RESTO',desde, hasta,version_fl);  

    /*HAY QUE INCLUIR ACTUALIZAR HISTORICO DE BAJAS EN CONDICION IF*/
      if ((DIF_MFMC=0 or (DIF_MFMC=1 and NDIAF<=8)) and registro=1 ) then
        INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO REGISTRO HISTORICO DE COMISIONES",120,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);		
        call `mm-commissions-reporting.KRT_CAPTACION.subprex_1001_ActualizarHistoricoDeCaptacionv4`(desde, hasta, version_fl);
        call `mm-commissions-reporting.KRT_CAPTACION.subprex_100120_ActualizarHistoricoDeMigraciones`(desde, hasta, version_fl);
        --call `mm-commissions-reporting.KRT_CAPTACION.subprex_100130_ActualizarHistoricoDeBajas`(desde,hasta,version_fl);
      end if;

      INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO ACTUALIZACION DE HISTORICO DE BAJAS",125,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);
      call `mm-commissions-reporting.KRT_CAPTACION.subprex_100130_ActualizarHistoricoDeBajas`(desde,hasta,version_fl);

      INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO GENERACION DE INFORMES",127,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
      call `mm-commissions-reporting.KRT_CAPTACION.subprex_1002_ExportaHojasInformeExcelv5`(desde,hasta,version_fl);

		  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO REGISTRO DIARIO DE TABLAS DE PARAMETRIZACIONES",130,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);      
      --call `mm-commissions-reporting.KRT_CAPTACION.subprex_1003_ActualizarTablasAggExtraccionv2`(desde, hasta,version_fl,registro,bdesarrollo);
      call `mm-commissions-reporting.KRT_CAPTACION.subprex_1004_ActualizarTablasAggParametrizacionv2`(desde, hasta,registro,bdesarrollo);    
        
    end if;

    -- INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("FIN PROCESAMIENTO",80,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    

  end if;

  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO ACTUALIZACION DE REGISTRO HISTORICO DE CAPTACION",140,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);

  --CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0910_RegistroHistoricoComisionesCaptacionFacturadoEnProcesov1`(desde, hasta);
  CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0910_RegistroHistoricoComisionesCaptacionFacturadoEnProcesov2_DESARROLLO_INTEGRACION`(desde, hasta);
  CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0920_RegistroHistoricoComisionesCaptacionDetalladoEnProcesov2`(desde, hasta);


  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("INICIO ACTUALIZACION DE TRANSACCIONES",150,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    
  --CALL `mm-commissions-reporting.KRT_SAP.subproc_0110_ActualizarTablaTransaccionesv1`(desde,"CAPTACION");
--  CALL `mm-commissions-reporting.KRT_SAP.subproc_0110_ActualizarTablaTransaccionesv2`(desde,"CAPTACION");
  CALL `mm-commissions-reporting.KRT_SAP.subproc_0110_ActualizarTablaTransaccionesv3`(desde,"CAPTACION");
  --CALL `mm-commissions-reporting.KRT_SAP.subproc_0112_ActualizarOrdenesSapEnTablaTransaccionesv0`(desde,"CAPTACION");
  CALL `mm-commissions-reporting.KRT_SAP.subproc_0112_ActualizarOrdenesSapEnTablaTransaccionesv2`(desde,"CAPTACION");
  --- INCLUIDO 2026-10-08
  CALL `mm-commissions-reporting.KRT_SAP.subproc_0114_RegistrarCodigoSapTablaTransacciones`(desde,"CAPTACION");  
  --- FIN INCLUIDO 2026-10-08  
	CALL `mm-commissions-reporting.KRT_SAP.subproc_0115_ActualizarTablaAggTransaccionesv1`(desde);
  CALL `mm-commissions-reporting.KRT_SAP.subproc_0118_ActualizarTablaSapKpiCierrev1`(desde);  


  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.LOG_FLUJO` VALUES ("FIN FLUJO",200,FECHA_CALC, CURRENT_TIME('Europe/Madrid'),desde,hasta, version_fl);    


END