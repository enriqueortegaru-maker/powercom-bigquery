BEGIN 

call `mm-commissions-reporting.KRT_CAPTACION.subprex_0101_CargarServiciosPorNombre_NoRv3` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0102_CargarServiciosPorNombre_Rv3` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0103_CargarServiciosPorVelocidad_NoRv3` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0104_CargarServiciosPorVelocidad_Rv3` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0105_CargarCrmPorCatalogov2` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0106_CargarCrmPorCatalogo_Adicionalesv1` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0107_CargarVentasPorVelocidadOrigenRTC_R`(desde,hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0109_TipificarVentasCaptacionv1`();
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0110_RecrearIdentificativoDePedido`();
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0108_CorregirCategoriaDeProductoMamboAxina`();

CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0111_CrearTablaClientexNPlays_Vv1`(desde,hasta);
-- ESTE PROCEDIMININETO REVISAR PARA ELIMINAR FUE SUSTIUIDO POR EL 107
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0111_CargarServiciosPorVelocidadOrigenRTC_R`(desde, hasta);
-- FIN COMENTARIO
call `mm-commissions-reporting.KRT_CAPTACION.subpr_0112_NormalizarCamposTipoStringv1`();
END