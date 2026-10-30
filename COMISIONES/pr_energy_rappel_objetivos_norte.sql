begin

     declare prefijo, mes_string string;
     declare vdesde int64;
     set vdesde=SAFE_ADD(SAFE_MULTIPLY(id_mes_pr,100),1);
     --- LOCAL
     --declare id_mes_pr INT64;declare vmarco_energia STRING;set id_mes_pr=202501;set vmarco_energia='TLV OUTBOUND CARTERA';

     --call COMISIONES.pr_energy_rappel_objetivos_norte(202501, null);

     CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.ENERGY_RAPPEL_OBJETIVO_norte` 
     OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) as      
     with imp as (

          select * except(maximo,importe),
          coalesce(LAG(maximo,1) over(partition by marco_energia, clase, concepto order by maximo asc), 0 ) as base,
          maximo, importe
          from `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_RAPPELxPCT_IMPORTE`
          order by marco_energia, clase, concepto, maximo

     ),  obj as (
          
          --declare id_mes_pr, vdesde INT64;declare vmarco_energia STRING;set id_mes_pr=202506;set vdesde=20250601;set vmarco_energia='TLV OUTBOUND CARTERA';
          select 
          --c. *
          c.marca, c.marco_energia, c.distribuidor, c.distribuidor_norm,
          --- Número de ventas
          count(c.commission_id)  as nc, --over(partition by c.marca, c.marco_energia, c,distribuidor) as ncom
          o.objetivo,
          lt.nlaborables,
          lc.nlaborables,
          safe_divide(count(c.commission_id), o.objetivo) as ratio_no_pond,
          --safe_divide(safe_multiply(safe_divide(count(c.commission_id), o.objetivo),lc.nlaborables),lt.nlaborables) as ratio
          ROUND(safe_divide(safe_multiply(safe_divide(count(c.commission_id), o.objetivo),lc.nlaborables),lt.nlaborables),3) as ratio
          from `mm-commissions-reporting.KRT_REPORTING.COMISIONES_ENERGIA` c
          inner join `mm-commissions-reporting.GS.PARAM_KRT_ENERGIA_RAPPELxPCT_OBJETIVOS` o
          on o.marca=c.marca and o.marco_energia=c.marco_energia and c.distribuidor_norm=`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(o.distribuidor)
          left join `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesTranscurrido`(CAST(FORMAT_DATE("%Y%m%d", PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING))) AS INT64)) lt on lt.marca_ds=c.marca
          left join `mm-commissions-reporting.KRT_SAP.f_vt_est_nDiasLaborablesEnMesCompleto`(CAST(FORMAT_DATE("%Y%m%d", PARSE_DATE("%Y%m%d", CAST(vdesde AS STRING))) AS INT64)) lc on lc.marca_ds=c.marca
          where (contains_substr(c.clase,"LUZ") or contains_substr(c.clase,"ELECTRICIDAD"))
          and c.marco_energia=vmarco_energia
          and o.marco_energia=vmarco_energia          
          and coalesce(o.objetivo,0) >0
          group by 1,2,3,4,6,7,8


     ) select c.*, o.ratio, i.base, i.maximo, i.importe
     from `mm-commissions-reporting.KRT_REPORTING.COMISIONES_ENERGIA` c
     inner join obj o using(marca, marco_energia, distribuidor_norm)
     inner join imp i using(marco_energia, clase, concepto)
     --order by c.commission_id asc
     where o.ratio >= i.base 
     and  o.ratio < i.maximo
     --and service_id="680017"
     and id_mes=id_mes_pr;


     UPDATE `mm-commissions-reporting.TEMP.ENERGY_RAPPEL_OBJETIVO_norte` 
     SET COMISION=importe,
     concepto='D - Rappel',
     commission_id=concat(commission_id,'ROB')
     WHERE TRUE;

end