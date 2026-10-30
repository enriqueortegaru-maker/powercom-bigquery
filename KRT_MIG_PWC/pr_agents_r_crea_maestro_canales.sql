BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.AGENTS_R_MAESTRO_CANALES` AS
  SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.f_vt_agents_r_registro_relaciones_agente_login_siebel`();

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.AGENTS_R_TRADUCTOR_CANALES_CTX_KD` AS
  SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.f_vt_agents_r_traductor_ctx_kd`();



END