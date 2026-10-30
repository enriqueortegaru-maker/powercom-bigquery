BEGIN

  --- Tablas Salida
  --		`mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION`	

--- PASO 1: CREO TABLA VENTASxCLIENTExTIPIFICACION

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` AS

  --- Tablas Entrada
  --  `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` 
  --  `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION`
  --  `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`

  SELECT
    *,
    '' VALOR,
    '' PACK,
    NULL PLAYS
  FROM
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` ;

--- PASO 2: ACTUALIZO TABLA VENTASxCLIENTExTIPIFICACION    
  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET
    a.VALOR = c.VALOR,
    a.pack = c.pack,
    a.plays = c.plays
  FROM (
    SELECT
      DISTINCT cliente_id,
      marca_ds,
      mes_rfb,
      VALOR,
      MIN(pack) OVER (PARTITION BY cliente_id) pack,
      plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
    WHERE
      VALOR = 'HIGH') C
  WHERE
    a.marca_ds = c.marca_ds
    AND a.cliente_id = c.cliente_id
    AND CAST(ROUND(a.fecha_rfb_id/100,0) AS int64) = c.mes_rfb
    AND a.VALOR = '';


--- PASO 3: ACTUALIZO TABLA VENTASxCLIENTExTIPIFICACION
  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET
    a.VALOR = c.VALOR,
    a.pack = c.pack,
    a.plays = c.plays
  FROM (
    SELECT
      DISTINCT cliente_id,
      marca_ds,
      mes_rfb,
      VALOR,
      MIN(pack) OVER (PARTITION BY cliente_id) pack,
      plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
    WHERE
      valor = 'MID') C
  WHERE
    a.marca_ds = c.marca_ds
    AND a.cliente_id = c.cliente_id
    AND CAST(ROUND(a.fecha_rfb_id/100,0) AS int64) = c.mes_rfb
    AND a.valor = '';


--- PASO 4: ACTUALIZO TABLA VENTASxCLIENTExTIPIFICACION
  UPDATE
    `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET
    a.valor = c.valor,
    a.pack = c.pack,
    a.plays = c.plays
  FROM (
    SELECT
      DISTINCT cliente_id,
      marca_ds,
      mes_rfb,
      valor,
      MIN(pack) OVER (PARTITION BY cliente_id) pack,
      plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
    WHERE
      valor = 'LOW') C
  WHERE
    a.marca_ds = c.marca_ds
    AND a.cliente_id = c.cliente_id
    AND CAST(ROUND(a.fecha_rfb_id/100,0) AS int64) = c.mes_rfb
    AND a.valor = '';                                                                              


--- PASO 5: CREO TABLA 
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS_MAS_RAPPEL_MAS_AJUSTES_MAS_TIPIFICACION` AS
    SELECT * FROM 
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION`; 


end