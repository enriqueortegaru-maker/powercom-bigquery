begin

-- call `mm-commissions-reporting.NO_EXCLUSIVO.pr_comisiones_working_ifs` (date_trunc(date_add (current_date (), interval -1 month), month)) ;

call `mm-commissions-reporting.IFS.pr_comisiones_working_ifs` (
  ['7233','7234'],
  ['MM','MP'], --
  ['Confirmed','Rejected', 'Reported'],
  'NO_EXCLUSIVO.comisiones_working_ifs',
  date_trunc(date_add (current_date (), interval -1 month), month)
  );
  
delete  `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ifs` 
where 
(
  descripcion_concepto not in ('B - Comision Q25','B - Reparacion Terminal (Anovo)','C - Calidad Cartera')
  and
  SPLIT(campaign_code, '-')[offset(0)] != 'PH'
)
;

create or replace table `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_contabiliza_ifs` 
as
select *
from `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ifs`
where SPLIT(process_code, '-')[offset(0)] in ('INIT_TOUP', 'FINANCE', 'SUBSIDY','MARKETING','DOA','SIM_COST')
;

delete  `mm-commissions-reporting.NO_EXCLUSIVO.comisiones_working_ifs` 
where SPLIT(process_code, '-')[offset(0)] in ('INIT_TOUP', 'FINANCE', 'SUBSIDY','MARKETING','DOA','SIM_COST')
;


call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  'IFS',
  'NO_EXCLUSIVO.comisiones_working_ifs',
  'NO_EXCLUSIVO.comisiones_working'
);

end