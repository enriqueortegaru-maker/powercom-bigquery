BEGIN

  CALL `mm-commissions-reporting.KRT_SAP.subproc_crea_PARAM_SAP_ZAGRUPACION`();
  CALL `mm-commissions-reporting.KRT_SAP.subproc_crea_PARAM_SAP_ZDESCAGRUP`();
  CALL `mm-commissions-reporting.KRT_SAP.subproc_crea_PARAM_SAP_ZDESCSUBAGRUPACION`();
  
END