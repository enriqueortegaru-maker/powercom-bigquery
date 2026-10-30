BEGIN

    -- PASO 1: Inserto registros en tabla EVENTOS_CARTERA
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
      agente_creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento
    FROM
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`;




END