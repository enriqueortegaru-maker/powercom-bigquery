BEGIN

  DECLARE VERSION_FL, DESDE INT64;
  SET VERSION_FL=1;
  SET DESDE= CAST(FORMAT_DATE("%Y%m%d",PARSE_DATE("%Y%m",CAST(desde_mes AS STRING))) AS INT64);
  
  call `mm-commissions-reporting.COMISIONES.pr_energy_luz_nortev1`(desde_mes);
	call `mm-commissions-reporting.COMISIONES.pr_energy_gas_norte`(desde_mes,NULL);
	call `mm-commissions-reporting.COMISIONES.pr_energy_sve_norte`(desde_mes,NULL);
	call `mm-commissions-reporting.COMISIONES.pr_energy_svg_norte`(desde_mes,NULL);

  CALL `mm-commissions-reporting.KRT_MIG_PWC.subproc_energia_0100_creaUnificaComisionesEnergia`();  

	--call `mm-commissions-reporting.COMISIONES.pr_energy_rappel_objetivos_norte`(desde_mes,NULL);  
  --- DE MOMENTO SOLO SE PUEDE APLICAR MARCO TLV OUTBOUND CARTERA PENDIENTE DESARROLLO DEL RESTO
  call `mm-commissions-reporting.COMISIONES.pr_energy_rappel_objetivos_norte`(desde_mes,'TLV OUTBOUND CARTERA');  
  
	call `mm-commissions-reporting.COMISIONES.pr_energy_clawback_norte`(desde_mes);
  
  CALL `mm-commissions-reporting.KRT_MIG_PWC.subproc_energia_0110_canalizaEnCtxComisionesDeEnergia`(desde);  
  CALL `mm-commissions-reporting.KRT_MIG_PWC.subproc_energia_0120_canalizaEnCtxDecomisionesDeEnergia`(desde);

  

END