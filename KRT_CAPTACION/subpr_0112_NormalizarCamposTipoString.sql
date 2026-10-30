BEGIN


  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET marca_ds=TRIM(marca_ds) where marca_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET detalle_servicio_ds=TRIM(detalle_servicio_ds) where detalle_servicio_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET CONCEPTO_DS=TRIM(CONCEPTO_DS) where CONCEPTO_DS is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET canal_alta_ds=TRIM(canal_alta_ds) where canal_alta_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET subcanal_ds=TRIM(subcanal_ds) where subcanal_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET tipo_canal_alta_ds=TRIM(tipo_canal_alta_ds) where tipo_canal_alta_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET nombre_distribuidor_alta_ds=TRIM(nombre_distribuidor_alta_ds) where nombre_distribuidor_alta_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET agente_alta_id=TRIM(agente_alta_id) where agente_alta_id is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET agente_creador_id=TRIM(agente_creador_id) where agente_creador_id is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET categoria_servicio_ds=TRIM(categoria_servicio_ds) where categoria_servicio_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET cif_nif=TRIM(cif_nif) where cif_nif is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET segmento_ds=TRIM(segmento_ds) where segmento_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET subsegmento_ds=TRIM(subsegmento_ds) where subsegmento_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET marca_cartera_ds=TRIM(marca_cartera_ds) where marca_cartera_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET equipo_ds=TRIM(equipo_ds) where equipo_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET territorio_ds=TRIM(territorio_ds) where territorio_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET tecnologia_detalle_ds=TRIM(tecnologia_detalle_ds) where tecnologia_detalle_ds is not null;
  UPDATE `mm-commissions-reporting.KRT_CAPTACION.SERVICIOS_CAPTACION` SET expediente_id=TRIM(expediente_id) where expediente_id is not null;

END