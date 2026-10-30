BEGIN

  DECLARE
    PARAM_DESDE_DT,
    PARAM_HASTA_DT date;
  SET
    PARAM_DESDE_DT = parse_date ('%Y%m%d',
      CAST ( DESDE AS string) );
  SET
    PARAM_HASTA_DT = parse_date ('%Y%m%d',
      CAST ( HASTA AS string) );

  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION_MM.EVENTOS_CAPTACION` a
  SET
    a.concepto_ds = CONCAT(CASE
        WHEN a.categoria_servicio_ds = 'MOVILES POSTPAGO' THEN CASE
        WHEN orden = 1 THEN 'Primera linea '
      ELSE
      'Linea adicional '
    END
      ELSE
      ''
    END
      , a.concepto_ds,CASE
        WHEN c.clasificacion_ds = 'SF' THEN ' FMC'
      ELSE
      ' SOMO'
    END
      )
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY cliente_id, marca_ds ORDER BY gb DESC, servicio_id) orden
    FROM
      `mm-commissions-reporting.KRT_CAPTACION_MM.EVENTOS_CAPTACION`
    WHERE
      categoria_servicio_ds IN ('FIJA',
        'MOVILES POSTPAGO')) b,
    `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` c
  WHERE
    a.categoria_servicio_ds IN ('FIJA',
      'MOVILES POSTPAGO')
    AND a.servicio_id = b.servicio_id
    AND a.marca_ds = b.marca_ds
    AND a.cliente_id = c.cliente_id
    AND a.marca_ds = c.marca_ds
    AND CAST(c.desde_dt AS date) <= PARAM_HASTA_DT
    AND CAST(c.hasta_dt AS date) > PARAM_HASTA_DT;

END