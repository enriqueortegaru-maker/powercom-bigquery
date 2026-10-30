BEGIN

/*
CALL `mm-commissions-reporting.COMISIONES.pr_actualizar_facturas_drive`();
*/

UPDATE `mm-commissions-reporting.COMISIONES.transacciones` a

SET id_factura_drive = b.fileid, modificado = CURRENT_TIMESTAMP()

FROM (
     SELECT * EXCEPT(rank)
     FROM (
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM `mm-commissions-reporting.REPORTED.log_files`
          WHERE UPPER(file_name) LIKE '%PDF%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
          UNION ALL
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM `mm-commissions-reporting.REPORTED.log_files_facturas_b2b_cablemovil`
          WHERE UPPER(file_name) LIKE '%PDF%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
          UNION ALL
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM `mm-commissions-reporting.REPORTED.log_files_facturas_b2b_marblanca`
          WHERE UPPER(file_name) LIKE '%PDF%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
          UNION ALL

     --HACEMOS SPLIT PARA PREPAGO, DE ESTE MODO, LA CONVIVENCIA NO SE VE AFECTADA Y SIRVE PARA EL ESCENARIO DEFINITIVO --JAVIER GONZALEZ JULIO/26
/*
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM `mm-commissions-reporting.REPORTED.log_files_facturas_etnico`
          WHERE UPPER(file_name) LIKE '%PDF%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
*/
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM(
               SELECT file_name, file_id, created_date
               FROM `mm-commissions-reporting.REPORTED.log_files_facturas_etnico`
               WHERE UPPER(file_name) LIKE '%PDF%'

               UNION ALL

               SELECT file_name, file_id, created_date
               FROM `mm-commissions-reporting.REPORTED.log_files_facturas_etnico_prepaid`
               WHERE UPPER(file_name) LIKE '%PDF%'
          )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
          UNION ALL
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM `mm-commissions-reporting.REPORTED.log_files_facturas_no_exclusivo`
          WHERE UPPER(file_name) LIKE '%PDF%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
          UNION ALL
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM `mm-commissions-reporting.REPORTED.log_files_facturas_resto`
          WHERE UPPER(file_name) LIKE '%PDF%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
          UNION ALL
          (
          SELECT
                SPLIT(file_name, '_')[OFFSET(1)] AS invoice_id
               ,file_id AS fileid
               ,created_date
               ,1 AS rank
          FROM `mm-commissions-reporting.REPORTED.log_files_facturas_historic`
          WHERE UPPER(file_name) LIKE '%PDF%'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY created_date DESC) = 1
          )
          )
     QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
     ) b

WHERE a.invoice_id = b.invoice_id
  AND (a.id_factura_drive <> b.fileid OR a.id_factura_drive IS NULL)   --PROPUESTA CORRECCION JAVIER GONZALEZ PARA NO ACTUALIZAR REGISTROS IGUALES  --DEBEMOS INCLUIR TAMBIÉN EL NULL
;

END