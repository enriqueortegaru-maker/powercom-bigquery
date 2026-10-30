begin

-- call COMISIONES.pr_rollback_confirmar_agrupacion_canal (202301 , 'MCOM 0223.4');

update `mm-commissions-reporting.COMISIONES.transacciones` a
set modificado = current_timestamp(),
    proceso_sap = null,
    estado = 'validado',
    id_registro = null
where id_mes = mes_pr
and estado = 'confirmado'
and proceso_sap = proceso_sap_pr ;

end