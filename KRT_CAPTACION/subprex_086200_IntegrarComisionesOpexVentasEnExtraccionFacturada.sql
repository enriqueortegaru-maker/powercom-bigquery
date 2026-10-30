BEGIN

	--- Inserto los apuntes en la tabla de comisiones

  
  --DECLARE VDESDE, VFECHA_CALC_OR, VFECHA_CALC_DE INT64;SET VDESDE=20260201;SET VFECHA_CALC_OR=20260305;SET VFECHA_CALC_DE=20260304;

    IF (select count(marca) from  `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` where coalesce(importe,0)>0 and desde=vdesde ) > 0 then 
      insert `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` (fecha_calc_dt, marca_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,categoria_servicio_ds, detalle_servicio_ds,concepto_ds, clase_mm, desc_mm, orden_sap, mes_comision_id, importe, decomisionable, grid)
      --DECLARE VDESDE INT64;SET VDESDE=20260201;
      --DECLARE VDESDE, VFECHA_CALC_OR, VFECHA_CALC_DE INT64;SET VDESDE=20260201;SET VFECHA_CALC_OR=20260305;SET VFECHA_CALC_DE=20260304;
      select PARSE_DATE("%Y%m%d",CAST(vfecha_calc_de AS STRING)) as fecha_calc_dt, c.marca, c.canal, c.subcanal, c.distribuidor,c.categoria_servicio,top.detalle_servicio_ds, c.concepto,
      `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_comisiones`(desc_mm) as clase_mm,
      c.desc_mm, c.orden, CAST(VDESDE/100 AS INT64) as mes_comision_id, c.importe , 'N' as decomisionable, 666 as grid
      from `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` c
      LEFT JOIN (
        --- Descubro catalogo de servicio predominante para asignar la comision a ese catalogo y posteriormente poder generar el concepto SAP  
        SELECT 
          ag.marca_ds, 
          ag.categoria_servicio_ds, 
          ag.detalle_servicio_ds
        FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` ag
        INNER JOIN `mm-commissions-reporting.KRT_CARTERA.V_FLUJO_MESxVERSION` vr on vr.mes=parse_Date("%Y%m%d" ,cast(vdesde as string))    
        WHERE ag.desde=vdesde
        and ag.fecha_calc_dt=parse_Date("%Y%m%d" ,cast(vfecha_calc_or as string))
        and ag.version=vr.version
        GROUP BY 
          ag.marca_ds, 
          ag.categoria_servicio_ds, 
          ag.detalle_servicio_ds
        QUALIFY ROW_NUMBER() OVER (PARTITION BY ag.marca_ds, ag.categoria_servicio_ds ORDER BY SUM(ag.importe) DESC) = 1

      ) top
        ON c.marca = top.marca_ds 
        AND c.categoria_servicio = top.categoria_servicio_ds    
      where contains_Substr(tipo, "CAPTACION")
      and c.desde=VDESDE;

    End If;

END