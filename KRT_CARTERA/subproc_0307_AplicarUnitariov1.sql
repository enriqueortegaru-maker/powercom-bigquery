BEGIN  


  ---============================================================================================================
  --- MODULO QUE CALCULA  EL IMPORTE BASE QUE SE APLICA AL EVENTO COMISIONBLE Y ENRIQUECE EL EVENTO CON ESE DATO
  ---   IMPORTE: IMPORTE BASE DE LA COMISION POR VENTA
  ---  
  --- IMPORTE BASE EN TELEVENTAS CON ATRIBUTO TVT_IPS_VIRGIN="S":
  ---   SI OPERACION ES ALTA (CONCEPTO ORIGEN NO ES NULO O DE LOGITUD)
  ---
  ---=============================================================================================================


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.VENTAS_TELEVENTAS` AS
    SELECT a.*,
      CASE WHEN tvt_ups_virgin = 'S' 
                AND concepto_origen_ds IS NOT NULL 
                --- PARCHE V1
                --- AÑADIDO  
                AND NOT LENGTH(TRIM(concepto_origen_ds)) <2 
                --- FIN PARCHE V1
                THEN 
                    CASE WHEN b.importe_base - ifnull(c.importe_base, 0) > 0 THEN 15
                         WHEN b.importe_base - ifnull(c.importe_base, 0) < 0 THEN -15
                         ELSE  0  
                    END
                ELSE b.importe_base - ifnull(c.importe_base,0) END importe
    FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO` B
    ON UPPER(a.marca_ds) = UPPER(b.marca_ds) AND UPPER(a.MARCO_RETRIBUTIVO) = UPPER(b.marco_retributivo_ds) AND UPPER(a.concepto_ds) = UPPER(b.concepto_ds)
    LEFT JOIN `mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO` C
    ON UPPER(a.marca_ds) = UPPER(c.marca_ds) AND UPPER(a.MARCO_RETRIBUTIVO) = UPPER(c.marco_retributivo_ds) AND UPPER(a.concepto_origen_ds) = UPPER(c.concepto_ds);

  END