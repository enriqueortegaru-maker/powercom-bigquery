BEGIN

    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_TERMINALES` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_MARCO` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_DESCUENTOS` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_USUARIOS` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_VALOR` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_POSTVENTA` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RETRASOS` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO` where 1=1;
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_MULTIPLICADOR` where 1=1;


    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_OBJETIVOS` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.OBJETIVOS`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.CANALES`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_P` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.NIVELES_PRESENCIAL`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVELES_OBJETIVOS_NP` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.NIVELES_NO_PRESENCIAL`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANALES` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_TERMINALES` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.TERMINALES`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_MARCO` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MARCO`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_DESCUENTOS` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.CANCELACIONES_DESCUENTOS`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANCELACIONES_USUARIOS` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.CANCELACIONES_USUARIOS`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_VALOR` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VALOR`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_POSTVENTA` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.POSTVENTA`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_RETRASOS` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RETRASOS`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_EXTRAS` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.EXTRAS`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_NIVEL_RAPPEL_ASIGNADO` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_ASIGNADO`;
    INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.PARAM_MULTIPLICADOR` SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.MULTIPLICADOR`;

END