BEGIN 


  DECLARE VMES_FACTURA_DT DATE;DECLARE VMES_FACTURA_ID INT64;SET VMES_FACTURA_DT='2024-01-01';SET VMES_FACTURA_ID= CAST(FORMAT_DATE("%Y%m%d",VMES_FACTURA_DT) AS INT64);

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_REPORTING.STAT_SAP_FACTURAS_ACREEDOR` AS

    with d as (
        --DECLARE VMES_FACTURA_DT DATE;DECLARE VMES_FACTURA_ID INT64;SET VMES_FACTURA_DT='2025-03-01';SET VMES_FACTURA_ID= CAST(FORMAT_DATE("%Y%m%d",VMES_FACTURA_DT) AS INT64);    
        with mm as (
          select distinct sociedad, distribuidor, TRIM(UPPER(cif)) as cif 
          from `mm-commissions-reporting.COMISIONES.transacciones`
          where marca not in ("EUSKALTEL","R","TELECABLE","VIRGIN","RACC")
          and mes_liquidado >=VMES_FACTURA_DT
        ), tr_gekt as (
          select distinct mes_factura_dt, UPPER(TRIM(sociedad)) as sociedad, tipo, distribuidor, TRIM(UPPER(cif)) as cif, sum(comision) over(partition by mes_factura_dt, UPPER(TRIM(sociedad)), tipo, distribuidor, TRIM(UPPER(cif))) as importe
          from `mm-commissions-reporting.KRT_SAP.TRANSACCIONES`
          where marca in ("EUSKALTEL","R","TELECABLE","VIRGIN","RACC")
          and mes_factura_dt >=VMES_FACTURA_DT
        ), og as (
          select distinct 
          --nombre_comercial as distribuidor, 
          TRIM(UPPER(CIF)) as cif, 
          autofactura
          from `mm-commissions-reporting.COMISIONES.DEALER_ORANGE` 
        ), bp as (

              --DECLARE VMES_FACTURA_DT DATE;DECLARE VMES_FACTURA_ID INT64;SET VMES_FACTURA_DT='2025-03-01';SET VMES_FACTURA_ID= CAST(FORMAT_DATE("%Y%m%d",VMES_FACTURA_DT) AS INT64);
              with ac as (
                select distinct TRIM(UPPER(sociedad)) as society,  CAST(bp AS STRING) as vendor_id , TRIM(UPPER(cif)) as cif, autofactura as autobill, nombre_acreedor as provider
                from `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ACREEDORES`
              ),   
              p as (
                with acr as (
                    --DECLARE VMES_FACTURA_DT DATE;DECLARE VMES_FACTURA_ID INT64;SET VMES_FACTURA_DT='2025-03-01';SET VMES_FACTURA_ID= CAST(FORMAT_DATE("%Y%m%d",VMES_FACTURA_DT) AS INT64);
                    select distinct * from  `mm-commissions-reporting.KRT_SAP.f_vt_debugSAP_apuntes_tipodocumento_general_ledger_todos_acreedores_desde_fecha`( "KC", VMES_FACTURA_ID) 
                    --UNION ALL
                    --select distinct * from  `mm-commissions-reporting.KRT_SAP.f_vt_debugSAP_apuntes_tipodocumento_general_ledger_todos_acreedores_desde_fecha`( "KB", VMES_FACTURA_ID) 
                    --where vendor_id="13228"
                )  
                SELECT distinct TRIM(UPPER(society)) as society,
                TRIM(UPPER(vendor_id)) as vendor_id,
                document_type_ds,
                fiscal_year,
                period,
                CAST(FORMAT_DATE("%Y%m",DATE_SUB(PARSE_DATE("%Y%m%d",CONCAT(CAST(fiscal_year AS STRING),LPAD(CAST(period as string),2,'0'),'01')), INTERVAL 1 MONTH)) AS INT64) accrual_month_id,
                DATE_SUB(PARSE_DATE("%Y%m%d",CONCAT(CAST(fiscal_year AS STRING),LPAD(CAST(period as string),2,'0'),'01')), INTERVAL 1 MONTH) accrual_month_dt, --restar 1 mes
                array_agg(distinct accounting_date IGNORE NULLS ORDER BY accounting_date) as saccounting_date,
                CASE WHEN  CAST(FORMAT_DATE('%d',clearing_date) AS INT64) BETWEEN 5 AND 9 then DATE_ADD(DATE_TRUNC(clearing_date,MONTH), INTERVAL 4 DAY) 
                    WHEN  CAST(FORMAT_DATE('%d',clearing_date) AS INT64) BETWEEN 20 AND 24 then DATE_ADD(DATE_TRUNC(clearing_date,MONTH), INTERVAL 19 DAY)  
                    else clearing_date 
                END as payment_date,
                clearing_date,  
                FROM acr
                where vendor_id is not null
                group by all 
                order by 1,2,4,5
              ) select p.*,
              ac.cif,
              ac.provider,
              ac.autobill,
              --DATE_DIFF(p.payment_date, p.accrual_month_dt,MONTH) as nmonth,
              --FORMAT_DATE("%d", p.payment_date) as nday,
              CONCAT(CAST(DATE_DIFF(p.payment_date, p.accrual_month_dt,MONTH) AS STRING),'M+',LPAD(FORMAT_DATE("%d", p.payment_date),2,'0')) payment_shift_ds
              from p
              left join ac on ac.society=p.society and ac.vendor_id=p.vendor_id
              --where ac.cif="B75444638"
              order by 1,2,4,5
        ) 
        select distinct bp.* except(society,cif), tr_gekt.* except(distribuidor),  
        case when mm.cif is not null then 1 else 0 END as bdis_mm,
        case when og.cif is not null then 1 else 0 END as bdis_or, 
        --og.autofactura as autofactura_og 
        from tr_gekt 
        left  join mm on mm.cif=tr_gekt.cif 
        left  join og on og.cif=tr_gekt.cif
        left join bp on bp.society=tr_gekt.sociedad and bp.cif=tr_gekt.cif and bp.accrual_month_dt=tr_gekt.mes_factura_dt
        --where case when mm.distribuidor is not null then 1 else 0 END=1 
        --or  case when og.distribuidor is not null then 1 else 0 END=1 
    ) 
    select distinct --sociedad,
      --tipo, 
      vendor_id,
      cif,
      provider,
      document_type_ds,
      fiscal_year,
      period,
      accrual_month_id,
      accrual_month_dt, 
      saccounting_date,
      payment_date,
      clearing_date,
      payment_shift_ds,  
      autobill, 
      --Array_to_string(array_agg(distinct autofactura_og IGNORE NULLS ORDER BY autofactura_og),',') as vautofactura_og, 
      case when max(bdis_mm) + max(bdis_or) > 0 then 1 else 0 end bdis_mo,
      max(bdis_mm) as bdis_mm,
      max(bdis_or) as bdis_or,
      sum(importe) as importe
      from d
      group by all;

END