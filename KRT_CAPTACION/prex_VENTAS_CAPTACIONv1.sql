BEGIN 
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0101_CargarServiciosPorNombre_NoRv2` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0102_CargarServiciosPorNombre_Rv2` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0103_CargarServiciosPorVelocidad_NoRv2` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0104_CargarServiciosPorVelocidad_Rv2` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0105_CargarCrmPorCatalogov2` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0106_CargarCrmPorCatalogo_Adicionalesv1` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0107_CargarVentasPorVelocidadOrigenRTC_R`(desde,hasta);
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0108_CorregirCategoriaDeProductoMamboAxina`();
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0109_TipificarVentasCaptacion`();
CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0111_CrearTablaClientexNPlays_V`();
-- ESTE PROCEDIMININETO REVISAR PARA ELIMINAR FUE SUSTIUIDO POR EL 107
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0111_CargarServiciosPorVelocidadOrigenRTC_R`(desde, hasta);
-- FIN COMENTARIO
call `mm-commissions-reporting.KRT_CAPTACION.subpr_0112_NormalizarCamposTipoStringv1`();
END