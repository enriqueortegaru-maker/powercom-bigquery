BEGIN
  DECLARE VMES_ID, VHOY_ID, VVER_CAPT, VVER_CART INT64;
  DECLARE VMES_FACTURA_DT DATE;

  SET VMES_FACTURA_DT = PARSE_DATE('%Y%m%d', CAST(vdesde AS STRING));
  SET VMES_ID = CAST(FORMAT_DATE('%Y%m', VMES_FACTURA_DT) AS INT64);
  SET VHOY_ID = CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE('Europe/Madrid')) AS INT64);

  IF CONTAINS_SUBSTR(vtipo, 'Total') OR CONTAINS_SUBSTR(vtipo, 'Captacion') OR CONTAINS_SUBSTR(vtipo, 'Cartera') THEN

    --- PASO 1: ELIMINO Y RECREO TABLA INTERMEDIA
    DROP TABLE IF EXISTS `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_V5`;
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_V5` AS
    SELECT * FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5` WHERE 1 = 0;

    --- PASO 2: INSERTO REGISTROS DE CAPTACION (COMISION + DECOMISION UNIFICADOS)
    IF CONTAINS_SUBSTR(vtipo, 'Total') OR CONTAINS_SUBSTR(vtipo, 'Captacion') THEN
      SET VVER_CAPT = `mm-commissions-reporting.KRT_CAPTACION.f_obtenerVersionDeFlujoVigenteEnMes`(VMES_FACTURA_DT);

      INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_V5` (
        mes_factura_dt, mes_liquidado, commission_id, id_registro, invoice_id, estado, marca,
        customer_id, service_id, concepto_ds_gekt, tariff_ds, clase_concepto, activation_date,
        sale_date, canal_gekt, subcanal, distribuidor, razon_social, seller, customer_dni,
        segmento, tariff_id, concepto, tipo_concepto, order_id, account_id, bundle_type,
        marco, orden, comision, id_mes, sfid_id, agrupacion_canal, canal, subcanal_gekt,
        nombre_comercio, service_type, technology_ds, order_type_agg, bp, id_comisionista,
        cif, cod_marca, cod_segmento, sociedad, deactivation_date, causa_baja_agrup, causa_baja,
        unidades, zona_fiscal, billing_type_ds, operation, distribuidor_gekt,
        categoria_servicio_ds, clase, tipo, concepto_factura_ds, data_source_ds
      )
      WITH g_capt AS (
        SELECT UPPER(TRIM(marca)) AS marca_norm, orden, DETALLE
        FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
        WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
          AND UPPER(TRIM(tipo)) = 'CAPTACION'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(marca)), orden ORDER BY CANAL, DETALLE) = 1
      )
      SELECT
        c.mes_factura_dt,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_mes_liquidado`(c.mes_factura_dt, c.fecha_rfb_dt),
        c.commission_id,
        c.id_registro,
        c.invoice_id,
        c.estado,
        c.marca_ds,
        CAST(c.Cliente_id AS STRING),
        CAST(c.servicio_id AS STRING),
        CAST(c.concepto_ds AS STRING),
        c.detalle_servicio_ds,
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.detalle_servicio_ds, c.clase_mm, c.desc_mm, c.concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap),
          c.segmento_ds, c.desc_mm, c.categoria_servicio_ds, g.DETALLE
        ),
        EXTRACT(DATE FROM c.fecha_rfb_dt),
        EXTRACT(DATE FROM c.fecha_venta_neta_dt),
        c.canal_alta_ds,
        c.subcanal_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(c.marca_ds, c.nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(c.marca_ds, c.nombre_distribuidor_alta_ds),
        c.agente_alta_id,
        c.cif_nif,
        COALESCE(NULLIF(UPPER(TRIM(c.segmento_ds)), ''), 'RESIDENCIAL'),
        c.catalogo_id,
        c.desc_mm,
        CAST(NULL AS STRING),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_order_id`(c.marca_ds, c.pedido),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_account_id`(c.marca_ds, CAST(c.contrato_id AS STRING)),
        c.cat_plays_p,
        c.marco_Retributivo_ds,
        c.orden_sap,
        c.importe,
        VMES_ID,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id_v1`(c.marca_ds, c.categoria_servicio_ds, c.canalizacion.equipo, c.canalizacion.equipoId, c.canalizacion.agente, c.canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_agrupacion_canalv1`(c.mes_factura_dt, c.marco_retributivo_ds, c.canal_alta_ds, c.subcanal_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_canal`(c.marco_retributivo_ds, c.canal_alta_ds, c.subcanal_ds),
        c.subcanal_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comerciov2`(c.marca_ds, c.canal_alta_ds, c.equipo_ds, c.agente_Alta_id, c.categoria_servicio_ds, c.canalizacion.EquipoDesc, c.canalizacion.AgenteComercial),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_service_type`(c.categoria_servicio_ds, c.detalle_servicio_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_technology`(c.categoria_servicio_ds, c.tecnologia_detalle_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_order_type_agg`(c.portabilidad_in_lg),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(c.marca_ds, c.nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(c.marca_ds, c.nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cif_comisionista`(c.marca_ds, c.nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_marca`(c.marca_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_segmento`(c.segmento_ds),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(c.marca_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_deactivation_date`(),
        CAST(NULL AS STRING),
        CAST(NULL AS STRING),
        1, 'PEN', 'POSTPAID', 'ALTA',
        c.nombre_distribuidor_alta_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_categoria_servicio`(c.categoria_servicio_ds, c.tecnologia_detalle_ds),
        'COMISION', 'CAPTACION',
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.detalle_servicio_ds, c.clase_mm, c.desc_mm, c.concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap),
          c.segmento_ds, c.desc_mm, '', ''
        ),
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(c.marca_ds, c.categoria_servicio_ds)
      FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_DETALLADO` c
      LEFT JOIN g_capt g
        ON g.marca_norm = UPPER(TRIM(c.marca_ds))
       AND g.orden = c.orden_sap
      WHERE c.mes_factura_dt = VMES_FACTURA_DT
        AND c.version = VVER_CAPT

      UNION ALL

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
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento_ds, desc_mm, '', ''
        ),
        EXTRACT(DATE FROM fecha_rfb_dt),
        EXTRACT(DATE FROM fecha_venta_neta_dt),
        canal_alta_ds,
        subcanal_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca_ds, nombre_distribuidor_alta_ds),
        agente_alta_id,
        cif_nif,
        COALESCE(NULLIF(UPPER(TRIM(segmento_ds)), ''), 'RESIDENCIAL'),
        CAST(NULL AS STRING),
        desc_mm,
        CAST(NULL AS STRING),
        CAST(NULL AS STRING),
        CAST(NULL AS STRING),
        CAST(NULL AS STRING),
        marco_retributivo_ds,
        orden_sap,
        importe,
        VMES_ID,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_sfid_id_v1`(marca_ds, categoria_servicio_ds, canalizacion.equipo, canalizacion.equipoId, canalizacion.agente, canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_agrupacion_canalv1`(mes_factura_dt, marco_retributivo_ds, canal_alta_ds, subcanal_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_canal`(marco_retributivo_ds, canal_alta_ds, subcanal_ds),
        subcanal_ds,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_nombre_comerciov2`(marca_ds, canal_alta_ds, equipo_ds, agente_Alta_id, categoria_servicio_ds, canalizacion.EquipoDesc, canalizacion.AgenteComercial),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_service_type`(categoria_servicio_ds, detalle_servicio_ds),
        CAST(NULL AS STRING),
        CAST(NULL AS STRING),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_id_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cif_comisionista`(marca_ds, nombre_distribuidor_alta_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_marca`(marca_ds),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_cod_segmento`(segmento_ds),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(marca_ds),
        EXTRACT(DATE FROM fecha_baja_dt),
        motivo_baja_agrup_ds,
        motivo_baja_ds,
        1, 'PEN', 'POSTPAID', 'BAJA',
        nombre_distribuidor_alta_ds,
        categoria_servicio_ds,
        'DECOMISION', 'CAPTACION',
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CAPTACION',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(detalle_servicio_ds, clase_mm, desc_mm, concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(orden_sap),
          segmento_ds, desc_mm, '', ''
        ),
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(marca_ds, categoria_servicio_ds)
      FROM `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_DECOMISIONES_CAPTACION_DETALLADO`
      WHERE mes_factura_dt = VMES_FACTURA_DT
        AND version = VVER_CAPT;
    END IF;

    --- PASO 3: INSERTO REGISTROS DE CARTERA (COMISION + DECOMISION UNIFICADOS)
    IF CONTAINS_SUBSTR(vtipo, 'Total') OR CONTAINS_SUBSTR(vtipo, 'Cartera') THEN
      SET VVER_CART = `mm-commissions-reporting.KRT_CARTERA.f_obtenerVersionDeFlujoVigenteEnMes`(VMES_FACTURA_DT);

      INSERT `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_V5` (
        mes_factura_dt, commission_id, id_registro, invoice_id, estado, mes_liquidado, id_mes,
        marca, order_id, account_id, tariff_id, tariff_ds, distribuidor, razon_social,
        canal_gekt, subcanal, seller, customer_id, customer_dni, activation_date, segmento,
        tariff_id_origin, service_id_origin, tariff_ds_origin, operation_type, service_id,
        concepto_ds_gekt, concepto_lista_ds_gekt, concepto_origen_ds_gekt, marco, campaign_code,
        causa_baja, causa_baja_agrup, orden, clase_concepto, comision, concepto, tipo_concepto,
        sfid_id, agrupacion_canal, canal, subcanal_gekt, nombre_comercio, service_type,
        order_type_agg, bp, id_comisionista, cif, cod_marca, cod_segmento, sociedad,
        deactivation_date, unidades, zona_fiscal, billing_type_ds, operation,
        distribuidor_gekt, categoria_servicio_ds, clase, tipo, concepto_factura_ds, data_source_ds
      )
      WITH g_cart AS (
        SELECT UPPER(TRIM(marca)) AS marca_norm, orden, DETALLE
        FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_OSxGRUPO_OS`
        WHERE ESTADO IN ('ACTIVO', 'PUBLICADA', 'INACTIVO')
          AND UPPER(TRIM(tipo)) = 'CARTERA'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(marca)), orden ORDER BY CANAL, DETALLE) = 1
      )
      SELECT
        c.mes_factura_dt,
        c.commission_id,
        c.id_registro,
        c.invoice_id,
        c.estado,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(c.mes_factura_dt, c.fecha_Activacion, c.desc_mm),
        CAST(FORMAT_DATE('%Y%m', `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(c.mes_factura_dt, c.fecha_Activacion, c.desc_mm)) AS INT64),
        c.marca_ds,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_id`(c.marca_ds, c.claseProducto, c.contrato),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_account_id`(c.marca_ds, c.claseProducto, c.contrato),
        c.IdCatalogo,
        c.NombreProducto,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(c.marca_ds, c.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(c.marca_ds, c.nombre_distribuidor),
        c.Canal,
        c.subcanal,
        c.agente,
        CAST(c.IdFijo AS STRING),
        c.DNI_CIF,
        c.Fecha_Activacion,
        COALESCE(NULLIF(UPPER(TRIM(c.segmento)), ''), 'RESIDENCIAL'),
        CAST(c.idCatalogoOrigen AS STRING),
        CAST(c.IdProductoOrigen AS STRING),
        c.NombreProductoOrigen,
        c.tipoMovimiento,
        CAST(c.IdProducto AS STRING),
        c.concepto_ds,
        c.concepto_lista,
        c.concepto_origen_ds,
        c.MARCO_RETRIBUTIVO,
        COALESCE(c.nombre_Campana, c.campana_id),
        CAST(NULL AS STRING),
        CAST(NULL AS STRING),
        c.orden_sap,
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CARTERA',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.nombreProducto, c.clase_mm, c.desc_mm, c.concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap),
          c.segmento, c.desc_mm, c.tipoMovimiento, g.DETALLE
        ),
        c.importe,
        c.desc_mm,
        CAST(NULL AS STRING),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id_v1`(c.marca_ds, c.tipoProducto, c.canalizacion.equipo, c.canalizacion.equipoId, c.canalizacion.agente, c.canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_agrupacion_canalv1`(c.mes_factura_dt, c.marco_retributivo, c.canal, c.subcanal),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_canal`(c.marco_retributivo, c.canal, c.subcanal),
        c.subcanal,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comerciov2`(c.marca_ds, c.canal, c.agente, c.ClaseProducto, c.canalizacion.equipoDesc, c.canalizacion.agenteComercial),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_service_type`(c.TipoProducto),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_type_agg`(c.TipoMovimiento, ''),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(c.marca_ds, c.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(c.marca_ds, c.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`(c.marca_ds, c.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_marca`(c.marca_ds),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_segmento`(c.segmento),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(c.marca_ds),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_deactivation_date`(),
        1, 'PEN', 'POSTPAID',
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_operacion`(c.TipoMovimiento),
        c.nombre_distribuidor,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_categoria_servicio`(c.ClaseProducto, c.TipoProducto),
        'COMISION', 'CARTERA',
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CARTERA',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(c.nombreProducto, c.clase_mm, c.desc_mm, c.concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(c.orden_sap),
          c.segmento, c.desc_mm, c.tipoMovimiento, ''
        ),
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(c.marca_ds, c.tipoProducto)
      FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_DETALLADO` c
      LEFT JOIN g_cart g
        ON g.marca_norm = UPPER(TRIM(c.marca_ds))
       AND g.orden = c.orden_sap
      WHERE c.mes_factura_dt = VMES_FACTURA_DT
        AND c.version = VVER_CART

      UNION ALL

      SELECT
        d.mes_factura_dt,
        d.commission_id,
        d.id_registro,
        d.invoice_id,
        d.estado,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(d.mes_factura_dt, d.fechaDesinstalacion, d.desc_mm),
        CAST(FORMAT_DATE('%Y%m', `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_mes_liquidado`(d.mes_factura_dt, d.fechaDesinstalacion, d.desc_mm)) AS INT64),
        d.marca_ds,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_id`(d.marca_ds, d.claseProducto, d.contrato),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_account_id`(d.marca_ds, d.claseProducto, d.contrato),
        d.IdCatalogo,
        d.NombreProducto,
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(d.marca_ds, d.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(d.marca_ds, d.nombre_distribuidor),
        d.Canal,
        d.subcanal,
        d.agente,
        CAST(d.IdFijo AS STRING),
        d.DNI_CIF,
        d.Fecha_Activacion,
        COALESCE(NULLIF(UPPER(TRIM(d.segmento)), ''), 'RESIDENCIAL'),
        d.idCatalogoOrigen,
        CAST(d.IdProductoOrigen AS STRING),
        d.NombreProductoOrigen,
        d.TipoMovimiento,
        CAST(d.IdProducto AS STRING),
        d.concepto_ds,
        CAST(NULL AS STRING),
        d.concepto_origen_ds,
        d.MARCO_RETRIBUTIVO,
        d.campana_id,
        d.CausaBaja,
        d.CausaBajaGeneral,
        d.orden_sap,
        `mm-commissions-reporting.KRT_SAP.f_generadorDeConceptoEnSap`(
          'CARTERA',
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimeraLetraDeConceptoEnSap`(d.nombreProducto, d.clase_mm, d.desc_mm, d.concepto_ds),
          `mm-commissions-reporting.KRT_SAP.f_generadorPrimerDigitoDeOrdenSap`(d.orden_sap),
          d.segmento, d.desc_mm, d.tipoMovimiento, g.DETALLE
        ),
        d.total,
        d.desc_mm,
        CAST(NULL AS STRING),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_sfid_id_v1`(d.marca_ds, d.tipoProducto, d.canalizacion.equipo, d.canalizacion.equipoId, d.canalizacion.agente, d.canalizacion.agenteId),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_agrupacion_canalv1`(d.mes_factura_dt, d.marco_retributivo, d.canal, d.subcanal),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_canal`(d.marco_retributivo, d.canal, d.subcanal),
        d.subcanal,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_nombre_comerciov2`(d.marca_ds, d.canal, d.agente, d.ClaseProducto, d.canalizacion.equipoDesc, d.canalizacion.agenteComercial),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_service_type`(d.TipoProducto),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_order_type_agg`(d.TipoMovimiento, d.causaBaja),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(d.marca_ds, d.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_id_comisionista`(d.marca_ds, d.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cif_comisionista`(d.marca_ds, d.nombre_distribuidor),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_marca`(d.marca_ds),
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_cod_segmento`(d.segmento),
        `mm-commissions-reporting.KRT_SAP.f_obtieneSociedadDesdeMarca`(d.marca_ds),
        CAST(NULL AS DATE),
        1, 'PEN', 'POSTPAID', 'BAJA',
        d.nombre_distribuidor,
        `mm-commissions-reporting.KRT_CARTERA.f_trans_crea_categoria_servicio`(d.ClaseProducto, d.TipoProducto),
        'DECOMISION', 'CARTERA',
        CAST(NULL AS STRING),
        `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_categoria_servicio`(d.marca_ds, d.tipoProducto)
      FROM `mm-commissions-reporting.KRT_CARTERA.HISTORICO_DECOMISIONES_CARTERA_DETALLADO` d
      LEFT JOIN g_cart g
        ON g.marca_norm = UPPER(TRIM(d.marca_ds))
       AND g.orden = d.orden_sap
      WHERE d.mes_factura_dt = VMES_FACTURA_DT
        AND d.version = VVER_CART;
    END IF;

    --- PASO 3.3: CORRIJO ORDEN SAP Y RESUELVO CODIGO SAP [V5]
    CALL `mm-commissions-reporting.KRT_SAP.subproc_0113_ResolverCodigoSapv5_opt`('TRANSACCIONES_EN_PROCESO_V5', vdesde, vtipo);

    --- PASO 4: ACTUALIZO TABLA TRANSACCIONES_V5
    IF CONTAINS_SUBSTR(vtipo, 'Total') OR CONTAINS_SUBSTR(vtipo, 'Captacion') THEN
      DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5` t
      WHERE t.mes_factura_dt = VMES_FACTURA_DT
        AND CONTAINS_SUBSTR(t.tipo, 'CAPTACION')
        AND t.data_source_ds IN ('EKTNET', 'R', 'TCNET')
        AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(t.segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
        AND NOT EXISTS (
          SELECT 1
          FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` p
          WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
            AND p.mes_comision_id = VMES_ID
            AND p.fecha_id IS NOT NULL
            AND p.fecha_id < VHOY_ID
        );

      INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5`
      SELECT e.*
      FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_V5` e
      WHERE CONTAINS_SUBSTR(e.tipo, 'CAPTACION')
        AND e.data_source_ds IN ('EKTNET', 'R', 'TCNET')
        AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(e.segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
        AND NOT EXISTS (
          SELECT 1
          FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` p
          WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
            AND p.mes_comision_id = VMES_ID
            AND p.fecha_id IS NOT NULL
            AND p.fecha_id < VHOY_ID
        );
    END IF;

    IF CONTAINS_SUBSTR(vtipo, 'Total') OR CONTAINS_SUBSTR(vtipo, 'Cartera') THEN
      DELETE FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5` t
      WHERE t.mes_factura_dt = VMES_FACTURA_DT
        AND CONTAINS_SUBSTR(t.tipo, 'CARTERA')
        AND t.data_source_ds IN ('EKTNET', 'R', 'TCNET')
        AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(t.segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
        AND NOT EXISTS (
          SELECT 1
          FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p
          WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(t.marca))
            AND p.mes_comision_id = VMES_ID
            AND p.fecha_id IS NOT NULL
            AND p.fecha_id < VHOY_ID
        );

      INSERT INTO `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_V5`
      SELECT e.*
      FROM `mm-commissions-reporting.KRT_SAP.TRANSACCIONES_EN_PROCESO_V5` e
      WHERE CONTAINS_SUBSTR(e.tipo, 'CARTERA')
        AND e.data_source_ds IN ('EKTNET', 'R', 'TCNET')
        AND NOT CONTAINS_SUBSTR(COALESCE(NULLIF(UPPER(TRIM(e.segmento)), ''), 'RESIDENCIAL'), 'BUSINESS')
        AND NOT EXISTS (
          SELECT 1
          FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_PUBLICACION` p
          WHERE UPPER(TRIM(p.marca_ds)) = UPPER(TRIM(e.marca))
            AND p.mes_comision_id = VMES_ID
            AND p.fecha_id IS NOT NULL
            AND p.fecha_id < VHOY_ID
        );
    END IF;

  END IF;
END