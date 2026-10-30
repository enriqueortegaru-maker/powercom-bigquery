begin

-- call `mm-commissions-reporting.IFS.pr_campos_rebate_transaction` ();

declare creation_time_dwh, creation_time_comisiones timestamp;

set creation_time_dwh = (select max(creation_time) as creation_time_dwh
from `mm-dwh-prod.00_SANDBOX_IFS.INFORMATION_SCHEMA.TABLES` 
where table_name like 'IFSAPP_REBATE_TRANSACTION%');

set creation_time_comisiones = (select max(creation_time) as creation_time_comisiones
from `mm-commissions-reporting.IFS.INFORMATION_SCHEMA.TABLES` 
where table_name = 'campos_rebate_transaction');

if creation_time_dwh > creation_time_comisiones then

create or replace table  `mm-commissions-reporting.IFS.campos_rebate_transaction` as

with ifs as
(
select transaction_id
       ,yoi_activation_date_fixed
       ,yoi_deactivation_date_fixed
       ,contract_type_group
       ,yoi_cus_kategory as CUS_KATEGORY 
       ,row_number () over (partition by transaction_id order by _table_suffix desc) as rn
from `mm-dwh-prod.00_SANDBOX_IFS.IFSAPP_REBATE_TRANSACTION*`
)
select * except (rn)
from ifs
where rn = 1;

end if;

end