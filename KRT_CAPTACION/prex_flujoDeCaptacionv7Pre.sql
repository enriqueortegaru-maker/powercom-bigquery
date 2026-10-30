BEGIN
  DECLARE VERSION_FL, DESDE_1M INT64;
--  DECLARE DESDE, HASTA INT64;
--  SET DESDE=20230201;
--  SET HASTA=20230208;
  SET VERSION_FL=7;
  SET DESDE_1M=CAST(CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(parse_date('%Y%m%d', CAST ( DESDE AS string)), interval 1 month),month)) AS STRING) AS INT64);
  

  --call `mm-commissions-reporting.KRT_CAPTACION.pr_servicios_captacion`(desde , hasta);
  --call `mm-commissions-reporting.KRT_CAPTACION.subprex_0002_ConvierteStringVacioEnNuloEnTablasDeParametros`(); 
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0010_MormalizarParametrizacion_ConvertirCerosANulos`();       
  call `mm-commissions-reporting.KRT_CAPTACION.prex_VENTAS_CAPTACIONv3`(desde_1m , hasta);  
  call `mm-commissions-reporting.KRT_CAPTACION.prex_SERVICIOS_CAPTACIONv8`(desde , hasta); 
  --call `mm-commissions-reporting.KRT_CAPTACION.prex_EVENTOS_CAPTACIONv1`(desde , hasta);     
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0201_CalcularMarcoRetributivo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0202_EliminarEventosConBajaPreviav2`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0203_IncluirMultiplicadorv1`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0301_CalcularRappel_Ventas`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0302_CalcularRappel_Subcanalv1`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0303_CalcularRappel_Canalv2`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0304_CalcularRappel_Presencialv1`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0305_CalcularRappel_Ventas_NoPresencial`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0306_CalcularRappel_Subcanal_NoPresencialv1`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0307_CalcularRappel_Canal_NoPresencialv1`(hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0308_CalcularRappel_Alcanzado`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0402_InsertarRappel_Teoricov2`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0403_InsertarRappel_Diferenciav3`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0501_CargarAjustesPortabilidadesIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0502_ActualizarUnitariosIntragrupo`();
  call `mm-commissions-reporting.KRT_CAPTACION.subpr_0503_CargarAjustesEventosDefinitivos`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0504_InsertarAjustesExtrasv2`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0505_InsertarAjustesPostventav2`();
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0601_CargarRetrasosv1`(desde,hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0602_CalcularClawbackv1`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_0801_CrearComisionesv1`(desde, hasta);
  if registro>0 then
--  if registro>1000 then
    call `mm-commissions-reporting.KRT_CAPTACION.subpr_1001_ActualizarHistoricoDeCaptacionv1`(desde, hasta, version_fl);
  end if;
  call `mm-commissions-reporting.KRT_CAPTACION.subprex_1002_ExportaHojasInformeExcelv3`(desde,hasta,version_fl);
  if registro =1 and bdesarrollo >0 then  
--  if registro >1000 then  
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_1003_ActualizarTablasAggExtraccionv2`(desde, hasta,version_fl,registro,bdesarrollo);
    call `mm-commissions-reporting.KRT_CAPTACION.subprex_1004_ActualizarTablasAggParametrizacion`(hasta,registro,bdesarrollo);    
  end if;

END