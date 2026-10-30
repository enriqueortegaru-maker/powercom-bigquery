BEGIN
    DELETE
    FROM
      `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES_HISTORICO`
    WHERE
      fecha_RFB_id BETWEEN DESDE  AND HASTA; 

    INSERT INTO
      `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES_HISTORICO`
    SELECT
    *
    FROM
      `mm-commissions-reporting.KRT_CAPTACION_MM.COMISIONES`;
END