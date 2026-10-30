begin

-- call `mm-commissions-reporting.EXCLUSIVO.pr_comisiones_working_ifs`(date_trunc(date_add (current_date (), interval -1 month), month));


call `mm-commissions-reporting.IFS.pr_comisiones_working_ifs` (
  ['7233','7234', '7190','7209','7222','7227','7228','7229','7232'],
  --['BY','ML','CI'],
  ['DB'], 
  ['Confirmed','Reported'],
  'EXCLUSIVO.comisiones_working_ifs',
  mes_pr
  );

/*
delete  `mm-commissions-reporting.EXCLUSIVO.comisiones_working_ifs` 
where campaign_code in ('ML-7233','CI-7233')
;
*/



create or replace table `mm-commissions-reporting.EXCLUSIVO.comisiones_contabiliza_ifs` 
as
select *
from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_ifs`
where SPLIT(process_code, '-')[offset(0)] in ('INIT_TOUP', 'FINANCE', 'SUBSIDY','MARKETING','DOA','SIM_COST')
;

delete  `mm-commissions-reporting.EXCLUSIVO.comisiones_working_ifs` 
where SPLIT(process_code, '-')[offset(0)] in ('INIT_TOUP', 'FINANCE', 'SUBSIDY','MARKETING','DOA','SIM_COST')
;


/*
select distinct tipo_concepto, process_code,SPLIT(process_code, '-')[offset(0)] 
from `mm-commissions-reporting.EXCLUSIVO.comisiones_working_ifs` 
where length ( tipo_concepto ) > 4
;
*/
  
call `mm-commissions-reporting.CONTROL.pr_insert_comisiones_working`
(
  'IFS',
  'EXCLUSIVO.comisiones_working_ifs',
  'EXCLUSIVO.comisiones_working'
);

end