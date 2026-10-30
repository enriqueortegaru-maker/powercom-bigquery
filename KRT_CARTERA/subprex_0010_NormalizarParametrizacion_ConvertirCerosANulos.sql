BEGIN
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET multiplicador_upg=NULL WHERE multiplicador_upg=0;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET nivel_ups=NULL WHERE nivel_ups=0;
END