BEGIN

-- CALL`mm-commissions-reporting.B2B.pr_TRAFICO_CDR_ADAMO`()



DECLARE finMes,inicioMes DATE;
DECLARE dias_var, mes_int INT64;
DECLARE datos_pull_tuca, datos_pull_vlcCtb FLOAT64;

--Actualizamos la bolsa de GB 
CALL `mm-commissions-reporting.B2B.pr_TRAFICO_DATOS_BOLSA_CDR_ADAMO`();

SET mes_int = CAST(FORMAT_DATE('%Y%m',DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)) AS INT64); --mes_int
SET finMes = LAST_DAY(PARSE_DATE('%Y%m%d', FORMAT('%06d01', mes_int))); --LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH));
SET inicioMes = PARSE_DATE('%Y%m%d', FORMAT('%06d01', mes_int)); --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);
SET dias_var = DATE_DIFF(finMes,inicioMes,DAY)+1;

--HISTÓRICO TRÁFICO

  -- DELETE  `mm-commissions-reporting.B2B.TRAFICO_x_HISTORICO_prueba`
  -- WHERE id_mes = mes_int
  --;
  
  --INSERT INTO 
  CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TRAFICO_x_HISTORICO_ADAMO` 
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

    
    WITH

    billing AS (
        SELECT DISTINCT 
          a.data_month_id AS id_mes,
          DATE_TRUNC(a.invoice_date, MONTH) AS invoice_date,
          a.customer_id,
          a.invoice_id,
          b.mes_inicio,
          b.agrupacion_canal
        FROM `mm-datamart-kd.BILLING.billing_detail_xena` a
        JOIN `mm-commissions-reporting.GS.DEALERS_TRAFICO_ADAMO` b 
        ON a.customer_id = b.id_comisionista 
        WHERE 1=1
          AND data_month_id = CAST(FORMAT_DATE('%Y%m',DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), INTERVAL 1 MONTH),MONTH)) AS INT64) -- tiene que haber valores de id_mes > mes int en la GS (porque esta linea suma un mes)
      ),

    origen AS (
        SELECT 
          mes_int AS id_mes,
          b.invoice_date,
          b.agrupacion_canal,
          b.customer_id,
          CASE
            WHEN descripcion_tarzona like '%|SMS' THEN 'SMS' 
            WHEN descripcion_tarzona like '%|VOZ' THEN 'VOZ'
            WHEN descripcion_tarzona like '%|DAT' THEN 'DAT'
            ELSE 'NO_TIPO'
          END AS TIPO,
          REGEXP_EXTRACT(descripcion_tarzona, r'^(.*?)\|') AS DESCRIPCION_AMBITO,
          CASE
            WHEN Tarifa_fact like '%3P%' OR descripcion_fact like '%3P%' THEN '3P'
            ELSE 'OM'
          END AS TARIFA,
          a.*,
          b.* EXCEPT(id_mes, agrupacion_canal, customer_id, invoice_date)
        FROM `mm-dwh-prod.00_SANDBOX_XENA.XENA_HISTORICO_VOZ_*` a
        JOIN billing b ON a.num_fact = b.invoice_id
        WHERE 1=1
          AND _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d',DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
      ),

      previo AS (
        SELECT 
          * EXCEPT(num_horas,num_llamadas,tarzona,descripcion_tarzona,serie,numero,total_precio,total_dest,grplistado,Coste_Acceso_Positivo,Coste_Acceso_Negativo,Coste_Terminacion,Id_Empresa,descripcion_list),
          total_precio AS COSTE,
          CASE
              WHEN a.descripcion_tarzona like '%|VOZ' THEN CAST(num_horas AS FLOAT64)
              ELSE 0
            END
          AS SEGUNDOS,
            CASE
              WHEN a.descripcion_tarzona like '%|DAT' THEN CAST(num_horas AS FLOAT64)
              ELSE 0
            END
          AS DATOS,
            CASE
              WHEN a.descripcion_tarzona like '%|SMS' THEN CAST(num_llamadas AS FLOAT64)
              ELSE 0
            END
          AS SMS
        FROM origen a
      )

    SELECT * EXCEPT(COSTE,SEGUNDOS,DATOS,SMS),
      SUM(COSTE) AS COSTE,
      SUM(SEGUNDOS) AS SEGUNDOS,
      SUM(DATOS) AS DATOS,
      SUM(SMS) AS SMS
    FROM previo
    GROUP BY ALL
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TRAFICO_CDRS_ADAMO`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
  
  --CDRS
    SELECT 
      id_mes,
      agrupacion_canal,
      customer_id AS COD_OP, 
      CASE
        WHEN DESCRIPCION_AMBITO IS NULL THEN 'No Ambito'
        ELSE DESCRIPCION_AMBITO
      END AS DESCRIPCION_AMBITO,
      CASE
        WHEN DESCRIPCION_AMBITO LIKE 'Roaming%' THEN
          CASE 
            WHEN DESCRIPCION_AMBITO LIKE '% UE%' OR DESCRIPCION_AMBITO = 'Roaming desde Zona 1' THEN 'UE'
            WHEN DESCRIPCION_AMBITO LIKE '%Term.%' THEN 'ROAMING TERMINAL'
            ELSE 'ROAMING'
          END
        WHEN DESCRIPCION_AMBITO IN ('Datos', 'Moviles','Nacionales','Llamadas Interprovinciales','Llamadas Locales','Llamadas Provinciales','Locales','Moviles Nacionales.','Provinciales') THEN 
          CASE
            WHEN TARIFA='3P' THEN '3P NACIONAL'
            ELSE'NACIONAL'
          END
        WHEN DESCRIPCION_AMBITO = 'Internacionales' THEN 'INTERNACIONAL'
        WHEN DESCRIPCION_AMBITO IN ('Numeros Comerciales','Red Inteligente','Servicios Especiales') THEN 'ESPECIAL'
        ELSE 'NO CAT'
      END AS SOBRECATEGORIZACION,
      TARIFA AS CONV, 
      a.TIPO,
      COSTE, 
      Segundos/60 AS DURACION,
      IF(DATOS IS NULL,0,DATOS)/1024 AS DATOS,
      SMS AS SMS,
      -- DESTINO AS CATEGORIZACION,
      -- RED
    FROM `mm-commissions-reporting.B2B.TRAFICO_x_HISTORICO_ADAMO` a
    -- LEFT JOIN (
    --     SELECT *
    --     FROM `mm-commissions-reporting.TEMP.TUCA_Sobrecategorizacion`
    --     QUALIFY ROW_NUMBER() OVER(PARTITION BY TIPO, CATEGORIZACION) = 1
    --   ) b ON a.TIPO = b.TIPO AND a.DESTINO = b.CATEGORIZACION 
    WHERE id_mes = mes_int
;

  --PRIMERA CARGA INFORME IWONA Y CATEGORIZACIÓN DE DUPLICADOS Y CALCULO DE DIAS ACTIVO
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TRAFICO_INFORME_IWONA_ADAMO`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
  WITH
    informe_iwona AS (
      SELECT x.*  except (Bono, Fecha_Activacion),
        SAFE.PARSE_DATE('%Y%m%d', CAST(x.Fecha_activacion AS STRING)) AS Fecha_Activacion,
        b.agrupacion_canal
      FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*` x
      LEFT JOIN `mm-b2b-reporting.MAESTROS.Maestro_B2B` m ON x.Cliente = m.customer_id_xena 
      INNER JOIN `mm-commissions-reporting.GS.DEALERS_TRAFICO_ADAMO` b
      ON x.cliente = b.id_comisionista
      where x.data_month_id = mes_int
    ),

    iwona_pre AS (
      SELECT
        a.Msisdn AS NUMERO_TX, 
        1 AS fila_iwo,
        data_month_id, 
        Orden, 
        agrupacion_canal,
        Upper(a.Cliente) AS COD_OP, 
        a.SubCliente, 
        Fecha_Activacion, 
        CASE
          WHEN Fecha_Activacion > inicioMes THEN DATE_DIFF(finMes, Fecha_Activacion,DAY)+ 1
          ELSE DATE_DIFF(finMes,inicioMes, DAY)+1
        END AS Dias,
          
        COALESCE(Tarifa_ID,Bono_Compartido_Descripcion) AS Tarifa_ID, 
        Producto_ID, 
        Producto_Descripcion, 
        Total_Facturacion, 
        Total_Facturacion - Cdrs_voz_Importe - Cdrs_datos_Importe - Cdrs_sms_Importe AS Total_Base,
        CASE
          WHEN Tarifa_ID LIKE '%3P%' 
            OR Producto_ID LIKE '%3P%'
            OR Bono_Compartido_Descripcion LIKE '%3P%'
            OR Bono_Compartido_Descripcion LIKE '%3P%'
            OR Bono_Compartido_ID LIKE '%3P%' 
              THEN 'FMC'
          ELSE'OM'
        END AS CONV2,
        Cdrs_voz_Minutos, 
        Cdrs_voz_Importe, 
        Cdrs_datos_MB, 
        Cdrs_datos_Importe, 
        Cdrs_sms_Unidades, 
        Cdrs_sms_Importe, 
        Bonos_Total, 
        Bonos_Descuentos_Total, 
        Bonos_Datos_Descripcion, 
        Bonos_Datos_Precios, 
        Bonos_Datos_Importe, 
        Bonos_Datos_Descuento, 
        Bonos_Voz_Descripcion, 
        Bonos_Voz_Precios, 
        Bonos_Voz_Importe, 
        Bonos_Voz_Descuento, 
        Bonos_SMS_Descripcion, 
        Bonos_SMS_Precios, 
        Bonos_SMS_Importe, 
        Bonos_SMS_Descuento, 
        Resto_Descuentos, 
        Permanencias, 
        ConsumosMinimos, 
        OtrosDatos, 
        Bono_Compartido_Descripcion, 
        Bono_Compartido_ID, 
        Bono_Compartido_Perfil, 
        Bono_Compartido_Comentario, 
        Id_Grupo_Cliente, 
        Promociones, 
        Cdrs_Voz_Minutos_Bono, 
        Cdrs_datos_MB_Bono, 
        Cdrs_sms_unidades_Bono, 
        Community, 
        Num_Fact, 
        Cdrs_datos_MB_BonoCompartido, 
        Bono_Compartido_ProdRelacionado
      FROM informe_iwona a
      QUALIFY ROW_NUMBER() OVER(PARTITION BY agrupacion_canal,IF(MSISDN IS NULL, GENERATE_UUID(), MSISDN) ORDER BY Fecha_Activacion ASC, Total_Facturacion DESC) = 1
    )
    SELECT *
    FROM iwona_pre
;



--SEGUNDA LECTURA DE INFORME IWONA, INDICANDO EL NUEVO PVP, MINUTOS, SMS Y GIGAS PARA LA PRIMERA APARICIÓN DEL NÚMERO NO 3P, TODO PRORRATEADO PARA 'F0079*'
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TRAFICO_INFORME_IWONA_NUEVO_PVP_ADAMO`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS  
  
  WITH
    iwona_pre_2 AS (
      SELECT
        a.*,
        CASE
          WHEN NUMERO_TX  IS NULL THEN 0
          -- WHEN REGEXP_CONTAINS(IFNULL(UPPER(Tarifa_ID),' '),r'(TRV)') AND a.total_base <= 0.5 THEN 0
          -- WHEN REGEXP_CONTAINS(IFNULL(UPPER(Tarifa_ID),' '),r'(TRV)') AND a.total_base > 0.5 THEN a.total_base -0.5
          WHEN REGEXP_CONTAINS(IFNULL(UPPER(Tarifa_ID),' '),r'(TRV)') THEN 0
          WHEN (Cdrs_voz_Minutos = 0 AND Cdrs_datos_MB = 0 AND Cdrs_sms_Unidades = 0) THEN 0
          ELSE b.total_tarifa_NA
        END AS Total_Tarifa_NA,

        CASE
           WHEN NUMERO_TX  IS NULL THEN 0
           ELSE b.datos_bolsa     
        END AS GB_inc,
          
        CASE
          WHEN NUMERO_TX  IS NULL THEN 0
          ELSE b.min_incl
        END Min_inc,

        CASE
          WHEN NUMERO_TX  IS NULL THEN 0
          ELSE b.sms_incl
        END SMS_inc
    
     FROM `mm-commissions-reporting.TEMP.TRAFICO_INFORME_IWONA_ADAMO` a
     LEFT JOIN `mm-commissions-reporting.B2B.TRAFICO_DATOS_BOLSA_ADAMO` b
     ON a.COD_OP = b.id_comisionista and a.data_month_id = b.id_mes

    )
    SELECT *
    FROM iwona_pre_2
;

--ACUMULADO POR OPERADOR DE LAS BOLSAS CREADAS
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TRAFICO_PULLES_F_ADAMO`
--   OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS  
--   WITH 
--       PULLES_PRE AS (
--         SELECT
--           a.COD_OP,
--           SUM(GB_inc) AS GB_Bolsa,
--           SUM(Min_inc) AS MIN_Bolsa,
--           SUM(SMS_inc) AS SMS_Bolsa,
--           COUNT(DISTINCT NUMERO_TX) AS Clientes_Activos,
--           IFNULL(GB_consumidos,0) AS GB_consumidos,
--           IFNULL(MIN_consumidos,0) AS MIN_consumidos,
--           IFNULL(SMS_consumidos,0) AS SMS_consumidos,
--           -- IFNULL(MIN_consumidos_ONNET,0) AS MIN_consumidos_ONNET,
--           CAST(NULL AS FLOAT64 ) MIN_consumidos_ONNET,
--           -- IFNULL(MIN_consumidos_OFNET,0) AS MIN_consumidos_OFNET
--           CAST(NULL AS FLOAT64 ) MIN_consumidos_OFNET

--         FROM `mm-commissions-reporting.TEMP.TRAFICO_INFORME_IWONA_NUEVO_PVP_ADAMO` a --iwona_pre_2 a
--         LEFT JOIN (
--           SELECT 
--             id_mes,
--             COD_OP,
--             SUM(DATOS) AS GB_consumidos,
--             SUM(DURACION) AS MIN_consumidos,
--             SUM(SMS) AS SMS_consumidos
--           FROM `mm-commissions-reporting.TEMP.TRAFICO_CDRS_ADAMO` --CDRS
--           WHERE SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' 
--           GROUP BY ALL
--         ) b ON a.COD_OP = b.COD_OP
--         -- LEFT JOIN (
--         --   SELECT 
--         --     id_mes,
--         --     COD_OP,
--         --     SUM(DURACION) AS MIN_consumidos_ONNET
--         --   FROM `mm-commissions-reporting.TEMP.TRAFICO_CDRS` --CDRS
--         --   WHERE SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' AND RED = 'ONNET'
--         --   GROUP BY ALL
--         -- ) c ON a.COD_OP = c.COD_OP
--         -- LEFT JOIN(
--         --   SELECT
--         --     id_mes,
--         --     COD_OP,
--         --     SUM(DURACION) AS MIN_consumidos_OFNET
--         --   FROM `mm-commissions-reporting.TEMP.TRAFICO_CDRS` --CDRS
--         --   WHERE SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' AND RED = 'OFFNET'
--         --   GROUP BY ALL
--         -- ) d ON a.COD_OP = d.COD_OP
--         GROUP BY ALL
--       ),

--   --CALCULO COMPARATIVO GLOBAL Y POR OPERADOR PARA SACAR SUS GB/MIN/SMS APORTADOS, CUBIERTOS Y SOBRANTES

--     PULLES AS (
--       SELECT *,
--       'TOTAL' AS Codigo,
--         GB_Bolsa - GB_consumidos AS GB_Global,
--         IF((GB_Bolsa - GB_consumidos) > 0,1,0) AS GB_Cubiertos,
--         IF((GB_Bolsa - GB_consumidos) > 0,0,GB_consumidos - GB_Bolsa) AS GB_Faltantes,
--         IF((GB_Bolsa - GB_consumidos) > 0,GB_Bolsa - GB_consumidos,0) AS GB_Sobrantes,
--         MIN_Bolsa - MIN_consumidos AS MIN_Global,
--         IF((MIN_Bolsa - MIN_consumidos) > 0,1,0) AS MIN_Cubiertos,
--         IF((MIN_Bolsa - MIN_consumidos) > 0,0,MIN_consumidos - MIN_Bolsa) AS MIN_Faltantes,
--         IF((MIN_Bolsa - MIN_consumidos) > 0,MIN_Bolsa - MIN_consumidos,0) AS MIN_Sobrantes,
--         SMS_Bolsa - SMS_consumidos AS SMS_Global,
--         IF((SMS_Bolsa - SMS_consumidos) > 0,1,0) AS SMS_Cubiertos,
--         IF((SMS_Bolsa - SMS_consumidos) > 0,0,SMS_consumidos - SMS_Bolsa) AS SMS_Faltantes,
--         IF((SMS_Bolsa - SMS_consumidos) > 0,SMS_Bolsa - SMS_consumidos,0) AS SMS_Sobrantes
--       FROM PULLES_PRE
--     ),


--     PULLES_F AS ( -- Se busca con el OVER PARTITION que la sumatoria sea por agrupación canal
--       SELECT a.*,
--         SUM(GB_Bolsa)         OVER (PARTITION BY agrupacion_canal) AS GB_Bolsa_Total, --Total GB aportados
--         SUM(GB_consumidos)    OVER (PARTITION BY agrupacion_canal) AS GB_consumidos_Total, --Total GB consumidos a cubrir
--         SUM(GB_Global)        OVER (PARTITION BY agrupacion_canal) AS GB_Global_Reparto, --GB sobrantes o faltantes totales

--         SUM(GB_Faltantes)     OVER (PARTITION BY agrupacion_canal) AS GB_Faltantes_Total, 
--         SUM(GB_Sobrantes)     OVER (PARTITION BY agrupacion_canal) AS GB_Sobrantes_Total,

--         SUM(MIN_Bolsa)        OVER (PARTITION BY agrupacion_canal) AS MIN_Bolsa_Total, 
--         SUM(MIN_consumidos)   OVER (PARTITION BY agrupacion_canal) AS MIN_consumidos_Total,
--         SUM(MIN_Global)       OVER (PARTITION BY agrupacion_canal) AS MIN_Global_Reparto,

--         SUM(MIN_Faltantes)    OVER (PARTITION BY agrupacion_canal) AS MIN_Faltantes_Total, 
--         SUM(MIN_Sobrantes)    OVER (PARTITION BY agrupacion_canal) AS MIN_Sobrantes_Total,

--         SUM(SMS_Bolsa)        OVER (PARTITION BY agrupacion_canal) AS SMS_Bolsa_Total,
--         SUM(SMS_consumidos)   OVER (PARTITION BY agrupacion_canal) AS SMS_consumidos_Total,
--         SUM(SMS_Global)       OVER (PARTITION BY agrupacion_canal) AS SMS_Global_Reparto,

--         SUM(SMS_Faltantes)    OVER (PARTITION BY agrupacion_canal) AS SMS_Faltantes_Total, 
--         SUM(SMS_Sobrantes)    OVER (PARTITION BY agrupacion_canal) AS SMS_Sobrantes_Total,

--         SUM(Clientes_Activos) OVER (PARTITION BY agrupacion_canal) AS Clientes_Activos_Total
        
--       FROM PULLES a
--       GROUP BY ALL
--     )

-- --     PULLES_F AS (
-- --       SELECT a.*,
-- --         b.* EXCEPT(codigo)
-- --       FROM PULLES a
-- --       LEFT JOIN(
-- --         SELECT
-- --           'TOTAL'               AS Codigo,
-- --           SUM(GB_Bolsa)         AS GB_Bolsa_Total, --Total GB aportados
-- --           SUM(GB_consumidos)    AS GB_consumidos_Total, --Total GB consumidos a cubrir
-- --           SUM(GB_Global)        AS GB_Global_Reparto, --GB sobrantes o faltantes totales

-- --           SUM(GB_Faltantes)     AS GB_Faltantes_Total, 
-- --           SUM(GB_Sobrantes)     AS GB_Sobrantes_Total,

-- --           SUM(MIN_Bolsa)        AS MIN_Bolsa_Total, 
-- --           SUM(MIN_consumidos)   AS MIN_consumidos_Total,
-- --           SUM(MIN_Global)       AS MIN_Global_Reparto,

-- --           SUM(MIN_Faltantes)    AS MIN_Faltantes_Total, 
-- --           SUM(MIN_Sobrantes)    AS MIN_Sobrantes_Total,

-- --           SUM(SMS_Bolsa)        AS SMS_Bolsa_Total,
-- --           SUM(SMS_consumidos)   AS SMS_consumidos_Total,
-- --           SUM(SMS_Global)       AS SMS_Global_Reparto,

-- --           SUM(SMS_Faltantes)    AS SMS_Faltantes_Total, 
-- --           SUM(SMS_Sobrantes)    AS SMS_Sobrantes_Total,

-- --           SUM(Clientes_Activos) AS Clientes_Activos_Total
-- --         FROM PULLES
-- --       ) b ON a.codigo = b.codigo
-- --     )


--     SELECT *
--     FROM PULLES_F
-- ;

-- --CALCULO DE LOS GB/MIN/SMS A FACTURAR A CADA OPERADOR
-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TRAFICO_BOLSAS_ADAMO`
--   OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
--   WITH 
--     BOLSA AS (
--     SELECT
--       --COD_OP,
--       *,
--       CASE
--         WHEN GB_Cubiertos = 1 OR GB_consumidos = 0 THEN GB_consumidos
--         ELSE 
--           IFNULL(
--             LEAST(
--               GB_Bolsa + (GB_Sobrantes_Total / GB_Faltantes_Total * GB_Faltantes), GB_consumidos),
--           GB_Bolsa)
--       END AS GB_Operador,
--       CASE
--         WHEN MIN_Cubiertos = 1 OR MIN_consumidos = 0 THEN MIN_consumidos
--         ELSE 
--           IFNULL(
--             LEAST (MIN_Bolsa + (MIN_Sobrantes_Total / MIN_Faltantes_Total * MIN_Faltantes), MIN_consumidos),
--           MIN_Bolsa)
--       END AS MIN_Operador,
--       CASE
--         WHEN SMS_Cubiertos = 1 OR SMS_consumidos = 0 THEN SMS_consumidos
--         ELSE 
--           IFNULL(
--             LEAST(SMS_Bolsa + (SMS_Sobrantes_Total / SMS_Faltantes_Total * SMS_Faltantes),SMS_consumidos),
--           SMS_Bolsa)
--       END AS SMS_Operador,
--       CASE
--         WHEN GB_consumidos - IFNULL(
--           LEAST(GB_Bolsa + GB_Sobrantes_Total / IF(GB_Faltantes_Total * GB_Faltantes = 0,1,GB_Faltantes_Total * GB_Faltantes),GB_consumidos),GB_Bolsa
--         ) > 0 THEN 1
--         ELSE 0
--       END AS GB_Facturar,
--       CASE
--         WHEN MIN_consumidos - IFNULL(
--           LEAST( MIN_Bolsa + (MIN_Sobrantes_Total / IF(MIN_Faltantes_Total * MIN_Faltantes = 0,1,MIN_Faltantes_Total * MIN_Faltantes)),MIN_consumidos),MIN_Bolsa
--         ) > 0 THEN 1
--         ELSE 0
--       END AS MIN_Facturar,
--       CASE
--         WHEN SMS_consumidos - IFNULL(
--           LEAST(SMS_Bolsa + (SMS_Sobrantes_Total / IF(SMS_Faltantes_Total * SMS_Faltantes = 0,1,SMS_Faltantes_Total * SMS_Faltantes)),SMS_consumidos), SMS_Bolsa
--         ) > 0 THEN 1
--         ELSE 0
--       END AS SMS_Facturar,
--       -- MIN_consumidos_ONNET,
--       -- MIN_consumidos_OFNET
--     FROM `mm-commissions-reporting.TEMP.TRAFICO_PULLES_F_ADAMO`
--     )
--     SELECT *
--     FROM BOLSA
--;

--CARGA DE CDRS YA CATEGORIZADOS Y DE BOLSAS
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.TRAFICO_CDRS_FINAL_ADAMO`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS
  WITH
    CDRs_PRE AS (
      SELECT 
        agrupacion_canal,
        TIPO, 
        CAST(NULL AS STRING) AS CATEGORIZACION, 
        CDRS.COD_OP, 
        DESCRIPCION_AMBITO, 
        CAST(NULL AS STRING) AS DESTINO, 
        SOBRECATEGORIZACION, 
        CONV, 
        COSTE, 
        DURACION, 
        DATOS, 
        SMS, 
        CAST(NULL AS STRING) AS RED,
        --BOLSA.* EXCEPT(COD_OP)
      FROM `mm-commissions-reporting.TEMP.TRAFICO_CDRS_ADAMO` CDRS
      --LEFT JOIN `mm-commissions-reporting.TEMP.TRAFICO_BOLSAS_ADAMO` BOLSA ON BOLSA.COD_OP = CDRS.COD_OP
    ),

    --RETARIFICACIÓN DE CDRS UE, RETARIFICACIÓN DE CDRS NACIONALES Y REDUCCIÓN AL 60%

    CDRS_FINAL AS (
      SELECT 
        mes_int AS id_mes,
        PARSE_DATE('%Y%m%d', FORMAT('%06d01', mes_int)) AS mes_liqui,
        a.*, 
            -- CASE
            --   WHEN SOBRECATEGORIZACION = 'UE' AND CONV = 'OM' THEN
            --     CASE 
            --       WHEN TIPO = 'SMS' THEN exceso_sms_ue * SMS
            --       WHEN TIPO = 'DAT' THEN exceso_datos_ue * DATOS
            --       WHEN TIPO = 'VOZ' THEN exceso_voz_ue * DURACION
            --       ELSE COSTE
            --     END
        --       WHEN SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' THEN
        --         CASE 
        --           WHEN TIPO = 'SMS' THEN 
        --             CASE 
        --               WHEN SMS <= SMS_Operador OR SMS_Facturar = 0 THEN 0
        --               ELSE  exceso_sms_nac * (SMS - SMS_Operador)
        --             END
        --           WHEN TIPO = 'DAT' THEN 
        --             CASE 
        --               WHEN DATOS <= GB_Operador OR GB_Facturar = 0 THEN 0
        --               ELSE exceso_datos_nac * (DATOS - GB_Operador)
        --             END
        --           WHEN TIPO = 'VOZ' THEN 
        --             CASE 
        --               WHEN DURACION <= MIN_Operador OR MIN_Facturar = 0 THEN 0
        --               ELSE 0
                        
        --             END
        --           ELSE 
        --             CASE 
        --               WHEN CONV = 'OM' THEN COSTE * exceso_otros
        --               ELSE COSTE
        --             END
        --         END
        --       ELSE 
        --         CASE 
        --           WHEN CONV = 'OM' THEN COSTE * exceso_otros
        --           ELSE COSTE
        --         END

        -- END AS COSTE2

      -- CAMBIO DESPUES DEL PROBLEMA DE LA RETARIFICACION DE LOS EXCESOS DE FIBRA VALENCIA

          -- WHEN SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' THEN
          --       CASE 
          --         WHEN TIPO = 'SMS' THEN 
          --           CASE 
          --             WHEN SMS_consumidos_total <= SMS_bolsa_total OR SMS_Facturar = 0 THEN 0
          --             ELSE  exceso_sms_nac * SMS_Faltantes
          --           END
          --         WHEN TIPO = 'DAT' THEN 
          --           CASE 
          --             WHEN GB_consumidos_total <= GB_Bolsa_Total OR GB_Facturar = 0 THEN 0
          --             ELSE exceso_datos_nac * GB_Faltantes
          --           END
          --         WHEN TIPO = 'VOZ' THEN 
          --           -- CASE 
          --           --   WHEN MIN_CONSUMIDOS <= MIN_Operador OR MIN_Facturar = 0 THEN 0
          --           --   ELSE exceso_voz_nac * (MIN_CONSUMIDOS - MIN_Operador)
          --           CASE
          --             WHEN MIN_CONSUMIDOS_TOTAL <= MIN_BOLSA_TOTAL OR MIN_FACTURAR = 0 THEN 0
          --             ELSE exceso_voz_nac * MIN_FALTANTES
          --           END
          --         ELSE 
          --           CASE 
          --             WHEN CONV = 'OM' THEN COSTE * 0.60
          --             ELSE COSTE
          --           END
          --       END
          --     ELSE 
          --       CASE 
          --         WHEN CONV = 'OM' THEN COSTE * 0.60
          --         ELSE COSTE
          --       END

        --END AS COSTE2

        COSTE * 0.6 AS COSTE2


      FROM CDRS_PRE a
      -- LEFT JOIN `mm-commissions-reporting.B2B.TRAFICO_DATOS_BOLSA_ADAMO` b
      -- ON a.COD_OP = b.id_comisionista and b.id_mes = mes_int

    )
    SELECT *
  FROM CDRS_FINAL

;

--PESTAÑA CDRs FINAL DS

  DELETE `mm-commissions-reporting.B2B.TRAFICO_CDRS_FINAL_DS`
  WHERE id_mes = mes_int and agrupacion_canal = 'B2B - Adamo'
  ;

  INSERT INTO `mm-commissions-reporting.B2B.TRAFICO_CDRS_FINAL_DS`

    SELECT
      * EXCEPT(COSTE2),

      CAST(NULL AS FLOAT64) AS GB_Bolsa,
      CAST(NULL AS FLOAT64) AS MIN_Bolsa,
      CAST(NULL AS FLOAT64) AS SMS_Bolsa,

      CAST(NULL AS INT64) AS Clientes_Activos,

      CAST(NULL AS FLOAT64) AS GB_consumidos,
      CAST(NULL AS FLOAT64) AS MIN_consumidos,
      CAST(NULL AS FLOAT64) AS SMS_consumidos,
      CAST(NULL AS FLOAT64) AS MIN_consumidos_ONNET,
      CAST(NULL AS FLOAT64) AS MIN_consumidos_OFNET,

      CAST(NULL AS STRING) AS Codigo,

      CAST(NULL AS FLOAT64) AS GB_Global,

      CAST(NULL AS INT64) AS GB_Cubiertos,

      CAST(NULL AS FLOAT64) AS GB_Faltantes,
      CAST(NULL AS FLOAT64) AS GB_Sobrantes,
      CAST(NULL AS FLOAT64) AS MIN_Global,

      CAST(NULL AS INT64) AS MIN_Cubiertos,

      CAST(NULL AS FLOAT64) AS MIN_Faltantes,
      CAST(NULL AS FLOAT64) AS MIN_Sobrantes,
      CAST(NULL AS FLOAT64) AS SMS_Global,

      CAST(NULL AS INT64) AS SMS_Cubiertos,

      CAST(NULL AS FLOAT64) AS SMS_Faltantes,
      CAST(NULL AS FLOAT64) AS SMS_Sobrantes,
      CAST(NULL AS FLOAT64) AS GB_Bolsa_Total,
      CAST(NULL AS FLOAT64) AS GB_consumidos_Total,
      CAST(NULL AS FLOAT64) AS GB_Global_Reparto,
      CAST(NULL AS FLOAT64) AS GB_Faltantes_Total,
      CAST(NULL AS FLOAT64) AS GB_Sobrantes_Total,
      CAST(NULL AS FLOAT64) AS MIN_Bolsa_Total,
      CAST(NULL AS FLOAT64) AS MIN_consumidos_Total,
      CAST(NULL AS FLOAT64) AS MIN_Global_Reparto,
      CAST(NULL AS FLOAT64) AS MIN_Faltantes_Total,
      CAST(NULL AS FLOAT64) AS MIN_Sobrantes_Total,
      CAST(NULL AS FLOAT64) AS SMS_Bolsa_Total,
      CAST(NULL AS FLOAT64) AS SMS_consumidos_Total,
      CAST(NULL AS FLOAT64) AS SMS_Global_Reparto,
      CAST(NULL AS FLOAT64) AS SMS_Faltantes_Total,
      CAST(NULL AS FLOAT64) AS SMS_Sobrantes_Total,

      CAST(NULL AS INT64) AS Clientes_Activos_Total,

      CAST(NULL AS FLOAT64) AS GB_Operador,
      CAST(NULL AS FLOAT64) AS MIN_Operador,
      CAST(NULL AS FLOAT64) AS SMS_Operador,

      CAST(NULL AS INT64) AS GB_Facturar,
      CAST(NULL AS INT64) AS MIN_Facturar,
      CAST(NULL AS INT64) AS SMS_Facturar,

      COSTE2

    FROM `mm-commissions-reporting.B2B.TRAFICO_CDRS_FINAL_DS_ADAMO`;
  

  -- CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TRAFICO_CDRS_FINAL_DS_ADAMO` AS

  -- SELECT * FROM `mm-commissions-reporting.TEMP.TRAFICO_CDRS_FINAL_ADAMO`
  -- ;




--   CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TRAFICO_CDRS_FINAL_DS_ADAMO` AS


-- --PESTAÑA BOLSAS OM NACIONAL
--   DELETE `mm-commissions-reporting.B2B.TRAFICO_BOLSAS_DS_PRUEBA`
--   WHERE id_mes = mes_int
--   ;

--   INSERT INTO `mm-commissions-reporting.B2B.TRAFICO_BOLSAS_DS_PRUEBA` 

--   -- CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TRAFICO_BOLSAS_DS_ADAMO` AS
    
--     SELECT 
--       mes_int AS id_mes,
--       PARSE_DATE('%Y%m%d', FORMAT('%06d01', mes_int)) AS mes_liqui,
--       agrupacion_canal,
--       COD_OP,
--       b.nombre_comercio        AS nombre_operador,
--       IFNULL(MIN_Bolsa,0)      AS MIN_Bolsa, 
--       IFNULL(MIN_consumidos,0) AS MIN_consumidos,
--       IFNULL(MIN_Facturar,0)   AS MIN_Facturar,
--       IFNULL(GB_Bolsa,0)       AS GB_Bolsa,
--       IFNULL(GB_consumidos,0)  AS GB_consumidos,
--       IFNULL(GB_Facturar,0)    AS GB_Facturar,
--       IFNULL(SMS_Bolsa,0)      AS SMS_Bolsa,
--       IFNULL(SMS_consumidos,0) AS SMS_consumidos,
--       IFNULL(SMS_Facturar,0)   AS SMS_Facturar
--     FROM `mm-commissions-reporting.TEMP.TRAFICO_BOLSAS_ADAMO` a 
--     LEFT JOIN `mm-commissions-reporting.GS.DEALERS_TRAFICO_ADAMO` b ON a.COD_OP = b.id_comisionista

-- ;

--PESTAÑA COMISIONES

  DELETE `mm-commissions-reporting.B2B.TRAFICO_COMISIONES_DS`
  WHERE id_mes = mes_int and agrupacion_canal = 'B2B - Adamo'
  ;

  INSERT INTO `mm-commissions-reporting.B2B.TRAFICO_COMISIONES_DS` 

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TRAFICO_COMISIONES_DS_ADAMO` AS

    SELECT 
      mes_int AS id_mes,
      PARSE_DATE('%Y%m%d', FORMAT('%06d01', mes_int)) mes_liqui,
      d.agrupacion_canal,
      a.COD_OP AS COD_OP,
      UPPER(d.nombre_comercio) AS nombre_comercio,
      SUM(
        CASE
          WHEN CONV2 = 'OM' AND numero_tx is not null THEN 1
          ELSE 0
        END
      ) AS clientes_activos_OM,
      SUM(
        CASE
          WHEN CONV2 = 'FMC' THEN 1
          ELSE 0
        END
      ) AS clientes_activos_FMC,
      SUM(Total_Facturacion)-(SUM(Cdrs_voz_Importe)+SUM(Cdrs_datos_Importe)+SUM(Cdrs_sms_Importe)) AS FACT_BASE_TARIFAS,
      (SUM(Cdrs_voz_Importe)+SUM(Cdrs_datos_Importe)+SUM(Cdrs_sms_Importe)) AS FACT_CDRs,
      SUM(Total_Facturacion) AS TOTAL_FACT_EMITIDA,
      b.Total_Tarifa_NA AS FACT_BASE_NUEVA,
      COALESCE(COSTE2,0) AS FACT_CDRS_SEG_ADENDA,
      b.Total_Tarifa_NA + COALESCE(COSTE2,0) AS FACT_TOTAL_SEG_ACUERDO,
      1 - ((b.Total_Tarifa_NA + COALESCE(COSTE2,0))/IF(SUM(Total_Facturacion) =0,1,SUM(Total_Facturacion))) AS PORCENTAJE_COMISION,
      (1 - ((b.Total_Tarifa_NA + COALESCE(COSTE2,0))/IF(SUM(Total_Facturacion) =0,1,SUM(Total_Facturacion))))* SUM(Total_Facturacion)  AS COMISION_NETA
    FROM `mm-commissions-reporting.TEMP.TRAFICO_INFORME_IWONA_ADAMO` a
    LEFT JOIN (
      SELECT COD_OP,
        SUM(Total_Tarifa_NA) AS Total_Tarifa_NA
      FROM `mm-commissions-reporting.TEMP.TRAFICO_INFORME_IWONA_NUEVO_PVP_ADAMO`
      GROUP BY ALL
    ) b ON a.COD_OP = b.COD_OP
    LEFT JOIN (
      SELECT 
        COD_OP,
        SUM(COSTE2) AS COSTE2
      FROM `mm-commissions-reporting.TEMP.TRAFICO_CDRS_FINAL_ADAMO`
      GROUP BY ALL
      ) c ON a.COD_OP = c.COD_OP
    JOIN `mm-commissions-reporting.GS.DEALERS_TRAFICO_ADAMO` d ON a.COD_OP = d.id_comisionista
    GROUP BY a.COD_OP, b.Total_Tarifa_NA, COSTE2, d.nombre_comercio, d.agrupacion_canal
;
--PESTAÑA INFORMACIÓN FACTURACIÓN BASE

  DELETE `mm-commissions-reporting.B2B.TRAFICO_INFORME_IWONA_NUEVO_PVP_DS`
  WHERE id_mes = mes_int and agrupacion_canal = 'B2B - Adamo'
  ;

  INSERT INTO `mm-commissions-reporting.B2B.TRAFICO_INFORME_IWONA_NUEVO_PVP_DS` 

  -- CREATE OR REPLACE TABLE `mm-commissions-reporting.B2B.TRAFICO_INFORME_IWONA_NUEVO_PVP_DS_ADAMO` AS

    SELECT 
      a.data_month_id AS id_mes,
      PARSE_DATE('%Y%m%d', FORMAT('%06d01', mes_int)) AS mes_liqui,
      d.agrupacion_canal,
      COD_OP,
      d.nombre_comercio,
      SubCliente,
      Fecha_Activacion,
      NUMERO_TX,
      Tarifa_ID,
      Total_Base,
      a.Total_Tarifa_NA,
      Min_inc,
      GB_inc,
      SMS_inc,
      Bonos_Voz_Descripcion,
      Bonos_SMS_Descripcion,
      Bonos_Datos_Descripcion,	
      Bono_Compartido_ID,	
      Bono_Compartido_Descripcion
    FROM `mm-commissions-reporting.TEMP.TRAFICO_INFORME_IWONA_NUEVO_PVP_ADAMO` a
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_TRAFICO_ADAMO` d ON a.COD_OP = d.id_comisionista
  ;


END