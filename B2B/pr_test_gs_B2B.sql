BEGIN

--CALL `mm-commissions-reporting.B2B.pr_test_gs_B2B`();


SELECT * FROM `mm-commissions-reporting.TEMP.gs_global_campana_B2B` LIMIT 100;

SELECT * FROM `mm-commissions-reporting.TEMP.gs_global_subcampana_B2B` LIMIT 100;

SELECT * FROM `mm-commissions-reporting.TEMP.gs_global_rangos_B2B` LIMIT 100;

SELECT * FROM `mm-commissions-reporting.TEMP.gs_global_subc_operador_B2B` LIMIT 100;

SELECT * FROM `mm-commissions-reporting.B2B.gs_global_provision_B2B` LIMIT 100;

END