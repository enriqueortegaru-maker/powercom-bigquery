BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_transactions`(202410,'calculado','sin facturar');  
--'validado','facturado'      --Valores para uso real y no para test 
-- 'calculado','sin facturar' --Valores para uso test y no para real

INSERT INTO `mm-commissions-reporting.COSTES_LOGISTICOS.transacciones_cd` 
(
  SELECT LC.cost_id AS commission_id
    , estado_transaccion_facturada as estado_facturacion  --'facturado'
    , LC.mes_liquidado
    , LC.id_mes
    , LO.id_master AS agrupacion_master
    , LO.master AS master
    , LC.codigo_coste AS concepto
    , LC.tipo_coste AS tipo_concepto
    , '1' AS unidades
    , LC.coste_sin_imp AS coste_sin_impuestos
    , LC.coste_con_imp AS coste_con_impuestos
    , UPPER(LO.operador_logistico) AS operador_logistico
    , CASE WHEN ZONA.zona = 'Canarias' THEN 'CAN' ELSE 'PEN' END AS zona_fiscal
    , LO.marca AS marca
    , CASE WHEN dispositivo IN ('STB') THEN 'TV' 
          WHEN dispositivo IN ('ROUTER FIBRA','MODEM','ROUTER') THEN 'INTERNET' 
          WHEN dispositivo IN ('TERMINAL','ACCESORIO','SIM','TABLET','SMART_TV','ACCESORIES WITH IMEI','ACCESORIES','ACCESORIES WITH SERIAL NUMBER') THEN 'MOBILE' 
          ELSE dispositivo END AS service_type 
    , LO.telefono_contacto AS phone_nm
    , LO.categoria_contrato AS contrat_category
    , LO.id_suscripcion AS service_id
    , LO.id_cliente AS customer_id
    , LO.categoria_contrato AS billing_type_ds
    , LO.fecha_comunicacion AS sale_date
    , LO.fecha_ultima_actualizacion AS last_update_date
    , LO.id_orden AS order_id
    , LO.tipo_pedido AS order_type
    , 'TBD' AS cod_segmento
    , CASE WHEN UPPER(LO.marca) IN ('YOIGO') THEN '01'
           WHEN UPPER(LO.marca) IN ('MASMOVIL') THEN '05'
           ELSE NULL END AS cod_marca
    , 'TBD' AS cod_tipo_contrato
    , 'TBD' AS cod_producto
    , 'TBD' AS cod_canal
    , LC.numero_serie AS serial_number
    , LC.coste_sin_imp AS tax_base
    , COALESCE(POSTPRO.jira_asociado,NULL) AS claim_code
    , COALESCE(POSTPRO.notas,NULL) AS comments
    , 'POWERCOM' AS facturador
    , NULL AS proceso_sap
    , NULL AS id_registro
    , NULL AS invoice_id
    , CASE WHEN UPPER(LO.marca) IN ('YOIGO','MASMOVIL') THEN 'X001' ELSE NULL END AS sociedad
    , NULL AS bp
    , NULL AS cuenta_contable
    , NULL AS centro_coste
    , NULL AS documento_sap
    , NULL AS documento_sap_posicion
    , NULL AS fecha_contabilizacion
    , CURRENT_TIMESTAMP() AS creado
    , NULL AS modificado
    , NULL AS id_factura_drive
        --Comienzan los campos propios de canal directo
    , CASE WHEN LC.tipo_pedido = 'Entrega' THEN LO.estado_final 
           WHEN LC.tipo_pedido = 'Desistimiento' THEN DESTADOS.accion
           ELSE CAST(NULL AS STRING) END AS estado_pedido
    , LC.reexpedition AS reexpedicion
    , LC.impuesto AS impuesto
    , LO.courier AS courier
    , LO.servicio AS servicio
    , LO.identificacion AS identificacion
    , LO.retorno_contrato AS retorno_contrato
    , LO.provincia AS provincia
    , LO.codigo_postal AS codigo_postal
    , LO.tipo_cliente AS tipo_cliente
    , LO.contrato AS contrato
    , LO.estado_reexpedicion AS estado_reexpedicion
    , LO.SFID_ID AS sfid_id
    , LO.RMA AS rma
    , LC.agrupacion_canal AS agrupacion_canal
    , LC.canal AS canal    

  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` LC
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` LO
      ON  LO.id_orden = CAST(LC.id_orden AS STRING)
      AND LO.tipo_pedido = LC.tipo_pedido
      AND LO.reexpedicion = LC.reexpedition
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
      ON  ZONA.codigo_postal = SUBSTR(LO.codigo_postal,1,2)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` POSTPRO
      ON  POSTPRO.id_orden = CAST(LC.id_orden AS STRING)
      AND POSTPRO.tipo_pedido = LC.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` DESTADOS
      ON  DESTADOS.orderCrmId = CAST(LC.id_orden AS STRING)
      AND DESTADOS.reexpedition = LC.reexpedition
      AND DESTADOS.rank = 1
  WHERE LC.id_mes = id_mes_factura
    AND LC.estado = estado_coste_facturar  --el plan es pasar a 'validado' los costes que queramos facturar. Así podemos dejar en 'calculado' lo que no queramos facturar
  
);

END