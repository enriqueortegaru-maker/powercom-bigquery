BEGIN

declare id_mes int64;

set id_mes = cast(format_date('%Y%m',date_trunc(date_add (current_date (), interval -0 month), month ) ) as int64 );

-- call `mm-commissions-reporting.COMISIONES.ejecucion_diaria`();

  call `mm-commissions-reporting.COMISIONES.pr_facturar_sap`();


  call  `mm-commissions-reporting.COMISIONES.pr_activaciones` (id_mes);


  call  `mm-commissions-reporting.COMISIONES.pr_acti` (id_mes,null);


  call `mm-commissions-reporting.COMISIONES.pr_check_ventas_base`(true);

  call  `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio` ('completo');

  call  `mm-commissions-reporting.COMISIONES.pr_prov`(null);


END