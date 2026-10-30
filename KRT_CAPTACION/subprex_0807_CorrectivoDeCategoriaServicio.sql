BEGIN

    --- PASO 1 : CORRECTIVO ENERGIA
    IF (select count(*) from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` where (categoria_servicio_ds is null or length(categoria_servicio_ds) <2)) >0 THEN
      UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
      SET categoria_servicio_ds ="ENERGIA"
      WHERE (categoria_servicio_ds is null or length(categoria_servicio_ds) <2)
      and (detalle_Servicio_ds in('ELECTRICIDAD','GAS','SVE','SVG') or contains_substr(concepto_ds,"energia") );
    END IF;


    --- PASO 2 : RESTO
    IF (select count(*) from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` where (categoria_servicio_ds is null or length(categoria_servicio_ds) <2)) >0 THEN

        UPDATE `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` c
        SET c.categoria_servicio_ds =s.categoria_servicio_ds
        FROM ( 
          select distinct marca_ds, cliente_id, servicio_id, categoria_servicio_ds 
          from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`  
        ) s
        where s.marca_ds=c.marca_ds
        and s.cliente_id=c.cliente_id
        and s.servicio_id=c.servicio_id
        and (c.categoria_servicio_ds is null or length(c.categoria_servicio_ds) <2)
        and exists (
            select 1
            from `mm-commissions-reporting.KRT_CAPTACION.V_FLUJO_MESxVERSION` v
            where PARSE_DATE("%Y-%m-%d",CAST(v.mes AS STRING))=DATE_TRUNC(c.fecha_Calc_dt, MONTH) and c.version=v.version
        );
    END IF;

END