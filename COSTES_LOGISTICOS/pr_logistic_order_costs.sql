BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_order_costs`()

DECLARE id_mes_actual STRING;
SET id_mes_actual = CONCAT(SUBSTR(CAST(DATE_TRUNC(CURRENT_DATE(), MONTH) AS STRING),1,4),SUBSTR(CAST(DATE_TRUNC(CURRENT_DATE(), MONTH) AS STRING),6,2));

  --Creacion tablas costes de entregas
CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_costs` AS (

  SELECT 'DIRECTA'||'_'||id_mes_actual||'_'||ROW_NUMBER () OVER () AS cost_id, *
  FROM (

    --01.-Costes impresos blanco y negro
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada
      , COSTES.codigo_coste, COSTES.tipo_coste, ROUND((COSTES.importe * ORDENES.total_impresos),6) AS coste_sin_imp, ROUND((COSTES.importe * ORDENES.total_impresos * IMPUESTOS.valor),6) AS coste_con_imp  
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
--      , AGRUPACION.agrupacion as agrupacion_canal
      , COALESCE(AGRUPACION.agrupacion,'Otros') AS agrupacion_canal
      , ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
        AND COSTES.validacion = 'total_impresos'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE (ORDENES.total_impresos > 0 AND ORDENES.total_impresos IS NOT NULL)
--      AND ORDENES.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
--      AND ORDENES.dispositivo <> 'DOCUMENTACION SMART TV'

    UNION ALL
    
    --02.-Costes preimpresos
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe * ORDENES.total_preimpresos),6) AS coste_sin_imp
      , ROUND((COSTES.importe * ORDENES.total_preimpresos * IMPUESTOS.valor),6) AS coste_con_imp  
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
        AND ORDENES.total_preimpresos > 0
        AND COSTES.validacion = 'total_preimpresos'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE  (ORDENES.total_preimpresos > 0 AND ORDENES.total_preimpresos IS NOT NULL)
--      AND ORDENES.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
--      AND ORDENES.dispositivo <> 'DOCUMENTACION SMART TV'

    UNION ALL

    --03.-Costes impresos color
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe * ORDENES.total_color),6) AS coste_sin_imp
      , ROUND((COSTES.importe * ORDENES.total_color * IMPUESTOS.valor),6) AS coste_con_imp  
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
        AND ORDENES.total_color > 0
        AND COSTES.validacion = 'total_impresos_color'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE  (ORDENES.total_color > 0 AND ORDENES.total_color IS NOT NULL)
--      AND ORDENES.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
--      AND ORDENES.dispositivo <> 'DOCUMENTACION SMART TV'

    UNION ALL
/*
    --04.-Costes de cancelación
    --HAY QUE COMPROBAR SI ES CORRECTO JG Y SI ES PARA TODOS Y QUE HACER CON LAS SMART-TVs DE HL
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp  
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal--, CONCEPTO.concepto
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE UPPER(COSTES.codigo_coste) = 'L - CANCELACION'
      AND UPPER(COSTES.cancelacion_solicitada) = 'SI'  --Parece que aplicamos siempre, no solo cuando se solicita la cancelacion
      AND (
          (ORDENES.estado_reexpedicion in ('Destruido (SIM)','Devuelto al almacen') AND UPPER(ORDENES.courier) = 'CORREOS')
        OR (ORDENES.estado_reexpedicion in ('Devuelto al almacen') AND (UPPER(ORDENES.courier) <> 'CORREOS' OR ORDENES.courier IS NULL))
      )
  */

    --04.-Costes de cancelación
    --HAY QUE COMPROBAR SI ES CORRECTO JG Y SI ES PARA TODOS Y QUE HACER CON LAS SMART-TVs DE HL
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp  
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal--, CONCEPTO.concepto
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE UPPER(COSTES.codigo_coste) = 'L - CANCELACION'
      AND UPPER(COSTES.cancelacion_solicitada) = 'SI'  --Parece que aplicamos siempre, no solo cuando se solicita la cancelacion
      AND (
          (ORDENES.estado_final in ('Destruido (SIM)','Devuelto al almacen') AND UPPER(ORDENES.courier) = 'CORREOS')
        OR (ORDENES.estado_final in ('Devuelto al almacen') AND (UPPER(ORDENES.courier) <> 'CORREOS' OR ORDENES.courier IS NULL))
      )
      AND (UPPER(ORDENES.courier) NOT IN ('HL','INSIDE'))
      AND COSTES.courier IN ('%')

    UNION ALL

    --04.-Costes de cancelación SMART-TV
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp  
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal--, CONCEPTO.concepto
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND UPPER(LINEAS.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND UPPER(LINEAS.dispositivo) IN ('SMART TV+DOCUMENTACION','SMART TV')
--      LEFT JOIN  `mm-commissions-reporting.TEMP.tamano_smart_tv` TAMANO
--        ON  (TAMANO.id_modelo = LINEAS.id_modelo OR TAMANO.codigo_modelo = LINEAS.id_modelo)
      LEFT JOIN `mm-commissions-reporting.TEMP.10_gs_tamano_smart_tv` TAMANO
        ON  COALESCE(LINEAS.id_modelo,LINEAS.codigo_modelo) = TAMANO.id_modelo  -- (TAMANO.id_modelo = LINEAS.id_modelo OR TAMANO.id_modelo = LINEAS.codigo_modelo)
    WHERE UPPER(COSTES.codigo_coste) = 'L - CANCELACION'
      AND UPPER(COSTES.cancelacion_solicitada) = 'SI'  --Parece que aplicamos siempre, no solo cuando se solicita la cancelacion
      AND (
          (ORDENES.estado_final in ('Destruido (SIM)','Devuelto al almacen') AND UPPER(ORDENES.courier) = 'CORREOS')
        OR (ORDENES.estado_final in ('Devuelto al almacen') AND (UPPER(ORDENES.courier) <> 'CORREOS' OR ORDENES.courier IS NULL))
      )

      AND ORDENES.dispositivo IN ('SMART TV','SMART TV+DOCUMENTACION')
      AND COSTES.courier NOT IN ('%')    
      AND (UPPER(ORDENES.courier) IN ('HL','INSIDE') AND UPPER(ORDENES.courier) = UPPER(COSTES.courier) AND COSTES.zona = ZONA.valor)
      AND COSTES.validacion = 'tamano' AND TAMANO.tamano = COSTES.valor_desde
-- FALTA METER LA OPCION PARA ANTES DE jul/25 para que aplique %


    UNION ALL

    --05.-Cancelado y destruido. costes únicos para sims-destruidas (Coste por destrucción de la SIM por parte del transportista)
    --HAY QUE COMPROBAR SI ES CORRECTO JG Y SI ES PARA TODOS Y QUE HACER CON LAS SMART-TVs DE HL
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Destruido','Destruído por transportista','Destruido (SIM)')
      AND COSTES.validacion in ('destruccion')

    UNION ALL

    --06.-DEVUELTO AL ALMACEN Y SIM+dispositivo, hay que abonar la destrucción de la SIM
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Devuelto al almacen')
      AND ORDENES.dispositivo LIKE 'SIM+%'
      AND COSTES.validacion in ('destruccion')

    UNION ALL

    --07.-DUA y gestión administrativa end to end de aduanas Ceuta y Melilla
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND UPPER(ORDENES.provincia) IN ('CEUTA','MELILLA')
      AND UPPER(COSTES.codigo_coste) = 'L - DUA'

    UNION ALL

    --08.-SEGURO transporte a todo riesgo por el valor de la mercancia PARA CORREOS
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
--      , ROUND((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100),6) AS coste_sin_imp
--      , TRUNC(ROUND(((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100) * IMPUESTOS.valor),6),6) AS coste_con_imp 
      , CASE WHEN precio_almacen_sin_imp IS NULL THEN ROUND((COALESCE(STOCK_IB.Precio_mk_up,0) * COSTES.porcentaje / 100),6) ELSE ROUND((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100),6) END AS coste_sin_imp
      , CASE WHEN precio_almacen_con_imp IS NULL THEN ROUND((COALESCE(STOCK_IB.Precio_mk_up,0) * COSTES.porcentaje / 100) * IMPUESTOS.valor,6) ELSE ROUND(((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100) * IMPUESTOS.valor),6) END AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
        AND ORDENES.courier = COSTES.courier
        AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO'
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.TEMP.stock_Interbox` STOCK_IB
        ON  STOCK_IB.Codigo = LINEAS.id_modelo
    WHERE ORDENES.estado_final IN ('Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND UPPER(LINEAS.dispositivo) NOT IN ('SIM')
      AND COSTES.codigo_coste = 'L - SEGURO'
      AND UPPER(ORDENES.courier) = 'CORREOS'
      AND ORDENES.dispositivo <> 'DOCUMENTACION SMART TV'
      
--      AND LINEAS.precio_almacen_sin_imp IS NOT NULL
--      AND LINEAS.precio_almacen_sin_imp <> 0

    UNION ALL

    --09.-SEGURO transporte a todo riesgo por el valor de la mercancia PARA DISTINTO DE CORREOS
    SELECT ORDENES.id_orden AS id_orden, LINEAS.reexpedicion AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
--      , ROUND((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100),6) AS coste_sin_imp
--      , TRUNC(ROUND(((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100) * IMPUESTOS.valor),6),6) AS coste_con_imp 
      , CASE WHEN precio_almacen_sin_imp IS NULL THEN ROUND((COALESCE(STOCK_IB.Precio_mk_up,0) * COSTES.porcentaje / 100),6) ELSE ROUND((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100),6) END AS coste_sin_imp
      , CASE WHEN precio_almacen_con_imp IS NULL THEN ROUND((COALESCE(STOCK_IB.Precio_mk_up,0) * COSTES.porcentaje / 100) * IMPUESTOS.valor,6) ELSE ROUND(((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100) * IMPUESTOS.valor),6) END AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
        AND COSTES.courier = CAST('%' AS STRING)
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.TEMP.stock_Interbox` STOCK_IB
        ON  STOCK_IB.Codigo = LINEAS.id_modelo
    WHERE ORDENES.estado_final IN ('Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND LINEAS.dispositivo NOT IN ('SIM')
      AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO'
      AND COSTES.codigo_coste = 'L - SEGURO'
      AND ORDENES.courier <> 'CORREOS'
--      AND LINEAS.precio_almacen_sin_imp IS NOT NULL
--      AND LINEAS.precio_almacen_sin_imp <> 0
      AND ORDENES.dispositivo <> 'DOCUMENTACION SMART TV'

    UNION ALL

    --10.-SEGURO transporte SIM
    SELECT ORDENES.id_orden AS id_orden, LINEAS.reexpedicion AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND(COSTES.importe,6) AS coste_sin_imp
      , TRUNC(ROUND((COSTES.importe * IMPUESTOS.valor),4),4) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal        
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)','Destruido (SIM)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND LINEAS.dispositivo IN ('SIM')
      AND COSTES.codigo_coste = 'L - SEGURO'
      AND ORDENES.courier <> 'CORREOS'
      AND COSTES.courier <> 'CORREOS'
      AND UPPER(COSTES.dispositivo) = UPPER(LINEAS.dispositivo)
      AND ORDENES.dispositivo <> 'DOCUMENTACION SMART TV'

    UNION ALL

    --10.1.-SEGURO transporte SIM CORREOS
    SELECT ORDENES.id_orden AS id_orden, LINEAS.reexpedicion AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND(COSTES.importe,6) AS coste_sin_imp
      , TRUNC(ROUND((COSTES.importe * IMPUESTOS.valor),4),4) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal        
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)','Destruido (SIM)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND LINEAS.dispositivo IN ('SIM')
      AND COSTES.codigo_coste = 'L - SEGURO'
      AND ORDENES.courier = 'CORREOS'
      AND COSTES.courier = 'CORREOS'
      AND UPPER(COSTES.dispositivo) = UPPER(LINEAS.dispositivo)
      AND ORDENES.dispositivo <> 'DOCUMENTACION SMART TV'

    UNION ALL

    --10.2.-SEGURO transporte DOCUMENTACION SMART TV CORREOS
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND(COSTES.importe,6) AS coste_sin_imp
      , TRUNC(ROUND((COSTES.importe * IMPUESTOS.valor),4),4) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal        
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND COSTES.codigo_coste = 'L - SEGURO'
      AND ORDENES.courier = 'CORREOS'
      AND COSTES.courier = 'CORREOS'
      AND UPPER(COSTES.dispositivo) = UPPER(ORDENES.dispositivo)
      AND ORDENES.dispositivo = 'DOCUMENTACION SMART TV'

    UNION ALL

    --11.-Recogida documentacion Correos
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.retorno_contrato = 'SI'
      AND UPPER(ORDENES.courier) IN ('CORREOS')
      AND COSTES.codigo_coste IN ('L - DEVO_CONTRATO')
      AND UPPER(ORDENES.courier) = UPPER(COSTES.courier)
      AND COSTES.zona = ZONA.valor
    
    UNION ALL

    --12.-Recogida documentacion No Correos ni HL
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.retorno_contrato = 'SI'
      AND UPPER(ORDENES.courier) NOT IN ('CORREOS')
      AND UPPER(COSTES.codigo_coste) IN ('L - DEVO_CONTRATO')
      AND UPPER(COSTES.courier) NOT IN ('HL','CORREOS')
      
    UNION ALL

    --13.-FOTO DNI CORREOS - EED - Entrega Exclusiva destinatario
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal        
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)','Destruido (SIM)','Devuelto al almacen')   --Se paga a correo aunque no se entregue
      AND COSTES.codigo_coste IN ('L - FOTODNI')
      AND COSTES.courier IN ('CORREOS')
      AND UPPER(ORDENES.courier) IN ('CORREOS')

    UNION ALL

    --14.-Entrega Exclusiva NO CORREOS
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)') --,'Devuelto al almacen','Destruido (SIM)') --No aplica si no entrega
      AND UPPER(COSTES.codigo_coste) IN ('L - ENTREGA_EXCL')
      AND UPPER(COSTES.courier) NOT IN ('CORREOS') -- = '%'
      AND (UPPER(ORDENES.courier) NOT IN ('CORREOS') OR ORDENES.courier IS NULL)
      AND ORDENES.identificacion IS NOT NULL
--      AND UPPER(ORDENES.dispositivo) NOT IN ('SMART TV+DOCUMENTACION','SMART TV') --aplicamos tamb ¡ién a Smart TV

  UNION ALL

    --15.-Entrega Exclusiva CORREOS
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)','Destruido (SIM)','Devuelto al almacen') --Se paga a correo aunque no se entregue
      AND UPPER(COSTES.codigo_coste) IN ('L - ENTREGA_EXCL')
      AND UPPER(ORDENES.courier) IN ('CORREOS')
      AND UPPER(COSTES.courier) = UPPER(ORDENES.courier)
      AND ORDENES.identificacion IS NOT NULL
      AND UPPER(ORDENES.dispositivo) NOT IN ('SMART TV+DOCUMENTACION','SMART TV')

    UNION ALL
/*
    --16.-Costes preparacion del pedido
    SELECT PEDIDO.id_orden AS id_orden, PEDIDO.reexpedition, PEDIDO.estado_final, PEDIDO.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, PEDIDO.canal
      , PEDIDO.marca, PEDIDO.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` PEDIDO
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(PEDIDO.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(PEDIDO.tipo_pedido)
        AND CAST(PEDIDO.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
--      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_dispositivo_calculado` DISPOSITIVO
--        ON  CAST(DISPOSITIVO.id_orden AS INT64) = PEDIDO.id_orden
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = PEDIDO.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(PEDIDO.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(PEDIDO.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(PEDIDO.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      WHERE PEDIDO.estado_reexpedicion IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
--      AND UPPER(DISPOSITIVO.dispositivo_calculado) = UPPER(COSTES.dispositivo)
      AND UPPER(PEDIDO.dispositivo) = UPPER(COSTES.dispositivo)
      AND UPPER(COSTES.codigo_coste) IN ('L - PREPA_PEDIDO')
*/

    --16.1-Costes preparacion del pedido
    SELECT PEDIDO.id_orden AS id_orden, PEDIDO.reexpedition, PEDIDO.estado_final, PEDIDO.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, PEDIDO.canal
      , PEDIDO.marca, PEDIDO.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, PEDIDO.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` PEDIDO
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(PEDIDO.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(PEDIDO.tipo_pedido)
        AND CAST(PEDIDO.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = PEDIDO.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(PEDIDO.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(PEDIDO.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--      WHERE PEDIDO.estado_reexpedicion IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
    WHERE (PEDIDO.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
          OR (PEDIDO.estado_reexpedicion IS NULL AND PEDIDO.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)'))
        )
      AND UPPER(PEDIDO.dispositivo) = UPPER(COSTES.dispositivo)
      AND UPPER(COSTES.codigo_coste) IN ('L - PREPA_PEDIDO')
      AND UPPER(COSTES.dispositivo) NOT IN ('PAE','PAE o Patinete','MAE','GAE')
      AND COSTES.validacion IS NULL
      --AND PEDIDO.dispositivo <> 'DOCUMENTACION SMART TV'
--      AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL)  --GJV 2026/01/31

    UNION ALL

--16.2-Costes preparacion del pedido
    SELECT PEDIDO.id_orden AS id_orden, PEDIDO.reexpedition, PEDIDO.estado_final, PEDIDO.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, PEDIDO.canal
      , PEDIDO.marca, PEDIDO.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, PEDIDO.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` PEDIDO
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(PEDIDO.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(PEDIDO.tipo_pedido)
        AND CAST(PEDIDO.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = PEDIDO.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(PEDIDO.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(PEDIDO.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--      WHERE PEDIDO.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
    WHERE (PEDIDO.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
          OR (PEDIDO.estado_reexpedicion IS NULL AND PEDIDO.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)'))
        )
      AND UPPER(PEDIDO.dispositivo) = UPPER(COSTES.dispositivo)
      AND UPPER(COSTES.codigo_coste) IN ('L - PREPA_PEDIDO')
      AND UPPER(COSTES.dispositivo) IN ('PAE','PAE o Patinete','MAE','GAE')
      -- AND COSTES.validacion = 'total_peso'
      -- AND PEDIDO.total_peso > COSTES.valor_desde
      -- AND PEDIDO.total_peso <= COSTES.valor_hasta
      -- AND PEDIDO.dispositivo <> 'DOCUMENTACION SMART TV'
--      AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL)  --GJV 2026/01/31

    UNION ALL

    --16.3.-Costes preparacion del pedido - SIM ADICIONAL
    SELECT PEDIDO.id_orden AS id_orden, PEDIDO.reexpedition, PEDIDO.estado_final, PEDIDO.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe * (COALESCE((PEDIDO.numero_lineas-1),0))),6) AS coste_sin_imp
      , ROUND((COSTES.importe * (COALESCE((PEDIDO.numero_lineas-1),0)) * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, PEDIDO.canal
      , PEDIDO.marca, PEDIDO.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, PEDIDO.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` PEDIDO
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(PEDIDO.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(PEDIDO.tipo_pedido)
        AND CAST(PEDIDO.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = PEDIDO.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(PEDIDO.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(PEDIDO.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(PEDIDO.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE PEDIDO.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND UPPER(COSTES.codigo_coste) IN ('L - PREPA_PEDIDO_SIM_AD')
      -- AND UPPER(COSTES.dispositivo) NOT IN ('PAE','PAE o Patinete')
      AND PEDIDO.dispositivo like '%SIM%'
      -- AND COSTES.dispositivo = 'SIM adicional'
      AND PEDIDO.numero_lineas IS NOT NULL
      AND PEDIDO.numero_lineas > 1
      AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL)  --GJV 2026/01/31
      AND PEDIDO.dispositivo <> 'DOCUMENTACION SMART TV'

    UNION ALL

    --16.4.-Costes preparacion del pedido - DISPOSITIVO ADICIONAL (TAR0012)
    SELECT PEDIDO.id_orden AS id_orden, PEDIDO.reexpedition, PEDIDO.estado_final, PEDIDO.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe * (COALESCE((PEDIDO.numero_lineas-1),0))),6) AS coste_sin_imp
      , ROUND((COSTES.importe * (COALESCE((PEDIDO.numero_lineas-1),0)) * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(PEDIDO.fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(PEDIDO.fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(PEDIDO.fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, PEDIDO.canal
      , PEDIDO.marca, PEDIDO.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, PEDIDO.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` PEDIDO
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(PEDIDO.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(PEDIDO.tipo_pedido)
        AND CAST(PEDIDO.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      INNER JOIN `mm-commissions-reporting.TEMP.pedidos_varios_dispositivos` VARIOS_DISPOSITIVOS
        ON  VARIOS_DISPOSITIVOS.ot = PEDIDO.pedido_padre
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = PEDIDO.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(PEDIDO.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(PEDIDO.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(PEDIDO.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE PEDIDO.estado_final IN ('Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND UPPER(COSTES.codigo_coste) IN ('L - PREPA_PEDIDO_DISP_AD')
      AND PEDIDO.numero_lineas IS NOT NULL
      AND PEDIDO.numero_lineas >= 2
      AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL)  --GJV 2026/01/31

    UNION ALL

    --17.-Costes preparacion del pedido adicionales
    --Hay promociones puntuales que aplican costes especiales
    SELECT PEDIDO.id_orden AS id_orden, PEDIDO.reexpedition, PEDIDO.estado_final, PEDIDO.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, PEDIDO.canal
      , PEDIDO.marca, PEDIDO.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, PEDIDO.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` PEDIDO
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(PEDIDO.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(PEDIDO.tipo_pedido)
        AND CAST(PEDIDO.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
--      LEFT JOIN `mm-commissions-reporting.TEMP.dispositivo_calculado` DISPOSITIVO
--        ON  CAST(DISPOSITIVO.id_orden AS STRING) = PEDIDO.id_orden
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = PEDIDO.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(PEDIDO.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(PEDIDO.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      WHERE PEDIDO.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
--        AND UPPER(DISPOSITIVO.dispositivo_calculado) = UPPER(COSTES.dispositivo)
        AND PEDIDO.dispositivo NOT IN ('SIM','DOCUMENTACION SMART TV')
        AND UPPER(COSTES.codigo_coste) IN ('L - PREPA_EXTRA')
        -- AND COSTES.validacion = 'total_peso'
        -- AND PEDIDO.total_peso >= COSTES.valor_desde
        -- AND PEDIDO.total_peso <= COSTES.valor_hasta
        AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL)  --GJV 2026/01/31

    UNION ALL

    --18.-Costes terminal PAGO INICIAL
    SELECT ORDENES.id_orden AS id_orden, LINEAS.reexpedicion AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, 'T - PAGO_INICIAL' AS codigo_coste, 'PAYMENT' AS tipo_coste
      , ROUND((LINEAS.pago_inicial / IMPUESTOS.valor),6) AS coste_sin_imp
      , ROUND((LINEAS.pago_inicial),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado
      , CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , LINEAS.numero_serie AS numero_serie
      , 'N/A' AS codigo_contrato, 'N/A' AS posicion_cm, 'N/A' AS texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  ORDENES.id_orden = LINEAS.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND UPPER(ORDENES.tipo_pedido) = 'ENTREGA'
      AND ORDENES.dispositivo NOT IN ('SIM','STB','ROUTER')
      AND (LINEAS.dispositivo NOT IN  ('SIM','STB','ROUTER') OR LINEAS.dispositivo IS NULL)
      AND LINEAS.pago_inicial <> 0

    UNION ALL

    --19.-Costes terminal PAGO CUOTAS
    SELECT ORDENES.id_orden AS id_orden, LINEAS.reexpedicion AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, 'T - CUOTAS' AS codigo_coste, 'FINANCE' AS tipo_coste
      , ROUND((LINEAS.pago_aplazado / IMPUESTOS.valor),6) AS coste_sin_imp
      , ROUND((LINEAS.pago_aplazado),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , LINEAS.numero_serie AS numero_serie
      , 'N/A' AS codigo_contrato, 'N/A' AS posicion_cm, 'N/A' AS texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  ORDENES.id_orden = LINEAS.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND UPPER(ORDENES.tipo_pedido) = 'ENTREGA'
      AND ORDENES.dispositivo NOT IN ('SIM','STB','ROUTER')
      AND (LINEAS.dispositivo NOT IN  ('SIM','STB','ROUTER') OR LINEAS.dispositivo IS NULL)
      AND LINEAS.pago_aplazado <> 0
    
    UNION ALL

      --20.-Costes terminal PAGO VALOR RESIDUAL
    SELECT ORDENES.id_orden AS id_orden, LINEAS.reexpedicion AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, 'T - VALOR_RESIDUAL' AS codigo_coste, 'FINANCE' AS tipo_coste
      , ROUND((LINEAS.valor_residual / IMPUESTOS.valor),6) AS coste_sin_imp
      , ROUND((LINEAS.valor_residual),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , LINEAS.numero_serie AS numero_serie
      , 'N/A' AS codigo_contrato, 'N/A' AS posicion_cm, 'N/A' AS texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  ORDENES.id_orden = LINEAS.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND UPPER(ORDENES.tipo_pedido) = 'ENTREGA'
      AND ORDENES.dispositivo NOT IN ('SIM','STB','ROUTER')
      AND (LINEAS.dispositivo NOT IN  ('SIM','STB','ROUTER') OR LINEAS.dispositivo IS NULL)
      AND LINEAS.valor_residual <> 0
    
    UNION ALL

      --21.-Costes terminal PAGO SUBSIDIO
    SELECT ORDENES.id_orden AS id_orden, LINEAS.reexpedicion AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, 'T - SUBSIDIO' AS codigo_coste, 'SUBSIDIO' AS tipo_coste
      , ROUND((LINEAS.subsidio),6) AS coste_sin_imp
      , ROUND((LINEAS.subsidio * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , LINEAS.numero_serie AS numero_serie
      , 'N/A' AS codigo_contrato, 'N/A' AS posicion_cm, 'N/A' AS texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  ORDENES.id_orden = LINEAS.id_orden
        AND LINEAS.marca = ORDENES.marca
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.reexpedition = LINEAS.reexpedicion
      AND UPPER(ORDENES.tipo_pedido) = 'ENTREGA'
      AND ORDENES.dispositivo NOT IN ('SIM','STB','ROUTER')
      AND (LINEAS.dispositivo NOT IN  ('SIM','STB','ROUTER') OR LINEAS.dispositivo IS NULL)
      AND LINEAS.subsidio <> 0

    UNION ALL

    --22.-Costes transporte Correos, de ida si se entrega o si se devuelve
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  UPPER(AGRUPACION.canal) = UPPER(ORDENES.canal)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= ZONA.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= ZONA.fecha_hasta
    WHERE ORDENES.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND COSTES.codigo_coste IN ('L - TRANSP')
      AND UPPER(ORDENES.courier) IN ('CORREOS')
      AND UPPER(COSTES.courier) = UPPER(ORDENES.courier)
      AND COSTES.zona = ZONA.valor
      AND COSTES.validacion = 'total_peso'
      AND ORDENES.total_peso > COSTES.valor_desde
      AND ORDENES.total_peso <= COSTES.valor_hasta
      AND (
           (UPPER(ORDENES.dispositivo) IN ('SIM','DOCUMENTACION SMART TV') AND (ORDENES.numero_lineas <= 1 OR ORDENES.numero_lineas IS NULL)  AND UPPER(COSTES.dispositivo) = 'SIM')  --SIM Only
        OR (UPPER(ORDENES.dispositivo) IN ('SIM')  AND ORDENES.numero_lineas >= 2 AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO')  --MultiSIM  aplica dispositivo
        OR (UPPER(ORDENES.dispositivo) IN ('ROUTER','STB','STB + SIM','ROUTER + SIM') AND UPPER(COSTES.dispositivo) = 'ROUTER/STB')
        OR (UPPER(ORDENES.dispositivo) NOT IN ('SIM','ROUTER','STB','STB + SIM','ROUTER + SIM','DOCUMENTACION SMART TV') AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO')
      )
      
    UNION ALL

    --23.-Costes transporte si no es Correos HASTA máximo KG. definidos. Metemos el transporte de ida si se entrega o si se devuelve
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        --AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
--        AND COSTES.validacion = 'total_peso'  --REVISAR QUE PASA POR QUITARLO
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= ZONA.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= ZONA.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND UPPER(LINEAS.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND UPPER(LINEAS.dispositivo) IN ('SMART TV+DOCUMENTACION','SMART TV')
--      LEFT JOIN  `mm-commissions-reporting.TEMP.tamano_smart_tv` TAMANO
--        ON  (TAMANO.id_modelo = LINEAS.id_modelo OR TAMANO.codigo_modelo = LINEAS.id_modelo)
      LEFT JOIN `mm-commissions-reporting.TEMP.10_gs_tamano_smart_tv` TAMANO
        ON  COALESCE(LINEAS.id_modelo,LINEAS.codigo_modelo) = TAMANO.id_modelo  -- (TAMANO.id_modelo = LINEAS.id_modelo OR TAMANO.id_modelo = LINEAS.codigo_modelo)

    WHERE ORDENES.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND COSTES.codigo_coste IN ('L - TRANSP')
      AND (UPPER(ORDENES.courier) NOT IN ('CORREOS') OR ORDENES.courier IS NULL)

      AND (
            (UPPER(ORDENES.dispositivo) = 'SIM' AND (ORDENES.numero_lineas <= 1 OR ORDENES.numero_lineas IS NULL) AND UPPER(COSTES.dispositivo) = 'SIM' AND COSTES.courier = '%' AND COSTES.validacion = 'total_peso' AND COSTES.zona = ZONA.valor)  --SIM Only
         OR (UPPER(ORDENES.dispositivo) = 'SIM' AND ORDENES.numero_lineas >= 2 AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO' AND COSTES.courier = '%' AND COSTES.validacion = 'total_peso' AND COSTES.zona = ZONA.valor)  --MultiSIM  aplica dispositivo
         OR (UPPER(ORDENES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION') AND UPPER(ORDENES.courier) NOT IN ('HL','INSIDE') AND COSTES.dispositivo = 'DISPOSITIVO' AND COSTES.courier = '%' AND COSTES.validacion = 'total_peso' AND COSTES.zona = ZONA.valor AND (
             (ORDENES.total_peso >= 2 AND COSTES.valor_hasta = 2)
          OR (ORDENES.total_peso < 2 AND ORDENES.total_peso > COSTES.valor_desde AND ORDENES.total_peso <= COSTES.valor_hasta)
         ))
         OR (UPPER(ORDENES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION') AND UPPER(ORDENES.courier) IN ('HL','INSIDE') AND (TAMANO.tamano > 0 AND TAMANO.tamano IS NOT NULL) /*AND COSTES.validacion = 'tamano'*/ AND UPPER(COSTES.courier) = UPPER(ORDENES.courier) AND COSTES.zona = ZONA.valor AND UPPER(ORDENES.dispositivo) = UPPER(COSTES.dispositivo) AND TAMANO.tamano = COSTES.valor_desde)
         OR (UPPER(ORDENES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION') AND UPPER(ORDENES.courier) IN ('HL','INSIDE') AND (TAMANO.tamano = 0 OR TAMANO.tamano IS NULL) /*AND COSTES.validacion = 'tamano'*/ AND UPPER(COSTES.courier) = UPPER(ORDENES.courier) AND COSTES.zona = ZONA.valor AND UPPER(ORDENES.dispositivo) = UPPER(COSTES.dispositivo) AND COSTES.valor_desde = 0)
         OR (UPPER(ORDENES.dispositivo) NOT IN ('SIM','SMART TV','SMART TV+DOCUMENTACION') AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO' AND COSTES.courier = '%' AND COSTES.validacion = 'total_peso' AND COSTES.zona = ZONA.valor 
          AND (
              (ORDENES.total_peso >= 2 AND COSTES.valor_hasta = 2)
            OR (ORDENES.total_peso < 2 AND ORDENES.total_peso > COSTES.valor_desde AND ORDENES.total_peso <= COSTES.valor_hasta)
          )
         )
      )

    UNION ALL

    --23.1.-Costes transporte SMART-TV Devuelta
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo

    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= ZONA.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= ZONA.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND UPPER(LINEAS.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND UPPER(LINEAS.dispositivo) IN ('SMART TV+DOCUMENTACION','SMART TV')
      LEFT JOIN `mm-commissions-reporting.TEMP.10_gs_tamano_smart_tv` TAMANO
        ON  COALESCE(LINEAS.id_modelo,LINEAS.codigo_modelo) = TAMANO.id_modelo

    WHERE ORDENES.estado_final IN ('Devuelto al almacen')
      AND COSTES.codigo_coste IN ('L - TRANSP_DEVOLUCION')
      AND (UPPER(ORDENES.courier) IN ('HL','INSIDE') OR ORDENES.courier IS NULL)
      AND UPPER(ORDENES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION') 
      AND COSTES.dispositivo IN ('SMART TV','SMART TV+DOCUMENTACION') 

      AND COSTES.zona = ZONA.valor
      AND CASE WHEN TAMANO.tamano = 0 OR TAMANO.tamano IS NULL THEN COSTES.valor_desde = 0
               ELSE TAMANO.tamano = COSTES.valor_desde END

    UNION ALL

    --23.2.-Costes transporte SMART-TV Segundo Intento
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition AS reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , SEGUNDO_INTENTO.nserie AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      INNER JOIN `mm-commissions-reporting.TEMP.maslola_segundos_intentos_STV` SEGUNDO_INTENTO
        ON  CAST(SEGUNDO_INTENTO.itemnumber AS STRING) = ORDENES.id_orden
        AND SEGUNDO_INTENTO.rx = ORDENES.reexpedition
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= ZONA.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= ZONA.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND UPPER(LINEAS.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND UPPER(LINEAS.dispositivo) IN ('SMART TV+DOCUMENTACION','SMART TV')
      LEFT JOIN `mm-commissions-reporting.TEMP.10_gs_tamano_smart_tv` TAMANO
        ON  COALESCE(LINEAS.id_modelo,LINEAS.codigo_modelo) = TAMANO.id_modelo  -- (TAMANO.id_modelo = LINEAS.id_modelo OR TAMANO.id_modelo = LINEAS.codigo_modelo)

    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND COSTES.codigo_coste IN ('L - TRANSP (2º INTENTO)')
      AND UPPER(ORDENES.courier) IN ('HL','INSIDE')
      AND UPPER(ORDENES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION')
      AND UPPER(COSTES.dispositivo) = UPPER(ORDENES.dispositivo)
      AND TAMANO.tamano = COSTES.valor_desde 
      AND UPPER(COSTES.courier) = UPPER(ORDENES.courier)
      AND COSTES.validacion = 'tamano' 
      AND COSTES.zona = ZONA.valor

    UNION ALL

    --24.-Costes transporte si no es Correos por Kg adicional. Metemos el transporte de ida si se entrega o si se devuelve     
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
--      , ROUND((COSTES.importe*(ORDENES.total_peso-2)),6) AS coste_sin_imp
--      , ROUND((COSTES.importe*(ORDENES.total_peso-2) * IMPUESTOS.valor),6) AS coste_con_imp
      , ROUND((COSTES.importe*(CEIL(ORDENES.total_peso-2))),6) AS coste_sin_imp  --CEIL REDONDEA AL ALZA, COMPROBAR QUE PASA CON ALGO QUE PESE UN NUMERO ENTERO MAYOR QUE 2
      , ROUND((COSTES.importe*(CEIL(ORDENES.total_peso-2)) * IMPUESTOS.valor),6) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= ZONA.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= ZONA.fecha_hasta
    WHERE COSTES.codigo_coste IN ('L - TRANSP_KG_AD')
      AND ORDENES.total_peso > 2
      AND ORDENES.estado_final IN ('Destruido (SIM)','Devuelto al almacen','Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND (UPPER(ORDENES.courier) NOT IN ('CORREOS','HL','INSIDE') OR ORDENES.courier IS NULL)
      AND UPPER(ORDENES.dispositivo) NOT IN ('SIM') --,'PAE') -- ('SMART TV','SMART TV+DOCUMENTACION','SIM')  --Sí aplica a Smart TVs enviadas por otro courier que no sea HL o INSIDE  --PAE no lleva kilo adicional
      AND COSTES.servicio = '%'   -- no se está aplicando ORDENES.servicio = 'DELIVERY_24'
      AND COSTES.zona = ZONA.valor
      AND COSTES.validacion = 'kilo_adicional'
      AND COSTES.courier = '%'
--      AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO'
      --TODOS APLICA DISPOSITIVO, MENOS ROUTER Y STB
      AND CASE WHEN ORDENES.dispositivo IN ('ROUTER','ROUTER + SIM','STB','STB + SIM') THEN COSTES.dispositivo = 'ROUTER/STB'
               WHEN ORDENES.dispositivo NOT IN ('ROUTER','ROUTER + SIM','STB','STB + SIM', 'SIM') THEN COSTES.dispositivo = 'DISPOSITIVO'
               ELSE COSTES.dispositivo = 'NA' END

    UNION ALL

    --25.-Costes Servicio adicional de retorno de documentacion
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
    WHERE ORDENES.estado_final IN ('Entregado','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND UPPER(ORDENES.courier) = UPPER(COSTES.courier)  -- = 'CORREOS'
      AND COSTES.codigo_coste IN ('L - RETORNO_DOC')
      AND COSTES.validacion = 'total_peso'
      AND COSTES.zona = ZONA.valor
      AND UPPER(ORDENES.courier) = UPPER(COSTES.courier)
      AND ORDENES.total_peso > COSTES.valor_desde    --Si 0.250 Kg. son 1 Kg., lo ponemos extrictamente mayor que el mínimo para que coja no pase al siguiente escalón
      AND ORDENES.total_peso <= COSTES.valor_hasta   --Si 0.250 Kg. son 1 Kg., lo ponemos menor o igual que el máximo para que coja hacia abajo
      AND (
          (UPPER(ORDENES.dispositivo) IN ('SIM','DOCUMENTACION SMART TV') AND UPPER(COSTES.dispositivo) = 'SIM')
        OR (UPPER(ORDENES.dispositivo) IN ('ROUTER','STB') AND UPPER(COSTES.dispositivo) = 'ROUTER/STB')
        OR (UPPER(ORDENES.dispositivo) NOT IN ('SIM','ROUTER','STB','DOCUMENTACION SMART TV') AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO')
      )
--      AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL)  --GJV 2026/01/31
--      AND UPPER(ORDENES.retorno_contrato) = 'SI' --2026/02/17 --Solo aplicar si el pedido lleva retorno contrato
      AND (
        (UPPER(ORDENES.dispositivo) NOT IN ('DOCUMENTACION SMART TV') AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL) AND UPPER(ORDENES.retorno_contrato) = 'SI')
        OR (UPPER(ORDENES.dispositivo) IN ('DOCUMENTACION SMART TV'))
      )

    UNION ALL

    --26.-Coste por cancelacion después del picking
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp 
      ,  IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    WHERE ORDENES.estado_final IN ('Cancelado postpicking')
      AND COSTES.codigo_coste in ('L - CANCEL_PICK')
      AND UPPER(ORDENES.cancelacion_solicitada) = UPPER(COSTES.cancelacion_solicitada)

    UNION ALL
    
	--27.-Coste de transporte en una Devolucion al almacen con Correos
    SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
      , ROUND((COSTES.importe),6) AS coste_sin_imp
      , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp  
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal--, CONCEPTO.concepto
      , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
      INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--        ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
    WHERE UPPER(COSTES.codigo_coste) = 'L - TRANSP'
      AND ORDENES.estado_final IN ('Devuelto al almacen') 
      AND UPPER(ORDENES.courier) = 'CORREOS'
      AND UPPER(COSTES.courier)  = 'CORREOS'
      AND COSTES.estado = 'Devuelto'
--      AND COSTES.zona = ZONA.valor
--      AND ORDENES.total_peso > COSTES.valor_desde
--      AND ORDENES.total_peso <= COSTES.valor_hasta
--      AND CASE WHEN ORDENES.dispositivo IN ('ROUTER','ROUTER + SIM','STB','STB + SIM') THEN COSTES.dispositivo = 'ROUTER/STB'
--               WHEN ORDENES.dispositivo NOT IN ('ROUTER','ROUTER + SIM','STB','STB + SIM', 'SIM') THEN COSTES.dispositivo = 'DISPOSITIVO'
--               ELSE COSTES.dispositivo = 'NA' END
  )
);

  --Creacion tablas costes de desistimientos
CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_costs` AS(
--select 'DIRECT'||'_'||'202409'||'_'||row_number () over () as cost_id, *
SELECT 'INVERSA'||'_'||id_mes_actual||'_'||ROW_NUMBER () OVER () AS cost_id, *
--  , 'Calculado' as estado_facturacion
from (
  --01-1.-SEGURO transporte a todo riesgo por el valor de la mercancia -> Dispositivo y courier Correos
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
    , ROUND((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100),6) AS coste_sin_imp   
    , ROUND(((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje * IMPUESTOS.valor) / 100),6) AS coste_con_imp   
    , IMPUESTOS.valor as impuesto      
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
      AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      AND UPPER(ORDENES.courier) = UPPER(COSTES.courier)
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--      ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion NOT IN ('EXPEDITION_DISASTER','EXPEDITION_CREATED')  --No se paga seguro si termina en disaster, porque los costes los pagará Interbox. Tampoco si solo ha sido creado.
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final NOT IN ('Desastre','Sin estado en Kafka ni Orderbox','Recogida fallida')
    AND UPPER(ORDENES.dispositivo) <> 'SIM'
    AND (LINEAS.dispositivo NOT IN ('SIM') OR LINEAS.dispositivo IS NULL)
    AND UPPER(COSTES.codigo_coste) = 'L - SEGURO'
    AND UPPER(COSTES.tipo_pedido) = 'DESISTIMIENTO'

  UNION ALL

  --01-2.-SEGURO transporte a todo riesgo por el valor de la mercancia -> Dispositivo y courier Distinto de Correos
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
    , ROUND((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje / 100),6) AS coste_sin_imp   
    , ROUND(((LINEAS.precio_almacen_sin_imp * COSTES.porcentaje * IMPUESTOS.valor) / 100),6) AS coste_con_imp
    , IMPUESTOS.valor as impuesto      
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado, CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
      AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      AND COSTES.courier = CAST('%' AS STRING)
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--      ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion NOT IN ('EXPEDITION_DISASTER','EXPEDITION_CREATED')  --No se paga seguro si termina en disaster, porque los costes los pagará Interbox. Tampoco si solo ha sido creado.
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final NOT IN ('Desastre','Sin estado en Kafka ni Orderbox','Recogida fallida')
    AND UPPER(ORDENES.dispositivo) <> 'SIM'
    AND (LINEAS.dispositivo NOT IN ('SIM') OR LINEAS.dispositivo IS NULL)
    AND UPPER(COSTES.codigo_coste) = 'L - SEGURO'
    AND UPPER(COSTES.tipo_pedido) = 'DESISTIMIENTO'
    AND UPPER(ORDENES.courier) <> 'CORREOS'

  UNION ALL

  --02.-Costes verificacion
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste, ROUND(COSTES.importe,6) AS coste_sin_imp
--    , CASE WHEN IMPUESTOS.codigo_postal IS NOT NULL THEN ROUND((COSTES.importe  * IMPUESTOS.valor),6) ELSE ROUND((COSTES.importe * 1.21),6) END AS coste_con_imp   --HAY QUE MODIFICARLO PARA LEER EL VALOR 00 SEGÚN LA FECHA QUE CORRESPONDA
    , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
    , IMPUESTOS.valor as impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado, CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON COSTES.operador_logistico = ORDENES.operador_logistico 
      AND ORDENES.tipo_pedido = COSTES.tipo_pedido
      AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
      AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--      ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion NOT IN ('EXPEDITION_DISASTER','EXPEDITION_NOT_COLLECTED','EXPEDITION_CREATED')  --No se paga seguro si termina en disaster, porque los costes los pagará Interbox. Si no se recoge, tampoco se paga. Tampoco si solo ha sido creado.
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final NOT IN ('Desastre','Sin estado en Kafka ni Orderbox','Recogida fallida') 
    AND ORDENES.dispositivo <> 'SIM'
    AND COSTES.codigo_coste IN ('L - VERIFICACION')
    AND UPPER(COSTES.tipo_pedido) = 'DESISTIMIENTO'
    AND (
          ((ORDENES.courier NOT IN ('HL') OR ORDENES.courier IS NULL) AND COSTES.courier = '%')
       OR (ORDENES.courier IN ('HL') AND COSTES.courier = ORDENES.courier)
    )

UNION ALL

  --03.1.-TRANSP de CORREOS
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
    , ROUND(COSTES.importe,6) AS coste_sin_imp
--    , CASE WHEN IMPUESTOS.codigo_postal IS NOT NULL THEN ROUND((COSTES.importe  * IMPUESTOS.valor),6) ELSE ROUND((COSTES.importe * 1.21),6) END AS coste_con_imp     --HAY QUE MODIFICARLO PARA LEER EL VALOR 00 SEGÚN LA FECHA QUE CORRESPONDA
    , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
    , IMPUESTOS.valor as impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  ORDENES.operador_logistico = COSTES.operador_logistico
      AND ORDENES.tipo_pedido = COSTES.tipo_pedido
      AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
      AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--      ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
      ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion NOT IN ('EXPEDITION_DISASTER','EXPEDITION_NOT_COLLECTED','EXPEDITION_CREATED')  --No se paga seguro si termina en disaster, porque los costes los pagará Interbox. Si no se recoge, tampoco se paga
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final NOT IN ('Desastre','Sin estado en Kafka ni Orderbox','Recogida fallida') 
    AND ORDENES.dispositivo <> 'SIM'
    AND (LINEAS.dispositivo NOT IN ('SIM') OR LINEAS.dispositivo IS NULL)
    AND COSTES.codigo_coste = 'L - TRANSP'
    AND UPPER(COSTES.tipo_pedido) = 'DESISTIMIENTO'   
    AND UPPER(COSTES.courier) = upper(ORDENES.courier)
    AND (
             (LINEAS.dispositivo = 'SIM' AND UPPER(COSTES.dispositivo) = 'SIM')
          OR (LINEAS.dispositivo IN ('Router Fibra','Modem') AND UPPER(COSTES.dispositivo) = 'ROUTER/STB')
          OR (LINEAS.dispositivo NOT IN ('Router Fibra','Modem','SIM') AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO')
        )
    AND LINEAS.peso > COSTES.valor_desde AND LINEAS.peso <= COSTES.valor_hasta  --0,6 kg. marca como 1 kg.
    AND COSTES.zona = ZONA.valor  
    AND COSTES.validacion = 'total_peso'
    AND UPPER(ORDENES.courier) IN ('CORREOS')

  UNION ALL

  --03.2.-TRANSP de HL
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada --, COSTES.codigo_coste, COSTES.tipo_coste
    , 'L - DEVOLUCION' AS codigo_coste --, COSTES.codigo_coste
    , COSTES.tipo_coste
    , ROUND(COSTES.importe,6) AS coste_sin_imp
--    , CASE WHEN IMPUESTOS.codigo_postal IS NOT NULL THEN ROUND((COSTES.importe  * IMPUESTOS.valor),6) ELSE ROUND((COSTES.importe * 1.21),6) END AS coste_con_imp     --HAY QUE MODIFICARLO PARA LEER EL VALOR 00 SEGÚN LA FECHA QUE CORRESPONDA
    , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
    , IMPUESTOS.valor as impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  ORDENES.operador_logistico = COSTES.operador_logistico
      AND ORDENES.tipo_pedido = COSTES.tipo_pedido
      AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
      AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--      ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
      ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion NOT IN ('EXPEDITION_DISASTER','EXPEDITION_NOT_COLLECTED','EXPEDITION_CREATED')  --No se paga seguro si termina en disaster, porque los costes los pagará Interbox. Si no se recoge, tampoco se paga
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final NOT IN ('Desastre','Sin estado en Kafka ni Orderbox','Recogida fallida') 
    AND ORDENES.dispositivo <> 'SIM'
    AND (LINEAS.dispositivo NOT IN ('SIM') OR LINEAS.dispositivo IS NULL)
    AND COSTES.codigo_coste = 'L - TRANSP'
    AND UPPER(COSTES.tipo_pedido) = 'DESISTIMIENTO'   
    AND UPPER(COSTES.courier) = upper(ORDENES.courier)
    AND (
             (LINEAS.dispositivo = 'SIM' AND UPPER(COSTES.dispositivo) = 'SIM')
          OR (LINEAS.dispositivo IN ('Router Fibra','Modem') AND UPPER(COSTES.dispositivo) = 'ROUTER/STB')
          OR (LINEAS.dispositivo NOT IN ('Router Fibra','Modem','SIM') AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO')
        )
    AND COSTES.zona = ZONA.valor  
    AND COSTES.validacion = 'total_peso'
    AND UPPER(ORDENES.courier) IN ('HL')

  UNION ALL

  --03.3.-TRANSP distinto de CORREOS
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada --, COSTES.codigo_coste, COSTES.tipo_coste
    , 'L - DEVOLUCION' AS codigo_coste --, COSTES.codigo_coste
    , COSTES.tipo_coste
    , ROUND(COSTES.importe,6) AS coste_sin_imp
--    , CASE WHEN IMPUESTOS.codigo_postal IS NOT NULL THEN ROUND((COSTES.importe  * IMPUESTOS.valor),6) ELSE ROUND((COSTES.importe * 1.21),6) END AS coste_con_imp     --HAY QUE MODIFICARLO PARA LEER EL VALOR 00 SEGÚN LA FECHA QUE CORRESPONDA
    , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
    , IMPUESTOS.valor as impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  ORDENES.operador_logistico = COSTES.operador_logistico
      AND ORDENES.tipo_pedido = COSTES.tipo_pedido
      AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
      AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--      ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
      ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion NOT IN ('EXPEDITION_DISASTER','EXPEDITION_NOT_COLLECTED','EXPEDITION_CREATED')  --No se paga seguro si termina en disaster, porque los costes los pagará Interbox. Si no se recoge, tampoco se paga
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final NOT IN ('Desastre','Sin estado en Kafka ni Orderbox','Recogida fallida')
    AND ORDENES.dispositivo <> 'SIM'
    AND (LINEAS.dispositivo NOT IN ('SIM') OR LINEAS.dispositivo IS NULL)
    AND COSTES.codigo_coste = 'L - TRANSP'
    AND UPPER(COSTES.tipo_pedido) = 'DESISTIMIENTO'   
    AND UPPER(COSTES.courier) = '%'
/*
    AND (
             (LINEAS.dispositivo = 'SIM' AND UPPER(COSTES.dispositivo) = 'SIM')
          OR (LINEAS.dispositivo IN ('Router Fibra','Modem') AND UPPER(COSTES.dispositivo) = 'ROUTER/STB')
          OR (LINEAS.dispositivo NOT IN ('Router Fibra','Modem','SIM') AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO')
        )
*/
    AND LINEAS.peso > COSTES.valor_desde AND LINEAS.peso <= COSTES.valor_hasta  --0,6 kg. marca como 1 kg.
    AND COSTES.zona = ZONA.valor  
    AND COSTES.validacion = 'total_peso'
    AND (UPPER(ORDENES.courier) NOT IN ('CORREOS','HL') OR ORDENES.courier IS NULL)

UNION ALL

  --04.-TRANSP_KG_AD
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada --, COSTES.codigo_coste, COSTES.tipo_coste
    , 'L - DEVOLUCION' AS codigo_coste --, COSTES.codigo_coste
    , COSTES.tipo_coste
    , ROUND((COSTES.importe*(LINEAS.peso-2)),6) AS coste_sin_imp
    , ROUND((COSTES.importe*(LINEAS.peso-2))*IMPUESTOS.valor,6) AS coste_con_imp 
    , IMPUESTOS.valor as impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
      AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
--      ON  SUBSTR(ORDENES.codigo_postal,1,2) = IMPUESTOS.codigo_postal
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
      ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion NOT IN ('EXPEDITION_DISASTER','EXPEDITION_NOT_COLLECTED','EXPEDITION_CREATED')  --No se paga seguro si termina en disaster, porque los costes los pagará Interbox. Si no se recoge, tampoco se paga
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final NOT IN ('Desastre','Sin estado en Kafka ni Orderbox','Recogida fallida') 
    AND ORDENES.dispositivo <> 'SIM'
    AND (LINEAS.dispositivo NOT IN ('SIM') OR LINEAS.dispositivo IS NULL)
    AND UPPER(COSTES.tipo_pedido) = 'DESISTIMIENTO'   
    AND (
              (LINEAS.dispositivo = 'SIM' AND UPPER(COSTES.dispositivo) = 'SIM')
          OR (LINEAS.dispositivo IN ('Router Fibra','Modem') AND UPPER(COSTES.dispositivo) = 'ROUTER/STB')
          OR (LINEAS.dispositivo NOT IN ('Router Fibra','Modem','SIM') AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO')
        )
    AND COSTES.zona = ZONA.valor  
    AND COSTES.codigo_coste = 'L - TRANSP_KG_AD'
    AND COSTES.validacion = 'kilo_adicional'
    AND ORDENES.total_peso > 2
    AND UPPER(ORDENES.courier) NOT IN ('CORREOS','HL')
    AND UPPER(ORDENES.dispositivo) NOT IN ('SMART TV','SMART TV+DOCUMENTACION','SIM')

  UNION ALL

  /****************************************************************
  * HAY QUE RECUPERAR EL COSTE YA ABONADO, NO CALCULARLO DE NUEVO *
  ****************************************************************/
  
   --05.-Costes terminal 
  SELECT ORDENES.id_orden, ORDENES.rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada, CONCAT('X',SUBSTR(ABONADOS.codigo_coste,2,18)) AS codigo_coste, ABONADOS.tipo_coste AS tipo_coste
    , (ABONADOS.coste_sin_imp*-1) AS coste_sin_imp
    , (ABONADOS.coste_con_imp*-1) AS coste_con_imp
    , ABONADOS.impuesto AS impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , ABONADOS.numero_serie AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa` ORDENES   
--    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.v_desistimiento_estado` ESTADOS
    LEFT JOIN `mm-commissions-reporting.TEMP.desistimiento_estado` ESTADOS
      ON  ESTADOS.orderCrmId = CAST(ORDENES.id_orden AS STRING)
      AND ESTADOS.reexpedition = ORDENES.rexpedicion
      AND ESTADOS.rank = 1
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_costs` ABONADOS
      ON  ABONADOS.id_orden = CAST(ORDENES.pedido_padre AS STRING)
      AND ABONADOS.codigo_coste IN ('T - PAGO_INICIAL','T - CUOTAS','T - VALOR_RESIDUAL','T - SUBSIDIO')
  WHERE UPPER(ORDENES.tipo_pedido) = 'DESISTIMIENTO'
--    AND ORDENES.estado_final IN ('Cerrado') 
--    AND ESTADOS.accion IN ('EXPEDITION_ACCEPTED')  
    AND ORDENES.estado_final IS NOT NULL
    AND ORDENES.estado_final IN ('Abonado') 
    AND ORDENES.dispositivo <> 'SIM'
  ORDER BY 1

  --09.-TRANSP_ANOVO PENDIENTE DE CONSEGUIR ESTE ESTADO DE ENVIADO A ANOVO
  --10.-TRANSP_ANOVO_KG_AD PENDIENTE DE CONSEGUIR ESTE ESTADO DE ENVIADO A ANOVO
  )

);

  --Creacion tablas costes de SWAP
CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap_costs` AS(
  select 'SWAP'||'_'||id_mes_actual||'_'||ROW_NUMBER () OVER () AS cost_id, *
  from (
    --01.-TRANSP SWAP 
    SELECT ORDENES.id_orden, ORDENES.reexpedition AS rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada 
      , COSTES.codigo_coste AS codigo_coste
      , COSTES.tipo_coste
      , ROUND(COSTES.importe,6) AS coste_sin_imp
      , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` ORDENES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
        AND ORDENES.total_peso < COSTES.valor_hasta
        AND ORDENES.total_peso >= COSTES.valor_desde
        AND CASE WHEN UPPER(ORDENES.dispositivo) = 'SMART TV' THEN UPPER(ORDENES.dispositivo) = UPPER(COSTES.dispositivo) ELSE COSTES.dispositivo = 'DISPOSITIVO' END
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
        ON  ESTADOS.estado = ORDENES.estado_final
        AND UPPER(ESTADOS.tipo_pedido) = 'SWAP'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
    WHERE UPPER(ORDENES.tipo_pedido) = 'SWAP'
      AND ORDENES.estado_final IS NOT NULL
      --AND ORDENES.estado_final IN ('Entregado','No Entregado-Devuelto al Almacén') --,'Devuelto al almacen','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.dispositivo NOT IN ('SMART TV')
      AND ESTADOS.final = 'SI'
      AND ESTADOS.facturable = 'SI'
      AND COSTES.codigo_coste = 'L - TRANSP_SWAP'
      AND COSTES.zona = ZONA.valor  
      AND COSTES.validacion = 'total_peso'

    UNION ALL

  --01.2.-TRANSP SWAP KG. ADICIONAL
    SELECT ORDENES.id_orden, ORDENES.reexpedition AS rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada 
      , COSTES.codigo_coste AS codigo_coste
      , COSTES.tipo_coste
--      , ROUND(COSTES.importe,6) AS coste_sin_imp
--      , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
      , ROUND((COSTES.importe*(CEIL(ORDENES.total_peso-2))),6) AS coste_sin_imp  --CEIL REDONDEA AL ALZA, COMPROBAR QUE PASA CON ALGO QUE PESE UN NUMERO ENTERO MAYOR QUE 2
      , ROUND((COSTES.importe*(CEIL(ORDENES.total_peso-2)) * IMPUESTOS.valor),6) AS coste_con_imp 
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` ORDENES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
        AND UPPER(COSTES.dispositivo) = 'DISPOSITIVO'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
        ON  ESTADOS.estado = ORDENES.estado_final
        AND UPPER(ESTADOS.tipo_pedido) = 'SWAP'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
    WHERE UPPER(ORDENES.tipo_pedido) = 'SWAP'
      AND ORDENES.estado_final IS NOT NULL
      AND ORDENES.total_peso > 2
      AND ORDENES.dispositivo NOT IN ('SMART TV')
      --AND ORDENES.estado_final IN ('Entregado','No Entregado-Devuelto al Almacén') --,'Devuelto al almacen','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ESTADOS.final = 'SI'
      AND ESTADOS.facturable = 'SI'
      AND COSTES.codigo_coste = 'L - TRANSP_SWAP_KG_AD'
      AND COSTES.zona = ZONA.valor  
      AND COSTES.validacion = 'kilo_adicional'

    UNION ALL

    --01.3-TRANSP SWAP (SMART TV)
    SELECT ORDENES.id_orden, ORDENES.reexpedition AS rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada 
      , COSTES.codigo_coste AS codigo_coste
      , COSTES.tipo_coste
      , ROUND(COSTES.importe,6) AS coste_sin_imp
      , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` ORDENES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
        AND COSTES.dispositivo = 'SMART TV'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
        ON  ESTADOS.estado = ORDENES.estado_final
        AND UPPER(ESTADOS.tipo_pedido) = 'SWAP'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND UPPER(LINEAS.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        AND UPPER(LINEAS.dispositivo) IN ('SMART TV+DOCUMENTACION','SMART TV')
      INNER JOIN `mm-commissions-reporting.TEMP.10_gs_tamano_smart_tv` TAMANO
        ON  (TAMANO.id_modelo = LINEAS.id_modelo) -- OR TAMANO.id_modelo = LINEAS.codigo_modelo)
    WHERE UPPER(ORDENES.tipo_pedido) = 'SWAP'
      AND ORDENES.estado_final IS NOT NULL
      --AND ORDENES.estado_final IN ('Entregado','No Entregado-Devuelto al Almacén') --,'Devuelto al almacen','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND UPPER(ORDENES.dispositivo) IN ('SMART TV')
      AND ESTADOS.final = 'SI'
      AND ESTADOS.facturable = 'SI'
      AND COSTES.codigo_coste = 'L - TRANSP_SWAP'
      AND COSTES.zona = ZONA.valor  
      AND COSTES.validacion = 'tamano'
      AND TAMANO.tamano = COSTES.valor_desde

    UNION ALL

      --02.-DEVOLUCION RECOGIDA SWAP 
    SELECT ORDENES.id_orden, ORDENES.reexpedition AS rexpedicion, ORDENES.estado_final, ORDENES.cancelacion_solicitada
      , COSTES.codigo_coste AS codigo_coste
      , COSTES.tipo_coste
      , ROUND(COSTES.importe,6) AS coste_sin_imp
      , ROUND(COSTES.importe*IMPUESTOS.valor,6) AS coste_con_imp
      , IMPUESTOS.valor as impuesto
      , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
      , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
      , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal, ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
      , CAST(NULL AS STRING) AS numero_serie
      , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` ORDENES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
        ON  UPPER(ORDENES.operador_logistico) = UPPER(COSTES.operador_logistico)
        AND UPPER(ORDENES.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= COSTES.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= COSTES.fecha_hasta
        AND CASE WHEN UPPER(ORDENES.dispositivo) IN ('TV YOIGO','SMART TV') THEN UPPER(COSTES.dispositivo) = 'SMART TV'
                 WHEN UPPER(ORDENES.dispositivo) IN ('ACCESORIO','ACCESORIES','MODEM','ROUTER','TABLET','TERMINAL','PAE','MAE','GAE') THEN UPPER(COSTES.dispositivo) = '%'        
            ELSE UPPER(COSTES.dispositivo) = '%' END
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
        ON  AGRUPACION.canal = ORDENES.canal
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
        AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
        ON  ESTADOS.estado = ORDENES.estado_final
        AND UPPER(ESTADOS.tipo_pedido) = 'SWAP'
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
    WHERE UPPER(ORDENES.tipo_pedido) = 'SWAP'
      AND ORDENES.estado_final IS NOT NULL
      --AND ORDENES.estado_final IN ('Entregado','No Entregado-Devuelto al Almacén') --,'Devuelto al almacen','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ESTADOS.final = 'SI'
      AND ESTADOS.facturable = 'SI'
      AND COSTES.codigo_coste = 'L - RECOGIDA'
      AND UPPER(COSTES.tipo_pedido) = 'SWAP'

  UNION ALL

    --03.-Costes preparacion del pedido
  SELECT PEDIDO.id_orden AS id_orden, PEDIDO.reexpedition AS rexpedicion, PEDIDO.estado_final, PEDIDO.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
    , ROUND((COSTES.importe),6) AS coste_sin_imp
    , ROUND((COSTES.importe * IMPUESTOS.valor),6) AS coste_con_imp
    , IMPUESTOS.valor as impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, PEDIDO.canal
    , PEDIDO.marca, PEDIDO.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, PEDIDO.dispositivo

  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` PEDIDO
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  UPPER(COSTES.operador_logistico) = UPPER(PEDIDO.operador_logistico)
      AND UPPER(COSTES.tipo_pedido) = UPPER(PEDIDO.tipo_pedido)
      AND CAST(PEDIDO.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      AND CASE WHEN UPPER(PEDIDO.dispositivo) IN ('ACCESORIO','ACCESORIES','MODEM','ROUTER','TABLET','TERMINAL') THEN UPPER(COSTES.dispositivo) = 'DISPOSITIVO'
                WHEN UPPER(PEDIDO.dispositivo) IN ('PAE') THEN UPPER(COSTES.dispositivo) = 'PAE'
                WHEN UPPER(PEDIDO.dispositivo) IN ('MAE') THEN UPPER(COSTES.dispositivo) = 'MAE'
                WHEN UPPER(PEDIDO.dispositivo) IN ('TV YOIGO','SMART TV') THEN UPPER(COSTES.dispositivo) = 'SMART TV'
                ELSE UPPER(COSTES.dispositivo) = 'DISPOSITIVO' END
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = PEDIDO.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
      ON  COALESCE(SUBSTR(PEDIDO.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(PEDIDO.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
      ON  ESTADOS.estado = PEDIDO.estado_final
      AND UPPER(ESTADOS.tipo_pedido) = 'SWAP'

    WHERE UPPER(COSTES.codigo_coste) IN ('L - PREPA_PEDIDO')
      AND UPPER(PEDIDO.tipo_pedido) = 'SWAP'
      AND PEDIDO.estado_final IS NOT NULL
      AND PEDIDO.estado_final NOT IN ('Anulado pre-picking','Desastre')
      AND ESTADOS.final = 'SI'
      AND ESTADOS.facturable = 'SI'
      AND (numero_expedicion IS NOT NULL AND direccion IS NOT NULL)  --GJV 2026/01/31

  UNION ALL

  --04.-SEGURO transporte a todo riesgo
  SELECT ORDENES.id_orden AS id_orden, ORDENES.reexpedition AS rexpedicion, ORDENES.estado_final
    , ORDENES.cancelacion_solicitada, COSTES.codigo_coste, COSTES.tipo_coste
    , ROUND((COALESCE(STOCK_IB.Precio_mk_up,0) * COSTES.porcentaje / 100),6) AS coste_sin_imp
    , ROUND(((COALESCE(STOCK_IB.Precio_mk_up,0)) * COSTES.porcentaje / 100) * IMPUESTOS.valor,6) AS coste_con_imp
    , IMPUESTOS.valor as impuesto
    , 'calculado' as estado, CAST(DATE_TRUNC(fecha_estado_final, MONTH) AS DATE) as mes_liquidado
    , CAST(CONCAT(SUBSTRING(CAST(fecha_estado_final AS STRING),1,4),SUBSTRING(CAST(fecha_estado_final AS STRING),6,2)) AS INT64) as id_mes
    , AGRUPACION.agrupacion as agrupacion_canal, ORDENES.canal
    , ORDENES.marca, ORDENES.tipo_pedido as tipo_pedido
    , CAST(NULL AS STRING) AS numero_serie
    , codigo_contrato, posicion_cm, texto_sap, ORDENES.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap` ORDENES
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES
      ON  UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
      AND UPPER(COSTES.tipo_pedido) = 'SWAP'
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN COSTES.fecha_desde AND COSTES.fecha_hasta
      AND COSTES.courier = CAST('%' AS STRING)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap_line` LINE
      ON  LINE.id_orden = ORDENES.id_orden
      AND LINE.reexpedicion = ORDENES.reexpedition
      AND LINE.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.LISTA_IMEIS_MODELOS` LINEAS
      ON  LINEAS.numero_serie = LINE.numero_serie
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_agrupacion_canal` AGRUPACION
      ON  AGRUPACION.canal = ORDENES.canal
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
      ON  COALESCE(SUBSTR(ORDENES.codigo_postal,1,2),'28') = IMPUESTOS.codigo_postal
      AND CAST(ORDENES.fecha_estado_final AS DATE) BETWEEN IMPUESTOS.fecha_desde AND IMPUESTOS.fecha_hasta
    LEFT JOIN `mm-commissions-reporting.TEMP.stock_Interbox` STOCK_IB
      ON  STOCK_IB.Codigo = LINEAS.id_modelo
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
      ON  ESTADOS.estado = ORDENES.estado_final
      AND UPPER(ESTADOS.tipo_pedido) = 'SWAP'
  WHERE UPPER(COSTES.codigo_coste) = 'L - SEGURO'
      AND UPPER(ORDENES.tipo_pedido) = 'SWAP'
      --AND ORDENES.estado_final IN ('Entregado','No Entregado-Devuelto al Almacén') --,'Devuelto al almacen','Entregado (Documentacion KO)','Entregado (Documentacion OK)')
      AND ORDENES.estado_final IS NOT NULL
      AND ESTADOS.final = 'SI'
      AND ESTADOS.facturable = 'SI'
  )
);


  --Creacion tablas costes de DEVOLUCION
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_devol_costs` AS(
--   select 'DEVOL'||'_'||id_mes_actual||'_'||ROW_NUMBER () OVER () AS cost_id, *
--   from (

--   )
-- );

  --Creacion costes por gestión de los Jiras, para retroceder lo ya facturado en las transacciones
CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_jira_costs` AS 
(
  SELECT CONCAT(CONCAT(PPR.jira_asociado,'_'),TRA.commission_id) AS cost_id
      , CAST(TRA.order_id AS INT64) AS id_orden
      , TRA.reexpedicion AS reexpedition
      , PPR.estado_final AS estado_final  --revisar, no da datos
      , ORD.cancelacion_solicitada AS cancelacion_solicitada
      , TRA.concepto AS codigo_coste
      , TRA.tipo_concepto AS tipo_coste
      , (-1*TRA.coste_sin_impuestos) AS coste_sin_imp
      , (-1*TRA.coste_con_impuestos) AS coste_con_imp
      , TRA.impuesto AS impuesto
      , 'calculado' AS estado
      , DATE_TRUNC((CURRENT_DATE()-30), MONTH) AS mes_liquidado 
      , CAST(CONCAT(EXTRACT(YEAR FROM (CURRENT_DATE()-30)), EXTRACT(MONTH FROM (CURRENT_DATE()-30))) AS INT64) AS id_mes  
      , TRA.agrupacion_canal AS agrupacion_canal
      , TRA.canal AS canal
      , TRA.marca AS marca
      , TRA.order_type AS tipo_pedido
      , TRA.serial_number AS numero_serie
      , 'Pendiente' AS codigo_contrato, 'Pendiente' AS posicion_cm, 'Pendiente' AS texto_sap, 'Pendiente' AS dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.transacciones_cd` TRA
    INNER JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` PPR
      ON  CAST(PPR.id_orden AS STRING) = TRA.order_id 
      AND PPR.tipo_pedido = TRA.order_type
      AND PPR.reexpedicion = TRA.reexpedicion
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORD
      ON CAST(PPR.id_orden AS STRING) = TRA.order_id
      AND ORD.reexpedicion = TRA.reexpedicion
      AND ORD.tipo_pedido = TRA.order_type

  WHERE NOT EXISTS (  --Comprobamos que no hayamos incluido ya el negativo. Lo hacemos con el Jira, por si hay un segundo Jira para el mismo pedido
      SELECT 1 
      FROM `mm-commissions-reporting.COSTES_LOGISTICOS.transacciones_cd` TCD
      WHERE TCD.commission_id = CONCAT(CONCAT(PPR.jira_asociado,'_'),TRA.commission_id)
    )
    AND NOT EXISTS (  --Eliminamos que el negativo se vuelva a incluir en positivo
      SELECT 1 
      FROM `mm-commissions-reporting.COSTES_LOGISTICOS.transacciones_cd` TCD
      WHERE TCD.commission_id = SUBSTR(TRA.commission_id,10,50)
    )
);


  --Crear tabla de costes de LOGISTICA
  CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` AS
  (
    SELECT COSTES.*
      --cost_id, CAST(id_orden AS INT64) AS id_orden, COSTES.* EXCEPT (cost_id,id_orden)
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_costs` COSTES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
        ON  UPPER(ESTADOS.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND UPPER(ESTADOS.estado) = UPPER(COSTES.estado_final)
--    WHERE ESTADOS.final = 'SI' AND ESTADOS.facturable = 'SI'

    UNION ALL

    SELECT COSTES.*
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_inversa_costs` COSTES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
        ON  UPPER(ESTADOS.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND UPPER(ESTADOS.estado) = UPPER(COSTES.estado_final)
--    WHERE ESTADOS.final = 'SI' AND ESTADOS.facturable = 'SI'

    UNION ALL

    SELECT COSTES.cost_id, CAST(COSTES.id_orden AS STRING), COSTES.* EXCEPT (cost_id, id_orden)
      --COSTES.*
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_swap_costs` COSTES
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` ESTADOS
        ON  UPPER(ESTADOS.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND UPPER(ESTADOS.estado) = UPPER(COSTES.estado_final)
--    WHERE ESTADOS.final = 'SI' AND ESTADOS.facturable = 'SI'

    UNION ALL

    SELECT COSTES.cost_id, CAST(COSTES.id_orden AS STRING), COSTES.* EXCEPT (cost_id, id_orden)
    --COSTES.*
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_jira_costs` COSTES

  );

END