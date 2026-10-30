BEGIN


	---------------------------------------------------------------
	---
	---		VENTAS_CAPTACION CONTEXTUAL
	---

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_CAPTACION_CTX` AS 
	select marca_ds,sistema_ds,segmento_ds,cliente_id,contrato_id,pedido_id,expediente_padre_id,expediente_id,flujo_provision_id,servicio_id,categoria_servicio_ds,detalle_servicio_ds,tecnologia_detalle_ds,catalogo_id,velocidad_mb,gb,canal_alta_ds,subcanal_ds,nombre_distribuidor_alta_ds,marca_cartera_ds,territorio_ds,fecha_venta_bruta_id,fecha_cancelacion_id,fecha_venta_neta_id,fecha_rfs_id,fecha_rfb_id,fecha_baja_id,estado_crm_ds,estado_hoy_ds,causa_baja
	from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS`
	where fecha_venta_bruta_id between CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval 1 month),month))  AS INT64)  AND CAST(FORMAT_DATE("%Y%m%d",date_sub(CURRENT_DATE(), interval 1 day)) AS INT64)
	and segmento_ds='PYME';


	/* rep_ventas_detail_krtv sólo contiene datos de canales residencial y soho 
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_CAPTACION_CTX_REP` AS 
	select *
	from `mm-datamart-kd.SERVICES.rep_ventas_detail_krtv`
	where fecha_venta_bruta_id between CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval 1 month),month))  AS INT64)  AND CAST(FORMAT_DATE("%Y%m%d",date_sub(CURRENT_DATE(), interval 1 day)) AS INT64)
	and segmento_ds='PYME'*/



	---------------------------------------------------------------
	---
	---		VENTAS_CAPTACION DATAMARTKD
	---


	/*
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_CAPTACION_KD_TELCO_EKTNET` AS 
	select brand_ds, data_source_ds, segmento_rep, segment_ds, channel_segment_ds, sub_segment_ds, SubSegmentoCanal2, customer_id, account_id, contract_id, order_type_ds, ped_bundle_id, order_id, Pedido_Id, bundle_type, order_status_ds, flujo_id, 
	osAccion, service_id, swProductType, swTipologiaProducto, sell_type, campaign, discounts, service_type_raw, service_type, sell_tariff_ds, technology_ds, line_type_ds, billing_type_ds, tariff_id, tariff_ds, osNombre, 
	superchannel_ds, master_channel_ds, channel_type_ds, channel_ds, subchannel_ds, swChnlPartnerId, mnpTipoDistribuidor, swType, swName, swVerticalFocus, seller_ds, swCreatedBy, terminal_model, service_status_ds,
	dateInstalled,cancellation_day_id, Orden_FechaCreacion, order_day_id, pedido_swDateCreated, Flujo_StartTime, done_day_id, DateInstalled, activation_date, deactivation_date, FechaDesinstalacion, 
	deactivation_reason_ds---, Motivo_cancelacion, Motivo_baja, ProdORigId, ProdDest
	from  `mm-datamart-kd.SERVICES.ventas_base_telco_ektnet`
	where CAST(FORMAT_DATE("%Y%m%d",dateInstalled) AS INT64) between CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval 1 month),month))  AS INT64)  AND CAST(FORMAT_DATE("%Y%m%d",date_sub(CURRENT_DATE(), interval 1 day)) AS INT64)
	and segmento_rep='PYME';
	*/

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_CAPTACION_KD_TELCO_EKTNET` AS 
	select brand_ds, data_source_ds, 
	--segmento_rep, 
	segment_ds, channel_segment_ds, sub_segment_ds, 
	--SubSegmentoCanal2, 
	customer_id, account_id, contract_id, order_type_ds, ped_bundle_id, order_id, 
	--Pedido_Id, 
	bundle_type, order_status_ds, 
	--flujo_id, 
	--order_id,
	--osAccion, 
	service_id, 
	--swProductType, 
	--swTipologiaProducto, 
	sell_type, campaign, 
	--discounts, 
	--service_type_raw, 
	service_type, sell_tariff_ds, technology_ds, line_type_ds, billing_type_ds, tariff_id, tariff_ds, 
	--osNombre, 
	superchannel_ds, master_channel_ds, channel_type_ds, channel_ds, subchannel_ds, 
	--swChnlPartnerId, mnpTipoDistribuidor, swType, swName, swVerticalFocus, 
	seller, 
	--swCreatedBy, 
	terminal_model, service_status_ds,
	--dateInstalled,
	--cancellation_day_id, 
	cancellation_date,
	--Orden_FechaCreacion, 
	--order_day_id, 
	order_fix_id, 
	--pedido_swDateCreated, 
	--Flujo_StartTime, 
	--done_day_id, 
	done_date, 
	dateInstalled, activation_date, deactivation_date, 
	--FechaDesinstalacion, 
	deactivation_reason_ds---, Motivo_cancelacion, Motivo_baja, ProdORigId, ProdDest
	from  `mm-datamart-kd.SERVICES.ventas_base_telco_ektnet`
	where CAST(FORMAT_DATE("%Y%m%d",dateInstalled) AS INT64) between CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval 1 month),month))  AS INT64)  AND CAST(FORMAT_DATE("%Y%m%d",date_sub(CURRENT_DATE(), interval 1 day)) AS INT64)
--	and segmento_rep='PYME';
  and sub_segment_ds='PYME';



/*
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_CAPTACION_KD_TELCO_EKTNET` AS 
	select brand_ds, data_source_ds,  segment_ds, sub_segment_ds, channel_segment_ds, 
	--*sub_segment_ds, SubSegmentoCanal2, 
	customer_id, account_id, contract_id, order_type_ds, order_id, bundle_type, order_status_ds, 
	 service_id, sell_type, campaign, service_type, sell_tariff_ds, technology_ds, line_type_ds, billing_type_ds, tariff_id, tariff_ds, 
	superchannel_ds, master_channel_ds, channel_type_ds, channel_ds, subchannel_ds,  seller, terminal_model, service_status_ds,
	cancellation_date, order_day_ds,  done_date, DateInstalled, activation_date, deactivation_date
	deactivation_reason_ds---, Motivo_cancelacion, Motivo_baja, ProdORigId, ProdDest
	from  `mm-datamart-kd.SERVICES.ventas_base_telco_ektnet`
	where CAST(FORMAT_DATE("%Y%m%d",dateInstalled) AS INT64) between CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval 5 month),month))  AS INT64)  AND CAST(FORMAT_DATE("%Y%m%d",date_sub(CURRENT_DATE(), interval 1 day)) AS INT64)
	and sub_segment_ds='PYME';

*/


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_CAPTACION_KD_TELCO_EKTNET` AS 
	select brand_ds, data_source_ds,  segment_ds, sub_segment_ds, channel_segment_ds, /*sub_segment_ds, SubSegmentoCanal2,*/ customer_id, account_id, contract_id, order_type_ds, 
	--order_id, 
	bundle_type, order_status_ds, 
	service_id, sell_type, campaign, service_type, sell_tariff_ds, technology_ds, line_type_ds, billing_type_ds, tariff_id, tariff_ds, 
	superchannel_ds, master_channel_ds, channel_type_ds, channel_ds, subchannel_ds,  seller, terminal_model, service_status_ds,
	cancellation_date, order_date,  done_date, DateInstalled, activation_date, deactivation_date
	deactivation_reason_ds---, Motivo_cancelacion, Motivo_baja, ProdORigId, ProdDest
	from  `mm-datamart-kd.SERVICES.ventas_base_telco_ektnet`
	where CAST(FORMAT_DATE("%Y%m%d",dateInstalled) AS INT64) between CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval 5 month),month))  AS INT64)  AND CAST(FORMAT_DATE("%Y%m%d",date_sub(CURRENT_DATE(), interval 1 day)) AS INT64)
	and sub_segment_ds='PYME';



/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/*                                                                                                                                */
/*                                                                                                                                */
/*    PRODUCTOS_EKTNET                                                                                                            */
/*                                                                                                                                */
/*                                                                                                                                */
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/


	---------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------
	---
	---		PASO 1: CREACIÓN DE ENTIDADES
	---



		---  PASO 1.1: CREACION DE  BUZONES_EKTNET

				---IMPORTANTE
				--- UN BUZON SE CONSIDERA DE CAPTACION SI VIENE PRECEDIDO POR UN BUZON DE TRAMITACION Y MARCA DE CHECK
				---		bMarcaCheck: Buzon de asesoria preventa precedido por un buzon de tramitación de tipo marca check -> Cambiar a bMarcaCheck
				---	ADICIONALEMTE LOS BUZONES DE CAPTACION SE PUEDEN CLASIFICAR EN
				---		bClienteCaptado: 
				---				Check que informa si el buzon es de un ya cliente (soho en muchos casos) 
				---					0 cliente inactivo o somo en el momento de creación del buzón, 
				---					1 si cliente tenía acceso fijo en momento de creación de buzón (identificación en base a tramo de cliente)
				---		bMarcaCheck: 
				---				Check que informa si el buzon de asesoría preventa es precedido de un buzón de swClasificacion Solicitud, swTipoRec Tramitacion y swTipoSol  Marcar Check
				---					0 buzón de asesoría preventa no es precedido por buzón de solicitud de tramitación de marcar check
				---					1 buzón de asesoría preventa no es precedido por buzón de solicitud de tramitación de marcar check
				--- 	bBuzonSohoPrevio: 
				---				Check que informa si el buzon contiene productos con fecha previa a la creación del buzón, y por tanto se corresponde con un buzon de un cliente captacion que era previamente SOHO, y que productos previos a la captación, que se van a migrar
				---					0 Buzon no contiene productos con fecha previa a fecha de creación de buzón
				---					1 Buzon contiene productos con fecha previa a fecha de creación de buzón		
				--- 	bPrSohoPrevio:Check que marca los productos del buzón que van a ser migrados durante el proceso de captación. s decir, son los productos contenidos en el buzón y con fecha de creación previa al instanciado del buzón.
				---					0 Producto creado con posterioridad a la fecha de creación del buzón
				---					1 Producto creado con anterioridad a la fecha de creación del buzón



		--- OUT 1.1: LOG_0101_BUZONES_DESCUBIERTOS: Buzones Descubiertos: Población completa de buzones creados en 2023 por clientes de segmentos distintos a residencial -> 180049

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS` AS 
			select lb.*,
			cl.swNIE,
			CONCAT(CAST(cl.swNIE as STRING),'_',CAST(lb.swCustomerId as STRING),'_',CAST(coalesce(lb.swAgreementId,0) as STRING)) as grbuzid,
			ROW_NUMBER() OVER(PARTITION BY lb.swCustomerId, lb.swAgreementId order  by lb.swCustomerId, lb.swAgreementId,lb.swBuzonId ) as grbuzid_ind,				
			case when tra.clasificacion_ds="INACTIVO" or tra.clasificacion_ds="SOMO" then 1 else 0 end as bClienteCaptado,
			clc.swMarcaCartera, 
			cl.swDelegExt,
			clc.swSegPostVenta, cl.swSegmento, cl.swSegmento2, cl.swSubSegmentoMkt,
			cl.swCodigoAsociado, cl.swCanal,swDireccionEmail, 
			cl.swDireccionEmail as swDireccionEmail_Cl,
			clc.swTipoEvento, clc.swIdEvento, clc.swTipoComunicacion,
			---e.swFirstName, e.swLastName, e.swSegundoApellido,
			---e.swLogin,e.swDepartment,e.swTipoProy, swNivel,
			EXTRACT(DATE FROM lb.swDateCreated) as fecha_buzon_d, COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM lb.swDateCreated)) AS INT64),99991231) as fecha_buzon_id
			from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_buzon` lb
			left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` as tra 
			--ON tra.cliente_id = lb.swCustomerId AND tra.marca_ds = "EUSKALTEL" AND tra.desde_id <= CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM lb.swDateCreated)) AS INT64) AND tra.hasta_id> CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM lb.swDateCreated)) AS INT64)			
			ON tra.cliente_id = lb.swCustomerId AND tra.marca_ds = "EUSKALTEL" AND tra.desde_id < CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM lb.swDateCreated)) AS INT64) AND tra.hasta_id>= CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM lb.swDateCreated)) AS INT64) 
			left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swCustomerId=lb.swCustomerId		
			left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caract_cliente`clc on clc.swCustomerId=lb.swCustomerId
			---left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_employee_vw` e on e.swSalutation=cl.swCodigoAsociado
			where CAST(FORMAT_DATE("%Y%m%d",lb.swDateCreated) AS INT64) >=20230101
			and not contains_substr(cl.swSegmento,'Residencial');


		---  OUT 1.1: LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS: Buzones creados por los clientes que han creado un buzon de auditoria en 2023: Población completa de buzones creados por clientes que han creado un buzón de auditoria en 2023 -> 3557			
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS` AS 
			/*select lb.*,cl.swNIE, 
			EXTRACT(DATE FROM lb.swDateCreated) as fecha_buzon_d, COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM lb.swDateCreated)) AS INT64),99991231) as fecha_buzon_id
			from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_buzon` lb
			left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swCustomerId=lb.swCustomerId*/
			select * from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS` lb
			where exists (
				select 1 
				from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_buzon` btr
				/*where contains_substr(swTipoRec,"asesor") and contains_substr(swTipoRec,"preventa")*/
				where contains_substr(swTipoSol,"auditor")
				and btr.swCustomerId=lb.swCustomerId
				and CAST(FORMAT_DATE("%Y%m%d",btr.swDateCreated) AS INT64) >=20230101
			) and CAST(FORMAT_DATE("%Y%m%d",lb.swDateCreated) AS INT64) >=20230101
			order by lb.swCustomerId desc, lb.swBuzonId asc;



		--- OUT 1.1: LOG_0101_BUZONES_AUDITORIA_DESCUBIERTOS_Y_PRECEDIDOS_POR_MARCA_CHECK: Población de buzones de tipo asesoría preventa, creados en 2023, y precedidos por un buzón de tipo marca check -> 261
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_AUDITORIA_DESCUBIERTOS_Y_PRECEDIDOS_POR_MARCA_CHECK` AS 
			select a.swCustomerId, a.swnie , a.swBuzonId, a.swDateCreated,  t.swBuzonId as swBuzonId_t, t.swDateCreated as swDateCreated_t,  DATE_DIFF(EXTRACT(DATE FROM a.swDateCreated), EXTRACT(DATE FROM t.swDateCreated) ,DAY) as NDAYS
			from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS` a
			inner join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS` t on t.swCustomerId=a.swCustomerId 
			and contains_substr(a.swTipoRec,"asesor") and contains_substr(a.swTipoRec,"preventa") and contains_substr(a.swTipoSol,"audit") 
			and contains_substr(t.swTipoRec, "tramit") and contains_substr(t.swTipoSol, "marca")  and contains_substr(t.swTipoSol, "check");


		--- OUT 1.1: LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS: Buzones creados por clientes que han creado un buzon de auditoria en 2023, enriquecida con una variable booleana que informa si el cliente ha creado un buzon marca check previo  -> 3557
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS` AS
			Select distinct b.*, case when Coalesce(c.swBuzonId,-666)>-666  then 1 else 0 end as bMarcaCheck  
			from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS` b
			left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_AUDITORIA_DESCUBIERTOS_Y_PRECEDIDOS_POR_MARCA_CHECK` c
			on b.swBuzonId=c.swBuzonId and b.swCustomerId=c.swCustomerId;



		-------------------------------------------------------------------------------------------------------
		----
		----	NUEVAS TABLAS 
		----
		


		--- OUT 1.1: LOG_0101_BUZONES_DESCUBIERTOS_Y_PRECEDIDOS_POR_MARCA_CHECK: Población de buzones creados en 2023 por clientes de segmentos distintos a residencial, precedidos por de un buzón de tipo marca check -> 1925
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS_Y_PRECEDIDOS_POR_MARCA_CHECK` AS 
			select distinct a.swCustomerId, a.swnie , a.swBuzonId, a.swDateCreated,  t.swBuzonId as swBuzonId_t, t.swDateCreated as swDateCreated_t,  DATE_DIFF(EXTRACT(DATE FROM a.swDateCreated), EXTRACT(DATE FROM t.swDateCreated) ,DAY) as NDAYS
			from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS` a
			inner join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS` t on t.swCustomerId=a.swCustomerId 
			and contains_substr(t.swTipoRec, "tramit") and contains_substr(t.swTipoSol, "marca")  and contains_substr(t.swTipoSol, "check")
			and a.swBuzonId!=t.swBuzonId 
			and a.swDateCreated >= t.swDateCreated;
			
			

		--- OUT 1.1: LOG_0101_BUZONES_DESCUBIERTOS_Y_CANDIDATOS_CAPTACION:Población de buzones descubiertos en 2023 por clientes de segmentos distintos a residencial, asociados a canal y que cumplen criterios de tipificación asociados a buzones que pueden formar parte de procsos de captación: 46895
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS_Y_CANDIDATOS_CAPTACION` AS 		
			with lb as (
				select distinct * from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS` lb
				where (contains_substr(lb.swClasificacion,"solicitud") or contains_substr(lb.swClasificacion,"provisi"))
							and  (contains_substr(lb.swTipoRec,"modifica") or contains_substr(lb.swTipoRec,"prevent") or contains_substr(lb.swTipoRec,"fuera de conf") or contains_substr(lb.swTipoRec,"acci") or contains_substr(lb.swTipoRec,"solicit")) 
			)	select distinct lb.*, case when Coalesce(c.swBuzonId,-666)>-666  then 1 else 0 end as bMarcaCheck 
			from  lb
			left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS_Y_PRECEDIDOS_POR_MARCA_CHECK` c on c.swBuzonId=lb.swBuzonId and c.swCustomerId=lb.swCustomerId;
			

			
		----
		----	FIN NUEVAS TABLAS 
		----
		-------------------------------------------------------------------------------------------------------			



			--- PASO 1.1.1: RECREO CANALES NO INFORMADOS

			--- OUT 1.1.1: LOG_0101_BUZONES_CANAL_RECREADO:  Buzones creados por clientes que han creado al menos un buzon de auditoria en 2023, enriquecido con datos de canal de distribución
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CANAL_RECREADO` AS
				SELECT distinct *, max(coalesce(swChnlParternId,0)) over(partition by swCustomerId order by swBuzonId)  as canalRec
				---IMPORTANTE: EN FUNCION DE TABLA SELECCIONADA DETERMINO LA POBLACION DE BUZONES QUE COMPONE LA TABLA BUZONES_EKTNET
				--- SOLO CONSIDERO BUZONES DE AUDITORIA PREVENTA
				--from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CLIENTES_AUDITORIA_DESCUBIERTOS`
				--- CONSIDERO TODO TIPO DE BUZONES -> CUIDADO PORQUE AL APLICAR ESTA CONDICION SE REDUCEN SIGNIFICATIVAMENTE LOS BUZONES
				from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_DESCUBIERTOS_Y_CANDIDATOS_CAPTACION`
				order by swCustomerId desc, swBuzonId asc;

				UPDATE  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CANAL_RECREADO` SET swChnlParternId=canalRec where swChnlParternId is null;
				--UPDATE  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CANAL_RECREADO` SET swChnlParternId=CAST(NULL AS INT64) where swChnlParternId=0;

				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CANAL_RECREADO` AS 
				SELECT * except(canalRec) from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CANAL_RECREADO`;



			--- PASO 1.1.2: ENRIQUEZCO BUZONES CON CANALES Y DATOS ADICIONALES DE CANAL Y CLIENTE 
			--- OUT 1.1.2: BUZONES_EKTNET: Buzones creados por clientes que han creado al menos un buzon de auditoria en 2023, enriquecido con datos de canal de distribución y datos de cliente 

				/*select buz.swBuzonId, tra.clasificacion_ds, tra.desde_id,  tra.hasta_id, buz.swDateCreated, case when tra.clasificacion_ds="INACTIVO" or tra.clasificacion_ds="SOMO" then 0 else 1 end as bClienteCaptado, 
				--DATE_DIFF(parse_date ('%Y%m%d', CAST (tra.hasta_id  AS string)),EXTRACT(DATE FROM buz.swDateCreated), DAY ) as NDayRfb_Audit 
				from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CANAL_RECREADO` buz
				left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` as tra 
				ON tra.cliente_id = buz.swCustomerId AND tra.marca_ds = "EUSKALTEL" AND tra.desde_id <= CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM buz.swDateCreated)) AS INT64) AND tra.hasta_id> CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM buz.swDateCreated)) AS INT64);
	*/

				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` AS 
				select distinct buz.* except(swAgreementId, osFlujoProvId), buz.swAgreementId as swAgreementId_buz, 
				CASE m.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' END mmMarcaDesc,
				/*cl.swNIE,*/ cli.cif_nif, /*cl.swSegmento,*/ cli.subsegmento_ds,
				ca.swCOInterno, 
				c1.canal_agrupado1_ds, 
				c2.canal_agrupado2_ds, 
				sc.subcanal_ds, ca.swVerticalFocus, ca.swChnlPartnerId, ca.swName,
				case when osFlujoProvId is null then 0 else 1 end as bFlujo,
				osFlujoProvId
				--case when tra.clasificacion_ds="INACTIVO" or tra.clasificacion_ds="SOMO" then 1 else 0 end as bClienteCaptado,
				from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_CANAL_RECREADO` buz
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl  ON cl.swCustomerId=buz.swCustomerId
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_mm_marcas` m  ON m.mmMarcaId = cl.mmMarcaId
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D50_EDW_INFO_PERSONAL.edw_50_cliente_info` cli ON cli.marca_ds=CASE m.mmMarcaDesc WHEN 'Euskaltel' THEN 'EUSKALTEL' WHEN 'Virgin Telco' THEN 'VIRGIN' WHEN 'RACCTEL+' THEN 'RACC' WHEN 'Telecable' THEN 'TELECABLE' END  AND cli.cliente_id=buz.swCustomerId
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_canal_asociado` ca  ON ca.swChnlPartnerId =buz.swChnlParternId
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_maestro_canal` c  ON c.canal_id = buz.swChnlParternId
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl1` c1  ON c.canal_agrupado1_id = c1.canal_agrupado1_id
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_canal_agrupado_nvl2` c2  ON c.canal_agrupado2_id = c2.canal_agrupado2_id
				LEFT JOIN `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subcanal` sc  ON c.subcanal_id = sc.subcanal_id
				--left join `dw-cloud-euskaltel-prod-283409.D50_EDW.edw_50_cliente_tramo_servicio_rfb` as tra ON tra.cliente_id = buz.swCustomerId AND tra.marca_ds = "EUSKALTEL" AND tra.desde_id <= CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM buz.swDateCreated)) AS INT64) AND tra.hasta_id> CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM buz.swDateCreated)) AS INT64) 
				order by buz.swCustomerId desc, buz.swBuzonId asc;

			--- OUT 1.1.2: BUZONES_EKTNET_AUDITORIA: Buzones de tipo Asesoría preventa y operacón Auditoría, creados en 2023, enriquecido con datos de canal de distribución y datos de cliente 
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET_AUDITORIA` AS 
				select * from  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` where contains_substr(swTipoSol, "Auditor");


			--- PASO 1.1.3: DESCUBRO LAS RELACIONES BUZONES DE AUDITORIA x FLUJOS 

				--- PASO 1.1.3.1: DESCUBRO FLUJOS NO ASOCIADOS INICIALMENTE A BUZON
				--- OUT 1.1.3.1: BUZONES_EKTNETxFLUJOS_NO_ASOCIADOS
					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS_NO_ASOCIADOS` AS 
					SELECT osBuzonAsociado, swCustomerId,osFlujoProvId, osFlujoProvCatId,swObjectType, swDateCreated, EXTRACT(DATE FROM swDateCreated) as fecha_flujo_d
					FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_os_flujo_prov` f
					where exists (
					  select 1
					  from  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` b
					  where f.osBuzonAsociado=b.swBuzonId and f.swCustomerId=b.swCustomerId
					)order by 1,2,3;


				--- PASO 1.1.3.2: CREO TABLA CON RELACIONES DE BUZONES Y FLUJOS NO ASOCIADOS INICIALMENTE A BUZON 
				--- OUT 1.1.3.2: BUZONES_EKTNETxFLUJOS_TMP
					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS_TMP` AS 
					select b.* except(osFlujoProvId), fxb.osFlujoProvId
					from `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` b
					inner join  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS_NO_ASOCIADOS` as fxb
					on b.swBuzonId=fxb.osBuzonAsociado and b.swCustomerId=fxb.swCustomerId
					order by b.swBuzonId, fxb.osFlujoProvId;

				--- PASO 1.1.3.3: INSERTO  RELACIONES DE BUZONES Y FLUJOS DESCUBIERTAS INICIALMENTE 
					INSERT INTO `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS_TMP`
					SELECT *
					from `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` b 
					where not exists(
						select 1
						from `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS_TMP`  fxb
						where b.swBuzonId=fxb.swBuzonId and b.swCustomerId=fxb.swCustomerId				
					);


					/*	
					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS`  as 
					select b.*, 
					case when b.osFlujoProvId is not null then ROW_NUMBER()  OVER(PARTITION BY b.swBuzonId, b.swCustomerId ORDER BY b.osFlujoProvId) END as flid, 
					count(distinct b.osFlujoProvId) OVER(PARTITION BY b.swBuzonId, b.swCustomerId)  as nflujos, 
					from `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS` b
					order by b.swBuzonId;
					*/

				--- PASO 1.1.3.4: ENRIQUEZCO LAS RELACIONES DE BUZONES Y FLUJOS, CON INDICADORES ADICIONALES
				--- OUT 1.1.3.4: BUZONES_EKTNETxFLUJOS			
					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS`  as 
					select distinct b.*, 
					case when b.osFlujoProvId is not null then ROW_NUMBER()  OVER(PARTITION BY b.swBuzonId, b.swCustomerId ORDER BY b.osFlujoProvId) END as flid, 
					count(distinct b.osFlujoProvId) OVER(PARTITION BY b.swBuzonId, b.swCustomerId)  as nflujos, 
					f.osFlujoProvCatId,f.swDateCreated as swDateCreated_fl, EXTRACT(DATE FROM f.swDateCreated) as fecha_flujo_d, f.osEstado,
					fc.osNombre, fc.osAccion,		
					from `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS_TMP` b
					LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_os_flujo_prov`f on f.osFlujoProvId=b.osFlujoProvId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_os_flujo_prov_cat` fc on fc.osFlujoProvCatId=f.osFlujoProvCatId		
					order by b.swBuzonId, b.osFlujoProvId;


				--- PASO 1.1.3.5: ACTUALIZO TABLA BUZONESxFLUJOS EN CASOS QUE BFLUJO=0 Y NF>0. ES DECIR QUE BUZON INICIAL NO TIENE INFORMADO FLUJO, PERO SI HAY FLUJOS ASOCIADOS AL BUZON*/
				--- OUT 1.1.3.5: LOG_0101_BUZONES_EKTNETxFLUJOS_CON_NFLUJOS_Y_NO_BFLUJO
					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_EKTNETxFLUJOS_CON_NFLUJOS_Y_NO_BFLUJO` AS 
					select distinct swBuzonId, bFlujo,nFlujos 
					from  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS` where bFlujo=0 and nFlujos>0;
					
					
					UPDATE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS` b
					SET bFlujo=1
					FROM  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0101_BUZONES_EKTNETxFLUJOS_CON_NFLUJOS_Y_NO_BFLUJO` u
					WHERE b.swBuzonId=u.swBuzonId;
					
					
					
					
					/*
							--- Nuevos 
							with fv as (
							  SELECT distinct swCustomerId, swBuzonId, osFlujoProvId, from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP`where osFlujoProvId is not null
							) select fn.*
							from `mm-commissions-reporting.KRT_CAP_PYME.FLUJOSxBUZONES_EKTNET` fn
							where not exists(
							  select 1 from fv
							  where fv.swBuzonId=fn.osBuzonAsociado and fv.swCustomerId=fn.swCustomerId
							) order by 1,2;


							--- Viejos no Nuevos 

							with fv as (
							  SELECT distinct swCustomerId, swBuzonId, osFlujoProvId, from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP`where osFlujoProvId is not null
							) select fv.*
							from fv
							where not exists(
							  select 1 from `mm-commissions-reporting.KRT_CAP_PYME.FLUJOSxBUZONES_EKTNET` fn
							  where fv.swBuzonId=fn.osBuzonAsociado and fv.swCustomerId=fn.swCustomerId
							) order by 1,2;
					*/



		--- PASO 1.2: CREACION DE TABLA PRODUCTOS_EKTNET
		
			--- La tabla PRODUCTOS_EKTNET registra la población completa de productos invocados por los distintos flujos de provisión asociados a los buzones objetos de análisis
			--- La jeraquía de relaciones contenida en esta tabla es CLIENTE -> BUZON -> FLUJO DE PROVISION -> PRODUCTO 
	
		
			
				/*REVISAR SI INTRODUCIR Pedido_Id*/
				/*PENDIENTE FIJAR RELACION ENTRE DESCUENTO Y SERVICIO DEL QUE DEPENDE: POSIBILIDAD MEDIANTE */
			--- OUT 1.2.1: PRODUCTOS_EKTNET_TMP
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` AS
			select distinct buz.*,  
			/*cl.swCondGnrales, 
			f.swGeoCod,f.osFlujoProvCatId,f.osProdVisible,f.swDateCreated as swDateCreated_fl, EXTRACT(DATE FROM f.swDateCreated) as fecha_flujo_d,
			fc.osNombre, fc.osAccion,*/			
			f.swGeoCod,f.osProdVisible,
			cl.swCondGnrales,			
			case when date_diff(buz.fecha_buzon_d, EXTRACT(DATE FROM p.swDateCreated),DAY) > 0 Then 1 else 0 end as bPrSohoPrevio,		
			/*AÑADIDO*/
			max(case when date_diff(buz.fecha_buzon_d, EXTRACT(DATE FROM p.swDateCreated),DAY) > 0 Then 1 else 0 end) over(Partition by  buz.swBuzonId, buz.swCustomerId,p.swAgreementId,buz.swAgreementId_buz ) as bBuzonSohoPrevio,
			/*FIN AÑADIDO*/			
			cat.swProdReleaseId, cat.swLineType, cat.swLineName, cat.swLineaNegocio, cat.swPhase, cat.swTracking,
			cat.swProductType,cat.swReleaseName,cat.swFacturable, 
			p.swAgreementId, p.swContratoFisicoId,f.swInstProdId, p.swMasterInstProdId, p.swProdOrigId, p.swParentInstProdId,

			p.swDateCreated as swDateCreated_pr, 
			EXTRACT(DATE FROM p.swDateCreated) as fecha_venta_d, COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM p.swDateCreated)) AS INT64),99991231) as fecha_venta_id, 
			p.swDateInstalled, EXTRACT(DATE FROM p.swDateInstalled) as fecha_rfb_d, COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM p.swDateInstalled)) AS INT64),99991231)as fecha_rfb_id,
			p.swFechaDesinstalacion, EXTRACT(DATE FROM p.swFechaDesinstalacion) as fecha_baja_d,  COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM p.swFechaDesinstalacion)) AS INT64),99991231)as fecha_baja_id,
			date_diff(EXTRACT(DATE FROM p.swFechaDesinstalacion),EXTRACT(DATE FROM p.swDateInstalled),DAY) as nDaysAct,
			/*AÑADIDO 2023-12-06 Tipificación de prAccion en función de accción de flujo y fechas de creación de producto y de creación de flujo*/
			case when contains_substr(buz.osAccion,"alta") then "Alta"
				 when contains_substr(buz.osAccion,"baja") then "Baja"
				 when contains_substr(buz.osAccion,"migrac") AND EXTRACT(DATE FROM p.swDateCreated) >= buz.fecha_flujo_d then "Alta"				 
				 when contains_substr(buz.osAccion,"migrac") AND  EXTRACT(DATE FROM p.swDateCreated) < buz.fecha_flujo_d then "Baja"
			END as prAccion,
			/*FIN AÑADIDO*/							
			p.swFechaInicioVirtual, p.swFechaFinVirtual, `mm-commissions-reporting.KRT_CAP_PYME.fmonths_between`(EXTRACT(DATE FROM p.swFechaFinVirtual), EXTRACT(DATE FROM p.swFechaInicioVirtual)) as nmeses,
			aa.swFechaAccion as finicioDesc, ad.swFechaAccion as ffinDesc,
			cp.gcpDuracionReal durComp, cp.gcpFechaInicioReal finiComp, cp.gcpFechaVencReal ffinComp, 
			--cpor.gcpDuracionReal  durCompOr, cpor.gcpFechaInicioReal  finiCompOr, cpor.gcpFechaVencReal ffinCompOr,
			case when swCaractName="Duracion" then cc.swCaractValor End as DurDescuento,
			case when swCaractName="Permanencia" then cc.swCaractValor End as PermDescuento, 
			case when swCaractName="Responsable" then cc.swCaractValor End as RespDescuento,
			case when swCaractName="Descuento" then cc.swCaractValor End as PctmDescuento,   

			cs.categoria_servicio_ds, cs.tipo_servicio_ds, cs.subtipo_servicio_ds, cs.detalle_Servicio_ds
			
			--from   `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` buz 
			from   `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS` buz 
			--AÑADIDO PARA ENRIQUECER CON DATO DE FLUJO ASOCIADO A BUZON
			LEFT JOIN  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_os_inst_product_flujo`f on f.osFlujoProvId=buz.osFlujoProvId
			LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_os_flujo_prov_cat` fc on fc.osFlujoProvCatId=f.osFlujoProvCatId
			--AÑADIDO PARA ENRIQUECER CON DATO DE PRODUCTOS ASOCIADOS A FLUJO DE PROVISION		
			LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat  ON cat.swProdReleaseId = f.swProdReleaseId
			LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p  ON p.swInstProdId = f.swInstProdId 

			--AÑADIDO PARA ENRIQUECER CON DATO DE MARCA CLIENTE DE CANAL DIRECTO
			LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl  ON cl.swCustomerId = p.swCustomerId
			
			--AÑADIDO PARA ENRIQUECER CON DATO DE  FIN PROMOCION
			LEFT join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto_accion` aa  on  aa.swInstProdId=f.swInstProdId and TRIM(UPPER(aa.swAccion))="ACTIVAR PRODUCTO"
			LEFT join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto_accion` ad  on  ad.swInstProdId=f.swInstProdId and TRIM(UPPER(ad.swAccion))="DESACTIVAR PRODUCTO"
			
			--AÑADIDO   PARA ENRIQUECER CON DATO DE  FIN COMPROMISO DE PERMANENCIA DE DESCUENTOS
			LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_compromiso` cp on cp.swInstProdId=f.swInstProdId 
			
			--AÑADIDO   PARA ENRIQUECER CON DATO DE  FIN COMPROMISO DE PERMANENCIA DE SERVICIOS
			--LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_compromiso` cpor on cpor.swInstProdIdOrigenCompr=f.swInstProdId
			
			--AÑADIDO  PARA ENRIQUECER DESCUENTOS CON DATOS DE CARACTERISTICAS
			LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc ON cc.swInstProdId= f.swInstProdId /*and cat.swProductType='Descuento'*/ and cc.swCaractName in ("Duracion", "Permanencia","Responsable","Descuento")
			
			--AÑADIDO  PARA ENRIQUECER CON DATOS DE TIPIFICACION DE SERVICIO
			left join `mm-commissions-reporting.KRT_CAPTACION.CATALOGOS_SERVICIOS_BASExMARCA` as cs on cs.catalogo_id=CAST(p.swProdReleaseId AS STRING) and cs.marca_ds="EUSKALTEL"
			---left join `dw-cloud-euskaltel-prod-283409.D20_TRANSLATOR.tr_k_30_catalogo_servicio`cs on cs.catalogo_id=p.swProdReleaseId
			---left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_tipo_servicio`ts on ts.tipo_servicio_id=cs.tipo_servicio_id
			---left join `dw-cloud-euskaltel-prod-283409.D70_DIMENSION.dim_subtipo_servicio`sts on sts.subtipo_servicio_id=cs.subtipo_servicio_id			
			
			order by buz.swCustomerId desc, buz.swBuzonId asc, f.swInstProdId;

			/* Nuevo campo calculado:
					prAccion:
						case when contains_substr(buz.osAccion,"alta") then "Alta"
							 when contains_substr(buz.osAccion,"alta") then "Baja"
							 when contains_substr(buz.osAccion,"migrac") AND  EXTRACT(DATE FROM p.swDateCreated) < swDateCreated_fl then "Baja"
							 when contains_substr(buz.osAccion,"migrac") AND EXTRACT(DATE FROM p.swDateCreated) >= swDateCreated_fl then "Alta"
						END as prAccion
					
					
			*/


		 /*	 20231205
		  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` AS	
			with p1 as (
			--- 64801
			  select distinct * except(DurDescuento,PermDescuento,RespDescuento,PctmDescuento)
			  --- 66122
			from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP`  
			), p2 as (
			--- 63565
			  select swBuzonId, swCustomerId,swAgreementId,swAgreementId_buz,swInstProdId, 
			  max(CAST(DurDescuento AS INT64)) as DurDescuento,
			  max(CAST(CAST(PermDescuento AS FLOAT64) AS INT64)) as PermDescuento,
			  max(CAST(PctmDescuento AS FLOAT64)) as PctmDescuento 
			  from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` 
			--where  swInstProdId=141229551
			  group by 1,2,3,4,5
			), p3 as (
			--- 3270
			  select swBuzonId, swCustomerId,swAgreementId,swAgreementId_buz,
			  max(bPrSohoPrevio) as bBuzonSohoPrevio
			  from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` 
			--where  swInstProdId=141229551
			  group by 1,2,3,4
			)
			--- 62689
			select distinct p1.*, p3.bBuzonSohoPrevio, p2.* except (swBuzonId, swCustomerId,swAgreementId,swAgreementId_buz,swInstProdId)
			from p1
			inner join p2 on p2.swBuzonId=p1.swBuzonId and p2.swCustomerId=p1.swCustomerId and p2.swAgreementId=p1.swAgreementId and coalesce(p2.swAgreementId_buz,1)=coalesce(p1.swAgreementId_buz,1) and p2.swInstProdId=p1.swInstProdId 
			inner join p3 on p3.swBuzonId=p1.swBuzonId and p3.swCustomerId=p1.swCustomerId and p3.swAgreementId=p1.swAgreementId and coalesce(p3.swAgreementId_buz,1)=coalesce(p3.swAgreementId_buz,1);			
		*/


			UPDATE `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` 
			SET DurDEscuento=replace(DurDescuento,"Prueba FTTH Internet 300M","" ) 
			WHERE contains_substr(DurDescuento,"Prueba FTTH Internet 300M");


			UPDATE `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` 
			SET PctmDescuento=replace(PctmDescuento,",","." ) 
			WHERE contains_substr(PctmDescuento,",");


			--- OUT 1.2.2: PRODUCTOS_EKTNET
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` AS	
			with p1 as (
			--- 64801
			  select distinct * except(DurDescuento,PermDescuento,RespDescuento,PctmDescuento)
			  --- 66122
				from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP`  
			), p2 as (
			--- 63565
			  select swBuzonId, swCustomerId,swAgreementId,swAgreementId_buz,swInstProdId, 
			  max(CAST(DurDescuento AS INT64)) as DurDescuento,
			  max(CAST(CAST(PermDescuento AS FLOAT64) AS INT64)) as PermDescuento,
			  max(CAST(PctmDescuento AS FLOAT64)) as PctmDescuento 
			  from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` 
			--where  swInstProdId=141229551
			  group by 1,2,3,4,5
			)/*, p3 as (
			--- 3270
			  select swBuzonId, swCustomerId,swAgreementId,swAgreementId_buz,
			  max(bPrSohoPrevio) as bBuzonSohoPrevio
			  from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` 
			--where  swInstProdId=141229551
			  group by 1,2,3,4
			)*/
			--- 62689
			select distinct p1.* , /*p3.bBuzonSohoPrevio,*/ p2.* except (swBuzonId, swCustomerId,swAgreementId,swAgreementId_buz,swInstProdId)
			from p1
			inner join p2 on p2.swBuzonId=p1.swBuzonId and p2.swCustomerId=p1.swCustomerId and p2.swAgreementId=p1.swAgreementId and coalesce(p2.swAgreementId_buz,1)=coalesce(p1.swAgreementId_buz,1) and p2.swInstProdId=p1.swInstProdId 
			/*inner join p3 on p3.swBuzonId=p1.swBuzonId and p3.swCustomerId=p1.swCustomerId and p3.swAgreementId=p1.swAgreementId and coalesce(p3.swAgreementId_buz,1)=coalesce(p3.swAgreementId_buz,1)*/;			




		--- PASO 1.3: CREACION DE TABLA RELACIONES BUZON->FLUJOS->PRODUCTOS_EKTNET
		
			--- La tabla PRODUCTOS_EKTNET registra la población completa de productos invocados por los distintos flujos de provisión asociados a los buzones objetos de análisis
			--- La jeraquía de relaciones contenida en esta tabla es CLIENTE -> BUZON -> FLUJO DE PROVISION -> PRODUCTO 
			---     Un cliente puede crear N buzones, pero un buzon sólo se relaciona con un cliente
			---		Un buzón puede relacionarse con N flujos de provisión, y un flujo de provisión puede relacionarse con 1 sólo buzón
			---		Un flujo de provisión se relaciona con N productos. Y 1 producto se puede relacionar con M flujos de provisión

			--- OUT 1.3: CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET
			--- La tabla BUZONESxFLUJOSxPRODUCTOS_EKTNET registra las relaciones instanciadas entr buzones, flujos y productos

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET`as
			select distinct  swCustomerId, swBuzonid,osFlujoProvId,osFlujoProvCatId,osNombre,osAccion, osEstado, swInstProdId, 
			case when contains_substr(osAccion,"alta") then "Alta"
				 when contains_substr(osAccion,"baja") then "Baja"
				 when contains_substr(osAccion,"migrac") AND fecha_venta_d >= fecha_flujo_d then "Alta"				 
				 when contains_substr(osAccion,"migrac") AND  fecha_venta_d < fecha_flujo_d then "Baja"
			END as prAccion,
			fecha_buzon_d, fecha_flujo_d, fecha_venta_d 
			from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
			order by 8 asc;



			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` as
			with bb as (
			  select distinct swCustomerId, swBuzonId
			  from `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET`
			  where prAccion="Baja"
			  order by 1,2
			), fb as (
			  select distinct swCustomerId, swBuzonId,osFlujoProvId
			  from `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET`
			  where prAccion="Baja"
			  order by 1,2,3
			)select distinct b.*, 
			case when coalesce(bb.swBuzonId,0)=b.swBuzonId then 1 else 0 end as bBuzonConBajas,
			case when coalesce(fb.osFlujoProvId,0)=b.osFlujoProvId then 1 else 0 end as bFlujoConBajas,      		
			from `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` b
			left join bb on bb.swCustomerId=b.swCustomerId and bb.swBuzonId=b.swBuzonId
			left join fb on fb.swCustomerId=b.swCustomerId and fb.swBuzonId=b.swBuzonId	and fb.osFlujoProvId=b.osFlujoProvId		
			--where b.swCustomerId=115
			order by 1,2,3,8;



		--- PASO 1.4: INTEGRO LA VARIABLE bBuzonConBajas EN TABLA BUZON_EKTNET
			--- OUT 1.4: LOG_0104_BUZONES_EKTNET_PREV
			--- OUT 1.4: BUZONES_EKTNET			

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0104_BUZONES_EKTNET_PREV` as SELECT * FROM  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET`;
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` AS 
			SELECT distinct b.*, bb.bBuzonConBajas 
			FROM `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` b
			LEFT JOIN `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` bb  on  bb.swCustomerId=b.swCustomerId and bb.swBuzonId=b.swBuzonId;
			


		--- PASO 1.5: INTEGRO LAS VARIABLES bBuzonConBajas y bFlujoConBajas EN TABLA BUZON_EKTNETxFLUJOS
			--- OUT 1.5: LOG_0105_BUZONES_EKTNETxFLUJOS_PREV
			--- OUT 1.5: BUZONES_EKTNETxFLUJOS			

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0105_BUZONES_EKTNETxFLUJOS_PREV` as SELECT * FROM  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS`;
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS` AS 
			SELECT distinct b.*, bb.bBuzonConBajas, bb.bFlujoConBajas  
			FROM `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS` b
			LEFT JOIN `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` bb  on  bb.swCustomerId=b.swCustomerId and bb.swBuzonId=b.swBuzonId and bb.osFlujoProvId=b.osFlujoProvId;
		

		--- PASO 1.6: INTEGRO LAS VARIABLES bBuzonConBajas y bFlujoConBajas EN TABLA PRODUCTOS_EKTNET

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0106_PRODUCTOS_EKTNET_TMP` AS SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP`; 
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` AS 
			SELECT distinct p.*, pb.bBuzonConBajas, pb.bFlujoConBajas  
			FROM `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET_TMP` p
			LEFT JOIN `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` pb  on  pb.swCustomerId=p.swCustomerId and pb.swBuzonId=p.swBuzonId and pb.osFlujoProvId=p.osFlujoProvId and pb.swInstProdId=p.swInstProdId;

  			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0106_PRODUCTOS_EKTNET` AS SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`;
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` AS 
			SELECT distinct p.*, pb.bBuzonConBajas, pb.bFlujoConBajas  
			FROM `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
			LEFT JOIN `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` pb  on  pb.swCustomerId=p.swCustomerId and pb.swBuzonId=p.swBuzonId and pb.osFlujoProvId=p.osFlujoProvId and pb.swInstProdId=p.swInstProdId;

			/*
			--- NUEVO

			UPDATE  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
			SET p.bBuzonConBajas= pb.bBuzonConBajas 
			FROM `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` pb 
			WHERE  pb.swCustomerId=p.swCustomerId 
			and pb.swBuzonId=p.swBuzonId 
			and pb.osFlujoProvId=p.osFlujoProvId 
			and pb.swInstProdId=p.swInstProdId
			and p.bBuzonConBajas!= pb.bBuzonConBajas;


			UPDATE  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
			SET p.bFlujoConBajas=pb.bFlujoConBajas  
			FROM `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` pb 
			WHERE  pb.swCustomerId=p.swCustomerId 
			and pb.swBuzonId=p.swBuzonId 
			and pb.osFlujoProvId=p.osFlujoProvId 
			and pb.swInstProdId=p.swInstProdId
			and p.bFlujoConBajas!=pb.bFlujoConBajas;

			--- FIN NUEVO
			*/

		--- PASO 1.7: DESCUBRIMIENTO DE DESCUENTOS CREADOS TRAS ACTIVACION DE PRODUCTOS 
			--- OUT 1.7: LOG_0404_DESCUENTOS_CREADOS_TRAS_BUZON

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0404_DESCUENTOS_CREADOS_TRAS_BUZON` AS
			with c as (
				--- Población de productos instanciados en buzones de clientes captados 	
				select distinct swBuzonid, swCustomerId,swInstProdId, swDateCreated_pr, swDateInstalled as swDateInstalled_pr from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` where /*bMarcaCheck=1 and*/ bClienteCaptado=1
			) select distinct  swBuzonId, cat.swProdReleaseId, cat.swLineType, cat.swLineName, cat.swLineaNegocio, cat.swPhase, cat.swTracking,
			cat.swProductType,cat.swReleaseName,cat.swFacturable, 
			p.swAgreementId, p.swContratoFisicoId,p.swInstProdId, p.swMasterInstProdId, p.swProdOrigId, p.swParentInstProdId,

			EXTRACT(DATE FROM c.swDateCreated_pr) as swDateCreated_pr,	
			EXTRACT(DATE FROM p.swDateCreated) as swDateCreated, EXTRACT(DATE FROM p.swDateCreated) as fecha_venta_d, COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM p.swDateCreated)) AS INT64),99991231) as fecha_venta_id, 
			EXTRACT(DATE FROM c.swDateInstalled_pr) as swDateInstalled_pr,
			EXTRACT(DATE FROM p.swDateInstalled) as swDateInstalled , EXTRACT(DATE FROM p.swDateInstalled) as fecha_rfb_d, COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM p.swDateInstalled)) AS INT64),99991231)as fecha_rfb_id,			
			EXTRACT(DATE FROM p.swFechaDesinstalacion) as swDateUnistalled, EXTRACT(DATE FROM p.swFechaDesinstalacion) as fecha_baja_d,  COALESCE(CAST(FORMAT_DATE("%Y%m%d",EXTRACT(DATE FROM p.swFechaDesinstalacion)) AS INT64),99991231)as fecha_baja_id,			
			case when p.swDateInstalled is null then 0 else 1 END as bDiscActivated,
			case when p.swDateInstalled is null and p.swFechaDesinstalacion is null then 1 else 0 END as DiscActivatedToday,			
			DATE_DIFF(EXTRACT(DATE FROM p.swFechaDesinstalacion),EXTRACT(DATE FROM p.swDateInstalled),DAY) as nDaysAct,										
			DATE_DIFF (EXTRACT(DATE FROM p.swDateCreated),EXTRACT(DATE FROM c.swDateCreated_pr),DAY) nDaysCreatePrDescPost_CreatePrFlujoBuzon,
			DATE_DIFF (EXTRACT(DATE FROM p.swDateInstalled),EXTRACT(DATE FROM c.swDateInstalled_pr),DAY) nDaysActivatePrDescPost_ActivatePrFlujoBuzon,	
			case when swCaractName="Duracion" then cc.swCaractValor End as DurDescuento,
			case when swCaractName="Permanencia" then cc.swCaractValor End as PermDescuento, 
			case when swCaractName="Responsable" then cc.swCaractValor End as RespDescuento,
			case when swCaractName="Descuento" then cc.swCaractValor End as PctmDescuento,   
			cs.categoria_servicio_ds, cs.tipo_servicio_ds, cs.subtipo_servicio_ds, cs.detalle_Servicio_ds						
			from `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p
			inner join c on c.swCustomerId=p.swCustomerId and not(c.swInstProdId=p.swInstProdId) 
			inner JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat  ON cat.swProdReleaseId = p.swProdReleaseId
			LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_caracteristica` cc ON cc.swInstProdId= p.swInstProdId /*and cat.swProductType='Descuento'*/ and cc.swCaractName in ("Duracion", "Permanencia","Responsable","Descuento")			
			left join `mm-commissions-reporting.KRT_CAPTACION.CATALOGOS_SERVICIOS_BASExMARCA` as cs on cs.catalogo_id=CAST(p.swProdReleaseId AS STRING) and cs.marca_ds="EUSKALTEL"			
			where DATE_DIFF (EXTRACT(DATE FROM p.swDateCreated),EXTRACT(DATE FROM c.swDateCreated_pr),DAY) >0
			and contains_substr(cat.swProductType ,"descu");



		
			--- select * from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0404_DESCUENTOS_CREADOS_TRAS_BUZON` where contains_substr(swReleaseName,'100') order by swBuzonId asc;
			--- select * from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0404_DESCUENTOS_CREADOS_TRAS_BUZON` where swBuzonId=21605999;
		





			/*  PASO 1.5: CREO VENTAS_EKTNET*/
			
			/*REVISAR DUPLICADO DE CAMPOS TRAS MODIFICACION TABLA PRODUCTOS_EKTNET*/
			/*
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_EKTNET` AS
			select b.*, s.fecha_venta_neta_id, s.fecha_rfb_id, s.estado_hoy_ds, s.segmento_ds, s.detalle_servicio_ds, s.agente_alta_id, s.agente_creador_id,s.categoria_servicio_ds,
			s.equipo_ds, s.territorio_ds, s.tecnologia_detalle_ds, s.portabilidad_in_lg,
			CASE WHEN s.categoria_servicio_ds = 'BANDA ANCHA' THEN s.velocidad_mb ELSE s.gb END gb,
			s.contrato_id, s.tipo_producto_pedido_re_ds, s.visibilidad_pedido_lg, s.tipo_pedido_ds, s.pedido_id,s.expediente_padre_id, s.expediente_id
			from `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s
			inner join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` b on b.mmMarcaDesc=s.marca_ds and b.swCustomerId=s.cliente_id and b.swInstProdId=s.servicio_id;
			*/

			--select * from `mm-commissions-reporting.KRT_CAP_PYME.SERVICIOS_CAPTACION_EKTNET` where canal_agrupado2_ds is not null; -> 1667 ->3907
			--select * from `mm-commissions-reporting.KRT_CAP_PYME.SERVICIOS_CAPTACION_EKTNET` where canal_agrupado2_ds is null; -> 2686 ->

			/*
			SELECT s.* except (swDescSol, swDescripcion, swObservaciones), 
			Replace(Replace(s.swDescSol,'\r','# '),'\n','#') as swDescSol, 
			Replace(Replace(s.swDescripcion,'\r','#'),'\n','#') as swDescripcion,  
			Replace(Replace(s.swObservaciones,'\r','#'),'\n','#') as swObservaciones,
			b.swChnlPartnerId as swChnlPartnerId_Or
			FROM `mm-commissions-reporting.KRT_CAP_PYME.VENTAS_EKTNET` s
			LEFT JOIN `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNET` b on b.swCustomerId=s.swCustomerId and b.swBuzonId=s.swBuzonId
			*/

		---
		---		FIN CREACIÓN DE ENTIDADES
		---
		---------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------------------------------------






/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/*                                                                                                                                */
/*                                                                                                                                */
/*    CALCULO DE FACTURACION											                                                          */  
/*                                                                                                                                */
/*                                                                                                                                */
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/**********************************************************************************************************************************/




	---------------------------------------------------------------
	---
	---	PASO 2: CALCULO DE OBJETOS FACTURABLES 
	---




		--------------------------------------------------------------------
		---
		---
		---		PASO 2.1: OBTENGO ARBOLES DE PRODUCTOS INSTANCIADOS
		---				RESULTADO: ARBOLES DE PRODUCTOS 	
		---				AUDITORIA: HAY 78 PRODUCTOS QUE NO SE DESCUBREN EN ARBOL. DETALLE OSACCION MUESTA 3 altas, 50 bajas y 25 migraciones. CONSIDERAR INCLUIR swContratoFisicoId, osNombrey osAccion para analizar detalles 	
		---		PASO 2.2: CRUZO CATALOOS DE DISTINTAS CLASES DE CATALOGOS FACTURABLES EN ARBOR, CON INSTANCIAS DE PRODUCTOS. 
		---				RESULTADO: DESCUBRO LAS INSTANCIAS DE PRODUCTOS FACTURABLES SEGUN ARBOR
		---		PASO 2.3: CRUZO LAS INSTANCIAS DE PRODUCTOS FACTURABLES SEGUN ARBOR, CON EL ARBOL DE PRODUCTOS INSTANCIADOS. 
		---				RESULTADO: DESCUBRO LOS PRODUCTOS A LOS QUE SE APLICA LA FACTURACION (ENTIENDO QUE PADRES EN CASO DE DESCUENTOS, CARGOS Y  BONOS, PERO HAY QUE REVISAR)
		---		PASO 2.4: GENERO OBJETOS FACTURABLES
		---					
		---				2.4.1. CUOTAS AlTA
		---				2.4.2. CUOTAS MENSUALES
		---				2.4.3	 BONOS
		---				2.4.4  TARIFAS
		---				2.4.5  DESCUENTOS OBJETIVO
		---				2.4.6  DESCUENTOS	RESTRICCIONES		
		---
		---		PASO 2.5: INTEGRO COMPONENTES
	
		--- PASO 2.1: CREO ARBOLES DE PRODUCTOS INSTANCIADOS QUE NO TIENEN PADRE
		---			RESULTADO: ARBOLES DE PRODUCTOS INSTANCIADOS QUE NO TIENEN PADRE
		---						3155 productos que no tienen padre
		---						17788 productos que forman parte de arboles de productos que no tienen padres	
		---			AUDITORIA: HAY 78 PRODUCTOS QUE NO SE DESCUBREN EN ARBOL. DETALLE OSACCION MUESTA 3 altas, 50 bajas y 25 migraciones. CONSIDERAR INCLUIR swContratoFisicoId, osNombrey osAccion para analizar detalles 			


		--- OUT 2.1: ARBOL_PRODUCTOS_EKTNET: CREACION DE ARBOLES DE PRODUCTOS INSTANCIADOS QUE NO TIENEN PADRES
				
			CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` AS	
			with recursive rec as (			
					SELECT p.swInstProdId as idreg,1 as lvl, 
					p.swTipoRec, p.swBuzonId, p.bMarcaCheck,p.bClienteCaptado, p.bBuzonSohoPrevio, p.bPrSohoPrevio, p.bBuzonConBajas,p.swCustomerId,p.swNIE,p.swAgreementId, p.swContratoFisicoId, p.swTipoProducto,p.swProductType, p.swInstProdId, p.swProdReleaseId,p.swReleaseName, p.swFacturable,p.swMasterInstProdId,p.swProdOrigId,
					p.fecha_venta_d,p.fecha_rfb_d,p.fecha_baja_d,p.fecha_venta_id,p.fecha_rfb_id,p.fecha_baja_id,p.nDaysAct, 
					p.swParentInstProdId, CAST(NULL as INT64) as swProdReleaseIdParent, CAST(NULL as STRING) as swReleaseNameParent, 
					p.swInstProdId as swInstProdIdRoot, p.swProdReleaseId as swProdReleaseIdRoot, p.swReleaseName as swReleaseNameRoot          
					from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
					where p.swParentInstProdId is NULL
					and p.swInstProdId is not null
					--and p.swTipoRec="Asesoría Preventa"
					union ALL
					select r.idreg, r.lvl+1 as lvl, 
					ph.swTipoRec, ph.swBuzonId,ph.bMarcaCheck, ph.bClienteCaptado, ph.bBuzonSohoPrevio, ph.bPrSohoPrevio, ph.bBuzonConBajas, ph.swCustomerId,ph.swNIE, ph.swAgreementId, ph.swContratoFisicoId, ph.swTipoProducto,ph.swProductType, ph.swInstProdId, ph.swProdReleaseId,ph.swReleaseName, ph.swFacturable,ph.swMasterInstProdId,ph.swProdOrigId,
					ph.fecha_venta_d,ph.fecha_rfb_d,ph.fecha_baja_d,ph.fecha_venta_id,ph.fecha_rfb_id,ph.fecha_baja_id,ph.nDaysAct,
					ph.swParentInstProdId,cat_padre.swProdReleaseId as swProdReleaseIdParent, cat_padre.swReleaseName as swReleaseNameParent, 
					r.swInstProdIdRoot, r.swProdReleaseIdRoot, r.swReleaseNameRoot 
					from rec r
					inner join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` ph on  ph.swParentInstProdId=r.swInstProdId and ph.swBuzonId=r.swBuzonId and ph.swTipoRec=r.swTipoRec
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` pr_padre on pr_padre.swInstProdId=ph.swParentInstProdId
					LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat_padre  ON cat_padre.swProdReleaseId = pr_Padre.swProdReleaseId
					where r.lvl<=10			
			)
			select distinct * 
			from rec
			order by 1 asc, 2 asc;

				
				/*
				with recursive rec as (			
					SELECT p.swInstProdId as idreg,1 as lvl, 
					p.swTipoRec, p.swBuzonId,p.swCustomerId,p.swAgreementId, p.swTipoProducto,p.swProductType, p.swProdReleaseId,p.swReleaseName, p.swFacturable, p.swInstProdId,p.swMasterInstProdId,p.swProdOrigId,p.swParentInstProdId, 
					p.swProdReleaseId as swProdReleaseIdRoot, p.swReleaseName as swReleaseNameRoot 
					from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
					where p.swParentInstProdId is NULL
					and p.swInstProdId is not null
					and p.swTipoRec="Asesoría Preventa"
					union ALL
					select r.idreg, r.lvl+1 as lvl, 
					ph.swTipoRec, ph.swBuzonId,ph.swCustomerId, ph.swAgreementId, ph.swTipoProducto,ph.swProductType, ph.swProdReleaseId,ph.swReleaseName, ph.swFacturable, ph.swInstProdId,ph.swMasterInstProdId,ph.swProdOrigId,ph.swParentInstProdId,
					r.swProdReleaseIdRoot, r.swReleaseNameRoot 
					from rec r
					inner join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` ph on  ph.swParentInstProdId=r.swInstProdId and ph.swBuzonId=r.swBuzonId and ph.swTipoRec=r.swTipoRec
					where lvl<=10			
				)
				select distinct * 
				from rec
				order by 1 asc, 2 asc;
				*/

				


		--- PASO 2.2: CRUZO CATALOOS DE DISTINTAS CLASES DE CATALOGOS FACTURABLES EN ARBOR, CON INSTANCIAS DE PRODUCTOS. 
		---			RESULTADO: DESCUBRO LAS INSTANCIAS DE PRODUCTOS FACTURABLES SEGUN ARBOR
		--- OUT 2.2: ARBORxPRODUCTOS_EKTNET: CREACION DE ARBOLES DE PRODUCTOS INSTANCIADOS QUE NO TIENEN PADRES
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxPRODUCTOS_EKTNET` AS 
				select distinct "CUOTAS_ALTA" as clase, p.swInstProdId, p.swFacturable
				from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS_ALTA` c
				on p.swProdReleaseId=c.swProdReleaseId 
				--where p.swTipoRec="Asesoría Preventa"
				UNION ALL 
				select distinct "CUOTAS" as clase, p.swInstProdId, p.swFacturable
				from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS` c
				on p.swProdReleaseId=c.swProdReleaseId
				--where p.swTipoRec="Asesoría Preventa"			
				UNION ALL 			
				select distinct "TARIFAS" as clase, p.swInstProdId, p.swFacturable
				from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_TARIFAS` c
				on p.swProdReleaseId=c.Id_Prod_CRM 
				--where p.swTipoRec="Asesoría Preventa"			
				UNION ALL 			
				select distinct "BONOS" as clase, p.swInstProdId, p.swFacturable
				from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_BONOS` c
				on p.swProdReleaseId=c.Id_Prod_CRM 	
				--where p.swTipoRec="Asesoría Preventa"
				UNION ALL 			
				select distinct "DESCUENTOS_CLIENTES_RESTRICCION" as clase, p.swInstProdId, p.swFacturable
				from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_RES` c
				on p.swProdReleaseId=c.Id_Prod_CRM 
				--where p.swTipoRec="Asesoría Preventa"
				UNION ALL 			
				select distinct "DESCUENTOS_CLIENTES_OBJETIVO" as clase, p.swInstProdId, p.swFacturable
				from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
				on p.swProdReleaseId=c.Id_Prod_CRM; 
				--where p.swTipoRec="Asesoría Preventa";
					
				
		--- PASO 2.3: CRUZO LAS INSTANCIAS DE PRODUCTOS FACTURABLES SEGUN ARBOR, CON LOS ARBOLES  DE PRODUCTOS INSTANCIADOS. 
		---		   RESULTADO: DESCUBRO LOS PRODUCTOS A LOS QUE SE APLICA LA FACTURACION (ENTIENDO QUE PADRES EN CASO DE DESCUENTOS, CARGOS Y  BONOS, PERO HAY QUE REVISAR) 

			/*CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` as
			Select  distinct f.clase, gr.*, case when gr.swParentInstProdId is null then gr.swInstProdId else gr.swParentInstProdId end  as swInstProdIdBilled --, gr.
			from  `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` gr
			inner join  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxPRODUCTOS_EKTNET` f on gr.swInstProdId=f.swInstProdId;*/
			
		--- OUT 2.3: ARBORxARBOL_PRODUCTOS_EKTNET_PREV: Tabla que cruza el arbol de productos descubiertos, con os catálogos de productos instanciados en el facturador 
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` as
				Select  distinct f.clase, gr.*, 
				--case when gr.swParentInstProdId is null then gr.swInstProdId else gr.swParentInstProdId end  as swInstProdIdBilled , 
				--cat_padre.swProdReleaseId as swProdReleaseIdBilled,cat_padre.swReleaseName as swReleaseNameBilled
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` gr
				inner join  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxPRODUCTOS_EKTNET` f on gr.swInstProdId=f.swInstProdId and not contains_substr(coalesce(f.clase,"") ,"RESTRICCION");
				--left join `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` pr_padre on pr_padre.swInstProdId=gr.swParentInstProdId
				--LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_prod_cat` cat_padre  ON cat_padre.swProdReleaseId = pr_Padre.swProdReleaseId;
				

				/* PREVIO
				---- Tabla que recrea todos los árboles de productos 
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` as
				with recursive rec as (			
					SELECT  
					p.idreg, p.lvl,p.swBuzonId,p.bMarcaCheck,p.swCustomerId,
					hf.clase,p.swProductType, p.swProdReleaseId,p.swReleaseName,
					--hf.swReleaseNameBilled, hf.swInstProdIdBilled ,          
					p.swInstProdId, p.fecha_venta_d,p.fecha_rfb_d, p.fecha_baja_d, p.fecha_venta_id,p.fecha_rfb_id, p.fecha_baja_id, p.nDaysAct, 
					phf.clase as claseParent, 
					p.swProdReleaseIdParent, p.swReleaseNameParent , p.swParentInstProdId, 
					--phf.swReleaseName as swReleaseNameParent,   
					p.swReleaseNameRoot, p.swInstProdIdRoot
					from `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` p
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` hf on hf.swInstProdId=p.swInstProdId             
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` phf on phf.swInstProdId=p.swParentInstProdId 
					--where p.swInstProdId=136525609
					union ALL
					select r.idreg, r.lvl+1 as lvl,r.swBuzonId,r.bMarcaCheck,r.swCustomerId,
					hf.clase,pr.swProductType,pr.swProdReleaseId,pr.swReleaseName,
					--hf.swReleaseNameBilled, hf.swInstProdIdBilled,          
					pr.swInstProdId, pr.fecha_venta_d,pr.fecha_rfb_d, pr.fecha_baja_d, pr.fecha_venta_id,pr.fecha_rfb_id, pr.fecha_baja_id, pr.nDaysAct, 
					phf.clase as claseParent,
					--NULL, NULL,NULL,NULL,         
					pr.swProdReleaseIdParent, pr.swReleaseNameParent, pr.swParentInstProdId,
					--phf.swReleaseName as swReleaseNameParent ,
					--NULL,NULL,          
					r.swReleaseNameRoot, r.swInstProdIdRoot  
					--r.swInstProdIdRoot, r.swProdReleaseIdRoot, r.swReleaseNameRoot 
					from rec r
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` pr on pr.swParentInstProdId=r.swInstProdId         
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` hf on hf.swParentInstProdId=r.swInstProdId  
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` phf on phf.swInstProdId=r.swInstProdId 				
					where r.lvl<=10 and not (r.lvl>1 and r.swProdReleaseId is null)
				)
				select distinct * 
				from rec
				where swProdReleaseId is not null
				--and not contains_substr(coalesce(clase,"") ,"RESTRICCION")
				--and not contains_substr(coalesce(claseParent,"") ,"RESTRICCION")
				--and not (lvl>1 and swProdReleaseId is null)
				order by 1 asc, 2 asc, 10 asc;
				FIN PREVIO*/
				
				--- Tabla que enrique el arbol de productos descubiertos, y cruzados con facturador, con las relaciones sobre que productos se imputan los cargos de las distintos productos

		--- OUT 2.3: LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC_TMP
			CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC_TMP` as
				with recursive rec as (			
				---- Productos raiz de grafos en buzones
					SELECT  
					p.idreg, p.lvl,p.swBuzonId,p.bMarcaCheck, p.bClienteCaptado, p.bBuzonSohoPrevio, p.bPrSohoPrevio, p.swCustomerId,p.swNIE, p.swfacturable,
					pf.clase,p.swProductType, p.swProdReleaseId,p.swReleaseName,
					--hf.swReleaseNameBilled, hf.swInstProdIdBilled ,          
					p.swInstProdId, p.swAgreementId, p.swContratoFisicoId, p.fecha_venta_d,p.fecha_rfb_d, p.fecha_baja_d, p.fecha_venta_id,p.fecha_rfb_id, p.fecha_baja_id, p.nDaysAct,
					--ppf.clase as claseParent, 
					--p.swProdReleaseIdParent, p.swReleaseNameParent , p.swParentInstProdId, 

			  ---   swInstProdIdBilled: 
			  ---       Si el producto es CUOTA, TARIFA o BONO entonces es swInstProdId del producto 
			  ---       Si el producto es DESCUENTO, entonces es nulo 

			  ---   swProdReleaseIdBilled:
			  ---       Si el producto es CUOTA, TARIFA o BONO entonces es el swProdReleaseId del producto
			  ---       Si el producto es DESCUENTO, entonces es nulo 

			  ---   swReleaseNameBilled
			  ---       Si el producto es CUOTA, TARIFA o BONO entonces es swReleaseName
			  ---       Si el producto es DESCUENTO, entonces es nulo 

			  ---   ClaseBilled: 
			  ---       Si la clase del producto contiene CUOTA o TARIFA o BONO entonces es la clase del hijo
			  ---       Si la clase del producto contiene DESCUENTO entonces es nulo

					case  when(contains_substr(pf.clase,"CUOTA")  or contains_substr(pf.clase,"TARIFA") or contains_substr(pf.clase,"BONO")) then p.swInstProdId
							when contains_substr(pf.clase,"DESCUENTO") then CAST(NULL AS INT64)
					end as swInstProdIdBilled,
					case	when(contains_substr(pf.clase,"CUOTA")  or contains_substr(pf.clase,"TARIFA") or contains_substr(pf.clase,"BONO")) then p.swProdReleaseId
							when contains_substr(pf.clase,"DESCUENTO") then CAST(NULL AS INT64)
					end as swProdReleaseIdBilled,
					case  when(contains_substr(pf.clase,"CUOTA")  or contains_substr(pf.clase,"TARIFA") or contains_substr(pf.clase,"BONO")) then p.swReleaseName
							when contains_substr(pf.clase,"DESCUENTO") then CAST(NULL AS STRING)
					end as swReleaseNameBilled,
					case  when(contains_substr(pf.clase,"CUOTA")  or contains_substr(pf.clase,"TARIFA") or contains_substr(pf.clase,"BONO")) then pf.clase
							when contains_substr(pf.clase,"DESCUENTO") then CAST(NULL AS STRING)
					end as claseBilled,

					--phf.swReleaseName as swReleaseNameParent,   
					p.swReleaseNameRoot, p.swInstProdIdRoot
					from `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` p
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` pf on pf.swInstProdId=p.swInstProdId             
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` ppf on ppf.swInstProdId=p.swParentInstProdId 
					--where p.swInstProdId=136525609
					where p.lvl=1 --and p.swFacturable=1
					/*AÑADIDO*/
					--and p.swbuzonid=22234850
					--and p.idreg=141820015
					/*FIN AÑADIDO*/          
					union ALL
					--- Productos hijo:

					select r.idreg, r.lvl+1 as lvl,r.swBuzonId,r.bMarcaCheck, r.bClienteCaptado, r.bBuzonSohoPrevio, r.bPrSohoPrevio, r.swCustomerId,r.swNIE,hf.swFacturable,
					hf.clase,pr.swProductType,pr.swProdReleaseId,pr.swReleaseName,
					--hf.swReleaseNameBilled, hf.swInstProdIdBilled,          
					pr.swInstProdId, pr.swAgreementId, pr.swContratoFisicoId, pr.fecha_venta_d,pr.fecha_rfb_d, pr.fecha_baja_d, pr.fecha_venta_id,pr.fecha_rfb_id, pr.fecha_baja_id, pr.nDaysAct, 
					--phf.clase as claseParent,
					--NULL, NULL,NULL,NULL,         
					--pr.swProdReleaseIdParent, pr.swReleaseNameParent, pr.swParentInstProdId,
					--phf.swReleaseName as swReleaseNameParent ,
					--NULL,NULL,          


				  ---   swInstProdIdBilled: 
				  ---       Si la clase del producto hijo es CUOTA, TARIFA o BONO entonces es swInstProdId del producto hijo
				  ---       Si la clase del producto hijo es DESCUENTO y la clase previa es distinta de BONO, entonces hereda la previa

				  ---   swProdReleaseIdBilled:
				  ---       Si la clase del producto hijo es CUOTA, TARIFA o BONO entonces es el swProdReleaseId del producto
				  ---       Si la clase del producto hijo es DESCUENTO y la clase previa es distinta de BONO, entonces hereda la previa

				  ---   swReleaseNameBilled
				  ---       Si la clase del producto hijo es CUOTA, TARIFA o BONO entonces es swReleaseName
				  ---       Si la clase del producto hijo es DESCUENTO y la clase previa es distinta de BONO, entonces hereda la previa

				  ---   ClaseBilled: 
				  ---       Si la clase del producto hijo contiene CUOTA o TARIFA o BONO entonces es la clase del hijo
				  ---       Si la clase del producto hijo contiene DESCUENTO y la clase previa es distinta de BONO entonces es nulo

					case  when(contains_substr(hf.clase,"CUOTA")  or contains_substr(hf.clase,"TARIFA") or contains_substr(hf.clase,"BONO"))  and pr.swInstProdId=hf.swInstProdId then hf.swInstProdId
							when contains_substr(hf.clase,"DESCUENTO") and not contains_substr( phf.clase, "BONO") then phf.swInstProdId
					end as swInstProdIdBilled,
					case  when(contains_substr(hf.clase,"CUOTA")  or contains_substr(hf.clase,"TARIFA") or contains_substr(hf.clase,"BONO"))  and pr.swInstProdId=hf.swInstProdId then hf.swProdReleaseId
							when contains_substr(hf.clase,"DESCUENTO") and not contains_substr( phf.clase, "BONO") then phf.swProdReleaseId
					end as swProdReleaseIdBilled,
					case  when(contains_substr(hf.clase,"CUOTA")  or contains_substr(hf.clase,"TARIFA") or contains_substr(hf.clase,"BONO"))   and pr.swInstProdId=hf.swInstProdId then hf.swReleaseName
							when contains_substr(hf.clase,"DESCUENTO") and not contains_substr( phf.clase, "BONO") then phf.swReleaseName
					end as swReleaseNameBilled,
					case  when(contains_substr(hf.clase,"CUOTA")  or contains_substr(hf.clase,"TARIFA") or contains_substr(hf.clase,"BONO"))   and pr.swInstProdId=hf.swInstProdId then hf.clase
							when contains_substr(hf.clase,"DESCUENTO") and not contains_substr( phf.clase, "BONO") then phf.clase
					end as claseBilled,

					r.swReleaseNameRoot, r.swInstProdIdRoot  
					--r.swInstProdIdRoot, r.swProdReleaseIdRoot, r.swReleaseNameRoot 
					from rec r
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBOL_PRODUCTOS_EKTNET` pr on pr.swBuzonid=r.swBuzonid and  pr.idreg=r.idreg and pr.swParentInstProdId=r.swInstProdId --and pr.swFacturable=1          
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` hf on hf.swBuzonid=r.swBuzonid and  hf.idreg=r.idreg and hf.swParentInstProdId=r.swInstProdId --and hf.swFacturable=1 
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` phf on phf.swBuzonid=r.swBuzonid and  phf.idreg=r.idreg and phf.swInstProdId=r.swInstProdId --and phf.swFacturable=1
					where r.lvl<=10 and not (r.lvl>1 and r.swProdReleaseId is null) 
				)
				select distinct * 
				from rec
				where swProdReleaseId is not null
				--and not contains_substr(coalesce(clase,"") ,"RESTRICCION")
				--and not contains_substr(coalesce(claseParent,"") ,"RESTRICCION")
				--and not (lvl>1 and swProdReleaseId is null)
				order by 1 asc, 2 asc, 10 asc;
						

		--- OUT 2.3: LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` as
				select * from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC_TMP` where swFacturable=1;
				
				/**/
				
				/*
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` as
				Select  distinct p.*, 
				case when contains_substr(p.clase,"CUOTA") or contains_substr(p.clase,"TARIFA") or contains_substr(p.clase,"BONO") then p.clase
					 when contains_substr(p.clase,"DESCUENTO") and not contains_substr( l.claseParent, "BONO") then l.claseParent 
				end  as claseBilled,
				case when contains_substr(p.clase,"CUOTA") or contains_substr(p.clase,"TARIFA") or contains_substr(p.clase,"BONO") then p.swInstProdId 
				  	 when contains_substr(p.clase,"DESCUENTO") and not contains_substr( l.claseParent, "BONO")  then p.swParentInstProdId 
				end  as swInstProdIdBilled, 
				case when contains_substr(p.clase,"CUOTA") or contains_substr(p.clase,"TARIFA") or contains_substr(p.clase,"BONO") then p.swProdReleaseId 
				  	 when contains_substr(p.clase,"DESCUENTO") and not contains_substr( l.claseParent, "BONO") then p.swProdReleaseIdParent 
				end  as swProdReleaseIdBilled, 
				case when contains_substr(p.clase,"CUOTA") or contains_substr(p.clase,"TARIFA") or contains_substr(p.clase,"BONO") then p.swReleaseName 
				  	 when contains_substr(p.clase,"DESCUENTO") and not contains_substr( l.claseParent, "BONO") then p.swReleaseNameParent 
				end  as swReleaseNameBilled, 
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` p
				left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` l  on l.idreg=p.idreg and l.swInstProdId=p.swInstProdId and not contains_substr( l.claseParent, "BONO"); 
				--where p.idreg=136525609;
				*/


		--- OUT 2.3: ARBORxARBOL_PRODUCTOS_EKTNET: Tabla que enriquece el cruce de los productos y el facturador, con datos que caracterizan  				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` as
				Select  distinct p.*, l.claseBilled, l.swInstProdIdBilled, l.swProdReleaseIdBilled, l.swReleaseNameBilled, 
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` p
				left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` l  on l.swBuzonId=p.swBuzonId and l.idreg=p.idreg and l.swInstProdId=p.swInstProdId  and l.clase=p.clase 
				-- and not contains_substr( l.claseParent, "BONO"); 
				--where p.idreg=136525609
				where l.claseBilled is not null;
				--and p.idreg=141820015;




		--- PASO 2.4: GENERACION OBJETOS FACTURABLES
	
			
			---- PASO 2.4.1: Genero cuotas de alta
			--- OUT 2.4.1: CU_CUOTAS_ALTA_TMP: Cuotas de alta								
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTA_TMP` as
				select distinct p.*, c.* except(swProdReleaseId, swReleaseName), SAFE_DIVIDE(rate,10000) as importe
				from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS_ALTA` c
				on p.swProdReleaseId=c.swProdReleaseId  and p.clase="CUOTAS_ALTA" and p.claseBilled="CUOTAS_ALTA"  and EXTRACT(DATE FROM c.Active_Date) < p.fecha_venta_d and  EXTRACT(DATE FROM coalesce(c.Inactive_Date,'2099-12-30'))>p.fecha_venta_d ;
				


			---- PASO 2.4.2: Genero cuotas mensuales
			--- OUT 2.4.2: ARBOR_CAT_CUOTAS_MENSUALES_ACT: Catálogos de cuotas mensuales activas 										
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_CUOTAS_MENSUALES_ACT`	AS 			  
				select swProdReleaseId,swReleaseName, descripcion, Description_text,count(rate) as n, min(rate) as rate_min, max(rate) as rate_max, CAST(avg(rate) AS INT64)  as rate_pr 
				from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS` 
				where Inactive_date is null
				and not(swProdReleaseId=8151 and contains_substr(Description_text,"Telefonogune aurreratuaren paketea/Paquete Centralita Avanzada")) 
				and not(swProdReleaseId=7951 and contains_substr(Description_text,"Finkotik nazioart.300 h.k./C.mens bono origen fijo internacional 300 minutos"))
				and not (swProdReleaseId=7181 and not contains_substr(Description_text,"Finkotik eg.deiet.1.000 min.bon.h.k./C.men.bono llamad.origen fijo 1.000 min"))
				group by 1,2,3,4 
				order by swProdReleaseId desc;

			--- OUT 2.4.2: CU_CUOTAS_MENSUALES_TMP: Cuotas mensuales	
				-- 29512
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` as				
				select distinct p.* except(swTipoProducto), c.* except(swProdReleaseId,swReleaseName),
				SAFE_DIVIDE(rate_min,10000) as importe, SAFE_DIVIDE(rate_min,10000) as importe_min, SAFE_DIVIDE(rate_max,10000) as importe_max, SAFE_DIVIDE(rate_pr,10000) as importe_pr
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_CUOTAS_MENSUALES_ACT` c
				on p.swProdReleaseId=c.swProdReleaseId and p.claseBilled="CUOTAS"
				order by swcustomerId, swAgreementId, swInstProdIdBilled, swInstProdId;  

				/*
				----DESARROLLO
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_CUOTAS_MENSUALES_ACT`	AS 			  
				select swProdReleaseId,swReleaseName, descripcion, Description_text,count(rate) as n, min(rate) as rate_min, max(rate) as rate_max, CAST(avg(rate) AS INT64)  as rate_pr 
				from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS` 
				--where Inactive_date is null
				where not(swProdReleaseId=8151 and contains_substr(Description_text,"Telefonogune aurreratuaren paketea/Paquete Centralita Avanzada")) 
				and not(swProdReleaseId=7951 and contains_substr(Description_text,"Finkotik nazioart.300 h.k./C.mens bono origen fijo internacional 300 minutos"))
				group by 1,2,3,4 
				order by swProdReleaseId desc;


				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` as				
				select distinct p.* except(swTipoProducto), c.* except(swProdReleaseId,swReleaseName),
				--SAFE_DIVIDE(rate_min,10000) as importe, SAFE_DIVIDE(rate_min,10000) as importe_min, SAFE_DIVIDE(rate_max,10000) as importe_max, SAFE_DIVIDE(rate_pr,10000) as importe_pr
				SAFE_DIVIDE(rate,10000) as importe, SAFE_DIVIDE(rate_min,10000) as importe_min, SAFE_DIVIDE(rate_max,10000) as importe_max, SAFE_DIVIDE(rate_pr,10000) as importe_pr
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS` c
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_CUOTAS_MENSUALES_ACT` c
				on p.swProdReleaseId=c.swProdReleaseId and p.claseBilled="CUOTAS" and EXTRACT(DATE FROM c.Active_Date) < p.fecha_venta_d and  EXTRACT(DATE FROM coalesce(c.Inactive_Date,'2099-12-30'))>p.fecha_venta_d 
				order by swcustomerId, swAgreementId, swInstProdIdBilled, swInstProdId;  
				*/
 


			--- OUT 2.4.2: LOG_0402_CU_BONOS_REPLICAN_CUOTAS_MENSUALES_TMP
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0402_CU_BONOS_REPLICAN_CUOTAS_MENSUALES_TMP` as				
				select p.* from  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` p 
				where contains_substr(p.clase,"ONO") and contains_substr(p.claseBilled,"CUOTAS") 
				--and swBuzonId=21605999
				and exists(
					select 1
					from  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` d
					where d.swInstProdIdBilled=p.swInstProdIdBilled and contains_substr(d.clase,"UOTA") and coalesce(d.importe,0)=coalesce(p.importe,0)
				);


				DELETE FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` c
				where contains_substr(c.clase,"ONO") and contains_substr(c.claseBilled,"CUOTAS") 
				and exists (
					select 1
					from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0402_CU_BONOS_REPLICAN_CUOTAS_MENSUALES_TMP` b 
					where b.swInstProdIdBilled=c.swInstProdIdBilled and coalesce(b.importe,0)=coalesce(c.importe,0)			
				);



			--- OUT 2.4.2: LOG_0402_CU_CUOTAS_ALTA_REPLICAN_CUOTAS_MENSUALES_TMP
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0402_CU_CUOTAS_ALTA_REPLICAN_CUOTAS_MENSUALES_TMP` as				
				select p.* from  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` p 
				where contains_substr(p.clase,"ALTA") and contains_substr(p.claseBilled,"CUOTAS") 
				---and swBuzonId=21605999
				and exists(
					select 1
					from  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` d
					where d.swInstProdIdBilled=p.swInstProdIdBilled and contains_substr(d.clase,"UOTA") and not contains_substr(d.clase,"ALTA") and coalesce(d.importe,0)=coalesce(p.importe,0)
				);


				DELETE FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` c
				where contains_substr(c.clase,"ALTA") and contains_substr(c.claseBilled,"CUOTAS") 
				and exists (
					select 1
					from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0402_CU_CUOTAS_ALTA_REPLICAN_CUOTAS_MENSUALES_TMP` b 
					where b.swInstProdIdBilled=c.swInstProdIdBilled and coalesce(b.importe,0)=coalesce(c.importe,0)			
				);


			--- OUT 2.4.2: CU_COUTAS_MENSUALES_NO_ARPU_TMP: Productos que no son descuentos, y que están asociados a una cuota mensual en arbor, pero que no son cuotas mensuales
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_COUTAS_MENSUALES_NO_ARPU_TMP` as
				select p.* from  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				where contains_substr(p.claseBilled,"CUOTA") and not contains_substr(p.claseBilled,"ALTA") and not contains_substr(clase,"ESCUENT")
				and not exists(
					select 1
					from  `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` d
					where d.swInstProdId=p.swInstProdId
				);
				
				


			--- PASO 2.4.3: Genero Bonos
			--- OUT 2.4.3: ARBOR_CAT_BONOS_ACT				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_BONOS_ACT`	AS 			  
				select distinct * except(Tipo_restriccion, Restriccion_bono, Tipo_uso, Tipo_datos_bono, Plan_bono,exclusion)
				from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_BONOS` 
				where Fh_inactivacion_tarifa_bono is null
				--where Fecha_Inactivacion is null
				--and not (Id_Prod_CRM=3476 and orden_dto=1238 and coalesce(Porcentaje_Dto,0)=0)			
				order by Id_Prod_CRM desc;

			--- OUT 2.4.3: CU_BONOS_TMP				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_BONOS_TMP` as
				select distinct p.*, c.* except(producto_afectado)
				from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_BONOS_ACT` c
				--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";				
				on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.claseBilled="BONOS";


				/*
				----PARA VERIFICAR ESTRUCTURA EN CASO DE BONOS
				select from where swCustomerId=6283286 -> Producto 138478997 Cargo (catalogo 6434)y 138478998 descuento (catalogo 8037)
				select from where swCustomerId=7625984

				select swProdReleaseId from `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_CUOTAS`  where swProdReleaseId=6434;
				*/

			---- PASO 2.4.5: Genero descuentos cliente objetivo
			----	Por descuento nec
				
				/* VERSION ORIGINAL SIN CREAR CAMPO AGREGADO
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO_ACT`	AS 		
				select distinct * except(cargos_asociados, descripcion_cargo, target_dto, num_fila),
				count(distinct Porcentaje_Dto) OVER(PARTITION BY Id_Prod_CRM, producto_afectado)  as npctxcat
				from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` 
				where not (Id_Prod_CRM=3476 and orden_dto=1238 and coalesce(Porcentaje_Dto,0)=0)
				and Fecha_Inactivacion is null
				order by Id_Prod_CRM desc;
				*/


			--- OUT 2.4.5: ARBOR_CAT_DESCUENTOS_OBJETIVO				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO`	AS 
				with dagg as (
					select distinct id_Prod_Crm, string_agg(distinct Datos_Target) as Datos_Target_agg from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` group by 1 order  by 1
				), 
				df as (
					select distinct * except(cargos_asociados, descripcion_cargo, target_dto, num_fila,Datos_Target), count(distinct Porcentaje_Dto) OVER(PARTITION BY Id_Prod_CRM, producto_afectado)  as npctxcat
					from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` 
					where not (Id_Prod_CRM=3472 and orden_dto=1243)
					and not (Id_Prod_CRM=3270 and (orden_dto=2261 or orden_dto=2262))
					--and Fecha_Inactivacion is null
					order by Id_Prod_CRM desc
				) 
				select distinct df.*, dagg.Datos_Target_agg
				from df
				inner join dagg on dagg.id_Prod_CRM=df.Id_Prod_CRM
				--where not(df.Id_Prod_CRM!=3472 and contains_substr(df.Description_text,"Telefonogune aurreratuaren paketea/Paquete Centralita Avanzada")) 
				order by df.Id_Prod_CRM desc;



				/*
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO_ACT`	AS 
				with dagg as (
					select distinct id_Prod_Crm, string_agg(distinct Datos_Target) as Datos_Target_agg from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` group by 1 order  by 1
				), 
				df as (
					select distinct * except(cargos_asociados, descripcion_cargo, target_dto, num_fila,Datos_Target), count(distinct Porcentaje_Dto) OVER(PARTITION BY Id_Prod_CRM, producto_afectado)  as npctxcat
					from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` 
					where not (Id_Prod_CRM=3472 and orden_dto=1243)
					and Fecha_Inactivacion is null
					order by Id_Prod_CRM desc
				) 
				select distinct df.*, dagg.Datos_Target_agg
				from df
				inner join dagg on dagg.id_Prod_CRM=df.Id_Prod_CRM
				--where not(df.Id_Prod_CRM!=3472 and contains_substr(df.Description_text,"Telefonogune aurreratuaren paketea/Paquete Centralita Avanzada")) 
				order by df.Id_Prod_CRM desc;
				*/

				/*
				---- ESTA CONSULTA ESTA EN PRODUCCION, PERO TIENE EL PROBLEMA DE QUE NO RESUELVE BIEN EL CASO DE LOS DESCUENTOS EN RAIZ
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` as
				select distinct p.*, c.* except(producto_afectado), 
				Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
				coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
				pr.PermDescuento as PermanenciaPrDto, 
				pr.PctmDescuento as PorcentajePrDto,
				coalesce(pr.PctmDescuento,c.Porcentaje_Dto) as PctDtoCom
				from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO_ACT` c
				--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
				--ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE
				--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
				--FIN MODIFICACION
				on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"
				left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=p.swBuzonId and pr.swCustomerId=p.swCustomerId and pr.swInstProdId=p.swInstProdId;  ---5317
				*/

				----  DESARROLLO
				
					--- Tiene como objetivo diferenciar el cálculo del importe de los descuentos que no tienen padre de los descuentos que tienen padre
				
				/*				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1` as
				with cf as (
					--- Descuentos de nivel 1 (no tienen padre), enriquecido con poblacion de todas las cuotas que pueden se asignadas a esos productos --6618 cuotas
					select distinct p.* except(claseBilled, swInstProdIdBilled,swProdReleaseIdBilled,swReleaseNameBilled), f.claseBilled,f.swInstProdIdBilled, f.swProdReleaseIdBilled, f.swReleaseNameBilled 
					from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` f
					on f.swBuzonid=p.swBuzonid and  f.lvl>1 and f.swInstProdIdBilled is not null and contains_substr(f.claseBilled,"cuota")  and not contains_substr(f.clase,"descuento") 
					where p.lvl=1 and p.swInstProdIdBilled is null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO" --and p.idreg=139557372 and p.idreg=139557368
				) select cf.*,  c.* except(producto_afectado),
						Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
						coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
						pr.PermDescuento as PermanenciaPrDto, 
						pr.PctmDescuento as PorcentajePrDto,
						coalesce(pr.PctmDescuento,c.Porcentaje_Dto) as PctDtoCom								
				from cf 
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO_ACT` c
				--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
				--ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE--
				--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
				--FIN MODIFICACION--
				on cf.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE cf.swProdReleaseIdBilled=c.Producto_afectado END and cf.lvl=1 and cf.swInstProdIdBilled is not null and cf.clase="DESCUENTOS_CLIENTES_OBJETIVO"
				left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=cf.swBuzonId and pr.swCustomerId=cf.swCustomerId and pr.swInstProdId=cf.swInstProdId;
				*/				

				/*			
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1` as							
				--- Importe de descuentos en productos que tienen padre
				select distinct p.*, c.* except(producto_afectado), 
				Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
				coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
				pr.PermDescuento as PermanenciaPrDto, 
				pr.PctmDescuento as PorcentajePrDto,
				coalesce(pr.PctmDescuento,c.Porcentaje_Dto) as PctDtoCom
				from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO_ACT` c
				--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
				--ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE--
				--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
				--FIN MODIFICACION--
				on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.lvl>1 and p.swInstProdIdBilled is not null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"
				left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=p.swBuzonId and pr.swCustomerId=p.swCustomerId and pr.swInstProdId=p.swInstProdId;  ---5317
				*/


				
				/*
				with cf as (
					--- Descuentos de nivel 1 (no tienen padre), enriquecido con poblacion de todas las cuotas que pueden se asignadas a esos productos --6618 cuotas
					select distinct p.* except(claseBilled, swInstProdIdBilled,swProdReleaseIdBilled,swReleaseNameBilled), f.claseBilled,f.swInstProdIdBilled, f.swProdReleaseIdBilled, f.swReleaseNameBilled 
					from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
					left join `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` f
					on f.swBuzonid=p.swBuzonid and  f.lvl>1 and f.swInstProdIdBilled is not null and contains_substr(f.claseBilled,"cuota")  and not contains_substr(f.clase,"descuento") 
					where p.lvl=1 and p.swInstProdIdBilled is null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"
				) select distinct cf.*,  c.* except(producto_afectado),
						Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
						coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
						pr.PermDescuento as PermanenciaPrDto, 
						pr.PctmDescuento as PorcentajePrDto,
						coalesce(pr.PctmDescuento,c.Porcentaje_Dto) as PctDtoCom,
				from cf 
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO` c
				--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
				--ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE
				--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
				--FIN MODIFICACION
				on cf.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE cf.swProdReleaseIdBilled=c.Producto_afectado END and cf.lvl=1 and cf.swInstProdIdBilled is not null and cf.clase="DESCUENTOS_CLIENTES_OBJETIVO"
				left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=cf.swBuzonId and pr.swCustomerId=cf.swCustomerId and pr.swInstProdId=cf.swInstProdIdBilled
				where DATE_DIFF(cf.fecha_venta_d,EXTRACT(DATE FROM c.Fecha_Activacion),  DAY) > 0 and Coalesce(DATE_DIFF(EXTRACT(DATE FROM Fecha_Inactivacion),cf.fecha_venta_d,  DAY) , 9999) >=0;
				*/

			--- OUT 2.4.5: CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1` as
				--- Importe de descuentos en productos que tienen padre				
				select distinct p.*, c.* except(producto_afectado, Porcentaje_dto,Lim_Inferior_Bandas, Lim_Superior_Bandas), 
				Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
				coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
				pr.PermDescuento as PermanenciaPrDto, 
				pr.PctmDescuento as PorcentajePrDto,
				coalesce(pr.PctmDescuento,c.Porcentaje_Dto) as PctDtoCom,
				c.Porcentaje_Dto
				from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO` c
				--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
				--ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE--
				--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
				--FIN MODIFICACION--
				on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.lvl>1 and p.swInstProdIdBilled is not null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"
				left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=p.swBuzonId and pr.swCustomerId=p.swCustomerId and pr.swInstProdId=p.swInstProdId  ---5317
				where DATE_DIFF(p.fecha_venta_d,EXTRACT(DATE FROM c.Fecha_Activacion),  DAY) > 0 and Coalesce(DATE_DIFF(EXTRACT(DATE FROM c.Fecha_Inactivacion),p.fecha_venta_d,  DAY) , 9999) >=0;			


			--- OUT 2.4.5: CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_TMP				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_TMP` as
				with r as (
					with cf as (
						--- Descuentos de nivel 1 (no tienen padre), enriquecido con poblacion de todas las cuotas que pueden se asignadas a esos productos --6618 cuotas ---6044 cuotas
						select distinct p.* except(claseBilled, swInstProdIdBilled,swProdReleaseIdBilled,swReleaseNameBilled), f.claseBilled,f.swInstProdIdBilled, f.swProdReleaseIdBilled, f.swReleaseNameBilled 
						from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` p 
						left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` f
						on f.swBuzonid=p.swBuzonid and  f.lvl>1 and f.swInstProdIdBilled is not null and contains_substr(f.claseBilled,"cuota")  and not contains_substr(f.clase,"descuento") 
						where p.lvl=1 and p.swInstProdIdBilled is null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"
					) select distinct cf.*, c.* except(producto_afectado),
							Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
							coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
							pr.PermDescuento as PermanenciaPrDto, 
							pr.PctmDescuento as PorcentajePrDto,
							coalesce(pr.PctmDescuento,c.Porcentaje_Dto) as PctDtoCom,
					from cf 
					inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO` c
					--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
					/*ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE*/
					--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
					/*FIN MODIFICACION*/				
					on cf.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE cf.swProdReleaseIdBilled=c.Producto_afectado END and cf.lvl=1 and cf.swInstProdIdBilled is not null and cf.clase="DESCUENTOS_CLIENTES_OBJETIVO"
					left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=cf.swBuzonId and pr.swCustomerId=cf.swCustomerId and pr.swInstProdId=cf.swInstProdIdBilled
					where DATE_DIFF(cf.fecha_venta_d,EXTRACT(DATE FROM c.Fecha_Activacion),  DAY) > 0 and Coalesce(DATE_DIFF(EXTRACT(DATE FROM Fecha_Inactivacion),cf.fecha_venta_d,  DAY) , 9999) >=0
					---and idreg=141820549 -and swInstProdIdBilled=141820123
				) select distinct r.* except(PctDtoCom, Porcentaje_dto,Lim_Inferior_Bandas, Lim_Superior_Bandas), 
				max(PctDtoCom) over(partition by swBuzonId, swCustomerId,swInstProdId ) as PctDtoCom,  
				max(PctDtoCom) over(partition by swBuzonId, swCustomerId,swInstProdId ) as Porcentaje_dto 
				from r;

						
						--SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_TMP` l WHERE  l.swBuzonId=22234850; 

			--- OUT 2.4.5: CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_DES										
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_DES` as														
				with p as (
				   ---  poblacion de todas las cuotas que pueden ser asignadas a descuentos en raiz
				  select distinct p.*, l.claseBilled, l.swInstProdIdBilled, l.swProdReleaseIdBilled, l.swReleaseNameBilled, lv1.swProdReleaseId as  swProdReleaseIdDesc, lv1.swReleaseName as  swReleaseNameDesc, lv1.clase as claseDesc
				  from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` p 
				  inner join  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_TMP` lv1 on lv1.swInstProdIdBilled=p.swInstProdId  and lv1.claseBilled=p.clase --and  lv1.swBuzonId=22234850
				  left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` l  on l.idreg=p.idreg and l.swInstProdId=p.swInstProdId 						   
						   
				)	select distinct p.* /*except(swProdReleaseIdDesc, swReleaseNameDesc, claseDesc)*/, c.* except(producto_afectado, Porcentaje_dto,Lim_Inferior_Bandas, Lim_Superior_Bandas), 
				Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
				coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
				pr.PermDescuento as PermanenciaPrDto, 
				pr.PctmDescuento as PorcentajePrDto,
				coalesce(pr.PctmDescuento,c.Porcentaje_Dto) as PctDtoCom, 
				c.Porcentaje_Dto
				from  p 
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO` c
				--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
				--ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE--
				--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
				--FIN MODIFICACION--
				on p.swProdReleaseIdDesc=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.lvl>1 and p.swInstProdIdBilled is not null and p.claseDesc="DESCUENTOS_CLIENTES_OBJETIVO" and c.Nivel_aplicacion="Servicio"
				left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=p.swBuzonId and pr.swCustomerId=p.swCustomerId and pr.swInstProdId=p.swInstProdId  ---5317
				where DATE_DIFF(p.fecha_venta_d,EXTRACT(DATE FROM c.Fecha_Activacion),  DAY) > 0 and Coalesce(DATE_DIFF(EXTRACT(DATE FROM c.Fecha_Inactivacion),p.fecha_venta_d,  DAY) , 9999) >=0;			
					
					
					
			--- OUT 2.4.5: CU_DESCUENTOS_OBJETIVO_PREV_LVL_1															
			--- En caso de que el catálogo tenga definidas varios posibles tramos de descuento, y el producto no tenga especificado un porcentaje por caracteristica, se asigna el porcentaje de descuento mas grande
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1` as					
				select distinct * except(Porcentaje_Dto, PorcentajePrDto,PctDtoCom), 
				max(PorcentajePrDto) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as PorcentajePrDto,
				max(PctDtoCom) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as PctDtoCom,
				max(Porcentaje_Dto) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as Porcentaje_Dto				
				from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_DES`
				order by swInstProdId;

					

				--select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_TMP` where swBuzonId=22234850;	-- 160
				--select * FROM  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_DES` where swBuzonId=22234850; --64


				--select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1` where swBuzonId=22234850;
				--select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1` where swBuzonId=22234850 and id_prod_crm=10548;
				--select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` where swBuzonId=22234850 and id_prod_crm=10548 order by lvl asc;
				--select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_DES` where swBuzonId=22234850 and id_prod_crm=10548 order by lvl asc;


				---select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1` where swBuzonId=22234850;



				/*	PARCHE */
				
				--CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1` as
				--SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1` where 1=0; 
			
				/*	FIN PARCHE */



				/*	--- DESARROLLO  INTEGRACION DE CU_DESCUENTOS_OBJETIVO_PREV_LVL_1 y CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1 
					---		CU_DESCUENTOS_OBJETIVO_PREV_LVL_1 NO TIENE LA ESTRUCTURA DE COLUMNAS DE CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1
					
					CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1` as
					Select  distinct p.*, c.* except(producto_afectado, Porcentaje_dto,Lim_Inferior_Bandas, Lim_Superior_Bandas), l.claseBilled, l.swInstProdIdBilled, l.swProdReleaseIdBilled, l.swReleaseNameBilled, 
					from  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p
					inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO` c
					on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.lvl>1 and p.swInstProdIdBilled is not null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
					inner join  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1_TMP` l  on l.swInstProdId=p.swInstProdId -- and not contains_substr( l.claseParent, "BONO")
					--where l.claseBilled is not null;				
					--and p.idreg=136525609;
				
				*/
			

				/*	FIN DESARROLLO */

				
			--- OUT 2.4.5: CU_DESCUENTOS_OBJETIVO_PREV	
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` as
				select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_M1`
				UNION ALL
				select * except(swProdReleaseIdDesc,swReleaseNameDesc,claseDesc) FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV_LVL_1`;
				---not (claseBilled="CUOTAS" and contains_substr(Datos_Target_agg,"CUOTAS DE ALTA"))

			--- OUT 2.4.5: CU_DESCUENTOS_OBJETIVO_DES					
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_DES` as
				select * from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` where npctxcat=0
				union all 
				select * from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` where npctxcat=1
				union all				
				select * from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` where npctxcat>1 and PctDtoCom=Porcentaje_Dto; --- 238

			--- OUT 2.4.5: CU_DESCUENTOS_OBJETIVO_TMP
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_TMP` as
				select distinct d.*, SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100)) as importe 
				from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_DES` d
				left join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTA_TMP` ca on ca.swInstProdId=d.swInstProdIdBilled
				left join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` cm on cm.swInstProdId=d.swInstProdIdBilled;				

			--- OUT 2.4.5: CU_COUTAS_SIN_DESCUENTO_TMP				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_COUTAS_SIN_DESCUENTO_TMP` as
				select p.* from  `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				where contains_substr(p.clase,"CUOTA")
				and not exists(
					select 1 
					from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_TMP` d
					where d.swInstProdIdBilled=p.swInstProdId
				);
				


				---select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` where swBuzonId=22234850;
				---select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_PREV` where swBuzonId=22234850 and id_prod_crm=10548 order by lvl asc;
				---select * FROM `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_DES` where swBuzonId=22234850 and id_prod_crm=10548 order by lvl asc;
				
				
				/*
				select from p.* `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				where contains_substr(p.clase,"CUOTA")
				and not exists(
					select 1 
					from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_TMP` d
					where d.swInstProdIdBilled=p.swInstProdId
				)
				*/
				

			---- PASO 2.4.6:Genero descuentos restricciones

				
			--- OUT 2.4.6: ARBOR_CAT_DESCUENTOS_RES_ACT				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_RES_ACT`	AS 			  
				select distinct * 
				from  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_RES` 
				where Fecha_Inactivacion is null
				--and  not (Id_Prod_CRM=3476 and orden_dto=1238 and coalesce(Porcentaje_Dto,0)=0)
				order by Id_Prod_CRM desc;


			--- OUT 2.4.6: CU_DESCUENTOS_RES_TMP				
				CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_RES_TMP` as
				select distinct p.*, c.*
				from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET` p 
				--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_RES_ACT` c
				on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.clase="DESCUENTOS_CLIENTES_RESTRICCION";




			--- PASO 2.4.7: Genero de descuentos de cuentas 

				--- PASO 2.4.7.1: Identifico la población de descuentos de nivel 1, que son de tipo cuenta 
				
						--- Descuentos de nivel 1 (no tienen padre) con nivel_de_aplicación "cuenta"

				--- OUT 2.4.7.1: CU_DESCUENTOS_CUENTA_PREV				
						  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV` as --- 4758
						  with p as (
									--- Descuentos de nivel 1 (no tienen padre) enriquecido con poblacion de todas las cuotas que pueden se asignadas a esos descuentos

 									/*select distinct p.*  except(claseBilled, swInstProdIdBilled,swProdReleaseIdBilled,swReleaseNameBilled), f.claseBilled,f.swInstProdIdBilled, f.swProdReleaseIdBilled, f.swReleaseNameBilled, pd.DurDescuento, pd.PermDescuento, pd.PctmDescuento 
									from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` p 
									left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` f
									on f.swBuzonid=p.swBuzonid and  f.lvl>1 and f.swInstProdIdBilled is not null and contains_substr(f.claseBilled,"cuota")  and not contains_substr(f.clase,"descuento") 
									left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pd on pd.swBuzonId=p.swBuzonId and  pd.swCustomerId=p.swCustomerId and pd.swInstProdId=p.swInstProdId
									where p.lvl=1 and p.swInstProdIdBilled is null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"*/

 									select distinct p.*  except(claseBilled, swInstProdIdBilled,swProdReleaseIdBilled,swReleaseNameBilled), f.claseBilled,f.swInstProdIdBilled, f.swProdReleaseIdBilled, f.swReleaseNameBilled, pd.DurDescuento, pd.PermDescuento, pd.PctmDescuento 
									from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` p 
									left join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` f
									on f.swBuzonid=p.swBuzonid and  f.lvl>1 and f.swInstProdIdBilled is not null and contains_substr(f.claseBilled,"cuota")  and not contains_substr(f.clase,"descuento") 
									left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pd on pd.swBuzonId=p.swBuzonId and  pd.swCustomerId=p.swCustomerId and pd.swInstProdId=p.swInstProdId
									where p.lvl=1 and p.swInstProdIdBilled is null and p.clase="DESCUENTOS_CLIENTES_OBJETIVO" and p.swContratoFisicoId=f.swContratoFisicoId
									

						  ) , cf as (
									--- Catálogos de descuentos de tipo cuenta
									--select cf.id_Prod_CRM,cf.Nivel_aplicacion, cf.Tipo_dto, cf.Dominio_Dto, cf.Linea_Prod, cf.Porcentaje_Dto, cf.Fecha_Activacion, cf.Fecha_Inactivacion,cf.Producto_afectado, 
									--string_agg(distinct cf.tipo_restriccion) as tipo_objeto_agg, string_agg(distinct cf.Datos_restriccion) as Datos_objeto_agg
									select distinct cf.id_Prod_CRM,cf.Nivel_aplicacion, cf.Tipo_dto, cf.Dominio_Dto, cf.Linea_Prod, cf.Orden_Plan_dto, cf.Orden_dto, cf.Porcentaje_Dto, cf.Duracion, cf.Fecha_Activacion, cf.Fecha_Inactivacion,cf.Producto_afectado, 
									cf.tipo_restriccion as tipo_objeto, cf.Datos_restriccion as Datos_objeto, count(distinct Porcentaje_Dto) OVER(PARTITION BY Id_Prod_CRM, producto_afectado)  as npctxcat
									from `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_RES` cf
									---string_agg(distinct cf.tipo_target) as tipo_objeto_agg, string_agg(distinct cf.Datos_target) as Datos_objeto_agg
									---from `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` cf
									where cf.Nivel_aplicacion="Cuenta"
									--group by 1,2,3,4,5,6,7,8,9
							), lp as ( 							
									--- Catálogos de productos facturables por linea de producto definida en arbor									
									select distinct coalesce(linea_prod,"NOINF") as linea_prod, id_prod_crm, nombre_CRM, nombre_arbor,Producto_afectado
									from `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_RES`
									order by 1,2												
							), dominioxclase As (
									select dominio, clase
									from 
									UNNEST(['CUOTAS MENSUALES','CUOTAS DE ALTA','TODOS LOS CARGOS','TODOS LOS CARGOS']) as dominio WITH OFFSET o1
									left join
									UNNEST(['CUOTAS','CUOTAS_ALTA','CUOTAS','CUOTAS_ALTA']) as clase WITH OFFSET o2   
									ON o2=o1
							)	 --- Población de descuentos de tipo cuenta asociados a cuotas sobre las que se debe aplicar						
						  select distinct p.*, -- cf.*
						  cf.Nivel_aplicacion, cf.Tipo_dto, cf.Dominio_Dto, cf.Linea_Prod, cf.Orden_Plan_dto, cf.Orden_dto,/*cf.tipo_objeto_agg, Datos_objeto_agg,*/cf.tipo_objeto, cf.Datos_objeto, cf.Porcentaje_Dto, cf.Duracion, cf.Fecha_Activacion, cf.Fecha_Inactivacion,cf.Producto_afectado,cf.npctxcat,
						  dc.clase as clase_cf 
						  from p
						  inner join  cf on p.swProdReleaseId=cf.id_Prod_CRM   --- catálogo descuento raiz que debe aplicarse a nivel de cuenta (catálogo de producto descuento que se debe aplicar a cuenta segú n facturador
						  inner join dominioxclase dc on dc.dominio=cf.Dominio_dto and p.claseBilled=dc.clase
						  inner join  lp on lp.id_prod_crm=p.swProdReleaseId and case when lp.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=lp.Producto_afectado END and lp.linea_prod=cf.linea_prod 							
						  where DATE_DIFF(p.fecha_venta_d,EXTRACT(DATE FROM cf.Fecha_Activacion),  DAY) > 0 and Coalesce(DATE_DIFF(EXTRACT(DATE FROM cf.Fecha_Inactivacion),p.fecha_venta_d,  DAY) , 9999) >=0 									
						  --and swBuzonId=22234850
						  order by idreg, swBuzonId, swInstProdId; 




						---- Población de catálogos de productos asignados a las líneas de producto definidas en Arbor 

							--select distinct coalesce(linea_prod,"NOINF"), id_prod_crm, nombre_CRM, nombre_arbor	from `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_RES` order by 1,2
							
							
						---- Cuotas sobre las que se aplica el descuento:

				--- OUT 2.4.7.1: CU_DESCUENTOS_CUENTA_PREV_LVL_1_TMP
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1_TMP` as --- 4758
							with r as (
								select distinct cf.* , --c.* except(producto_afectado),
										Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, DurDescuento as DuracionPrDto, 
										coalesce(DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
										PermDescuento as PermanenciaPrDto, 
										PctmDescuento as PorcentajePrDto,
										coalesce(PctmDescuento,cf.Porcentaje_Dto) as PctDtoCom,
								from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV` as cf 
								--inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO` c
								--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
								/*ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE*/
								--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
								/*FIN MODIFICACION*/				
								--on cf.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE cf.swProdReleaseIdBilled=c.Producto_afectado END and cf.lvl=1 and cf.swInstProdIdBilled is not null and cf.clase="DESCUENTOS_CLIENTES_OBJETIVO"
								--left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=cf.swBuzonId and pr.swCustomerId=cf.swCustomerId and pr.swInstProdId=cf.swInstProdIdBilled
								--where DATE_DIFF(cf.fecha_venta_d,EXTRACT(DATE FROM c.Fecha_Activacion),  DAY) > 0 and Coalesce(DATE_DIFF(EXTRACT(DATE FROM Fecha_Inactivacion),cf.fecha_venta_d,  DAY) , 9999) >=0
								---and idreg=141820549 -and swInstProdIdBilled=141820123
							) select distinct r.* except(PctDtoCom, Porcentaje_dto), 
							max(PctDtoCom) over(partition by swBuzonId, swCustomerId,swInstProdId ) as PctDtoCom,  
							max(PctDtoCom) over(partition by swBuzonId, swCustomerId,swInstProdId ) as Porcentaje_dto 
							from r;

						    --- OUT 2.4.7.1: CU_DESCUENTOS_CUENTA_PREV_LVL_1_DES
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1_DES` as	--- 5617 ---6208 --5393	---4765	
							with p as ( --9118
									---  poblacion de todas las cuotas que pueden se asignadas a descuentos en raiz
									select distinct p.*, l.claseBilled, l.swInstProdIdBilled, l.swProdReleaseIdBilled, l.swReleaseNameBilled, 
									lv1.clase as claseDesc, lv1.idreg as idregDesc, lv1.lvl as lvlDesc, lv1.swProductType  as swProductTypeDesc, 
									lv1.swInstProdId  as swInstProdIdDesc, lv1.swProdReleaseId as  swProdReleaseIdDesc, lv1.swReleaseName as  swReleaseNameDesc, lv1.swFacturable as swFacturableDesc,
									lv1.Orden_plan_dto, lv1.orden_dto, lv1.DuracionPrDto, lv1.DurDtoCom,lv1.PermanenciaPrDto, lv1.Porcentaje_Dto, lv1.PorcentajePrDto, lv1.PctDtoCom,
									from `mm-commissions-reporting.KRT_CAP_PYME.ARBORxARBOL_PRODUCTOS_EKTNET_PREV` p 
									inner join  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1_TMP` lv1 on lv1.swBuzonId=p.swBuzonId and  lv1.swInstProdIdBilled=p.swInstProdId  and lv1.swContratoFisicoId=p.swContratoFisicoId -- and  lv1.swBuzonId=20891368
									inner join `mm-commissions-reporting.KRT_CAP_PYME.LOG_0301_ARBORxARBOL_PRODUCTOS_EKTNET_LIST_REC` l  on l.swBuzonId=p.swBuzonId and l.idreg=p.idreg and l.swInstProdId=p.swInstProdId and l.swContratoFisicoId=p.swContratoFisicoId						   
													   
							)select distinct p.* /*except(swProdReleaseIdDesc, swReleaseNameDesc, claseDesc)*/, --c.* except(producto_afectado, Porcentaje_dto,Lim_Inferior_Bandas, Lim_Superior_Bandas), 
							/*
							Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end as DuracionDto, pr.DurDescuento as DuracionPrDto, 
							coalesce(pr.DurDescuento,Case when Duracion="0" then NULL else Cast(split(Duracion," ")[Offset(0)] As int64) end )as DurDtoCom,
							pr.PermDescuento as PermanenciaPrDto, 
							pr.PctmDescuento as PorcentajePrDto,
							coalesce(pr.PctmDescuento,p.Porcentaje_Dto) as PctDtoCom, 
							p.Porcentaje_Dto*/
							from  p 
							--inner join `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_TRG` c
							--inner join `mm-commissions-reporting.KRT_CAP_PYME.ARBOR_CAT_DESCUENTOS_OBJETIVO` c
							--on p.swProdReleaseId=c.Id_Prod_CRM and p.swProdReleaseIdBilled=c.Producto_afectado and p.clase="DESCUENTOS_CLIENTES_OBJETIVO";	
							--ELIMINO MODIFICACION PARA INCLUIR DESCUENTOS DESDE CUENTA YA QUE ESTOS LOS TRATAMOS APARTE--
							--on p.swProdReleaseId=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE case when p.swProdReleaseIdBilled is null then TRUE  ELSE p.swProdReleaseIdBilled=c.Producto_afectado END END and p.clase="DESCUENTOS_CLIENTES_OBJETIVO"				
							--FIN MODIFICACION--
							--on p.swProdReleaseIdDesc=c.Id_Prod_CRM and case when c.Producto_afectado=0 then TRUE ELSE p.swProdReleaseIdBilled=c.Producto_afectado END and p.lvl>1 and p.swInstProdIdBilled is not null and p.claseDesc="DESCUENTOS_CLIENTES_OBJETIVO"
							left join `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` pr on pr.swBuzonId=p.swBuzonId and pr.swCustomerId=p.swCustomerId and pr.swInstProdId=p.swInstProdId  and p.swContratoFisicoId=pr.swContratoFisicoId
							where p.claseBilled is not null 
							and contains_substr(p.claseBilled,"uota")
							and contains_substr(p.clase,"uota")
							and p.clase=p.claseBilled
							and p.swProdReleaseId=p.swProdReleaseIdBilled
							order by swInstProdId;


							
							---select swbuzonid, swInstProdIdBilled, count(swInstProdId) as ns from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1_DES` group by 1,2 having count(swInstProdIdBilled) >1;
							
				--- OUT 2.4.7.1: CU_DESCUENTOS_CUENTA_PREV_LVL_1
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1` as	 -- 5353	-- 6208	 -5393	--4765	
							select distinct * except(Orden_plan_dto, Orden_dto, Porcentaje_Dto, PorcentajePrDto,PctDtoCom), 
							max(Orden_dto) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as Orden_dto,
							max(Orden_plan_dto) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as Orden_plan_dto,														
							max(PorcentajePrDto) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as PorcentajePrDto,
							max(PctDtoCom) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as PctDtoCom,
							max(Porcentaje_Dto) over(partition by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled order by clase, swcustomerId, swBuzonId, idreg, lvl, swInstProdId,swInstProdIdBilled ) as Porcentaje_Dto				
							from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1_DES`
							order by swInstProdId;

						    --- OUT 2.4.7: CU_DESCUENTOS_CUENTA_TMP
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_TMP` as
							select distinct p.*, 
							c.id_Prod_CRM,c.Nivel_aplicacion, c.Tipo_dto, c.Dominio_Dto, c.Linea_Prod, c.Duracion, c.Fecha_Activacion, c.Fecha_Inactivacion,c.Producto_afectado, 
							c.tipo_restriccion as tipo_objeto, c.Datos_restriccion as Datos_objeto, 
							count(distinct c.Porcentaje_Dto) OVER(PARTITION BY c.Id_Prod_CRM, c.producto_afectado)  as npctxcat --except(c.Porcentaje_Dto) 
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1` p
							--left join  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_PREV_LVL_1_TMP` lv1 on lv1.swInstProdIdBilled=p.swInstProdId
							left join  `mm-commissions-reporting.KRT_CAP_PYME.PARAM_FACT_DESCUENTOS_CL_RES` c on c.id_Prod_Crm=p.swProdReleaseIdDesc;

							--Pendiente recrear algunos campos	
							UPDATE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_TMP` 
							SET clase=claseDesc,idreg=idregDesc,lvl=lvlDesc,swProductType=swProductTypeDesc,swInstProdId=swInstProdIdDesc, swProdReleaseId=swProdReleaseIdDesc, swReleaseName=swReleaseNameDesc, 
							swFacturable=swFacturableDesc, swParentInstProdId=CAST(NULL AS INT64),  swReleaseNameParent=CAST(NULL as string)  
							where 1=1;


			--- PASO 2.4.8: Integración de descuentos

			--- OUT 2.4.8: CU_DESCUENTOS_TOTALES_TMP
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES_TMP` as						
							select distinct "SERVICIO" as tipoDescuento, clase, claseBilled, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bPrSohoPrevio, bBuzonConBajas, idreg, lvl, swBuzonId, swCustomerId, swAgreementId, swContratoFisicoId, swTipoProducto, 
							swTipoRec, swProductType, swInstProdId, swProdReleaseId, swReleaseName, swFacturable, fecha_venta_d, fecha_venta_id, fecha_rfb_d, fecha_rfb_id, fecha_baja_d, fecha_baja_id, nDaysAct, 
							swMasterInstProdId, swProdOrigId, swParentInstProdId, swProdReleaseIdParent, swReleaseNameParent, swInstProdIdBilled, swProdReleaseIdBilled, swReleaseNameBilled, 
							swInstProdIdRoot, swProdReleaseIdRoot, swReleaseNameRoot, Id_Prod_CRM, Linea_Prod, Fecha_Activacion, Fecha_Inactivacion, Dominio_Dto, Tipo_Dto, Nivel_aplicacion, Orden_Dto, Orden_plan_Dto, 
							PermanenciaPrDto, Duracion, DuracionPrDto, DurDtoCom, npctxcat, Porcentaje_Dto, PorcentajePrDto, PctDtoCom
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_OBJETIVO_TMP` 
							UNION ALL
							select distinct "CUENTA" as tipoDescuento, clase, claseBilled, bMarcaCheck, bClienteCaptado, bBuzonSohoPrevio, bPrSohoPrevio, bBuzonConBajas, idreg, lvl, swBuzonId, swCustomerId, swAgreementId, swContratoFisicoId, swTipoProducto, 
							swTipoRec, swProductType, swInstProdId, swProdReleaseId, swReleaseName, swFacturable, fecha_venta_d, fecha_venta_id, fecha_rfb_d, fecha_rfb_id, fecha_baja_d, fecha_baja_id, nDaysAct, 
							swMasterInstProdId, swProdOrigId, swParentInstProdId, swProdReleaseIdParent, swReleaseNameParent, swInstProdIdBilled, swProdReleaseIdBilled, swReleaseNameBilled, 
							swInstProdIdRoot, swProdReleaseIdRoot, swReleaseNameRoot, Id_Prod_CRM, Linea_Prod, Fecha_Activacion, Fecha_Inactivacion, Dominio_Dto, Tipo_Dto, Nivel_aplicacion, Orden_Dto, Orden_plan_Dto, 
							PermanenciaPrDto, Duracion, DuracionPrDto, DurDtoCom, npctxcat, Porcentaje_Dto, PorcentajePrDto, PctDtoCom
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_CUENTA_TMP`; 							


						    --- OUT 2.4.8: CU_DESCUENTOS_TOTALES_EXCLUIDOS_NDAYS_0
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES_EXCLUIDOS_NDAYS_0` as						
							select * from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES_TMP` where nDaysAct=0;

						    --- OUT 2.4.8: CU_DESCUENTOS_TOTALES
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES` as	
							SELECT * FROM  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES_TMP`  t
							WHERE NOT EXISTS (
							  select 1 from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES_EXCLUIDOS_NDAYS_0` n 
							  where n.swBuzonid=t.swBuzonid and n.swCustomerid=t.swCustomerid and n.swInstProdId=t.swInstProdId and n.swInstProdIdBilled=t.swInstProdIdBilled
							);

							

						/*
						--- Función analítica para calcular el pct de descuento que se aplica a cada   
							
							with d as (
									--- Población de cuotas que tienene dos o mas 	
									--select swBuzonId, swInstProdId,swInstProdIdBilled,claseBilled, count(swCustomerId) as ns
									select swBuzonId, swInstProdIdBilled,clase, claseBilled, count(swCustomerId) as ns		
									from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES` 
									--group by 1,2,3,4
									group by 1,2,3,4 
									having  count(swCustomerId)>1
									--order by 5 desc,1,2,3
									order by 5 desc,1,2,3
							) --select t.*,  LAG(t.PctDtoCom) over(PARTITION BY t.swBuzonId, t.swInstProdId, t.swInstProdIdBilled ORDER BY t.Orden_dto asc ) as Prev
							select t.*, 
							LAG(t.PctDtoCom) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled ORDER BY t.PctDtoCom desc ) as PctDtoComPrev,
							ROW_NUMBER()  over(PARTITION BY t.swBuzonId , t.claseBilled, t.swInstProdIdBilled ORDER BY  t.PctDtoCom desc ) as DtoOrder,
							from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES` t
							--inner join d on d.swBuzonId=t.swBuzonId and  d.swInstProdId=t.swInstProdId and d.swInstProdIdBilled=t.swInstProdIdBilled
							inner join d on d.swBuzonId=t.swBuzonId and d.swInstProdIdBilled=t.swInstProdIdBilled and d.claseBilled=t.claseBilled
							--where t.swInstProdIdBilled=141838271
							where t.swBuzonId=20264381
							order by t.swBuzonId,  t.claseBilled, t.swInstProdIdBilled, PctDtoCom desc, t.tipoDescuento;

						*/	
							
							

			--- PASO 2.4.9: Calculo del descuento acumulado en 12 Meses 
				
					
				---	PASO 2.4.9.1: Recreo tabla que despeina los descuentos activos por mes.
				---	OUT 2.4.9.1: CU_DESCUENTOS_TOTALESxMES_TMP
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_TMP` as 
						with imes as (
									select imes from UNNEST([1,2,3,4,5,6,7,8,9,10,11,12]) as imes
						) select --t.swInstProdId,t.swInstProdIdBilled,t.DurDtoCom, m.imes, t.tipoDescuento
						t.*, m.imes
						from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALES` t 
						inner join imes m on  m.imes<=coalesce(t.DurDtoCom,999)
						--where t.swInstProdId=25556163
						order by t.swInstProdIdBilled, t.swInstProdId, m.imes;


				---	PASO 2.4.9.2: Borro los descuentos asociados a cuotas de alta, que hayan podido recrearse con más de 1 mes
				---	OUT 2.4.9.2: CU_DESCUENTOS_TOTALESxMES_EXCLUIDOS_IMES_NO_1						
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_EXCLUIDOS_IMES_NO_1` as 
						SELECT * FROM  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_TMP` where contains_substr(claseBilled,"ALTA") and imes>1;
						
						DELETE FROM  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_TMP` where contains_substr(claseBilled,"ALTA") and imes>1;


						---- PDTE CREAR PORCENTAJE DE DTO POR PRODUCTO Y MES COMO RESULTADO DEL ACUMULADO DEL MES Y DEL PREVIO, en caso de excederse de 100, se imputa la diferencia
						
				---	OUT 2.4.9.2: CU_DESCUENTOS_TOTALESxMES_DES						
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_DES` as 
						/*with t as (
								select t.*, 
								LAG(t.PctDtoCom) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) as PctDtoComPrev,
								ROW_NUMBER()  over(PARTITION BY t.swBuzonId , t.claseBilled, t.swInstProdIdBilled, t.imes ORDER BY  t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) as DtoOrder
								from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_TMP` t
								--inner join d on d.swBuzonId=t.swBuzonId and  d.swInstProdId=t.swInstProdId and d.swInstProdIdBilled=t.swInstProdIdBilled
								--inner join d on d.swBuzonId=t.swBuzonId and d.swInstProdIdBilled=t.swInstProdIdBilled and d.claseBilled=t.claseBilled
								--where t.swInstProdIdBilled=141838271
								--where t.swBuzonId=20264381
								order by t.swBuzonId,  t.claseBilled, t.swInstProdIdBilled, PctDtoCom desc, t.tipoDescuento
						) select t.*, 
						case when t.PctDtoCom + coalesce(t.PctDtoComPrev,0) <=100 THEN (t.PctDtoCom + coalesce(t.PctDtoComPrev,0)) else (100- t.PctDtoComPrev) END as PctDtoAplicar,
						t.PctDtoCom + coalesce(t.PctDtoComPrev,0) as PctDtoAcumulado
						from t
						order by t.swBuzonId,  t.claseBilled, t.swInstProdIdBilled, PctDtoCom desc, t.tipoDescuento;*/
						/*with t as (
								select t.*, 
								Coalesce(LAG(coalesce(t.PctDtoCom,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) ,0)as PctDtoComPrev,
								sum(PctDtoCom) over(PARTITION BY t.swBuzonId , t.claseBilled, t.swInstProdIdBilled, t.imes ORDER BY  t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ROWS between Unbounded Preceding and current row) as PctDtoComAc,                         
								--(coalesce(t.PctDtoCom,0) +Coalesce(LAG(coalesce(t.PctDtoCom,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) ,0)) as PctDtoComAc,
								ROW_NUMBER()  over(PARTITION BY t.swBuzonId , t.claseBilled, t.swInstProdIdBilled, t.imes ORDER BY  t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) as DtoOrder
								from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_TMP` t
								--inner join d on d.swBuzonId=t.swBuzonId and  d.swInstProdId=t.swInstProdId and d.swInstProdIdBilled=t.swInstProdIdBilled
								--inner join d on d.swBuzonId=t.swBuzonId and d.swInstProdIdBilled=t.swInstProdIdBilled and d.claseBilled=t.claseBilled
								--where t.swInstProdIdBilled=137264439
								--where t.swBuzonId=20264381
								--and imes=12
								order by t.swBuzonId,  t.claseBilled, t.swInstProdIdBilled, PctDtoComAc asc, t.tipoDescuento
						) select t.*, 
						LAG(coalesce(t.PctDtoComAc,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) as PctDtoAcComPrev,            
						case when t.PctDtoComAc <=100 THEN t.PctDtoCom else 100 - LAG(coalesce(t.PctDtoComAc,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) END as PctDtoAplicar,
						--t.PctDtoComAc 
						from t
						--where t.swInstProdIdBilled=137264439
						--and imes=12
						order by t.swBuzonId,  t.claseBilled, t.swInstProdIdBilled, PctDtoCom desc, DtoOrder, t.tipoDescuento;*/
						
						with t as (
								select t.*, 
								Coalesce(LAG(coalesce(t.PctDtoCom,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) ,0)as PctDtoComPrev,
								sum(PctDtoCom) over(PARTITION BY t.swBuzonId , t.claseBilled, t.swInstProdIdBilled, t.imes ORDER BY  t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ROWS between Unbounded Preceding and current row) as PctDtoComAc,                         
								--(coalesce(t.PctDtoCom,0) +Coalesce(LAG(coalesce(t.PctDtoCom,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) ,0)) as PctDtoComAc,
								ROW_NUMBER()  over(PARTITION BY t.swBuzonId , t.claseBilled, t.swInstProdIdBilled, t.imes ORDER BY  t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) as DtoOrder
								from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_TMP` t
								--inner join d on d.swBuzonId=t.swBuzonId and  d.swInstProdId=t.swInstProdId and d.swInstProdIdBilled=t.swInstProdIdBilled
								--inner join d on d.swBuzonId=t.swBuzonId and d.swInstProdIdBilled=t.swInstProdIdBilled and d.claseBilled=t.claseBilled
								--where t.swInstProdIdBilled=137264439
								--where t.swBuzonId=20264381
								--and imes=12
								order by t.swBuzonId,  t.claseBilled, t.swInstProdIdBilled, PctDtoComAc asc, t.tipoDescuento
						) select t.*, 
						LAG(coalesce(t.PctDtoComAc,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) as PctDtoAcComPrev,            
						case when t.PctDtoComAc <=100 THEN t.PctDtoCom                  
							 else 
								  case when (100 - LAG(coalesce(t.PctDtoComAc,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) )> 0 
									   then  (100 - LAG(coalesce(t.PctDtoComAc,0)) over(PARTITION BY t.swBuzonId, t.claseBilled , t.swInstProdIdBilled, t.imes ORDER BY t.imes, t.PctDtoCom desc, coalesce(DurDtoCom,999) desc ) )
								  else 0
								  END 
						END as PctDtoAplicar,
						--t.PctDtoComAc 
						from t
						--where t.swInstProdIdBilled=140777587
						--and imes=12
						order by t.swBuzonId,  t.claseBilled, t.swInstProdIdBilled, PctDtoCom desc, DtoOrder, t.tipoDescuento;




				---	OUT 2.4.9.2: CU_DESCUENTOS_TOTALESxMES						
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES` as 
						SELECT * FROM  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_DES`;
						--SELECT * FROM  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES_DES` where PctDtoAcumulado<=100;


				---	OUT 2.4.9.2: CU_DESCUENTOS_TOTALESxFLUJOxMES						
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMES` as 
						select distinct c.*,
						r.fecha_buzon_d, r.osFlujoProvId,r.osFlujoProvCatId,r.osNombre,r.osAccion, r.osEstado,r.fecha_flujo_d, r.prAccion
						from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES` as c
						inner join `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` r on r.swCustomerId=c.swCustomerId  and r.swBuzonId= c.swBuzonId and r.swInstProdId=c.swInstProdIdBilled
						order by 1,2;

						
						

				---- PASO 2.4.9.5: Creo tablas que despeinan las cuatas activas por mes.

					---- PASO 2.4.9.5.1: Creo tabla de cuotas de alta por mes
							CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxMES` as 
							select --t.swInstProdId,t.swInstProdIdBilled,t.DurDtoCom, m.imes, t.tipoDescuento
							t.*,  1 as imes
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTA_TMP` t; 

							CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES` as 
							select distinct c.*,
							r.fecha_buzon_d,r.osFlujoProvId,r.osFlujoProvCatId,r.osNombre,r.osAccion, r.osEstado,r.fecha_flujo_d, r.prAccion 
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxMES` as c
							inner join `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` r on r.swCustomerId=c.swCustomerId  and r.swBuzonId= c.swBuzonId and r.swInstProdId=c.swInstProdId
							order by 1,2;
							

							CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0495_CU_CUOTAS_ALTAxFLUJOxMES_DUP` AS 
							with dup as (
									select swBuzonId, swCustomerId, swAgreementId,swInstPRodId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bPrSohoPrevio,sum(importe) as imp_cuotas_alta, count(importe) as np
									from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES`
									where not contains_substr(osEstado,"Anulado")
									group by 1,2,3,4,5,6,7,8
									having count(importe)>1
							)select dup.np, c.swInstProdId, c.* except(swInstProdId)
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES` c
							inner join dup on dup.swInstProdId=c.swInstProdId
							order by dup.np desc, c.swInstProdId asc, c.fecha_venta_d, c.fecha_flujo_d;


							/*select distinct swBuzonId, swInstPRodId,swReleaseName, osFlujoProvId, osFlujoProvCatId,osNombre,osAccion, osEstado, fecha_buzon_d, fecha_venta_d, fecha_flujo_d, fecha_rfb_d, fecha_baja_d, prAccion 
							from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0495_CU_CUOTAS_ALTAxFLUJOxMES_DUP` 
							where np=6;
							*/
							
					----	PASO 2.4.9.5.2: Creo tabla de cuotas mensuales por mes
							CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxMES` as 
							with imes as (
										select imes from UNNEST([1,2,3,4,5,6,7,8,9,10,11,12]) as imes
							) select --t.swInstProdId,t.swInstProdIdBilled,t.DurDtoCom, m.imes, t.tipoDescuento
							t.*, m.imes
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALES_TMP` t 
							inner join imes m on  1=1
							--where t.swInstProdId=25556163
							order by t.swInstProdIdBilled, t.swInstProdId, m.imes;


							CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxFLUJOxMES` as 
							select distinct c.*,
							r.fecha_buzon_d, r.osFlujoProvId,r.osFlujoProvCatId,r.osNombre,r.osAccion, r.osEstado,r.fecha_flujo_d, r.prAccion						
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxMES` as c
							inner join `mm-commissions-reporting.KRT_CAP_PYME.CLIENTESxBUZONESxFLUJOSxPRODUCTOS_EKTNET` r on r.swCustomerId=c.swCustomerId  and r.swBuzonId= c.swBuzonId and r.swInstProdId=c.swInstProdId
							order by 1,2;


							CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0495_CU_CUOTAS_MENSUALESxFLUJOxMES_DUP` AS 
							with dup as (
									select swBuzonId, swCustomerId, swAgreementId,swInstPRodId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bPrSohoPrevio,sum(importe) as imp_cuotas_alta, count(importe) as np
									from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES`
									where not contains_substr(osEstado,"Anulado")
									group by 1,2,3,4,5,6,7,8
									having count(importe)>1
							)select dup.np, c.swInstProdId, c.* except(swInstProdId)
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxFLUJOxMES` c
							inner join dup on dup.swInstProdId=c.swInstProdId
							order by dup.np desc, c.swInstProdId asc, c.fecha_venta_d, c.fecha_flujo_d;


							/*select distinct swBuzonId, swInstPRodId,swReleaseName, osFlujoProvId, osFlujoProvCatId,osNombre,osAccion, osEstado, fecha_buzon_d, fecha_venta_d, fecha_flujo_d, fecha_rfb_d, fecha_baja_d, prAccion 
							from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0495_CU_CUOTAS_ALTAxFLUJOxMES_DUP` 
							where np=6;
							*/

				--- PASO 2.4.9.7: Creo tablas que despeinan los descuentos configurados por mes.

					---	PASO 2.4.9.7.1: Creo tabla descuento, con importe asociado

							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMESxIMPORTE` as
							select distinct d.*, SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoAplicar,100)) as importe 										
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxMES` d
							left join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxMES` ca on ca.swInstProdId=d.swInstProdIdBilled and ca.imes=d.imes
							left join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxMES` cm on cm.swInstProdId=d.swInstProdIdBilled  and cm.imes=d.imes
							where not (d.claseBilled="CUOTAS" and contains_substr(d.Dominio_Dto,"ALTA") /*and contains_substr(d.Datos_Target_agg,"ALTA")*/)	;
							
							/*
							CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMESxIMPORTE` as
							select distinct d.*, SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoAplicar,100)) as importe 
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMES` d
							left join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES` ca on ca.swInstProdId=d.swInstProdIdBilled and ca.imes=d.imes and ca.osFlujoProvId=d.osFlujoProvId
							left join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxFLUJOxMES` cm on cm.swInstProdId=d.swInstProdIdBilled  and cm.imes=d.imes and cm.imes=d.imes and cm.osFlujoProvId=d.osFlujoProvId
							where not (d.claseBilled="CUOTAS" and contains_substr(d.Dominio_Dto,"ALTA") --and contains_substr(d.Datos_Target_agg,"ALTA")
							)	;
							*/
							
							
							CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMESxIMPORTE_TMP` AS 
							select distinct d.*,
							coalesce(cm.importe,ca.importe) as cuotain,
							SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100)) as impuni_lin,  
							coalesce(cm.importe,ca.importe) + SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100)) as coutaout_lin,
							SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100)) as importe_prev,
							coalesce(cm.importe,ca.importe) + SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100)) as cuotaout_prev,
							SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100)) as importe,
							SAFE_MULTIPLY(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100)) as cuota
							--coalesce(LAG(SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)) over(PARTITION BY(swBuzonId,swCustomerId,swInstProdIdBilled,imes) ORDER BY PctDtoCom asc),SAFE_DIVIDE(PctDtoCom,100)),SAFE_MULTIPLY(-1, coalesce(cm.importe,ca.importe)),SAFE_DIVIDE(PctDtoCom,100) )
							from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMES` d
							left join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES` ca on ca.swBuzonId=d.swBuzonId and ca.claseBilled=d.claseBilled and ca.swInstProdId=d.swInstProdIdBilled and ca.imes=d.imes and ca.osFlujoProvId=d.osFlujoProvId and ca.prAccion=d.prAccion
							left  join `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxFLUJOxMES` cm on  cm.swBuzonId=d.swBuzonId and cm.claseBilled=d.claseBilled and cm.swInstProdId=d.swInstProdIdBilled  and cm.imes=d.imes and cm.osFlujoProvId=d.osFlujoProvId and cm.prAccion=d.prAccion
							where not (d.claseBilled="CUOTAS" and contains_substr(d.Dominio_Dto,"ALTA")
							/*and contains_substr(d.Datos_Target_agg,"ALTA")*/)	
							--and d.swBuzonId=22393709 and d.swInstProdIdBilled=115370324 and d.imes=12
							--and d.swBuzonId=20891368 and d.swInstProdIdBilled=132964959 and d.imes=12
							order by d.swBuzonId, d.claseBilled, d.osFlujoProvId, d.swInstProdIdBilled, d.DtoOrder, d.imes asc; 



							CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMESxIMPORTE` AS 
							with recursive rec as (
								select distinct o.* except(cuotain, impuni_lin, coutaout_lin, cuotaout_prev, importe_prev, importe, cuota), o.cuotain, o.importe, (o.cuotain + o.importe) as cuota,  o.importe as importe_ac
								from  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMESxIMPORTE_TMP` o
								WHERE o.DtoOrder=1 
								--and o.swBuzonId=20891368 and o.swInstProdIdBilled=132964959 and o.imes=12
								--and o.swBuzonId=20891368 and o.swInstProdIdBilled=132964959 and o.imes=12
				  --and o.swBuzonId=22393709 and o.swInstProdIdBilled=115370324 and o.imes=12
								--order by o.swBuzonId, o.claseBilled, o.osFlujoProvId, o.swInstProdIdBilled, o.DtoOrder, o.imes asc		
								union ALL		
								select c.* except(cuotain, impuni_lin, coutaout_lin, cuotaout_prev, importe_prev, importe, cuota),
								r.cuota,
								SAFE_MULTIPLY(-1, SAFE_MULTIPLY(r.cuota, SAFE_DIVIDE(c.PctDtoCom,100))),
								r.cuota+SAFE_MULTIPLY(-1, SAFE_MULTIPLY(r.cuota, SAFE_DIVIDE(c.PctDtoCom,100))),
								r.importe_ac+SAFE_MULTIPLY(-1, SAFE_MULTIPLY(r.cuota, SAFE_DIVIDE(c.PctDtoCom,100))),
								--SAFE_MULTIPLY(-1, SAFE_MULTIPLY(r.cuota, SAFE_DIVIDE(c.PctDtoCom,100))),
								--r.coutaout_lin, r.cuotaout_prev, r.importe_prev, r.importe, r.cuota
								from rec r 
								inner join  `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMESxIMPORTE_TMP` c
								on c.swCustomerId=r.swCustomerId
								and c.swBuzonId=r.swBuzonId 
								and c.claseBilled=r.claseBilled and c.osFlujoProvId=r.osFlujoProvId 
								and c.swInstProdIdBilled=r.swInstProdIdBilled  
								and c.imes=r.imes and c.prAccion=r.prAccion
								and c.DtoOrder=r.DtoOrder+1
								where r.DtoOrder <10
								--order by c.swBuzonId, c.claseBilled, c.osFlujoProvId, c.swInstProdIdBilled, c.DtoOrder, c.imes asc 		
							) select distinct * 
							from rec
							order by rec.swBuzonId, rec.claseBilled, rec.osFlujoProvId, rec.swInstProdIdBilled, rec.DtoOrder, rec.imes asc;
		
	


	--- PASO 3: CALCULO DEL ARPU_1M 

		---	 	REPENSAR EL CALCULO DEL VALOR DE LA VARIABLE B_CLIENTE_CAPTADO
		---			EN EL PARADIGMA DE CAPTACION BASADA EN BIZONES DE AUDITORIA PREVENTA EL CALCULO DE ESTA VARIABLE ERA SENCILLO YA QUE AFECTABA AL PRIMER BUZON INSTANCIADO PORDUPLA CLIENTE - AGREEMENT
		---			EN EL NUEVO PARADIGMA EL CALCULO DEL VALOR DE LA VARIABLE SE COMPICA YA QUE LA VARIABLE SE PUEDE ASIGNAR A LA SECUENCIA DE BUZONES INSTANCIADOS TRANSCURRIDOS HASTA DOS MESES DESPUES DEL INSTANCIADO DEL PRIMER BUZON DE UN CLIENTE

		---		REPENSAR CALCULO DEL ARPU
		---		CALCULO DE ARPU EN OPERACIONES QUE NO IMPLICAN MIGRACIÓN: ARPU_1M SEGMENTADO POR BUZON PARA TODOS LOS BUZONES NO RELACIONADOS CON MIGRACIONES (MARCA BBUZONSOHOPREVIO=0)
		---			CAPTACION: 
		---				NUEVOS CLIENTES: FILTRADO DE REGISTROS DE CAPTACIÓN (BCLIENTE_CAPTAD0=1)		
		---
		---			CARTERA:
		---				FILTRADO (BCLIENTE_CAPTAD0=0 Y MARCA CHECK=0)
		---
		---			CASO BCLIENTE_CAPTADO=0 Y MARCA_CHECK=1 --- REVISAR
		
		---		CALCULO DEL INCREMENTO DE ARPU EN OPERACIONES QUE IMPLICAN MIGRACION: CALCULO DEL ARPU_1M SEGMENTADO POR BUZON PARA TODOS LOS BUZONES RELACIONADOS CON MIGRACIONES (MARCA BBUZONSOHOPREVIO=1)
		---			CAPTACION: 
		---				NUEVOS CLIENTES: REVISAR DOS CASOS DE POTENCIALES REGISTROS DE CAPTACION (BCLIENTE_CAPTAD0=1) 	--- REVISAR		
		---				YA CLIENTES: FILTRADO DE REGISTROS DE CAPTACIÓN (BCLIENTE_CAPTAD0=0 Y MARCA CHECK=1)
		---
		---			CARTERA:
		---				FILTRADO (BCLIENTE_CAPTAD0=0 Y MARCA CHECK=0)
		
		

		--- PASO 3.1: CALCULO ARPU_1M DE BUZONES   (5711 buzones - 2661 sin bajas y 3050 con bajas)
			--- PASO 3.1.1: CALCULO ARPU_1M DE BUZONES SIN BAJAS DE PRODUCTOS   -> 2661 buzones		
			--- OUT  3.1.1: ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS_NO_BAJAS: Arpu calculado por buzón, en buzones sin operaciones de bajas de productos 

		
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS_NO_BAJAS` as 				
						With arpu as (
							with pr as (
								select distinct fecha_buzon_d, min(fecha_flujo_d) over(PARTITION BY swCustomerId, swBuzonId) as fecha_venta_d, swCustomerId, swNIE,swAgreementId,grbuzid, grbuzid_ind, swBuzonId, swClasificacion, swTipoRec, swTipoSol, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas,--bPrSohoPrevio, 
								canal_agrupado1_ds, subcanal_ds, swName,swSegmento, subsegmento_ds
								from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`	
								where not contains_substr(osEstado, "anulado")
								--and contains_substr(swTipoRec,'reventa')
								--and swcustomerid=7679032								
								--select distinct swBuzonId, swCustomerId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bPrSohoPrevio
								--from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
							), ca as (
								select swCustomerId, swAgreementId, swBuzonId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio,bBuzonConBajas, --bPrSohoPrevio,
								sum(importe) as imp_cuotas_alta
								from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES`
								where not contains_substr(osEstado, "anulado")
								--and swcustomerid=7679032
								group by 1,2,3,4,5,6,7--,8
							), cm as (
								select swCustomerId, swAgreementId, swBuzonId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio,bBuzonConBajas, --bPrSohoPrevio, 
								sum(importe) as imp_cuotas_mensuales
								from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxFLUJOxMES`
								where not contains_substr(osEstado, "anulado")
								--and swcustomerid=7679032
								--where bClienteCaptado=0
								group by 1,2,3,4,5,6,7---,8
							), d as (
								select swCustomerId, swAgreementId, swBuzonId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, --bPrSohoPrevio, 
								sum(importe) as imp_descuentos
								from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMESxIMPORTE`
								where not contains_substr(osEstado, "anulado")
								--and swcustomerid=7679032
								group by 1,2,3,4,5,6,7--,8
							) select ca.swCustomerId, pr.swNIE, ca.swAgreementId, pr.fecha_buzon_d, pr.fecha_venta_d,pr.grbuzid, pr.grbuzid_ind, ca.swBuzonid, pr.swClasificacion, pr.swTipoRec, pr.swTipoSol,ca.bMarcaCheck, ca.bClienteCaptado, ca.bBuzonSohoPrevio, ca.bBuzonConBajas, --ca.bPrSohoPrevio, 
							canal_agrupado1_ds, subcanal_ds, swName,swSegmento, subsegmento_ds,
							ROUND(coalesce(imp_cuotas_alta,0),2) as CUOTAS_ALTA, 
							ROUND(coalesce(imp_cuotas_mensuales,0),2) as CUOTAS_MENSUALES, 
							ROUND(coalesce(imp_descuentos,0),2) as DESCUENTOS, 
							ROUND((coalesce(imp_cuotas_alta,0) + coalesce(imp_cuotas_mensuales,0) + coalesce(imp_descuentos,0)),2) as ARPU_12M, 
							ROUND( SAFE_DIVIDE((coalesce(imp_cuotas_mensuales,0) ),12),2 ) as CMEN_1M,						
							ROUND( SAFE_DIVIDE((coalesce(imp_descuentos,0)),12),2 ) as DESC_1M,
							ROUND(SAFE_DIVIDE((coalesce(imp_cuotas_alta,0) + coalesce(imp_cuotas_mensuales,0) + coalesce(imp_descuentos,0)),12),2) as ARPU_1M							
							from pr
							left join ca on ca.swCustomerId=pr.swCustomerId and ca.swAgreementId=pr.swAgreementId and ca.swBuzonId=pr.swBuzonId and ca.bMarcaCheck=pr.bMarcaCheck and ca.bClienteCaptado=pr.bClienteCaptado and ca.bBuzonSohoPrevio=pr.bBuzonSohoPrevio --and ca.bPrSohoPrevio=pr.bBuzonSohoPrevio							
							left join cm on pr.swCustomerId=cm.swCustomerId and pr.swAgreementId=cm.swAgreementId and cm.swBuzonId=pr.swBuzonId and pr.bMarcaCheck=cm.bMarcaCheck and pr.bClienteCaptado=cm.bClienteCaptado and pr.bBuzonSohoPrevio=ca.bBuzonSohoPrevio --and pr.bPrSohoPrevio=cm.bBuzonSohoPrevio
							left join d on d.swCustomerId=pr.swCustomerId and d.swAgreementId=pr.swAgreementId and d.swBuzonId=pr.swBuzonId and d.bMarcaCheck=pr.bMarcaCheck and d.bClienteCaptado=pr.bClienteCaptado and d.bBuzonSohoPrevio=pr.bBuzonSohoPrevio --and d.bPrSohoPrevio=pr.bBuzonSohoPrevio							
							where cm.bBuzonSohoPrevio is not null
							and cm.bBuzonConBajas=0						
							/*and ca.bMarcaCheck=1
							and ca.bClienteCaptado=0*/
							/*cm.bClienteCaptado=1*/
							order by 17 asc
						), np as (
							select  swCustomerId, swBuzonId, swAgreementId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, --bPrSohoPrevio, 
							count(distinct if(contains_substr(categoria_servicio_ds,'BANDA ANCHA'), swInstProdId, NULL)) as nBA,
							count(distinct if(contains_substr(categoria_servicio_ds,'FIJA'), swInstProdId, NULL)) as nTF,						
							count(distinct if(contains_substr(categoria_servicio_ds,'MOVILES') or contains_substr(tipo_servicio_ds,'MOVIL'), swInstProdId, NULL)) as nTM,
							count(distinct if(contains_substr(categoria_servicio_ds,'TELEVISION'), swInstProdId, NULL)) as nTV,
							from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
							where not contains_substr(osEstado, "anulado")
							GROUP BY 1,2,3,4,5,6,7--,8
							ORDER BY 1,2,3,4,5,6,7--,8 
						) select --ROW_NUMBER() OVER(PARTITION BY a.grbuzid order  by a.grbuzid, a.grbuzid_ind) as ind,
						a.*, np.nBA, np.nTF, np.nTM, np.nTV
						from arpu a 
						left join np on np.swCustomerId=a.swCustomerId and np.swAgreementId=a.swAgreementId and np.swBuzonId=a.swBuzonId  and np.bMarcaCheck=a.bMarcaCheck and np.bClienteCaptado=a.bClienteCaptado and np.bBuzonSohoPrevio=a.bBuzonSohoPrevio --and np.bPrSohoPrevio=a.bPrSohoPrevio
						--where contains_substr(a.swName,"LANALDEN")
						--where a.swBuzonId in(21310157,21338139,20488425,20749742,21552755,21982444,21982444,21472389,20743985,20743985,21452610,21452610,21876154,21448087,20894153,21393669,21393669,21393669,20735966,21324203,20259881,20726491,20726491,20726491,21888751,21029859,21422880,21058155,21058155,21808038,21808038,21808038,20379628,20379628,22192488,20488425,21996952,21996952)
						--order by 2,3,4,1;
						--where a.swCustomerId=6875
						order by 1,2,3,7;
		
		
			--- PASO 3.1.2: CALCULO ARPU_1M DE BUZONES CON BAJAS DE PRODUCTOS   -> 3050 buzones
			--- OUT  3.1.2: ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS_SI_BAJAS: Arpu calculado por buzón, en buzones con operaciones de bajas de productos 


						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS_SI_BAJAS` as 
						With arpu as (
							with pr as (
								select distinct fecha_buzon_d, min(fecha_flujo_d) over(PARTITION BY swCustomerId, swBuzonId) as fecha_venta_d, swCustomerId, swNIE,swAgreementId, grbuzid, grbuzid_ind, swBuzonId, swClasificacion, swTipoRec, swTipoSol, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, --bPrSohoPrevio, 
								canal_agrupado1_ds, subcanal_ds, swName,swSegmento, subsegmento_ds
								from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`	
								where not contains_substr(osEstado, "anulado")
								--and contains_substr(swTipoRec,'reventa')
								--and swcustomerid=7679032								
								--select distinct swBuzonId, swCustomerId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bPrSohoPrevio
								--from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
							), ca as (
								select swCustomerId, swAgreementId, swBuzonId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, --bPrSohoPrevio, 
								sum(importe) as imp_cuotas_alta, sum(if(contains_substr(prAccion,"baja"),importe, NULL)) as imp_baja_cuotas_alta , sum(if(contains_substr(prAccion,"alta"),importe, NULL)) as imp_alta_cuotas_alta
								from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_ALTAxFLUJOxMES`
								where not contains_substr(osEstado, "anulado")
								and bBuzonConBajas=1
								--and swcustomerid=7679032
								group by 1,2,3,4,5,6,7
							), cm as (
								select swCustomerId, swAgreementId, swBuzonId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, --bPrSohoPrevio, 
								sum(importe) as imp_cuotas_mensuales, sum(if(contains_substr(prAccion,"baja"),importe, NULL)) as imp_baja_cuotas_mensuales , sum(if(contains_substr(prAccion,"alta"),importe, NULL)) as imp_alta_cuotas_mensuales
								from `mm-commissions-reporting.KRT_CAP_PYME.CU_CUOTAS_MENSUALESxFLUJOxMES`
								where not contains_substr(osEstado, "anulado")
								and bBuzonConBajas=1
								--and swcustomerid=7679032
								group by 1,2,3,4,5,6,7

							), d as (
								select swCustomerId, swAgreementId, swBuzonId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, --bPrSohoPrevio, 
								sum(importe) as imp_descuentos, sum(if(contains_substr(prAccion,"baja"),importe, NULL)) as imp_baja_descuentos , sum(if(contains_substr(prAccion,"alta"),importe, NULL)) as imp_alta_descuentos
								from `mm-commissions-reporting.KRT_CAP_PYME.CU_DESCUENTOS_TOTALESxFLUJOxMESxIMPORTE`
								where not contains_substr(osEstado, "anulado")
								--and swcustomerid=7679032
								group by 1,2,3,4,5,6,7
							) select distinct ca.swCustomerId,pr.swNIE, ca.swAgreementId, pr.fecha_buzon_d, pr.fecha_venta_d, pr.grbuzid, pr.grbuzid_ind, ca.swBuzonid, pr.swClasificacion, pr.swTipoRec, pr.swTipoSol,ca.bMarcaCheck, ca.bClienteCaptado, ca.bBuzonSohoPrevio, ca.bBuzonConBajas, --ca.bPrSohoPrevio, 
							canal_agrupado1_ds, subcanal_ds, swName,swSegmento, subsegmento_ds,
							--ROUND(coalesce(imp_cuotas_alta,0),2) as CUOTAS_ALTA, 
							--ROUND(coalesce(imp_cuotas_mensuales,0),2) as CUOTAS_MENSUALES, 
							--ROUND(coalesce(imp_descuentos,0),2) as DESCUENTOS, 

							ROUND(coalesce(imp_alta_cuotas_alta,0),2) as ALTA_CUOTAS_ALTA, 
							ROUND(coalesce(imp_alta_cuotas_mensuales,0),2) as ALTA_CUOTAS_MENSUALES, 
							ROUND(coalesce(imp_alta_descuentos,0),2) as ALTA_DESCUENTOS, 						
							ROUND(coalesce(imp_alta_cuotas_alta,0) + coalesce(imp_alta_cuotas_mensuales,0) + coalesce(imp_alta_descuentos,0),2) AS ALTA_ARPU_12M,
							ROUND(SAFE_DIVIDE(coalesce(imp_alta_cuotas_alta,0) + coalesce(imp_alta_cuotas_mensuales,0) + coalesce(imp_alta_descuentos,0),12),2) AS ALTA_ARPU_1M,
							
							ROUND(coalesce(imp_baja_cuotas_alta,0),2) as BAJA_CUOTAS_ALTA, 
							ROUND(coalesce(imp_baja_cuotas_mensuales,0),2) as BAJA_CUOTAS_MENSUALES, 
							ROUND(coalesce(imp_baja_descuentos,0),2) as BAJA_DESCUENTOS,
							ROUND(coalesce(imp_baja_cuotas_alta,0) + coalesce(imp_baja_cuotas_mensuales,0) + coalesce(imp_baja_descuentos,0),2) AS BAJA_ARPU_12M,							
							ROUND(SAFE_DIVIDE(coalesce(imp_baja_cuotas_alta,0) + coalesce(imp_baja_cuotas_mensuales,0) + coalesce(imp_baja_descuentos,0),12),2) AS BAJA_ARPU_1M,							
							
							ROUND(SAFE_DIVIDE(coalesce(imp_alta_cuotas_alta,0) + coalesce(imp_alta_cuotas_mensuales,0) + coalesce(imp_alta_descuentos,0),12),2) - 
							ROUND(SAFE_DIVIDE(coalesce(imp_baja_cuotas_alta,0) + coalesce(imp_baja_cuotas_mensuales,0) + coalesce(imp_baja_descuentos,0),12),2) AS VAR_ARPU_1M,

							ROUND(SAFE_DIVIDE(coalesce(imp_alta_cuotas_alta,0),2) - ROUND(coalesce(imp_baja_cuotas_alta,0),12),2) as VAR_CUOTAS_ALTA_1M,
							ROUND(SAFE_DIVIDE(coalesce(imp_alta_cuotas_mensuales,0),2) - ROUND(coalesce(imp_baja_cuotas_alta,0),12),2) as VAR_CUOTAS_MENSUALES_1M, 							
							ROUND(SAFE_DIVIDE(coalesce(imp_alta_descuentos,0),2) - ROUND(coalesce(imp_baja_descuentos,0),12),2) as VAR_DESCUENTOS_1M,	

							
							--ROUND((coalesce(imp_cuotas_alta,0) + coalesce(imp_cuotas_mensuales,0) + coalesce(imp_descuentos,0)),2) as ARPU_12M, 
							--ROUND( SAFE_DIVIDE((coalesce(imp_cuotas_mensuales,0) ),12),2 ) as CMEN_1M,						
							--ROUND( SAFE_DIVIDE((coalesce(imp_descuentos,0)),12),2 ) as DESC_1M,
							--ROUND(SAFE_DIVIDE((coalesce(imp_cuotas_alta,0) + coalesce(imp_cuotas_mensuales,0) + coalesce(imp_descuentos,0)),12),2) as ARPU_1M							
							from pr
							left join ca on ca.swCustomerId=pr.swCustomerId and ca.swAgreementId=pr.swAgreementId and ca.swBuzonId=pr.swBuzonId and ca.bMarcaCheck=pr.bMarcaCheck and ca.bClienteCaptado=pr.bClienteCaptado and ca.bBuzonSohoPrevio=pr.bBuzonSohoPrevio  and ca.bBuzonConBajas=pr.bBuzonConBajas --and ca.bPrSohoPrevio=pr.bBuzonSohoPrevio							
							left join cm on pr.swCustomerId=cm.swCustomerId and pr.swAgreementId=cm.swAgreementId and cm.swBuzonId=pr.swBuzonId and pr.bMarcaCheck=cm.bMarcaCheck and pr.bClienteCaptado=cm.bClienteCaptado and pr.bBuzonSohoPrevio=cm.bBuzonSohoPrevio  and pr.bBuzonConBajas=cm.bBuzonConBajas --and pr.bPrSohoPrevio=cm.bBuzonSohoPrevio
							left join d on d.swCustomerId=pr.swCustomerId and d.swAgreementId=pr.swAgreementId and d.swBuzonId=pr.swBuzonId and d.bMarcaCheck=pr.bMarcaCheck and d.bClienteCaptado=pr.bClienteCaptado and d.bBuzonSohoPrevio=pr.bBuzonSohoPrevio  and d.bBuzonConBajas=pr.bBuzonConBajas --and d.bPrSohoPrevio=pr.bBuzonSohoPrevio							
							where cm.bBuzonSohoPrevio is not null
							/*ca.bMarcaCheck=1
							and ca.bClienteCaptado=0*/
							and cm.bBuzonConBajas=1							
							
							--and contains_substr(swTipoRec,"preven")
							order by 14 asc
						), np as (
							select  swCustomerId, swBuzonId, swAgreementId, bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, --bPrSohoPrevio, 
							--count(distinct if(contains_substr(categoria_servicio_ds,'BANDA ANCHA'), swInstProdId, NULL)) as nBA,
							count(distinct if(contains_substr(categoria_servicio_ds,'BANDA ANCHA') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as BAJA_nBA,
							count(distinct if(contains_substr(categoria_servicio_ds,'BANDA ANCHA') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) as ALTA_nBA,
							count(distinct if(contains_substr(categoria_servicio_ds,'BANDA ANCHA') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) - 
							count(distinct if(contains_substr(categoria_servicio_ds,'BANDA ANCHA') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as VAR_nBA,							


							--count(distinct if(contains_substr(categoria_servicio_ds,'FIJA'), swInstProdId, NULL)) as nTF,		
							count(distinct if(contains_substr(categoria_servicio_ds,'FIJA') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as BAJA_nTF,
							count(distinct if(contains_substr(categoria_servicio_ds,'FIJA') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) as ALTA_nTF,
							count(distinct if(contains_substr(categoria_servicio_ds,'FIJA') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) - 
							count(distinct if(contains_substr(categoria_servicio_ds,'FIJA') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as VAR_nTF,


							--count(distinct if(contains_substr(categoria_servicio_ds,'MOVILES') or contains_substr(tipo_servicio_ds,'MOVIL'), swInstProdId, NULL)) as nTM,
							count(distinct if(contains_substr(categoria_servicio_ds,'MOVILES') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as BAJA_nTM,
							count(distinct if(contains_substr(categoria_servicio_ds,'MOVILES') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) as ALTA_nTM,							
							count(distinct if(contains_substr(categoria_servicio_ds,'MOVILES') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) - 
							count(distinct if(contains_substr(categoria_servicio_ds,'MOVILES') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as VAR_nTM,


							--count(distinct if(contains_substr(categoria_servicio_ds,'TELEVISION'), swInstProdId, NULL)) as nTV,
							count(distinct if(contains_substr(categoria_servicio_ds,'TELEVISION') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as BAJA_nTV,
							count(distinct if(contains_substr(categoria_servicio_ds,'TELEVISION') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) as ALTA_nTV,
							count(distinct if(contains_substr(categoria_servicio_ds,'TELEVISION') and contains_substr(prAccion,"alta"), swInstProdId, NULL)) - 
							count(distinct if(contains_substr(categoria_servicio_ds,'TELEVISION') and contains_substr(prAccion,"baja"), swInstProdId, NULL)) as VAR_nTV,

							from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
							where not contains_substr(osEstado, "anulado")
							GROUP BY 1,2,3,4,5,6,7
							ORDER BY 1,2,3,4,5,6,7 
						) select distinct a.*, np.VAR_nBA, np.VAR_nTF, np.VAR_nTM, np.VAR_nTV, np.ALTA_nBA, np.BAJA_nBA
						from arpu a 
						left join np on np.swCustomerId=a.swCustomerId and np.swAgreementId=a.swAgreementId and np.swBuzonId=a.swBuzonId  and np.bMarcaCheck=a.bMarcaCheck and np.bClienteCaptado=a.bClienteCaptado and np.bBuzonSohoPrevio=a.bBuzonSohoPrevio  and np.bBuzonConBajas=a.bBuzonConBajas --and np.bPrSohoPrevio=a.bPrSohoPrevio
						where a.swCustomerId is not null
						order by 1,2,3,4,5,6,7,8,9,10;
						
	
	
			--- PASO 3.1.3: CALCULO ARPU_1M DE BUZONES   -> 5711 buzones
			--- OUT  3.1.2: ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS: Arpu calculado por buzón
	
					CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS` as 
					select * from `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS_NO_BAJAS`
					UNION all
					select swCustomerId, swNIE, swAgreementId, fecha_buzon_d, fecha_venta_d, grbuzid, grbuzid_ind,swBuzonid, swClasificacion, swTipoRec, swTipoSol, bMarcaCheck, bClienteCaptado, bBuzonSohoPrevio, bBuzonConBajas, 
					canal_agrupado1_ds, subcanal_ds, swName,swSegmento, subsegmento_ds,
					(ALTA_CUOTAS_ALTA - BAJA_CUOTAS_ALTA) as CUOTAS_ALTA, 
					(ALTA_CUOTAS_MENSUALES - BAJA_CUOTAS_MENSUALES) as CUOTAS_MENSUALES, 
					(ALTA_DESCUENTOS - BAJA_DESCUENTOS) as DESCUENTOS,
					(ALTA_ARPU_12M - BAJA_ARPU_12M) as ARPU_12M,
					VAR_CUOTAS_MENSUALES_1M as CMEN_1M, 							
					VAR_DESCUENTOS_1M as DESC_1M,							
					(ALTA_ARPU_1M - BAJA_ARPU_1M) as ARPU_1M,
					VAR_nBA as nBA,
					VAR_nTF as nTF,
					VAR_nTM as nTM,
					VAR_nTV as nTV
					from `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS_SI_BAJAS`;

						
	

		--- PASO 3.2: CALCULO ARPU_1M DE CLIENTES NUEVOS.
		---			  INDICADOR SEGMENTADO POR BUZON. 
		---			  INTEGRA TODO TIPO DE BUZONES 	
		---			  EXCLUYE LAS OPERACIONES SOBRE PRODUCTOS ASOCIADAS A FLUJOS ANULADOS
		---			  SOLO CONSIDERA LOS PRODUCTOS MARCADOS COMO PRODCUTOS DE CLIENTES NUEVOS (MARCA BCLIENTECAPTADO=1)


				SELECT distinct * FROM `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS`  where bClienteCaptado=1 order by 1 asc;

				SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS`  
				where bClienteCaptado=1 and bBuzonConBajas=0 and not Contains_substr(swName,'sin indicar') and contains_substr(swTipoSol,'auditor')
				order by 6,7;						


				SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_BUZONES_NO_FLUJOS_ANULADOS`  
				where contains_substr(swTipoSol,'auditor')
				order by 6,7;						



	---- 444 buzones 

		---> 238 cruzan por NIF
		select distinct l.* 
		from  `mm-commissions-reporting.KRT_CAP_PYME.TIP_HIST_LIQ_DESCUBIERTO` l
		where exists (
				select 1
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_CAPTACION_NO_FLUJOS_ANULADOS` d
				where TRIM(UPPER(d.swNIE))=TRIM(UPPER(l.CIF))
		) or exists(
				select 1
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_YACLIENTE_CAPTACION_NO_FLUJOS_ANULADOS` d
				where TRIM(UPPER(d.swNIE))=TRIM(UPPER(l.CIF))
		) order by  1;


		---> 206 no cruzan por NIF	
		select distinct l.* 
		from  `mm-commissions-reporting.KRT_CAP_PYME.TIP_HIST_LIQ_DESCUBIERTO` l
		where exists (
				select 1
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_CAPTACION_NO_FLUJOS_ANULADOS` d
				where TRIM(UPPER(d.swNIE))=TRIM(UPPER(l.CIF))
		) or exists(
				select 1
				from  `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_YACLIENTE_CAPTACION_NO_FLUJOS_ANULADOS` d
				where TRIM(UPPER(d.swNIE))=TRIM(UPPER(l.CIF))
		) order by  1;






	--- PASO 4: GENERACION DE COMISONADO
		
		---- PASO 4.1: CALCULO MULTIPLICADOR
		
		
		---- PASO 4.2: CALCULO COMISIONADO DE NUEVOS CLIENTES CAPTADOS

				
									select swBuzonId, swCustomerId, swInstProdId, swReleaseName,swFacturable, fecha_rfb_d, fecha_baja_d, date_diff(fecha_baja_d, fecha_rfb_d, DAY) as ndias, osAccion, prAccion  
									from  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
									where prAccion="Alta"
									and fecha_baja_d is not null 
									order by 8 asc, 1,2,3; 
		
		
									--ClienteId: 7593287, 2179110
		
						/*
						--- CAPTACION SIN FLUJOS ANULADOS
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.COMISIONES_BUZONESxIMPORTESxNRGUS_CAPTACION_TODOS_FLUJOS` as
						with  f as (
							select swBuzonid, fecha_buzon_d, min(fecha_venta_d) as fecha_comisionado, date_diff(min(fecha_venta_d),fecha_buzon_d, DAY ) as ndias
							from  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
							where fecha_venta_d>=fecha_buzon_d
							group by 1,2
							order by 1 asc,2 
						) 						
						Select date_trunc(f.fecha_buzon_d,month) as mes_buzon, date_trunc(f.fecha_comisionado,month) as mes_venta, i.*, 7 as multiplicador,
						7*i.ARPU_1M + case when nBA>6 or nTM>6 then ARPU_1M else 0 end as COMISION						
						from `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_CAPTACION_NO_FLUJOS_ANULADOS` i
						--from `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxIMPORTESxNRGUS` 
						left join f
						on i.swBuzonId=f.swBuzonid and  i.bClienteCaptado=1
						order by 2,1;						
						*/
						
		---- OUT 4.2: COMISIONES_BUZONESxIMPORTESxNRGUS_CAPTACION_NO_FLUJOS_ANULADOS
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.COMISIONES_BUZONESxIMPORTESxNRGUS_CAPTACION_NO_FLUJOS_ANULADOS` as
						with  f as (
							select swBuzonid, fecha_buzon_d, min(fecha_venta_d) as fecha_comisionado, date_diff(min(fecha_venta_d),fecha_buzon_d, DAY ) as ndias
							from  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
							where fecha_venta_d>=fecha_buzon_d
							and not contains_substr(osEstado, "anulado")
							group by 1,2
							order by 1 asc,2 
						) 						
						Select date_trunc(f.fecha_buzon_d,month) as mes_buzon, date_trunc(f.fecha_comisionado,month) as mes_venta, i.*, 
						5*i.ARPU_1M + case when nBA>6 or nTM>6 then ARPU_1M else 0 end as COMISION
						from `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_CAPTACION_NO_FLUJOS_ANULADOS` i
						inner join f
						on i.swBuzonId=f.swBuzonid 
						order by 2,1;						


		---- OUT 4.2: COMISIONES_BUZONESxIMPORTESxNRGUS_CAPTACION_NO_FLUJOS_ANULADOS
		
						CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.COMISIONES_BUZONESxIMPORTESxNRGUS_YACLIENTE_CAPTACION_NO_FLUJOS_ANULADOS`as 
						with  f as (
							select swBuzonid, fecha_buzon_d, min(fecha_venta_d) as fecha_comisionado, date_diff(min(fecha_venta_d),fecha_buzon_d, DAY ) as ndias
							from  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
							where fecha_venta_d>=fecha_buzon_d
							and not contains_substr(osEstado, "anulado")
							group by 1,2
							order by 1 asc,2 
						) 						
						Select date_trunc(f.fecha_buzon_d,month) as mes_buzon, date_trunc(f.fecha_comisionado,month) as mes_venta, i.*, 
						case when VAR_ARPU_1M > 0 then 7*i.VAR_ARPU_1M + case when VAR_nBA>6 or VAR_nTM>6 then VAR_ARPU_1M else 0 end 
							 else 0 
						end as COMISION
						from `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxFLUJOSxIMPORTESxNRGUS_YACLIENTE_CAPTACION_NO_FLUJOS_ANULADOS` i
						inner join f
						on i.swBuzonId=f.swBuzonid 
						order by 2,1;						
				
						
						---- Pendiente enriquecer tabla con
						----	Fecha de creación de buzón
						----	Fecha de lanzamiento de flujo 	
						----	Fecha de venta de producto
						
						select distinct swBuzonId, swCustomerId, swAgreementId, fecha_buzon_d, fecha_flujo_d, fecha_venta_d,  bMarcaCheck,bClienteCaptado, bBuzonSohoPrevio, bPrSohoPrevio, canal_agrupado1_ds, subcanal_ds, swName,swSegmento, subsegmento_ds
						from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET`
						order by 1,2,3,4,5,6,7;
						
						
		----	PASO 4.3: Establezco comparativa entre comisionaes liquidadas y calculadas 

						CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CAP_PYME.AUDIT_IMP_LIQ_CALC` AS 
						with i as (
							Select h.mes_id, c.swCustomerId, 
							c.bMarcaCheck, c.bClienteCaptado, c.bBuzonSohoPrevio, c.bPrSohoPrevio, 
							c.canal_agrupado1_ds, c.subcanal_ds, c.swName,c.swSegmento, c.subsegmento_ds,
							h.buzon, 						
							h.PUESTOS_FIJOS+h.Bandas_anchas+h.MOVILES as nRGU_LIQ,  h.PUESTOS_FIJOS, h.Bandas_anchas, h.MOVILES, 
							c.nTF+c.nBA+c.nTM as nRGU_CALC, c.nTF, c.nBA, c.nTM,
							h.ARPU_MES as ARPU_1M_LIQ, h.ARPU_ANUAL as ARPU_12M_LIQ, 
							c.ARPU_1M as ARPU_1M_CALC, c.ARPU_12M AS ARPU_12M_CALC, 
							(h.Bandas_anchas) - (c.nBA) as DIF_nBA_LIQ_CALC,
							(h.PUESTOS_FIJOS) - (c.nTF ) as DIF_nTF_LIQ_CALC,
							(h.MOVILES) - (c.nTM ) as DIF_nTM_LIQ_CALC,
							(h.PUESTOS_FIJOS+h.Bandas_anchas+h.MOVILES) - (c.nTF+c.nBA+c.nTM ) as DIF_NRGU_LIQ_CALC,
							ROUND(h.ARPU_MES - c.ARPU_1M,2 ) as DIF_ARPU_1M_LIQ_CALC,
							ROUND(h.ARPU_ANUAL - c.ARPU_12M,2) as DIF_ARPU_12M_LIQ_CALC,						 
							c.CUOTAS_ALTA, c.CUOTAS_MENSUALES, c.DESCUENTOS,
							ROUND(h.ARPU_ANUAL - c.CUOTAS_MENSUALES,2) as DIF_ARPU12M_LIQ_CMENS_12M
							from  `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxIMPORTESxNRGUS` c
							inner join `mm-commissions-reporting.KRT_CAP_PYME.HISTORICO_CAPTACION_LIQUIDADO` h on  CAST(h.buzon as int64)=c.swBuzonid
							order by 17 asc
						) select distinct * from i where ARPU_1M_LIQ is not null and ARPU_1M_CALC is not null and ARPU_1M_LIQ>0 ;




		---- PASO 4.4: Calculo la facturación en el año
		----

				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.FA_FACTURACION_CLIENTES` as 
				SELECT f.fecha_mes_ciclo_dt, f.swCustomerId, f.swAgreementId, f.bill_ref_no, f.bill_total, f.services_amount,f.consumptions_amount, f.discounts_amount, f.taxable_amount_ppal,f.tax_amount_ppal,f.bill_total_elec  
				FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_factura` f
				inner join  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p on  p.swcustomerId=f.swcustomerId and p.swAgreementId=f.swAgreementId
				WHERE fecha_mes_ciclo_dt >= "2023-01-01"; 


				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxIMPORTESxNRGUSxFACTURACION` as 
				SELECT distinct f.* except(swCustomerId,swAgreementId), c.*
				FROM `mm-commissions-reporting.KRT_CAP_PYME.ARPU_BUZONESxIMPORTESxNRGUS` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.FA_FACTURACION_CLIENTES`  f on c.swCustomerId=f.swCustomerId and c.swAgreementId=f.swAgreementId; 


				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUDIT_IMP_LIQ_CALCxFACTURACION` as 
				SELECT distinct f.* except(swCustomerId), c.*
				FROM `mm-commissions-reporting.KRT_CAP_PYME.AUDIT_IMP_LIQ_CALC` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.FA_FACTURACION_CLIENTES`  f on c.swCustomerId=f.swCustomerId; 

						
				/*
				CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.FA_FACTURACION_CLIENTES` as 
				SELECT fecha_mes_ciclo_dt, swCustomerId, swAgreementId, bill_ref_no, bill_total, services_amount,consumptions_amount, discounts_amount, taxable_amount_ppal,tax_amount_ppal,bill_total_elec  
				FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_factura` f
				WHERE fecha_mes_ciclo_dt >= "2023-01-01" 
				and exists(
				  select 1
				  from `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` p
				  where p.swcustomerId=f.swcustomerId
				  and p.swAgreementId=f.swAgreementId
				);
				*/		
						

/***** IMPORTANTE
REVISAR BUZON 21594616						

*/



----
----
----	FIN PRODUCCION
----
----
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


END