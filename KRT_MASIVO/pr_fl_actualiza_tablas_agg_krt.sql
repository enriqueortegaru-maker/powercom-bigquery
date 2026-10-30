BEGIN


    -- CALL `mm-commissions-reporting.KRT_MASIVO.pr_fl_actualiza_tablas_agg_krt`(202607, "DECOMISION");

    if tipo="TOTAL" or (contains_substr(tipo,"COMISION") and not contains_substr(tipo,"DECOMISION") )then 
        delete from `mm-commissions-reporting.KRT_MASIVO.AGG_COMISIONES` 
        where fecha_calc_dt=CURRENT_DATE() 
        --and CAST(CAST(FORMAT_DATE("%Y%m",activation_date) AS STRING) AS INT64)=vmes_id ;
        and mes_id=vmes_id ;

        insert into `mm-commissions-reporting.KRT_MASIVO.AGG_COMISIONES`  
        from (--  select CURRENT_DATE(),* 
              --  from `mm-commissions-reporting.KRT_PYME.COMISIONES` 
              --  WHERE CAST(CAST(FORMAT_DATE("%Y%m",activation_date) AS STRING) AS INT64)=vmes_id
               
                select CURRENT_DATE(),* 
                from `mm-commissions-reporting.KRT_MASIVO.COMISIONES` 
                WHERE mes_id=vmes_id

            );
    end if;



    if tipo="TOTAL" or contains_substr(tipo,"DECOMISION") then 
        delete from `mm-commissions-reporting.KRT_MASIVO.AGG_DECOMISIONES` 
        where fecha_calc_dt=CURRENT_DATE() 
        --and CAST(CAST(FORMAT_DATE("%Y%m",deactivation_date) AS STRING) AS INT64)=vmes_id ;
        and mes_id=vmes_id ;
        
        insert into `mm-commissions-reporting.KRT_MASIVO.AGG_DECOMISIONES`  
        from (--  select CURRENT_DATE(),* 
              --  from `mm-commissions-reporting.KRT_MASIVO.DECOMISIONES` 
              --  WHERE CAST(CAST(FORMAT_DATE("%Y%m",deactivation_date) AS STRING) AS INT64)=vmes_id
               
                select CURRENT_DATE(),* 
                from `mm-commissions-reporting.KRT_MASIVO.DECOMISIONES` 
                WHERE mes_id=vmes_id               
            );
    end if;

    

END