BEGIN

    ------------------------------------------------------------------------------
    ---
    --- PASO 1 : CORRECTIVO EN BASE A DESCRIPCION DE CONCEPTO
    ---
    ---		APLICA AL COMISIONADO DEº
    ---			SOMO:	A - Servicio movil Postpago No Convergente (SOMO)
    ---					E - Clawback Servicio movil Postpago No Convergente (SOMO)
    ---			ALARMA	B - Alarma
    ---					PDTE DECOMISIONADO ALARMA 


		---- UNITARIOS
		UPDATE `mm-commissions-reporting.KRT_CAPTACION.UNITARIOS` c
		SET c.orden_sap=p.orden_sap  
		FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
		where c.marca_ds=p.marca_ds 
		and c.desc_mm=p.desc_mm 
		and case when p.segmento_ds="X" then true else c.segmento_ds=p.segmento_ds end;



		---- COMISIONES
		UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
		SET c.orden_sap=p.orden_sap  
		FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
		where c.marca_ds=p.marca_ds 
		and c.desc_mm=p.desc_mm 
		and case when p.segmento_ds="X" then true else c.segmento_ds=p.segmento_ds end;


		----- DECOMISIONES

		UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_6M` c
		SET c.orden_sap=p.orden_sap  
		FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
		where c.marca_ds=p.marca_ds 
		and c.desc_mm=p.desc_mm 
		and case when p.segmento_ds="X" then true else c.segmento_ds=p.segmento_ds end;


		UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_24M` c
		SET c.orden_sap=p.orden_sap  
		FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
		where c.marca_ds=p.marca_ds 
		and c.desc_mm=p.desc_mm 
		and case when p.segmento_ds="X" then true else c.segmento_ds=p.segmento_ds end;


		UPDATE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
		SET c.orden_sap=p.orden_sap  
		FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_ESTATICO_CORRECTIVO_ORDEN_SAP` p
		where c.marca_ds=p.marca_ds 
		and c.desc_mm=p.desc_mm 
		and case when p.segmento_ds="X" then true else c.segmento_ds=p.segmento_ds end;

END