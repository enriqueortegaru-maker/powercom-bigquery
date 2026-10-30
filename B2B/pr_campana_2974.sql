BEGIN

  SELECT 
      'CABCAMP2'||'_'||CAST(id_mes_liquidacion AS STRING)||'_'||'CM_2974'||'_'||row_number () over () AS commission_id, *

  -- TENEMOS QUE METER UN UNION ALL CON LOS CLAWBACKS, PARA QUE LLEVEN UN ÚNICO commission_id

  FROM (

      --D - Camp. Cable ID: 2974
    SELECT
        'calculado' AS estado
      , inicio_mes_liquidacion AS mes_liquidado
      , id_mes_liquidacion AS id_mes
      , CASE WHEN UBA.comm_brand_ds = 'CABLEMOVIL' THEN 'B2B - Cablemovil' ELSE CONCAT('B2B - ',UBA.comm_brand_ds) END AS agrupacion_canal
      , CASE WHEN UBA.comm_brand_ds = 'CABLEMOVIL' THEN 'CM' ELSE CONCAT('CANAL_TBD - ',UBA.comm_brand_ds) END AS canal
      , CONCAT('D - Camp. Cable ID: ',CAST(GSC.ID_SUBCAMPANA AS STRING)) AS concepto
      , 'UPFR' AS tipo_concepto
      , CAST(1 AS INT64) AS unidades
      , GSC.PxQ_MAXIMO AS comision
      , GSC.CODIGO_XENA AS id_comisionista
      , GSC.CODIGO_XENA AS distribuidor
      , GSC.CODIGO_XENA AS sfid_id
      , GSC.CODIGO_XENA AS seller
      , GSC.CLIENTE AS nombre_comercio
      , GSC.CLIENTE AS razon_social
      , DC.documento AS cif
      , CASE WHEN DC.zona_fiscal = '#N/A' THEN CAST(NULL AS STRING) ELSE DC.zona_fiscal END AS zona_fiscal
      , CAST(NULL AS STRING) AS cond_pago
      , UBA.comm_brand_ds AS marca
      , UBA.service_type AS service_type
      , UBA.phone_nm AS phone_nm
      , UBA.activation_tariff_id AS tariff_id
      , UBA.activation_tariff_ds AS tariff_ds
      , UBA.service_id AS service_id
      , UBA.account_id AS account_id
      , UBA.cliente AS customer_id
      , UBA.line_type_ds AS line_type_ds
      , UBA.bundle_type AS bundle_type
      , UBA.technology_ds AS technology_ds
      , UBA.billing_type_ds AS billing_type_ds
      , UBA.activation_date AS sale_date
      , UBA.activation_date AS activation_date
      , UBA.deactivation_date AS deactivation_date
      , UBA.account_id AS order_id
      , CAST(NULL AS STRING) AS order_type_agg
      , `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(UBA.segment_ds,UBA.comm_brand_ds) AS cod_segmento
      , `mm-commissions-reporting.COMISIONES.f_cod_marca`(UBA.brand_aggr,UBA.service_type) AS cod_marca
      , CASE WHEN UBA.billing_type_ds = 'PREPAID' THEN '10'
            WHEN UBA.bundle_type = 'FMC' AND UBA.line_type_ds = 'MAIN' THEN (CASE WHEN UBA.technology_ds = 'ADSL' THEN '60' ELSE '61' END)
            WHEN UBA.bundle_type = 'FMC' THEN (CASE WHEN UBA.technology_ds = 'ADSL' THEN '66' ELSE '67' END)
            WHEN UBA.bundle_type = 'MO' AND UBA.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND UBA.comm_brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
            ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(UBA.billing_type_ds, UBA.service_type, UBA.bundle_type, UBA.technology_ds, UBA.comm_brand_ds, UBA.line_type_ds)
            END AS cod_tipo_contrato
      , CASE WHEN UBA.comm_brand_ds IN ('ADAMO','CABLEMOVIL') THEN '022'
            WHEN UBA.comm_brand_ds IN ('MARBLANCA') THEN '039'
            WHEN UBA.comm_brand_ds IN ('EUSKALTEL') THEN '040'
            WHEN UBA.comm_brand_ds IN ('NASH','NETLLAR','OCEAN') THEN '999'
            ELSE '999' END AS cod_producto
      , CASE WHEN UBA.comm_brand_ds IN ('ADAMO','ALTERNA','CABLEMOVIL','HITS','MARBLANCA','NASH','NETLLAR','OCEAN','PARLEM') THEN '30'
            ELSE '999' END AS cod_canal
      , GSC.campana AS campaign_code
      , CAST(NULL AS STRING) AS serial_number
      , CAST(NULL AS STRING) AS tax_base
      , CAST(NULL AS STRING) AS claim_code
      , 'CABCAMP2'||'_'||CAST(id_mes_liquidacion AS STRING)||'_'||'CM' AS process_code
      , 'Autofactura' AS comments
      , 'C_MANUAL' AS facturador
      , CAST(NULL AS STRING) AS proceso_sap
      , CAST(NULL AS STRING) AS id_registro
      , CAST(NULL AS STRING) AS invoice_id
      , 'X001' AS sociedad
      , CAST(NULL AS STRING) AS bp
      , CAST(NULL AS STRING) AS cuenta_contable
      , CAST(NULL AS STRING) AS centro_coste
      , CAST(NULL AS STRING) AS documento_sap
      , CAST(NULL AS STRING) AS documento_sap_posicion
      , CAST(NULL AS STRING) AS fecha_contabilizacion
      , CURRENT_TIMESTAMP () AS creado
      , CAST(NULL AS STRING) AS modificado
      , CAST(NULL AS STRING) AS id_factura_drive
      , CAST(NULL AS STRING) AS emails_acceso_trazabilidad

    FROM(
      --D - Camp. Cable ID: 2974
      SELECT *
      FROM `mm-commissions-reporting.TEMP.upfronts_base_arca`
      WHERE cliente IN ('F00856')  --CATEGORIZACIÓN
        AND group_donor NOT IN ('GRUPO MASMOVIL','ORANGE') --Operadores_donantes
        --AND activation_date_main_line BETWEEN inicio_mes_liquidacion AND fin_mes_liquidacion --DESDE	HASTA
        AND activation_date BETWEEN inicio_mes_liquidacion AND fin_mes_liquidacion --DESDE	HASTA
        AND bundle_type = 'MO' --TIPO LINEA
        AND PVP_ARPU >= 1   --PVP Desde
    ) UBA
 
    INNER JOIN `mm-commissions-reporting.B2B.gs_global_subcampana` GSC
      ON  GSC.CODIGO_XENA = UBA.cliente
      AND GSC.MARCA = UBA.comm_brand_ds
      AND GSC.INICIO_SUBCAMPANA <= inicio_mes_liquidacion
      AND PARSE_DATE('%m/%d/%Y', GSC.FIN_SUBCAMPANA) >= fin_mes_liquidacion
      AND GSC.TIPO_CAMPANA = 'VOLUMEN'
      AND GSC.OBJETIVO_KPI_UPFRONT = 'BRUTAS'
      AND GSC.TIPO_ALTA = 'PORTABILIDAD'
      AND GSC.OPERADOR_DONANTE = 'NOT (GRUPO MAS ORANGE)'

    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` DC
      ON  DC.id_comisionista = GSC.CODIGO_XENA

  WHERE 1=1

    AND UBA.activation_date >= GSC.INICIO_SUBCAMPANA
    AND UBA.activation_date <= CAST(REPLACE(FIN_SUBCAMPANA,'/','-') AS DATE FORMAT 'MM-DD-YYYY')
--    AND CASE WHEN SUBSTR(PROXIMO_CIERRE,1,3) = '202' THEN (SAFE_CAST(PROXIMO_CIERRE AS INT64)) ELSE CAST(NULL AS INT64) END = (id_mes_liquidacion+1) --Porque id_subcampañas indica el mes de ejecución y no el mes de liquidación
    AND CASE WHEN SUBSTR(CERRADA_HASTA,1,3) = '202' THEN (SAFE_CAST(CERRADA_HASTA AS INT64)) WHEN SUBSTR(CERRADA_HASTA,1,3) = '0' THEN 0 ELSE CAST(NULL AS INT64) END >= id_mes_liquidacion
    AND CASE WHEN GSC.OPERADOR_DONANTE = 'NOT (GRUPO MAS ORANGE)' THEN UBA.group_donor NOT IN ('GRUPO MASMOVIL','ORANGE')
             WHEN GSC.OPERADOR_DONANTE = 'GRUPO MAS ORANGE'       THEN UBA.group_donor IN ('GRUPO MASMOVIL','ORANGE')
             WHEN GSC.OPERADOR_DONANTE = 'TODOS'                  THEN UBA.group_donor IS NOT NULL
             WHEN GSC.OPERADOR_DONANTE = 'NO'                     THEN UBA.group_donor IS NULL
             ELSE 1=1 END

      UNION ALL

      --D - Camp. Cable ID: 2974 (CLAWBACK)
    SELECT 
        'calculado' AS estado
      , inicio_mes_liquidacion AS mes_liquidado
      , id_mes_liquidacion AS id_mes
      , CASE WHEN UBA.comm_brand_ds = 'CABLEMOVIL' THEN 'B2B - Cablemovil' ELSE CONCAT('B2B - ',UBA.comm_brand_ds) END AS agrupacion_canal
      , CASE WHEN UBA.comm_brand_ds = 'CABLEMOVIL' THEN 'CM' ELSE CONCAT('CANAL_TBD - ',UBA.comm_brand_ds) END AS canal
      , CONCAT('E - Camp. Cable ID: ',CAST(GSC.ID_SUBCAMPANA AS STRING)) AS concepto
      , 'UPFR' AS tipo_concepto
      , CAST(-1 AS INT64) AS unidades
      , (-1*GSC.PxQ_MAXIMO) AS comision
      , GSC.CODIGO_XENA AS id_comisionista
      , GSC.CODIGO_XENA AS distribuidor
      , GSC.CODIGO_XENA AS sfid_id
      , GSC.CODIGO_XENA AS seller
      , GSC.CLIENTE AS nombre_comercio
      , GSC.CLIENTE AS razon_social
      , DC.documento AS cif
      , CASE WHEN DC.zona_fiscal = '#N/A' THEN CAST(NULL AS STRING) ELSE DC.zona_fiscal END AS zona_fiscal
      , CAST(NULL AS STRING) AS cond_pago
      , UBA.comm_brand_ds AS marca
      , UBA.service_type AS service_type
      , UBA.phone_nm AS phone_nm
      , UBA.activation_tariff_id AS tariff_id
      , UBA.activation_tariff_ds AS tariff_ds
      , UBA.service_id AS service_id
      , UBA.account_id AS account_id
      , UBA.cliente AS customer_id
      , UBA.line_type_ds AS line_type_ds
      , UBA.bundle_type AS bundle_type
      , UBA.technology_ds AS technology_ds
      , UBA.billing_type_ds AS billing_type_ds
      , UBA.activation_date AS sale_date
      , UBA.activation_date AS activation_date
      , UBA.deactivation_date AS deactivation_date
      , UBA.account_id AS order_id
      , CAST(NULL AS STRING) AS order_type_agg
      , `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(UBA.segment_ds,UBA.comm_brand_ds) AS cod_segmento
      , `mm-commissions-reporting.COMISIONES.f_cod_marca`(UBA.brand_aggr,UBA.service_type) AS cod_marca
      , CASE WHEN UBA.billing_type_ds = 'PREPAID' THEN '10'
              WHEN UBA.bundle_type = 'FMC' AND UBA.line_type_ds = 'MAIN' THEN (CASE WHEN UBA.technology_ds = 'ADSL' THEN '60' ELSE '61' END)
              WHEN UBA.bundle_type = 'FMC' THEN (CASE WHEN UBA.technology_ds = 'ADSL' THEN '66' ELSE '67' END)
              WHEN UBA.bundle_type = 'MO' AND UBA.line_type_ds IN ('ADDITIONAL', 'EXTRA') AND UBA.comm_brand_ds IN ('YOIGO', 'PEPEPHONE') THEN '68'
              ELSE `mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_tipo_contrato`(UBA.billing_type_ds, UBA.service_type, UBA.bundle_type, UBA.technology_ds, UBA.comm_brand_ds, UBA.line_type_ds)
              END AS cod_tipo_contrato
      , CASE WHEN UBA.comm_brand_ds IN ('ADAMO','CABLEMOVIL') THEN '022'
              WHEN UBA.comm_brand_ds IN ('MARBLANCA') THEN '039'
              WHEN UBA.comm_brand_ds IN ('EUSKALTEL') THEN '040'
              WHEN UBA.comm_brand_ds IN ('NASH','NETLLAR','OCEAN') THEN '999'
              ELSE '999' END AS cod_producto
      , CASE WHEN UBA.comm_brand_ds IN ('ADAMO','ALTERNA','CABLEMOVIL','HITS','MARBLANCA','NASH','NETLLAR','OCEAN','PARLEM') THEN '30'
              ELSE '999' END AS cod_canal
      , GSC.campana AS campaign_code
      , CAST(NULL AS STRING) AS serial_number
      , CAST(NULL AS STRING) AS tax_base
      , CAST(NULL AS STRING) AS claim_code
      , 'CABCAMP2'||'_'||CAST(id_mes_liquidacion AS STRING)||'_'||'CM' AS process_code
      , 'Autofactura' AS comments
      , 'C_MANUAL' AS facturador
      , CAST(NULL AS STRING) AS proceso_sap
      , CAST(NULL AS STRING) AS id_registro
      , CAST(NULL AS STRING) AS invoice_id
      , 'X001' AS sociedad
      , CAST(NULL AS STRING) AS bp
      , CAST(NULL AS STRING) AS cuenta_contable
      , CAST(NULL AS STRING) AS centro_coste
      , CAST(NULL AS STRING) AS documento_sap
      , CAST(NULL AS STRING) AS documento_sap_posicion
      , CAST(NULL AS STRING) AS fecha_contabilizacion
      , CURRENT_TIMESTAMP () AS creado
      , CAST(NULL AS STRING) AS modificado
      , CAST(NULL AS STRING) AS id_factura_drive
      , CAST(NULL AS STRING) AS emails_acceso_trazabilidad
    FROM(
      --D - Camp. Cable ID: 2974 (CLAWBACK)
      SELECT *
      FROM `mm-commissions-reporting.TEMP.upfronts_base_arca` uba
      WHERE uba.cliente IN ('F00856')
        AND uba.group_donor NOT IN ('GRUPO MASMOVIL','ORANGE')
        --AND uba.deactivation_date_main_line BETWEEN inicio_mes_liquidacion AND fin_mes_liquidacion
        AND uba.deactivation_date BETWEEN inicio_mes_liquidacion AND fin_mes_liquidacion
        AND uba.bundle_type = 'MO'
        AND uba.PVP_ARPU >= 1
          --Ya hemos abonado el service_id
        AND uba.service_id IN (
          SELECT distinct(tra.service_id)
          FROM `mm-commissions-reporting.COMISIONES.transacciones` tra
          WHERE tra.mes_liquidado BETWEEN inicio_mes_clawback AND fin_mes_clawback
            AND tra.concepto LIKE '%2974%'
            AND tra.unidades = 1
        )
          --Ya hemos abonado el nº de teléfono
        AND CAST(uba.phone_nm AS STRING) IN (
          SELECT distinct(tra.phone_nm)
          FROM `mm-commissions-reporting.COMISIONES.transacciones` tra
          WHERE tra.mes_liquidado BETWEEN inicio_mes_clawback AND fin_mes_clawback
            AND tra.concepto LIKE '%2974%'
            AND tra.unidades = 1
        )
          --Quitamos si ya está a 0€ o no está abonado previamente, proque ya habremos aplicado el clawback antes o no se habrá pagado
        AND uba.service_id IN (
          SELECT service_id
          FROM(
            SELECT tra.service_id, phone_nm, SUM(tra.comision) AS IMPORTE
            FROM `mm-commissions-reporting.COMISIONES.transacciones` tra
            WHERE tra.mes_liquidado BETWEEN inicio_mes_clawback AND fin_mes_clawback
              AND tra.concepto LIKE '%2974%'
              AND tra.unidades = 1
            GROUP BY ALL
            HAVING IMPORTE > 0
          )
        )
      )UBA
      INNER JOIN `mm-commissions-reporting.B2B.gs_global_subcampana` GSC
        ON  GSC.CODIGO_XENA = UBA.cliente
        AND GSC.MARCA = UBA.comm_brand_ds
        AND GSC.INICIO_SUBCAMPANA <= inicio_mes_liquidacion
        AND PARSE_DATE('%m/%d/%Y', GSC.FIN_SUBCAMPANA) >= fin_mes_liquidacion
        AND GSC.TIPO_CAMPANA = 'VOLUMEN'
        AND GSC.OBJETIVO_KPI_UPFRONT = 'BRUTAS'
        AND GSC.TIPO_ALTA = 'PORTABILIDAD'
        AND GSC.OPERADOR_DONANTE = 'NOT (GRUPO MAS ORANGE)'
      LEFT JOIN `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` DC
        ON  DC.id_comisionista = GSC.CODIGO_XENA
    WHERE 1=1
      AND UBA.activation_date >= GSC.INICIO_SUBCAMPANA
      AND UBA.activation_date <= CAST(REPLACE(FIN_SUBCAMPANA,'/','-') AS DATE FORMAT 'MM-DD-YYYY')
--      AND CASE WHEN SUBSTR(PROXIMO_CIERRE,1,3) = '202' THEN (SAFE_CAST(PROXIMO_CIERRE AS INT64)) ELSE CAST(NULL AS INT64) END = (id_mes_liquidacion+1) --Porque id_subcampañas indica el mes de ejecución y no el mes de liquidación
      AND CASE WHEN SUBSTR(CERRADA_HASTA,1,3) = '202' THEN (SAFE_CAST(CERRADA_HASTA AS INT64)) WHEN SUBSTR(CERRADA_HASTA,1,3) = '0' THEN 0 ELSE CAST(NULL AS INT64) END >= id_mes_liquidacion
      AND CASE WHEN GSC.OPERADOR_DONANTE = 'NOT (GRUPO MAS ORANGE)' THEN UBA.group_donor NOT IN ('GRUPO MASMOVIL','ORANGE')
               WHEN GSC.OPERADOR_DONANTE = 'GRUPO MAS ORANGE'       THEN UBA.group_donor IN ('GRUPO MASMOVIL','ORANGE')
               WHEN GSC.OPERADOR_DONANTE = 'TODOS'                  THEN UBA.group_donor IS NOT NULL
               WHEN GSC.OPERADOR_DONANTE = 'NO'                     THEN UBA.group_donor IS NULL
               ELSE 1=1 END

  )
;

END