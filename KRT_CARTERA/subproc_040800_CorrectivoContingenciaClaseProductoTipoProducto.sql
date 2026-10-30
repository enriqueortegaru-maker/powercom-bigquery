BEGIN

	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
	SET TIPOPRODUCTO="TERMINALES"
	WHERE contains_substr(clase_mm,"Terminal") and not contains_substr(TipoProducto,"Terminal");

	UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
	SET TIPOPRODUCTO="DISPOSITIVOS"
	WHERE contains_substr(clase_mm,"Dispositivo") and not contains_substr(TipoProducto,"Dispositivo");

END