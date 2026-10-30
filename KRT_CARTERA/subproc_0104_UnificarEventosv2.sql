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
      agente_Creador_id,
      concepto_ds,
      concepto_origen_ds,
      medio_conocimiento
    FROM
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA_EKTNET`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0104_EVENTOS_CARTERA` AS
    SELECT *
    FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0104_EVENTOS_CARTERA_INCR` AS
    SELECT *
    FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` f4
    WHERE NOT EXISTS(
      SELECT 1 
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0103_EVENTOS_CARTERA_EKTNET` f3
      WHERE f3.mmMarcaDesc=f4.marca_ds
      and f3.cliente_id=f4.idfijo
      and f3.productoId=f4.Idproducto
      and f3.TipoMovimiento=f4.TipoMovimiento
    );




END