BEGIN


  CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` AS

  SELECT s.*,v.pedido_id, v.expediente_padre_id, '' VALOR,'' PACK, NULL PLAYS_RFB, NULL PLAYS_V, NULL PLAYS_VBA, NULL PLAYS_P, NULL PLAYS_PBA, NULL PLAYS      
  FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` s
  LEFT JOIN `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  ON v.marca_ds=s.marca_ds and v.cliente_id=s.cliente_id and v.servicio_id=s.servicio_id and v.canal_alta_ds=s.canal_alta_ds and v.agente_creador_id=s.agente_creador_id and v.fecha_venta_neta_dt=s.fecha_venta_neta_dt;





--- Informo nplays_rfb
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


  --- Informo nplays_v
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays_v=b.nplays
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.cliente_id=b.cliente_id;



  --- Informo nplays_vba
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays_vba=b.NPLAYS_PBA
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.cliente_id=b.cliente_id;



  --- Vuelco registros en los que el play de ventas es nulo

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0703_VENTASxCLIENTExTIPIFICACION_NULOS` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` where plays_v is null;


--- Informo nplays_p

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays_p=b.nplays
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.marca_ds!="R"
  and NOT CONTAINS_SUBSTR(a.marca_ds,'TELECABLE')  -- PARCHE PROVISIONAL PARA TELECABLE
  and a.cliente_id=b.cliente_id
  and CAST(a.pedido_id AS STRING)=b.pedido_id;

    -- PARCHE PROVISIONAL PARA TELECABLE
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
    SET a.plays_p=b.nplays
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` b
    where a.marca_ds=b.marca_ds
    and CONTAINS_SUBSTR(a.marca_ds,'TELECABLE')
    and a.cliente_id=b.cliente_id
    and CAST(a.pedido_id AS STRING)=b.pedido_id;

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays_pba=b.nplays
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.marca_ds="R"
  and a.cliente_id=b.cliente_id
  and a.expediente_padre_id=b.pedido_id;


  --- Informo nplays_pba

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays_pba=b.nplays_pba
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.marca_ds!="R"
  and NOT CONTAINS_SUBSTR(a.marca_ds,'TELECABLE')  -- PARCHE PROVISIONAL PARA TELECABLE
  and a.cliente_id=b.cliente_id
  and CAST(a.pedido_id AS STRING) =b.pedido_id;


    -- PARCHE PROVISIONAL PARA TELECABLE
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
    SET a.plays_pba=b.NPLAYS_PBA
    FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` b
    where a.marca_ds=b.marca_ds
    and CONTAINS_SUBSTR(a.marca_ds,'TELECABLE')
    and a.cliente_id=b.cliente_id
    and CAST(a.pedido_id AS STRING) =b.pedido_id;

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays_pba=b.NPLAYS_PBA
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExPEDIDOxNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.marca_ds="R"
  and a.cliente_id=b.cliente_id
  and a.expediente_padre_id=b.pedido_id;



  --- Informo nplays con dato de nplays de ventas
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` a
  SET a.plays=b.nplays
  FROM `mm-commissions-reporting.KRT_CAPTACION.CLIENTExNPLAYS_V` b
  where a.marca_ds=b.marca_ds
  and a.cliente_id=b.cliente_id;


  --- Actualizo nplays no informado con plays ventas con nplays_rfb
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION` 
  SET plays=plays_rfb
  where plays is null;


END