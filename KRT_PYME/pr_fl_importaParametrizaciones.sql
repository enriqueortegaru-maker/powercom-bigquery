BEGIN
  CALL `mm-commissions-reporting`.KRT_MIG_PWC.pr_fl_importaParametrizaciones(
    'GS', 'KRT_PYME', 'PARAM_KRT_PYME', NULL
  );
END