BEGIN
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.AUDIT_CANALIZACION_EQUIPO_FIDELIZACION` AS 
      SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.f_vt_canalizacion_audit_funcion_agente_equipo_fidelizacion`(vdesde);

END