BEGIN 


UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
SET 
  v.tipo_canal_alta_ds = mc.canal_agrupado2_ds,
  v.canal_alta_ds = mc.canal_agrupado1_ds, 
  v.subcanal_ds = mc.subcanal_ds, 
  -- PARCHE TRAS ACTUALIZACION EN MAESTRO_CANAL
  --v.nombre_distribuidor_alta_ds = mc.distribuidor.nombre, 
  v.nombre_distribuidor_alta_ds = mc.distribuidor.ds, 
  v.equipo_ds = mc.equipo_ds
FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` p
INNER JOIN `mm-commissions-reporting.KRT_MIG_PWC.tr_t_30_maestro_canal` mc 
  ON mc.agente.id = p.swPedId 
  AND mc.equipo.Id = p.swChnlPartnerId
WHERE v.servicio_id = p.swINstProdId
  -- Filtros aplicados directamente sobre la tabla destino para podar particiones
  AND v.marca_ds = "TELECABLE"
  AND v.canal_alta_ds = "DESCONOCIDO"
  AND v.categoria_servicio_ds != "MOVILES POSTPAGO";

END