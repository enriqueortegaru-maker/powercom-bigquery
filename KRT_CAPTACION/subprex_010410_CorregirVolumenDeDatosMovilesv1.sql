BEGIN


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_010410_VENTAS_CAPTACION_UPD` AS
  with v as (
      select distinct marca_ds, cliente_id, servicio_id, catalogo_id, detalle_servicio_ds
      from `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
      order by 1,2,3,4
  ), c as (
      SELECT distinct 
          marca_ds, 
          tariff_id_ct,
          tariff_ds, 
          gb_nuevo 
      FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_VOLUMEN_DATOS`
      WHERE TRIM(UPPER(actualizacion)) = "SI"
  ) select distinct v.marca_ds, v.cliente_id, v.servicio_id, v.catalogo_id, v.detalle_servicio_ds, c.gb_nuevo
    from v
    inner join c  on v.marca_ds=c.marca_ds and v.detalle_servicio_ds=c.tariff_ds;


  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  SET gb=CAST(gb_nuevo as float64)
  FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_010410_VENTAS_CAPTACION_UPD`c
  WHERE v.marca_ds=c.marca_ds 
  and v.cliente_id=c.cliente_id
  and v.servicio_id=c.servicio_id;
  --and v.detalle_servicio_ds=c.detale_Serviciotariff_ds ;


  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION` v
  SET v.concepto_ds= c.concepto_ds
  FROM  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CATALOGOS` c
  WHERE  c.marca_ds=v.marca_ds 
  and c.categoria_servicio_ds=v.categoria_servicio_ds
  and c.tecnologia_detalle_ds=v.tecnologia_detalle_ds
  and v.categoria_servicio_ds='MOVILES POSTPAGO' 
  and c.tecnologia_detalle_ds='MOVIL' 
  and c.tipo_identificacion_ds='BLOQUE'
  and v.gb between  c.valor_minimo and c.valor_maximo
  ---CONTINGENCIA
  and v.gb!=0;
  ---FIN CONTINGENCIA 

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_010410_VENTAS_CAPTACION` AS
  SELECT * 
  FROM `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`;

END