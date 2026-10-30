BEGIN


    --UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`  UPDATE SET VALOR=NULL WHERE VALOR='';
    --UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`  UPDATE SET PACK=NULL WHERE PACK='';

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
      trim(c.marca_ds) = trim(coalesce(b.marca_ds,''))
      AND coalesce(c.ba,'NA') = case when b.ba='' THEN 'NA' ELSE b.ba END
      AND coalesce(c.post,'NA') = case when b.post='' THEN 'NA' ELSE b.post END
      AND coalesce(c.tv,'NA') = case when b.tv='' THEN 'NA' ELSE b.tv END
      AND coalesce(c.fija,'NA') = case when b.fija='' THEN 'NA' ELSE b.fija END
      AND CONTAINS_SUBSTR(b.valor,'LOW')
      AND trim(c.valor) = '';

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
      trim(c.marca_ds) = trim(coalesce(b.marca_ds,''))
      AND coalesce(c.ba,'NA') = case when b.ba='' THEN 'NA' ELSE b.ba END
      AND coalesce(c.post,'NA') = case when b.post='' THEN 'NA' ELSE b.post END
      AND coalesce(c.tv,'NA') = case when b.tv='' THEN 'NA' ELSE b.tv END
      AND coalesce(c.fija,'NA') = case when b.fija='' THEN 'NA' ELSE b.fija END
      AND CONTAINS_SUBSTR(b.valor,'MID')
      AND trim(c.valor) = '';

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
      trim(c.marca_ds) = trim(coalesce(b.marca_ds,''))
      AND coalesce(c.ba,'NA') = case when b.ba='' THEN 'NA' ELSE b.ba END
      AND coalesce(c.post,'NA') = case when b.post='' THEN 'NA' ELSE b.post END
      AND coalesce(c.tv,'NA') = case when b.tv='' THEN 'NA' ELSE b.tv END
      AND coalesce(c.fija,'NA') = case when b.fija='' THEN 'NA' ELSE b.fija END
      AND CONTAINS_SUBSTR(b.valor,'HIGH')
      AND trim(c.valor) = '';


end