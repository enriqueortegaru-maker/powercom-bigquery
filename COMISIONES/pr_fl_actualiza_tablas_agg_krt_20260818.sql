BEGIN

    if tipo="TOTAL" or tipo="VENTAS" then 
        delete from `mm-commissions-reporting.COMISIONES.AGG_VENTAS_COMISIONES_KRT` where fecha_calc_dt=CURRENT_DATE() and id_mes_activacion=vmes_id ;
        insert into `mm-commissions-reporting.COMISIONES.AGG_VENTAS_COMISIONES_KRT`  from (select CURRENT_DATE(),* from `mm-commissions-reporting.COMISIONES.VENTAS_COMISIONES_KRT`);

        delete from `mm-commissions-reporting.COMISIONES.AGG_BAJAS_COMISIONES_KRT` where fecha_calc_dt=CURRENT_DATE() and id_mes_desactivacion=vmes_id;
        insert into `mm-commissions-reporting.COMISIONES.AGG_BAJAS_COMISIONES_KRT`  from (select CURRENT_DATE(),* from `mm-commissions-reporting.COMISIONES.BAJAS_COMISIONES_KRT`);

    elseif tipo="TOTAL" or tipo="DEVICES" then 
        delete from `mm-commissions-reporting.COMISIONES.AGG_DEVICE_BASE_KRT` where fecha_calc_dt=CURRENT_DATE() and id_mes_activacion=vmes_id ;
        insert into `mm-commissions-reporting.COMISIONES.AGG_DEVICE_BASE_KRT`  from (select CURRENT_DATE(),* from `mm-commissions-reporting.TEMP.DEVICE_BASE_KRT`);

    elseif tipo="TOTAL" or tipo="ACTIVACIONES" then 
        delete from `mm-commissions-reporting.COMISIONES.AGG_ACTIVACIONES_KRT` where fecha_calc_dt=CURRENT_DATE() and id_mes=vmes_id ;
        insert into `mm-commissions-reporting.COMISIONES.AGG_ACTIVACIONES_KRT`  from (select CURRENT_DATE(),* from `mm-commissions-reporting.COMISIONES.ACTIVACIONES_KRT`);

    elseif tipo="TOTAL" or tipo="DESACTIVACIONES" then 
        delete from `mm-commissions-reporting.COMISIONES.AGG_DESACTIVACIONES_KRT` where fecha_calc_dt=CURRENT_DATE() and id_mes=vmes_id ;
        insert into `mm-commissions-reporting.COMISIONES.AGG_DESACTIVACIONES_KRT`  from (select CURRENT_DATE(),* from `mm-commissions-reporting.COMISIONES.DESACTIVACIONES_KRT`);


    end if;

END