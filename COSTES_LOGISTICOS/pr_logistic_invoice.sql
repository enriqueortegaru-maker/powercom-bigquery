BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_invoice`();

DECLARE mes_actual_ini DATE;
DECLARE mes_actual_fin DATE;
DECLARE mes_anterior_ini DATE;
DECLARE mes_anterior_fin DATE;
DECLARE id_mes_actual INT64;
DECLARE id_mes_anterior INT64;

SET mes_actual_ini   = DATE_TRUNC(CURRENT_DATE(), MONTH);
SET mes_actual_fin   = LAST_DAY(CURRENT_DATE(), MONTH);
SET mes_anterior_ini = DATE_TRUNC((DATE_TRUNC(CURRENT_DATE(), MONTH)-1), MONTH);
SET mes_anterior_fin = LAST_DAY((DATE_TRUNC(CURRENT_DATE(), MONTH)-1), MONTH);
SET id_mes_actual    = CAST(CONCAT(SUBSTR(CAST(mes_actual_ini AS STRING),1,4),SUBSTR(CAST(mes_actual_ini AS STRING),6,2)) AS INT64);
SET id_mes_anterior  = CAST(CONCAT(SUBSTR(CAST(mes_anterior_ini AS STRING),1,4),SUBSTR(CAST(mes_anterior_ini AS STRING),6,2)) AS INT64);

--Generamos las tablas temporales en el MAIN
--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_temp`();

    --Crea factura costes logísticos del mes pasado (mes completo)
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_complete` AS(
 SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
      , CONCAT(SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),1,4),SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),6,2)) AS id_mes
      , ORDENES.marca AS MARCA
      , 'B2C' AS TARIFA_APLICADA
      , CASE WHEN ORDENES.dispositivo = 'DOCUMENTACION SMART TV' THEN CAST(ORDENES.pedido_padre AS STRING) ELSE ORDENES.id_orden END AS Order_No
      , CAST(NULL AS STRING) AS TIPO_DE_ENTRADA
      , COALESCE(LINEAS.MSISDN,ORDENES.telefono_contacto) AS MSISDN
      , LINEAS.numero_serie AS Imei_Icc
      , ORDENES.id_orden AS Item_number
      , LINEAS.id_modelo AS Articulo
      --, LINEAS.descripcion_modelo AS Modelo
      , REPLACE(REPLACE(LINEAS.descripcion_modelo,","," "),";"," ") AS Modelo
      , ORDENES.courier AS Courier 
      --, ORDENES.provincia AS Provincia
      , REPLACE(REPLACE(ORDENES.Provincia,","," "),";"," ") AS Provincia
      --, ORDENES.direccion AS Direccion
      , REGEXP_REPLACE(REPLACE(REPLACE(ORDENES.direccion,","," "),";"," "), r'[\r\n]', ' ')  as Direccion
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
      --, CASE WHEN ZONA.valor = 'D' THEN '31' ELSE 'TBD_30_3000' END AS Almacen
      , CASE WHEN ZONA.valor = 'D' THEN '31' ELSE NULL END AS Almacen
      , ORDENES.numero_lineas AS Bultos
      --, ORDENES.numero_lineas AS Unidades
      , CASE WHEN ORDENES.numero_lineas > 0 THEN ORDENES.numero_lineas 
             ELSE COALESCE((CONTA_TMP.Term + CONTA_TMP.Sim + CONTA_TMP.Pae + CONTA_TMP.Patin + CONTA_TMP.TV + CONTA_TMP.Plv),0)
             END AS Unidades
      , CONTADORES.Term AS Term
      , CONTADORES.Sim AS Sim
      , CONTADORES.Pae AS Pae
      , CONTADORES.Patin AS Patin
      , CONTADORES.TV AS TV
--      , CONTADORES.Plv AS Plv 
      , CASE WHEN ORDENES.dispositivo = 'DOCUMENTACION SMART TV' THEN 1 ELSE CONTADORES.Plv END AS Plv
--      , CAST(NULL AS STRING) AS Referencias
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
      , ROUND(ORDENES.total_peso,3) AS Kilos
      , ORDENES.retorno_contrato AS DAC
      , CASE WHEN ORDENES.identificacion IN ('Exclusiva (+ entrega segura + FOTODNI)','Exclusiva (+ FOTODNI)','Exclusiva') THEN 'DNI Verif.' ELSE CAST(NULL AS STRING) END AS Foto_Dni
--      , ORDENES.numero_lineas AS Unid_Fact 
      , CASE WHEN ORDENES.numero_lineas > 0 THEN ORDENES.numero_lineas 
             ELSE COALESCE((CONTA_TMP.Term + CONTA_TMP.Sim + CONTA_TMP.Pae + CONTA_TMP.Patin + CONTA_TMP.TV + CONTA_TMP.Plv),0)
             END AS Unid_Fact
      , CONTADORES.Coste_prep AS Coste_prep
      , CONTADORES.Unidades_adic AS Unidades_adic
      , CONTADORES.Sim_adic AS Sim_adic
      , CONTADORES.Costes_Impresos AS Costes_Impresos
      , CONTADORES.Costes_Preimpresos AS Costes_Preimpresos
      , CONTADORES.Coste_Cancelacion_post AS Coste_Cancelacion_post
      , COALESCE(CONTADORES.Palets_Manip,'0') AS Palets_Manip 
      , COALESCE(CONTADORES.Palets_sin_Manip,'0') AS Palets_sin_Manip
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
--      , CASE WHEN ORDENES.dispositivo IN ('ROUTER','STB','ONT') THEN 'Fijo' ELSE 'Movil' END AS Tipo_equipo
      , TIPO.Tipo_equipo AS Tipo_equipo
      , ORDENES.reexpedicion
         
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
        --Cruzamos con tablas temporales
    LEFT JOIN `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica` CONTADORES
      ON  CONTADORES.id_orden = ORDENES.id_orden 
      AND CONTADORES.reexpedicion = ORDENES.reexpedicion
      AND CONTADORES.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.kafka_nombre` NOMBRE
      ON  NOMBRE.documento = ORDENES.documento
    LEFT JOIN `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica_Tmp` CONTA_TMP
      ON  CONTA_TMP.id_orden = ORDENES.id_orden 
      AND CONTA_TMP.reexpedicion = ORDENES.reexpedicion
      AND CONTA_TMP.tipo_pedido = ORDENES.tipo_pedido

  WHERE gef.final = 'SI'
    AND gef.facturable = 'SI'
    AND ORDENES.estado_final NOT IN ('MULTISIM')
    --AND ORDENES.fecha_estado_final BETWEEN mes_anterior_ini AND mes_anterior_fin
    AND ORDENES.fecha_estado_final BETWEEN '2026-05-01' AND '2026-05-31'
    AND CONTADORES.Total_Coste_Man_y_Trans NOT IN (0.0)  --Eliminamos los que son 0€ en total, para que no generen factura los MULTISIM y otros sin costes.
    AND ORDENES.id_orden NOT IN ('18571553','18574176','18608978','18618432','18664815','18666981','18650743','18664872','18665379','18674806','18673877','18684176','18677753','18656664','18665684','18701291','18697299','18702235','18688139','18709210','18708074','18710279','18707757','18719871','18719133','18717353','18719605','18715707','18714008','18725157','18717025','18720951','18721421','18725018','18739514','18732069','18726223','18714304','18740486','18745461','18742596','18746399','18732305','18745170','18750626','18752604','18752282','18746943','18745839','18745844','18748699','18755589','18760721','18720840','18759019','18736086','18744165','18755375','18773818','18773033','18761810','18764411','18773141','18769591','18761823','18769334','18740388','18715923','18718245','18775536','18775566','18756130','18773137','18780241','18761143','18761944','18776677','18747373','18778208','18780022','18773813','18760154','18776687','18784566','18784162','18784210','18791682','18776770','18789885','18794116','18794274','18794218','18775426','18769681','18782415','18772386','18779005','18799577','18799215','18775241','18797416','18803204','18794078','18803852','18796785','18768686','18799492','18801662','18800386','18774358','18809709','18792700','18692012','18815307','18812342','18805569','18814216','18808489','18810618','18806313','18760844','18814658','18770515','18808143','18824479','18820011','18812986','18818874','18817909','18827775','18828614','18826199','18818914','18811466','18762577','18773477','18818596','18659784','18827757','18776872','18781670','18769053','18810555','18836259','18831088','18807823','18752321','18826802','18842458','18800154','18772009','18837569','18840525','18819933','18843232','18805227','18816673','18841953','18856428','18759664','18804201','18855187','18777098','18775811','18853587','18867984','18861784','18862126','18753218','18864145','18855781','18784216','18856943','18844942','18861368','18860233','18866360','18756272','18830196','18872549','18790735','18859024','18873198','18868777','18869650','18867837','18875030','18869191','18864541','18864937','18865763','18869737','18860073','18872438','18880368','18875818','18864434','18793309','18871604','18887990','18826949','18888898','18887943','18810356','18888246','18877608','18886480','18887817','18819401','18739281','18877419','18830124','18800621','18836922','18896816','18898014','18886987','18886351','18892766','18884956','18876835','18892534','18896764','18849342','18882390','18830820','18902345','18804713','18900520','18902667','18901450','18928138','18909594','18938584','18894099','18894105','18850869','18901067','18761802','18826200','18830891','18952213','18884237','18837851','18904252','18650772','18822358','18856202','18792089','18826522','18835839','18893762','18856666','18892717','18812688','18884757','18890764','18846282','18893481','18901663','18792303','18894821','18897066','18902367','18843959','18884376','18724914','18876032','18902489','18898010','18902498')
)
;

/*
    --Crea factura costes terminales del mes pasado (mes completo)
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_devices_complete` AS(
  SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
        , (select max(COST.id_mes) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.reexpedition = ORDENES.reexpedicion) AS id_mes
      , ORDENES.marca AS MARCA
      , CASE WHEN ZONA.valor = 'D' THEN 'CANARIAS' ELSE 'PENINSULA' END AS Almacen
      , LINEAS.id_modelo AS Referencia
      , LINEAS.descripcion_modelo AS Descripcion
      , ORDENES.fecha_estado_final AS Fecha
      --, 'Pendiente_Eurologistica' AS N_pedido
      , ORDENES.numero_expedicion AS N_pedido
      , ORDENES.id_orden AS S_pedido
      , 1 AS Cantidad
      , (select round(sum(COST.coste_sin_imp),2) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden
          and UPPER(COST.tipo_coste) NOT IN ('LOGISTICO') and COST.numero_serie = LINEAS.numero_serie and COST.reexpedition = ORDENES.reexpedicion
        ) AS Total
      , (select round(sum(COST.coste_con_imp),2) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden
          and UPPER(COST.tipo_coste) NOT IN ('LOGISTICO') and COST.numero_serie = LINEAS.numero_serie and COST.reexpedition = ORDENES.reexpedicion
        ) AS TOTAL_CON_IMPTO  
      , ORDENES.documento AS CIF
      , LINEAS.numero_serie AS N_Serie
      --, 'TBD' AS N_Factura
      , CAST (NULL AS STRING) AS N_Factura
      , 'S' AS Estado_final
      , ORDENES.tipo_pedido AS Tipo_evento_logistico
      , (select case when max(numero_serie) is null then 'MO' else 'FMC' end from `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINE where LINE.id_orden = ORDENES.id_orden and LINE.reexpedicion = ORDENES.reexpedicion and LINE.dispositivo in ('STB','ROUTER')) as pedido_MO_FMC
      , ORDENES.reexpedicion
            
  FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` ORDENES
    LEFT JOIN `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` LINEAS
      ON  LINEAS.id_orden = ORDENES.id_orden
      AND CASE WHEN ORDENES.tipo_pedido = 'Entrega' THEN LINEAS.reexpedicion = ORDENES.reexpedicion 
               WHEN ORDENES.tipo_pedido = 'Desistimiento' THEN LINEAS.reexpedicion IS NULL
          END
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
    LEFT JOIN `mm-commissions-reporting.TEMP.kafka_nombre` NOMBRE
      ON  NOMBRE.documento = ORDENES.documento

  WHERE gef.final = 'SI'
    AND ((ORDENES.tipo_pedido = 'Entrega' and gef.entregado = 'SI') OR (ORDENES.tipo_pedido = 'Desistimiento' AND ORDENES.estado_final IN ('Abonado')))
    AND (LINEAS.dispositivo NOT IN ('STB','ROUTER','SIM') OR LINEAS.dispositivo IS NULL)   --Cambio mientras resolvemos el problema con LINEAS.dispositivo
    AND (ORDENES.dispositivo NOT IN ('SIM','DOCUMENTACION SMART TV','ROUTER FIBRA','STB') OR ORDENES.dispositivo IS NULL)
    AND ORDENES.fecha_estado_final BETWEEN mes_anterior_ini AND mes_anterior_fin

  
);

    --Crea factura costes dispositivos propiedad de XFERA del mes pasado (mes completo)
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_xfera_complete` AS(
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
        --, 'TBD' AS N_albaran
        , CAST (NULL AS STRING) AS N_albaran
        , ORDENES.fecha_estado_final AS Fecha
        --, 'Pendiente_Eurologistica' AS N_pedido
        , ORDENES.numero_expedicion AS N_pedido
        , CONCAT(CONCAT(ORDENES.id_orden,'-'),ORDENES.reexpedicion) AS S_pedido
        , 1 AS Cantidad

            --  HAY QUE CAMBIAR LOS MARK-UPS POR EL PARÁMETRO DE `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_markups` MARKUP 

        , CASE WHEN UPPER(MASTER.subfamily) = 'STB' THEN ROUND((MASTER.inwarehouse_price * 1.0168),2)  --Precio markup Interbox para tipo STBs
               WHEN UPPER(MASTER.subfamily) LIKE '%ROUTER%' THEN ROUND((MASTER.inwarehouse_price * 1.0202),2)  --Precio markup Interbox para tipo Router
               WHEN MASTER.subfamily = 'COMPLEMENTOS' THEN ROUND((MASTER.inwarehouse_price * 1.0146),2)  ----Precio markup Interbox para tipo Hotspot
               ELSE ROUND((MASTER.inwarehouse_price * 1.0165),2)
          END AS Total
        , 'A87297354' AS CIF
        , LINEAS.numero_serie AS N_Serie
        , 'S' AS Estado_final
        , ORDENES.id_cliente AS Cliente
        , NOMBRE.nombre_completo AS Nombre_envio
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
    LEFT JOIN `mm-commissions-reporting.TEMP.kafka_nombre` NOMBRE
      ON  NOMBRE.documento = ORDENES.documento
  
    WHERE gef.final = 'SI'
      AND LINEAS.dispositivo IN ('STB','ROUTER')
      AND ((ORDENES.tipo_pedido = 'Entrega' and gef.entregado = 'SI') OR (ORDENES.tipo_pedido = 'Desistimiento'))
      AND LINEAS.id_modelo NOT IN (select gcf.referencia from `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_router_cliente_final` gcf)  --Si está en la lista de routers de cliente, no se incluye en esta factura.
      AND ORDENES.fecha_estado_final BETWEEN mes_anterior_ini AND mes_anterior_fin

  )
  WHERE id_mes IS NOT NULL
);
*/


    --Crea factura costes logísticos del mes en curso (simulación para seguimiento del mes actual)
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.41_logistic_invoice_current_month` AS(
 SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
      , CONCAT(SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),1,4),SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),6,2)) AS id_mes
      , ORDENES.marca AS MARCA
      , 'B2C' AS TARIFA_APLICADA
      , CASE WHEN ORDENES.dispositivo = 'DOCUMENTACION SMART TV' THEN CAST(ORDENES.pedido_padre AS STRING) ELSE ORDENES.id_orden END AS Order_No  --feb/25 En caso de documentación de SMART TV les ponemos el pedido_padre
      , CAST(NULL AS STRING) AS TIPO_DE_ENTRADA
      , COALESCE(LINEAS.MSISDN,ORDENES.telefono_contacto) AS MSISDN
      , LINEAS.numero_serie AS Imei_Icc
      , ORDENES.id_orden AS Item_number
      , LINEAS.id_modelo AS Articulo
      --, LINEAS.descripcion_modelo AS Modelo
      , REPLACE(REPLACE(LINEAS.descripcion_modelo,","," "),";"," ") AS Modelo
      , ORDENES.courier AS Courier  --16723243 ¿GLS ES ASM CENTRAL?  REVISAR TAMBIÉN SERVICIO
      --, ORDENES.provincia AS Provincia
      , REPLACE(REPLACE(ORDENES.Provincia,","," "),";"," ") AS Provincia
      --, ORDENES.direccion AS Direccion
      , REGEXP_REPLACE(REPLACE(REPLACE(ORDENES.direccion,","," "),";"," "), r'[\r\n]', ' ')  as Direccion
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
      --, 'TBD' AS Fact_cliente_final
      , CAST(NULL AS STRING) AS Fact_cliente_final
      --, 'TBD' AS Alb_de_envio
      , CAST(NULL AS STRING) AS Alb_de_envio
      --, 'TBD' AS Alb_de_abono
      , CAST(NULL AS STRING) AS Alb_de_abono
      , 'N' AS Tipo_pedido_N
      --, 'TBD' AS Pedido_Plataf
      , CAST(NULL AS STRING) AS Pedido_Plataf
      , ORDENES.numero_expedicion Pedido_Eurolog
      , ORDENES.tipo_pedido AS Tipo_Pedido
      , FORMAT_DATE("%d/%m/%Y", ORDENES.fecha_comunicacion) AS Fecha_Pedido
      --, CASE WHEN ZONA.valor = 'D' THEN '31' ELSE 'TBD_30_3000' END AS Almacen
      , CASE WHEN ZONA.valor = 'D' THEN '31' ELSE NULL END AS Almacen
      --, 'TBD' AS Bultos
      , CAST(NULL AS STRING) AS Bultos
--      , ORDENES.numero_lineas AS Unidades
      , CASE  WHEN ORDENES.numero_lineas > 0 THEN ORDENES.numero_lineas 
        ELSE COALESCE((CONTA_TMP.Term + CONTA_TMP.Sim + CONTA_TMP.Pae + CONTA_TMP.Patin + CONTA_TMP.TV + CONTA_TMP.Plv),0)
        END AS Unidades
      , CONTADORES.Term AS Term
      , CONTADORES.Sim AS Sim
      , CONTADORES.Pae AS Pae
      , CONTADORES.Patin AS Patin
      , CONTADORES.TV AS TV
--      , 'TBD' AS Plv
      , CONTADORES.Plv AS Plv 
      --, 'TBD' AS Referencias
      , CAST(NULL AS STRING) AS Referencias
      --, ORDENES.total_impresos AS Impresos
      --, ORDENES.total_preimpresos AS Preimpresos
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
      , ROUND(ORDENES.total_peso,3) AS Kilos
      , ORDENES.retorno_contrato AS DAC
      , CASE WHEN ORDENES.identificacion IN ('Exclusiva (+ entrega segura + FOTODNI)','Exclusiva (+ FOTODNI)','Exclusiva') THEN 'DNI Verif.' ELSE CAST(NULL AS STRING) END AS Foto_Dni
--      , ORDENES.numero_lineas AS Unid_Fact
      , CASE WHEN ORDENES.numero_lineas > 0 THEN ORDENES.numero_lineas 
             ELSE COALESCE((CONTA_TMP.Term + CONTA_TMP.Sim + CONTA_TMP.Pae + CONTA_TMP.Patin + CONTA_TMP.TV + CONTA_TMP.Plv),0)
             END AS Unid_Fact
      , CONTADORES.Coste_prep AS Coste_prep
      , CONTADORES.Unidades_adic AS Unidades_adic
      , CONTADORES.Sim_adic AS Sim_adic
      , CONTADORES.Costes_Impresos AS Costes_Impresos
      , CONTADORES.Costes_Preimpresos AS Costes_Preimpresos
      , CONTADORES.Coste_Cancelacion_post AS Coste_Cancelacion_post
      , COALESCE(CONTADORES.Palets_Manip,'0') AS Palets_Manip 
      , COALESCE(CONTADORES.Palets_sin_Manip,'0') AS Palets_sin_Manip
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
      --, CASE WHEN ORDENES.dispositivo IN ('ROUTER','STB','ONT') THEN 'Fijo' ELSE 'Movil' END AS Tipo_equipo
      , TIPO.Tipo_equipo AS Tipo_equipo
         
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
        --Cruzamos con tablas temporales
    LEFT JOIN `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica` CONTADORES
      ON  CONTADORES.id_orden = ORDENES.id_orden 
      --AND CONTADORES.reexpedicion = ORDENES.reexpedicion
      AND CONTADORES.tipo_pedido = ORDENES.tipo_pedido
    LEFT JOIN `mm-commissions-reporting.TEMP.kafka_nombre` NOMBRE
      ON  NOMBRE.documento = ORDENES.documento
    LEFT JOIN `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica_Tmp` CONTA_TMP
      ON  CONTA_TMP.id_orden = ORDENES.id_orden 
      AND CONTA_TMP.reexpedicion = ORDENES.reexpedicion
      AND CONTA_TMP.tipo_pedido = ORDENES.tipo_pedido

  WHERE gef.final = 'SI'
    AND gef.facturable = 'SI'
    AND ORDENES.estado_final NOT IN ('MULTISIM')
    AND ORDENES.fecha_estado_final BETWEEN mes_actual_ini AND mes_actual_fin
    AND CONTADORES.Total_Coste_Man_y_Trans NOT IN (0.0)  --Eliminamos los que son 0€ en total, para que no generen factura los MULTISIM y otros sin costes.
);


/*
    --Crea factura costes terminales del mes en curso (simulación para seguimiento del mes actual)
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.41_logistic_invoice_devices_current_month` AS(
  SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
      , (select max(COST.id_mes) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.reexpedition = ORDENES.reexpedicion) AS id_mes
      , ORDENES.marca AS MARCA
      , CASE WHEN ZONA.valor = 'D' THEN 'CANARIAS' ELSE 'PENINSULA' END AS Almacen
      , LINEAS.id_modelo AS Referencia
      , LINEAS.descripcion_modelo AS Descripcion
      , ORDENES.fecha_estado_final AS Fecha
      --, 'Pendiente_Eurologistica' AS N_pedido
      , ORDENES.numero_expedicion AS N_pedido
      , ORDENES.id_orden AS S_pedido
      , 1 AS Cantidad
      , (select round(sum(COST.coste_sin_imp),2) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.numero_serie = LINEAS.numero_serie and COST.reexpedition = ORDENES.reexpedicion and upper(COST.codigo_coste) in ('T - PAGO_INICIAL','T - CUOTAS','T - VALOR_RESIDUAL','T - SUBSIDIO')) AS Total
      , (select round(sum(COST.coste_con_imp),2) from `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COST where COST.id_orden = ORDENES.id_orden and COST.numero_serie = LINEAS.numero_serie and COST.reexpedition = ORDENES.reexpedicion and upper(COST.codigo_coste) in ('T - PAGO_INICIAL','T - CUOTAS','T - VALOR_RESIDUAL','T - SUBSIDIO')) AS TOTAL_CON_IMPTO  
      , ORDENES.documento AS CIF
      , LINEAS.numero_serie AS N_Serie
      --, 'TBD' AS N_Factura
      , CAST(NULL AS STRING) AS N_Factura
      , 'S' AS Estado_final
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

  WHERE gef.final = 'SI'
--    AND LINEAS.dispositivo NOT IN ('STB','ROUTER','SIM')
--    AND gef.entregado = 'SI'
    AND (LINEAS.dispositivo NOT IN ('STB','ROUTER','SIM') OR LINEAS.dispositivo IS NULL)   --Cambio mientras resolvemos el problema con LINEAS.dispositivo
    AND ORDENES.fecha_estado_final BETWEEN mes_actual_ini AND mes_actual_fin

  -- FALTA METER LOS ROUTERs/STBs ÇUE SÍ PAGA EL CLIENTE FINAL 
);

    --Crea factura costes dispositivos propiedad de XFERA del mes en curso (simulación para seguimiento del mes actual)
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.41_logistic_invoice_xfera_current_month` AS(
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
        --, 'TBD' AS N_albaran
        , CAST(NULL AS STRING) AS N_albaran
        , ORDENES.fecha_estado_final AS Fecha
        --, 'Pendiente_Eurologistica' AS N_pedido
        , ORDENES.numero_expedicion AS N_pedido
        , CONCAT(CONCAT(ORDENES.id_orden,'-'),ORDENES.reexpedicion) AS S_pedido
        , 1 AS Cantidad

            --  HAY QUE CAMBIAR LOS MARK-UPS POR EL PARÁMETRO DE `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_markups` MARKUP 

        , CASE WHEN UPPER(MASTER.subfamily) = 'STB' THEN ROUND((MASTER.inwarehouse_price * 1.0168),2)  --Precio markup Interbox para tipo STBs
               WHEN UPPER(MASTER.subfamily) LIKE '%ROUTER%' THEN ROUND((MASTER.inwarehouse_price * 1.0202),2)  --Precio markup Interbox para tipo Router
               WHEN MASTER.subfamily = 'COMPLEMENTOS' THEN ROUND((MASTER.inwarehouse_price * 1.0146),2)  ----Precio markup Interbox para tipo Hotspot
               ELSE ROUND((MASTER.inwarehouse_price * 1.0165),2)
          END AS Total

        , 'A87297354' AS CIF
        , LINEAS.numero_serie AS N_Serie
        , 'S' AS Estado_final
        , ORDENES.id_cliente AS Cliente
        , NOMBRE.nombre_completo AS Nombre_envio
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
      LEFT JOIN `mm-commissions-reporting.TEMP.kafka_nombre` NOMBRE
        ON  NOMBRE.documento = ORDENES.documento
  
    WHERE gef.final = 'SI'
      AND LINEAS.dispositivo IN ('STB','ROUTER')
      AND gef.entregado = 'SI'
      AND LINEAS.id_modelo NOT IN (select gcf.referencia from `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_router_cliente_final` gcf)  --Si está en la lista de routers de cliente, no se incluye en esta factura.
      AND ORDENES.fecha_estado_final BETWEEN mes_actual_ini AND mes_actual_fin
  )
  WHERE id_mes IS NOT NULL
);
*/


     -----------------------------------------------------------
     -- MOVEMOS LA FACTURA HISTÓRICA PARA CREARLA MENSUALMENTE--
     -----------------------------------------------------------
/*
   --Crea listado completo de costes logísticos acumulado
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.42_logistic_invoice` AS(
 SELECT SUBSTR(CAST(DATE_TRUNC(ORDENES.fecha_estado_final, MONTH) AS STRING),1,10) AS mes_estado_final
      , CONCAT(SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),1,4),SUBSTR(CAST(ORDENES.fecha_estado_final AS STRING),6,2)) AS id_mes
      , ORDENES.marca AS MARCA
      , 'B2C' AS TARIFA_APLICADA
      , CASE WHEN ORDENES.dispositivo = 'DOCUMENTACION SMART TV' THEN ORDENES.pedido_padre ELSE ORDENES.id_orden END AS Order_No  --feb/25 En caso de documentación de SMART TV les ponemos el pedido_padre
      , CAST(NULL AS STRING) AS TIPO_DE_ENTRADA
      , COALESCE(LINEAS.MSISDN,ORDENES.telefono_contacto) AS MSISDN
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
      , ORDENES.numero_lineas AS Bultos
--      , 'TBD' AS Bultos
      , ORDENES.numero_lineas AS Unidades
--      , CASE WHEN TERM.Term IS NOT NULL THEN TERM.Term ELSE 0 END AS Term
      , CONTADORES.Term AS Term
--      , CASE WHEN Sim.Sim IS NOT NULL THEN Sim.Sim ELSE 0 END AS Sim
      , CONTADORES.Sim AS Sim
--      , CASE WHEN Pae.Pae IS NOT NULL THEN Pae.Pae ELSE 0 END AS Pae
      , CONTADORES.Pae AS Pae
--      , CASE WHEN TV.TV IS NOT NULL THEN TV.TV ELSE 0 END AS TV
      , CONTADORES.TV AS TV
--      , 'TBD' AS Plv
      , CONTADORES.Plv AS Plv 
      , 'TBD' AS Referencias
      --, ORDENES.total_impresos AS Impresos
      --, ORDENES.total_preimpresos AS Preimpresos
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
      , ROUND(ORDENES.total_peso,3) AS Kilos
      , ORDENES.retorno_contrato AS DAC
      , CASE WHEN ORDENES.identificacion IN ('Exclusiva (+ entrega segura + FOTODNI)','Exclusiva (+ FOTODNI)') THEN 'DNI Verif.' ELSE CAST(NULL AS STRING) END AS Foto_Dni
      , ORDENES.numero_lineas AS Unid_Fact    
      , CONTADORES.Coste_prep AS Coste_prep
      , CONTADORES.Unidades_adic AS Unidades_adic
      , CONTADORES.Sim_adic AS Sim_adic
      , CONTADORES.Costes_Impresos AS Costes_Impresos
      , CONTADORES.Costes_Preimpresos AS Costes_Preimpresos
      , CONTADORES.Coste_Cancelacion_post AS Coste_Cancelacion_post
      , COALESCE(CONTADORES.Palets_Manip,'0') AS Palets_Manip 
      , COALESCE(CONTADORES.Palets_sin_Manip,'0') AS Palets_sin_Manip
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
    LEFT JOIN `mm-commissions-reporting.TEMP.Contadores_Factura_Logistica` CONTADORES
      ON  CONTADORES.id_orden = ORDENES.id_orden 
      AND CONTADORES.reexpedicion = ORDENES.reexpedicion
      AND CONTADORES.tipo_pedido = ORDENES.tipo_pedido

  WHERE gef.final = 'SI'
    AND gef.facturable = 'SI'
    AND ORDENES.estado_final NOT IN ('MULTISIM')
    AND CONTADORES.Total_Coste_Man_y_Trans NOT IN (0.0)  --Eliminamos los que son 0€ en total, para que no generen factura los MULTISIM y otros sin costes.
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
      --, 'Pendiente_Eurologistica' AS N_pedido
      , ORDENES.numero_expedicion AS N_pedido
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
        --, 'Pendiente_Eurologistica' AS N_pedido
        , ORDENES.numero_expedicion AS N_pedido
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
*/

/*
CREATE OR REPLACE TABLE `mm-commissions-reporting.COSTES_LOGISTICOS.42_devices_invoice_last_month_controlling` AS(
  SELECT idc.*
    , CASE WHEN UPPER(dbe.segment_ds) = 'RESIDENCIAL' THEN 'residencial'
          WHEN UPPER(dbe.segment_ds) = 'SOHO' THEN 'soho'
          WHEN UPPER(dbe.segment_ds) = 'BUSINESS' THEN 'business'
          ELSE dbe.segment_ds END AS segmento
    , CASE WHEN dbe.sell_terminal_origin_ds = 'RENUEVO' THEN 'renuevo' ELSE 'captacion' END AS tipo_orden
    , CASE WHEN dbe.financed_total_amount > 0                                                             THEN 'pago financiado'
          WHEN dbe.financed_total_amount = 0 AND dbe.not_financed_price > 0                              THEN 'pago unico'
          WHEN dbe.financed_total_amount = 0 AND dbe.not_financed_price = 0 AND dbe.gross_subsidy_1 <> 0 THEN 'pago subsidiado'
          WHEN dbe.financed_total_amount = 0 AND dbe.not_financed_price = 0 AND dbe.gross_subsidy_1 = 0  THEN 'gratis'
          ELSE 'revisar tipo de pago' END AS tipo_pago
    , ROUND(dbe.cost_price,2) AS coste_total, dbe.not_financed_price AS pago_inicial, dbe.financed_total_amount AS pago_financiado, dbe.gross_subsidy_1 AS subsidio

  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_devices_complete`  idc
    LEFT JOIN `mm-datamart-kd.SERVICES.devices_base_emysim` dbe
      ON  dbe.serial_number = idc.N_Serie
      AND CAST(dbe.item_number AS STRING) = idc.S_pedido
  WHERE idc.Tipo_evento_logistico = 'Entrega'

  UNION ALL

  SELECT idc.*
    , CASE WHEN UPPER(dbe.segment_ds) = 'RESIDENCIAL' THEN 'residencial'
          WHEN UPPER(dbe.segment_ds) = 'SOHO' THEN 'soho'
          WHEN UPPER(dbe.segment_ds) = 'BUSINESS' THEN 'business'
          ELSE dbe.segment_ds END AS segmento
    , CASE WHEN dbe.sell_terminal_origin_ds = 'RENUEVO' THEN 'renuevo' ELSE 'captacion' END AS tipo_orden
    , CASE WHEN dbe.financed_total_amount > 0                                                             THEN 'pago financiado'
          WHEN dbe.financed_total_amount = 0 AND dbe.not_financed_price > 0                              THEN 'pago unico'
          WHEN dbe.financed_total_amount = 0 AND dbe.not_financed_price = 0 AND dbe.gross_subsidy_1 <> 0 THEN 'pago subsidiado'
          WHEN dbe.financed_total_amount = 0 AND dbe.not_financed_price = 0 AND dbe.gross_subsidy_1 = 0  THEN 'gratis'
          ELSE 'revisar tipo de pago' END AS tipo_pago
    , ROUND(dbe.cost_price,2) AS coste_total, dbe.not_financed_price AS pago_inicial, dbe.financed_total_amount AS pago_financiado, dbe.gross_subsidy_1 AS subsidio

  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_devices_complete`  idc
    LEFT JOIN(
      SELECT N_Serie, S_pedido, CIF
      FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_devices_complete`  idc
      WHERE Tipo_evento_logistico = 'Entrega'
      GROUP BY ALL
    ) lista
      ON  lista.N_Serie = idc.N_Serie
      AND lista.CIF = idc.CIF
    LEFT JOIN `mm-datamart-kd.SERVICES.devices_base_emysim` dbe
      ON  dbe.serial_number = idc.N_Serie
--      AND dbe.item_number = idc.S_pedido
  WHERE idc.Tipo_evento_logistico = 'Desistimiento'
    AND lista.S_pedido = CAST(dbe.item_number AS STRING)

);
*/

  --Informe para Qiero
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.43_logistic_costs_quiero` AS(
  SELECT * EXCEPT (pep, cuenta)
    , CASE WHEN tipo_pedido IN ('ENTREGA') AND tipo_equipo IN ('Movil')      THEN 'A/LLM_LG_DIR_MOV_MM'
          WHEN tipo_pedido IN ('ENTREGA') AND tipo_equipo IN ('Fijo')        THEN 'A/LLM_LG_DIR_FIJO_MM'
          WHEN tipo_pedido IN ('DESISTIMIENTO','SWAP') AND tipo_equipo IN ('Movil') THEN 'A/LLM_LG_INV_MOV_MM'
          WHEN tipo_pedido IN ('DESISTIMIENTO','SWAP') AND tipo_equipo IN ('Fijo')  THEN 'A/LLM_LG_INV_FIJO_MM'
      ELSE pep END AS pep
    , CASE WHEN tipo_pedido IN ('ENTREGA') AND tipo_equipo IN ('Movil')      THEN 'Costs to Acquire & Retain'
          WHEN tipo_pedido IN ('ENTREGA') AND tipo_equipo IN ('Fijo')        THEN 'Costs to Acquire & Retain'
          WHEN tipo_pedido IN ('DESISTIMIENTO','SWAP') AND tipo_equipo IN ('Movil') THEN 'Cost to serve'
          WHEN tipo_pedido IN ('DESISTIMIENTO','SWAP') AND tipo_equipo IN ('Fijo')  THEN 'Cost to serve'
      ELSE cuenta END AS cuenta

  FROM (
    SELECT lic.id_mes
      , SUBSTR(CAST(lic.id_mes AS STRING),1,4) AS year
      , COSTES.marca
      , UPPER(COSTES.tipo_pedido) AS tipo_pedido
      , COSTES.estado_final AS estado
      , TIPO.canal AS canal
      , TIPO.dispositivo AS tipo_producto
      , TIPO.Tipo_equipo AS tipo_equipo
      , COSTES.codigo_contrato
      , COSTES.posicion_cm
      , COSTES.texto_sap
      , vul.valor AS valor_unitario
      , CASE WHEN COSTES.codigo_contrato IN ('TAR0158','TAR0237','TAR0490') THEN COUNT(1) ELSE ROUND(SAFE_DIVIDE(SUM(coste_sin_imp),vul.valor),0) END AS cuenta_unidades  --SEGURO TAR0158  TAR0237  TAR0490   FALTA EL RESTO (ELSE)
      , ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp
      , FACTURA.pep as pep
      , FACTURA.pl2 as cuenta
    FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COSTES
      INNER JOIN `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_complete` lic
        ON  lic.Order_No = COSTES.id_orden
        --AND lic.id_mes = CAST(COSTES.id_mes AS STRING)
        AND  lic.reexpedicion = COSTES.reexpedition
      LEFT JOIN `mm-commissions-reporting.TEMP.tipo_equipo` TIPO
        ON  UPPER(TIPO.marca) = UPPER(COSTES.marca)
        AND UPPER(TIPO.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND TIPO.id_orden = COSTES.id_orden
      LEFT JOIN `mm-commissions-reporting.TEMP.valor_unitario_logistico` vul
        ON  vul.codigo_contrato = COSTES.codigo_contrato
        AND UPPER(vul.tipo_pedido) = UPPER(COSTES.tipo_pedido)
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.gs_datos_factura` FACTURA
        ON  CASE WHEN UPPER(COSTES.marca) IN ('LYCAMOBILE') THEN UPPER(FACTURA.marca) IN ('LYCA')
                WHEN UPPER(COSTES.marca) IN ('MASMOVIL') AND UPPER(COSTES.tipo_pedido) IN ('ENTREGA','DESISTIMIENTO')  THEN UPPER(FACTURA.marca) IN ('MASMOVIL')
                WHEN UPPER(COSTES.marca) IN ('MASMOVIL') AND UPPER(COSTES.tipo_pedido) NOT IN ('ENTREGA','DESISTIMIENTO')  THEN UPPER(FACTURA.marca) IN ('MASMOVIL POSTVENTA')
                WHEN UPPER(COSTES.marca) IN ('YOIGO') AND UPPER(COSTES.tipo_pedido) IN ('ENTREGA','DESISTIMIENTO') THEN UPPER(FACTURA.marca) IN ('YOIGO')
                WHEN UPPER(COSTES.marca) IN ('YOIGO') AND UPPER(COSTES.tipo_pedido) NOT IN ('ENTREGA','DESISTIMIENTO') THEN UPPER(FACTURA.marca) IN ('YOIGO POSTVENTA')
                ELSE UPPER(COSTES.marca) = UPPER(FACTURA.marca) END
        AND CASE WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('ABONADO') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('ABONADO')
                WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('ENTREGADO A CLIENTE') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('DEVUELTO A CLIENTE')
                WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('ENTREGADO EN ALMACEN') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('DESESTIMIENTO RECHADO NO APTOS')
                WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('RECHAZADO') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('MERCANCÍA ERRÓNEA')
                WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('CANCELADO POSTPICKING') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('ANULADO POST PICKING') AND UPPER(FACTURA.canal) = 'DIRECTO'
                WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('DESTRUIDO (SIM)') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DESTRUIDO POR EUROLOGISTICA') AND UPPER(FACTURA.canal) = 'DIRECTO'
                WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('DEVUELTO AL ALMACEN') AND UPPER(COSTES.dispositivo) NOT IN ('SIM CARD','SIM') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DEVOLUCIÓN EN ALMACÉN Y ABONADO') AND UPPER(FACTURA.canal) = 'DIRECTO'
                WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('DEVUELTO AL ALMACEN') AND UPPER(COSTES.dispositivo)  IN ('SIM CARD','SIM') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DESTRUIDO POR EUROLOGISTICA') AND UPPER(FACTURA.canal) = 'DIRECTO'
                WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('ENTREGADO') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('ENTREGADO') AND UPPER(FACTURA.canal) = 'DIRECTO'
                WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('ENTREGADO (DOCUMENTACION KO)') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DAC ENVIADO') AND UPPER(FACTURA.canal) = 'DIRECTO'
                WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('ENTREGADO (DOCUMENTACION OK)') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DAC EN ALMACEN') AND UPPER(FACTURA.canal) = 'DIRECTO'
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('CANCELADO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ANULADO PRE PICKING')
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('CANCELADO DEVOLUCION ALMACÉN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ANULADO PRE PICKING')
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('CANCELADO-ANULADO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ANULADO PRE PICKING')
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('ENTREGA ALMACEN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ENTREGADO')
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('ENTREGADO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ENTREGADO')
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('ENTREGADO ANOVO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('SWAP EN ALMACÉN Y ABONADO')
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('NO ENTREGADO-DEVUELTO AL ALMACÉN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('SWAP EN ALMACÉN Y ABONADO')
                WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('RECHAZADO CLIENTE-DEVUELTO AL ALMACÉN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('SWAP EN ALMACÉN Y ABONADO') AND UPPER(FACTURA.tipo_equipo) = 'MOVIL' END
        AND CASE WHEN UPPER(COSTES.dispositivo) IN ('DOCUMENTACION SMART TV') THEN UPPER(FACTURA.tipo_producto) IN ('DOCUMENTOS') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('MAE') THEN UPPER(FACTURA.tipo_producto) IN ('MAE') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('PAE') THEN UPPER(FACTURA.tipo_producto) IN ('PAE') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('PATINETE') THEN UPPER(FACTURA.tipo_producto) IN ('PATIN') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('ROUTER','ROUTER FIBRA','ROUTER ADSL','ROUTER + SIM','SIM+ROUTER') THEN UPPER(FACTURA.tipo_producto) IN ('ROUTERS CORREOS') AND UPPER(FACTURA.tipo_equipo) IN ('FIJO')
                WHEN UPPER(COSTES.dispositivo) IN ('SIM CARD','SIM') THEN UPPER(FACTURA.tipo_producto) IN ('TARJETAS') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('ACCESORIO + SIM','Equipo manipulado + SIM','TERMINAL + SIM','SIM + DISPOSITIVO','SIM+ACCESORIO') THEN UPPER(FACTURA.tipo_producto) IN ('TERM+TARJ') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('STB + SIM') THEN UPPER(FACTURA.tipo_producto) IN ('TERM+TARJ') AND UPPER(FACTURA.tipo_equipo) IN ('FIJO')
                WHEN UPPER(COSTES.dispositivo) IN ('STB','ONT','TV YOIGO') THEN UPPER(FACTURA.tipo_producto) IN ('TERMINALES') AND UPPER(FACTURA.tipo_equipo) IN ('FIJO')
                WHEN UPPER(COSTES.dispositivo) IN ('ACCESORIO','SMARTPHONE','ACCESORIES WITH IMEI','MODEM','SMARTWATCH','ACCESORIES WITH SERIAL NUMBER','TERMINAL','TABLET','ACCESORIES') THEN UPPER(FACTURA.tipo_producto) IN ('TERMINALES') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION') THEN UPPER(FACTURA.tipo_producto) IN ('TV') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                WHEN UPPER(COSTES.dispositivo) IN ('OTROS') THEN UPPER(FACTURA.tipo_producto) IN ('NULO') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
                ELSE UPPER(FACTURA.tipo_producto) IN ('TERMINALES') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL') END

    WHERE COSTES.tipo_coste = 'LOGISTICO'
  --    AND COSTES.id_orden in (SELECT distinct icm.Order_No FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_complete` icm)
    GROUP BY ALL
  )
);

/*
  --Informe para Quiero ANTERIOR
CREATE OR REPLACE TABLE `mm-logistics-reporting.LOG_FACTURACION.43_logistic_costs_quiero` AS(
  SELECT id_mes
      , SUBSTR(CAST(id_mes AS STRING),1,4) AS year
      , COSTES.marca
      , UPPER(COSTES.tipo_pedido) AS tipo_pedido
      , COSTES.estado_final AS estado
      , TIPO.canal AS canal
      , TIPO.dispositivo AS tipo_producto
      , TIPO.Tipo_equipo AS tipo_equipo
      , COSTES.codigo_contrato
      , COSTES.posicion_cm
      , COSTES.texto_sap
      --, ROUND(MIN(coste_sin_imp),2) AS valor_unitario
      --, ROUND(coste_sin_imp,2) AS valor_unitario  --2026/03/20
      , CASE WHEN COSTES.codigo_coste NOT IN ('L - SEGURO') THEN COSTES_CONFIG.importe 
             ELSE (COSTES_CONFIG.porcentaje/100) END AS valor_unitario
      , COUNT(1) AS cuenta_unidades, ROUND(SUM(coste_sin_imp),2) AS coste_sin_imp
      , FACTURA.pep as pep
      , FACTURA.pl2 as cuenta
  FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_costs` COSTES
      LEFT JOIN `mm-commissions-reporting.TEMP.tipo_equipo` TIPO
        ON  UPPER(TIPO.marca) = UPPER(COSTES.marca)
        AND UPPER(TIPO.tipo_pedido) = UPPER(COSTES.tipo_pedido)
        AND TIPO.id_orden = COSTES.id_orden
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` ORDENES
        ON  UPPER(COSTES.tipo_pedido) = UPPER(ORDENES.tipo_pedido)
        --AND UPPER(COSTES.operador_logistico) = UPPER(ORDENES.operador_logistico)
        AND COSTES.id_orden = ORDENES.id_orden
        AND COSTES.tipo_pedido = ORDENES.tipo_pedido
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_zona` ZONA
        ON  ZONA.codigo_postal = SUBSTR(ORDENES.codigo_postal,1,2)
        AND CAST(ORDENES.fecha_comunicacion AS DATE) BETWEEN ZONA.fecha_desde AND ZONA.fecha_hasta
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_costs` COSTES_CONFIG
      ON  COSTES_CONFIG.codigo_contrato = COSTES.codigo_contrato
      AND COSTES_CONFIG.fecha_desde >= COSTES.mes_liquidado
      AND COSTES_CONFIG.fecha_hasta <= COSTES.mes_liquidado
      AND CASE WHEN COSTES_CONFIG.zona <> '%' THEN COSTES_CONFIG.zona = ZONA.valor
               ELSE COSTES_CONFIG.zona = '%' END
    LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.gs_datos_factura` FACTURA
      ON  CASE WHEN UPPER(COSTES.marca) IN ('LYCAMOBILE') THEN UPPER(FACTURA.marca) IN ('LYCA')
               WHEN UPPER(COSTES.marca) IN ('MASMOVIL') AND UPPER(COSTES.tipo_pedido) IN ('ENTREGA','DESISTIMIENTO')  THEN UPPER(FACTURA.marca) IN ('MASMOVIL')
               WHEN UPPER(COSTES.marca) IN ('MASMOVIL') AND UPPER(COSTES.tipo_pedido) NOT IN ('ENTREGA','DESISTIMIENTO')  THEN UPPER(FACTURA.marca) IN ('MASMOVIL POSTVENTA')
               WHEN UPPER(COSTES.marca) IN ('YOIGO') AND UPPER(COSTES.tipo_pedido) IN ('ENTREGA','DESISTIMIENTO') THEN UPPER(FACTURA.marca) IN ('YOIGO')
               WHEN UPPER(COSTES.marca) IN ('YOIGO') AND UPPER(COSTES.tipo_pedido) NOT IN ('ENTREGA','DESISTIMIENTO') THEN UPPER(FACTURA.marca) IN ('YOIGO POSTVENTA')
               ELSE UPPER(COSTES.marca) = UPPER(FACTURA.marca) END
      AND CASE WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('ABONADO') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('ABONADO')
               WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('ENTREGADO A CLIENTE') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('DEVUELTO A CLIENTE')
               WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('ENTREGADO EN ALMACEN') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('DESESTIMIENTO RECHADO NO APTOS')
               WHEN UPPER(COSTES.tipo_pedido) IN ('DESISTIMIENTO') AND UPPER(COSTES.estado_final) IN ('RECHAZADO') THEN UPPER(FACTURA.tipo_pedido) IN ('DESESTIMIENTO') AND UPPER(FACTURA.estado) IN ('MERCANCÍA ERRÓNEA')
               WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('CANCELADO POSTPICKING') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('ANULADO POST PICKING') AND UPPER(FACTURA.canal) = 'DIRECTO'
               WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('DESTRUIDO (SIM)') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DESTRUIDO POR EUROLOGISTICA') AND UPPER(FACTURA.canal) = 'DIRECTO'
               WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('DEVUELTO AL ALMACEN') AND UPPER(COSTES.dispositivo) NOT IN ('SIM CARD','SIM') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DEVOLUCIÓN EN ALMACÉN Y ABONADO') AND UPPER(FACTURA.canal) = 'DIRECTO'
               WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('DEVUELTO AL ALMACEN') AND UPPER(COSTES.dispositivo)  IN ('SIM CARD','SIM') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DESTRUIDO POR EUROLOGISTICA') AND UPPER(FACTURA.canal) = 'DIRECTO'
               WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('ENTREGADO') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('ENTREGADO') AND UPPER(FACTURA.canal) = 'DIRECTO'
               WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('ENTREGADO (DOCUMENTACION KO)') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DAC ENVIADO') AND UPPER(FACTURA.canal) = 'DIRECTO'
               WHEN UPPER(COSTES.tipo_pedido) IN ('ENTREGA') AND UPPER(COSTES.estado_final) IN ('ENTREGADO (DOCUMENTACION OK)') THEN UPPER(FACTURA.tipo_pedido) IN ('ENTREGA') AND UPPER(FACTURA.estado) IN ('DAC EN ALMACEN') AND UPPER(FACTURA.canal) = 'DIRECTO'
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('CANCELADO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ANULADO PRE PICKING')
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('CANCELADO DEVOLUCION ALMACÉN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ANULADO PRE PICKING')
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('CANCELADO-ANULADO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ANULADO PRE PICKING')
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('ENTREGA ALMACEN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ENTREGADO')
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('ENTREGADO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('ENTREGADO')
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('ENTREGADO ANOVO') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('SWAP EN ALMACÉN Y ABONADO')
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('NO ENTREGADO-DEVUELTO AL ALMACÉN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('SWAP EN ALMACÉN Y ABONADO')
               WHEN UPPER(COSTES.tipo_pedido) IN ('SWAP') AND UPPER(COSTES.estado_final) IN ('RECHAZADO CLIENTE-DEVUELTO AL ALMACÉN') THEN UPPER(FACTURA.tipo_pedido) IN ('SWAP') AND UPPER(FACTURA.estado) IN ('SWAP EN ALMACÉN Y ABONADO') AND UPPER(FACTURA.tipo_equipo) = 'MOVIL' END
      AND CASE WHEN UPPER(COSTES.dispositivo) IN ('DOCUMENTACION SMART TV') THEN UPPER(FACTURA.tipo_producto) IN ('DOCUMENTOS') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('MAE') THEN UPPER(FACTURA.tipo_producto) IN ('MAE') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('PAE') THEN UPPER(FACTURA.tipo_producto) IN ('PAE') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('PATINETE') THEN UPPER(FACTURA.tipo_producto) IN ('PATIN') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('ROUTER','ROUTER FIBRA','ROUTER ADSL','ROUTER + SIM','SIM+ROUTER') THEN UPPER(FACTURA.tipo_producto) IN ('ROUTERS CORREOS') AND UPPER(FACTURA.tipo_equipo) IN ('FIJO')
               WHEN UPPER(COSTES.dispositivo) IN ('SIM CARD','SIM') THEN UPPER(FACTURA.tipo_producto) IN ('TARJETAS') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('ACCESORIO + SIM','Equipo manipulado + SIM','TERMINAL + SIM','SIM + DISPOSITIVO','SIM+ACCESORIO') THEN UPPER(FACTURA.tipo_producto) IN ('TERM+TARJ') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('STB + SIM') THEN UPPER(FACTURA.tipo_producto) IN ('TERM+TARJ') AND UPPER(FACTURA.tipo_equipo) IN ('FIJO')
               WHEN UPPER(COSTES.dispositivo) IN ('STB','ONT','TV YOIGO') THEN UPPER(FACTURA.tipo_producto) IN ('TERMINALES') AND UPPER(FACTURA.tipo_equipo) IN ('FIJO')
               WHEN UPPER(COSTES.dispositivo) IN ('ACCESORIO','SMARTPHONE','ACCESORIES WITH IMEI','MODEM','SMARTWATCH','ACCESORIES WITH SERIAL NUMBER','TERMINAL','TABLET','ACCESORIES') THEN UPPER(FACTURA.tipo_producto) IN ('TERMINALES') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('SMART TV','SMART TV+DOCUMENTACION') THEN UPPER(FACTURA.tipo_producto) IN ('TV') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               WHEN UPPER(COSTES.dispositivo) IN ('OTROS') THEN UPPER(FACTURA.tipo_producto) IN ('NULO') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL')
               ELSE UPPER(FACTURA.tipo_producto) IN ('TERMINALES') AND UPPER(FACTURA.tipo_equipo) IN ('MOVIL') END
  WHERE COSTES.tipo_coste = 'LOGISTICO'
--    AND id_mes IN (id_mes_anterior,id_mes_actual)
    AND COSTES.id_orden in (
      SELECT distinct icm.Order_No
      FROM `mm-logistics-reporting.LOG_FACTURACION.40_logistic_invoice_complete` icm
    )
  GROUP BY ALL
  ORDER BY 1,5,2
);
*/

END