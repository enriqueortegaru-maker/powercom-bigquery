BEGIN

	--- Inserto los apuntes en la tabla de comisiones

  --DECLARE VDESDE INT64;SET VDESDE=20260201;

    IF (select count(marca) from  `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` where coalesce(importe,0)>0 and desde=vdesde ) > 0 then 
      insert `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` (marca_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,categoria_servicio_ds, detalle_servicio_ds,concepto_ds, clase_mm, desc_mm, orden_sap, mes_comision_id, importe, decomisionable, grid)
      --DECLARE VDESDE INT64;SET VDESDE=20260201;
      select c.marca, c.canal, c.subcanal, c.distribuidor,c.categoria_servicio,top.detalle_servicio_ds, c.concepto,
      `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_comisiones`(desc_mm) as clase_mm,
      c.desc_mm, c.orden, CAST(VDESDE/100 AS INT64) as mes_comision_id, c.importe, 'N', 666
      from `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` c
      LEFT JOIN (
        --- Descubro catalogo de servicio predominante para asignar la comision a ese catalogo y posteriormente poder generar el concepto SAP  
        SELECT 
          marca_ds, 
          categoria_servicio_ds, 
          detalle_servicio_ds
        FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
        GROUP BY 
          marca_ds, 
          categoria_servicio_ds, 
          detalle_servicio_ds
        QUALIFY ROW_NUMBER() OVER (PARTITION BY marca_ds, categoria_servicio_ds ORDER BY SUM(importe) DESC) = 1

      ) top
        ON c.marca = top.marca_ds 
        AND c.categoria_servicio = top.categoria_servicio_ds    
      where contains_Substr(tipo, "CAPTACION")
      and c.desde=VDESDE;

    End If;

END