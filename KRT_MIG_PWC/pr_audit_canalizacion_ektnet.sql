BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.AUDIT_CANALIZACION_EKTNET` AS
  SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.f_vt_audit_canalizacion_ektnet`();

END