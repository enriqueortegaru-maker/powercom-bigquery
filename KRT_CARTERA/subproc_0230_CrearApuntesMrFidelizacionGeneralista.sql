BEGIN

  --- Se generan dos apuntes por servicio
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_FIDELIZACION_GENERALISTA`AS
  select * except(tipo_servicio, es_venta_mes_n,es_activacion_mes_n,importe_retribuible_triplet,activaciones_triplet_paso4,	activaciones_dupla_paso5,	importe), 
  999 as clave_mr, 
  'MR Fidelizacion G' as MARCO_RETRIBUTIVO, 
  'N' as tvt_ups_virgin, 
  'N' as televenta,
  comision_por_venta as importe,
  1 as nivel,
  comision_por_venta as importe_nivel,
  0 as bono_comercial,
  0 as bono_calidad
  from 	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` 
  where comision_por_venta>0
  UNION ALL (
  with p as (
    select *  except(tipo_servicio, es_venta_mes_n,es_activacion_mes_n,importe_retribuible_triplet,activaciones_triplet_paso4,	activaciones_dupla_paso5,	importe) 
    from 	`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_FIDELIZACION_GENERALISTA` 

  )
  select * 
  replace('Reparto de horas'as TipoMovimiento, "D - Extra" as concepto_ds) ,
  --replace("D - Extra" as concepto_ds), 
  999 as clave_mr, 
  'MR Fidelizacion G' as MARCO_RETRIBUTIVO, 
  'N' as tvt_ups_virgin, 
  'N' as televenta,
  comision_por_venta as importe,
  1 as nivel,
  comision_por_venta as importe_nivel,
  0 as bono_comercial,
  0 as bono_calidad
  from p
    where coste_por_venta >0);

END