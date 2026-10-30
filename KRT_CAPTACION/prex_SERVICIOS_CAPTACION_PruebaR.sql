BEGIN 
call `mm-commissions-reporting.KRT_CAPTACION.subprex_0111_CargarServiciosPorVelocidadOrigenRTC_R` (desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.subpr_0111_NormalizarCamposTipoString`();
END