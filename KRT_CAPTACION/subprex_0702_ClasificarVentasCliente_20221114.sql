BEGIN

    UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` c
    SET
      c.valor = b.valor,
      c.pack = b.pack,
      c.plays = b.plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.PARAM_VALOR` b
    WHERE
      -- a.marca_ds = b.marca_ds
      --AND 
      b.marca_ds = c.marca_ds
      AND ifnull(b.ba,
        'NA') = ifnull(c.ba,
        'NA')
      AND ifnull(b.post,
        'NA') = ifnull(c.post,
        'NA')
      AND ifnull(b.tv,
        'NA') = ifnull(c.tv,
        'NA')
      AND ifnull(b.fija,
        'NA') = ifnull(c.fija,
        'NA')
      AND b.valor = 'LOW'
      AND c.valor = '';
    UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` c
    SET
      c.valor = b.valor,
      c.pack = b.pack,
      c.plays = b.plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.PARAM_VALOR` b
    WHERE
      -- a.marca_ds = b.marca_ds
      --AND 
      b.marca_ds = c.marca_ds
      AND ifnull(b.ba,
        'NA') = ifnull(c.ba,
        'NA')
      AND ifnull(b.post,
        'NA') = ifnull(c.post,
        'NA')
      AND ifnull(b.tv,
        'NA') = ifnull(c.tv,
        'NA')
      AND ifnull(b.fija,
        'NA') = ifnull(c.fija,
        'NA')
      AND b.valor = 'MID'
      AND c.valor = '';
    UPDATE
      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE` c
    SET
      c.valor = b.valor,
      c.pack = b.pack,
      c.plays = b.plays
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.PARAM_VALOR` b
    WHERE
      -- a.marca_ds = b.marca_ds
      --AND 
      b.marca_ds = c.marca_ds
      AND ifnull(b.ba,
        'NA') = ifnull(c.ba,
        'NA')
      AND ifnull(b.post,
        'NA') = ifnull(c.post,
        'NA')
      AND ifnull(b.tv,
        'NA') = ifnull(c.tv,
        'NA')
      AND ifnull(b.fija,
        'NA') = ifnull(c.fija,
        'NA')
      AND b.valor = 'HIGH'
      AND c.valor = '';

end