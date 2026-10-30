BEGIN

  DECLARE VERSION_FL, FECHAF, DIF_MFMC, NDIAF  INT64;
	SET VERSION_FL=1;
  SET FECHAF=CAST(FORMAT_DATE("%Y%m%d",CURRENT_DATE()) as INT64);
  SET NDIAF=CAST(FORMAT_DATE("%d",CURRENT_DATE()) as INT64);
  SET DIF_MFMC=CAST(FECHAF/100 AS INT64)-CAST(HASTA/100 AS INT64);
  SELECT FECHAF,NDIAF,DIF_MFMC;

	--- VARIABLES LOCALES---
	--DECLARE desde, hasta, registro, binvocaciondesarrollo INT64;SET desde=20230301;SET hasta=20230331;SET registro=0;SET binvocaciondesarrollo=0;

	--- Añadido 2023/02/25
	call `mm-commissions-reporting.KRT_CARTERA.subprex_0010_NormalizarParametrizacion_ConvertirCerosANulos`(); 
	--- Fin 
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnetv1` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0102_DescubrirEventosEktnet_Telecablev1` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0103_DescubrirEventosEktNet_NoTelecablev1` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0104_UnificarEventosv1` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0105_DescubrirEventosR` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0106_TipificarProductos`();
	CALL `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('EVENTOS_CARTERA',desde, hasta,version_fl);	

	call `mm-commissions-reporting.KRT_CARTERA.subproc_0107_CalcularSomos` ();
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
	--call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionar`(desde,hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionarv1`(desde,hasta);	
	CALL `mm-commissions-reporting.KRT_CARTERA.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('DECOMISIONES',desde, hasta,version_fl);	
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0402_Comisionar`(desde,hasta);	
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportar`();
  if (DIF_MFMC=0 or (DIF_MFMC=1 and NDIAF<=5) and registro=1 ) then		
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0701_ActualizarHistoricoDeCartera`(desde,hasta);
		call `mm-commissions-reporting.KRT_CARTERA.subproc_0801_ActualizarTablasAggExtraccion`(hasta, registro, binvocaciondesarrollo);	
	end if;
END