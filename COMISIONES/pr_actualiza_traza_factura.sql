BEGIN

--CALL `mm-commissions-reporting.COMISIONES.pr_actualiza_traza_factura`('completo',202603);  --modo --> completo ó mensual  -- id_mes_actual lo toma de la hoja de Control (2 meses hacia atrás)

      IF modo = 'completo' THEN
      CREATE OR REPLACE TABLE `mm-commissions-reporting.COMISIONES.transaccion_traza_factura` AS
            SELECT  t.commission_id
                  , t.id_mes
                  , x.id_fichero_trazabilidad
                  , b.id_fichero_factura
                  , agr_ser.agrupacion_servicio
                  , CAST(NULL AS STRING) AS CANAL_N0
                  , CAST(NULL AS STRING) AS CANAL_N1
                  , CAST(NULL AS STRING) AS CANAL_N2
                  , COALESCE(d.SEGMENTO,CAST(NULL AS STRING)) AS segmentacion
                  , COALESCE(d.CUENTA_CLIENTE,CAST(NULL AS STRING)) AS cuenta_cliente
                  , COALESCE(d.GRUPO,CAST(NULL AS STRING)) AS grupo
                  , COALESCE(d.PROVINCIA,CAST(NULL AS STRING)) AS provincia
                  , COALESCE(d.GERENTE_CUENTA,CAST(NULL AS STRING)) AS gerente_cuenta

            FROM `mm-commissions-reporting.COMISIONES.transacciones` t

            LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d 
                  ON  t.cif = d.documento 
                  AND t.id_comisionista = d.id_comisionista

            --trzabilidad XLSX
            LEFT JOIN (
                  SELECT * EXCEPT(rank)
                  FROM (
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,2 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        )
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
                  ) x
                  ON t.invoice_id = x.invoice_id AND t.estado = 'facturado'

            --Facturas pdf
            LEFT JOIN
            (
            SELECT * EXCEPT(rank)
            FROM (
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS id_fichero_factura
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_b2b_cablemovil`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_b2b_marblanca`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_etnico`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_no_exclusivo`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_resto`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_historic`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  )
            QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
            ) b
            ON t.invoice_id = b.invoice_id

            --agrupacion_servicio
            LEFT JOIN `mm-commissions-reporting.COMISIONES.accesos_comisiones` agr_ser 
                  ON  t.marca = agr_ser.marca
                  AND t.service_type = agr_ser.service_type
                  AND t.agrupacion_canal = agr_ser.agrupacion_canal

            --WHERE t.commission_id IN ('ARCT_202602_CM_100','ARCA_202602_CM_554950')

            QUALIFY ROW_NUMBER() OVER (PARTITION BY t.commission_id, x.id_fichero_trazabilidad, b.id_fichero_factura, agr_ser.agrupacion_servicio ORDER BY segmentacion DESC, cuenta_cliente DESC, grupo DESC) = 1;

      ELSE IF modo = 'mensual' THEN

      DELETE
      FROM `mm-commissions-reporting.COMISIONES.transaccion_traza_factura`
      WHERE 1 = 1
        AND id_mes >= id_mes_actual;

      INSERT INTO `mm-commissions-reporting.COMISIONES.transaccion_traza_factura`
            SELECT  t.commission_id
                  , t.id_mes
                  , x.id_fichero_trazabilidad
                  , b.id_fichero_factura
                  , agr_ser.agrupacion_servicio
                  , CAST(NULL AS STRING) AS CANAL_N0
                  , CAST(NULL AS STRING) AS CANAL_N1
                  , CAST(NULL AS STRING) AS CANAL_N2
                  , COALESCE(d.SEGMENTO,CAST(NULL AS STRING)) AS segmentacion
                  , COALESCE(d.CUENTA_CLIENTE,CAST(NULL AS STRING)) AS cuenta_cliente
                  , COALESCE(d.GRUPO,CAST(NULL AS STRING)) AS grupo
                  , COALESCE(d.PROVINCIA,CAST(NULL AS STRING)) AS provincia
                  , COALESCE(d.GERENTE_CUENTA,CAST(NULL AS STRING)) AS gerente_cuenta

            FROM `mm-commissions-reporting.COMISIONES.transacciones` t

            LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d 
                  ON  t.cif = d.documento 
                  AND t.id_comisionista = d.id_comisionista

            --trzabilidad XLSX
            LEFT JOIN (
                  SELECT * EXCEPT(rank)
                  FROM (
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,1 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        UNION ALL
                        (
                        SELECT
                              REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                              ,file_id AS id_fichero_trazabilidad
                              ,created_date
                              ,2 AS rank
                        FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
                        WHERE UPPER(file_name) LIKE '%XLS%'
                        QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
                        )
                        )
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
                  ) x
                  ON t.invoice_id = x.invoice_id AND t.estado = 'facturado'

            --Facturas pdf
            LEFT JOIN
            (
            SELECT * EXCEPT(rank)
            FROM (
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS id_fichero_factura
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_b2b_cablemovil`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_b2b_marblanca`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_etnico`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_no_exclusivo`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_resto`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  UNION ALL
                  (
                  SELECT
                        SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
                        ,file_id AS fileid
                        ,created_date
                        ,1 AS rank
                  FROM `mm-commissions-reporting.REPORTED.log_files_facturas_historic`
                  WHERE UPPER(file_name) LIKE '%PDF%'
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
                  )
                  )
            QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
            ) b
            ON t.invoice_id = b.invoice_id

            --agrupacion_servicio
            LEFT JOIN `mm-commissions-reporting.COMISIONES.accesos_comisiones` agr_ser 
                  ON  t.marca = agr_ser.marca
                  AND t.service_type = agr_ser.service_type
                  AND t.agrupacion_canal = agr_ser.agrupacion_canal

            WHERE t.id_mes >= id_mes_actual
              --AND t.commission_id IN ('ARCT_202602_CM_100','ARCA_202602_CM_554950')

            QUALIFY ROW_NUMBER() OVER (PARTITION BY t.commission_id, x.id_fichero_trazabilidad, b.id_fichero_factura, agr_ser.agrupacion_servicio ORDER BY segmentacion DESC, cuenta_cliente DESC, grupo DESC) = 1;

      END IF;
      END IF;

END