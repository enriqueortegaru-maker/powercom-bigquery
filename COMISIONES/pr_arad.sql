BEGIN


DECLARE sql, prefijo, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);

SET prefijo = '3ARAD';

SET canales_pr = ['ADA'];

-- call `mm-commissions-reporting.COMISIONES.pr_arad`(202609,['ADA']);

-------------------------------------------------------------------------------VALIDACIONES----------------------------------------------------------------------------------------


-- ASSERT EXISTS(--No está en App Script

--     SELECT DISTINCT  data_month_id
--     FROM  `mm-datamart-kd.BILLING.billing_report_xena_cableoperadores_*`
--     WHERE cliente = '216517'
--       AND data_month_id = CAST(mes_string AS INT64)

--   ) AS 'Todavía no está creada la tabla origen del mes correspondiente'
--   ;

-- ASSERT NOT EXISTS (--No está en App Script

--   WITH 
--     dato AS (
--       SELECT CONCAT(year, 'T', trimestre) AS trimestre
--       FROM (
--         SELECT *
--         FROM `mm-commissions-reporting.GS.INDICE_ADAMO_TRIMESTRAL`
--         WHERE indice IS NOT NULL
--         QUALIFY ROW_NUMBER() OVER (ORDER BY year DESC, trimestre DESC) = 1
--       )
--     )
--     SELECT 1
--     FROM dato
--     WHERE trimestre != FORMAT(
--     "%dT%d",
--     IF(EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', mes_string)) = 1 , EXTRACT(YEAR FROM PARSE_DATE('%Y%m', mes_string))-1, EXTRACT(YEAR FROM PARSE_DATE('%Y%m', mes_string))),
--     CASE 
--       WHEN EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', mes_string)) - 1 = 0 THEN 4
--       ELSE EXTRACT(QUARTER FROM PARSE_DATE('%Y%m', mes_string)) - 1
--     END
--     )
-- ) AS 'Falta por agregar el índice ARPU/DOU del trimestre anterior'

-- ;


-----------------------------------------------------------------------------FIN VALIDACIONES--------------------------------------------------------------------------------------

call `mm-commissions-reporting.B2B.pr_TRAFICO_CDR_ADAMO`();


 CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.comisiones_arad` AS 

-- DELETE FROM `mm-commissions-reporting.TEMP.comisiones_arad`
-- WHERE id_mes = mes_int;

-- INSERT INTO `mm-commissions-reporting.TEMP.comisiones_arad`



WITH 

    C_TRAFICO AS(
      
      SELECT COD_OP AS codigo_cableoperador, PORCENTAJE_COMISION AS porcentaje
      FROM `mm-commissions-reporting.B2B.TRAFICO_COMISIONES_DS`  
      WHERE id_mes = CAST(mes_string AS INT64) and agrupacion_canal = 'B2B - Adamo'
    ),


  base AS (
    SELECT *
    FROM `mm-commissions-reporting.B2B.comisiones_base_arad_*`
    WHERE 1=1
      AND _TABLE_SUFFIX = CONCAT(mes_string,'01')
  ), 

  max_precio_base AS (
    SELECT 
      a.* EXCEPT(imp_without_tax),
      b.max_precio AS pvp_sin_iva
    FROM base a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        MAX(imp_without_tax) AS max_precio
      FROM base
      WHERE phone_nm IS NOT NULL
      GROUP BY 1
    ) b ON a.account_id = b.account_id AND a.imp_without_tax = b.max_precio
    WHERE b.account_id IS NOT NULL 
  ), --SELECT * FROM max_precio_base 

  min_base AS (
    SELECT 
      a.* EXCEPT(activation_date),
      b.min_act_date AS activation_date
    FROM max_precio_base a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        MIN(activation_date) AS min_act_date
      FROM max_precio_base
      GROUP BY 1
    ) b ON a.account_id = b.account_id AND a.activation_date = b.min_act_date
    WHERE b.account_id IS NOT NULL 
  ),--SELECT * FROM min_base 

  bono_base AS (
    SELECT 
      a.* EXCEPT(phone_nm),
      'SI' AS linea_principal,
      b.min_phone_nm AS phone_nm
    FROM min_base a
    LEFT JOIN (
      SELECT DISTINCT
        account_id,
        bono_id,
        MIN(phone_nm) AS min_phone_nm
      FROM min_base
      GROUP BY 1,2
    ) b ON a.account_id = b.account_id AND a.phone_nm = b.min_phone_nm AND a.bono_id = b.bono_id
    WHERE b.account_id IS NOT NULL 
  ) --SELECT * FROM bono_base WHERE account_id ='216517720779'
  ,

  def_base AS(
    SELECT a.*,
        IF(b.linea_principal IS NULL,'NO','SI') AS linea_principal,
        CASE
          WHEN b.phone_nm IS NOT NULL THEN 'MAIN'
          ELSE 'ADDITIONAL'
        END AS line_type_ds,
        c.service_type,
        c.service_id,
        c.technology_ds,
        c.billing_type_ds,
        c.deactivation_date
    FROM base a
    LEFT JOIN bono_base b ON a.account_id = b.account_id AND a.phone_nm = b.phone_nm
    LEFT JOIN (
      SELECT a.* EXCEPT(activation_date),
        b.max_activation_date
      FROM `mm-datamart-kd.SERVICES.service_base_net` a
      JOIN (
        SELECT DISTINCT phone_nm, account_id, MAX(activation_date) AS max_activation_date
        FROM `mm-datamart-kd.SERVICES.service_base_net`
        WHERE comm_brand_ds = 'CABLEMOVIL'
        GROUP BY 1,2
      ) b ON a.phone_nm = b.phone_nm AND a.account_id = b.account_id AND a.activation_date = b.max_activation_date
    ) c ON a.phone_nm = CAST(c.phone_nm AS STRING) AND a.account_id = c.account_id
  ),

    indice_trimestral AS (
      SELECT CONCAT(year,'T',trimestre) AS trimestre, indice
      FROM (
        SELECT *
        FROM `mm-commissions-reporting.GS.INDICE_ADAMO_TRIMESTRAL`
        WHERE indice IS NOT NULL
        GROUP BY ALL
        QUALIFY ROW_NUMBER() OVER(ORDER  BY year DESC,trimestre DESC) = 1
      )
    ),

-- CALCULO

  b AS (
    SELECT DISTINCT
      'calculado' as estado,
      DATE_TRUNC(PARSE_DATE('%Y%m',mes_string), MONTH) AS mes_liquidado, --DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)  
      CAST(mes_string AS INT64) as id_mes, 
      'Adamo' AS agrupacion_canal,
      'ADA' AS canal,
     -- CONCEPTO
    CONCAT(
      'C - Gestión Cartera Móvil (',
      CAST(ROUND(ct.porcentaje * 100,2) AS STRING),
      '%)'
    ) AS concepto,

  'AIRT' AS tipo_concepto,
      CAST(NULL AS INT64) AS unidades, 
      -- COMISIÓN
    def_base.imp_without_tax * ct.porcentaje AS comision,
      imp_without_tax,
      def_base.CLIENTE             AS id_comisionista,
      def_base.CLIENTE             AS distribuidor,
      def_base.CLIENTE             AS sfid_id,
      def_base.CLIENTE             AS seller, --es null def_base.sfid_id
      gs.nombre_comercio  AS nombre_comercio,
      gs.razon_social  AS razon_social, 
      gs.cond_pago         AS cond_pago,
      gs.documento                  AS cif,
      gs.zona_fiscal                        AS zona_fiscal,
      'ADAMO'                      AS marca,
      CASE
        WHEN service_type IS NULL THEN 'MOBILE'
        ELSE def_base.service_type
      END                          AS service_type,
      CAST(def_base.phone_nm       AS STRING)           AS phone_nm,
      def_base.bono_id             AS tariff_id,
      def_base.bono_name           AS tariff_ds,
      def_base.service_id          AS service_id,
      def_base.account_id          AS account_id,
      def_base.cliente             AS customer_id,
      def_base.line_type_ds        AS line_type_ds,
      CAST(NULL AS STRING)         AS bundle_type,
      def_base.technology_ds       AS technology_ds,
      def_base.billing_type_ds     AS billing_type_ds,
      CAST(NULL AS DATE)           AS sale_date,
      def_base.activation_date     AS activation_date,
      IF(def_base.deactivation_date > LAST_DAY((PARSE_DATE('%Y%m',mes_string))),'9999-12-31', def_base.deactivation_date)   AS deactivation_date, --LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
      CAST(NULL AS STRING)         AS order_id,
      --CAST(def_base.order_id AS STRING)           AS order_id,
      CAST(NULL AS STRING)         AS order_type_agg,
      --def_base.order_type_agg     AS order_type_agg,
      '42'                         AS cod_segmento,
      '05'                         AS cod_marca,
      '20'                     AS cod_tipo_contrato,
      '30'                     AS cod_canal,
      '022'                     AS cod_producto,
      CAST(NULL AS STRING)     AS campaign_code,
      CAST(NULL AS STRING)     AS serial_number,
      def_base.imp_without_tax AS tax_base,
      CAST(NULL AS STRING)     AS claim_code,
      CAST(NULL AS STRING)     AS process_code,
      CAST(NULL AS STRING)     AS comments,
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
      CAST(NULL AS STRING)     AS emails_acceso_trazabilidad
    FROM def_base
    LEFT JOIN indice_trimestral a ON def_base.trimestre_indice = a.trimestre
    LEFT JOIN C_TRAFICO ct
    ON ct.codigo_cableoperador = def_base.CLIENTE
    LEFT JOIN `mm-commissions-reporting.GS.DEALERS_ADAMO` gs
    ON def_base.CLIENTE = gs.id_comisionista

  ),



  final AS (
    SELECT DISTINCT
      estado,
      b.mes_liquidado,
      id_mes,
      agrupacion_canal,
      canal,
      -- CASE
      --   WHEN acum_final.tipo_fact = 0 THEN 'C - Gestion Cartera Movil (45%)'
      --   ELSE concepto
      -- END AS concepto,
      concepto,
      tipo_concepto,
      1 AS unidades,
      -- CASE
      --   WHEN acum_final.tipo_fact = 0 THEN SUM(imp_without_tax*0.45)
      --   ELSE SUM(comision)
      -- END AS comision,
      comision,
      id_comisionista,
      distribuidor,
      sfid_id,
      seller,
      nombre_comercio,
      razon_social,
      cond_pago,
      cif,
      zona_fiscal,
      marca,
      service_type,
      phone_nm,
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
      claim_code,
      campaign_code,
      serial_number,
      tax_base,
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
      emails_acceso_trazabilidad
    FROM b
    --LEFT JOIN acum_final ON b.mes_liquidado = acum_final.mes_liquidado
    GROUP BY ALL
    -- 1,2,3,4,5,6,7,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,acum_final.tipo_fact

   )

  SELECT 
  prefijo||'_'||mes_string||'_'||canal||'_'||row_number () over() AS commission_id,
  *
  FROM final
  WHERE comision != 0;

-- Actualización tabla final --



call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`
(
  prefijo,
  mes_int,
  canales_pr,
  'TEMP.comisiones_arad',
  'ACTUALIZAR'
);

-- Procedimiento de Validaciones

call `mm-commissions-reporting.COMISIONES.pr_validaciones_B2BC`(mes_int, canales_pr)
;

END