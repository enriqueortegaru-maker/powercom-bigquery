BEGIN

  CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` AS

  SELECT
      *,
      '' VALOR,
      '' PACK,
      NULL PLAYS_RFB,
      NULL PLAYS      
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` ;


--- Informo nplays a partir de activaciones
  UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
    SET
      a.valor = c.valor,
      a.pack = c.pack,
      a.plays_rfb = c.plays
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


  --- Informo nplays a partir de ventas en campo plays
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays=b.nplays
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.cliente_id=b.cliente_id;


  --- Vuelco registros en los que el play de ventas es nulo

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0703_VENTASxCLIENTExTIPIFICACION_NULOS` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` where plays is null;


  --- Actualizo nplays a partir de ventas con datos de nplays_rfb
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` 
  SET plays=plays_rfb
  where plays is null;


END