BEGIN 

  --DECLARE desde, hasta INT64;SET desde=20230701;SET hasta=20230731;
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015000_CrearTablaServicios_Captacion`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015005_GestionarMigracionesDeServiciosPorCanalesNoInformados`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015010_GestionarMigracionesDeServiciosPorAgentesMigracion`(desde, hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_015020_IntegrarMigracionesEnTablaServicios_Captacion`(desde, hasta);  
  
  -- El valor 1 en el parametro excluir a 1, habilita la funcionalidad de exclusión de la no tipificación de los accesos móviles 
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0151_TipificarLineav5`(desde, hasta,1);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0161_CargarPlataformaCancelacionTv3` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0162_CargarPlataformaCancelacionKv4` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0163_CargarPlataformaCancelacionRv3` (desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0112_NormalizarCamposTipoString`();
END