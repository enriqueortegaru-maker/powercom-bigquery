BEGIN

--CREATE OR REPLACE VIEW `mm-commissions-reporting.KRT_REPORTING.v_ventas_base_telco_net_pyme` AS (

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_REPORTING.ventas_base_telco_net_pyme` AS
  with v as (
    SELECT distinct *
    FROM `mm-datamart-kd.SERVICES.ventas_base_telco_net`
    where brand_ds in("EUSKALTEL","TELECABLE","R")
    and sub_segment_ds="PYME"
  ), i as (

    select distinct brand_ds, datasource_ds, customer_id, company_name, company_size
    from `mm-datamart-kd.SERVICES.hash_int_customer_personal_info`
    where brand_ds in("EUSKALTEL","TELECABLE","R")
    and sub_segment_ds="PYME"

  )  select distinct v.*, i.* except(brand_ds, customer_id)
  from v
  left join i on v.brand_ds=i.brand_Ds and v.data_source_ds=i.datasource_ds and v.customer_id=i.customer_id;

--);

END