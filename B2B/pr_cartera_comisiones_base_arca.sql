BEGIN

--Declaramos las variables que se van a usar a lo largo del procedimiento /
DECLARE mes_string,mes_liqui, qry, tabla_nombre,tabla_nombre_row STRING;
DECLARE mes DATE;

SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes); -- 202504;
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','comisiones_base_arca_', mes_liqui, '');
set tabla_nombre_row = CONCAT('mm-commissions-reporting.B2B.','row_comisiones_base_arca_', mes_liqui, '');

-- CALL `mm-commissions-reporting.B2B.pr_cartera_comisiones_base_arca`()

IF NOT EXISTS(
    SELECT *
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE canal IN ('CM','CALT')
      AND id_mes = CAST(mes_string AS INT64)
      AND (commission_id LIKE 'ARCA%'AND commission_id LIKE CONCAT("ARCA_",CAST(mes_string AS INT64),"_%"))
      AND mes_liquidado = mes
    GROUP BY ALL
    ) THEN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.row_comisiones_base_arca`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 

    dealers AS (
      SELECT * EXCEPT (nombre_comercio,zona_fiscal),
        UPPER(nombre_comercio) AS nombre_comercio,
        IF(zona_fiscal = '#N/A','PEN',zona_fiscal) AS zona_fiscal
      FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL`
      WHERE comisiona IS TRUE AND check_duplicados = '1'
    ),
    
    grupo_avatel AS (
      SELECT id_comisionista AS id_avatel
      FROM `mm-commissions-reporting.GS.AVATEL_CABLEMOVIL`
      QUALIFY ROW_NUMBER() OVER (PARTITION BY id_comisionista) = 1
    ),

    trafico AS(
      SELECT id_comisionista
      FROM `mm-commissions-reporting.GS.DEALERS_TRAFICO`
    ),

    billing AS (
      SELECT * EXCEPT(service_type),
        CASE
          WHEN service_type = 'BROADBAND' THEN 'INTERNET'
          ELSE service_type
        END AS service_type,
      FROM `mm-datamart-kd.BILLING.billing_detail_xena`
    ),

    origen AS (--CARTERA
    
      SELECT 
        CAST(mes_string AS INT64) AS id_mes,
        'CABLEMOVIL' AS comm_brand_ds,
        'mes_actual' AS origen_info,
        a.data_month_id AS data_month_id_billing,
        a.customer_id AS CLIENTE,
        a.billing_tier_2,
        a.phone_nm,
        b.service_id,
        a.service_type,
        b.line_type_ds,
        a.account_id,
        c.SubCliente,
        a.invoice_id,
        a.invoice_date,
        a.init_date,
        a.end_date,
        CASE
          WHEN (a.billing_Tier_2 LIKE '%3P%' OR a.billing_Tier_2 LIKE '%CONV%')  THEN 'FMC' 
          ELSE 'MO'
        END AS bundle_type,
        CASE
          WHEN a.billing_tier_1 = '6' AND a.billing_tier_2 != 'TELEFONIA MOVIL' THEN NULL
          ELSE a.billing_tier_1
        END AS tariff_id,
        UPPER(CASE
          WHEN b.tariff_ds LIKE '%AD3P%' AND a.billing_tier_2 NOT LIKE  '%ADICIONAL_3P%' THEN NULL
          WHEN (b.tariff_ds LIKE '%TRV%' OR b.tariff_ds IS NULL) THEN a.billing_tier_2
          ELSE b.tariff_ds
        END) AS tariff_ds,
        Producto_ID,
        CASE
          WHEN a.billing_tier_1 = '6' AND a.billing_tier_2 != 'TELEFONIA MOVIL' THEN 0
          ELSE a.imp_without_tax
        END AS imp_without_tax,
        b.activation_date,
        b.deactivation_date,
        CAST(NULL AS STRING) AS descripcion_tarzona,
        kpi_gross_add,
        CASE
          WHEN a.phone_nm IS NULL THEN 1
          ELSE ROW_NUMBER() OVER (PARTITION BY a.account_id, a.phone_nm,billing_tier_2, CAST(a.imp_without_tax AS STRING), a.init_date, a.end_date,a.invoice_date ORDER BY activation_date DESC)
        END AS n_control
      FROM billing a --`mm-datamart-kd.BILLING.billing_detail_xena` a
      LEFT JOIN (
        SELECT DISTINCT
          MSISDN, 
          CLIENTE AS id_cliente,  
          Producto_ID, 
          SubCliente,
          Bono.bono_id AS bono_id,    
          --ACTUALIZAR TABLA MES A MES CURSO (Actual)
        FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*`,
        --FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_20241101` 
        UNNEST (bono) AS bono
        WHERE data_month_id = CAST(mes_string AS INT64)
      ) c ON a.phone_nm = CAST(c.Msisdn AS INT64) AND (a.billing_tier_1 = c.bono_id)  
      LEFT JOIN `mm-datamart-kd.SERVICES.service_base_net` b ON a.phone_nm = b.phone_nm 
        AND b.service_id = CONCAT(a.phone_nm,a.customer_id) 
        AND LAST_DAY(b.activation_date) <= LAST_DAY(a.init_date) 
        AND (LAST_dAY(b.deactivation_date) >= a.end_date OR b.deactivation_date IS NULL) 
        AND c.Producto_ID = b.tariff_id
      JOIN dealers d ON d.id_comisionista = a.customer_id
      WHERE a.comm_brand_ds IN ('CABLEMOVIL','EMBOU')
        AND a.invoice_date BETWEEN DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH) AND
    LAST_DAY(DATE_ADD(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH), MONTH)
    -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH) AND LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH))
        AND NOT (
          -- a.billing_tier_2 LIKE '%CIRCUITO%' 
          -- OR a.billing_tier_2 LIKE '%TRV%'
          -- OR a.billing_tier_2 = 'FACTURACION MANUAL' 
          -- OR a.billing_tier_2 LIKE 'TARJETA%' 
          -- OR a.billing_tier_2 LIKE '%TARJETA%' 
          -- OR a.billing_tier_2 LIKE '%SIM%' 
          -- OR a.billing_tier_2 LIKE '% SIM%' 
          -- OR a.billing_tier_2 LIKE '%COMPENSACION POR CORTE DE SERVICIO%' 
          -- OR a.billing_tier_2 = 'MES DESPLIEGUE DE RED' 
         a.billing_tier_2 = 'TELEFONIA MOVIL'
          -- OR a.billing_tier_2 IS NULL
        )

        UNION ALL

      SELECT 
        CAST(mes_string AS INT64) AS id_mes,
        'CABLEMOVIL' AS comm_brand_ds,
        'mes_actual' AS origen_info,
        b.data_month_id AS data_month_id_billing,
        b.account_id AS CLIENTE,
        a.Tarifa_fact AS billing_tier_2,
        CAST(NULL AS INT64)  AS phone_nm,
        CAST(NULL AS STRING) AS service_id,
        'MOBILE'  AS service_type,
        CAST(NULL AS STRING) AS line_type_ds,
        b.account_id,
        CAST(NULL AS STRING) AS SubCliente,
        b.invoice_id,
        b.invoice_date,
        CAST(NULL AS DATE) AS init_date,
        CAST(NULL AS DATE) AS end_date,
        'MO' AS bundle_type,
        a.Tarifa_fact AS tariff_id,
        UPPER(a.descripcion_fact) AS tariff_ds,
        CAST(NULL AS STRING) AS Producto_ID,
        a.total_precio     AS imp_without_tax,
        CAST(NULL AS DATE) AS activation_date,
        CAST(NULL AS DATE) AS deactivation_date,
        a.descripcion_tarzona as descripcion_tarzona,
        CAST(NULL AS INT64)  AS kpi_gross_add,
        n_control
      FROM `mm-commissions-reporting.TEMP.HISTORICO_VOZ_CABLEMOVIL` a
      JOIN (
        SELECT DISTINCT data_month_id,comm_brand_ds, account_id, customer_id, invoice_id, invoice_date,
          ROW_NUMBER() OVER(PARTITION BY data_month_id, account_id, customer_id, invoice_id ORDER BY invoice_date ASC) AS n_control
        FROM `mm-datamart-kd.BILLING.billing_detail_net`
        WHERE invoice_date BETWEEN DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',mes_string), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_ADD(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH), MONTH)
    -- DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH) AND LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH))
      ) b ON a.num_fact = b.invoice_id
      JOIN dealers d ON d.id_comisionista = b.customer_id
        WHERE b.comm_brand_ds IN ('CABLEMOVIL','EMBOU')
        AND  a.id_empresa = '05'
        AND n_control = 1
        AND a.descripcion_fact = 'Telefonia Movil'
        AND a.total_precio != 0
    ),

    --Desarrollo para identificar las lineas con paquetes 3P y complementar la información porque no vienen identificados todos los campos, como fecha,service_id,etc.
    agrupacion AS (
      SELECT 
        invoice_id,
        cliente,
        SubCliente,
        service_id,
        bundle_type,
        line_type_ds,
        phone_nm, 
        Producto_ID,
        activation_date,
        CASE
          WHEN CONCAT(Producto_ID,' - ',tariff_ds,' - ',billing_tier_2) LIKE '%3P%'AND bundle_type = 'FMC' THEN '3P'
          ELSE NULL
        END comments
      FROM origen
      QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1
    ),

    base_inicial AS (
      SELECT 
        id_mes,
        comm_brand_ds,
        origen_info,
        data_month_id_billing,
        COALESCE(a.CLIENTE,b.CLIENTE) AS CLIENTE,
        a.billing_tier_2,
        a.phone_nm,
        COALESCE(a.service_id,b.service_id) AS service_id,
        service_type,
        COALESCE(a.line_type_ds,b.line_type_ds) AS line_type_ds,
        account_id,
        UPPER(COALESCE(a.SubCliente, b.SubCliente)) AS SubCliente,
        a.invoice_id,
        invoice_date,
        init_date,
        end_date,
        COALESCE(b.bundle_type, a.bundle_type) AS bundle_type,
        tariff_id,
        tariff_ds,
        COALESCE(a.Producto_ID, b.Producto_ID) AS Producto_ID,
        imp_without_tax,
        COALESCE(a.activation_date, b.activation_date) AS activation_date,
        deactivation_date,
        descripcion_tarzona,
        kpi_gross_add,
        n_control,
        comments
      FROM origen a
      LEFT JOIN agrupacion b ON a.phone_nm = b.phone_nm AND a.invoice_id = b.invoice_id AND a.cliente = b.cliente
    ),

    origen_n_1 AS (--CARTERA --MA_CABLE no se tiene en cuenta en el calculo n-1
    
      SELECT 
        CAST(mes_string AS INT64) AS id_mes,
        'CABLEMOVIL' AS comm_brand_ds,
        'mes_anterior' AS origen_info,
        a.data_month_id AS data_month_id_billing,
        a.customer_id AS CLIENTE,
        a.billing_tier_2,
        a.phone_nm,
        b.service_id,
        a.service_type,
        b.line_type_ds,
        a.account_id,
        c.SubCliente,
        a.invoice_id,
        a.invoice_date,
        a.init_date,
        a.end_date,
        CASE
          WHEN (a.billing_Tier_2 LIKE '%3P%' OR a.billing_Tier_2 LIKE '%CONV%')  THEN 'FMC'
          ELSE 'MO'
        END AS bundle_type,
        CASE
          WHEN a.billing_tier_1 = '6' AND a.billing_tier_2 != 'TELEFONIA MOVIL' THEN NULL
          ELSE a.billing_tier_1
        END AS tariff_id,
        UPPER(CASE
          WHEN b.tariff_ds LIKE '%AD3P%' AND a.billing_tier_2 NOT LIKE  '%ADICIONAL_3P%' THEN NULL
          WHEN (b.tariff_ds LIKE '%TRV%' OR b.tariff_ds IS NULL) THEN a.billing_tier_2
          ELSE b.tariff_ds
        END) AS tariff_ds,
        Producto_ID,
        CASE
          WHEN a.billing_tier_1 = '6' AND a.billing_tier_2 != 'TELEFONIA MOVIL' THEN 0
          ELSE a.imp_without_tax
        END AS imp_without_tax,
        b.activation_date,
        b.deactivation_date,
        CAST(NULL AS STRING) AS descripcion_tarzona,
        kpi_gross_add,
        CASE
          WHEN a.phone_nm IS NULL THEN 1
          ELSE ROW_NUMBER() OVER (PARTITION BY a.account_id, a.phone_nm,billing_tier_2, CAST(a.imp_without_tax AS STRING), a.init_date, a.end_date,a.invoice_date ORDER BY activation_date DESC)
        END AS n_control
      FROM billing a --`mm-datamart-kd.BILLING.billing_detail_xena` a
      LEFT JOIN (
        SELECT DISTINCT
          MSISDN, 
          CLIENTE AS id_cliente,  
          Producto_ID, 
          SubCliente,
          Bono.bono_id AS bono_id,    
          --ACTUALIZAR TABLA MES A MES ANTERIOR
        FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*`,
        --FROM `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_20241001`
        UNNEST (bono) AS bono
        WHERE data_month_id = CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH)) AS INT64)
      ) c ON a.phone_nm = CAST(c.Msisdn AS INT64) AND (a.billing_tier_1 = c.bono_id)
      LEFT JOIN `mm-datamart-kd.SERVICES.service_base_net` b ON a.phone_nm = b.phone_nm 
        AND b.service_id = CONCAT(a.phone_nm,a.customer_id) 
        AND LAST_DAY(b.activation_date) <= LAST_DAY(a.init_date) 
        AND (LAST_dAY(b.deactivation_date) >= a.end_date OR b.deactivation_date IS NULL)
        AND c.Producto_ID = b.tariff_id
      JOIN dealers d ON d.id_comisionista = a.customer_id
      --Quitamos TUCA y AVATEL para que no se tenga en cuenta en el recálculo
      LEFT JOIN trafico ON a.customer_id = trafico.id_comisionista
      LEFT JOIN grupo_avatel ON a.customer_id = grupo_avatel.id_avatel
      --
      WHERE a.comm_brand_ds IN ('CABLEMOVIL','EMBOU')
        AND a.invoice_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',mes_string),MONTH))
        --DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH) AND LAST_DAY(DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH))    
        AND NOT (
          -- a.billing_tier_2 LIKE '%CIRCUITO%' 
          -- OR a.billing_tier_2 LIKE '%TRV%'
          -- OR a.billing_tier_2 = 'FACTURACION MANUAL' 
          -- OR a.billing_tier_2 LIKE 'TARJETA%' 
          -- OR a.billing_tier_2 LIKE '%TARJETA%' 
          -- OR a.billing_tier_2 LIKE '%SIM%' 
          -- OR a.billing_tier_2 LIKE '% SIM%' 
          -- OR a.billing_tier_2 LIKE '%COMPENSACION POR CORTE DE SERVICIO%'
          -- OR a.billing_tier_2 = 'MES DESPLIEGUE DE RED' 
          a.billing_tier_2 = 'TELEFONIA MOVIL'
          -- OR a.billing_tier_2 IS NULL
        )
        AND (trafico.id_comisionista IS NULL AND grupo_avatel.id_avatel IS NULL)
    ), 

    agrupacion_n_1 AS (
      SELECT 
        invoice_id,
        cliente,
        SubCliente,
        service_id,
        bundle_type,
        line_type_ds,
        phone_nm, 
        Producto_ID,
        activation_date,
        CASE
          WHEN CONCAT(Producto_ID,' - ',tariff_ds,' - ',billing_tier_2) LIKE '%3P%' AND bundle_type = 'FMC' THEN '3P'
          ELSE NULL
        END comments
      FROM origen_n_1
      QUALIFY ROW_NUMBER() OVER(PARTITION BY phone_nm ORDER BY activation_date DESC) = 1
    ),

    base_inicial_n_1 AS (
      SELECT 
        id_mes,
        comm_brand_ds,
        origen_info,
        data_month_id_billing,
        COALESCE(a.CLIENTE,b.CLIENTE) AS CLIENTE,
        a.billing_tier_2,
        a.phone_nm,
        COALESCE(a.service_id,b.service_id) AS service_id,
        service_type,
        COALESCE(a.line_type_ds,b.line_type_ds) AS line_type_ds,
        account_id,
        UPPER(COALESCE(a.SubCliente, b.SubCliente)) AS SubCliente,
        a.invoice_id,
        invoice_date,
        init_date,
        end_date,
        COALESCE(b.bundle_type, a.bundle_type) AS bundle_type,
        tariff_id,
        tariff_ds,
        COALESCE(a.Producto_ID, b.Producto_ID) AS Producto_ID,
        imp_without_tax,
        COALESCE(a.activation_date, b.activation_date) AS activation_date,
        deactivation_date,
        descripcion_tarzona,
        kpi_gross_add,
        n_control,
        comments,
      FROM origen_n_1 a
      LEFT JOIN agrupacion_n_1 b ON a.phone_nm = b.phone_nm AND a.invoice_id = b.invoice_id AND a.cliente = b.cliente
    ),

    base_n_1 AS (
      SELECT *
      FROM base_inicial_n_1
      WHERE n_control = 1
    ),

    final AS (
      SELECT *
      FROM base_inicial

      UNION ALL

      SELECT *
      FROM base_n_1
    )

    SELECT *
    FROM final
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_arca`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

    SELECT *
    FROM `mm-commissions-reporting.TEMP.row_comisiones_base_arca` 
    WHERE 1=1
      AND NOT (
          billing_tier_2 LIKE '%CIRCUITO%' 
          OR billing_tier_2 LIKE '%TRV%'
          OR billing_tier_2 = 'FACTURACION MANUAL' 
          OR billing_tier_2 LIKE 'TARJETA%' 
          OR billing_tier_2 LIKE '%TARJETA%' 
          OR billing_tier_2 LIKE '%SIM%' 
          OR billing_tier_2 LIKE '% SIM%' 
          OR billing_tier_2 LIKE '%COMPENSACION POR CORTE DE SERVICIO%'
          OR billing_tier_2 = 'MES DESPLIEGUE DE RED' 
          OR billing_tier_2 IS NULL
        )

  ;

  --Montamos la query de creación de la tabla diaria ROW/
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre_row ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.row_comisiones_base_arca`';
  EXECUTE IMMEDIATE qry;
  --Montamos la query de creación de la tabla diaria FILTRADA/
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.comisiones_base_arca`';
  EXECUTE IMMEDIATE qry;
  END IF;

  --Caso especial en el que la facturación se ha hecho PERO, quedó un cablero por subir su información a billing
  --Hay que agregar este left a la ultima consulta de base_inicial y modificar en vez de un CREATE OR REPLACE TABLE A UN INSERT TABLE
    -- LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` a ON tabla_nombre.CLIENTE = b.id_comisionista
    -- WHERE canal = 'CM'
    --   AND id_mes = CAST(FORMAT_DATE('%Y%m',DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) AS INT64)
    --   AND tabla_nombre.CLIENTE IS NULL;

END