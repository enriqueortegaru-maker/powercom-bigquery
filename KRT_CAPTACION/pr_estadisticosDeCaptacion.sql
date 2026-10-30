BEGIN

      ----  CONTABILIDAD DE ACCESOS DE BA

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxDIA` AS
      SELECT f.dia_dt as fecha_dt, f.dia_id as dia_id,  count(distinct s.servicio_id||s.marca_ds) naccba
      from `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA` f
      left join  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s 
      on f.dia_id between fecha_operacion_alta_id and fecha_baja_id
      where f.dia_id >=CAST(FORMAT_DATE("%Y%m%d",date_trunc(CURRENT_DATE(),year))AS INT64)
          and f.dia_dt < current_date() 
          and s.visibilidad_lg = 1  
          and s.tipo_servicio_ds='BANDA ANCHA'
          and s.segmento_ds in ('SOHO', 'RESIDENCIAL','PYME')
      group by 1,2
      order by 1 desc;

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxMARCAxDIA` AS
      SELECT f.dia_dt as fecha_dt, f.dia_id as dia_id, s.marca_ds,  count(distinct s.servicio_id||s.marca_ds) naccba
      from `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.DIM_FECHA` f
      left join  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s 
      on f.dia_id between fecha_operacion_alta_id and fecha_baja_id
      where f.dia_id >=CAST(FORMAT_DATE("%Y%m%d",date_trunc(CURRENT_DATE(),year))AS INT64)
          and f.dia_dt < current_date() 
          and s.visibilidad_lg = 1  
          and s.tipo_servicio_ds='BANDA ANCHA'
          and s.segmento_ds in ('SOHO', 'RESIDENCIAL','PYME')
      group by 1,2,3
      order by 1,2,3;




   --- ESTADISTICOS DE SERVICIOS COMISIONABLES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxDIA` as 
      with scagg as ( 
        with fechas as (
          SELECT fecha_dt 
          from 
          (select distinct LAST_DAY(fecha_calc_dt) as fecha_dt from `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION`
          UNION ALL SELECT CURRENT_DATE() as fecha_dt) 
          order by 1 desc
        ) select * from  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` scag
        inner join fechas
        on scag.fecha_calc_dt=fechas.fecha_dt
        where scag.CONCEPTO_DS!="Descuento plataforma cancelación" 
        order by scag.marca_ds desc, scag.fecha_rfb_dt desc   
      ) select PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d , nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      count(distinct concat(scagg.marca_ds,scagg.cliente_id)) as nclientes, count(concat(scagg.marca_ds, scagg.servicio_id)) as nsc, 
      count(distinct concat(scagg.marca_ds,scagg.servicio_id)) as nscd, 
      safe_divide(count(distinct concat(scagg.marca_ds,scagg.servicio_id)),nac.naccba) as rscd_pr,
      1-safe_divide(count(distinct concat(scagg.marca_ds,scagg.servicio_id)),nac.naccba) as rscd_nopr,
      1000*safe_divide(count(distinct concat(scagg.marca_ds,scagg.servicio_id)),nac.naccba) as nscdx1kpr
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxDIA` as nac 
      left join scagg 
      on FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',scagg.fecha_rfb_dt)  
      --where CONCEPTO_DS!="Descuento plataforma cancelación" 
      group by 1,2,3,4,5,6,7 order by 1 desc,2 desc;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxMARCAxDIA` as 
      with scagg as ( 
        with fechas as (
          SELECT fecha_dt 
          from 
          (select distinct LAST_DAY(fecha_calc_dt) as fecha_dt from `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION`
          UNION ALL SELECT CURRENT_DATE() as fecha_dt) 
          order by 1 desc
        ) select * from  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` scag
        inner join fechas
        on scag.fecha_calc_dt=fechas.fecha_dt
        where scag.CONCEPTO_DS!="Descuento plataforma cancelación" 
        order by scag.marca_ds desc, scag.fecha_rfb_dt desc   
      ) select nac.marca_ds, PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d , nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      count(distinct concat(scagg.marca_ds,scagg.cliente_id)) as nclientes, count(concat(scagg.marca_ds, scagg.servicio_id)) as nsc, 
      count(distinct concat(scagg.marca_ds,scagg.servicio_id)) as nscd, 
      safe_divide(count(distinct concat(scagg.marca_ds,scagg.servicio_id)),nac.naccba) as rscd_pr,
      1-safe_divide(count(distinct concat(scagg.marca_ds,scagg.servicio_id)),nac.naccba) as rscd_nopr,
      1000*safe_divide(count(distinct concat(scagg.marca_ds,scagg.servicio_id)),nac.naccba) as nscdx1kpr
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxMARCAxDIA` as nac 
      left join scagg 
      on nac.marca_ds=scagg.marca_ds and FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',scagg.fecha_rfb_dt)  
      --where CONCEPTO_DS!="Descuento plataforma cancelación" 
      group by 1,2,3,4,5,6,7,8 order by 1 desc,2 desc;



      --- TENDENCIA DE ESTADISTICOS DE SERVICIOS COMISIONABLES 


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxDIA_TREND` as 
    select sc.*, 
    avg(sc.nscd) over (ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nscd7d,
    avg(sc.nscd) over (ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nscd28d,    
    sum(sc.nscd) over (ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nscd7d,
    sum(sc.nscd) over (ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nscd28d,  
    safe_divide(sum(sc.nscd) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_rscd_pr7d,   
    safe_divide(sum(sc.nscd) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_rscd_pr28d,  
    sum(sc.rscd_pr) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_rscd_pr7d,
    sum(sc.rscd_pr) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_rscd_pr28d,
    1-safe_divide(sum(sc.nscd) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_rscd_nopr7d,   
    1-safe_divide(sum(sc.nscd) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_rscd_nopr28d,  
    sum(sc.rscd_nopr) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_rscd_nopr7d,
    sum(sc.rscd_nopr) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_rscd_nopr28d,
    1000*safe_divide(sum(sc.nscd) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_nscdx1kpr7d,   
    1000*safe_divide(sum(sc.nscd) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_nscdx1kpr28d,  
    avg(sc.nscdx1kpr) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) - 
    1000*safe_divide(sum(sc.nscd) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as diff_avg_nscdx1kpr_7d_28d,  
    sum(sc.nscdx1kpr) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nscdx1kpr7d,
    sum(sc.nscdx1kpr) over ( ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nscdx1kpr28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxDIA` as sc
    order by 1 desc;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxMARCAxDIA_TREND` as 
    select sc.*, 
    avg(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nscd7d,
    avg(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nscd28d,    
    sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nscd7d,
    sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nscd28d,  
    safe_divide(sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_rscd_pr7d,   
    safe_divide(sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_rscd_pr28d,  
    sum(sc.rscd_pr) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_rscd_pr7d,
    sum(sc.rscd_pr) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_rscd_pr28d,
    1-safe_divide(sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_rscd_nopr7d,   
    1-safe_divide(sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_rscd_nopr28d,  
    sum(sc.rscd_nopr) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_rscd_nopr7d,
    sum(sc.rscd_nopr) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_rscd_nopr28d,
    1000*safe_divide(sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_nscdx1kpr7d,   
    1000*safe_divide(sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_nscdx1kpr28d,  
    1000*safe_divide(sum(sc.nscd) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(sc.naccba)  over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as diff_avg_nscdx1kpr_7d_28d,  
    sum(sc.nscdx1kpr) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nscdx1kpr7d,
    sum(sc.nscdx1kpr) over ( PARTITION BY sc.marca_ds ORDER BY sc.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nscdx1kpr28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxMARCAxDIA` as sc
    order by 1 desc, 2 desc;

   --- ESTADISTICOS DE UNITARIOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNI` as 
      with uniagg as ( 
        with fechas as (
          SELECT fecha_dt 
          from 
          (select distinct LAST_DAY(fecha_calc_dt) as fecha_dt from `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS`
          UNION ALL SELECT CURRENT_DATE() as fecha_dt) 
          order by 1 desc
        ) select * from  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` uniag
        inner join fechas
        on uniag.fecha_calc_dt=fechas.fecha_dt
        where uniag.CONCEPTO_DS!="Descuento plataforma cancelación" 
        order by uniag.marca_ds desc, uniag.fecha_rfb_dt desc   
      ) select distinct uniagg.*  except(fecha_calc_dt)
      from uniagg 
      order by 1 desc, 2 desc;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNIxDIA` as 
      select PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d, nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      nsc.nsc,
      nsc.nscd,
      count(distinct concat(uniagg.marca_ds,uniagg.cliente_id)) as nclientes, count(concat(uniagg.marca_ds, uniagg.servicio_id)) as nuni, 
      count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)) as nunid, 
      safe_divide(1000*count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)),sum(nac.naccba)) as nunidx1k,
      safe_divide(count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)),nsc.nscd) as runid_sc,
      1-safe_divide(count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)),nsc.nscd) as runid_nosc    
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxDIA` as nac 
      left join `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNI` as uniagg 
      on FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',uniagg.fecha_rfb_dt)
      left join `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxDIA` as nsc
      on PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt))=nsc.fecha_rfb_d
      group by 1,2,3,4,5,6,7,8,9 order by 1 desc;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNIxMARCAxDIA` as 
      select nac.marca_ds,  PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d, nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      nsc.nsc,
      nsc.nscd,
      count(distinct concat(uniagg.marca_ds,uniagg.cliente_id)) as nclientes, count(concat(uniagg.marca_ds, uniagg.servicio_id)) as nuni, 
      count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)) as nunid, 
      safe_divide(1000*count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)),nac.naccba) as nunidx1k,
      safe_divide(count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)),nsc.nscd) as runid_sc,
      1-safe_divide(count(distinct concat(uniagg.marca_ds,uniagg.servicio_id)),nsc.nscd) as runid_nosc    
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxMARCAxDIA` as nac 
      left join  `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNI` as  uniagg 
      on nac.marca_ds=uniagg.marca_ds and FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',uniagg.fecha_rfb_dt)
      left join `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxMARCAxDIA` as nsc
      on nac.marca_ds=nsc.marca_ds and PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt))=nsc.fecha_rfb_d
      group by 1,2,3,4,5,6,7,8,9,10 order by 1 desc,2 desc;


    --- TENDENCIA DE ESTADISTICOS DE UNITARIOS 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNIxDIA_TREND` as 
    select uni.*, 
    avg(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunid7d,
    avg(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunid28d,    
    sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunid7d,
    sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunid28d,  
    avg(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunidx1k7d,
    avg(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunidx1k28d, 
    sum(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunidx1k7d,
    sum(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunidx1k28d,
    safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_sc7d,   
    safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_sc28d,  
    sum(uni.runid_sc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_sc7d,
    sum(uni.runid_sc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_sc28d, 
    1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc7d,   
    1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc28d,  
    (1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))) - (1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW)))  as diff_avg_runid_nosc_7d_28d,
    sum(uni.runid_nosc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_nosc7d,
    sum(uni.runid_nosc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_nosc28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNIxDIA` as uni
    order by 1 desc, 2 desc;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNIxMARCAxDIA_TREND` as 
    select uni.*, 
    avg(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunid7d,
    avg(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunid28d,    
    sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunid7d,
    sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunid28d,  
    avg(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunidx1k7d,
    avg(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunidx1k28d, 
    sum(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunidx1k7d,
    sum(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunidx1k28d,
    safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_sc7d,   
    safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_sc28d,  
    sum(uni.runid_sc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_sc7d,
    sum(uni.runid_sc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_sc28d, 
    1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc7d,   
    1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc28d,  
    (1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))) - (1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW)))  as diff_avg_runid_nosc_7d_28d,
    sum(uni.runid_nosc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_nosc7d,
    sum(uni.runid_nosc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_nosc28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNIxMARCAxDIA` as uni
    order by 1 desc, 2 desc;


  --- LISTADO DE SERVICIOS COMISIONABLES SIN UNITARIOS CALCULADOS


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_SCNOUNI` as 
    with uniagg as ( 
      with fechas as (
        SELECT fecha_dt 
        from 
        ( select distinct LAST_DAY(fecha_calc_dt) as fecha_dt from `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS`
          UNION ALL SELECT CURRENT_DATE() as fecha_dt) 
          order by 1 desc
        ) select * from  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` uniag
        inner join fechas
        on uniag.fecha_calc_dt=fechas.fecha_dt
        where uniag.CONCEPTO_DS!="Descuento plataforma cancelación" 
        order by uniag.marca_ds desc, uniag.fecha_rfb_dt desc   
      ), scagg as (
        with fechas as (
            SELECT fecha_dt 
            from 
            (select distinct LAST_DAY(fecha_calc_dt) as fecha_dt from `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION`
              UNION ALL SELECT CURRENT_DATE() as fecha_dt) 
              order by 1 desc
            ) select * from  `mm-commissions-reporting.KRT_CAPTACION.AGG_SERVICIOS_CAPTACION` scag
            inner join fechas
            on scag.fecha_calc_dt=fechas.fecha_dt
            where scag.CONCEPTO_DS!="Descuento plataforma cancelación" 
            order by scag.marca_ds desc, scag.fecha_rfb_dt desc   
      ) select distinct scagg.* except(fecha_calc_dt)
      from scagg
      left join uniagg
      on scagg.marca_ds=uniagg.marca_ds and scagg.Cliente_id=uniagg.Cliente_id and scagg.servicio_id=uniagg.servicio_id and scagg.concepto_ds=uniagg.concepto_ds and scagg.fecha_rfb_dt=uniagg.fecha_rfb_dt
      where uniagg.FECHA_RFB_ID is null
      order by 1 desc, 2 desc;


      --- LISTADO DE UNITARIOS COMISIONADOS

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNICOM` as  
        with uniagg as ( 
          with fechas as (
            SELECT fecha_dt 
            from 
            (select distinct LAST_DAY(fecha_calc_dt) as fecha_dt from `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS`
            UNION ALL SELECT CURRENT_DATE() as fecha_dt) 
            order by 1 desc
          ) select * from  `mm-commissions-reporting.KRT_CAPTACION.AGG_UNITARIOS` uniag
          inner join fechas
          on uniag.fecha_calc_dt=fechas.fecha_dt
          where uniag.CONCEPTO_DS!="Descuento plataforma cancelación" 
          order by uniag.marca_ds desc, uniag.fecha_rfb_dt desc   
        ), comagg as (
          with fechas as (
            SELECT fecha_dt 
            from 
            (select distinct LAST_DAY(fecha_calc_dt) as fecha_dt from `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES`
            UNION ALL SELECT CURRENT_DATE() as fecha_dt) 
            order by 1 desc
          ) select * from  `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` comag
          inner join fechas
          on comag.fecha_calc_dt=fechas.fecha_dt
          where comag.CONCEPTO_DS!="Descuento plataforma cancelación" 
          order by comag.marca_ds desc, comag.fecha_rfb_dt desc   
        ) select distinct uniagg.*  except(fecha_calc_dt)
        from uniagg 
        inner join comagg
        on comagg.marca_ds=uniagg.marca_ds and comagg.Cliente_id=uniagg.Cliente_id and comagg.servicio_id=uniagg.servicio_id and comagg.concepto_ds=uniagg.concepto_ds
        order by 1 desc, 2 desc;


      --- ESTADISTICOS DE UNITARIOS COMISIONADOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNICOMxDIA` as 
      select PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d, nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      nsc.nsc,
      nsc.nscd,
      count(distinct concat(unicomagg.marca_ds,unicomagg.cliente_id)) as nclientes, count(concat(unicomagg.marca_ds, unicomagg.servicio_id)) as nuni, 
      count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)) as nunid, 
      safe_divide(1000*count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nac.naccba) as nunidx1k,
      safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_sc,
      1-safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_nosc    
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxDIA` as nac 
      left join  `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNICOM` as unicomagg 
      on FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',unicomagg.fecha_rfb_dt)
      left join `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxDIA` as nsc
      on PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt))=nsc.fecha_rfb_d
      group by 1,2,3,4,5,6,7,8,9 order by 1 desc,2 desc;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNICOMxMARCAxDIA` as 
      select nac.marca_ds,  PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d, nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      nsc.nsc,
      nsc.nscd,
      count(distinct concat(unicomagg.marca_ds,unicomagg.cliente_id)) as nclientes, count(concat(unicomagg.marca_ds, unicomagg.servicio_id)) as nuni, 
      count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)) as nunid, 
      safe_divide(1000*count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nac.naccba) as nunidx1k,
      safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_sc,
      1-safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_nosc    
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxMARCAxDIA` as nac 
      left join  `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNICOM` as unicomagg 
      on nac.marca_ds=unicomagg.marca_ds and FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',unicomagg.fecha_rfb_dt)
      left join `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxMARCAxDIA` as nsc
      on nac.marca_ds=nsc.marca_ds and PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt))=nsc.fecha_rfb_d
      group by 1,2,3,4,5,6,7,8,9,10 order by 1 desc,2 desc;


   --- TENDENCIA DE ESTADISTICOS DE UNITARIOS COMISIONADOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNICOMxDIA_TREND` as 
    select uni.*, 
    avg(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunid7d,
    avg(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunid28d,    
    sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunid7d,
    sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunid28d,  
    avg(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunidx1k7d,
    avg(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunidx1k28d, 
    sum(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunidx1k7d,
    sum(uni.nunidx1k) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunidx1k28d,
    safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_sc7d,   
    safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_sc28d,  
    sum(uni.runid_sc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_sc7d,
    sum(uni.runid_sc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_sc28d, 
    1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc7d,   
    1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc28d,  
    (1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))) - (1-safe_divide(sum(uni.nunid) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW)))  as diff_avg_runid_nosc_7d_28d,
    sum(uni.runid_nosc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_nosc7d,
    sum(uni.runid_nosc) over ( ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_nosc28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNICOMxDIA` as uni
    order by 1 desc, 2 desc;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNICOMxMARCAxDIA_TREND` as 
    select uni.*, 
    avg(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunid7d,
    avg(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunid28d,    
    sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunid7d,
    sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunid28d,  
    avg(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunidx1k7d,
    avg(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunidx1k28d, 
    sum(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunidx1k7d,
    sum(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunidx1k28d,
    safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_sc7d,   
    safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_sc28d,  
    sum(uni.runid_sc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_sc7d,
    sum(uni.runid_sc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_sc28d, 
    1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc7d,   
    1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc28d,  
    (1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))) - (1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW)))  as diff_avg_runid_nosc_7d_28d,
    sum(uni.runid_nosc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_nosc7d,
    sum(uni.runid_nosc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_nosc28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNICOMxMARCAxDIA` as uni
    order by 1 desc, 2 desc;

    --- LISTADO DE UNITARIOS NO COMISIONADOS

      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNINOCOM` as  
      SELECT uni.* 
      FROM `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNI` as uni
      WHERE NOT EXISTS (
        SELECT * 
        FROM `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNICOM` as unicom
        where unicom.marca_ds=uni.marca_ds and unicom.cliente_id=uni.cliente_id and unicom.servicio_id=uni.servicio_id and unicom.fecha_rfb_dt=uni.fecha_rfb_dt
        );

      --- ESTADISTICOS DE UNITARIOS NO COMISIONADOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNINOCOMxDIA` as 
      select PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d, nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      nsc.nsc,
      nsc.nscd,
      count(distinct concat(unicomagg.marca_ds,unicomagg.cliente_id)) as nclientes, count(concat(unicomagg.marca_ds, unicomagg.servicio_id)) as nuni, 
      count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)) as nunid, 
      safe_divide(1000*count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nac.naccba) as nunidx1k,
      safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_sc,
      1-safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_nosc    
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxDIA` as nac 
      left join  `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNINOCOM` as unicomagg 
      on FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',unicomagg.fecha_rfb_dt)
      left join `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxDIA` as nsc
      on PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt))=nsc.fecha_rfb_d
      group by 1,2,3,4,5,6,7,8,9 order by 1 desc,2 desc;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNINOCOMxMARCAxDIA` as 
      select nac.marca_ds,  PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt)) as fecha_rfb_d, nac.naccba, 
      Extract(YEAR from nac.fecha_dt) as nyear, Extract(QUARTER from nac.fecha_dt) as nquarter, 
      Extract(MONTH from nac.fecha_dt) as nmonth, Extract(WEEK from nac.fecha_dt) as nweek, 
      Extract(DAYOFWEEK  from nac.fecha_dt) as ndayweek, 
      nsc.nsc,
      nsc.nscd,
      count(distinct concat(unicomagg.marca_ds,unicomagg.cliente_id)) as nclientes, count(concat(unicomagg.marca_ds, unicomagg.servicio_id)) as nuni, 
      count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)) as nunid, 
      safe_divide(1000*count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nac.naccba) as nunidx1k,
      safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_sc,
      1-safe_divide(count(distinct concat(unicomagg.marca_ds,unicomagg.servicio_id)),nsc.nscd) as runid_nosc    
      from `mm-commissions-reporting.KRT_CAPTACION.STAT_NACCBAxMARCAxDIA` as nac 
      left join  `mm-commissions-reporting.KRT_CAPTACION.STAT_LIST_UNINOCOM` as unicomagg 
      on nac.marca_ds=unicomagg.marca_ds and FORMAT_DATE('%Y%m%d',nac.fecha_dt)=FORMAT_DATE('%Y%m%d',unicomagg.fecha_rfb_dt)
      left join `mm-commissions-reporting.KRT_CAPTACION.STAT_NSCxMARCAxDIA` as nsc
      on nac.marca_ds=nsc.marca_ds and PARSE_DATE('%Y-%m-%d',FORMAT_DATE('%Y-%m-%d',nac.fecha_dt))=nsc.fecha_rfb_d
      group by 1,2,3,4,5,6,7,8,9,10 order by 1 desc,2 desc;

      --- TENDENCIA DE ESTADISTICOS DE UNITARIOS NO COMISIONADOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNINOCOMxDIA_TREND` as 
    select uni.*, 
    avg(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunid7d,
    avg(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunid28d,    
    sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunid7d,
    sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunid28d,  
    avg(uni.nunidx1k) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunidx1k7d,
    avg(uni.nunidx1k) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunidx1k28d, 
    sum(uni.nunidx1k) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunidx1k7d,
    sum(uni.nunidx1k) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunidx1k28d,
    safe_divide(sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_sc7d,   
    safe_divide(sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_sc28d,  
    sum(uni.runid_sc) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_sc7d,
    sum(uni.runid_sc) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_sc28d, 
    1-safe_divide(sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc7d,   
    1-safe_divide(sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc28d,  
  (1-safe_divide(sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))) - (1-safe_divide(sum(uni.nunid) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW)))  as diff_avg_runid_nosc_7d_28d,
    sum(uni.runid_nosc) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_nosc7d,
    sum(uni.runid_nosc) over (  ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_nosc28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNINOCOMxDIA` as uni
    order by 1 desc, 2 desc;



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNINOCOMxMARCAxDIA_TREND` as 
    select uni.*, 
    avg(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunid7d,
    avg(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunid28d,    
    sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunid7d,
    sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunid28d,  
    avg(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as avg_nunidx1k7d,
    avg(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as avg_nunidx1k28d, 
    sum(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_nunidx1k7d,
    sum(uni.nunidx1k) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_nunidx1k28d,
    safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_sc7d,   
    safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_sc28d,  
    sum(uni.runid_sc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_sc7d,
    sum(uni.runid_sc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_sc28d, 
    1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc7d,   
    1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW))  as avg_runid_nosc28d,  
  (1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW))) - (1-safe_divide(sum(uni.nunid) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW), sum(uni.nscd)  over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW)))  as diff_avg_runid_nosc_7d_28d,
    sum(uni.runid_nosc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 6 PRECEDING  AND CURRENT ROW) as sum_runid_nosc7d,
    sum(uni.runid_nosc) over ( PARTITION BY uni.marca_ds ORDER BY uni.fecha_rfb_d ROWS BETWEEN 27 PRECEDING  AND CURRENT ROW) as sum_runid_nosc28d
    from  `mm-commissions-reporting.KRT_CAPTACION.STAT_NUNINOCOMxMARCAxDIA` as uni
    order by 1 desc, 2 desc;

END