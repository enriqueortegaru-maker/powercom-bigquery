BEGIN

DECLARE canales_pr ARRAY<STRING>;

DECLARE prefijo STRING;

SET canales_pr = ['ENK'];

SET prefijo = 'REN_WA';

--CALL TERMINALES.pr_W_A_terminales_mes(202512,202511,202601,'2026-01-01');

    -- BORRAMOS LO QUE HAYA CALCULADO EN EL MES_PR_LIQUIDACION DE ESTE PROCESO POR SI NECESITAMOS RELANZARLO
    DELETE
    FROM `mm-commissions-reporting.COMISIONES.transacciones`
    WHERE canal IN UNNEST(canales_pr)
      AND id_mes = mes_pr_liquidacion
      AND commission_id LIKE prefijo||'_'||CAST(mes_pr_liquidacion AS STRING)||'_%'
      AND estado IN ('calculado','validado')
    ;
 

    --OBTENEMOS EL LISTADO DE LOS WRONG ADD--
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.W_A_terminales_mes`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS(
    SELECT IMEI, order_id, phone_nm, customer_id, service_id, id_comisionista, claim_code
    FROM `mm-commissions-reporting.TERMINALES.TERMINALES`
    WHERE id_mes = mes_pr_liquidacion
      AND claim_code like 'WRONG_ADD_20%'
      AND process_code IN ('REAL','AJUS_MANUAL')
      AND estado IN ('calculado','validado')
    GROUP BY ALL
    ORDER BY 1,2
  );

    --CREAMOS TRANSACCIONES PARA INSERTAR--

  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.calculo_W_A`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS(
  
  SELECT 
    calculo_wa.*
    ,prefijo||'_'||CAST(mes_pr_liquidacion AS STRING)||'_'||ROW_NUMBER () OVER () AS commission_id
  FROM (
      SELECT 
        'calculado' AS estado,
        mes_a_liquidar AS mes_liquidado,
        mes_pr_liquidacion AS id_mes,
        agrupacion_canal,
        canal,
        CASE WHEN concepto LIKE 'B - %' THEN CONCAT('E - ',SUBSTR(concepto,5,100))
             WHEN concepto LIKE 'D - %' THEN CONCAT('E - ',SUBSTR(concepto,5,100))
             WHEN concepto LIKE 'F - %' THEN CONCAT('H - ',SUBSTR(concepto,5,100))
             WHEN concepto LIKE 'G - %' THEN CONCAT('H - ',SUBSTR(concepto,5,100))
             ELSE concepto END AS concepto,
        tipo_concepto,
        unidades,
        (comision * -1) AS comision,
        tra.seller AS id_comisionista,
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
        tra.phone_nm AS phone_nm,
        tariff_id,
        tariff_ds,
        tra.service_id AS service_id,
        account_id,
        tra.customer_id AS customer_id,
        line_type_ds,
        bundle_type,
        technology_ds,
        billing_type_ds,
        sale_date,
        activation_date,
        CAST (mes_a_liquidar AS DATE) AS deactivation_date,
        tra.order_id AS order_id,
        order_type_agg,
        cod_segmento,
        cod_marca,
        cod_tipo_contrato,
        cod_producto,
        cod_canal,
        campaign_code,
        serial_number,
        tax_base,
        wa.claim_code AS claim_code, 
        process_code,
        comments,
        facturador,
        CAST (NULL AS STRING) AS proceso_sap,
        CAST (NULL AS STRING) AS id_registro,
        CAST (NULL AS STRING) AS invoice_id,
        sociedad,
        CAST (NULL AS STRING) AS bp,
        CAST (NULL AS STRING) AS cuenta_contable,
        CAST (NULL AS STRING) AS centro_coste,
        CAST (NULL AS STRING) AS documento_sap,
        CAST (NULL AS STRING) AS documento_sap_posicion,
        CAST (NULL AS STRING) AS fecha_contabilizacion,
        CAST (NULL AS TIMESTAMP) AS creado,
        CAST (NULL AS TIMESTAMP) AS modificado,
        CAST (NULL AS STRING) AS id_factura_drive,
        -- [CAST (NULL AS STRING)] AS emails_acceso_trazabilidad

      FROM `mm-commissions-reporting.COMISIONES.transacciones` tra
        INNER JOIN `mm-commissions-reporting.TEMP.W_A_terminales_mes` wa
          ON  wa.IMEI = tra.serial_number
          AND wa.phone_nm = tra.phone_nm
          AND wa.customer_id = tra.customer_id
          AND wa.service_id = tra.service_id
      --    AND wa.id_comisionista = tra.id_comisionista
      --    AND wa.order_id = tra.order_id
      WHERE tipo_concepto IN ('CURE')
        AND id_mes >= mes_revision_tra
      ) calculo_wa

  LEFT JOIN (
            SELECT DISTINCT serial_number, phone_nm, seller, activation_date, concepto
            FROM `mm-commissions-reporting.COMISIONES.transacciones`
            WHERE id_mes = mes_pr_liquidacion
            AND tipo_concepto = 'CURE'
            AND SUBSTR(concepto,1,4) IN ('E - ','Z - ')
            ) calculadas
        ON calculo_wa.serial_number = calculadas.serial_number
        AND calculo_wa.concepto = calculadas.concepto
        AND calculo_wa.phone_nm = calculadas.phone_nm
  
  WHERE calculadas.serial_number IS NULL
  );


CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('REN_WA', mes_pr_liquidacion, canales_pr, 'TEMP.calculo_W_A', 'ACTUALIZAR');

END