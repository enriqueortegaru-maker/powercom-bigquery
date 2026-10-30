BEGIN

-------------------------------------------------------------
-- Procedimiento que calcula el terminal PDV de MULTIBRAND
-------------------------------------------------------------

-- CALL `mm-commissions-reporting.COMISIONES.pr_terminal_pdv_multibrand`();

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.terminal_pdv_multibrand`  AS


    SELECT
      sfid_entrega_pdv AS sfid,
      'C_ENTREGA_TERMINAL_PDV_RENOVE' AS iDConcepto,
      DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
        AS FechaCompensacion,
      '6,00' AS VALUE,
      'LGARCIAZ' AS UsuarioCarga,
      'LGARCIAZ' AS UsuarioAjuste,
      brand_ds AS Marca,
      channel_segment_ds AS Mercado,
      'POSPAGO' AS Contrato,
      'MOVIL' AS Tecnologia,
      phone_nm AS MSISDN,
      SERIAL AS IMEI,
      order_id AS NumPedido,
      service_id AS CodContrato,
      'Entrega en tienda Multicanal'
        || FORMAT_DATE(
          '%m/%y',
          DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH))
        || ROW_NUMBER() OVER () AS COMENTARIO,
      'EXCLUSIVO' AS PEP,
      'ALL' AS Canal,
      'COM_EXT' AS IDEventoContexto,
      '' AS NumeroReclamacion,
      '' AS ReclamacionCasoID,
      'CALCULO' ASNOTASADV,
      'M' AS TIPO,
      '' AS IDFiscal,
      customer_id AS codigo_cliente,
    FROM
      (
        SELECT
          *,
          CAST(cancellationDatetime AS DATE) AS FECHA_CANCELACION_DEF,
          ROW_NUMBER()
            OVER (
              PARTITION BY customer_id
              ORDER BY
                -- prioridad: BAJA sobre EQENT (ajustable)
                CASE
                  WHEN TRIM(codigo_estado_logistica_jazztel) = 'BAJA_CRM4T' THEN 1
                  WHEN codigo_estado_logistica_jazztel = 'EQENT' THEN 2
                  ELSE 3
                  END,
                fecha_entrega DESC
            ) AS rn
        FROM
          (
            SELECT *
            FROM `mm-sales-reporting.PRESENCIAL_PDV.EX_Entrega_Tienda`
            WHERE
              codigo_estado_logistica_jazztel = 'EQENT'
              AND fecha_entrega >= DATE_TRUNC(
                DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
              AND fecha_entrega < DATE_TRUNC(CURRENT_DATE(), MONTH)
              AND billing_type_ds = 'POSTPAID'
            UNION ALL
            SELECT *
            FROM `mm-sales-reporting.PRESENCIAL_PDV.EX_Entrega_Tienda`
            WHERE
              TRIM(codigo_estado_logistica_jazztel) = 'BAJA_CRM4T'
              AND fecha_entrega >= DATE_TRUNC(
                DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
              AND fecha_entrega < DATE_TRUNC(CURRENT_DATE(), MONTH)
              AND billing_type_ds = 'POSTPAID'
          )
      )
    WHERE rn = 1
  ;
END