begin

-- call `mm-commissions-reporting.D2D.pr_comisiones_working_ifs` (date_trunc(date_add (current_date (), interval -1 month), month)) ;

call `mm-commissions-reporting.IFS.pr_comisiones_working_ifs` (
  ['7190','7209','7222','7227','7228','7229','7232'],
  ['DB','DD'], 
  'D2D.comisiones_working_ifs',
  mes_pr
  );
  
create or replace table `mm-commissions-reporting.D2D.comisiones_contabiliza_ifs` 
as
select *
from `mm-commissions-reporting.D2D.comisiones_working_ifs`
where SPLIT(process_code, '-')[offset(0)] in ('INIT_TOUP', 'FINANCE', 'SUBSIDY','MARKETING','DOA','SIM_COST')
;

delete  `mm-commissions-reporting.D2D.comisiones_working_ifs` 
where SPLIT(process_code, '-')[offset(0)] in ('INIT_TOUP', 'FINANCE', 'SUBSIDY','MARKETING','DOA','SIM_COST')
;


call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  'IFS',
  'D2D.comisiones_working_ifs',
  'D2D.comisiones_working'
);

end