BEGIN
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO`  UPDATE SET nivel_alcanzado_id=NULL WHERE nivel_alcanzado_id=0;
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS`  UPDATE SET objetivo=NULL WHERE objetivo=0;
END