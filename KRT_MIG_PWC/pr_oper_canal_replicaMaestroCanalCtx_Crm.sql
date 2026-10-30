BEGIN
  CALL `mm-commissions-reporting.KRT_MIG_PWC.pr_oper_canal_replicaMaestroCanalCtx_ektnet`();
  CALL `mm-commissions-reporting.KRT_MIG_PWC.pr_oper_canal_replicaMaestroCanalCtx_tcnet`();
  CALL `mm-commissions-reporting.KRT_MIG_PWC.pr_oper_canal_replicaMaestroCanalCtx_siebel`();
END