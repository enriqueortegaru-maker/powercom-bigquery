BEGIN 

  --- DESACTIVA  subprex_0170_CrearTablaRappelVentasv1
  --- ACTIVA     subprex_0170_CrearTablaRappelVentasv2

 -- LOCAL DECLARE desde_1m, hasta int64;SET desde_1m=20230801;SET desde=20230801; SET hasta=20230930;

call `mm-commissions-reporting.KRT_CAPTACION.subprex_0101_CargarServiciosPorNombre_NoRv4` (desde_1m , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0102_CargarServiciosPorNombre_Rv4` (desde_1m , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0103_CargarServiciosPorVelocidad_NoRv5` (desde_1m , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0104_CargarServiciosPorVelocidad_Rv4` (desde_1m , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_010410_CorregirVolumenDeDatosMovilesv1`();
call `mm-commissions-reporting.KRT_CAPTACION.subprex_010420_CorregirCanalizacionTcNetv1`();

call `mm-commissions-reporting.KRT_CAPTACION.subprex_0105_CargarCrmPorCatalogov5` (desde_1m , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0106_CargarCrmPorCatalogo_Adicionalesv1` (desde_1m , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0107_CargarVentasPorVelocidadOrigenRTC_Rv2`(desde_1m,hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0108_CargarPromocionesv0` (desde_1m , hasta);
Call `mm-commissions-reporting.KRT_CAPTACION.subprex_0108_CorregirCategoriaDeProductoMamboAxinav2`();
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0109_TipificarVentasCaptacionv3`();

call `mm-commissions-reporting.KRT_CAPTACION.subprex_0110_RecrearIdentificativoDePedido`();
CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_011020_CargarOfertasv1`();
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0108_CorregirCategoriaDeProductoMamboAxina`();

CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0111_CrearTablaClientexNPlays_Vv1`(desde_1m,hasta);
-- ESTE PROCEDIMININETO REVISAR PARA ELIMINAR FUE SUSTIUIDO POR EL 107
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0111_CargarServiciosPorVelocidadOrigenRTC_R`(desde_1m, hasta);
-- FIN COMENTARIO
call `mm-commissions-reporting.KRT_CAPTACION.subpr_0112_NormalizarCamposTipoStringv1`();
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0120_EliminarMigracionesyAutomatizaciones`();
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0120_EliminarMigracionesyAutomatizacionesv1`(desde_1m,hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0170_CrearTablaRappelVentasv2`(desde, hasta);
--call `mm-commissions-reporting.KRT_CAPTACION.subprex_0170_CrearTablaRappelVentasv1`(desde, hasta);
--CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0180_descubrirPortabilidadDeVentas`(desde, hasta);
--CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0180_descubrirPortabilidadDeVentasContextual`(desde, hasta);
--CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0180_descubrirPortabilidadDeVentasDatamark_kd`(desde_1m,desde, hasta);
CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0180_descubrirPortabilidadDeVentasDatamark_kd_CORRECTIVO_YOIGO_QUANTEL`(desde_1m, desde, hasta);

END