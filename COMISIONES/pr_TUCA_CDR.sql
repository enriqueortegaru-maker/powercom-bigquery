BEGIN

DECLARE finMes,inicioMes DATE;
DECLARE mes_int,dias_var INT64;
DECLARE datos_pull FLOAT64;


SET mes_int = 202505;
SET finMes = LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH));
SET inicioMes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);
SET dias_var = DATE_DIFF(finMes,inicioMes,DAY)+1;
SET datos_pull = 11.1; --GIGAS APORTADOS CADA MES, CADA MES SON 100 MB MÁS

-- call `mm-commissions-reporting.COMISIONES.pr_TUCA_CDR`()


--PRIMERA LECTURA DE CDRS Y CLASIFICACIÓN
--CDRS:
WITH 
  CDRS AS (
    SELECT 
      COP_OP AS COD_OP, 
      DESCRIPCION_AMBITO,
      DESTINO,
      CASE
        WHEN DESCRIPCION_AMBITO = 'Roaming' THEN
          CASE 
            WHEN DESTINO LIKE '% UE%' OR DESTINO = 'Roaming desde Zona 1' THEN 'UE'
            WHEN DESTINO LIKE '%Term.%' THEN 'ROAMING TERMINAL'
            ELSE 'ROAMING'
          END
        WHEN DESCRIPCION_AMBITO IN ('Datos', 'Moviles','Nacionales') THEN 
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
      IF(DATOS IS NULL,0,DATOS)/(1024*1024*1024) AS DATOS,
      SMS as SMS,
      DESTINO AS CATEGORIZACION,
      RED
    FROM `mm-commissions-reporting.TEMP.TUCA_x_202504` a
    LEFT JOIN (
        SELECT *
        FROM `mm-commissions-reporting.TEMP.TUCA_Sobrecategorizacion`
        QUALIFY ROW_NUMBER() OVER(PARTITION BY TIPO, CATEGORIZACION) = 1
      ) b ON a.TIPO = b.TIPO AND a.DESTINO = b.CATEGORIZACION 
  ),

--PRIMERA CARGA INFORME IWONA Y CATEGORIZACIÓN DE DUPLICADOS Y CALCULO DE DIAS ACTIVO

  informe_iwona AS (
    SELECT x.*  except (Bono, Fecha_Activacion),
      CASE
        WHEN CAST(PARSE_DATE('%Y%m%d',Fecha_Activacion) AS STRING) = x.Cliente THEN b.activation_date
        ELSE PARSE_DATE('%Y%m%d',Fecha_Activacion)
      END AS Fecha_Activacion
    FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*` x
    LEFT JOIN `mm-b2b-reporting.MAESTROS.Maestro_B2B` m ON x.Cliente = m.customer_id_xena
    LEFT JOIN (
      SELECT phone_nm,
        account_id,
        activation_date
      FROM `mm-datamart-kd.SERVICES.service_base_net`
      WHERE comm_brand_ds = 'CABLEMOVIL'
        --'618549989'
      QUALIFY ROW_NUMBER() OVER(PARTITION BY account_id, phone_nm ORDER BY activation_date DESC) = 1
    ) b ON x.MSISDN = CAST(b.phone_nm AS STRING) AND x.SubCliente = b.account_id
    WHERE m.grupo = "TUCA"
      AND data_month_id = mes_int
  ),

  iwona_pre AS (
    SELECT
      a.Msisdn AS NUMERO_TX, 
      --Se elimina la lógica de Primero y se implanta un QUALIFY para quedarnos con la primera aparición (activación)
      --IsNull(Lookup('NUMERO_TX','NUMERO_TX',Msisdn)) as Primero,
      ROW_NUMBER() OVER() AS fila_iwo,
      data_month_id, 
      Orden, 
      Upper(a.Cliente) AS COD_OP, 
      a.SubCliente, 

      Fecha_Activacion, 
      CASE
        WHEN Fecha_Activacion > inicioMes THEN DATE_DIFF(finMes, DATE_ADD(Fecha_Activacion, INTERVAL 1 DAY), DAY)
        ELSE DATE_DIFF(finMes, DATE_ADD(inicioMes, INTERVAL 1 DAY), DAY)
      END AS Dias,
        
      Tarifa_ID, 
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
      --//IF(Msisdn='',0,4.5) as Total_Tarifa_NA,
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
    --Hay datos con fechas de activación de Abril que no corresponden a la liquidación de marzo. Si se obvian el número final de cableros disminuye de 26 a 22. La resta de las fecha da un número negativo, es correcto?
    --WHERE Fecha_Activacion BETWEEN inicioMes AND finMes
    --Se hace la partición con los valores no nulos, los nulos se quedan.
    QUALIFY ROW_NUMBER() OVER(PARTITION BY IF(MSISDN IS NULL, GENERATE_UUID(), MSISDN) ORDER BY Fecha_Activacion ASC) = 1
  )
    -- SELECT *
    -- FROM iwona_pre
  ,

--SEGUNDA LECTURA DE INFORME IWONA, INDICANDO EL NUEVO PVP, MINUTOS, SMS Y GIGAS PARA LA PRIMERA APARICIÓN DEL NÚMERO NO 3P, TODO PRORRATEADO PARA 'F0079*'
  iwona_pre_2 AS (
    SELECT
      *,
      CASE
        WHEN Tarifa_ID NOT LIKE '%3P%' AND Bono_Compartido_Descripcion NOT LIKE '%3P%' THEN
          CASE
            WHEN NUMERO_TX = '' THEN 0
            WHEN COD_OP LIKE 'F0079%' THEN GREATEST(4.25 * Dias / dias_var, 0)
            ELSE 4.25
          END
        ELSE Total_Facturacion - Cdrs_voz_Importe - Cdrs_datos_Importe - Cdrs_sms_Importe
      END AS Total_Tarifa_NA,

      CASE
        WHEN Tarifa_ID NOT LIKE '%3P%' AND Bono_Compartido_Descripcion NOT LIKE '%3P%' THEN
          CASE
            WHEN NUMERO_TX = '' THEN 0
            WHEN COD_OP LIKE 'F0079%' THEN GREATEST(datos_pull * Dias / dias_var, 0)
            ELSE datos_pull
          END
        ELSE 0
      END AS GB_inc,

      CASE
        WHEN Tarifa_ID NOT LIKE '%3P%' AND Bono_Compartido_Descripcion NOT LIKE '%3P%' THEN
          CASE
            WHEN NUMERO_TX = '' THEN 0
            WHEN COD_OP LIKE 'F0079%' THEN GREATEST(200 * Dias / dias_var, 0)
            ELSE 200
          END
        ELSE 0
      END AS Min_inc,

      CASE
        WHEN Tarifa_ID NOT LIKE '%3P%' AND Bono_Compartido_Descripcion NOT LIKE '%3P%' THEN
          CASE
            WHEN NUMERO_TX = '' THEN 0
            WHEN COD_OP LIKE 'F0079%' THEN GREATEST(200 * Dias / dias_var, 0)
            ELSE 200
          END
        ELSE 0
      END AS SMS_inc
    FROM iwona_pre
  ),

--ACUMULADO POR OPERADOR DE LAS BOLSAS CREADAS

  PULLES_PRE AS (
    SELECT
      a.COD_OP,
      SUM(GB_inc) AS GB_Bolsa,
      SUM(Min_inc) AS MIN_Bolsa,
      SUM(SMS_inc) AS SMS_Bolsa,
      COUNT(DISTINCT NUMERO_TX) AS Clientes_Activos,
      GB_consumidos,
      MIN_consumidos,
      SMS_consumidos,
      MIN_consumidos_ONNET,
      MIN_consumidos_OFNET
    FROM iwona_pre_2 a
    LEFT JOIN (
      SELECT 
        COD_OP,
        SUM(DATOS) AS GB_consumidos,
        SUM(DURACION) AS MIN_consumidos,
        SUM(SMS) AS SMS_consumidos
      FROM CDRS
      WHERE SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' 
      GROUP BY ALL
    ) b ON a.COD_OP = b.COD_OP
    LEFT JOIN (
      SELECT 
        COD_OP,
        SUM(DURACION) AS MIN_consumidos_ONNET
      FROM CDRS
      WHERE SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' AND RED = 'ONNET'
      GROUP BY ALL
    ) c ON a.COD_OP = c.COD_OP
    LEFT JOIN(
      SELECT
        COD_OP,
        SUM(DURACION) AS MIN_consumidos_OFNET
      FROM CDRS
      WHERE SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' AND RED = 'OFFNET'
      GROUP BY ALL
    ) d ON a.COD_OP = d.COD_OP
    GROUP BY ALL
  ),

--CALCULO COMPARATIVO GLOBAL Y POR OPERADOR PARA SACAR SUS GB/MIN/SMS APORTADOS, CUBIERTOS Y SOBRANTES

  PULLES AS (
    SELECT *,
    'TOTAL' AS Codigo,
      GB_Bolsa - GB_consumidos AS GB_Global,
      IF((GB_Bolsa - GB_consumidos) > 0,1,0) AS GB_Cubiertos,
      IF((GB_Bolsa - GB_consumidos) > 0,0,GB_consumidos - GB_Bolsa) AS GB_Faltantes,
      IF((GB_Bolsa - GB_consumidos) > 0,GB_Bolsa - GB_consumidos,0) AS GB_Sobrantes,
      MIN_Bolsa - MIN_consumidos AS MIN_Global,
      IF((MIN_Bolsa - MIN_consumidos) > 0,1,0) AS MIN_Cubiertos,
      IF((MIN_Bolsa - MIN_consumidos) > 0,0,MIN_consumidos - MIN_Bolsa) AS MIN_Faltantes,
      IF((MIN_Bolsa - MIN_consumidos) > 0,MIN_Bolsa - MIN_consumidos,0) AS MIN_Sobrantes,
      SMS_Bolsa - SMS_consumidos AS SMS_Global,
      IF((SMS_Bolsa - SMS_consumidos) > 0,1,0) AS SMS_Cubiertos,
      IF((SMS_Bolsa - SMS_consumidos) > 0,0,SMS_consumidos - SMS_Bolsa) AS SMS_Faltantes,
      IF((SMS_Bolsa - SMS_consumidos) > 0,SMS_Bolsa - SMS_consumidos,0) AS SMS_Sobrantes
    FROM PULLES_PRE
  ),

  PULLES_F AS (
    SELECT *
    FROM PULLES a
    LEFT JOIN(
      SELECT
        'TOTAL' AS Codigo,
        SUM(GB_Bolsa) AS GB_Bolsa_Total, --Total GB aportados
        SUM(GB_consumidos) AS GB_consumidos_Total, --Total GB consumidos a cubrir
        sum(GB_Global) AS GB_Global_Reparto, --GB sobrantes o faltantes totales

        SUM(GB_Faltantes) AS GB_Faltantes_Total, 
        sum(GB_Sobrantes) AS GB_Sobrantes_Total,

        SUM(MIN_Bolsa) AS MIN_Bolsa_Total, 
        SUM(MIN_consumidos) AS MIN_consumidos_Total,
        SUM(MIN_Global) AS MIN_Global_Reparto,

        SUM(MIN_Faltantes) AS MIN_Faltantes_Total, 
        SUM(MIN_Sobrantes) AS MIN_Sobrantes_Total,

        SUM(SMS_Bolsa) AS SMS_Bolsa_Total,
        SUM(SMS_consumidos) AS SMS_consumidos_Total,
        SUM(SMS_Global) AS SMS_Global_Reparto,

        SUM(SMS_Faltantes) AS SMS_Faltantes_Total, 
        SUM(SMS_Sobrantes) AS SMS_Sobrantes_Total,

        SUM(Clientes_Activos) AS Clientes_Activos_Total
      FROM PULLES
    ) b ON a.codigo = b.codigo
  ),
  
--CALCULO DE LOS GB/MIN/SMS A FACTURAR A CADA OPERADOR

  BOLSA AS (
    SELECT
      --COD_OP,
      *,
      CASE
        WHEN GB_Cubiertos = 1 OR GB_consumidos = 0 THEN GB_consumidos
        ELSE 
          IFNULL(
            LEAST(
              GB_Bolsa + (GB_Sobrantes_Total / GB_Faltantes_Total * GB_Faltantes), GB_consumidos),
          GB_Bolsa)
      END AS GB_Operador,
      CASE
        WHEN MIN_Cubiertos = 1 OR MIN_consumidos = 0 THEN MIN_consumidos
        ELSE 
          IFNULL(
            LEAST (MIN_Bolsa + (MIN_Sobrantes_Total / MIN_Faltantes_Total * MIN_Faltantes), MIN_consumidos),
          MIN_Bolsa)
      END AS MIN_Operador,
      CASE
        WHEN SMS_Cubiertos = 1 OR SMS_consumidos = 0 THEN SMS_consumidos
        ELSE 
          IFNULL(
            LEAST(SMS_Bolsa + (SMS_Sobrantes_Total / SMS_Faltantes_Total * SMS_Faltantes),SMS_consumidos),
          SMS_Bolsa)
      END AS SMS_Operador,
      CASE
        WHEN GB_consumidos - IFNULL(
          LEAST(GB_Bolsa + (GB_Sobrantes_Total / GB_Faltantes_Total * GB_Faltantes),GB_consumidos),GB_Bolsa
        ) > 0 THEN 1
        ELSE 0
      END AS GB_Facturar,
      CASE
        WHEN MIN_consumidos - IFNULL(
          LEAST( MIN_Bolsa + (MIN_Sobrantes_Total / MIN_Faltantes_Total * MIN_Faltantes),MIN_consumidos),MIN_Bolsa
        ) > 0 THEN 1
        ELSE 0
      END AS MIN_Facturar,
      CASE
        WHEN SMS_consumidos - IFNULL(
          LEAST(SMS_Bolsa + (SMS_Sobrantes_Total / SMS_Faltantes_Total * SMS_Faltantes),SMS_consumidos), SMS_Bolsa
        ) > 0 THEN 1
        ELSE 0
      END AS SMS_Facturar,
      --MIN_consumidos_ONNET,
      --MIN_consumidos_OFNET
    FROM PULLES_F
  ),

  --CARGA DE CDRS YA CATEGORIZADOS Y DE BOLSAS
  CDRs_PRE AS (
    SELECT 
      TIPO, 
      CATEGORIZACION, 
      CDRS.COD_OP, 
      DESCRIPCION_AMBITO, 
      DESTINO, 
      SOBRECATEGORIZACION, 
      CONV, 
      COSTE, 
      DURACION, 
      DATOS, 
      SMS, 
      RED,
      BOLSA.*
    FROM CDRS
    LEFT JOIN BOLSA ON BOLSA.COD_OP = CDRS.COD_OP
  ),

  --RETARIFICACIÓN DE CDRS UE, RETARIFICACIÓN DE CDRS NACIONALES Y REDUCCIÓN AL 60%

  CDRS_FINAL AS (
    SELECT *,
      CASE 
        WHEN SOBRECATEGORIZACION = 'UE' AND CONV = 'OM' THEN
          CASE 
            WHEN TIPO = 'SMS' THEN 0.003 * SMS
            WHEN TIPO = 'DAT' THEN 1.3 * DATOS
            WHEN TIPO = 'VOZ' THEN 0.019 * DURACION
            ELSE COSTE
          END
        WHEN SOBRECATEGORIZACION = 'NACIONAL' AND CONV = 'OM' THEN
          CASE 
            WHEN TIPO = 'SMS' THEN 
              CASE 
                WHEN SMS <= SMS_Operador OR SMS_Facturar = 0 THEN 0
                ELSE 0.01 * (SMS - SMS_Operador)
              END
            WHEN TIPO = 'DAT' THEN 
              CASE 
                WHEN DATOS <= GB_Operador OR GB_Facturar = 0 THEN 0
                ELSE 0.55 * (DATOS - GB_Operador)
              END
            WHEN TIPO = 'VOZ' THEN 
              CASE 
                WHEN DURACION <= MIN_Operador OR MIN_Facturar = 0 THEN 0
                ELSE 
                  CASE 
                    WHEN RED = 'OFFNET' THEN 
                      0.00826 * MIN_consumidos_OFNET * (DURACION - MIN_Operador) / (MIN_consumidos_ONNET + MIN_consumidos_OFNET)
                    ELSE 
                      0.0026 * MIN_consumidos_ONNET * (DURACION - MIN_Operador) / (MIN_consumidos_ONNET + MIN_consumidos_OFNET)
                  END
              END
            ELSE 
              CASE 
                WHEN CONV = 'OM' THEN COSTE * 0.60
                ELSE COSTE
              END
          END
        ELSE 
          CASE 
            WHEN CONV = 'OM' THEN COSTE * 0.60
            ELSE COSTE
          END
      END AS COSTE2
      -- IF(SOBRECATEGORIZACION='UE' AND CONV='OM',
      --   IF(TIPO='SMS',
      --     --0.004*SMS, 
      --     0.003*SMS, 
      --   IF(TIPO='DAT',
      --       --1.55*DATOS,
      --     1.3*DATOS, 
      --   IF(TIPO='VOZ',
      --         -- 0.022*DURACION,
      --           0.019*DURACION,
      --           COSTE))),
      -- IF(SOBRECATEGORIZACION='NACIONAL' AND CONV='OM',
      --     IF(TIPO='SMS',
      --       IF(SMS<=SMS_Operador or SMS_Facturar=0,0,0.01*(SMS-SMS_Operador)),--'ALGO CON LOS SMS', 
      --     IF(TIPO='DAT',
      --       IF(DATOS<=(GB_Operador)or GB_Facturar=0,0,0.55*(DATOS-GB_Operador)),--'ALGO CON LOS DAT', 
      --     IF(TIPO='VOZ',
      --       IF(DURACION<=(MIN_Operador)or MIN_Facturar=0,0,
      --     IF(RED='OFFNET',0.00826*MIN_consumidos_OFNET*(DURACION-MIN_Operador)/(MIN_consumidos_ONNET+MIN_consumidos_OFNET),0.0026*MIN_consumidos_ONNET*(DURACION-MIN_Operador)/(MIN_consumidos_ONNET+MIN_consumidos_OFNET))),-- 'ALGO CON LA VOZ', 
      --     IF(CONV='OM',COSTE*0.60,COSTE)))),
      --     IF(CONV='OM',COSTE*0.60,COSTE))) as COSTE2

    FROM CDRS_PRE
  )


SELECT *
FROM bolsa
WHERE 1=1
 --AND COD_OP LIKE 'F0079%'
--AND Tarifa_ID NOT LIKE '%3P%' AND Bono_Compartido_Descripcion NOT LIKE '%3P%'
  --Tarifa_id LIKE '%3P%'
--FROM `mm-commissions-reporting.TEMP.TUCA_Sobrecategorizacion`

;
END