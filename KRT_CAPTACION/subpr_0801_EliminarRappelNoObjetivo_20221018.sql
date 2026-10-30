BEGIN

  CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` AS

    WITH POB_OBJ AS(
      SELECT * 
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTExTIPIFICACION`
      WHERE NOT (
        UPPER(concepto_ds) LIKE '%RAPPEL%'
        AND coalesce(plays,0) IN (1,
          2)
        AND ((canal_alta_ds='TELEVENTA'
            AND marca_ds = 'V')
          OR (canal_alta_ds = 'WEB'
            AND subcanal_ds = 'WEB DISTRIBUIDOR'
            AND marca_ds <> 'VIRGIN'))
      )
    )
    
    SELECT * 
    FROM POB_OBJ;

end