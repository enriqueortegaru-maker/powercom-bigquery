BEGIN

  DECLARE VFECHA_CALC_DT, VFECHA_CALC_CAP_DT, VFECHA_CALC_CAR_DT  DATE;  
  ---LOCAL
  --DECLARE VDESDE INT64; SET VDESDE=20250101;
  --SET VFECHA_CALC_DT=CURRENT_DATE('Europe/Madrid');
  SET VFECHA_CALC_DT=DATE_SUB(CURRENT_DATE('Europe/Madrid'), INTERVAL 1 DAY);
  SET VFECHA_CALC_CAP_DT=(select max(fecha_calc_dt) from `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` where desde=vdesde);
  SET VFECHA_CALC_CAR_DT=(select max(fecha_calc_dt) from `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CANALES` where desde=vdesde);  

  --SELECT VFECHA_CALC_DT;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_MIG_PWC.ENERGIA_DECOMISIONES_CANALIZADAS_CTX` AS
  with p as (
    select marca_ds, canal_ds, subcanal_ds, nombre_distribuidor_ds,ARRAY_TO_STRING(array_agg(distinct marco_retributivo_ds  order by marco_retributivo_ds),',' ) as marco
    from `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES`
    where fecha_Calc_dt=VFECHA_CALC_CAP_DT
    and desde=vdesde	
    group by 1,2,3,4
    order by 1,2,3,4
  ),

  r as (
    select marca_ds, canal, subcanal, nombre_distribuidor, ARRAY_TO_STRING(array_agg(distinct agrupador_mr order by agrupador_mr),',' ) as marco 
    from `mm-commissions-reporting.KRT_CARTERA.AGG_PARAM_CANALES`
    where fecha_Calc_dt=VFECHA_CALC_CAR_DT
    and desde=vdesde    
    group by 1,2,3,4
    order by 1,2,3,4
  )

  --- CLAWBACK

  select "CAPTACION" as tipo, 
  `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) as clase,
  e.*, 
  marco,
  `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) as distribuidor_norm
  from `mm-commissions-reporting.TEMP.ENERGY_CLAWBACK_norte`  e
  inner join p on UPPER(TRIM(e.marca))=UPPER(TRIM(p.marca_ds)) and UPPER(TRIM(e.canal_ds))=UPPER(TRIM(p.canal_ds)) 
  and case when UPPER(TRIM(p.subcanal_ds))!='X' THEN e.subcanal_ds=p.subcanal_ds ELSE TRUE END 
  and UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor)))=UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(p.nombre_distribuidor_ds)))
  UNION ALL

  select "CARTERA" as tipo,
  `mm-commissions-reporting.KRT_MIG_PWC.f_energia_obtenerClaseDesdeConcepto`(e.concepto) as clase,  
  e.*,
  marco,  
  `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor) as distribuidor_norm   
  from `mm-commissions-reporting.TEMP.ENERGY_CLAWBACK_norte`  e
  inner join r on UPPER(TRIM(e.marca))=UPPER(TRIM(r.marca_ds)) and UPPER(TRIM(e.canal_ds))=UPPER(TRIM(r.canal))
  and case when UPPER(TRIM(r.subcanal))!='X' THEN UPPER(TRIM(e.subcanal_ds))=UPPER(TRIM(r.subcanal)) ELSE TRUE END
  and UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor)))=UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(r.nombre_distribuidor)))
  where not exists (
      select 1
      from `mm-commissions-reporting.KRT_CAPTACION.AGG_PARAM_CANALES` p
      where UPPER(TRIM(e.marca))=UPPER(TRIM(p.marca_ds)) and UPPER(TRIM(e.canal_ds))=UPPER(TRIM(p.canal_ds)) 
      and case when UPPER(TRIM(p.subcanal_ds))!='X' THEN e.subcanal_ds=p.subcanal_ds ELSE TRUE END 
and UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(e.distribuidor)))=UPPER(TRIM(`mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(p.nombre_distribuidor_ds)))      

  );


END