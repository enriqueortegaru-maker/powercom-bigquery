BEGIN

  DECLARE VERSION_FL, FECHAF, DIF_MFMC, NDIAF, MES_COMISION  INT64;
	SET VERSION_FL=4;
  SET FECHAF=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE()) as INT64);
  SET NDIAF=CAST(FORMAT_DATE("%d",CURRENT_DATE()) as INT64);
  SET DIF_MFMC=CAST(FECHAF/100 AS INT64)-CAST(HASTA/100 AS INT64);
	SET MES_COMISION=CAST(DESDE/100 AS INT64);
  SELECT FECHAF,NDIAF,DIF_MFMC;

	--- VARIABLES LOCALES---
	--DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20230301;SET hasta=20230331;SET registro=0;SET binvocaciondesarrollo=0;

	--- Añadido 2023/02/25
	call `mm-commissions-reporting.KRT_CARTERA.subprex_0010_NormalizarParametrizacion_ConvertirCerosANulos`(); 
	--- Fin 
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnetv2` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0102_DescubrirEventosEktnet_Telecablev2` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0103_DescubrirEventosEktNet_NoTelecablev2` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0104_UnificarEventosv2` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0105_DescubrirEventosRv1` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0106_TipificarProductos`();
  CALL `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('EVENTOS_CARTERA',desde, hasta,version_fl);		
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0107_CalcularSomos` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0108_GestionarMigracionesyAutomatizaciones` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0201_CalcularMRCanal` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0202_BorrarComisionesCaptacion` ();
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
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv3`(desde,hasta);
	  CALL `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('DECOMISIONES',desde, hasta,version_fl);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0402_Comisionarv2`(desde,hasta);	
	--call `mm-commissions-reporting.KRT_CARTERA.subproc_0403_EliminarMigracionesyAutomatizaciones`();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportarv1`();
  if (DIF_MFMC=0 or (DIF_MFMC=1 and NDIAF<=5) and registro=1 ) then	
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0701_ActualizarHistoricoDeCarterav1`(desde,hasta);
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccionv1`(hasta, registro, binvocaciondesarrollo);	
	end if;

	
  --if (DIF_MFMC>1 and registro=1 ) then	
	----- PARCHE ----
	--DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO_R` WHERE 1=1 ;
	--DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.DECOMISION_HISTORICO_R` WHERE 1=1 ;

	  --DELETE FROM `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO_R` where mes_comision_id=MES_COMISION and marca_ds='R';	
	  --INSERT INTO `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO_R` select * except(agente_creador_id) from `mm-commissions-reporting.KRT_CARTERA.OUT_COMISION_DETALLE`where marca_ds='R';
	
		--DELETE FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISION_HISTORICO_R` where mes_decomision_id=MES_COMISION and marca_ds='R';
	  --INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISION_HISTORICO_R` select * except(fecha_baja_id) from `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES_DETALLE`where marca_ds='R';	
	----- FIN ----	
	--end if;	
	

END