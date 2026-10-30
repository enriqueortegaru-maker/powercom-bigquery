BEGIN

--- PASO 1: Calculo ventas por cliente y registro en tabla de log

  CREATE OR REPLACE TABLE 
    `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` AS
  WITH
    A AS (
    SELECT
      DISTINCT marca_ds,
      cliente_id,
      CAST(ROUND(fecha_rfb_id/100,0) AS int64) mes_rfb,
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS`)
  SELECT
    DISTINCT a.marca_ds,
    a.cliente_id,
    a.mes_rfb,
    b.concepto_ds BA,
    c.Concepto_ds POST,
    d.concepto_ds tv,
    e.concepto_ds fija,
    '' PACK,
    '' VALOR,
    NULL PLAYS
  FROM
    A
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` B
  ON
    a.marca_ds = b.marca_ds
    AND a.cliente_id = b.cliente_id
    AND a.mes_rfb = CAST(ROUND(b.fecha_rfb_id/100,0) AS int64)
    AND b.categoria_servicio_ds = 'BANDA ANCHA'
    AND UPPER(b.concepto_ds) NOT LIKE '%DESCUENTO%'
    AND UPPER(b.concepto_ds) NOT LIKE '%RAPPEL%'
    AND UPPER(b.concepto_ds) NOT LIKE '%POSTVENTA%'
    AND UPPER(b.concepto_ds) NOT LIKE '%EXTRA%'
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` C
  ON
    a.marca_ds = C.marca_ds
    AND a.cliente_id = C.cliente_id
    AND a.mes_rfb = CAST(ROUND(c.fecha_rfb_id/100,0) AS int64)
    AND c.categoria_servicio_ds = 'MOVILES POSTPAGO'
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` D
  ON
    a.marca_ds = D.marca_ds
    AND a.cliente_id = D.cliente_id
    AND a.mes_rfb = CAST(ROUND(D.fecha_rfb_id/100,0) AS int64)
    AND d.categoria_servicio_ds = 'TELEVISION'
    and not CONTAINS_SUBSTR(d.detalle_servicio_ds,'etflix')    
    and not CONTAINS_SUBSTR(d.detalle_servicio_ds,'canal') 
    and not CONTAINS_SUBSTR(d.detalle_servicio_ds,'estrenos')     
    and not CONTAINS_SUBSTR(d.detalle_servicio_ds,'liga')    
    --AND UPPER(d.concepto_ds) NOT LIKE '%NETFLIX%'
    --AND UPPER(d.concepto_ds) NOT LIKE '%BAR%'
    --AND UPPER(d.concepto_ds) NOT LIKE '%MOVIS%'
  LEFT JOIN
    `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` e
  ON
    a.marca_ds = E.marca_ds
    AND a.cliente_id = e.cliente_id
    AND a.mes_rfb = CAST(ROUND(e.fecha_rfb_id/100,0) AS int64)
    AND e.categoria_servicio_ds = 'FIJA';


--- PASO 2: Creo tabla LOG_0701_VENTASxCLIENTE

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0701_VENTASxCLIENTExRFB` as 
  Select 
    * 
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`;



--- PASO 3: Actualizo campo PLAYS en tabla VENTAS_INTxCLIENTE

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
    SET PLAYS=CASE WHEN LENGTH(BA) >0 THEN 1 ELSE 0 END 
    + CASE WHEN LENGTH(FIJA) >0 THEN 1 ELSE 0 END 
    + CASE WHEN LENGTH(TV) >0 THEN 1 ELSE 0 END  
    + CASE WHEN LENGTH(POST) >0 THEN 1 ELSE 0 END
    WHERE 1=1;



--- PASO 4: Recreo tabla VENTAS_INTxCLIENTE pero con contabilidad en base a fecha comisionado

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` as 
  select marca_ds, cliente_id, max(mes_rfb) as mes_rfb, BA, POST,tv, fija, PACK, VALOR, PLAYS
  from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0701_VENTASxCLIENTExRFB`
  group by 1,2 ,4,5,6,7,8,9,10;


--- PASO 5: Actualizo campo PLAYS en tabla VENTAS_INTxCLIENTE

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
    SET PLAYS=CASE WHEN LENGTH(BA) >0 THEN 1 ELSE 0 END 
    + CASE WHEN LENGTH(FIJA) >0 THEN 1 ELSE 0 END 
    + CASE WHEN LENGTH(TV) >0 THEN 1 ELSE 0 END  
    + CASE WHEN LENGTH(POST) >0 THEN 1 ELSE 0 END
    WHERE 1=1;


--- PASO 4: Creo tabla LOG_0701_VENTAS_INTxCLIENTE

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.LOG_0701_VENTASxCLIENTExFC` as 
  Select 
    * 
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`;



END