BEGIN

    ------------------------------------------------------------------------------
    ---
    --- PASO 1 : CORRECTIVO EN BASE A DESCRIPCION DE CONCEPTO
    

	IF (select count(*) from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` where (tecnologia_detalle_ds is null or length(tecnologia_detalle_ds) <2)) >0 THEN
		UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
		SET tecnologia_detalle_ds ="ELECTRICIDAD"
		WHERE (tecnologia_detalle_ds is null or length(tecnologia_detalle_ds) <2)
		and (detalle_Servicio_ds in('ELECTRICIDAD','SVE') );


		UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
		SET tecnologia_detalle_ds ="GAS"
		WHERE (tecnologia_detalle_ds is null or length(tecnologia_detalle_ds) <2)
		and (detalle_Servicio_ds in('GAS','SVG') );


		UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`
		SET tecnologia_detalle_ds ="ELECTRICIDAD"
		WHERE (tecnologia_detalle_ds is null or length(tecnologia_detalle_ds) <2)
		and (contains_substr(concepto_ds,"energia") );
	END IF;


    --- PASO 2 : RESTO
    IF (select count(*) from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` where (tecnologia_detalle_ds is null or length(tecnologia_detalle_ds) <2)) >0 THEN


        UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
        SET c.tecnologia_detalle_ds =s.tecnologia_detalle_ds
        FROM ( 
          select distinct marca_ds, cliente_id, servicio_id, tecnologia_detalle_ds 
          from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`  
        ) s
        where s.marca_ds=c.marca_ds
        and s.cliente_id=c.cliente_id
        and s.servicio_id=c.servicio_id
        and (c.tecnologia_detalle_ds is null or length(c.tecnologia_detalle_ds) <2);

		END IF;

END