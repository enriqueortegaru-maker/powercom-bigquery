BEGIN

  DECLARE FECHAF, DIF_MFMC, NDIAF, MES_COMISION, version_fl  INT64;
	--- VARIABLES LOCALES---
	--DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20230601;SET hasta=20230630;SET registro=1;SET binvocaciondesarrollo=1;
  SET FECHAF=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE()) as INT64);
  SET NDIAF=CAST(FORMAT_DATE("%d",CURRENT_DATE()) as INT64);
  SET DIF_MFMC=CAST(FECHAF/100 AS INT64)-CAST(HASTA/100 AS INT64);
	SET MES_COMISION=CAST(DESDE/100 AS INT64);
	SET version_fl=5;
  --SELECT FECHAF,NDIAF,DIF_MFMC;


	--- Añadido 2023/02/25
	call `mm-commissions-reporting.KRT_CARTERA.subprex_0010_NormalizarParametrizacion_ConvertirCerosANulos`(); 
	--- Fin 
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
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` as 
	select * except(tipoProductoOrigen,subtipoProductoOrigen,tipoProducto,subtipoProducto) from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ;
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0106_TipificarProductos`();
 --- FIN ADAPTACION
  

  CALL `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('EVENTOS_CARTERA',desde, hasta,version_fl);  
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0107_CalcularSomos` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0108_GestionarMigracionesyAutomatizaciones` (desde, hasta);
	CALL `mm-commissions-reporting.KRT_CARTERA.subproc_0109_GestionarExclusionesDeVentasDeAgentes`();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0201_CalcularMRCanal` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0202_BorrarComisionesCaptacionv1` (desde);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0203_AplicarUnitario` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0204_NetearANivelClienteCanal` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0205_AplicarNivelConseguido` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0206_AplicarBonosCalidadYComercial` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0301_CalcularInfoCanal` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0303_CargarCampanasTC` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0304_CargarCampanasKVRACC` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0306_CalcularCampanasyMRv1` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0307_AplicarUnitario` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0308_AplicarMultiplicadorUpgrade` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0309_InsertarRappelUpselling` ();
	--call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv3`(desde,hasta); 


	call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv4`(desde,hasta);
  CALL `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('DECOMISIONES',desde, hasta,version_fl);	

	call `mm-commissions-reporting.KRT_CARTERA.subproc_0402_Comisionarv3`(desde,hasta);	
	--call `mm-commissions-reporting.KRT_CARTERA.subproc_0403_EliminarMigracionesyAutomatizaciones`();

--  ADAPTACION 
	--call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportarv3`();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportarv2`();
	 --- FIN ADAPTACION

  if (DIF_MFMC=0 or (DIF_MFMC=1 and NDIAF<=5) and registro=1 ) then	
	--	DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20230601;SET hasta=20230630;SET registro=1;SET binvocaciondesarrollo=1;
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0701_ActualizarHistoricoDeCarterav2`(desde,hasta); 
		--call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv2`(hasta, registro, binvocaciondesarrollo);	
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
	

END