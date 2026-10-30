BEGIN
  DECLARE VERSION_FL INT64;
  SET VERSION_FL=3;

  --call `mm-commissions-reporting.KRT_CAPTACION.pr_servicios_captacion`(desde , hasta);
  --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0002_ConvierteStringVacioEnNuloEnTablasDeParametros`()
  CALL `mm-commissions-reporting.KRT_CAPTACION.subprex_0001_CargarTablasDeParametrosv1`();
  call `mm-commissions-reporting.KRT_CAPTACION.prex_SERVICIOS_CAPTACIONv3`(desde , hasta);  
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0201_CalcularMarcoRetributivo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0202_EliminarEventosConBajaPrevia`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0203_IncluirMultiplicador`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0301_CalcularRappel_Ventas`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0302_CalcularRappel_Subcanalv1`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0303_CalcularRappel_Canalv2`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0304_CalcularRappel_Presencialv1`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0305_CalcularRappel_Ventas_NoPresencial`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0306_CalcularRappel_Subcanal_NoPresencialv1`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0307_CalcularRappel_Canal_NoPresencialv1`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0308_CalcularRappel_Alcanzado`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0402_InsertarRappel_Teorico`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0403_InsertarRappel_Diferencia`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0501_CargarAjustesPortabilidadesIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0502_ActualizarUnitariosIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0503_CargarAjustesEventosDefinitivos`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0504_InsertarAjustesExtras`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0505_InsertarAjustesPostventa`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0601_CargarRetrasos`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0602_CalcularClawback`(desde , hasta);
  --call `mm-commissions-reporting.KRT_CAPTACION.subpr_0701_CargarVentasPorCliente`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0701_CargarVentasPorClienteEnMesComisionado`();  
  --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0702_ClasificarVentasCliente`();
  --call `mm-commissions-reporting.KRT_CAPTACION.subpr_0703_ClasificarVentasClienteTipificacion`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0703_ClasificarVentasClienteTipificacionEnMesComisionado`();    
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0801_EliminarRappelNoObjetivov2`(desde, hasta);
  if registro>0 then
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_1001_ActualizarHistoricoDeCaptacion`(desde, hasta,version_fl);
  end if;
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_1002_ExportaHojasInformeExcel`(desde,hasta);
  if registro >0 and bdesarrollo >0 then  
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_1003_ActualizarTablasAggExtraccion`(hasta,registro,bdesarrollo);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_1004_ActualizarTablasAggParametrizacion`(hasta,registro,bdesarrollo);    
  end if;


END