begin

-- call `mm-commissions-reporting.SANDBOX.pr_refresh_mcom`()

call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_mcom`(date_trunc(date_add (current_date (), interval -1 month), month));

call `mm-commissions-reporting.TELEVENTA.pr_comisiones_working_mcom`(date_trunc(date_add (current_date (), interval -1 month), month));

call `mm-commissions-reporting.SANDBOX.pr_check_servicio_base`(date_trunc(date_add (current_date (), interval -1 month), month));

--call `mm-commissions-reporting.SANDBOX.pr_check_television`();

end