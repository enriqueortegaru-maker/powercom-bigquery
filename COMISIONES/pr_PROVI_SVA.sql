BEGIN
--CALL `mm-commissions-reporting.COMISIONES.pr_PROVI_SVA` (202409, null,null);




call COMISIONES.pr_ENERGY_GAS (id_mes_pr, null);

call COMISIONES.pr_ENERGY_LUZ (id_mes_pr, null);


call COMISIONES.pr_ENERGY_SVE (id_mes_pr, null);


call COMISIONES.pr_ENERGY_SVG (id_mes_pr, null);


create or replace table  `mm-commissions-reporting.TEMP.PROVISION_SVA` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 25 DAY)) AS  (
select * from TEMP.ENERGY_GAS
)
;
insert into TEMP.PROVISION_SVA select * from TEMP.ENERGY_LUZ;
insert into TEMP.PROVISION_SVA select * from TEMP.ENERGY_SVE;
insert into TEMP.PROVISION_SVA select * from TEMP.ENERGY_SVG;



select * from `mm-commissions-reporting.TEMP.PROVISION_SVA` ;
end