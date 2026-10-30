BEGIN


  DECLARE vnDia INT64; 
  SET vnDia=CAST(FORMAT_DATE("%d",CURRENT_DATE()) as integer);  

  IF vNDia<10 THEN 
    CALL `mm-commissions-reporting.KRT_CARTERA.pr_audit_equiposFidelizacionMesConcreto`(1);
  ELSE
    CALL `mm-commissions-reporting.KRT_CARTERA.pr_audit_equiposFidelizacionMesConcreto`(0);
  END IF;

END