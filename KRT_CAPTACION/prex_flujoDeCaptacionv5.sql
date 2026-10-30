BEGIN

  DECLARE VERSION_FL, DESDE_1M INT64;
  --DECLARE DESDE, HASTA, REGISTRO, BDESARROLLO INT64;
  --SET DESDE=20230201;
  --SET HASTA=20230208;
  --SET REGISTRO=1;
  --SET BDESARROLLO=1;
  SET VERSION_FL=5;
  SET DESDE_1M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE AS string)), interval 1 month),month)) AS STRING) AS INT64);
  
  --call `mm-commissions-reporting.KRT_CAPTACION.pr_servicios_captacion`(desde , hasta);
  --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0002_ConvierteStringVacioEnNuloEnTablasDeParametros`(); 
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0010_MormalizarParametrizacion_ConvertirCerosANulos`();       
  call `mm-commissions-reporting.KRT_CAPTACION.prex_VENTAS_CAPTACIONv1`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('VENTAS_CAPTACION',desde, hasta,version_fl);  
  call `mm-commissions-reporting.KRT_CAPTACION.prex_SERVICIOS_CAPTACIONv5`(desde , hasta); 
  call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('SERVICIOS_CAPTACION',desde, hasta,version_fl);  
--  call `mm-commissions-reporting.KRT_CAPTACION.prex_EVENTOS_CANCELACION_CAPTACIONv1`(desde , hasta);
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
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0403_InsertarRappel_Diferenciav1`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0501_CargarAjustesPortabilidadesIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0502_ActualizarUnitariosIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0503_CargarAjustesEventosDefinitivos`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0504_InsertarAjustesExtras`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0505_InsertarAjustesPostventa`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0601_CargarRetrasos`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0602_CalcularClawback`(desde , hasta);
call `mm-commissions-reporting.KRT_CAPTACION.prex_FLUJO_UPD_TABLAS_PRINCIPALESv0`('DECOMISIONES',desde, hasta,version_fl);    
  --call `mm-commissions-reporting.KRT_CAPTACION.subpr_0701_CargarVentasPorCliente`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0701_CargarVentasPorClienteEnMesComisionado`();  
  --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0702_ClasificarVentasCliente`();
  --call `mm-commissions-reporting.KRT_CAPTACION.subpr_0703_ClasificarVentasClienteTipificacion`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0703_RegistrarPlaysEnMesComisionadov1`();    
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0801_EliminarRappelNoObjetivov2`(desde, hasta);
  if registro>0 then
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_1001_ActualizarHistoricoDeCaptacionv1`(desde, hasta, version_fl);
  end if;
  --call `mm-commissions-reporting.KRT_CAPTACION.subpr_1002_ExportaHojasInformeExcelv2`(desde,hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_1002_ExportaHojasInformeExcelv3`(desde,hasta,version_fl);  
  if registro =1 and bdesarrollo >0 then  

    call `mm-commissions-reporting.KRT_CAPTACION.subprex_1003_ActualizarTablasAggExtraccionv2`(desde, hasta,version_fl, registro,bdesarrollo);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_1004_ActualizarTablasAggParametrizacion`(hasta,registro,bdesarrollo);    
  end if;



END