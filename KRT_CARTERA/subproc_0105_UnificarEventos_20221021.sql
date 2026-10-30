BEGIN

    INSERT INTO
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`
    SELECT
      mmMarcaDesc,
      CatalogoId,
      NombreProducto,
      nombre_distribuidor,
      Canal,
      subcanal,
      agente,
      cliente_id,
      Antiguedad,
      swNIE,
      MarcaCartera,
      Fecha_Activacion,
      Fecha_Creacion,
      swSegmento,
      Subsegmento,
      CatalogoIdOrigen,
      ProductoIdOrigen,
      NombreProductoOrigen,
      TipoMovimiento,
      ProductoId,
      Contrato,
      UsuarioCreador,
      concepto_ds,
      concepto_origen_ds
    FROM
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`;

END