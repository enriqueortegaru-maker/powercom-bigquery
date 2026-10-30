BEGIN

    UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` c
    SET
      c.valor = b.valor,
      c.pack = b.pack,
      c.plays = b.plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.VALOR` b
    WHERE
      -- a.marca_ds = b.marca_ds
      --AND 
      trim(b.marca_ds) = trim(c.marca_ds)
      AND trim(coalesce(b.ba,
        'NA')) = trim(coalesce(c.ba,
        'NA'))
      AND trim(coalesce(b.post,
        'NA')) = trim(coalesce(c.post,
        'NA'))
      AND Trim(coalesce(b.tv,
        'NA')) = trim(coalesce(c.tv,
        'NA'))
      AND trim(coalesce(b.fija,
        'NA')) = trim(coalesce(c.fija,
        'NA'))
      AND trim(b.valor) = 'LOW'
      AND trim(c.valor) = '';


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0702_VENTASxCLIENTE_LOW` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`;

    UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` c
    SET
      c.valor = b.valor,
      c.pack = b.pack,
      c.plays = b.plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.VALOR` b
    WHERE
      -- a.marca_ds = b.marca_ds
      --AND 
      trim(b.marca_ds) = trim(c.marca_ds)
      AND trim(coalesce(b.ba,
        'NA')) = trim(coalesce(c.ba,
        'NA'))
      AND trim(coalesce(b.post,
        'NA')) = trim(coalesce(c.post,
        'NA'))
      AND trim(coalesce(b.tv,
        'NA')) = trim(coalesce(c.tv,
        'NA'))
      AND trim(coalesce(b.fija,
        'NA')) = trim(coalesce(c.fija,
        'NA'))
      AND trim(b.valor) = 'MID'
      AND trim(c.valor) = '';

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0702_VENTASxCLIENTE_LOW_MID` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`;


    UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` c
    SET
      c.valor = b.valor,
      c.pack = b.pack,
      c.plays = b.plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.VALOR` b
    WHERE
      -- a.marca_ds = b.marca_ds
      --AND 
      trim(b.marca_ds) = trim(c.marca_ds)
      AND trim(coalesce(b.ba,
        'NA')) = trim(coalesce(c.ba,
        'NA'))
      AND trim(coalesce(b.post,
        'NA')) = trim(coalesce(c.post,
        'NA'))
      AND trim(coalesce(b.tv,
        'NA')) = trim(coalesce(c.tv,
        'NA'))
      AND trim(coalesce(b.fija,
        'NA')) = trim(coalesce(c.fija,
        'NA'))
      AND trim(b.valor) = 'HIGH'
      AND trim(c.valor) = '';

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0702_VENTASxCLIENTE_LOW_MID_HIGH` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`;

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
    SET PLAYS=CASE WHEN LENGTH(BA) >0 THEN 1 ELSE 0 END 
    + CASE WHEN LENGTH(FIJA) >0 THEN 1 ELSE 0 END 
    + CASE WHEN LENGTH(TV) >0 THEN 1 ELSE 0 END  
    + CASE WHEN LENGTH(POST) >0 THEN 1 ELSE 0 END
    WHERE 1=1;

end