begin

delete `mm-commissions-reporting.SAP.sap_comisiones`
where num_documento in (select distinct num_documento from `mm-commissions-reporting.SANDBOX.sap_temp`)
;

insert into `mm-commissions-reporting.SAP.sap_comisiones` 
select * except (vacio, valor_moneda),
parse_numeric(replace(replace(valor_moneda,'.',''),',','.')) as valor_moneda
FROM `mm-commissions-reporting.SANDBOX.sap_temp`
;

end