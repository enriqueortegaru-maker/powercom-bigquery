BEGIN
    -- DECLARE VDESDE INT64; SET VDESDE=20260901;
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.AUDIT_OS_SAP_FACTURA_APUNTES_VS_TRANSACCIONES` AS 
    -- DECLARE VDESDE INT64; SET VDESDE=20260901;
    with diff as (
      -- DECLARE VDESDE INT64; SET VDESDE=20260901;
      SELECT * from `mm-commissions-reporting.KRT_SAP.f_vt_audit_transacciones_no_apuntes_sap_cruce_codigo_sap`(VDESDE)
    ) , os as (
      select distinct sociedad, marca, orden, clase as clase_orden, cuenta, detalle,  canal, subcanal, controller, tipo, service_type, operacion, estado
      from `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
      WHERE COALESCE(ORDEN,0)>0
      group by all
      order by 1,2,3
    )
    select distinct diff.*,  os.DETALLE, OS.ESTADO, os.CONTROLLER, os.SERVICE_TYPE, os.CANAL, os.SUBCANAL, os.OPERACION, os.clase_orden, os.cuenta, 
    from diff
    left join  os
    on os.SOCIEDAD=diff.SOCIEDAD
    and os.MARCA=diff.MARCA
    and os.ORDEN=diff.ORDEN_sap
    AND os.tipo=diff.tipo;

END