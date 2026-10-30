BEGIN

  DECLARE canales_str,prefijo_tabla,tabla_nombre,commission_id_input,comm_brand, sql  STRING;
  DECLARE existe_uds_claw_pos BOOL;

-- CALL `mm-commissions-reporting.COMISIONES.pr_validaciones_B2BC`(202510, ['MB','MBA']);

  SET canales_str = ARRAY_TO_STRING(canales_pr, ',');

  SET prefijo_tabla = 
      CASE 
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('MB','MBA'))  THEN 'armb'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('CM','CALT')) THEN 'arca'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x = 'PAR')          THEN 'arpa'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x = 'ADA')          THEN 'arad'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('NASH', 'NTCLI', 'HICLI', 'OCE'))  THEN 'NNS'
        ELSE NULL
      END;

SET commission_id_input =
      CASE
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('MB','MBA'))  THEN 'ARMB%'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('CM','CALT')) THEN 'ARCA%'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x = 'PAR')          THEN 'ARPA%'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x = 'ADA')          THEN 'ARAD%'
        -- WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('NASH', 'NTCLI', 'HICLI', 'OCE'))  THEN 'NNS'
        ELSE NULL
      END;

SET comm_brand = 
      CASE
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('MB','MBA'))  THEN 'MARBLANCA'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('CM','CALT')) THEN 'CABLEMOVIL'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x = 'PAR')          THEN 'PARLEM'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x = 'ADA')          THEN 'ADAMO'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(canales_str, ',')) x WHERE x IN ('NASH', 'NTCLI', 'HICLI', 'OCE'))  THEN 'NETLLAR'
      END;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

    SELECT * EXCEPT(emails_acceso_trazabilidad)
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE 1=1
      AND id_mes = mes_int
      AND canal IN UNNEST(SPLIT(canales_str, ','))
  ;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.B2BC_validaciones_errores`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS

    SELECT 
      CAST(NULL AS STRING) AS errores,
      CAST(NULL AS STRING) AS id_comisionista,
      CAST(NULL AS STRING) AS nombre_comercio,
      CAST(NULL AS STRING) AS phone_nm,
      CAST(NULL AS STRING) AS comentarios
  ;

  -- -- 🔸 Validador 1: facturación base
    SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.comisiones_base_', prefijo_tabla, '_', CAST(mes_int AS STRING), '01');

    SET sql = '';
    SET sql = sql ||'INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios)';
    SET sql = sql || 'WITH base AS (';
    SET sql = sql ||    'SELECT id_mes, SUM(imp_without_tax) AS facturacion_original FROM ';
    SET sql = sql ||    tabla_nombre;
    SET sql = sql ||    ' GROUP BY ALL';
    SET sql = sql ||  '), ';
    SET sql = sql ||  'transacciones AS (';
    SET sql = sql ||    'SELECT id_mes, SUM(tax_base) AS tax_base_transacciones ';
    SET sql = sql ||    'FROM `mm-commissions-reporting.COMISIONES.transacciones` ';
    SET sql = sql ||    "WHERE canal IN UNNEST(SPLIT('" || canales_str || "', ',')) ";
    SET sql = sql ||   ' AND id_mes = ' || mes_int || ' AND tipo_concepto = "AIRT"'; 
    SET sql = sql || " AND commission_id LIKE '" || commission_id_input || "' ";
    SET sql = sql ||    'GROUP BY ALL';
    SET sql = sql ||  ') ';

    SET sql = sql || 'SELECT "Validación facturación base general" AS ERRORES,CAST(NULL AS STRING) AS id_comisionista,CAST(NULL AS STRING) AS nombre_comercio,CAST(NULL AS STRING) AS phone_nm,CONCAT("Facturacion original = ",ROUND(facturacion_original,2), " , Facturacion transacciones = ",ROUND(tax_base_transacciones,2), " , Diferencia = ", ROUND(facturacion_original -  tax_base_transacciones,2))';
    SET sql = sql || 'FROM base a ';
    SET sql = sql || 'LEFT JOIN transacciones b ON b.id_mes = a.id_mes ';
    SET sql = sql || 'WHERE b.id_mes IS NOT NULL';

    EXECUTE IMMEDIATE (sql);


  -- 🔸 Validador 2: duplicados por phone_nm D%

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios) 
      
      SELECT 
        'Error: Teléfono duplicado con concepto D%'AS ERRORES,
        id_comisionista,
        nombre_comercio, 
        phone_nm, 
        STRING_AGG( concepto, ' | ') AS comentarios
      FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
      WHERE 1=1
        AND concepto LIKE 'D -%'
        AND tipo_concepto = 'UPFR'
      GROUP BY ALL
      HAVING COUNT(phone_nm) > 1
    ;

  -- 🔸 Validador 3: duplicados por phone_nm A - Servicion base.

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios) 

      SELECT 'Error: Teléfono duplicado con concepto A - Servicio base' AS ERRORES,
        id_comisionista,
        nombre_comercio,
        phone_nm,
        CAST(NULL AS STRING) AS comentarios
      FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
      WHERE 1=1
        AND concepto LIKE 'A -%'
        AND tipo_concepto = 'UPFR'
      GROUP BY ALL
      HAVING COUNT(*) > 1
    ;

  -- 🔸 Validador 4: duplicados por importe en cartera.

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios)
  
      SELECT
        'Aviso: La cartera ha aumentado exponencialmente respecto al mes pasado' AS ERRORES,
        id_comisionista,
        nombre_comercio,
        CAST(NULL AS STRING) AS phone_nm,
        CONCAT('comision_mes_ant = ',ROUND(comision_mes_ant,2),' - ','comision_mes_act = ',ROUND(comision_mes_act,2), ' - ','variacion_pct = ',ROUND(variacion_pct,2)) AS comentarios
      FROM
        (SELECT
          id_comisionista,
          nombre_comercio,
          SUM(CASE WHEN id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH)) AS INT64) THEN comision END) AS comision_mes_ant,
          SUM(CASE WHEN id_mes = mes_int THEN comision END) AS comision_mes_act,
          SAFE_DIVIDE(
            (SUM(CASE WHEN id_mes = mes_int THEN comision END) -
            SUM(CASE WHEN id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH)) AS INT64) THEN comision END)),
            SUM(CASE WHEN id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH)) AS INT64) THEN comision END)
          ) * 100 AS variacion_pct,
          IF(
            SAFE_DIVIDE(
              (SUM(CASE WHEN id_mes = mes_int THEN comision END) -
              SUM(CASE WHEN id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH)) AS INT64) THEN comision END)),
              SUM(CASE WHEN id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH)) AS INT64) THEN comision END)
            ) * 100 > 50,
            "Revisar posible duplicado en cartera",
            NULL
          ) AS cond
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE tipo_concepto = 'AIRT'
            AND canal IN UNNEST(SPLIT(canales_str, ','))
            AND id_mes IN (CAST(FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH)) AS INT64), mes_int)
          GROUP BY id_comisionista, nombre_comercio
          HAVING cond IS NOT NULL
      )
    ;
  -- 🔸 Validador 5: unidades clawback positivas.

    SET existe_uds_claw_pos = EXISTS (
      SELECT DISTINCT 1
      FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
      WHERE 1=1
        AND concepto LIKE 'E %'
        AND unidades = 1
    )
  ;

    IF existe_uds_claw_pos THEN
      INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` VALUES ('Error: Existen unidades de clawback en positivo',NULL,NULL,NULL,NULL);
    END IF
  ;

  -- 🔸 Validador 6: Teléfonos con importe mayor a 100€.

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios) 

      SELECT 'Aviso: Teléfono con comisión mayor a 100€' AS ERRORES,
        id_comisionista,
        nombre_comercio,
        phone_nm,
        CONCAT('Comisión = ',CAST(SUM(comision) AS STRING)) AS comentarios 
      FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
      WHERE 1=1
        AND tipo_concepto = 'AIRT'
        AND phone_nm IS NOT NULL
      GROUP BY ALL
      HAVING SUM(comision) >= 100

      --A partir de la media de facturacion de todos los números de telefonos + 100€
  ;

  -- 🔸 Validador 7: Esta tarifa no se está comisionando.

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios) 

    --Separamos CM del resto por la traducción de los códigos de bonos.
      WITH 
        ventas AS (
          SELECT 
            comm_brand_ds,
            tariff_id,
            tariff_ds,
          FROM `mm-datamart-kd.SERVICES.service_base_net` a
          JOIN (
              SELECT
                invoice_date,
                phone_nm
              FROM `mm-datamart-kd.BILLING.billing_detail_net` 
              GROUP BY ALL
          )b ON a.phone_nm = b.phone_nm
          WHERE 1=1
            AND b.invoice_date BETWEEN DATE_TRUNC(DATE_ADD(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), INTERVAL 1 MONTH), MONTH) AND LAST_DAY(DATE_ADD(PARSE_DATE('%Y%m', CAST(mes_int AS STRING)), INTERVAL 1 MONTH), MONTH)
            AND comm_brand_ds = 
                CASE
                  WHEN EXISTS (SELECT 1 FROM UNNEST(canales_pr) x WHERE x IN ('MB','MBA'))  THEN 'MARBLANCA'
                  WHEN EXISTS (SELECT 1 FROM UNNEST(canales_pr) x WHERE x = 'PAR') THEN 'PARLEM'
                  WHEN EXISTS (SELECT 1 FROM UNNEST(canales_pr) x WHERE x = 'SW') THEN 'SWENO'
                  WHEN EXISTS (SELECT 1 FROM UNNEST(canales_pr) x WHERE x = 'ADA') THEN 'ADAMO'
                END
            AND activation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), MONTH))
          GROUP BY ALL
        ), 

        cartera_cm AS (
          SELECT 
            tariff_id,
            tariff_ds,
            billing_tier_2
          FROM `mm-commissions-reporting.B2B.comisiones_base_arca_*`
          WHERE 1=1
            AND _TABLE_SUFFIX =  CONCAT(CAST(mes_int AS STRING), '01')
          GROUP BY ALL
        ),

        CM AS (
          SELECT 
            'Error: tarifa no comisionada' AS ERRORES,
            CAST(NULL AS STRING) AS id_comisionista,
            CAST(NULL AS STRING) AS  nombre_comercio,
            CAST(NULL AS STRING) AS phone_nm,
            CONCAT('Tariff_id = ',a.tariff_id,', ','Tariff_ds = ', a.tariff_ds) AS comentarios
          FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada` a
          LEFT JOIN cartera_cm b ON a.tariff_id = b.tariff_id
          WHERE 1=1
            AND a.canal IN ('CM','CALT')
            AND b.tariff_id IS NULL
            AND a.tipo_concepto = 'AIRT'
          GROUP BY ALL
        ),

        cartera_g AS (
          SELECT 
            'Error: tarifa no comisionada' AS ERRORES,
            CAST(NULL AS STRING) AS id_comisionista,
            CAST(NULL AS STRING) AS nombre_comercio,
            CAST(NULL AS STRING) AS phone_nm,
            CONCAT('Tariff_id = ',a.tariff_id,', ','Tariff_ds = ', a.tariff_ds) AS comentarios,
          FROM ventas a
          LEFT JOIN (
            SELECT 
              tariff_id, 
              tariff_ds,
            FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
            WHERE 1=1
            GROUP BY ALL
          ) b ON a.tariff_id = b.tariff_id
          WHERE 1=1
            AND b.tariff_id IS NULL
          GROUP BY ALL
        ),

        final AS (
          SELECT *
          FROM CM
          WHERE comentarios IS NOT NULL

          UNION ALL

          SELECT *
          FROM cartera_g
          WHERE comentarios IS NOT NULL
        )

      SELECT *
      FROM final
      WHERE 1=1
  ;

  -- 🔸 Validador 8: Id_comisionistas que no se están comisionando.

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios) 

      SELECT 
        'Error: id_comisionista sin comisión' AS ERRORES,
        current_sfid_id AS id_comisionista,
        nombre_comercio,
        CAST(NULL AS STRING) AS phone_nm,
        CAST(NULL AS STRING) AS comentarios
      FROM (
        SELECT 
          CASE
            WHEN 'SW' IN UNNEST(SPLIT(canales_str, ','))  THEN CONCAT(current_sfid_id,'-',current_user_store)
            WHEN ('MB' IN UNNEST(SPLIT(canales_str, ',')) OR 'MBA' IN UNNEST(SPLIT(canales_str, ','))) AND current_sfid_id = 'C09-00724-0001' THEN 'C09-00724' 
            WHEN ('MB' IN UNNEST(SPLIT(canales_str, ',')) OR 'MBA' IN UNNEST(SPLIT(canales_str, ','))) AND current_sfid_id LIKE 'C09-00716%'  THEN 'C09-00716' --Unificamos tiendas por correo de soporte comercial.
            ELSE current_sfid_id
          END AS current_sfid_id,
          nombre_comercio
        FROM `mm-datamart-kd.SERVICES.ventas_base_net` a
        LEFT JOIN (
          SELECT 
            id_comisionista,
            nombre_comercio
          FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada` 
          WHERE 1=1
        ) b ON a.current_sfid_id = b.id_comisionista
        WHERE 1=1
          AND comm_brand_ds = comm_brand
          -- AND activation_date >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
          AND b.id_comisionista IS NULL
          AND a.current_sfid_id != 'NULL'
          AND a.activation_date IS NOT NULL
        GROUP BY ALL
          )
      WHERE 1=1
        AND current_sfid_id NOT IN (
          SELECT id_comisionista
          FROM `mm-commissions-reporting.GS.DEALERS_B2BC` 
        )
      GROUP BY ALL
  ;

  -- 🔸 Validador 9: Clawback aplicados con fechas distintas al mes de calculo.

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista,nombre_comercio, phone_nm, comentarios) 

      SELECT 'Error: Se están aplicando clawback con fecha anterior al mes de calculo' AS ERRORES,
        id_comisionista,
        nombre_comercio,
        phone_nm,
        CONCAT('Comisión = ',CAST(SUM(comision) AS STRING)) AS comentarios 
      FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
      WHERE 1=1
        AND tipo_concepto = 'UPFR'
        AND concepto LIKE 'E -%'
        AND deactivation_date < DATE_TRUNC(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), MONTH)
      GROUP BY ALL
  ;

  -- 🔸 Validador 10: Clawback aplicados con diferencia de fechas mayor a un año.

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista, nombre_comercio, phone_nm, comentarios) 

      SELECT 'Error: Se están aplicando clawback con diferencia de fechas mayores a un año' AS ERRORES,
        id_comisionista,
        nombre_comercio,
        phone_nm,
        CONCAT('Activation_date =',activation_date,' , ','Deactivation_date =',deactivation_date,' , ','Comisión = ',CAST(SUM(comision) AS STRING)) AS comentarios 
      FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
      WHERE 1=1
        AND tipo_concepto = 'UPFR'
        AND concepto LIKE 'E -%'
        AND DATE_DIFF(deactivation_date,activation_date,DAY) > 366 
        AND canal != 'ADA'
      GROUP BY id_comisionista,nombre_comercio,phone_nm,activation_date,deactivation_date
  ;

  -- 🔸 Validador 11 Clawback que no se están aplicando

    INSERT INTO `mm-commissions-reporting.TEMP.B2BC_validaciones_errores` (ERRORES, id_comisionista, nombre_comercio, phone_nm, comentarios) 

    WITH
      ventas AS (
        SELECT phone_nm, activation_date,deactivation_date
      FROM `mm-datamart-kd.SERVICES.ventas_base_net`
      WHERE 1=1
        AND deactivation_date BETWEEN DATE_TRUNC(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), MONTH) AND LAST_DAY(DATE_TRUNC(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)), MONTH))
        AND comm_brand_ds = comm_brand
        AND activation_date IS NOT NULL
      GROUP BY ALL
      )

      SELECT 'Error: No se están aplicando el clawback a estas lineas' AS ERRORES,
        id_comisionista,
        nombre_comercio,
        a.phone_nm,
        CONCAT('Concepto: ',a.concepto,' , ','Activation_date =',a.activation_date,' , ','Deactivation_date =',b.deactivation_date,' , ','Comisión = ',CAST(SUM(comision) AS STRING)) AS comentarios 
      FROM `mm-commissions-reporting.COMISIONES.transacciones` a --Transacciones original
      LEFT JOIN ventas b ON CAST(b.phone_nm AS STRING) = a.phone_nm AND a.activation_date = b.activation_date
      WHERE 1=1
        AND a.concepto LIKE 'A -%'
        AND estado != 'rechazado'
        AND canal IN UNNEST(SPLIT(canales_str, ','))
        AND DATE_DIFF(b.deactivation_date,a.activation_date,DAY) < 366
        AND tipo_concepto = 'UPFR'
        AND a.phone_nm NOT IN (
          SELECT phone_nm
          FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
          WHERE 1=1
            AND concepto LIKE 'E - Ser%'
        )
      GROUP BY id_comisionista,nombre_comercio,phone_nm,a.concepto,a.activation_date,b.deactivation_date

      UNION ALL

      SELECT 'Error: No se están aplicando el clawback a estas lineas' AS ERRORES,
        id_comisionista,
        nombre_comercio,
        a.phone_nm,
        CONCAT('Concepto: ',a.concepto,' , ','Activation_date =',a.activation_date,' , ','Deactivation_date =',b.deactivation_date,' , ','Comisión = ',CAST(SUM(comision) AS STRING)) AS comentarios 
      FROM `mm-commissions-reporting.COMISIONES.transacciones` a --Transacciones original
      LEFT JOIN ventas b ON CAST(b.phone_nm AS STRING) = a.phone_nm AND a.activation_date = b.activation_date
      WHERE 1=1
        AND a.concepto LIKE 'D -%'
        AND estado != 'rechazado'
        AND canal IN UNNEST(SPLIT(canales_str, ','))
        AND DATE_DIFF(b.deactivation_date,a.activation_date,DAY) < 366
        AND tipo_concepto = 'UPFR'
        AND a.phone_nm NOT IN (
          SELECT phone_nm
          FROM `mm-commissions-reporting.TEMP.B2BC_transacciones_filtrada`
          WHERE 1=1
            AND concepto NOT LIKE 'E - Ser%'
            AND concepto LIKE 'E -%'
        )
      GROUP BY id_comisionista,nombre_comercio,phone_nm,a.concepto,a.activation_date,b.deactivation_date

  ;
END