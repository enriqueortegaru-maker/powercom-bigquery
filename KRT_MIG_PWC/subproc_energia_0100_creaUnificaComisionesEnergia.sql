BEGIN


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_REPORTING.COMISIONES_ENERGIA` AS 
  select distinct *, "LUZ" as clase,
  `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(distribuidor) as distribuidor_norm  
  from `mm-commissions-reporting.TEMP.ENERGY_LUZ_norte` 
  UNION ALL 
  select distinct *, "GAS" as clase,
  `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(distribuidor) as distribuidor_norm  
  from `mm-commissions-reporting.TEMP.ENERGY_GAS_norte`
  UNION ALL
  select distinct *,"SVE" as clase,
  `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(distribuidor) as distribuidor_norm  
  from `mm-commissions-reporting.TEMP.ENERGY_sve_norte`
  UNION ALL
  select distinct *,"SVG" as clase,
  `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(distribuidor) as distribuidor_norm  
  from `mm-commissions-reporting.TEMP.ENERGY_svg_norte`
  UNION ALL
  select distinct *,"REP" as clase,
  `mm-commissions-reporting.KRT_MIG_PWC.f_dist_normalizaNombreDistribuidor`(distribuidor) as distribuidor_norm  
  from `mm-commissions-reporting.TEMP.ENERGY_LUZ_reparto_norte`;
  --UNION ALL
  --select * except(ratio,base,maximo,importe)  
  --from `mm-commissions-reporting.TEMP.ENERGY_RAPPEL_OBJETIVO_norte`;

END