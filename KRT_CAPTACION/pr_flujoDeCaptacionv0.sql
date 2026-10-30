BEGIN
  DECLARE VERSION_FL INT64;
  SET VERSION_FL=0;

  --call `mm-commissions-reporting.KRT_CAPTACION.pr_servicios_captacion`(desde , hasta);
  --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0002_ConvierteStringVacioEnNuloEnTablasDeParametros`();    
  call `mm-commissions-reporting.KRT_CAPTACION.pr_SERVICIOS_CAPTACION`(desde , hasta);  
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0201_CalcularMarcoRetributivo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0202_EliminarEventosConBajaPrevia`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0203_IncluirMultiplicador`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0301_CalcularRappel_Ventas`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0302_CalcularRappel_Subcanal`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0303_CalcularRappel_Canal`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0304_CalcularRappel_Presencial`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0305_CalcularRappel_Ventas_NoPresencial`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0306_CalcularRappel_Subcanal_NoPresencial`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0307_CalcularRappel_Canal_NoPresencial`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0308_CalcularRappel_Alcanzado`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0402_InsertarRappel_Teorico`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0403_InsertarRappel_Diferencia`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0501_CargarAjustesPortabilidadesIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0502_ActualizarUnitariosIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0503_CargarAjustesEventosDefinitivos`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0504_InsertarAjustesExtras`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0505_InsertarAjustesPostventa`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0601_CargarRetrasos`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0602_CalcularClawback`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0701_CargarVentasPorCliente`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0702_ClasificarVentasCliente`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0703_ClasificarVentasClienteTipificacion`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0801_EliminarRappelNoObjetivo`(desde, hasta);
  if registro >0 then
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_1001_ActualizarHistoricoDeCaptacion`(desde, hasta,version_fl);
  end if;
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_1002_ExportaHojasInformeExcel`(desde,hasta);
  if registro =1 and bdesarrollo >0 then  
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_1003_ActualizarTablasAggExtraccion`(hasta,registro,bdesarrollo);
  end if;  

END