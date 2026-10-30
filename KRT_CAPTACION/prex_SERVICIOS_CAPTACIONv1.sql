BEGIN 
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0101_CargarServiciosPorNombre_NoRv1` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0102_CargarServiciosPorNombre_Rv1` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0103_CargarServiciosPorVelocidad_NoRv1` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0104_CargarServiciosPorVelocidad_Rv1` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0105_CargarCrmPorCatalogo` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0106_CargarCrmPorCatalogo_Adicionales` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subpr_0107_TipificarLinea` (hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0108_CargarPlataformaCancelacionT` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0109_CargarPlataformaCancelacionK` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0110_CargarPlataformaCancelacionR` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subpr_0112_NormalizarCamposTipoString`();
END