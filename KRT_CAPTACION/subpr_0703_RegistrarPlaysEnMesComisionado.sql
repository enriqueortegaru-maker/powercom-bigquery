BEGIN

  CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` AS

  SELECT
      *,
      '' VALOR,
      '' PACK,
      NULL PLAYS
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` ;

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
        MAX(plays)  OVER (PARTITION BY cliente_id) plays 
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
    ) C
    WHERE
      a.marca_ds = c.marca_ds
      AND a.cliente_id = c.cliente_id
      AND CAST(ROUND(a.fecha_rfb_id/100,0) AS int64) = c.mes_rfb;                                                                              

END