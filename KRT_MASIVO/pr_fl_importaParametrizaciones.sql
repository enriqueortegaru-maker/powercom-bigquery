BEGIN
  CALL `mm-commissions-reporting`.KRT_MIG_PWC.pr_fl_importaParametrizaciones(
    'GS', 'KRT_MASIVO', 'PARAM_KRT_MAS', NULL
  );
END