BEGIN

-- ********* REVISAR ADICIONAL 3P, ESTA CAMBIADO EN LA FUNCION DEL CONCEPTO Y DE LA COMISION *************
DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = 'ARCA1'; 

SET canales_pr = ['CM','CALT'];

-- call `mm-commissions-reporting.COMISIONES.pr_arca`(202607,['CM','CALT']);

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

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arca` AS

  WITH
   
    dealers AS (
      SELECT * EXCEPT (nombre_comercio,zona_fiscal),
        UPPER(nombre_comercio) AS nombre_comercio,
        IF(zona_fiscal = '#N/A','PEN',zona_fiscal) AS zona_fiscal
      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL`
      WHERE comisiona IS TRUE AND check_duplicados = '1'
    ),
    
    grupo_avatel AS (
      SELECT id_comisionista AS id_avatel,porcentaje_avatel
      FROM `mm-commissions-reporting.GS.AVATEL_CABLEMOVIL`
      QUALIFY ROW_NUMBER() OVER (PARTITION BY id_comisionista) = 1
    ),

    C_TRAFICO AS(
      
      SELECT COD_OP AS codigo_cableoperador, PORCENTAJE_COMISION AS porcentaje
      FROM `mm-commissions-reporting.B2B.TRAFICO_COMISIONES_DS`
      WHERE id_mes = CAST(mes_string AS INT64)
    ),

    base AS (
      SELECT *
      FROM `mm-commissions-reporting.B2B.comisiones_base_arca_*` --base_inicial
      WHERE 1=1
        AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
        AND origen_info = 'mes_actual'
        AND n_control = 1

    ),

    base_n_1 AS (
      SELECT *
      FROM `mm-commissions-reporting.B2B.comisiones_base_arca_*` --base_inicial
      WHERE 1=1
        AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
        AND origen_info = 'mes_anterior'
        AND n_control = 1
    ),

    autofactura AS (--No se usa
      SELECT DISTINCT a.CIF AS CIF_AUTOFACTURA, zona_fiscal
      FROM `mm-commissions-reporting.GS.AUTOFACTURA_CABLEMOVIL` a
      WHERE a.Autofactura = TRUE
    ),
    
    b AS(
      SELECT 
        'calculado' as estado,
        DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) as mes_liquidado, -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
        CAST(mes_string AS INT64) AS id_mes,
        CASE
          WHEN dealers.CANAL = 'CALT' THEN 'B2B - Cablemovil Alterna'
          ELSE 'B2B - Cablemovil'
        END AS agrupacion_canal,
        dealers.canal AS canal,
        CASE 

          WHEN UPPER(base.billing_tier_2) = 'CUOTA MANTENIMIENTO LINEA'  THEN 'C - Gestion Cartera 3P (0%)'


          WHEN (base.billing_tier_2 LIKE '%3P%' AND base.bundle_type = 'FMC' AND C_TRAFICO.codigo_cableoperador IS NOT NULL) THEN CONCAT('C - Gestion Cartera 3P (',
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              ELSE 0
            END,'%)')


          WHEN (base.tariff_ds LIKE '%AD3P%' OR base.tariff_ds LIKE '%ADICIONAL_3P CABLEMOVIL%') AND base.bundle_type = 'FMC' THEN CONCAT('C - Gestion Cartera 3P (',
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              ELSE `mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds, grupo_avatel.porcentaje_avatel,base.comments)
            END,'%)')


          WHEN (base.billing_tier_2 LIKE '%3P%' AND base.bundle_type = 'FMC') THEN CONCAT('C - Gestion Cartera 3P (0%)')


          -- ADICIONALES NO 3P DATOS ADICIONAL
          WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%DATOS ADICIONAL%' THEN CONCAT('C - Gestion Cartera 3P (',
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              ELSE `mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds, grupo_avatel.porcentaje_avatel,base.comments)
            END,'%)')


          --PROMOCIONES
          WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%PROMO%' THEN CONCAT('C - Gestion Cartera Movil (',
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              ELSE `mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds, grupo_avatel.porcentaje_avatel,base.comments)
            END,'%)') 


          WHEN base.bundle_type = 'MO' AND base.phone_nm IS NOT NULL THEN CONCAT('C - Gestion Cartera Movil ','(', 
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax, grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
              ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
            END,'%)')


          WHEN base.bundle_type = 'MO' AND base.phone_nm IS NULL THEN CONCAT('C - Gestion Cartera Movil ','(', 
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
              ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
            END,'%)')


          WHEN (base.bundle_type = 'FMC' AND base.billing_Tier_2 LIKE '%CONV%') THEN CONCAT('C - Gestion Cartera CONV ', '(',
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
              ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
            END,'%)')
          
          -- RESTANTES FMC
          WHEN base.bundle_type = 'FMC' THEN CONCAT('C - Gestion Cartera 3P (',
            CASE
              WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN ROUND(C_TRAFICO.porcentaje*100,2)
              ELSE `mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds, grupo_avatel.porcentaje_avatel,base.comments)
            END,'%)')

            
          ELSE 'No cruza'
        END AS concepto,
        'AIRT' AS tipo_concepto,
        CAST(NULL AS INT64) AS unidades,
        imp_without_tax,
        base.imp_without_tax*(
          CASE
            WHEN C_TRAFICO.codigo_cableoperador = base.CLIENTE THEN C_TRAFICO.porcentaje*100
            WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
            ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
          END
          )/100 AS comision,
        max_comision_cableoperador.MAX_COMISION AS max_comision,
        base.CLIENTE             AS id_comisionista,
        base.CLIENTE             AS distribuidor,
        base.CLIENTE             AS sfid_id,
        base.CLIENTE             AS seller,
        dealers.nombre_comercio  AS nombre_comercio,
        dealers.nombre_comercio  AS razon_social,
        dealers.documento AS cif,
        dealers.zona_fiscal      AS zona_fiscal,
        CAST(NULL AS STRING)     AS cond_pago,
        'CABLEMOVIL'             AS marca,
        base.service_type        AS service_type,
        base.phone_nm            AS phone_nm,
        base.tariff_id           AS tariff_id,
        base.billing_tier_2      AS tariff_ds,
        base.service_id AS service_id,
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
        '30'                     AS cod_canal,
        '022'                    AS cod_producto,
        CONCAT(base.invoice_id,' - ',
          (CASE
            WHEN COALESCE(base.tariff_ds,base.billing_tier_2) = 'Telefonia Movil' THEN CONCAT('Telefonia Movil', ' - ',base.descripcion_tarzona)
            ELSE COALESCE(base.tariff_ds,base.billing_tier_2)
          END), 
          (CASE
            WHEN base.comments IS NOT NULL THEN CONCAT(' - ',COALESCE(base.comments,''))
            ELSE ''
          END)) AS campaign_code,
        CAST(NULL AS STRING)     AS serial_number,
        base.imp_without_tax     AS tax_base,
        CAST(NULL AS STRING)     AS claim_code,
        CAST(NULL AS STRING)     AS process_code,
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
        grupo_avatel.id_avatel
      FROM base
      JOIN dealers ON dealers.id_comisionista = base.cliente
      LEFT JOIN grupo_avatel ON grupo_avatel.id_avatel = dealers.id_comisionista
      LEFT JOIN (SELECT *,
        FROM `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores_historico_nuevo`
        QUALIFY ROW_NUMBER() OVER (PARTITION BY mes,CODIGO_CABLEOPERADOR,ID_TARIFA ORDER BY FECHA_MOD DESC) = 1 ) comisiones ON base.CLIENTE = comisiones.CODIGO_CABLEOPERADOR AND (base.tariff_id = comisiones.ID_TARIFA) AND MES = DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) 
      LEFT JOIN (
        SELECT DISTINCT
          CODIGO_CABLEOPERADOR,
          MAX(COMISION) AS MAX_COMISION
        FROM `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores_historico_nuevo`
        WHERE MES = DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH)
        GROUP BY 1
      ) max_comision_cableoperador ON base.CLIENTE = max_comision_cableoperador.CODIGO_CABLEOPERADOR
      -- LEFT JOIN ventas_pers_mobile 
      --   ON ventas_pers_mobile.account_id = base.CLIENTE     
      -- LEFT JOIN ventas_pers_fibra 
      --   ON ventas_pers_fibra.dealer_customer_id = base.CLIENTE 
      -- LEFT JOIN `mm-commissions-reporting.SAP.vendor_list` zona_fiscal 
      --   ON zona_fiscal.tax_code = COALESCE(ventas_pers_mobile.CIF, ventas_pers_fibra.CIF)
      LEFT JOIN C_TRAFICO ON base.CLIENTE = C_TRAFICO.codigo_cableoperador
    ),

    b_n_1 AS(
      SELECT 
        'calculado' as estado,
        DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) as mes_liquidado, -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
        CAST(mes_string AS INT64) AS id_mes,
        CASE
          WHEN dealers.CANAL = 'CALT' THEN 'B2B - Cablemovil Alterna'
          ELSE 'B2B - Cablemovil'
        END AS agrupacion_canal,
        dealers.canal AS canal,
        CASE 

          WHEN UPPER(base.billing_Tier_2) = 'CUOTA MANTENIMIENTO LINEA'  THEN 'Z - Gestion Cartera 3P (0%)'


          WHEN (base.tariff_ds LIKE '%AD3P%' AND base.bundle_type = 'FMC') THEN CONCAT('Z - Gestion Cartera 3P (',`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments),'%)')


          WHEN (base.billing_Tier_2 LIKE '%3P%' AND base.bundle_type = 'FMC') THEN CONCAT('Z - Gestion Cartera 3P (0%)')


          -- ADICIONALES NO 3P DATOS ADICIONAL
          WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%DATOS ADICIONAL%' THEN CONCAT('Z - Gestion Cartera 3P (',`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds, grupo_avatel.porcentaje_avatel,base.comments),'%)')


          --PROMOCIONES
          WHEN base.bundle_type = 'FMC' AND base.comments = '3P' AND base.billing_tier_2 LIKE '%PROMO%' THEN CONCAT('Z - Gestion Cartera Movil (',`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds, grupo_avatel.porcentaje_avatel,base.comments),'%)') 
          


          WHEN base.bundle_type = 'MO' AND base.phone_nm IS NOT NULL THEN CONCAT('Z - Gestion Cartera Movil ','(', 
            CASE
              WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
              ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
            END
            ,'%)')


          WHEN base.bundle_type = 'MO' AND base.phone_nm IS NULL THEN CONCAT('Z - Gestion Cartera Movil ','(', 
            CASE
              WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
              ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
            END
            ,'%)')


          WHEN (base.bundle_type = 'FMC' AND base.billing_Tier_2 LIKE '%CONV%') THEN CONCAT('Z - Gestion Cartera CONV ', '(',
            CASE
              WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
              ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
            END
            ,'%)')
          ELSE 'No cruza'
        END AS concepto,
        'AIRT' AS tipo_concepto,
        CAST(NULL AS INT64) AS unidades,
        imp_without_tax,
        base.imp_without_tax*(
          CASE
            WHEN (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments)) IS NULL THEN 20
            ELSE (`mm-commissions-reporting.B2B.f_concepto_comision_CM` (dealers.canal,comisiones.COMISION, base.billing_tier_2, base.tariff_id, dealers.nombre_comercio, base.CLIENTE, comisiones.ID_TARIFA, base.activation_date, base.phone_nm, max_comision_cableoperador.MAX_COMISION, base.imp_without_tax,grupo_avatel.id_avatel, base.bundle_type,base.tariff_ds,grupo_avatel.porcentaje_avatel,base.comments))
          END
          )/100 AS comision,
        max_comision_cableoperador.MAX_COMISION AS max_comision,
        base.CLIENTE             AS id_comisionista,
        base.CLIENTE             AS distribuidor,
        base.CLIENTE             AS sfid_id,
        base.CLIENTE             AS seller,
        dealers.nombre_comercio  AS nombre_comercio,
        dealers.nombre_comercio  AS razon_social,
        --UPPER(COALESCE(ventas_pers_mobile.CIF, ventas_pers_fibra.CIF, dealers.documento)) AS cif,
        dealers.documento AS cif,
        dealers.zona_fiscal      AS zona_fiscal,
        CAST(NULL AS STRING)     AS cond_pago,
        'CABLEMOVIL'             AS marca,
        base.service_type        AS service_type,
        base.phone_nm            AS phone_nm,
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
        IF(base.deactivation_date IS NULL, '9999-12-31',base.deactivation_date)   AS deactivation_date,
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
        '30'      AS cod_canal,
        '022'     AS cod_producto,
        CONCAT(FORMAT_DATE('%Y%m', DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH)),' - ',base.invoice_id,' - ', IFNULL(base.tariff_ds,base.billing_tier_2))AS campaign_code,
        CAST(NULL AS STRING)     AS serial_number,
        base.imp_without_tax     AS tax_base,
        CAST(NULL AS STRING)     AS claim_code,
        CAST(NULL AS STRING)     AS process_code,
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
        CAST(NULL AS STRING)     AS id_avatel
      FROM base_n_1 base
      JOIN dealers ON dealers.id_comisionista = base.cliente
      LEFT JOIN grupo_avatel ON grupo_avatel.id_avatel = dealers.id_comisionista
      LEFT JOIN (SELECT *,
        FROM `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores_historico_nuevo`
        QUALIFY ROW_NUMBER() OVER (PARTITION BY mes,CODIGO_CABLEOPERADOR,ID_TARIFA ORDER BY FECHA_MOD DESC) = 1 ) comisiones ON base.CLIENTE = comisiones.CODIGO_CABLEOPERADOR AND (base.tariff_id = comisiones.ID_TARIFA) AND MES = DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH)
      LEFT JOIN (
        SELECT DISTINCT
          CODIGO_CABLEOPERADOR,
          MAX(COMISION) AS MAX_COMISION
        FROM `mm-commissions-reporting.CABLEOPERADORES.maestro_comisiones_cableoperadores_historico_nuevo`
        WHERE MES = DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH) -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 2 MONTH), MONTH)
        GROUP BY 1
      ) max_comision_cableoperador ON base.CLIENTE = max_comision_cableoperador.CODIGO_CABLEOPERADOR
      LEFT JOIN C_TRAFICO ON base.CLIENTE = C_TRAFICO.codigo_cableoperador
      -- LEFT JOIN ventas_pers_mobile 
      --   ON ventas_pers_mobile.account_id = base.CLIENTE       
      -- LEFT JOIN ventas_pers_fibra 
      --   ON ventas_pers_fibra.dealer_customer_id = base.CLIENTE 
      -- LEFT JOIN `mm-commissions-reporting.SAP.vendor_list` zona_fiscal 
      --   ON zona_fiscal.tax_code = COALESCE(ventas_pers_mobile.CIF, ventas_pers_fibra.CIF)

      --No calculamos hacia atrás las comisiones que provengan de tráfico
      WHERE C_TRAFICO.codigo_cableoperador IS NULL
    ),

    b_n_1_a AS (
      SELECT *,
        CONCAT(IFNULL(CAST(ROW_NUMBER() OVER(PARTITION BY id_comisionista, tariff_id,phone_nm, CAST(tax_base AS STRING) ORDER BY phone_nm ASC, tax_base DESC) AS STRING),''),'-',IFNULL(id_comisionista, ''),'-',IFNULL(CAST(phone_nm AS STRING), ''), '-',IFNULL(tariff_id, ''),'-',IFNULL(CAST(tax_base AS STRING), '')) AS n_control
      FROM b_n_1 
    ), 

    tr AS (
      SELECT *, 
        CONCAT(IFNULL(CAST(ROW_NUMBER() OVER(PARTITION BY id_comisionista, tariff_id,phone_nm, CAST(tax_base AS STRING) ORDER BY phone_nm ASC, tax_base DESC) AS STRING),''),'-',IFNULL(id_comisionista, ''),'-',IFNULL(CAST(phone_nm AS STRING), ''), '-',IFNULL(tariff_id, ''),'-',IFNULL(CAST(tax_base AS STRING), '')) AS n_control
      FROM `mm-commissions-reporting.COMISIONES.transacciones`
      WHERE marca = 'CABLEMOVIL'
        AND commission_id LIKE 'ARC%'
        AND id_mes = CAST(FORMAT_DATE('%Y%m', DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH)) AS INTEGER) 

      UNION ALL

      --No duplicidad de reclamaciones ya subidas.
      SELECT *, 
        CONCAT(IFNULL(CAST(ROW_NUMBER() OVER(PARTITION BY id_comisionista, tariff_id,phone_nm, CAST(tax_base AS STRING) ORDER BY phone_nm ASC, tax_base DESC) AS STRING),''),'-',IFNULL(id_comisionista, ''),'-',IFNULL(CAST(phone_nm AS STRING), ''), '-',IFNULL(tariff_id, ''),'-',IFNULL(CAST(tax_base AS STRING), '')) AS n_control
      FROM `mm-commissions-reporting.COMISIONES.transacciones`
      WHERE marca = 'CABLEMOVIL'
        AND commission_id LIKE 'ARC%'
        AND id_mes = CAST(FORMAT_DATE('%Y%m', DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH)) AS INTEGER) 
    ),

    b_f_n_1 AS (

      SELECT a.*
      FROM b_n_1_a a
      LEFT JOIN tr ON a.n_control = tr.n_control
      WHERE tr.n_control IS NULL
    ), 

    final AS (

      SELECT 
        estado,
        mes_liquidado,
        id_mes,
        agrupacion_canal,
        canal,
        concepto,
        tipo_concepto,
        1 AS unidades,
        CAST(comision AS FLOAT64) AS comision,
        id_comisionista,
        distribuidor,
        sfid_id,
        seller,
        nombre_comercio,
        razon_social,
        cif,
        zona_fiscal,
        cond_pago,
        marca,
        service_type,
        CAST(phone_nm AS STRING) AS phone_nm,
        tariff_id,
        tariff_ds,
        service_id,
        account_id,
        customer_id,
        line_type_ds,
        bundle_type,
        technology_ds,
        billing_type_ds,
        sale_date,
        activation_date,
        deactivation_date,
        order_id,
        order_type_agg,
        cod_segmento,
        cod_marca,
        cod_tipo_contrato,
        cod_producto,
        cod_canal,
        campaign_code,
        serial_number,
        tax_base,
        claim_code,
        process_code,
        comments,
        facturador,
        proceso_sap,
        id_registro,
        invoice_id,
        sociedad,
        bp,
        cuenta_contable,
        centro_coste,
        documento_sap,
        documento_sap_posicion,
        fecha_contabilizacion,
        creado,
        modificado,
        id_factura_drive,
        emails_acceso_trazabilidad,
        id_avatel
      FROM b

      UNION ALL

      SELECT 
        estado,
        mes_liquidado,
        id_mes,
        agrupacion_canal,
        canal,
        concepto,
        tipo_concepto,
        1 AS unidades,
        CAST(comision AS FLOAT64) AS comision,
        id_comisionista,
        distribuidor,
        sfid_id,
        seller,
        nombre_comercio,
        razon_social,
        cif,
        zona_fiscal,
        cond_pago,
        marca,
        service_type,
        CAST(phone_nm AS STRING) AS phone_nm,
        tariff_id,
        tariff_ds,
        service_id,
        account_id,
        customer_id,
        line_type_ds,
        bundle_type,
        technology_ds,
        billing_type_ds,
        sale_date,
        activation_date,
        deactivation_date,
        order_id,
        order_type_agg,
        cod_segmento,
        cod_marca,
        cod_tipo_contrato,
        cod_producto,
        cod_canal,
        campaign_code,
        serial_number,
        tax_base,
        claim_code,
        process_code,
        comments,
        facturador,
        proceso_sap,
        id_registro,
        invoice_id,
        sociedad,
        bp,
        cuenta_contable,
        centro_coste,
        documento_sap,
        documento_sap_posicion,
        fecha_contabilizacion,
        creado,
        modificado,
        id_factura_drive,
        emails_acceso_trazabilidad,
        id_avatel
      FROM b_f_n_1
    ),

    general AS (
      SELECT *
      FROM final
      LEFT JOIN C_TRAFICO ON final.id_comisionista = C_TRAFICO.codigo_cableoperador 
      WHERE 1=1
      AND (comision IS NOT NULL)
      AND service_type != 'FIX' --PARA TUCA COMENTAR ESTO
      AND concepto NOT LIKE '%Gestion Cartera 3P (0%)' --PARA TUCA COMENTAR ESTO
      AND C_TRAFICO.codigo_cableoperador IS NULL  --PARA TUCA AGREGAR NOT
      AND id_avatel IS NULL --PARA AVATEL AGREGAR NOT
    ),

    tuca AS (
      SELECT *
      FROM final
      LEFT JOIN C_TRAFICO ON final.id_comisionista = C_TRAFICO.codigo_cableoperador 
      WHERE 1=1
      AND (comision IS NOT NULL) 
      AND C_TRAFICO.codigo_cableoperador IS NOT NULL  --PARA TUCA AGREGAR NOT
      AND id_avatel IS NULL --PARA AVATEL AGREGAR NOT
    ),

    avatel AS (
      SELECT *
      FROM final
      LEFT JOIN C_TRAFICO ON final.id_comisionista = C_TRAFICO.codigo_cableoperador 
      WHERE 1=1
      AND (comision IS NOT NULL)
      AND service_type != 'FIX' --PARA TUCA COMENTAR ESTO
      AND concepto NOT LIKE '%Gestion Cartera 3P (0%)' --PARA TUCA COMENTAR ESTO
      AND C_TRAFICO.codigo_cableoperador IS NULL  --PARA TUCA AGREGAR NOT
      AND id_avatel IS NOT NULL --PARA AVATEL AGREGAR NOT
    ),

    union_final AS (
      SELECT *
      FROM general
      
      UNION ALL
      
      SELECT *
      FROM tuca
      
      UNION ALL

      SELECT *
      FROM avatel
    )

  SELECT 
    prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
    union_final.* EXCEPT(id_avatel)
  FROM union_final
  WHERE 1=1
    AND comision != 0 
  ;

  ASSERT NOT EXISTS (

  SELECT * --concepto,bundle_type,SUM(comision)
  FROM `mm-commissions-reporting.TEMP.comisiones_arca` 
  WHERE 1=1
    AND comision = 0
    AND REGEXP_EXTRACT(concepto, r'\((\d+)%\)') != '0'
    AND tax_base != 0
  ) AS 'Hay lineas que no se están comisionando'
  ;



-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_arca',
  'ACTUALIZAR'
);

-- Procedimiento de Validaciones

--Se hacen automáticas cuando se lanza la liqui desde el googlesheet
-- CALL `mm-commissions-reporting.COMISIONES.pr_validaciones_B2BC`(mes_int, canales_pr)
-- ;

END