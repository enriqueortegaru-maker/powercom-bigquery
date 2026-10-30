BEGIN

  -- VALOR PARÁMETRO VTIPO
  --   "TOTAL"    : Actualización Captación + Cartera
  --   "CAPTACION": Actualización Captación
  --   "CARTERA"  : Actualización Cartera
  --CALL `mm-commissions-reporting.KRT_SAP.subproc_0110_ActualizarTablaTransaccionesv3_opt`(20261001, "TOTAL");

  DECLARE VHASTA, VMES_ID, VHOY_ID INT64;
  DECLARE VMES_FACTURA_DT DATE;

  SET VMES_FACTURA_DT = PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING));
  SET VHASTA          = CAST(FORMAT_DATE('%Y%m%d', LAST_DAY(VMES_FACTURA_DT)) AS INT64);
  SET VMES_ID         = CAST(FORMAT_DATE('%Y%m',   VMES_FACTURA_DT) AS INT64);
  SET VHOY_ID         = CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE('Europe/Madrid')) AS INT64);

  IF CONTAINS_SUBSTR(VTIPO, 'Total')
  OR CONTAINS_SUBSTR(VTIPO, 'Captacion')
  OR CONTAINS_SUBSTR(VTIPO, 'Cartera') THEN


    --- PASO 1: CREO TABLA INTERMEDIA

    IF CONTAINS_SUBSTR(VTIPO, 'Total') THEN
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` AS
      SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` WHERE 1=0;

    ELSEIF CONTAINS_SUBSTR(VTIPO, 'Captacion') THEN
      --- Preserva sección CARTERA (no procesada) para subproc_0115
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` AS
      SELECT *
      FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
      WHERE mes_factura_dt = VMES_FACTURA_DT
        AND tipo           = 'CARTERA'
        AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
        AND NOT CONTAINS_SUBSTR(data_source_ds, 'MYSIM');

    ELSEIF CONTAINS_SUBSTR(VTIPO, 'Cartera') THEN
      --- Preserva sección CAPTACION (no procesada) para subproc_0115
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` AS
      SELECT *
      FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
      WHERE mes_factura_dt = VMES_FACTURA_DT
        AND tipo           = 'CAPTACION'
        AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
        AND NOT CONTAINS_SUBSTR(data_source_ds, 'MYSIM');

    END IF;


    --- PASO 2: INSERTO REGISTROS DE CAPTACION EN TABLA INTERMEDIA
    IF CONTAINS_SUBSTR(VTIPO, 'Total') OR CONTAINS_SUBSTR(VTIPO, 'Captacion') THEN


      --- PASO 2.1: INSERTO COMISIONES CAPTACION
      INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
      (
        mes_factura_dt,
        mes_liquidado,
        commission_id,
        id_registro,
        invoice_id,
        estado,
        marca,
        customer_id,
        service_id,
        concepto_ds_gekt,
        tariff_ds,
        tipo_concepto,       -- [1] NULL; resolved in PASO 4
        activation_date,
        sale_date,
        canal_gekt,
        subcanal,
        distribuidor,
        razon_social,
        seller,
        customer_dni,
        segmento,
        tariff_id,
        concepto,
        clase_concepto,      -- [2] generator output
        order_id,
        account_id,
        bundle_type,
        marco,
        orden,
        comision,
        id_mes,
        sfid_id,
        agrupacion_canal,
        canal,
        subcanal_gekt,
        nombre_comercio,
        service_type,
        technology_ds,
        order_type_agg,
        bp,
        id_comisionista,
        cif,
        cod_marca,
        cod_segmento,
        sociedad,
        deactivation_date,
        unidades,
        zona_fiscal,
        billing_type_ds,
        operation,
        distribuidor_gekt,
        categoria_servicio_ds,
        clase,
        tipo,
        concepto_factura_ds,
        data_source_ds
      )

      SELECT
        mes_factura_dt,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_rfb_dt),
        commission_id,
        id_registro,
        invoice_id,
        estado,
        marca_ds,
        CAST(Cliente_id AS STRING),
        CAST(servicio_id AS STRING),
        CAST(concepto_ds AS STRING),
        detalle_servicio_ds,
        CAST(NULL AS STRING),   -- [1] tipo_concepto = NULL
        EXTRACT(DATE FROM fecha_rfb_dt),
        EXTRACT(DATE FROM fecha_venta_neta_dt),
        canal_alta_ds,
        subcanal_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
        agente_alta_id,
        cif_nif,
        COALESCE(NULLIF(UPPER(TRIM(segmento_ds)), ''), 'RESIDENCIAL'),
        catalogo_id,
        desc_mm,
        -- [2] clase_concepto ← generator output (SAP description; Translator CONCEPTO match key)
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento_ds, desc_mm, categoria_servicio_ds, g.DETALLE
        ),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_order_id`(marca_ds, pedido),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_account_id`(marca_ds, CAST(contrato_id AS STRING)),
        cat_plays_p,
        marco_Retributivo_ds,
        orden_sap,
        importe,
        CAST(FORMAT_DATE('%Y%m', mes_factura_dt) AS INT64),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id_v1`(marca_ds, categoria_servicio_ds, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo_ds, canal_alta_ds, subcanal_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_canal`(marco_retributivo_ds, canal_alta_ds, subcanal_ds),
        subcanal_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comerciov2`(marca_ds, canal_alta_ds, equipo_ds, agente_Alta_id, categoria_servicio_ds, canalizacion.EquipoDesc, canalizacion.AgenteComercial),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_service_type`(categoria_servicio_ds, detalle_servicio_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_technology`(categoria_servicio_ds, tecnologia_detalle_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_order_type_agg`(portabilidad_in_lg),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_marca`(marca_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_segmento`(segmento_ds),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_deactivation_date`(),
        1,
        'PEN',
        'POSTPAID',
        'ALTA',
        nombre_distribuidor_alta_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_categoria_servicio`(categoria_servicio_ds, tecnologia_detalle_ds),
        'COMISION',
        'CAPTACION',
        -- concepto_factura_ds = generator output (unchanged — this is the SAP description)
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento_ds, desc_mm, '', ''
        ),
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, categoria_servicio_ds)

      FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_DETALLADO` c
      LEFT JOIN (
        -- [3] Fixed: ON UPPER(TRIM(g.tipo)) = "CAPTACION" (was = c.marca_ds — always false)
        -- [4] ESTADO priority in ORDER BY
        SELECT tipo, marca, orden, CANAL, DETALLE,
          ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden
            ORDER BY
              CASE ESTADO WHEN 'ACTIVO' THEN 1 WHEN 'PUBLICADA' THEN 2 ELSE 3 END,
              CANAL, DETALLE
          ) AS rn
        FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
        WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
      ) g
        ON  UPPER(TRIM(g.tipo))  = 'CAPTACION'   -- [3] FIXED
        AND UPPER(TRIM(g.MARCA)) = UPPER(TRIM(c.marca_ds))
        AND g.ORDEN              = c.orden_sap
        AND g.rn                 = 1

      WHERE mes_factura_dt = vmes_factura_dt
        AND version = (
          SELECT `mm-commissions-reporting.KRT_CAPTACION.f_obtenerVersionDeFlujoVigenteEnMes`(
            PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING))
          )
        );


      --- PASO 2.2: INSERTO DECOMISIONES CAPTACION
      INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
      (
        mes_factura_dt,
        mes_liquidado,
        commission_id,
        id_registro,
        invoice_id,
        estado,
        marca,
        customer_id,
        service_id,
        concepto_ds_gekt,
        tariff_ds,
        tipo_concepto,       -- [1] NULL; resolved in PASO 4
        activation_date,
        sale_date,
        canal,
        subcanal,
        canal_gekt,
        subcanal_gekt,
        distribuidor,
        razon_social,
        seller,
        customer_dni,
        segmento,
        marco,
        orden,
        comision,
        deactivation_date,
        causa_baja_agrup,
        causa_baja,
        id_mes,
        concepto,
        clase_concepto,      -- [2] generator output
        sfid_id,
        agrupacion_canal,
        nombre_comercio,
        service_type,
        bp,
        id_comisionista,
        cif,
        cod_marca,
        cod_segmento,
        sociedad,
        unidades,
        zona_fiscal,
        billing_type_ds,
        operation,
        distribuidor_gekt,
        categoria_servicio_ds,
        clase,
        tipo,
        concepto_factura_ds,
        data_source_ds
      )

      SELECT
        mes_factura_dt,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_baja_dt),
        commission_id,
        id_registro,
        invoice_id,
        estado,
        marca_ds,
        CAST(Cliente_id AS STRING),
        CAST(servicio_id AS STRING),
        CAST(concepto_ds AS STRING),
        detalle_servicio_ds,
        CAST(NULL AS STRING),   -- [1] tipo_concepto = NULL
        EXTRACT(DATE FROM fecha_rfb_dt),
        EXTRACT(DATE FROM fecha_venta_neta_dt),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_canal`(marco_retributivo_ds, canal_alta_ds, subcanal_ds),
        subcanal_ds,
        canal_alta_ds,
        subcanal_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
        agente_alta_id,
        cif_nif,
        COALESCE(NULLIF(UPPER(TRIM(segmento_ds)), ''), 'RESIDENCIAL'),
        marco_retributivo_ds,
        orden_sap,
        importe,
        EXTRACT(DATE FROM fecha_baja_dt),
        motivo_baja_agrup_ds,
        motivo_baja_ds,
        CAST(FORMAT_DATE('%Y%m', mes_factura_dt) AS INT64),
        desc_mm,
        -- [2] clase_concepto ← generator output
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento_ds, desc_mm, '', ''
        ),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id_v1`(marca_ds, categoria_servicio_ds, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo_ds, canal_alta_ds, subcanal_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comerciov2`(marca_ds, canal_alta_ds, equipo_ds, agente_Alta_id, categoria_servicio_ds, canalizacion.EquipoDesc, canalizacion.AgenteComercial),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_service_type`(categoria_servicio_ds, detalle_servicio_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_marca`(marca_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_segmento`(segmento_ds),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
        1,
        'PEN',
        'POSTPAID',
        'BAJA',
        nombre_distribuidor_alta_ds,
        categoria_servicio_ds,
        'DECOMISION',
        'CAPTACION',
        -- concepto_factura_ds = generator output (unchanged)
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento_ds, desc_mm, '', ''
        ),
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, categoria_servicio_ds)

      FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_DETALLADO`
      WHERE mes_factura_dt = vmes_factura_dt
        AND version = (
          SELECT `mm-commissions-reporting.KRT_CAPTACION.f_obtenerVersionDeFlujoVigenteEnMes`(
            PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING))
          )
        );

    END IF;


    --- PASO 3: INSERTO REGISTROS DE CARTERA EN TABLA INTERMEDIA
    IF CONTAINS_SUBSTR(VTIPO, 'Total') OR CONTAINS_SUBSTR(VTIPO, 'Cartera') THEN


      --- PASO 3.1: INSERTO COMISIONES CARTERA
      INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
      (
        mes_factura_dt,
        commission_id,
        id_registro,
        invoice_id,
        estado,
        mes_liquidado,
        id_mes,
        marca,
        order_id,
        account_id,
        tariff_id,
        tariff_ds,
        distribuidor,
        razon_social,
        canal_gekt,
        subcanal,
        seller,
        customer_id,
        customer_dni,
        activation_date,
        segmento,
        tariff_id_origin,
        service_id_origin,
        tariff_ds_origin,
        operation_type,
        service_id,
        concepto_ds_gekt,
        concepto_lista_ds_gekt,
        concepto_origen_ds_gekt,
        marco,
        campaign_code,
        orden,
        tipo_concepto,       -- [1] NULL; resolved in PASO 4
        comision,
        concepto,
        clase_concepto,      -- [2] generator output
        sfid_id,
        agrupacion_canal,
        canal,
        subcanal_gekt,
        nombre_comercio,
        service_type,
        order_type_agg,
        bp,
        id_comisionista,
        cif,
        cod_marca,
        cod_segmento,
        sociedad,
        deactivation_date,
        unidades,
        zona_fiscal,
        billing_type_ds,
        operation,
        distribuidor_gekt,
        categoria_servicio_ds,
        clase,
        tipo,
        concepto_factura_ds,
        data_source_ds
      )

      SELECT
        mes_factura_dt,
        commission_id,
        id_registro,
        invoice_id,
        estado,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_Activacion, desc_mm),
        CAST(FORMAT_DATE('%Y%m', `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fecha_Activacion, desc_mm)) AS INT64),
        marca_ds,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_id`(marca_ds, claseProducto, contrato),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_account_id`(marca_ds, claseProducto, contrato),
        IdCatalogo,
        NombreProducto,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
        c.Canal,
        subcanal,
        agente,
        CAST(IdFijo AS STRING),
        DNI_CIF,
        Fecha_Activacion,
        COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'),
        CAST(idCatalogoOrigen AS STRING),
        CAST(IdProductoOrigen AS STRING),
        NombreProductoOrigen,
        tipoMovimiento,
        CAST(IdProducto AS STRING),
        concepto_ds,
        concepto_lista,
        concepto_origen_ds,
        MARCO_RETRIBUTIVO,
        COALESCE(nombre_Campana, campana_id),
        orden_sap,
        CAST(NULL AS STRING),   -- [1] tipo_concepto = NULL
        importe,
        desc_mm,
        -- [2] clase_concepto ← generator output
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CARTERA',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(nombreProducto, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento, desc_mm, tipoMovimiento, g.DETALLE
        ),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id_v1`(marca_ds, tipoProducto, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo, c.canal, subcanal),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_canal`(marco_retributivo, c.canal, subcanal),
        subcanal,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comerciov2`(marca_ds, c.canal, agente, ClaseProducto, canalizacion.equipoDesc, canalizacion.agenteComercial),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_service_type`(TipoProducto),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_type_agg`(TipoMovimiento, ''),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_marca`(marca_ds),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_segmento`(segmento),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_deactivation_date`(),
        1,
        'PEN',
        'POSTPAID',
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_operacion`(TipoMovimiento),
        nombre_distribuidor,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_categoria_servicio`(ClaseProducto, TipoProducto),
        'COMISION',
        'CARTERA',
        -- concepto_factura_ds = generator output (unchanged)
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CARTERA',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(nombreProducto, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento, desc_mm, tipoMovimiento, ''
        ),
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, tipoProducto)

      FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO` c
      LEFT JOIN (
        -- [3] Fixed: ON UPPER(TRIM(g.tipo)) = "CARTERA" (was = c.marca_ds — always false)
        -- [4] ESTADO priority in ORDER BY
        SELECT tipo, marca, orden, CANAL, DETALLE,
          ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden
            ORDER BY
              CASE ESTADO WHEN 'ACTIVO' THEN 1 WHEN 'PUBLICADA' THEN 2 ELSE 3 END,
              CANAL, DETALLE
          ) AS rn
        FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
        WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
      ) g
        ON  UPPER(TRIM(g.tipo))  = 'CARTERA'   -- [3] FIXED
        AND UPPER(TRIM(g.MARCA)) = UPPER(TRIM(c.marca_ds))
        AND g.ORDEN              = c.orden_sap
        AND g.rn                 = 1

      WHERE mes_factura_dt = vmes_factura_dt
        AND version = (
          SELECT `mm-commissions-reporting.KRT_CARTERA.f_obtenerVersionDeFlujoVigenteEnMes`(
            PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING))
          )
        );


      --- PASO 3.2: INSERTO DECOMISIONES CARTERA
      INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO`
      (
        mes_factura_dt,
        mes_liquidado,
        id_mes,
        commission_id,
        id_registro,
        invoice_id,
        estado,
        marca,
        order_id,
        account_id,
        tariff_id,
        tariff_ds,
        distribuidor,
        razon_social,
        canal_gekt,
        subcanal,
        seller,
        customer_id,
        customer_dni,
        activation_date,
        segmento,
        tariff_id_origin,
        service_id_origin,
        tariff_ds_origin,
        operation_type,
        service_id,
        concepto_ds_gekt,
        concepto_origen_ds_gekt,
        marco,
        comision,
        campaign_code,
        causa_baja,
        causa_baja_agrup,
        concepto,
        clase_concepto,      -- [2] generator output (was clase_mm in canonical)
        tipo_concepto,       -- [1] NULL; resolved in PASO 4
        orden,
        sfid_id,
        agrupacion_canal,
        canal,
        subcanal_gekt,
        nombre_comercio,
        service_type,
        order_type_agg,
        bp,
        id_comisionista,
        cif,
        cod_marca,
        cod_segmento,
        sociedad,
        unidades,
        zona_fiscal,
        billing_type_ds,
        operation,
        distribuidor_gekt,
        categoria_servicio_ds,
        clase,
        tipo,
        data_source_ds
      )

      SELECT
        mes_factura_dt,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fechaDesinstalacion, desc_mm),
        CAST(FORMAT_DATE('%Y%m', `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(mes_factura_dt, fechaDesinstalacion, desc_mm)) AS INT64),
        commission_id,
        id_registro,
        invoice_id,
        estado,
        marca_ds,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_id`(marca_ds, claseProducto, contrato),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_account_id`(marca_ds, claseProducto, contrato),
        IdCatalogo,
        NombreProducto,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor),
        d.Canal,
        subcanal,
        agente,
        CAST(IdFijo AS STRING),
        DNI_CIF,
        Fecha_Activacion,
        COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'),
        idCatalogoOrigen,
        CAST(IdProductoOrigen AS STRING),
        NombreProductoOrigen,
        TipoMovimiento,
        CAST(IdProducto AS STRING),
        concepto_ds,
        concepto_origen_ds,
        MARCO_RETRIBUTIVO,
        total,
        campana_id,
        CausaBaja,
        CausaBajaGeneral,
        desc_mm,
        -- [2] clase_concepto ← generator output
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CARTERA',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(nombreProducto, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento, desc_mm, tipoMovimiento, g.DETALLE
        ),
        CAST(NULL AS STRING),   -- [1] tipo_concepto = NULL
        orden_sap,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id_v1`(marca_ds, tipoProducto, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo, d.canal, subcanal),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_canal`(marco_retributivo, d.canal, subcanal),
        subcanal,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comerciov2`(marca_ds, d.canal, agente, ClaseProducto, canalizacion.equipoDesc, canalizacion.agenteComercial),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_service_type`(TipoProducto),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_type_agg`(TipoMovimiento, causaBaja),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_marca`(marca_ds),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_segmento`(segmento),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
        1,
        'PEN',
        'POSTPAID',
        'BAJA',
        nombre_distribuidor,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_categoria_servicio`(ClaseProducto, TipoProducto),
        'DECOMISION',
        'CARTERA',
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, tipoProducto)

      FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO` d
      LEFT JOIN (
        -- [3] Fixed: ON UPPER(TRIM(g.tipo)) = "CARTERA" (was = d.marca_ds — always false)
        -- [4] ESTADO priority in ORDER BY
        SELECT tipo, marca, orden, CANAL, DETALLE,
          ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(tipo)), UPPER(TRIM(marca)), orden
            ORDER BY
              CASE ESTADO WHEN 'ACTIVO' THEN 1 WHEN 'PUBLICADA' THEN 2 ELSE 3 END,
              CANAL, DETALLE
          ) AS rn
        FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
        WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
      ) g
        ON  UPPER(TRIM(g.tipo))  = 'CARTERA'   -- [3] FIXED
        AND UPPER(TRIM(g.MARCA)) = UPPER(TRIM(d.marca_ds))
        AND g.ORDEN              = d.orden_sap
        AND g.rn                 = 1

      WHERE mes_factura_dt = vmes_factura_dt
        AND version = (
          SELECT `mm-commissions-reporting.KRT_CARTERA.f_obtenerVersionDeFlujoVigenteEnMes`(
            PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING))
          )
        );

    END IF;


    --- PASO 4: RESUELVO CODIGO SAP  [NEW — fix_07_03]
    -- Lookup del CODIGO de 4 caracteres en PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP.
    -- Aplica a TODAS las filas de TRANSACCIONES_EN_PROCESO (CAPTACION + CARTERA).
    -- Segment expansion: MASIVO→{RESIDENCIAL,SOHO,PYME}; PYME M / PYME P→BUSINESS.
    -- SEGMENTO field may be a comma-separated list: each token exploded independently.
    -- Explicit token wins over expanded MASIVO / PYME M / PYME P (ORDER BY priority).
    -- Unmatched rows (Class A2/C) stay NULL — never force-assigned. [INVARIANT-VOCAB]
    UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` e
    SET tipo_concepto = k.CODIGO
    FROM (
      SELECT CODIGO, k_concepto, k_sociedad, k_marca, k_orden, k_segmento
      FROM (
        SELECT
          p.CODIGO,
          UPPER(TRIM(p.CONCEPTO)) AS k_concepto,
          UPPER(TRIM(p.SOCIEDAD)) AS k_sociedad,
          UPPER(TRIM(p.MARCA))    AS k_marca,
          p.ORDEN                 AS k_orden,
          seg                     AS k_segmento,
          ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(p.CONCEPTO)), UPPER(TRIM(p.SOCIEDAD)),
                         UPPER(TRIM(p.MARCA)), p.ORDEN, seg
            ORDER BY
              -- Explicit token wins over MASIVO / PYME M / PYME P expansion
              IF(REGEXP_REPLACE(UPPER(TRIM(s_raw)), r'[\s\-]+', ' ')
                   IN ('MASIVO', 'PYME M', 'PYME P'), 1, 0),
              p.CODIGO
          ) AS rn
        FROM `mm-commissions-reporting.KRT_SAP.PARAM_TRADUCTOR_KRT_ORDEN_SAP_CODIGO_SAP` p
        CROSS JOIN UNNEST(SPLIT(p.SEGMENTO, ',')) AS s_raw
        CROSS JOIN UNNEST(
          CASE REGEXP_REPLACE(UPPER(TRIM(s_raw)), r'[\s\-]+', ' ')
            WHEN 'MASIVO'  THEN ['RESIDENCIAL', 'SOHO', 'PYME']
            WHEN 'PYME M'  THEN ['BUSINESS']
            WHEN 'PYME P'  THEN ['BUSINESS']
            ELSE [REGEXP_REPLACE(UPPER(TRIM(s_raw)), r'[\s\-]+', ' ')]
          END
        ) AS seg
        WHERE NULLIF(TRIM(s_raw), '') IS NOT NULL
          AND LENGTH(TRIM(p.CODIGO)) = 4
      )
      WHERE rn = 1
    ) k
    WHERE k.k_concepto = UPPER(TRIM(e.clase_concepto))
      AND k.k_sociedad = UPPER(TRIM(e.sociedad))
      AND k.k_marca    = UPPER(TRIM(e.marca))
      AND k.k_orden    = e.orden
      AND k.k_segmento = COALESCE(NULLIF(UPPER(TRIM(e.segmento)), ''), 'RESIDENCIAL');


    --- PASO 5: ACTUALIZO TABLA TRANSACCIONES — CAPTACION

    DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
    WHERE t.mes_factura_dt = VMES_FACTURA_DT
      AND CONTAINS_SUBSTR(t.tipo, 'CAPTACION')
      AND t.data_source_ds IN ('EKTNET', 'R', 'TCNET')
      AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
      AND NOT EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` p
        WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
          AND p.mes_comision_id       = VMES_ID
          AND p.fecha_id IS NOT NULL
          AND p.fecha_id             < VHOY_ID
      );

    INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
    SELECT e.*
    FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` e
    WHERE CONTAINS_SUBSTR(e.tipo, 'CAPTACION')
      AND e.data_source_ds IN ('EKTNET', 'R', 'TCNET')
      AND NOT EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p
        WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
          AND p.mes_comision_id       = VMES_ID
          AND p.fecha_id IS NOT NULL
          AND p.fecha_id             < VHOY_ID
      );


    --- PASO 6: ACTUALIZO TABLA TRANSACCIONES — CARTERA

    DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
    WHERE t.mes_factura_dt = VMES_FACTURA_DT
      AND CONTAINS_SUBSTR(t.tipo, 'CARTERA')
      AND t.data_source_ds IN ('EKTNET', 'R', 'TCNET')
      AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
      AND NOT EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` p
        WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
          AND p.mes_comision_id       = VMES_ID
          AND p.fecha_id IS NOT NULL
          AND p.fecha_id              < VHOY_ID
      );

    INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
    SELECT e.*
    FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO` e
    WHERE CONTAINS_SUBSTR(e.tipo, 'CARTERA')
      AND e.data_source_ds IN ('EKTNET', 'R', 'TCNET')
      AND NOT EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p
        WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
          AND p.mes_comision_id       = VMES_ID
          AND p.fecha_id IS NOT NULL
          AND p.fecha_id              < VHOY_ID
      );

  END IF;

END