BEGIN

--Declaramos las variables que se van a usar a lo largo del procedimiento /
DECLARE mes_string,mes_liqui, qry, tabla_nombre STRING;
DECLARE mes DATE;

SET mes = DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH),MONTH);
SET mes_string = FORMAT_DATE('%Y%m',mes);
SET mes_liqui  = FORMAT_DATE('%Y%m%d',mes);
SET tabla_nombre = CONCAT('mm-commissions-reporting.B2B.','comisiones_base_arad_', mes_liqui, '');

-- CALL `mm-commissions-reporting.B2B.pr_cartera_comisiones_base_arad`()

IF NOT EXISTS(
    SELECT *
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE canal = 'ADA'
      AND id_mes = CAST(mes_string AS INT64)
      AND (commission_id LIKE 'ARAD%'AND commission_id LIKE CONCAT("ARAD_",CAST(mes_string AS INT64),"_%"))
      AND mes_liquidado = '2025-11-01'
    GROUP BY ALL
    ) THEN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_base_arad`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)) AS

  WITH 

    base AS (
      SELECT DISTINCT 
        FORMAT("%dT%d",EXTRACT(YEAR FROM PARSE_DATE('%Y%m', CAST(data_month_id AS STRING))),EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', CAST(data_month_id AS STRING)))) AS trimestre,
        FORMAT("%dT%d",EXTRACT(YEAR FROM PARSE_DATE('%Y%m', CAST(data_month_id AS STRING))),
          CASE 
            WHEN EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', CAST(data_month_id AS STRING))) - 1 = 0 THEN 4
            ELSE EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', CAST(data_month_id AS STRING))) - 1
          END) AS trimestre_indice,
        data_month_id AS id_mes,
        Cliente,
        SubCliente AS account_id,
        Msisdn AS phone_nm,
        --REVISAR ACTIVATION_DATE PARA VALORES DISTINTOS A FECHA
        CASE
          WHEN Fecha_Activacion IN ('W45486','216517','216042','<fecha>') THEN NULL
          ELSE PARSE_DATE('%Y%m%d',Fecha_Activacion)
        END AS activation_date,
        COALESCE(Tarifa_ID,SUBSTRING(Bono_Compartido_Descripcion,1,5)) AS bono_id,
        COALESCE(Producto_Descripcion,SUBSTRING(Bono_Compartido_Descripcion,7)) AS bono_name,
        Producto_ID,
        Total_Facturacion AS imp_without_tax
      --ALTUALIZAR EL FROM DE BASE TODOS LOS MESES --
      FROM  `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*` a
      WHERE 1=1
        AND a.cliente = '216517'
        AND a.data_month_id = CAST(mes_string AS INT64)
    )

    SELECT *
    FROM base
  ;

    --Montamos la query de creación de la tabla diaria /
  SET qry = 
  'CREATE OR REPLACE TABLE ' ||  tabla_nombre ||  ' AS SELECT * FROM ' || '`mm-commissions-reporting.TEMP.comisiones_base_arad`';
  EXECUTE IMMEDIATE qry;
  END IF;
END