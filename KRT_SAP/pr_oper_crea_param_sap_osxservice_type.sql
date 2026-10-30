BEGIN

-- 1. Store CURRENT_DATE() in a variable to guarantee consistency 
  --    just in case the procedure runs exactly at midnight.
  DECLARE v_today DATE DEFAULT CURRENT_DATE();

  -- 2. Recreate the parameter table
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxSERVICE_TYPE` AS
  SELECT * FROM `mm-commissions-reporting.KRT_SAP.f_vt_param_sap_osxservice_type`();

  -- 3. Idempotency Check: Only run the INSERT if today's date doesn't exist in the target table
  IF NOT EXISTS (
    SELECT 1 
    FROM `mm-commissions-reporting.KRT_SAP.AGG_PARAM_SAP_OSxSERVICE_TYPE` 
    WHERE fecha_calc_dt = v_today
    LIMIT 1
  ) THEN
  
    INSERT INTO `mm-commissions-reporting.KRT_SAP.AGG_PARAM_SAP_OSxSERVICE_TYPE` 
    SELECT DISTINCT 
      v_today AS fecha_calc_dt,
      *
    FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxSERVICE_TYPE`;
    
  END IF;

END