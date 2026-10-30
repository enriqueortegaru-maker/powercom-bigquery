BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_aggregate_invoice`();

   --Crea listado completo de costes logísticos acumulado
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.42_logistic_invoice` AS(
 SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
      , CONCAT(SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),1,4),SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),6,2)) AS id_mes
      , ORDENES.marca AS MARCA
      , 'B2C' AS TARIFA_APLICADA
      , CASE WHEN ORDENES.dispositivo = 'DOCUMENTACION SMART TV' THEN ORDENES.pedido_padre ELSE ORDENES.id_orden END AS Order_No  --feb/25 En caso de documentación de SMART TV les ponemos el pedido_padre
      , CAST(NULL AS STRING) AS TIPO_DE_ENTRADA
      , LINEAS.MSISDN AS MSISDN
      , LINEAS.numero_serie AS Imei_Icc
      , ORDENES.id_orden AS Item_number
      , LINEAS.id_modelo AS Articulo
      , LINEAS.descripcion_modelo AS Modelo
      , ORDENES.courier AS Courier  --16723243 ¿GLS ES ASM CENTRAL?  REVISAR TAMBIÉN SERVICIO
      , ORDENES.provincia AS Provincia
      , ORDENES.direccion AS Direccion
      , CASE WHEN ORDENES.tipo_pedido = 'Entrega' THEN ORDENES.estado_reexpedicion
             WHEN ORDENES.tipo_pedido = 'Desistimiento' THEN ORDENES.estado_final
             ELSE 'Revisar estado' END AS Estado
      , ORDENES.fecha_estado_final AS Fecha_estado
      , 'DIRECTO' AS Canal
      , ORDENES.id_cliente AS Cliente
      , ORDENES.documento AS DNI
      , ORDENES.telefono_contacto AS Tfno
      , ORDENES.importe_pedido AS IMPORTE
      , CASE WHEN LINEAS.pago_inicial IS NULL THEN 0 ELSE LINEAS.pago_inicial END AS Pago_inicial
      , 'SIN REEMBOLSO' AS Forma_pago
      , (ORDENES.importe_pedido * IMPUESTOS.valor) AS Precio_Impto_Incl  
      , 'TBD' AS Fact_cliente_final
      , 'TBD' AS Alb_de_envio
      , 'TBD' AS Alb_de_abono
      , 'N' AS Tipo_pedido_N
      , 'TBD' AS Pedido_Plataf
      , ORDENES.numero_expedicion Pedido_Eurolog
      , 'PEDIDO' AS Tipo_Pedido
      , ORDENES.fecha_comunicacion AS Fecha_Pedido
      , CASE WHEN ZONA.valor = 'D' THEN '31' ELSE 'TBD_30_3000' END AS Almacen
--      , ORDENES.numero_lineas AS Bultos
      , 'TBD' AS Bultos
      , ORDENES.numero_lineas AS Unidades
      , CASE WHEN TERM.Term IS NOT NULL THEN TERM.Term ELSE 0 END AS Term
      , CASE WHEN Sim.Sim IS NOT NULL THEN Sim.Sim ELSE 0 END AS Sim
      , CASE WHEN Pae.Pae IS NOT NULL THEN Pae.Pae ELSE 0 END AS Pae
      , CASE WHEN TV.TV IS NOT NULL THEN TV.TV ELSE 0 END AS TV
      , 'TBD' AS Plv
      , 'TBD' AS Referencias
      , ORDENES.total_impresos AS Impresos
      , ORDENES.total_preimpresos AS Preimpresos
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
      , CASE WHEN ORDENES.identificacion IN ('Exclusiva (+ entrega segura + FOTODNI)','Exclusiva (+ FOTODNI)') THEN 'DNI Verif.' ELSE CAST(NULL AS STRING) END AS Foto_Dni
      , ORDENES.numero_lineas AS Unid_Fact
      , CASE WHEN Coste_prep.Coste_prep IS NOT NULL THEN Coste_prep.Coste_prep ELSE 0 END AS Coste_prep
--      , 'TBD' AS Unidades_adic
      , CASE WHEN Coste_prep_sim_adic.Coste_prep IS NOT NULL AND Coste_prep_sim_adic.Coste_prep > 0 THEN CAST((Coste_prep_sim_adic.Coste_prep/0.16) AS INT64) ELSE CAST(0 AS INT64) END AS Unidades_adic
--      , CASE WHEN ORDENES.numero_lineas > 1 THEN (ORDENES.numero_lineas-1) ELSE 0 END AS Sim_adic
      , CASE WHEN Coste_prep_sim_adic.Coste_prep IS NOT NULL THEN Coste_prep_sim_adic.Coste_prep ELSE 0 END AS Sim_adic
      , CASE WHEN Costes_Impresos.Costes_Impresos IS NOT NULL THEN Costes_Impresos.Costes_Impresos ELSE 0 END AS Costes_Impresos
      , CASE WHEN Costes_Preimpresos.Costes_Preimpresos IS NOT NULL THEN Costes_Preimpresos.Costes_Preimpresos ELSE 0 END AS Costes_Preimpresos
      , CASE WHEN Coste_Cancelacion_post.Coste_Cancelacion_post IS NOT NULL THEN Coste_Cancelacion_post.Coste_Cancelacion_post ELSE 0 END AS Coste_Cancelacion_post
      , CAST(NULL AS STRING) AS Palets_Manip
      , CAST(NULL AS STRING) AS Palets_sin_Manip
      , CASE WHEN Total_Coste_Manipul.Total_Coste_Manipul IS NOT NULL THEN Total_Coste_Manipul.Total_Coste_Manipul ELSE 0 END AS Total_Coste_Manipul
      , CASE WHEN Coste_Devo_Contrato.Coste_Devo_Contrato IS NOT NULL THEN Coste_Devo_Contrato.Coste_Devo_Contrato ELSE 0 END AS Coste_Devo_Contrato
      , CASE WHEN Coste_Seguro_de_tte.Coste_Seguro_de_tte IS NOT NULL THEN Coste_Seguro_de_tte.Coste_Seguro_de_tte ELSE 0 END AS Coste_Seguro_de_tte
      , CASE WHEN Coste_Foto_DNI.Coste_Foto_DNI IS NOT NULL THEN Coste_Foto_DNI.Coste_Foto_DNI ELSE 0 END AS Coste_Foto_DNI
      , CASE WHEN Coste_Entrega_Exclusiva.Coste_Entrega_Exclusiva IS NOT NULL THEN Coste_Entrega_Exclusiva.Coste_Entrega_Exclusiva ELSE 0 END AS Coste_Entrega_Exclusiva
      , 0 AS Coste_Appointment
      , CASE WHEN Coste_Transp.Coste_Transp IS NOT NULL THEN Coste_Transp.Coste_Transp ELSE 0 END AS Coste_Transp
      , CASE WHEN Coste_Correos.Coste_Correos IS NOT NULL THEN Coste_Correos.Coste_Correos ELSE 0 END AS Coste_Correos
      , 0 AS Coste_Swaps
      , CASE WHEN Coste_Dua.Coste_Dua IS NOT NULL THEN Coste_Dua.Coste_Dua ELSE 0 END AS Coste_Dua
      , 0 AS Coste_Contrareembolso
      , CASE WHEN Coste_DESTRUCCION.Coste_DESTRUCCION IS NOT NULL THEN Coste_DESTRUCCION.Coste_DESTRUCCION ELSE 0 END AS Coste_DESTRUCCION
      , 0 AS Coste_DEVOLUCION_RECOG
      , CASE WHEN Coste_Cancelacion.Coste_Cancelacion IS NOT NULL THEN Coste_Cancelacion.Coste_Cancelacion ELSE 0 END AS Coste_Cancelacion
      , 0 AS Coste_Recanalizacion
      , 0 AS Coste_extras
      , CASE WHEN Total_Coste_Transporte.Total_Coste_Transporte IS NOT NULL THEN Total_Coste_Transporte.Total_Coste_Transporte ELSE 0 END AS Total_Coste_Transporte
      , 0 AS EXCESO_CORREOS_HL
      , CASE WHEN Total_Coste_Manipul.Total_Coste_Manipul IS NOT NULL AND Total_Coste_Transporte.Total_Coste_Transporte IS NOT NULL THEN (Total_Coste_Manipul.Total_Coste_Manipul+Total_Coste_Transporte.Total_Coste_Transporte) 
             WHEN Total_Coste_Manipul.Total_Coste_Manipul IS NULL AND Total_Coste_Transporte.Total_Coste_Transporte IS NOT NULL THEN Total_Coste_Transporte.Total_Coste_Transporte
             WHEN Total_Coste_Manipul.Total_Coste_Manipul IS NOT NULL AND Total_Coste_Transporte.Total_Coste_Transporte IS NULL THEN Total_Coste_Manipul.Total_Coste_Manipul
          ELSE 0 END AS Total_Coste_Man_y_Trans
      , 'S' AS Final
      , ORDENES.tipo_pedido AS Tipo_evento_logistico
      , (select case when max(numero_serie) is null then 'MO' else 'FMC' end from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE where LINEAS.id_orden = ORDENES.id_orden and LINE.reexpedicion = ORDENES.reexpedicion and LINE.dispositivo in ('STB','ROUTER')) as pedido_MO_FMC
         
  FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
      AND LINEAS.reexpedicion = ORDENES.reexpedicion
      AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
      ON  CASE WHEN ORDENES.tipo_pedido = 'Entrega' THEN gef.estado = ORDENES.estado_reexpedicion
               WHEN ORDENES.tipo_pedido = 'Desistimiento' THEN gef.estado = ORDENES.estado_final
          END
      AND UPPER(gef.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
      ON  IMPUESTOS.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND IMPUESTOS.fecha_desde BETWEEN CAST(ORDENES.fecha_estado_final AS DATE) AND CAST(ORDENES.fecha_estado_final AS DATE)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
      ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
        --Cruzamos con tablas temporales
    LEFT JOIN `mm-commissions-reporting.TEMP.Term_counter` TERM
      ON  TERM.id_orden = ORDENES.id_orden 
      AND TERM.reexpedicion = ORDENES.reexpedicion
    LEFT JOIN `mm-commissions-reporting.TEMP.SIM_counter` Sim
      ON  Sim.id_orden = ORDENES.id_orden 
      AND Sim.reexpedicion = ORDENES.reexpedicion
    LEFT JOIN `mm-commissions-reporting.TEMP.Pae_counter` Pae
      ON  Pae.id_orden = ORDENES.id_orden 
      AND Pae.reexpedicion = ORDENES.reexpedicion
    LEFT JOIN `mm-commissions-reporting.TEMP.TV_counter` TV
      ON  TV.id_orden = ORDENES.id_orden 
      AND TV.reexpedicion = ORDENES.reexpedicion
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_prep` Coste_prep
      ON  Coste_prep.id_orden = ORDENES.id_orden 
      AND Coste_prep.reexpedition = ORDENES.reexpedicion
      AND Coste_prep.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_prep_sim_adic` Coste_prep_sim_adic
      ON  Coste_prep_sim_adic.id_orden = ORDENES.id_orden 
      AND Coste_prep_sim_adic.reexpedition = ORDENES.reexpedicion
      AND Coste_prep_sim_adic.tipo_pedido = ORDENES.tipo_pedido    
    LEFT JOIN `mm-commissions-reporting.TEMP.Costes_Impresos` Costes_Impresos
      ON  Costes_Impresos.id_orden = ORDENES.id_orden 
      AND Costes_Impresos.reexpedition = ORDENES.reexpedicion
      AND Costes_Impresos.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Costes_Preimpresos` Costes_Preimpresos
      ON  Costes_Preimpresos.id_orden = ORDENES.id_orden 
      AND Costes_Preimpresos.reexpedition = ORDENES.reexpedicion   
      AND Costes_Preimpresos.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Cancelacion_post` Coste_Cancelacion_post
      ON  Coste_Cancelacion_post.id_orden = ORDENES.id_orden 
      AND Coste_Cancelacion_post.reexpedition = ORDENES.reexpedicion
      AND Coste_Cancelacion_post.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Total_Coste_Manipul` Total_Coste_Manipul
      ON  Total_Coste_Manipul.id_orden = ORDENES.id_orden 
      AND Total_Coste_Manipul.reexpedition = ORDENES.reexpedicion
      AND Total_Coste_Manipul.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Devo_Contrato` Coste_Devo_Contrato
      ON  Coste_Devo_Contrato.id_orden = ORDENES.id_orden 
      AND Coste_Devo_Contrato.reexpedition = ORDENES.reexpedicion
      AND Coste_prep_sim_adic.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Seguro_de_tte` Coste_Seguro_de_tte
      ON  Coste_Seguro_de_tte.id_orden = ORDENES.id_orden 
      AND Coste_Seguro_de_tte.reexpedition = ORDENES.reexpedicion
      AND Coste_Seguro_de_tte.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Foto_DNI` Coste_Foto_DNI
      ON  Coste_Foto_DNI.id_orden = ORDENES.id_orden 
      AND Coste_Foto_DNI.reexpedition = ORDENES.reexpedicion
      AND Coste_Foto_DNI.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Entrega_Exclusiva` Coste_Entrega_Exclusiva
      ON  Coste_Entrega_Exclusiva.id_orden = ORDENES.id_orden 
      AND Coste_Entrega_Exclusiva.reexpedition = ORDENES.reexpedicion
      AND Coste_Entrega_Exclusiva.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Transp` Coste_Transp
      ON  Coste_Transp.id_orden = ORDENES.id_orden 
      AND Coste_Transp.reexpedition = ORDENES.reexpedicion
      AND Coste_Transp.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Correos` Coste_Correos
      ON  Coste_Correos.id_orden = ORDENES.id_orden 
      AND Coste_Correos.reexpedition = ORDENES.reexpedicion
      AND Coste_Correos.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Dua` Coste_Dua
      ON  Coste_Dua.id_orden = ORDENES.id_orden 
      AND Coste_Dua.reexpedition = ORDENES.reexpedicion
      AND Coste_Dua.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_DESTRUCCION` Coste_DESTRUCCION
      ON  Coste_DESTRUCCION.id_orden = ORDENES.id_orden 
      AND Coste_DESTRUCCION.reexpedition = ORDENES.reexpedicion
      AND Coste_DESTRUCCION.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Coste_Cancelacion` Coste_Cancelacion
      ON  Coste_Cancelacion.id_orden = ORDENES.id_orden 
      AND Coste_Cancelacion.reexpedition = ORDENES.reexpedicion
      AND Coste_Cancelacion.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.Total_Coste_Transporte` Total_Coste_Transporte
      ON  Total_Coste_Transporte.id_orden = ORDENES.id_orden 
      AND Total_Coste_Transporte.reexpedition = ORDENES.reexpedicion
      AND Total_Coste_Transporte.tipo_pedido = ORDENES.tipo_pedido

  WHERE gef.final = 'SI'
    AND gef.facturable = 'SI'
);

    --Crea listado completo de costes terminales
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.42_logistic_invoice_devices` AS(
  SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
      , (select max(COST.id_mes) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.reexpedition = ORDENES.reexpedicion) AS id_mes
      , ORDENES.marca AS MARCA
      , CASE WHEN ZONA.valor = 'D' THEN 'CANARIAS' ELSE 'PENINSULA' END AS Almacen
      , LINEAS.id_modelo AS Referencia
      , LINEAS.descripcion_modelo AS Descripcion
      , ORDENES.fecha_estado_final AS Fecha
      , 'Pendiente_Eurologistica' AS N_pedido
      , ORDENES.id_orden AS S_pedido
      , 1 AS Cantidad
      , (select round(sum(COST.coste_sin_imp),2) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.numero_serie = LINEAS.numero_serie and COST.reexpedition = ORDENES.reexpedicion and upper(COST.codigo_coste) in ('T - PAGO_INICIAL','T - CUOTAS','T - VALOR_RESIDUAL','T - SUBSIDIO')) AS Total
      , (select round(sum(COST.coste_con_imp),2) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.numero_serie = LINEAS.numero_serie and COST.reexpedition = ORDENES.reexpedicion and upper(COST.codigo_coste) in ('T - PAGO_INICIAL','T - CUOTAS','T - VALOR_RESIDUAL','T - SUBSIDIO')) AS TOTAL_CON_IMPTO  
      , ORDENES.documento AS CIF
      , LINEAS.numero_serie AS N_Serie
      , 'TBD' AS N_Factura
      , 'S' AS Estado_final
      , ORDENES.tipo_pedido AS Tipo_evento_logistico
      , (select case when max(numero_serie) is null then 'MO' else 'FMC' end from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE where LINE.id_orden = ORDENES.id_orden and LINE.reexpedicion = ORDENES.reexpedicion and LINE.dispositivo in ('STB','ROUTER')) as pedido_MO_FMC
            
  FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
      AND LINEAS.reexpedicion = ORDENES.reexpedicion
      AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
      ON  gef.estado = ORDENES.estado_final
      AND UPPER(gef.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
      ON  IMPUESTOS.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND IMPUESTOS.fecha_desde <= CAST(ORDENES.fecha_estado_final AS DATE)
      AND IMPUESTOS.fecha_hasta >= CAST(ORDENES.fecha_estado_final AS DATE)
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
      ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
      AND CAST(ORDENES.fecha_comunicacion AS DATE) >= ZONA.fecha_desde
      AND CAST(ORDENES.fecha_comunicacion AS DATE) <= ZONA.fecha_hasta

  WHERE gef.final = 'SI'
    AND (LINEAS.dispositivo NOT IN ('STB','ROUTER','SIM') OR LINEAS.dispositivo IS NULL)   --Cambio mientras resolvemos el problema con LINEAS.dispositivo
);

    --Crea listado completo de costes dispositivos propiedad de XFERA
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.42_logistic_invoice_xfera` AS(
  SELECT *
  FROM (
    SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
        , (select max(COST.id_mes) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.reexpedition = ORDENES.reexpedicion) AS id_mes
        , ORDENES.marca AS MARCA
        , '0269898' AS Codigo
        , 'MASMOVIL BROADBAND S.A.' AS Nombre
        , CASE WHEN ZONA.valor = 'D' THEN 'CANARIAS' ELSE 'PENINSULA' END AS Almacen
        , LINEAS.id_modelo AS Referencia
        , LINEAS.descripcion_modelo AS Descripcion
        , 'TBD' AS N_albaran
        , ORDENES.fecha_estado_final AS Fecha
      , 'Pendiente_Eurologistica' AS N_pedido
        , CONCAT(CONCAT(ORDENES.id_orden,'-'),ORDENES.reexpedicion) AS S_pedido
        , 1 AS Cantidad

            --***********************************************************************************************************************
            --*  HAY QUE CAMBIAR LOS MARK-UPS POR EL PARÁMETRO DE `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_markups` MARKUP *
            --***********************************************************************************************************************

        , CASE WHEN UPPER(MASTER.subfamily) = 'STB' THEN ROUND((MASTER.inwarehouse_price * 1.0168),2)  --Precio markup Interbox para tipo STBs
               WHEN UPPER(MASTER.subfamily) LIKE '%ROUTER%' THEN ROUND((MASTER.inwarehouse_price * 1.0202),2)  --Precio markup Interbox para tipo Router
               WHEN MASTER.subfamily = 'COMPLEMENTOS' THEN ROUND((MASTER.inwarehouse_price * 1.0146),2)  ----Precio markup Interbox para tipo Hotspot
               ELSE ROUND((MASTER.inwarehouse_price * 1.0165),2)
          END AS Total

        , 'A87297354' AS CIF
        , LINEAS.numero_serie AS N_Serie
        , 'S' AS Estado_final
        , ORDENES.id_cliente AS Cliente
        , ORDENES.documento AS DNI
        , LINEAS.MSISDN AS Telefono
        , ORDENES.tipo_pedido AS Tipo_evento_logistico
        , (select case when max(numero_serie) is null then 'MO' else 'FMC' end from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE where LINE.id_orden = ORDENES.id_orden and LINE.reexpedicion = ORDENES.reexpedicion and LINE.dispositivo in ('STB','ROUTER')) as pedido_MO_FMC
              
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
      LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINEAS
        ON  LINEAS.id_orden = ORDENES.id_orden
        AND LINEAS.reexpedicion = ORDENES.reexpedicion
        AND LINEAS.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_estado_final` gef
      ON  CASE WHEN ORDENES.tipo_pedido = 'Entrega' THEN gef.estado = ORDENES.estado_reexpedicion
               WHEN ORDENES.tipo_pedido = 'Desistimiento' THEN gef.estado = ORDENES.estado_final
          END
      AND UPPER(gef.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_impuestos` IMPUESTOS
        ON  IMPUESTOS.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND IMPUESTOS.fecha_desde <= CAST(ORDENES.fecha_estado_final AS DATE)
        AND IMPUESTOS.fecha_hasta >= CAST(ORDENES.fecha_estado_final AS DATE)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) >= ZONA.fecha_desde
        AND CAST(ORDENES.fecha_comunicacion AS DATE) <= ZONA.fecha_hasta
      LEFT JOIN `mm-datamart-kd.LOGISTICS.log_maestro` MASTER --Tomo los precios del maestro de logistica en lugar de nuestra GS
        ON  MASTER.reference = LINEAS.id_modelo
  
    WHERE gef.final = 'SI'
      AND LINEAS.dispositivo IN ('STB','ROUTER')
      AND gef.entregado = 'SI'
      AND LINEAS.id_modelo NOT IN (select gcf.referencia from `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_router_cliente_final` gcf)  --Si está en la lista de routers de cliente, no se incluye en esta factura.
  )
  WHERE id_mes IS NOT NULL
);

END