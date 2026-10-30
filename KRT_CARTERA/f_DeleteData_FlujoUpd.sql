BEGIN

      DELETE FROM `mm-commissions-reporting.KRT_CARTERA.FLUJO_UPD_TABLAS_PRINCIPALES` where fecha_calc_dt=CURRENT_DATE() and nombre=vnombre and desde = vdesde and hasta=vhasta and version=vversion;

END