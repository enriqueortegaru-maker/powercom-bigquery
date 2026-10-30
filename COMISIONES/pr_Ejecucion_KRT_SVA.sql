begin 
--call COMISIONES.pr_Ejecucion_KRT_SVA (202409);

call COMISIONES.pr_ENERGY_LUZ_norte (id_mes_pr, null);

call COMISIONES.pr_ENERGY_GAS_norte (id_mes_pr, null);

call COMISIONES.pr_ENERGY_sve_norte (id_mes_pr, null);

call COMISIONES.pr_ENERGY_svg_norte (id_mes_pr, null);

delete `mm-commissions-reporting.COMISIONES.historico_sva_krt` where id_mes= id_mes_pr and substring(commission_id,1,10) in ('NENRG_RNEN','NENRG_BNEN');
insert into `mm-commissions-reporting.COMISIONES.historico_sva_krt` select * from  `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte` ;

delete `mm-commissions-reporting.COMISIONES.historico_sva_krt` where id_mes= id_mes_pr and substring(commission_id,1,11) = ('NENRG_BNGAS');
insert into `mm-commissions-reporting.COMISIONES.historico_sva_krt` select * from  `mm-commissions-reporting.TEMP.ENERGY_GAS_norte` ;

delete `mm-commissions-reporting.COMISIONES.historico_sva_krt` where id_mes= id_mes_pr and substring(commission_id,1,11) = ('NENRG_Bnsve');
insert into `mm-commissions-reporting.COMISIONES.historico_sva_krt` select * from  `mm-commissions-reporting.TEMP.ENERGY_sve_norte` ;

delete `mm-commissions-reporting.COMISIONES.historico_sva_krt` where id_mes= id_mes_pr and substring(commission_id,1,11) = ('NENRG_Bnsvg');
insert into `mm-commissions-reporting.COMISIONES.historico_sva_krt` select * from  `mm-commissions-reporting.TEMP.ENERGY_svg_norte` ;

call`COMISIONES.clawback_sva_norte`(id_mes_pr);

delete `mm-commissions-reporting.COMISIONES.historico_sva_krt` where id_mes= id_mes_pr and substring(commission_id,1,8) = 'CLAWBN_C';
insert into `mm-commissions-reporting.COMISIONES.historico_sva_krt` select * from  `mm-commissions-reporting.TEMP.CLAWB_SVA_NORTE`  ;


end