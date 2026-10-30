BEGIN

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET multiplicador_upg=NULL WHERE multiplicador_upg=0;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET nivel_ups=NULL WHERE nivel_ups=0;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET nivel_ups=NULL WHERE nivel_ups=0;    
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET campana_id=NULL where length(campana_id) <=1;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET nombre_campana=NULL where length(nombre_campana) <=1;    
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET nombre_campana=NULL where length(nombre_campana) <=1;    

    ---TRIM
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  UPDATE SET Sistema=UPPER(TRIM(Sistema)) where TRUE;      
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  UPDATE SET marca_ds=UPPER(TRIM(marca_ds)) where TRUE;          
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  UPDATE SET IdProdCat=UPPER(TRIM(IdProdCat)) where TRUE;      
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`  UPDATE SET tipo_movimiento=TRIM(tipo_movimiento) where TRUE;      

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO`  UPDATE SET marca_ds=UPPER(TRIM(marca_ds)) WHERE TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO`  UPDATE SET marco_retributivo_ds=TRIM(marco_retributivo_ds) WHERE TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO`  UPDATE SET concepto_ds=TRIM(concepto_ds) WHERE TRUE;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_NIVELCONSEGUIDO_TIPOMOVIMIENTO`  UPDATE SET marco_retributivo=TRIM(marco_retributivo) where TRUE;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET marca_ds=UPPER(TRIM(marca_ds)) where TRUE;      
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET canal=UPPER(TRIM(canal)) where TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET subcanal=UPPER(TRIM(subcanal)) where TRUE;              
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET nombre_distribuidor=UPPER(TRIM(nombre_distribuidor)) where TRUE;          
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET equipo=UPPER(TRIM(equipo)) where TRUE; 
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET agente=TRIM(agente) where TRUE; 

--    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET agrupador_mr=UPPER(TRIM(agrupador_mr)) where TRUE; 
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES`  UPDATE SET agrupador_mr=TRIM(agrupador_mr) where TRUE; 

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_TRAMOS_RAPPEL_OBJETIVOS`  UPDATE SET MR=(TRIM(MR)) where TRUE;      

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_BONUS_CALIDAD_COMERCIAL`  UPDATE SET nombre_distribuidor=UPPER(TRIM(nombre_distribuidor)) WHERE TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_BONUS_CALIDAD_COMERCIAL`  UPDATE SET marco_retributivo=TRIM(marco_retributivo) WHERE TRUE;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_RETRASOS`  UPDATE SET marca_ds=UPPER(TRIM(marca_ds)) WHERE TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_RETRASOS`  UPDATE SET nombre_distribuidor=UPPER(TRIM(nombre_distribuidor)) WHERE TRUE;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS`  UPDATE SET marca_ds=UPPER(TRIM(marca_ds)) where TRUE;      
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS`  UPDATE SET canal=UPPER(TRIM(canal)) where TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS`  UPDATE SET subcanal=UPPER(TRIM(subcanal)) where TRUE;              
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS`  UPDATE SET nombre_distribuidor=UPPER(TRIM(nombre_distribuidor)) where TRUE;          
--    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS`  UPDATE SET marco_retributivo=UPPER(TRIM(marco_retributivo)) where TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS`  UPDATE SET marco_retributivo=TRIM(marco_retributivo) where TRUE;

    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_MR_TVT_UPS`  UPDATE SET marco_retributivo=TRIM(marco_retributivo) where TRUE;


    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET nombre_campana=UPPER(TRIM(nombre_campana)) where TRUE;  
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`  UPDATE SET nombre_distribuidor=UPPER(TRIM(nombre_distribuidor)) where TRUE;      


    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMBIO_IMPORTE_FIJO`  UPDATE SET marca_ds=UPPER(TRIM(marca_ds)) where TRUE;      
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMBIO_IMPORTE_FIJO`  UPDATE SET canal=UPPER(TRIM(canal)) where TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMBIO_IMPORTE_FIJO`  UPDATE SET subcanal=UPPER(TRIM(subcanal)) where TRUE;              
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMBIO_IMPORTE_FIJO`  UPDATE SET nombre_distribuidor=UPPER(TRIM(nombre_distribuidor)) where TRUE;          
--    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMBIO_IMPORTE_FIJO`  UPDATE SET marco_retributivo=UPPER(TRIM(marco_retributivo)) where TRUE;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMBIO_IMPORTE_FIJO`  UPDATE SET marco_retributivo=TRIM(marco_retributivo) where TRUE;


END