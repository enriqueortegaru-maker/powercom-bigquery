BEGIN 
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0150_CrearTablaServicios_Captacion`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0151_TipificarLineav3`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0161_CargarPlataformaCancelacionTv1` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0162_CargarPlataformaCancelacionKv1` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0163_CargarPlataformaCancelacionRv1` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0112_NormalizarCamposTipoString`();

END