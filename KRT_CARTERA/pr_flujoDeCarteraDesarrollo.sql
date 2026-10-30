BEGIN
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0101_DescubrirEventosTcnet` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0102_DescubrirEventosEktnet_Telecable` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0103_DescubrirEventosEktNet_NoTelecable` (desde, hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0105_UnificarEventos` ();
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
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0306_CalcularCampanasyMR` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0307_AplicarUnitario` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0308_AplicarMultiplicadorUpgrade` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0309_InsertarRappelUpselling` ();
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0401_Decomisionar`(desde,hasta);
	call `mm-commissions-reporting.KRT_CARTERA.subproc_0501_Exportar`();
END