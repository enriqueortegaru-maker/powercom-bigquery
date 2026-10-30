BEGIN

--CALL `mm-commissions-reporting.B2B.pr_campanas_B2B`('2025-06-01','2025-06-30');

CALL `mm-commissions-reporting.B2B.pr_campanas_B2B_preparar_datos`(mes_inicio, mes_fin); --Ultima llamada `mm-commissions-reporting.TEMP.B2B_ventas`

CALL `mm-commissions-reporting.B2B.pr_campanas_B2B_calculo`(mes_inicio, mes_fin); --Ultima llamada `mm-commissions-reporting.TEMP.B2B_transacciones_campana`

END