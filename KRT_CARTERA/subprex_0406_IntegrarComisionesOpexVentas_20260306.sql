BEGIN

	--- Inserto los apuntes en la tabla de comisiones
  --DECLARE VDESDE INT64;SET VDESDE=20260201;

    IF (select count(marca) from  `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` where coalesce(importe,0)>0 and desde=vdesde ) > 0 then 

      insert `mm-commissions-reporting.KRT_CARTERA.COMISIONES` (marca_ds, canal, subcanal, nombre_distribuidor, ClaseProducto, TipoProducto, NombreProducto, concepto_ds, clase_mm,desc_mm, orden_sap, mes_comision_id, importe, importe_nivel, total)
      --DECLARE VDESDE INT64;SET VDESDE=20260201;
      select c.marca, c.canal, c.subcanal, c.distribuidor, c.categoria_servicio, top.ClaseProducto, top.NombreProducto, c.concepto,
      `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisionesv1`(c.desc_mm),
      c.desc_mm, c.orden, 
      CAST(VDESDE/100 AS INT64) as mes_comision_id,
      c.importe, c.importe, c.importe
      from `mm-commissions-reporting.KRT_SAP.PARAM_COMISIONxCANAL_NO_VENTAS` c
      LEFT JOIN (
        --- Descubro catalogo de servicio predominante para asignar la comision a ese catalogo y posteriormente poder generar el concepto SAP  
        SELECT 
          marca_ds,
          ClaseProducto,
          TipoProducto, 
          NombreProducto
        FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
        GROUP BY 
          marca_ds, 
          ClaseProducto,
          TipoProducto, 
          NombreProducto
        QUALIFY ROW_NUMBER() OVER (PARTITION BY marca_ds, ClaseProducto, TipoProducto ORDER BY SUM(importe) DESC) = 1

      ) top ON c.marca = top.marca_ds  AND c.categoria_servicio = top.TipoPRoducto    
      where contains_Substr(tipo, "CARTERA")
      and c.desde=VDESDE;
    End If;

END