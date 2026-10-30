begin

CALL `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_segr`(date_trunc(date_add (current_date (), interval -1 month), month));
CALL `mm-commissions-reporting.TELEVENTA.pr_comisiones_working_segr`(date_trunc(date_add (current_date (), interval -1 month), month));
CALL `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_segr`(date_trunc(date_add (current_date (), interval -1 month), month));
CALL `mm-commissions-reporting.D2D.pr_comisiones_working_segr`(date_trunc(date_add (current_date (), interval -1 month), month));


end