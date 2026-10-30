BEGIN 

  --- PASO 0: ACTUALIZO TABLA BASE REPORTING COMISIONES
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_REPORTING.T_REPORTING_COMISIONES_DES` as 
  select * from `mm-commissions-reporting.KRT_REPORTING.reporting_comisiones_des`;

END