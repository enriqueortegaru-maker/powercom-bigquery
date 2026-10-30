BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_norte_canalizacion_ct_mm` AS 
  with p as (
    select * from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_ektnet_canalizacion_ct_mm`
    union all 
    select * from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_tcnet_canalizacion_ct_mm`  
    union all 
    select * from `mm-commissions-reporting.KRT_MIG_PWC.tr_crm_siebel_canalizacion_ct_mm`
  ) select *
  from p 
  order by 1 asc,2 asc ,4 asc,6 asc ,8 asc;

END