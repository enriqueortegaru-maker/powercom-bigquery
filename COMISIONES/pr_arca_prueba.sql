BEGIN

DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARCA1'; 

SET canales_pr = ['CM','CALT'];

-- call `mm-commissions-reporting.COMISIONES.pr_arca_prueba`(202609,['CM','CALT']);

-------------------------------------------------------------------------------VALIDACIONES----------------------------------------------------------------------------------------

  --🔸 Validador 1: Verificar que están todos los cableros en deales

  ASSERT NOT EXISTS(--ASSERT agregado a App Script
    SELECT DISTINCT comm_brand_ds, customer_id, MAX(invoice_date), b.id_comisionista
    FROM `mm-datamart-kd.BILLING.billing_detail_net`a
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` b ON a.customer_id = b.id_comisionista
    WHERE comm_brand_ds = 'CABLEMOVIL' 
      AND NOT (customer_id  LIKE 'M%' OR customer_id  LIKE 'V%' OR customer_id  LIKE 'W%')
      AND a.invoice_date >= '2024-01-01'
      AND a.customer_id NOT IN ('216517','C53093')
      AND b.id_comisionista IS NULL
    GROUP BY 1,2, b.id_comisionista
    ORDER BY 2
  ) AS 'Falta añadir nuevos distribuidores.'
  ;

  --🔸 Validador 2: Verificar que están agregados todos los cableros de AUTOFACTURA en deales

  ASSERT NOT EXISTS(
    SELECT id_comisionista, COD_XENA
      FROM `mm-commissions-reporting.GS.AUTOFACTURA_CABLEMOVIL` a
    LEFT JOIN (
      SELECT id_comisionista
      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` 
    ) b ON b.id_comisionista = a.cod_xena
    WHERE 1=1
      AND DEALERS_COM != '0'
      AND b.id_comisionista IS NULL
  ) AS 'Falta añadir nuevos distribuidores de la pestaña de Autofactura.'
  ;

  --🔸 Validador 3: Verificar que están todos los cableros de AVATEL estén en su pestaña correspondiente

  ASSERT NOT EXISTS(
    SELECT a.id_comisionista, a.nombre_comercio
      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` a
    LEFT JOIN (
      SELECT id_comisionista, nombre_comercio
      FROM `mm-commissions-reporting.GS.AVATEL_CABLEMOVIL`
    ) b ON b.id_comisionista = a.id_comisionista
    WHERE 1=1
      AND a.documento = 'A93135218'
      AND b.id_comisionista IS NULL
  ) AS 'Falta añadir nuevos distribuidores de la pestaña de Avatel.'
  ;

-----------------------------------------------------------------------------FIN VALIDACIONES--------------------------------------------------------------------------------------

  -- Preparamos a los dealers, cogiendo los cambios de airtime y clasificándolos según el tipo de operador: estandar, trafico o generales(avatel, ahi+)

  -- Borramos del histórico el mes que estamos lanzando mes_int

    ------------Añadir un assert para que si no hay coincidencias en la
DELETE `mm-commissions-reporting.TEMP.cableoperadores_airtime_historico` 
WHERE id_mes = mes_int;


  -- Calculamos la tabla que vamos a insertar en el histórico 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cableoperadores_airtime_mes` AS (

        SELECT 
        mes_int as id_mes,
        cm.id_comisionista,
        cm.canal,
        razon_social,
        documento,
        auto,
        cond_pago,
        UPPER(cm.nombre_comercio) AS nombre_comercio,
        IF(zona_fiscal = '#N/A','PEN',zona_fiscal) AS zona_fiscal,
        ---Estandar
        CASE
         WHEN general.id_comisionista IS NULL AND trafico.COD_OP IS NULL THEN 1
         ELSE 0
        END AS estandar,
        CASE
         WHEN general.id_comisionista IS NULL AND trafico.COD_OP IS NULL  THEN COALESCE(estandar.porcentaje_estandar, 20)
         ELSE CAST(NULL AS INT64)
        END AS porcentaje_estandar,
        ---General
        CASE
         WHEN general.id_comisionista IS NOT NULL THEN 1
         ELSE 0
        END AS general,
        CASE
         WHEN general.id_comisionista IS NOT NULL THEN general.porcentaje_avatel
         ELSE CAST(NULL AS INT64)
        END AS porcentaje_general,
        ---Trafico
        CASE
         WHEN trafico.COD_OP IS NOT NULL THEN 1
         ELSE 0
        END AS trafico,
        CASE
         WHEN trafico.COD_OP IS NOT NULL THEN trafico.PORCENTAJE_COMISION
         ELSE 0
        END AS porcentaje_trafico,

      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` cm

      LEFT JOIN `mm-commissions-reporting.GS.AVATEL_CABLEMOVIL` general
        ON cm.id_comisionista = general.id_comisionista

      LEFT JOIN `mm-commissions-reporting.B2B.TRAFICO_COMISIONES_DS` trafico
        ON  cm.id_comisionista = trafico.COD_OP
        AND trafico.id_mes = mes_int

      LEFT JOIN `mm-commissions-reporting.GS.Porcentajes_Estandar` estandar
        ON  cm.id_comisionista = estandar.id_comisionista
        AND estandar.id_mes = mes_int

      WHERE comisiona IS TRUE AND check_duplicados = '1'

);
  -- Insertamos en el histórico
INSERT `mm-commissions-reporting.TEMP.cableoperadores_airtime_historico` 

  SELECT *
  FROM `mm-commissions-reporting.TEMP.cableoperadores_airtime_mes`
;

  -- Listo dealers, cogemos las bases de las comisiones tanto de id_mes como del id_mes del mes pasado por si nos hemos dejado algo sin comisionar
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cableoperadores_base_id_mes` AS(
      SELECT *
      FROM `mm-commissions-reporting.B2B.comisiones_base_arca_*` 
      WHERE 1=1
        AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
        AND origen_info = 'mes_actual'
        AND n_control = 1
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cableoperadores_base_id_mes_anterior` AS(
      SELECT *
      FROM `mm-commissions-reporting.B2B.comisiones_base_arca_*` --base_inicial
      WHERE 1=1
        AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
        AND origen_info = 'mes_anterior'
        AND n_control = 1

);

  -- Recreamos el histórico de tarifas
  ----------- Antes de lanzar hacia atrás cuidado con las fechas aquí por que se puede recrear el historico. Hacer un assert o un if para que no borre
DELETE `mm-commissions-reporting.TEMP.Tarifas_CM`
WHERE id_mes = mes_int;

INSERT `mm-commissions-reporting.TEMP.Tarifas_CM` (
  SELECT 
  mes_int AS id_mes,
  * 
  FROM `mm-commissions-reporting.GS.Tarifas_CM` 

);


--🔸 Validador 4: Verificar que lo que está en base cartera y no cruza con las tarifas, no tiene que comisionar

  ASSERT (
    SELECT COUNT(*)
    FROM `mm-commissions-reporting.TEMP.cableoperadores_base_id_mes` base

    LEFT JOIN `mm-commissions-reporting.TEMP.cableoperadores_airtime_mes` dealers
        ON base.CLIENTE = dealers.id_comisionista
        AND base.id_mes = dealers.id_mes
  
    LEFT JOIN `mm-commissions-reporting.TEMP.Tarifas_CM` tarifas
      ON base.tariff_id = tarifas.Id_Tarifa
      AND tarifas.id_mes = mes_int
  
    WHERE tarifas.Id_Tarifa IS NULL
      AND base.tariff_id IS NOT NULL
      AND base.imp_without_tax <> 0
      AND base.tariff_id not like 'CP%'
      AND dealers.trafico = 0 --Hay tarifas que son solo de trafico, nos quitamos esto
  ) = 0 AS 'Hay tarifas de base cartera que no cruzan con el listado de tarifas, pero que tienen facturacion'
;

--🔸 Validador 5: Verificar que no hay bonos duplicados por id_mes

  ASSERT NOT EXISTS (
  SELECT 1
  FROM `mm-commissions-reporting.TEMP.Tarifas_CM`
  WHERE Id_Tarifa != 'MA_CABLE_CONTIGO'
  AND id_mes = mes_int
  GROUP BY id_mes, Id_Tarifa
  HAVING COUNT(*) > 1
  ) AS 'Hay bonos duplicados'
;
 
  -- Empezamos a construir con estructura transacciones 
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cableoperadores_b_arca` AS(

      SELECT
      'calculado' AS estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) AS mes_liquidado,
      mes_int AS id_mes,
      CASE
          WHEN dealers.CANAL = 'CALT' THEN 'B2B - Cablemovil Alterna'
          ELSE 'B2B - Cablemovil'
      END AS agrupacion_canal,
      dealers.canal AS canal,
      --- Concepto
      CASE
        WHEN dealers.trafico = 1
          OR dealers.general = 1
          OR dealers.estandar = 1
        THEN
        CONCAT(
          'C - Gestion Cartera ',

          CASE
      
            WHEN base.bundle_type = 'MO' THEN 'Movil'
      
            WHEN base.bundle_type = 'FMC' THEN
              CASE
                WHEN base.billing_tier_2 LIKE '%3P%' THEN '3P'
                WHEN base.tariff_ds LIKE '%AD3P%'
                  OR base.tariff_ds LIKE '%ADICIONAL%3P%CABLEMOVIL%' THEN '3P'
                WHEN base.billing_tier_2 LIKE '%DATOS ADICIONAL%' THEN 'Movil'
                WHEN base.billing_tier_2 LIKE '%PROMO%'
                     AND base.comments = '3P' THEN 'Movil'
                WHEN base.billing_tier_2 LIKE '%CONV%' THEN 'Conv'
                ELSE '3P'
              END
          END,

          ' (',

          CASE
            --Trafico
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.trafico = 1 THEN ROUND(dealers.porcentaje_trafico*100, 2)
            --Avatel, Ahi+ y generales
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.general = 1 THEN dealers.porcentaje_general

            --Alternos, aplican como avatel y Ahi+ Pero las 3P no se pagan
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CALT' THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END

            ---Aprop TOXO Y XEC se comportan como alternos:
              WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.id_comisionista in ('F00764','F00765','F46758','F00692') THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END

            --Estandar
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CM' THEN
              CASE
                -- Tarifas especiales
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL AND tarifas_especiales.id_comisionista IS NOT NULL THEN tarifas_especiales.porcentaje_especiales
                -- Existe tarifa especial pero no para ese cableoperador
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL THEN 0

                -- No existe tarifa especial: aplicar reglas estándar
                WHEN tarifas_especiales.Id_tarifa IS NULL THEN
                  CASE

                --Tarifas Fijas a 0
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 0

                --Tarifas Fijas distintas de 0
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo != 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      CASE
                    --GRELO Y WIFITECH: Adicionales 3P van al 45 ADICIONAL_3P_3 CABLEMOVIL
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                    --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                        ELSE tarifas.porcentaje_fijo
                      END

                --Tarifas Estándar distintas de 0
                    WHEN tarifas.porcentaje_estandar != 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      --Casos especiales para algunos distribuidores estandar
                      CASE
                      --GRELO Y WIFITECH: Adicionales 3P van al 45
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                      --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                      --Call2world no le pagamos el bono B0934 porque la info no se sube a billing a tiempo
                      WHEN base.tariff_id = 'B0934' and dealers.id_comisionista = '202067' THEN 0
                      --Adicionales 3P van al 20
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') THEN 20
                        
                        ELSE dealers.porcentaje_estandar
                        
                      END
                    
                --PROMOS 3P van al 20% y no están en el muestrario de Bea
                    WHEN tarifas.Id_tarifa IS NULL AND base.tariff_id like 'CP%' THEN  
                      CASE WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%PROMO%'  THEN 20
                      ELSE dealers.porcentaje_estandar
                      END

                  END
              END
          END,

          '%)'
        ) END AS concepto,

      'AIRT' AS tipo_concepto,
      1 AS unidades,
      --- Comision
       base.imp_without_tax*(
       CASE
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.trafico = 1 THEN ROUND(dealers.porcentaje_trafico*100, 6)
            WHEN UPPER(base.billing_tier_2) = 'CUOTA MANTENIMIENTO LINEA'  THEN 0
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.general = 1 THEN dealers.porcentaje_general

            --Alternos, aplican como avatel y Ahi+ Pero las 3P no se pagan
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CALT' THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END

            ---Aprop TOXO Y XEC se comportan como alternos:
              WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.id_comisionista in ('F00764','F00765','F46758','F00692') THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END

            --Estandar
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CM' THEN
              CASE
                -- Tarifas especiales
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL AND tarifas_especiales.id_comisionista IS NOT NULL THEN tarifas_especiales.porcentaje_especiales

                -- Existe tarifa especial pero no para ese cableoperador
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL THEN 0

                -- No existe tarifa especial: aplicar reglas estándar
                WHEN tarifas_especiales.Id_tarifa IS NULL THEN
                  CASE
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 0
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo != 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      CASE
                      --GRELO Y WIFITECH: Adicionales 3P van al 45
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                      --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                        ELSE tarifas.porcentaje_fijo
                      END
                    WHEN tarifas.porcentaje_estandar != 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      --Casos especiales para algunos distribuidores estandar
                      CASE
                      --GRELO Y WIFITECH: Adicionales 3P van al 45
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                      --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                      --Call2world no le pagamos el bono B0934 porque la info no se sube a billing a tiempo
                        WHEN base.tariff_id in ('MA_CABLE_CABLENET','B0934') and dealers.id_comisionista = '202067' THEN 0
                      --Adicionales 3P van al 20
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') THEN 20
                        
                        ELSE dealers.porcentaje_estandar
                        
                      END
                    --PROMOS 3P van al 20% y no están en el muestrario de Bea
                    WHEN tarifas.Id_tarifa IS NULL AND base.tariff_id like 'CP%' THEN  
                      CASE WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%PROMO%'  THEN 20
                      ELSE dealers.porcentaje_estandar
                      END

                  END
              END
          END
          )/100 AS comision, 
      base.CLIENTE             AS id_comisionista,
      base.CLIENTE             AS distribuidor,
      base.CLIENTE             AS sfid_id,
      base.CLIENTE             AS seller,
      dealers.nombre_comercio  AS nombre_comercio,
      dealers.nombre_comercio  AS razon_social,
      dealers.documento        AS cif,
      dealers.zona_fiscal      AS zona_fiscal,
      dealers.cond_pago        AS cond_pago,
      'CABLEMOVIL'             AS marca,
      base.service_type        AS service_type,
      CAST(base.phone_nm AS STRING) AS phone_nm,
      base.tariff_id           AS tariff_id,
      base.billing_tier_2      AS tariff_ds,
      base.service_id          AS service_id,
      base.account_id          AS account_id,
      base.CLIENTE             AS customer_id,
      base.line_type_ds AS line_type_ds,
      base.bundle_type         AS bundle_type,
      CAST(NULL AS STRING)     AS technology_ds,
      CAST(NULL AS STRING)     AS billing_type_ds,
      CAST(NULL AS DATE)       AS sale_date,
      base.activation_date     AS activation_date,
      IF(base.deactivation_date IS NULL,'9999-12-31',base.deactivation_date) AS deactivation_date,
      base.SubCliente          AS order_id,
      CAST(NULL AS STRING)     AS order_type_agg,
      '42'                     AS cod_segmento,
      '05'                     AS cod_marca,
      CASE 
        WHEN UPPER(base.billing_Tier_2) = 'CUOTA MANTENIMIENTO LINEA' THEN '20'
        WHEN base.service_type = 'FIX' THEN '61' 
        WHEN base.service_type LIKE 'MOBILE' AND base.bundle_type  = 'FMC' THEN '61' 
        ELSE '20'
      END                      AS cod_tipo_contrato,
      '022'                    AS cod_producto,
      '30'                     AS cod_canal,
      CONCAT(
        (CASE
          WHEN COALESCE(base.tariff_ds,base.billing_tier_2) = 'Telefonia Movil' THEN CONCAT('Telefonia Movil', ' - ',base.descripcion_tarzona)
          ELSE COALESCE(base.tariff_ds,base.billing_tier_2)
        END), 
        (CASE
          WHEN base.comments IS NOT NULL THEN CONCAT(' - ',COALESCE(base.comments,''))
          ELSE ''
        END)
        )                        AS campaign_code,
        CAST(NULL AS STRING)     AS serial_number,
        base.imp_without_tax     AS tax_base,
        CAST(NULL AS STRING)     AS claim_code,
        base.invoice_id          AS process_code,
        CASE
          WHEN dealers.AUTO = 'NO' THEN 'No Autofactura'
          ELSE 'Autofactura'
        END                      AS comments,
        'C_MANUAL'               AS facturador,
        CAST(NULL AS STRING)     AS proceso_sap,
        CAST(NULL AS STRING)     AS id_registro,
        CAST(NULL AS STRING)     AS invoice_id,
        'X001'                   AS sociedad,
        CAST(NULL AS STRING)     AS bp,
        CAST(NULL AS STRING)     AS cuenta_contable,
        CAST(NULL AS STRING)     AS centro_coste,
        CAST(NULL AS STRING)     AS documento_sap,
        CAST(NULL AS STRING)     AS documento_sap_posicion,
        CAST(NULL AS STRING)     AS fecha_contabilizacion,
        CAST(NULL AS TIMESTAMP)  AS creado,
        CAST(NULL AS TIMESTAMP)  AS modificado,
        CAST(NULL AS STRING)     AS id_factura_drive,
        CAST(NULL AS STRING)     AS emails_acceso_trazabilidad,


      FROM `mm-commissions-reporting.TEMP.cableoperadores_base_id_mes` base

      LEFT JOIN `mm-commissions-reporting.TEMP.cableoperadores_airtime_mes` dealers ---Cambiar nombre pero fran lo llama comisiones también
        ON base.CLIENTE = dealers.id_comisionista
        AND base.id_mes = dealers.id_mes
        --Nota: Cuando se vaya a cambiar Base Comisiones Cablemovil, cuidado con los id_mes y lanzar cosas hacia atrás, no hay filtro de mes_int es decir de id_mes_pr
      
      LEFT JOIN `mm-commissions-reporting.TEMP.Tarifas_CM` tarifas
        ON base.tariff_id = tarifas.Id_Tarifa
        AND tarifas.id_mes = mes_int

      LEFT JOIN `mm-commissions-reporting.GS.Tarifas_CM_Especiales` tarifas_especiales
        ON base.tariff_id = tarifas_especiales.Id_Tarifa
        AND tarifas_especiales.id_comisionista = base.CLIENTE

      WHERE base.imp_without_tax != 0
        AND base.tariff_id IS NOT NULL


);

  -- Cuando suben información tardía a billing hay que ver si hemos generado comisión o no. Recalculamos n-1 y comprobamos por un identificador si lo hemos pagado o no. El identificador es una concatenación de: ROW_NUMBER-id_comisionista-phone_nm-tariff_id-tax_base
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cableoperadores_b_n_1_arca` AS(

      SELECT
      'calculado'              AS estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) AS mes_liquidado,
      mes_int                  AS id_mes,
      CASE
          WHEN dealers.CANAL = 'CALT' THEN 'B2B - Cablemovil Alterna'
          ELSE 'B2B - Cablemovil'
        END                    AS agrupacion_canal,
        dealers.canal          AS canal,
      --- Concepto igual pero con Z
        CASE
        WHEN dealers.trafico = 1
          OR dealers.general = 1
          OR dealers.estandar = 1
        THEN
        CONCAT(
          'Z - Gestion Cartera ',

          CASE
      
            WHEN base.bundle_type = 'MO' THEN 'Movil'
      
            WHEN base.bundle_type = 'FMC' THEN
              CASE
                WHEN base.billing_tier_2 LIKE '%3P%' THEN '3P'
                WHEN base.tariff_ds LIKE '%AD3P%'
                  OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' THEN '3P'
                WHEN base.billing_tier_2 LIKE '%DATOS ADICIONAL%' THEN 'Movil'
                WHEN base.billing_tier_2 LIKE '%PROMO%'
                     AND base.comments = '3P' THEN 'Movil'
                WHEN base.billing_tier_2 LIKE '%CONV%' THEN 'Conv'
                ELSE '3P'
              END
          END,

          ' (',

          CASE
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.trafico = 1 THEN ROUND(dealers.porcentaje_trafico*100, 2)
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.general = 1 THEN dealers.porcentaje_general

            --Alternos, aplican como avatel y Ahi+ Pero las 3P no se pagan
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CALT' THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END

              ---Aprop TOXO Y XEC se comportan como alternos:
              WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.id_comisionista in ('F00764','F00765','F46758','F00692') THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END

            --Estandar
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CM' THEN
              CASE
                -- Tarifas especiales
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL AND tarifas_especiales.id_comisionista IS NOT NULL THEN tarifas_especiales.porcentaje_especiales
                -- Existe tarifa especial pero no para ese cableoperador
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL THEN 0
                -- No existe tarifa especial: aplicar reglas estándar
                WHEN tarifas_especiales.Id_tarifa IS NULL THEN
                  CASE
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 0
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo != 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      CASE
                      --GRELO Y WIFITECH: Adicionales 3P van al 45
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                      --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                        ELSE tarifas.porcentaje_fijo
                      END
                    WHEN tarifas.porcentaje_estandar != 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      --Casos especiales para algunos distribuidores estandar
                      CASE
                      --GRELO Y WIFITECH: Adicionales 3P van al 45
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                      --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                      --Call2world no le pagamos el bono B0934 porque la info no se sube a billing a tiempo
                      WHEN base.tariff_id = 'B0934' and dealers.id_comisionista = '202067' THEN 0
                      --Adicionales 3P van al 20
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') THEN 20
                        
                        ELSE dealers.porcentaje_estandar
                        
                      END
                    --PROMOS 3P van al 20% y no están en el muestrario de Bea
                    WHEN tarifas.Id_tarifa IS NULL AND base.tariff_id like 'CP%' THEN  
                      CASE WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%PROMO%'  THEN 20
                      ELSE dealers.porcentaje_estandar
                      END

                  END
              END
          END,

          '%)'
        ) END AS concepto,
      'AIRT'                   AS tipo_concepto,
      1                        AS unidades,
      --- Comision
       base.imp_without_tax*(
       CASE
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.trafico = 1 THEN ROUND(dealers.porcentaje_trafico*100, 6)
            WHEN UPPER(base.billing_tier_2) = 'CUOTA MANTENIMIENTO LINEA'  THEN 0
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.general = 1 THEN dealers.porcentaje_general

            --Alternos, aplican como avatel y Ahi+ Pero las 3P no se pagan
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CALT' THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END
              
              ---Aprop TOXO Y XEC se comportan como alternos:
              WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.id_comisionista in ('F00764','F00765','F46758','F00692') THEN 
              CASE 
                WHEN base.tariff_ds like '%ADICIONAL%3P%' THEN dealers.porcentaje_estandar
                WHEN base.tariff_ds LIKE '%3P%' THEN 0
                ELSE dealers.porcentaje_estandar
              END

            --Estandar
            WHEN dealers.id_comisionista = base.CLIENTE AND dealers.estandar = 1 AND dealers.canal = 'CM' THEN
              CASE
                -- Tarifas especiales
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL AND tarifas_especiales.id_comisionista IS NOT NULL THEN tarifas_especiales.porcentaje_especiales
                -- Existe tarifa especial pero no para ese cableoperador
                WHEN tarifas_especiales.Id_tarifa IS NOT NULL THEN 0
                -- No existe tarifa especial: aplicar reglas estándar
                WHEN tarifas_especiales.Id_tarifa IS NULL THEN
                  CASE
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 0
                    WHEN tarifas.porcentaje_estandar = 0 AND tarifas.porcentaje_fijo != 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      CASE
                      --GRELO Y WIFITECH: Adicionales 3P van al 45
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                      --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                        ELSE tarifas.porcentaje_fijo
                      END
                    WHEN tarifas.porcentaje_estandar != 0 AND tarifas.porcentaje_fijo = 0 AND tarifas.porcentaje_especiales = 0 THEN 
                      --Casos especiales para algunos distribuidores estandar
                      CASE
                      --GRELO Y WIFITECH: Adicionales 3P van al 45
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') AND dealers.id_comisionista IN ('F42152', 'F00696') THEN 45
                      --Grupo Parlem: Adicionales 3P van al 38
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%' OR base.billing_tier_2 LIKE '%ADICIONAL%') AND dealers.id_comisionista IN ('F00692','216348','216242','F00764','F00765','F00679','F00763','F46758') THEN 38
                      --Call2world no le pagamos el bono B0934 porque la info no se sube a billing a tiempo
                        WHEN base.tariff_id in ('MA_CABLE_CABLENET','B0934') and dealers.id_comisionista = '202067' THEN 0
                      --Adicionales 3P van al 20
                        WHEN base.bundle_type = 'FMC' AND (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P%CABLEMOVIL%') THEN 20
                        
                        ELSE dealers.porcentaje_estandar
                        
                      END
                    --PROMOS 3P van al 20% y no están en el muestrario de Bea
                    WHEN tarifas.Id_tarifa IS NULL AND base.tariff_id like 'CP%' THEN  
                      CASE WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%PROMO%'  THEN 20
                      ELSE dealers.porcentaje_estandar
                      END

                  END
              END
          END
          )/100                AS comision,
      base.CLIENTE             AS id_comisionista,
      base.CLIENTE             AS distribuidor,
      base.CLIENTE             AS sfid_id,
      base.CLIENTE             AS seller,
      dealers.nombre_comercio  AS nombre_comercio,
      dealers.nombre_comercio  AS razon_social,
      dealers.documento        AS cif,
      dealers.zona_fiscal      AS zona_fiscal,
      dealers.cond_pago        AS cond_pago,
      'CABLEMOVIL'             AS marca,
      base.service_type        AS service_type,
      CAST(base.phone_nm AS STRING)   AS phone_nm,
      base.tariff_id           AS tariff_id,
      base.billing_tier_2      AS tariff_ds,
      base.service_id          AS service_id,
      base.account_id          AS account_id,
      base.CLIENTE             AS customer_id,
      base.line_type_ds        AS line_type_ds,
      base.bundle_type         AS bundle_type,
      CAST(NULL AS STRING)     AS technology_ds,
      CAST(NULL AS STRING)     AS billing_type_ds,
      CAST(NULL AS DATE)       AS sale_date,
      base.activation_date     AS activation_date,
      IF(base.deactivation_date IS NULL,'9999-12-31',base.deactivation_date) AS deactivation_date,
      base.SubCliente          AS order_id,
      CAST(NULL AS STRING)     AS order_type_agg,
      '42'                     AS cod_segmento,
      '05'                     AS cod_marca,
      CASE 
        WHEN UPPER(base.billing_Tier_2) = 'CUOTA MANTENIMIENTO LINEA' THEN '20'
        WHEN base.service_type = 'FIX' THEN '61' 
        WHEN base.service_type LIKE 'MOBILE' AND base.bundle_type  = 'FMC' THEN '61' 
        ELSE '20'
      END                      AS cod_tipo_contrato,
      '022'                    AS cod_producto,
      '30'                     AS cod_canal,
      CONCAT(FORMAT_DATE('%Y%m', DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH)),' - ',base.invoice_id,' - ', IFNULL(base.tariff_ds,base.billing_tier_2))AS campaign_code,
        CAST(NULL AS STRING)     AS serial_number,
        base.imp_without_tax     AS tax_base,
        CAST(NULL AS STRING)     AS claim_code,
        base.invoice_id     AS process_code,
        CASE
          WHEN dealers.AUTO = 'NO' THEN 'No Autofactura'
          ELSE 'Autofactura'
        END AS comments,
        'C_MANUAL'               AS facturador,
        CAST(NULL AS STRING)     AS proceso_sap,
        CAST(NULL AS STRING)     AS id_registro,
        CAST(NULL AS STRING)     AS invoice_id,
        'X001'                   AS sociedad,
        CAST(NULL AS STRING)     AS bp,
        CAST(NULL AS STRING)     AS cuenta_contable,
        CAST(NULL AS STRING)     AS centro_coste,
        CAST(NULL AS STRING)     AS documento_sap,
        CAST(NULL AS STRING)     AS documento_sap_posicion,
        CAST(NULL AS STRING)     AS fecha_contabilizacion,
        CAST(NULL AS TIMESTAMP)  AS creado,
        CAST(NULL AS TIMESTAMP)  AS modificado,
        CAST(NULL AS STRING)     AS id_factura_drive,
        CAST(NULL AS STRING)     AS emails_acceso_trazabilidad,


      FROM `mm-commissions-reporting.TEMP.cableoperadores_base_id_mes_anterior` base  --Auqnue ponga base, se refiere a base de n-1

      LEFT JOIN `mm-commissions-reporting.TEMP.cableoperadores_airtime_historico` dealers 
        ON base.CLIENTE = dealers.id_comisionista
        AND dealers.id_mes =CAST(FORMAT_DATE('%Y%m',DATE_SUB(PARSE_DATE('%Y%m', CAST(base.id_mes AS STRING)),INTERVAL 1 MONTH)) AS INT64)

      LEFT JOIN `mm-commissions-reporting.TEMP.Tarifas_CM` tarifas
        ON base.tariff_id = tarifas.Id_Tarifa
        AND tarifas.id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(PARSE_DATE('%Y%m', CAST(base.id_mes AS STRING)),INTERVAL 1 MONTH)) AS INT64)

      LEFT JOIN `mm-commissions-reporting.GS.Tarifas_CM_Especiales` tarifas_especiales
        ON base.tariff_id = tarifas_especiales.Id_Tarifa
        AND tarifas_especiales.id_comisionista = base.CLIENTE
        --Nota: Cuando se vaya a cambiar Base Comisiones Cablemovil, cuidado con los id_mes y lanzar cosas hacia atrás, no hay filtro de mes_int es decir de id_mes_pr
      WHERE base.imp_without_tax != 0
        AND base.tariff_id IS NOT NULL
        AND dealers.trafico = 0  -- No calculamos n-1 para los de tráfico
        AND dealers.id_comisionista IS NOT NULL --Nos quitamos los operadores que en n-1 no estén pero en n sí
      
      
);

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.cableoperadores_b_n_1_arca_final` AS(

  WITH base_n_1_control AS(
    SELECT *,
    CONCAT(
            IFNULL(CAST(ROW_NUMBER() OVER(
              PARTITION BY id_comisionista, tariff_id,phone_nm, CAST(tax_base AS STRING) ORDER BY phone_nm ASC, tax_base DESC
              ) AS STRING),''),
            '-',
            IFNULL(id_comisionista, ''),'-',IFNULL(CAST(phone_nm AS STRING), ''), '-',IFNULL(tariff_id, ''),'-',IFNULL(CAST(tax_base AS STRING), '')
            ) AS n_control_base_n_1
    FROM `mm-commissions-reporting.TEMP.cableoperadores_b_n_1_arca`
  )

    SELECT base_n_1_control.* 
    FROM base_n_1_control

    LEFT JOIN (
      SELECT *, 
      CONCAT(
            IFNULL(CAST(ROW_NUMBER() OVER(
              PARTITION BY id_comisionista, tariff_id,phone_nm, CAST(tax_base AS STRING) ORDER BY phone_nm ASC, tax_base DESC
              ) AS STRING),''),
            '-',
            IFNULL(id_comisionista, ''),'-',IFNULL(CAST(phone_nm AS STRING), ''), '-',IFNULL(tariff_id, ''),'-',IFNULL(CAST(tax_base AS STRING), '')
            ) AS n_control_trans
      FROM `mm-commissions-reporting.COMISIONES.transacciones`
      WHERE marca = 'CABLEMOVIL'
        AND commission_id LIKE 'ARC%'
        AND id_mes = CAST(FORMAT_DATE('%Y%m', DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH)) AS INTEGER)
    ) transacciones
      ON base_n_1_control.n_control_base_n_1 = transacciones.n_control_trans

    WHERE transacciones.n_control_trans IS NULL

);
------ Para el ciclo de 202606 no vamos a coger la parte correspondiente del mes anterior que calcula este proceso ya que hemos hecho cambios y no pagan exactamente lo mismo. Voy a dejar código para cogerlo de pr_arca. modificar este cacho para liquidaciones siguientes:
-- ASSERT mes_int < 202607
-- AS 'Revisar este código. A partir de 202607 hay que cambiar la lógica.';

-- DELETE `mm-commissions-reporting.TEMP.comisiones_arca_prueba`
-- WHERE 1=1;
-- ---Simplemente hay que borrar de aquí:
-- call `mm-commissions-reporting.COMISIONES.pr_arca`(202606,['CM','CALT']);

-- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arca_prueba` AS(
  
--   SELECT 
--   prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
--   *
--   FROM (

--     SELECT * 
--     FROM `mm-commissions-reporting.TEMP.cableoperadores_b_arca`
--     WHERE comision != 0

--     UNION ALL

--     SELECT * except(commission_id,porcentaje,codigo_cableoperador)
--     FROM `mm-commissions-reporting.TEMP.comisiones_arca`
--     WHERE comision != 0 and concepto like 'Z%'
--   )

-- );
---Hasta aquí y descomentar justo lo de abajo


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arca_prueba` AS(
  
  SELECT 
  prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
  *
  FROM (

    SELECT *
    FROM `mm-commissions-reporting.TEMP.cableoperadores_b_arca`
    WHERE comision != 0

    UNION ALL

    SELECT * EXCEPT(n_control_base_n_1)
    FROM `mm-commissions-reporting.TEMP.cableoperadores_b_n_1_arca_final`
    WHERE comision != 0
  )

);

---Para los bonos compartidos nos han pedido meter en trazabilidad el Bono_Compartido_Id de las tablas de Ivona
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arca_prueba` AS (

  WITH arca AS (
    SELECT
    a.*,
    ROW_NUMBER() OVER (
      PARTITION BY
        a.tariff_id,
        a.id_mes,
        process_code,
        CAST(a.tax_base AS STRING)
      ORDER BY a.phone_nm
    ) AS rn
    FROM `mm-commissions-reporting.TEMP.comisiones_arca_prueba` a
  ),

  ivona AS (
    SELECT
    t.data_month_id,
    t.Num_Fact,
    t.Total_Facturacion,
    t.Bono_Compartido_ID AS ID_bono_compartido,
    b.bono_id,
    ROW_NUMBER() OVER (
      PARTITION BY
        b.bono_id,
        t.data_month_id,
        t.Num_Fact,
        CAST(t.Total_Facturacion AS STRING)
      ORDER BY t.Bono_Compartido_ID
    ) AS rn
    FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*` t
    LEFT JOIN UNNEST(t.Bono) AS b
    WHERE t._TABLE_SUFFIX = FORMAT_DATE('%Y%m01',DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH))
    AND b.bono_compartido_id is not null
    AND LENGTH(b.bono_compartido_id) = 36 -- Hay caracteres y concatenaciones en algunas lineas que no son el UUID del bono compartido
  )

  SELECT
  arca.* EXCEPT(claim_code, rn),
  CASE
    WHEN arca.tariff_ds LIKE 'BONO%COMPAR%'
      THEN ivona.ID_bono_compartido
    ELSE arca.claim_code
  END AS claim_code

  FROM arca

  LEFT JOIN ivona
    ON arca.tariff_id = ivona.bono_id
    AND arca.id_mes = ivona.data_month_id
    AND arca.process_code = ivona.Num_Fact
    AND ROUND(arca.tax_base,4) = ROUND(ivona.Total_Facturacion,4) --Redondeo en el cruce porque a veces no redondeaban al mismo decimal y no cruzaban
    AND arca.rn = ivona.rn

);

-- Hay algunos bonos que no se encuentran en esta tabla sino en la del mes anterior, repetimos proceso con los bonos sin identificar, buscándolos en la tabla anterior:

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arca_prueba` AS (

  WITH arca AS (
    SELECT
    a.*,
    ROW_NUMBER() OVER (
      PARTITION BY
        a.tariff_id,
        a.id_mes,
        process_code,
        CAST(a.tax_base AS STRING)
      ORDER BY a.phone_nm
    ) AS rn
    FROM `mm-commissions-reporting.TEMP.comisiones_arca_prueba` a
  ),

  ivona AS (
    SELECT
    t.data_month_id,
    t.Num_Fact,
    t.Total_Facturacion,
    t.Bono_Compartido_ID AS ID_bono_compartido,
    b.bono_id,
    ROW_NUMBER() OVER (
      PARTITION BY
        b.bono_id,
        t.data_month_id,
        t.Num_Fact,
        CAST(t.Total_Facturacion AS STRING)
      ORDER BY t.Bono_Compartido_ID
    ) AS rn
    FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*` t
    LEFT JOIN UNNEST(t.Bono) AS b
    WHERE t._TABLE_SUFFIX = FORMAT_DATE('%Y%m01',DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 0 MONTH))
    AND b.bono_compartido_id is not null
    AND LENGTH(b.bono_compartido_id) = 36 -- Hay caracteres y concatenaciones en algunas lineas que no son el UUID del bono compartido
  )

  SELECT
  arca.* EXCEPT(claim_code, rn),
  CASE
    WHEN arca.tariff_ds LIKE 'BONO%COMPAR%' and arca.claim_code is null
      THEN ivona.ID_bono_compartido
    ELSE arca.claim_code
  END AS claim_code

  FROM arca

  LEFT JOIN ivona
    ON arca.tariff_id = ivona.bono_id
    AND arca.id_mes =  CAST(FORMAT_DATE('%Y%m', DATE_ADD(PARSE_DATE('%Y%m', CAST(ivona.data_month_id AS STRING)), INTERVAL 1 MONTH))AS INT64)
    AND arca.process_code = ivona.Num_Fact
    AND ROUND(arca.tax_base,4) = ROUND(ivona.Total_Facturacion,4) --Redondeo en el cruce porque a veces no redondeaban al mismo decimal y no cruzaban
    AND arca.rn = ivona.rn

);


ASSERT NOT EXISTS (

  SELECT * --concepto,bundle_type,SUM(comision)
  FROM `mm-commissions-reporting.TEMP.comisiones_arca_prueba` 
  WHERE 1=1
    AND comision = 0
    AND REGEXP_EXTRACT(concepto, r'\((\d+)%\)') != '0'
    AND tax_base != 0
  ) AS 'Hay lineas que tax_base =! 0 pero no tienen comision'
  ;


  -- Insertamos en transacciones
  call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo,mes_int,canales_pr,'TEMP.comisiones_arca_prueba',  'ACTUALIZAR');


--Incluir el pr de alea aquí
call `mm-commissions-reporting.COMISIONES.pr_comisiones_alea`(mes_int);

END