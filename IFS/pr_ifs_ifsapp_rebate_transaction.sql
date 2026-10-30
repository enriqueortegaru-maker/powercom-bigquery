BEGIN

-- CALL `mm-commissions-reporting.IFS.pr_ifs_ifsapp_rebate_transaction`('2022-11-01')

DECLARE last_month_rebate, table_name, qry, month_name STRING;


SET last_month_rebate = (
                        SELECT MAX(table_name)
                        FROM (
                             SELECT RIGHT(table_name, 8) AS table_name
                             FROM `mm-dwh-prod.00_SANDBOX_IFS.INFORMATION_SCHEMA.TABLES`
                             WHERE table_name LIKE 'IFSAPP_REBATE_TRANSACTION_20%'
                             )
                        WHERE DATE_TRUNC(PARSE_DATE('%Y%m%d', table_name), MONTH) = DATE_ADD(mes_pr, INTERVAL 1 MONTH)
                        );


CREATE OR REPLACE TEMPORARY TABLE ifs_transactions AS

SELECT DISTINCT
        transaction_id
       ,yoi_activation_date_fixed
       ,yoi_deactivation_date_fixed
       ,contract_type_group
       ,state

FROM `mm-dwh-prod.00_SANDBOX_IFS.IFSAPP_REBATE_TRANSACTION_*`
WHERE _table_suffix = last_month_rebate
;


SET month_name = REPLACE(CAST(DATE_ADD(mes_pr, INTERVAL 1 MONTH) AS STRING), '-', '');
SET table_name = CONCAT('`mm-commissions-reporting.IFS.ifs_ifsapp_rebate_transaction_', month_name, '`');
SET qry = 'CREATE OR REPLACE TABLE ' || table_name || ' AS SELECT * FROM ' || 'ifs_transactions';
EXECUTE IMMEDIATE qry;

END