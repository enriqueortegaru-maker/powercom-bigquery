BEGIN 
call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0101_CargarEventosPorNombre` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0102_CargarEventosPorBloque` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0103_CargarEventosPorCatalogo` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0104_TipificarLineasMoviles` (desde , hasta);
END