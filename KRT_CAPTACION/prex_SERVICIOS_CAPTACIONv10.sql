BEGIN 

  --DECLARE desde, hasta INT64;SET desde=20230101;SET hasta=20230120;  
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015000_CrearTablaServicios_Captacion`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015005_GestionarMigracionesDeServiciosPorCanalesNoInformados`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015010_GestionarMigracionesDeServiciosPorAgentesMigracion`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015020_IntegrarMigracionesEnTablaServicios_Captacion`(desde, hasta);  
  -- Al informar el parametro dexcluir a 0 se deshabilita la funcionalidad de exclusión de la no tipificación de los accesos móviles 
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0151_TipificarLineav6`(desde, hasta,0);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0161_CargarPlataformaCancelacionTv3` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0162_CargarPlataformaCancelacionKv4` (desde , hasta);
  -- MODIFICAION 20240219: CAUSA: CAMBIO DE PROCESO DE CANCELACION EN R EJECUTADO EN MARZO 2023 Y NO COMUNICADO
  --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0163_CargarPlataformaCancelacionRv3` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0163_CargarPlataformaCancelacionRv4` (desde , hasta);
  -- FIN MODIFICAION 20240219
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0112_NormalizarCamposTipoString`();
END