BEGIN 
  ---DECLARE vmes_id INT64;SET vmes_id=202607;

  --- EXTRACOMSIONES NO DISTRIBUIDAS
  INSERT INTO `mm-commissions-reporting.KRT_PYME.COMISIONES`
    (
      mes_id,
      data_source_ds,
      brand_ds,
      service_type,
      channel_ds,
      subchannel_ds,
      distribuidor,
      tipo,
      marco,
      concepto_marco,
      concepto,
      importe,
      orden,
  --    decomisionable,
      comisiona)
  ---DECLARE vmes_id INT64;SET vmes_id=202608;      
  SELECT 
    vmes_id,
    `mm-commissions-reporting.KRT_SAP.f_trans_crea_crm_desde_service_type`(brand_ds, SERVICE_TYPE),
    brand_ds,
    service_type,
    N1,
    N2,
    distribuidor,
    case when contains_substr(marco,"-CR") then "CARTERA"  when contains_substr(marco,"-CP") then "CAPTACION"end as tipo,
    marco,
    concepto_marco,
    CASE 	WHEN UPPER(TRIM(distribuir))='I' THEN 'D - Inicio Actividad'
            WHEN UPPER(TRIM(distribuir))='T' THEN 'D - Trimestral'
            WHEN UPPER(TRIM(distribuir))='A' THEN 'D - Anual' 	 	 	 	 
            WHEN UPPER(TRIM(distribuir))='F' THEN 'D - Fin Actividad'
            --WHEN contains_substr(concepto_marco,"Penalizacion cliente")  THEN 'P - Penalizacion cliente'
            ELSE 'D - Mensual'
    END, 	 	 	 	 	
    importe,
    orden,
    --decomisionable,
    1
  FROM
    `mm-commissions-reporting.GS.PARAM_KRT_PYME_EXTRAS`
  where brand_ds is not null
  and mes_id=vmes_id;

  --- FALTA PARTE DISTRIBUCION

END