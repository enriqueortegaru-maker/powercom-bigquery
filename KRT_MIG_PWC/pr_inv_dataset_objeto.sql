BEGIN
    /*
    DECLARE current_project STRING DEFAULT 'mm-commissions-reporting';
    DECLARE target_dataset_scope STRING DEFAULT 'KRT_CAPTACION';
    */


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.INV_DATASET_OBJETO` AS
    SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.f_vt_inv_dataset_objeto`('mm-commissions-reporting','KRT_CAPTACION')
    UNION ALL
    SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.f_vt_inv_dataset_objeto`('mm-commissions-reporting','KRT_CARTERA')
    UNION ALL
    SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.f_vt_inv_dataset_objeto`('mm-commissions-reporting','KRT_SAP')
    UNION ALL
    SELECT * FROM `mm-commissions-reporting.KRT_MIG_PWC.f_vt_inv_dataset_objeto`('mm-commissions-reporting','KRT_MIG_PWC');

END