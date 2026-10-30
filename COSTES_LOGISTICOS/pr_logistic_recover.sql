BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_recover`()

    --TABLA de órdenes de Entrega
--  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_recover_interbox` AS
  INSERT INTO `mm-logistics-reporting.LOG_FACTURACION.logistic_invoice_recover_interbox` 

    SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
        , CONCAT(SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),1,4),SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),6,2)) AS id_mes
        , ORDENES.marca AS MARCA
        , 'B2C' AS TARIFA_APLICADA
        , CASE WHEN ORDENES.dispositivo = 'DOCUMENTACION SMART TV' THEN CAST(ORDENES.pedido_padre AS STRING) ELSE ORDENES.id_orden END AS Order_No
        , CAST(NULL AS STRING) AS TIPO_DE_ENTRADA
        , LINEAS.MSISDN AS MSISDN
        , LINEAS.numero_serie AS Imei_Icc
        , ORDENES.id_orden AS Item_number
        , LINEAS.id_modelo AS Articulo
        , LINEAS.descripcion_modelo AS Modelo
        , ORDENES.courier AS Courier 
        , ORDENES.provincia AS Provincia
        , ORDENES.direccion AS Direccion
        , CASE WHEN ORDENES.tipo_pedido = 'Entrega' THEN ORDENES.estado_reexpedicion
              WHEN ORDENES.tipo_pedido = 'Desistimiento' THEN ORDENES.estado_final
              ELSE 'Revisar estado' END AS Estado
        , ORDENES.fecha_estado_final AS Fecha_estado
        , 'DIRECTO' AS Canal
        , ORDENES.id_cliente AS Cliente
        , NOMBRE.nombre_completo AS Nombre_envio
        , ORDENES.documento AS DNI
        , ORDENES.telefono_contacto AS Tfno
        , ORDENES.importe_pedido AS IMPORTE
        , CASE WHEN LINEAS.pago_inicial IS NULL THEN 0 ELSE LINEAS.pago_inicial END AS Pago_inicial
        , 'SIN REEMBOLSO' AS Forma_pago
        , (ORDENES.importe_pedido * IMPUESTOS.valor) AS Precio_Impto_Incl  
        , CAST(NULL AS STRING) AS Fact_cliente_final
        , CAST(NULL AS STRING) AS Alb_de_envio
        , CAST(NULL AS STRING) AS Alb_de_abono
        , 'N' AS Tipo_pedido_N
        , CAST(NULL AS STRING) AS Pedido_Plataf
        , ORDENES.numero_expedicion Pedido_Eurolog
        , ORDENES.tipo_pedido AS Tipo_Pedido
        , FORMAT_DATE("%d/%m/%Y", ORDENES.fecha_comunicacion) AS Fecha_Pedido
        , CASE WHEN ZONA.valor = 'D' THEN '31' ELSE NULL END AS Almacen
        , ORDENES.numero_lineas AS Bultos
        , ORDENES.numero_lineas AS Unidades
        , CONTADORES.Term AS Term
        , CONTADORES.Sim AS Sim
        , CONTADORES.Pae AS Pae
        , CONTADORES.Patin AS Patin
        , CONTADORES.TV AS TV
        , CASE WHEN ORDENES.dispositivo = 'DOCUMENTACION SMART TV' THEN 1 ELSE CONTADORES.Plv END AS Plv
        ,   (
              CASE WHEN CONTADORES.Term  > 0 THEN 1 ELSE 0 END +
              CASE WHEN CONTADORES.Sim   > 0 THEN 1 ELSE 0 END +
              CASE WHEN CONTADORES.Pae   > 0 THEN 1 ELSE 0 END +
              CASE WHEN CONTADORES.Patin > 0 THEN 1 ELSE 0 END +
              CASE WHEN CONTADORES.TV    > 0 THEN 1 ELSE 0 END +
              CASE WHEN CONTADORES.Plv   > 0 THEN 1 ELSE 0 END
            ) AS Referencias
        , CONTADORES.total_impresos AS Impresos
        , CONTADORES.total_preimpresos AS Preimpresos
        , ORDENES.dispositivo AS Tipo_producto
        , ZONA.zona AS Zona
        , CASE WHEN ORDENES.courier = 'CORREOS ENVIO SEGURO' THEN 'ENTREGA EN OFICINA'
                WHEN ORDENES.courier IN ('CLC (ASIGNA CANARIAS','CLC (ASIGNA CANARIAS)') THEN 'CLC24'
                WHEN ORDENES.courier = 'ASM DELTA' THEN 'BUSINESPARCEL'
                WHEN ORDENES.courier = 'HOME LOGISTICS' THEN 'HOME LOGISTICS'
                WHEN ORDENES.courier = 'INSIDE LOGISTICS' THEN 'INSIDE'
                WHEN ORDENES.courier = 'ASM CENTRAL' THEN 'ASM 14'
                WHEN ORDENES.courier = 'SENDING' THEN 'EXPRESS'
                ELSE ORDENES.courier END AS Servicio
        , CAST(ORDENES.total_peso AS INT64) AS Kilos
        , ORDENES.retorno_contrato AS DAC
        , CASE WHEN ORDENES.identificacion IN ('Exclusiva (+ entrega segura + FOTODNI)','Exclusiva (+ FOTODNI)','Exclusiva') THEN 'DNI Verif.' ELSE CAST(NULL AS STRING) END AS Foto_Dni
        , ORDENES.numero_lineas AS Unid_Fact 
        , CONTADORES.Coste_prep AS Coste_prep
        , CONTADORES.Unidades_adic AS Unidades_adic
        , CONTADORES.Sim_adic AS Sim_adic
        , CONTADORES.Costes_Impresos AS Costes_Impresos
        , CONTADORES.Costes_Preimpresos AS Costes_Preimpresos
        , CONTADORES.Coste_Cancelacion_post AS Coste_Cancelacion_post
        , CONTADORES.Palets_Manip AS Palets_Manip 
        , CONTADORES.Palets_sin_Manip AS Palets_sin_Manip
        , CONTADORES.Total_Coste_Manipul AS Total_Coste_Manipul
        , CONTADORES.Coste_Devo_Contrato AS Coste_Devo_Contrato
        , CONTADORES.Coste_Seguro_de_tte AS Coste_Seguro_de_tte
        , CONTADORES.Coste_Foto_DNI AS Coste_Foto_DNI
        , CONTADORES.Coste_Entrega_Exclusiva AS Coste_Entrega_Exclusiva
        , CONTADORES.Coste_Appointment AS Coste_Appointment
        , CONTADORES.Coste_Transp AS Coste_Transp
        , CONTADORES.Coste_Correos AS Coste_Correos
        , CONTADORES.Coste_Swaps AS Coste_Swaps
        , CONTADORES.Coste_Dua AS Coste_Dua
        , CONTADORES.Coste_Contrareembolso AS Coste_Contrareembolso
        , CONTADORES.Coste_DESTRUCCION AS Coste_DESTRUCCION
        , CONTADORES.Coste_DEVOLUCION_RECOG AS Coste_DEVOLUCION_RECOG
        , CONTADORES.Coste_Cancelacion AS Coste_Cancelacion
        , CONTADORES.Coste_Recanalizacion AS Coste_Recanalizacion
        , CONTADORES.Coste_extras AS Coste_extras
        , CONTADORES.Total_Coste_Transporte AS Total_Coste_Transporte
        , CONTADORES.EXCESO_CORREOS_HL AS EXCESO_CORREOS_HL
        , CONTADORES.Total_Coste_Man_y_Trans AS Total_Coste_Man_y_Trans
        , 'S' AS Final
        , ORDENES.tipo_pedido AS Tipo_evento_logistico
        , (select case when max(numero_serie) is null then 'MO' else 'FMC' end from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE where LINEAS.id_orden = ORDENES.id_orden and LINE.reexpedicion = ORDENES.reexpedicion and LINE.dispositivo in ('STB','ROUTER')) as pedido_MO_FMC
        , TIPO.Tipo_equipo AS Tipo_equipo
        , 'XXXX-XXXX' AS Claim_code
          
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
      LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND LINEAS.reexpedicion = ORDENES.reexpedicion
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
        ON CASE WHEN ORDENES.tipo_pedido = 'Entrega' THEN gef.estado = ORDENES.estado_reexpedicion
                WHEN ORDENES.tipo_pedido IN ('Desistimiento','Swap') THEN gef.estado = ORDENES.estado_final
                ELSE gef.estado = ORDENES.estado_final END
        AND UPPER(gef.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  IMPUESTOS.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND IMPUESTOS.fecha_desde BETWEEN CAST(ORDENES.fecha_estado_final AS DATE) AND CAST(ORDENES.fecha_estado_final AS DATE)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.TEMP.tipo_equipo` TIPO
        ON  UPPER(TIPO.marca) = UPPER(ORDENES.marca)
        AND UPPER(TIPO.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND TIPO.id_orden = ORDENES.id_orden
      LEFT JOIN `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica` CONTADORES
        ON  CONTADORES.id_orden = ORDENES.id_orden 
        AND CONTADORES.reexpedicion = ORDENES.reexpedicion
        AND CONTADORES.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_nombre` NOMBRE
        ON  NOMBRE.documento = ORDENES.documento

    WHERE gef.final = 'SI'
      AND gef.facturable = 'SI'
      AND ORDENES.estado_final NOT IN ('MULTISIM')
      AND ORDENES.id_orden IN (SELECT * FROM `mm-commissions-reporting.TEMP.contract_id_no_abonados_carga_manual`)  --Poner la tabla que elijamos
      AND CONTADORES.Total_Coste_Man_y_Trans NOT IN (0.0) 

    QUALIFY ROW_NUMBER () OVER (PARTITION BY ORDENES.marca, ORDENES.id_orden, ORDENES.numero_expedicion 
      ORDER BY ORDENES.direccion DESC, ORDENES.documento DESC, ORDENES.tipo_orden DESC, ORDENES.numero_lineas DESC) = 1;

END