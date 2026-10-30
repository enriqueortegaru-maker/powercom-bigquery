BEGIN
  DECLARE VERSION_FL, DESDE_MES INT64;

  SET VERSION_FL = 1;
  SET DESDE_MES = CAST(CAST(FORMAT_DATE("%Y%m", DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST(DESDE AS STRING)), MONTH)) AS STRING) AS INT64);

  CALL `mm-commissions-reporting`.KRT_MIG_PWC.pr_fl_importaParametrizaciones(
    'GS',
    'KRT_MASIVO',
    NULL,
    ['PARAM_KRT_ENERGIA_CANALES',
     'PARAM_KRT_ENERGIA_MARCO',
     'PARAM_KRT_ENERGIA_RAPPELxPCT_IMPORTE',
     'PARAM_KRT_ENERGIA_RAPPELxPCT_OBJETIVOS',
     'PARAM_KRT_ENERGIA_RAPPELxTRAMOS_IMPORTE',
     'PARAM_KRT_ENERGIA_RAPPELxTRAMOS_NIVEL_ALCANZADO',
     'PARAM_KRT_ENERGIA_REPARTO']
  );

  CALL `mm-commissions-reporting.COMISIONES.pr_energy_luz_nortev1`(desde_mes);
  CALL `mm-commissions-reporting.COMISIONES.pr_energy_gas_norte`(desde_mes, NULL);
  CALL `mm-commissions-reporting.COMISIONES.pr_energy_sve_norte`(desde_mes, NULL);
  CALL `mm-commissions-reporting.COMISIONES.pr_energy_svg_norte`(desde_mes, NULL);

  -- IMPORTANTE REVISAR PARAMETRIZACIONES Y MIGRAR DE GS A KRT_MASIVO

  CALL `mm-commissions-reporting.KRT_MIG_PWC.subproc_energia_0100_creaUnificaComisionesEnergia`();

  -- DE MOMENTO SOLO SE PUEDE APLICAR MARCO TLV OUTBOUND CARTERA PENDIENTE DESARROLLO DEL RESTO
  CALL `mm-commissions-reporting.COMISIONES.pr_energy_rappel_objetivos_norte`(desde_mes, 'TLV OUTBOUND CARTERA');

  CALL `mm-commissions-reporting.COMISIONES.pr_energy_clawback_norte`(desde_mes);

  CALL `mm-commissions-reporting.KRT_MIG_PWC.subproc_energia_0110_canalizaEnCtxComisionesDeEnergia`(desde);
  CALL `mm-commissions-reporting.KRT_MIG_PWC.subproc_energia_0120_canalizaEnCtxDecomisionesDeEnergia`(desde);

END