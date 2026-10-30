BEGIN

  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET marca_ds=TRIM(marca_ds) where marca_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET IdCatalogo=TRIM(IdCatalogo) where IdCatalogo is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET NombreProducto=TRIM(NombreProducto) where NombreProducto is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET nombre_distribuidor=TRIM(nombre_distribuidor) where nombre_distribuidor is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET Canal=TRIM(Canal) where Canal is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET subcanal=TRIM(subcanal) where subcanal is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET agente=TRIM(agente) where agente is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET DNI_CIF=TRIM(DNI_CIF) where DNI_CIF is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET Marca_Cartera=TRIM(Marca_Cartera) where Marca_Cartera is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET Segmento=TRIM(Segmento) where Segmento is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET Subsegmento=TRIM(Subsegmento) where Subsegmento is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET idCatalogoOrigen=TRIM(idCatalogoOrigen) where idCatalogoOrigen is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET NombreProductoOrigen=TRIM(NombreProductoOrigen) where NombreProductoOrigen is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET TipoMovimiento=TRIM(TipoMovimiento) where TipoMovimiento is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET UsuarioCreador=TRIM(UsuarioCreador) where UsuarioCreador is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET concepto_ds=TRIM(concepto_ds) where concepto_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET concepto_origen_ds=TRIM(concepto_origen_ds) where concepto_origen_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` SET TipoProducto=TRIM(TipoProducto) where TipoProducto is not null;

END