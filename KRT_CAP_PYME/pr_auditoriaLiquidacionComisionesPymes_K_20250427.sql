BEGIN

		DECLARE DESDE, HASTA INT64;
		DECLARE DESDE_DT, HASTA_DT DATETIME;
		DECLARE DESDE_D, HASTA_D DATE;						
		SET DESDE=20221001; SET HASTA=CAST(FORMAT_DATE('%Y%m%d',CURRENT_DATE('Europe/Madrid')) AS INT64);				
		SET DESDE_DT=parse_date ('%Y%m%d', CAST ( DESDE AS string));
		SET HASTA_DT=parse_date ('%Y%m%d', CAST ( HASTA AS string));
		SET DESDE_D=EXTRACT(DATE FROM DESDE_DT);
		SET HASTA_D=EXTRACT(DATE FROM HASTA_DT);			




	---------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------
	---
	---	PASO 2: Descubrimiento de cuentas
	---


		--- PASO 2.1: Descubro la población completa de relaciones CIFxCLIENTExCUENTAxESTADO instanciadas en ektnet, que han estado activas durante parte o el periodo completo de análisis . Cada relación se enriquece con cuatro datos. Número de clientes por cif,  número de cuentas por cif, número cuentas por cliente, índice de cuenta por cif, índice de cuenta por cliente, la fecha de inicio y fin de cuenta.
		--- OUT 2.1: AUFAC_CIFxCLIENTExCUENTA

		/*	
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCUENTA` AS 
		SELECT cl.swNIE, co.swCustomerId, co.swAgreementId, co.swStatus, extract(DATE FROM swStartDate ) as swStartDate, extract(DATE FROM co.swEndDate ) as swEndDate, 
		count(distinct c.swCustomerId) over(partition by cif) as nclxcif,		
		count(co.swStatus) over(partition by cl.swNIE) as ncuxcif,		
		count(co.swStatus) over(partition by co.swCustomerId) as ncuxcl,
		row_number() over(partition by co.swCustomerId order by co.swAgreementId asc) as indAgr 
		FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_contrato` co
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swCustomerId=co.swCustomerid
		--TABLESAMPLE SYSTEM(1 PERCENT) 
		where co.swstatus in ('Finalizado','Baja') order by 1,2;
		
		*/

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCUENTA` AS 	
		SELECT cl.swNIE, co.swCustomerId, co.swAgreementId, co.swStatus, extract(DATE FROM swStartDate ) as swStartDate, extract(DATE FROM co.swEndDate ) as swEndDate, 
		count(distinct co.swCustomerId) over(partition by cl.swNIE) as nclxcif,		
		count(co.swStatus) over(partition by cl.swNIE) as ncuxcif,		
		count(co.swStatus) over(partition by co.swCustomerId) as ncuxcl,
		row_number() over(partition by cl.swNIE order by co.swAgreementId asc) as indcuxcif, 		
		row_number() over(partition by co.swCustomerId order by co.swAgreementId asc) as indcuxcl,
		-- Fecha de inicio de comisionado es anterior a la fecha de creación de la cuenta
		-- 		Fecha de fin de comisionado es anterior a la fecha de creación de la cuenta 0
		-- 		Fecha de fin de comisionado es anterior a la fecha de baja de la cuenta 	1
		-- 		Fecha de fin de comisionado es posterior a la fecha de baja de la cuenta  2
		case when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)<0 											
				  then ( case when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)<=0 then 0
							  when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)<=0 then 1
							  when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)>0 then 2
						end														
				  ) 
		--  Fecha de inicio de comisionado es posterior a fecha de creación de la cuenta y previa a la fecha de baja de la cuenta
			  when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)>=0  AND DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)<=0  then 3
		--  Fecha de inicio de comisionado es posterior a la fecha de baja de la cuenta 0
			  when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)>0 then 0 
		end indint_tr
		FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_contrato` co
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swCustomerId=co.swCustomerid
		--TABLESAMPLE SYSTEM(1 PERCENT) 
		where co.swstatus in ('Finalizado','Baja') 
		-- condición que filtra las cuentas que han estado activas durante todo o parte del periodo en análisis
		and (co.swEndDate is null or DATE_DIFF(EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DESDE_D,DAY)>0)
		--and cl.swNIE in("78935694Q","18601235P","B31451156")
		order by 1,2;

		
		
		--- PASO 2.1: Registro la población de relaciones BUZONxCLIENTExCUENTA definidas en todos los buzones descubiertos en periodo de análisis
		--- OUT 2.1: AUFAC_BUZONES_DESCUBIERTOSxCLIENTEXCUENTA


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_BUZONES_DESCUBIERTOSxCLIENTExCUENTA` AS 
		select distinct swbuzonId, swCustomerId, swAgreementId from  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_DESCUBIERTOS` 
		where swAgreementId is not null ;			




		--- PASO 2.2: Registro la población de relaciones AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET definidas en CRM
		--- OUT 2.2: AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET_TMP` AS 
		SELECT distinct cl.swNIE, co.swCustomerId, co.swAgreementId, 
		--swPaymentMethod,
		case when contains_substr(co.swPaymentMethod,"Transferencia") then REPLACE(left(cl.swName,15)," ","") --,"_C",CAST(ROW_NUMBER() over(partition by cl.swNIE, co.swCustomerId, co.swAgreementId) AS STRING))
		else concat(co.swControlIBAN,co.swDigito, co.swEntidad,co.swSucursal, co.swNumCuenta, CAST(co.swDescNumCuenta AS STRING)) END as descNumCuenta,
		--ROW_NUMBER() over(partition by cl.swNIE order by concat(co.swControlIBAN,co.swDigito, co.swEntidad,co.swSucursal, co.swNumCuenta, co.swDescNumCuenta) asc) as indCuenta,
		co.swStatus, extract(DATE FROM swStartDate ) as swStartDate, extract(DATE FROM co.swEndDate ) as swEndDate, 
		-- Fecha de inicio de comisionado es anterior a la fecha de creación de la cuenta
		-- 		Fecha de fin de comisionado es anterior a la fecha de creación de la cuenta 0
		-- 		Fecha de fin de comisionado es anterior a la fecha de baja de la cuenta 	1
		-- 		Fecha de fin de comisionado es posterior a la fecha de baja de la cuenta  2
		case when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)<0 											
				  then ( case when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)<=0 then 0
							  when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)<=0 then 1
							  when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)>0 then 2
						end														
				  ) 
		--  Fecha de inicio de comisionado es posterior a fecha de creación de la cuenta y previa a la fecha de baja de la cuenta
			  when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)>=0  AND DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)<=0  then 3
		--  Fecha de inicio de comisionado es posterior a la fecha de baja de la cuenta 0
			  when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)>0 then 0 
		end indint_tr
		FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_contrato` co
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swCustomerId=co.swCustomerid
		--TABLESAMPLE SYSTEM(1 PERCENT) 
		where co.swstatus in ('Finalizado','Baja') 
		-- condición que filtra las cuentas que han estado activas durante todo o parte del periodo en análisis
		and (co.swEndDate is null or DATE_DIFF(EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DESDE_D,DAY)>0)
		--and cl.swNIE in("78935694Q","18601235P","B31451156")
		order by 1,2;



		/*			
		SELECT distinct cl.swNIE, co.swCustomerId, co.swAgreementId, 
		case when contains_substr(swPaymentMethod,"Transferencia") then left(cl.swName,15) else concat(co.swControlIBAN,co.swDigito, co.swEntidad,co.swSucursal, co.swNumCuenta, CAST(co.swDescNumCuenta AS STRING)) END as descNumCuenta,
		--ROW_NUMBER() over(partition by cl.swNIE order by concat(co.swControlIBAN,co.swDigito, co.swEntidad,co.swSucursal, co.swNumCuenta, co.swDescNumCuenta) asc) as indCuenta,
		co.swStatus, extract(DATE FROM swStartDate ) as swStartDate, extract(DATE FROM co.swEndDate ) as swEndDate, 
		-- Fecha de inicio de comisionado es anterior a la fecha de creación de la cuenta
		-- 		Fecha de fin de comisionado es anterior a la fecha de creación de la cuenta 0
		-- 		Fecha de fin de comisionado es anterior a la fecha de baja de la cuenta 	1
		-- 		Fecha de fin de comisionado es posterior a la fecha de baja de la cuenta  2
		case when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)<0 											
				  then ( case when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)<=0 then 0
							  when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)<=0 then 1
							  when DATE_DIFF(HASTA_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)>0 then 2
						end														
				  ) 
		--  Fecha de inicio de comisionado es posterior a fecha de creación de la cuenta y previa a la fecha de baja de la cuenta
			  when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swStartDate,'1970-01-01')),DAY)>=0  AND DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)<=0  then 3
		--  Fecha de inicio de comisionado es posterior a la fecha de baja de la cuenta 0
			  when DATE_DIFF(DESDE_D,EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DAY)>0 then 0 
		end indint_tr
		FROM `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_contrato` co
		LEFT JOIN `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` cl on cl.swCustomerId=co.swCustomerid
		--TABLESAMPLE SYSTEM(1 PERCENT) 
		where co.swstatus in ('Finalizado','Baja') 
		-- condición que filtra las cuentas que han estado activas durante todo o parte del periodo en análisis
		and (co.swEndDate is null or DATE_DIFF(EXTRACT(DATE FROM coalesce(co.swEndDate,'2099-12-31')),DESDE_D,DAY)>0)
		--and cl.swNIE in("78935694Q","18601235P","B31451156")
		order by 1,2;
		*/


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET` AS 	
		with cxd as (
			with p as (
				select distinct swNIE, descNumCuenta, 
				from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET_TMP` p
			)
			select p.* , 
			--case when coalesce(descNumCuenta,"NODEF")="NODEF" then NULL ELSE ROW_NUMBER() OVER (PARTITION BY swNIE ORDER BY swNIE, descNumCuenta)   END AS indice

			CONCAT("C_", CAST(ROW_NUMBER() OVER (PARTITION BY swNIE ORDER BY swNIE, descNumCuenta) AS STRING) ) AS account_id,
			from p
			order by 1,2
		) select c.* except (descNumCuenta,swStatus,swStartDate,swEndDate, indint_tr), 
		concat(c.swAgreementId,"_",cxd.account_id) as account_id,
		c.descNumCuenta,c.swStatus,c.swStartDate,c.swEndDate, c.indint_tr,
		count(distinct c.swCustomerId) over(partition by c.swNIE) as nclxcif,		
		count(distinct c.swAgreementId) over(partition by c.swCustomerId) as ncoxcl,
		count(distinct cxd.account_id) over(partition by c.swNIE) as ncuxcif,		
		row_number() over(partition by c.swNIE order by c.swAgreementId asc) as indcoxcif, 		
		row_number() over(partition by c.swCustomerId order by c.swAgreementId asc) as indcuxcl,
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET_TMP` c
		left join cxd on cxd.swNIE=c.swNIE and cxd.descNumCuenta=c.descNumCuenta;



		--- PASO 2.3: Registro la contabilidad de clientes y cuentas  en CRM, por CIF comisionado
		--- OUT 2.2: AUFAC_CIF_NCLxCIF_NCUxCIF


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIF_NCLxCIF_NCUxCIF` AS 	
		with p as (
			select distinct cif
			FROM `mm-commissions-reporting.GS.PYMES_KRT_COMISIONES` c
			where marca="K"
		) select distinct c.swNIE, c.nclxcif, ncuxcif
		from  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET`  c 
		inner join p on p.cif=c.swNIE
		order by nclxcif desc;
			



	---------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------
	---
	---	PASO 3: Creación de facturacion_ektnet
	---



		--- PASO 3.1: Creación de tabla FACTURACION_CAPTACIONxCUENTA_EUSKALTEL. Registra la facturación por cliente a nivel de cuenta, de los 27 meses previos y posteriores a la creación del buzón asociado. Acummula el importe de las factura mensuales y calcula varios estadisticos. Incremento intermensual y arpu a 3 6 y 12 meses
		--- OUT 3.1: FACTURACION_CAPTACIONxCUENTA_EUSKALTEL_EUSKALTEL

		--CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL` AS		
		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACIONxCUENTA_EUSKALTEL` AS			
		with pob as(
			with p as (
				select distinct 
				--- incluyo row_number
				--row_number() over(partition by c.marca, cl.swCustomerId, bk.swAgreementId order by bk.fecha_mes_ciclo_dt desc) as ind,
				---
				case when c.marca="K" then "EUSKALTEL" when c.marca="T" then "TELECABLE" when c.marca="R" then "R" END as brand_ds, 
				--c.mes_venta as sell_month_id, 
				--c.mes_abono as charge_month_id, 
				--parse_date('%Y%m%d', CONCAT(CAST(c.mes_venta as string),"01")) as sell_month_dt, 
				--parse_date('%Y%m%d', CONCAT(CAST(c.mes_abono as string),"01")) as charge_month_dt, 
				c.cif, 
				
				cl.swSegmento as segment_ds,
				cl.swSegmento2 as subsegment_ds,
				
				cl.swCustomerId as customer_id,
				count(distinct cl.swCustomerId) over(partition by c.marca, c.cif) as ncustxcif,
				count(distinct bk.swAgreementId) over(partition  by c.marca, cl.swCustomerId, bk.fecha_mes_ciclo_dt)  as naccxcust,
				count(distinct bk.euskaltel_bill_no) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as ninvoice,				
				--row_number() over(partition by c.marca, cl.swCustomerId, bk.fecha_mes_ciclo_dt order by bk.swAgreementId asc) as indaccount,
				--row_number() over(partition by c.marca, cl.swCustomerId, bk.swAgreementId) as indaccount, 		
				bk.swAgreementId as account_id,
				bk.account_no,
				Array_to_string(array_Agg(bk.euskaltel_bill_no) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt),",") as vinvoice_id,
				bk.fecha_mes_ciclo_dt as invoice_date,
				--bk.fecha_emision as invoice_sent_date, --- excluimos invoice_sent_date porque crea duplicados
				--bk.bill_total_elec,
				--bk.bill_total as imp_amount,
				--bk.bill_total_no_elec,
				sum(bk.bill_total) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as bill_total,				
				sum(bk.bill_total_elec) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as bill_total_elec,
				sum(bk.bill_total_no_elec) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as bill_total_no_elec,
												
				sum(bk.services_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as services_amount,
				sum(bk.consumptions_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as consumptions_amount,				
				sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as discounts_amount,											
				sum(bk.other_services_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as other_services_amount,
				sum(bk.regularizations_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)  as regularizations_amount,

				sum(bk.bill_total_elec) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt) as imp_fact,				
				sum(bk.taxable_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt) as imp_amount,			
				sum(bk.taxable_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt) + SAFE_NEGATE(sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)) as imp_no_disc,
				
				---	La ratio es el cociente entre el descuento total y la base imponible mas los descuentos			
				--SAFE_DIVIDE(SAFE_NEGATE(sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)),SAFE_DIVIDE(sum(bk.bill_total) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt), 1.21 ) + SAFE_NEGATE(sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt))) as disc_ratio,
				SAFE_DIVIDE(SAFE_NEGATE(sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)),sum(bk.taxable_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt) + SAFE_NEGATE(sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt))) as disc_ratio,

				--sum(bk.bill_total_elec) over(partition  by c.marca, cl.swCustomerId, bk.fecha_mes_ciclo_dt)  as bill_total_elec,
				--sum(bk.bill_total) over(partition  by c.marca, cl.swCustomerId, bk.fecha_mes_ciclo_dt)  as imp_amount,
				--sum(bk.bill_total_no_elec) over(partition  by c.marca, cl.swCustomerId, bk.fecha_mes_ciclo_dt)  as bill_total_no_elec,						
				FROM `mm-commissions-reporting.GS.PYMES_KRT_COMISIONES`c
				left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente`cl on cl.swNIE=c.CIF
				left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_factura` bk on bk.swcustomerid=cl.swCustomerId 
				where c.arpu_mes is not null
				and ABS(date_diff(bk.fecha_mes_ciclo_dt,parse_date('%Y%m%d', CONCAT(CAST(c.mes_abono as string),"01")),MONTH)) <28
				and c.marca="K"			
				--and cif="A48055891" -- caso de 3 buzones por cliente
				--and cif="B95755013"
				--and cif="13734160D" -- caso de 2 cuentas por cliente
				--and cif="08901842Z" -- caso de 2 facturas en un mes				
				--and cif="F72951676" -- caso de 10 facturas rectificativas en un mes
				order by bk.fecha_mes_ciclo_dt desc		

			) 
			
			--- incluyo row_number		
			select distinct row_number() over(partition by p.brand_ds, p.customer_id, p.account_id order by invoice_date desc) as ind,		
			p.*
			from p
			order by invoice_date desc
		)  select pob.*,
		LAG(imp_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc) as imp_amount_prev,
		imp_amount - coalesce(LAG(imp_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc),0) as var_arpu,  
		avg(imp_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) arpu_3m,
		avg(imp_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) arpu_6m,
		avg(imp_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) arpu_12m,

		LAG(discounts_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc) as disc_amount_prev,
		discounts_amount - coalesce(LAG(discounts_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc),0) as var_disc_amount,  
		avg(discounts_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) disc_3m,
		avg(discounts_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) disc_6m,
		avg(discounts_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) disc_12m,


		LAG(imp_no_disc) over(partition by brand_ds, customer_id,account_id order by invoice_date asc) as imp_no_disc_prev,
		imp_no_disc - coalesce(LAG(imp_no_disc) over(partition by brand_ds, customer_id,account_id order by invoice_date asc),0) as var_imp_no_disc, 
		avg(imp_no_disc) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) imp_no_disc_3m,
		avg(imp_no_disc) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) imp_no_disc_6m,
		avg(imp_no_disc) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) imp_no_disc_12m,
		
		avg(disc_ratio) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) disc_ratio_3m,
		avg(disc_ratio) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) disc_ratio_6m,
		avg(disc_ratio) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) disc_ratio_12m,

		
		from pob
		where pob.imp_amount!=0
		and pob.brand_ds="EUSKALTEL"
		--where cif="A48055891" -- caso de 3 buzones por cliente
		--where cif="B95755013"
		--where cif="13734160D" -- caso de 2 cuentas por cliente-
		--and cif="13734160D" -- caso de 2 cuentas por cliente-
		--and cif="08901842Z" -- caso de 2 facturas en un mes    
		--and cif="F72951676" -- caso de 10 facturas rectificativas en un mes
		--and cif="78997216J"
		--and cif="B95510731"
		order by pob.cif, pob.account_id, pob.invoice_date;
		

		--- PASO 3.2: Creación de tabla FACTURACION_CAPTACIONxCLIENTE_EUSKALTEL. Registra la facturación a nivel de cuenta, de los 27 meses previos y posteriores a la creación del buzón asociado. Acummula el importe de las factura mensuales y calcula varios estadisticos. Incremento intermensual y arpu a 3 6 y 12 meses
		--- OUT 3.2: FACTURACION_CAPTACIONxCLIENTE_EUSKALTEL_EUSKALTEL

		---- REGISTRO POR CIFxCLIENTExMES 	
		---- IMPORTANTE PARA FUTURO DESARROLLO DE CASO DE ANALISIS DE FACTURACION POR CLIENTE, LOS CAMPOS ACCOUNT_ID Y ACCOUNT_NO PASAN A SER UN ARRAY DE STRINGS EN LUGAR DE SER CAMPOS DE TIPO ENTERO COMO EN EL CASO DE LA TABLA DE FACTUACION POR CUENTA
		----	ESTÒ PUEDE CONDICIONAR LA COMPATIBILIDAD HACIA ADELANTE

		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACIONxCLIENTE_EUSKALTEL` AS		
		with pob as(							
			with p as (
					select distinct 
					--- incluyo row_number
					--row_number() over(partition by c.marca, cl.swCustomerId, bk.swAgreementId order by bk.fecha_mes_ciclo_dt desc) as ind,
					---
					c.brand_ds,
					--c.mes_venta as sell_month_id, 
					--c.mes_abono as charge_month_id, 
					--parse_date('%Y%m%d', CONCAT(CAST(c.mes_venta as string),"01")) as sell_month_dt, 
					--parse_date('%Y%m%d', CONCAT(CAST(c.mes_abono as string),"01")) as charge_month_dt, 
					c.cif, 
					
					c.segment_ds,
					c.subsegment_ds,
					
					c.customer_id,
					count(distinct c.customer_id) over(partition by c.brand_ds, c.cif) as ncustxcif,
					count(distinct c.account_id) over(partition  by c.brand_ds, c.customer_id, c.invoice_date)  as naccxcust,
					sum(c.ninvoice) over(partition  by c.brand_ds, c.customer_id, c.invoice_date) as ninvoice,				
					--row_number() over(partition by c.marca, cl.swCustomerId, bk.fecha_mes_ciclo_dt order by bk.swAgreementId asc) as indaccount,
					--row_number() over(partition by c.marca, cl.swCustomerId, bk.swAgreementId) as indaccount, 		
					c.invoice_date,

					Array_to_string(array_Agg(CAST(c.account_id AS STRING)) over(partition  by c.brand_ds, c.cif, c.Customer_Id, c.invoice_date),",") as account_id,
					Array_to_string(array_Agg(CAST(c.account_no AS STRING)) over(partition  by c.brand_ds, c.cif, c.Customer_Id, c.invoice_date),",") as account_no,
					Array_to_string(array_Agg(c.vinvoice_id ) over(partition  by c.brand_ds, c.cif, c.Customer_Id, c.invoice_date),",") as vinvoice_id,

					CAST(NULL as FLOAT64) as bill_total,				
					CAST(NULL as FLOAT64) as bill_total_elec,
					CAST(NULL as FLOAT64) as bill_total_no_elec,
											
					CAST(NULL as FLOAT64) as services_amount,
					CAST(NULL as FLOAT64) as consumptions_amount,				
					SAFE_DIVIDE(sum(c.discounts_amount) over(partition  by c.brand_ds, c.customer_Id, c.invoice_date),1.21) as discounts_amount,									
					CAST(NULL as FLOAT64) as other_services_amount,
					CAST(NULL as FLOAT64) as regularizations_amount,

					sum(c.imp_fact) over(partition  by c.brand_ds, c.customer_Id,  c.invoice_date) as imp_fact, 
					SAFE_DIVIDE(sum(c.imp_amount) over(partition  by c.brand_ds, c.customer_Id,  c.invoice_date),1.21) as imp_amount,			
					sum(c.imp_no_disc) over(partition  by c.brand_ds, c.customer_Id,  c.invoice_date) + SAFE_NEGATE(sum(c.discounts_amount) over(partition  by c.brand_ds, c.customer_Id, c.invoice_date)) as imp_no_disc,
					
					---	La ratio es el cociente entre el descuento total y la base imponible mas los descuentos			
					--SAFE_DIVIDE(SAFE_NEGATE(sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt)),SAFE_DIVIDE(sum(bk.bill_total) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt), 1.21 ) + SAFE_NEGATE(sum(bk.discounts_amount) over(partition  by c.marca, cl.swCustomerId,bk.swAgreementId, bk.fecha_mes_ciclo_dt))) as disc_ratio,
					
					SAFE_DIVIDE( SAFE_NEGATE(sum(c.discounts_amount) over(partition  by c.brand_ds, c.customer_Id, c.invoice_date)) ,
					sum(c.imp_amount) over(partition  by c.brand_ds, c.customer_Id, c.invoice_date) + SAFE_NEGATE(sum(c.discounts_amount) over(partition  by c.brand_ds, c.Customer_Id, c.invoice_date))) as disc_ratio,

					FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACIONxCUENTA_EUSKALTEL` c
					--where c.customer_id="400848537" --and c.invoice_date='2024-03-01'
					--where c.customer_id="400145564" --and c.invoice_date='2024-03-01'
					order by 1,2,5,9,11	

			) 
			
			--- incluyo row_number		
			select distinct row_number() over(partition by p.brand_ds, p.customer_id, p.account_id order by invoice_date desc) as ind,		
			p.*
			from p
			order by invoice_date desc
		)  select pob.*,
		LAG(imp_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc) as imp_amount_prev,
		imp_amount - coalesce(LAG(imp_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc),0) as var_arpu,  
		avg(imp_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) arpu_3m,
		avg(imp_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) arpu_6m,
		avg(imp_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) arpu_12m,

		LAG(discounts_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc) as disc_amount_prev,
		discounts_amount - coalesce(LAG(discounts_amount) over(partition by brand_ds, customer_id,account_id order by invoice_date asc),0) as var_disc_amount,  
		avg(discounts_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) disc_3m,
		avg(discounts_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) disc_6m,
		avg(discounts_amount) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) disc_12m,


		LAG(imp_no_disc) over(partition by brand_ds, customer_id,account_id order by invoice_date asc) as imp_no_disc_prev,
		imp_no_disc - coalesce(LAG(imp_no_disc) over(partition by brand_ds, customer_id,account_id order by invoice_date asc),0) as var_imp_no_disc, 
		avg(imp_no_disc) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) imp_no_disc_3m,
		avg(imp_no_disc) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) imp_no_disc_6m,
		avg(imp_no_disc) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) imp_no_disc_12m,
		
		avg(disc_ratio) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 2 FOLLOWING) disc_ratio_3m,
		avg(disc_ratio) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 5 FOLLOWING) disc_ratio_6m,
		avg(disc_ratio) over(partition by brand_ds, customer_id, account_id order by ind asc Range Between CURRENT ROW AND 11 FOLLOWING) disc_ratio_12m,

		
		from pob
		where pob.imp_amount!=0
		and pob.brand_ds="EUSKALTEL"
		--where cif="A48055891" -- caso de 3 buzones por cliente
		--where cif="B95755013"
		--where cif="13734160D" -- caso de 2 cuentas por cliente-
		--and cif="13734160D" -- caso de 2 cuentas por cliente-
		--and cif="08901842Z" -- caso de 2 facturas en un mes    
		--and cif="F72951676" -- caso de 10 facturas rectificativas en un mes
		--and cif="78997216J"
		--and cif="B95510731"
		order by pob.cif, pob.account_id, pob.invoice_date;
		


		--- PASO 3.3: Seleccion de nivel de segmentación de análsis, a nivel de cliente o de cuenta. Por defecto en el caso de K el análisis se hace a nivel de cuenta 

		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL` AS		
		SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACIONxCUENTA_EUSKALTEL`;		



		--- PASO 3.4: Identificacion de CIFs a excluir de comisionado por estar asociado a un número de clientes superior a 3.
		--- OUT 3.4: AUFAC_CIFxNCUSTOMER_M1


		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxNCUSTOMER_M1` AS
		select distinct brand_ds, cif, 
		count(distinct customer_id) over(partition by brand_ds, cif) as nclxcif,		
		--count(distinct swAgreementId) over(partition by brand_ds, customer_id) as ncoxcl,
		--count(distinct account_id) over(partition by brand_ds, cif) as ncuxcif,		
		--count(distinct customer_id) over(partition by brand_ds, cif) as nclxcif 
		--count(distinct account_id) over(partition by brand_ds, cif) as ncuxcif 		
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL`
		Qualify ncustxcif>1 order by 1,2,3;
		/*
		---- CIFs CON MAS DE TRES CUSTOMERS 
		SELECT *
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxNCUSTOMER`
		where nclxcif >3


		---- CONTROL DE CONTRATOS SIN CUENTA ASOCIADA 
		with p as (
			with c as (
				select distinct brand_ds, account_id, from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL`
			) select distinct c.account_id, cc.*
			from c
			left join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCONTRATOxCUENTA_EKTNET` cc on c.account_id=cc.swAgreementId
			order by 1 asc
		) select p.*
		from p 
		--left join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`
		where swnie is null
		or descNumCuenta is null

		--- CASO CIF B95888780

		*/


		--- PASO 3.5: Excluir de comisionado CIFs asociadoa a un número de clientes superior a 3.
		--- OUT 3.5: AUFAC_FACTURACION_CAPTACION_EUSKALTEL_EXCLUIDA		

		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL_EXCLUIDA` AS 
		SELECT f.* FROM  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL` f 
		INNER JOIN `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxNCUSTOMER_M1`  c on c.cif=f.cif  and c.nclxcif>3;


		DELETE FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL` f
		WHERE exists (
			select 1
			from  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL_EXCLUIDA` c
			where c.cif=f.cif
		);





	---------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------
	---
	---	PASO 4: Creación de tabla HISTORICO_CAPTACION_EUSKALTEL_LIST
	---


		--- PASO 4.1: Creo de tabla HISTORICO_CAPTACION_EUSKALTEL_LIST que importa el historico de comisiones de captacion liquidadas. Una comisión por registro enriquecida con mes de venta y abono, número de unitarios, arpu comisionado, multiplicador aplicado, contador de comisiones por cif y  comisión acumulada por cif
		--- OUT 4.1: HISTORICO_CAPTACION_EUSKALTEL_LIST
			CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS
			with p as (	select distinct marca, 
						case when marca="K" then "EUSKALTEL" when marca="T" then "TELECABLE" when marca="R" then "R" END as brand_ds ,
						cif, count(comision_total) as ncomxcif, sum(comision_total) as comision_acumuladaxcif 
						from `mm-commissions-reporting.GS.PYMES_KRT_COMISIONES` 
						group by 1,2,3
			)
			select distinct p.*,row_number() over(partition by c.cif order by c.mes_venta) as ind,
			c.mes_venta, c.mes_Abono, c.distribuidor, c.buzon, 
			c.accesosBA as nBA_com,c.accesosTF as nTF_com,c.accesosTM  as nTM_com, replace(lower(c.multiplicador),'x','' ) as multiplicador_com, c.arpu_mes as arpu_mes_com, 
			c.comision_base, c.comision_total, c.comentarios
			from   p
			inner join 	`mm-commissions-reporting.GS.PYMES_KRT_COMISIONES` c using(marca, cif)
			order by 1,2,3,5;

		
			CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_LOG_0410_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS
			SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST`;


		--- PASO 4.2: Enriquezco el histórico de comisiones, con distintos datos 
		
			--- PASO 4.2.1: Datos que caracterizan al buzón asociado a la comisión (swcustomerId, swClasificacion, swTipoRec, swTipoSol, swDescripcion, swDateCreatedclasf)
			--- OUT 4.2.1:  HISTORICO_CAPTACION_EUSKALTEL_LIST		
			
			--- IMPORTANTE: SE DEBE ASEGURAR QUE TODOS LOS BUZONES INFORMAN EL IDCLIENTE 

			CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS
			SELECT distinct b.swCustomerId, b.swClasificacion, b.swTipoRec, b.swTipoSol, b.swDescripcion, b.swDateCreated, c.* 
			FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c 
			LEFT JOIN  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_DESCUBIERTOS` b on Cast(c.buzon as string)=cast(b.swBuzonId as string) 
			where c.marca="K";


			CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_LOG_0421_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS
			SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST`;


			--- PASO 4.2.2: Si el campo swcustomerid no está informado y el cif relacionado con el buzón sólo se asocia a un swcustomerid, se importa el swcustomerid del buzón asociado a la comisión  
			--- OUT 4.2.1:  HISTORICO_CAPTACION_EUSKALTEL_LIST		

				
			UPDATE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` l
			SET l.swCustomerId =nd.swCustomerId

			--- nd: Duplas cif - swcustomerId en las que un cif sólo está asociado a un único swcustomerid en las buzones descubiertos
			FROM (				
					with p as(
							--- Población de CIFs sin customerid informado en comisión/buzón
							select cif, count(distinct swCustomerId) as ncid,							
							from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` h
							group by 1
							having ncid=0
					)
					select distinct p.*, c.swCustomerId, nclxcif, ncuxcif, ncuxcl, indcuxcl,indint_tr, swAgreementId
					from p
					left join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCUENTA` c
					on c.swNIE=p.cif  
					where c.ncuxcif=1 and c.ncuxcl=1 ---and (c.swEndDate is null or DATE_DIFF(c.swEndDate,HASTA_D,DAY)>0)
					order by 1 asc		
			) nd 
			where nd.cif=l.cif 
			and l.swCustomerId is null;


			CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_LOG_0422_CIF_CON_SWCUSTOMERID_NO_DESCUBIERTO` AS
			select mes_venta, cif, swCustomerId, Buzon
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST`
			where swCustomerId is null
			order by 1,2;


			--Revisar Select * from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` where b.swCustomerId=1874413


			--- PASO 4.2.3: Creo tabla AUFAC_CLIENTExCUENTA_COMISION con duplas customerId x cuenta activa en la fecha de creación del buzón comisionado. Cada registro se enriquece con el número de cuentas activas por cliente en la fecha de creación del cliente, y un índice que identifica cada cuenta en cada cliente. Esta tabla permite conocer que clientes tienen más de una cuenta activa en la fecha de creación del buzón 
			--- OUT 4.2.3  CLIENTExCUENTA_COMISION
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_COMISION` AS 
			with p as (
					--- tabla con duplas customerId x cuenta activos en fecha de creación de buzón comisionado
					select distinct c.swCustomerId, cxc.swAgreementId
					from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c
					left join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CIFxCLIENTExCUENTA` cxc 
					on cxc.swCustomerId=c.swCustomerId and ( cxc.swEndDate is null or Date_diff(cxc.swEndDate, EXTRACT(DATE FROM c.swDateCreated), DAY) >=0)	
					where c.swCustomerId is not null and cxc.swAgreementId is not null
			)	select p.*, count( p.swAgreementId) over(partition by p.swCustomerId ) as nCuentas, row_number()  over (partition by p.swCustomerId ) as indCuenta 
			from p;		




			--- PASO 4.2.4: Creo tabla  AUFAC_CLIENTExCUENTA_BUZONDESCUBIERTO con relaciones CIFxCUSTOMERxCUENTAxBUZON registradas en los productos descubiertos. En todos los casos nos quedamos con relaciones descubiertas en productos instanciados tras creación de buzón
			
			--- OUT 4.2.4  CLIENTExCUENTA_BUZONDESCUBIERTO

			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_BUZONDESCUBIERTO` AS 
			--select distinct  swCustomerId, swbuzonId, swAgreementId from  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_DESCUBIERTOS` where swAgreementId is not null ;
			--select distinct  swCustomerId, swbuzonId, swAgreementId_buz as swAgreementId from  `mm-commissions-reporting.KRT_CAP_PYME.BUZONES_EKTNETxFLUJOS` where swAgreementId_buz is not null ;
			--select distinct  swCustomerId, swbuzonId, swAgreementId from  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` where swAgreementId_buz is not null ;
			select distinct  swNIE, swCustomerId, swbuzonId, swAgreementId  
			from  `mm-commissions-reporting.KRT_CAP_PYME.PRODUCTOS_EKTNET` 
			where swAgreementId is not null 
			and bPrSohoPrevio=0; --- me quedo con cuenta asociada a productos instanciados tras creación de buzón			
			



			--- PASO 4.2.5: Enriquezco la tabla HISTORICO_CAPTACION_EUSKALTEL_LIST con el identificativo de único de cuenta en aquel caso de que el customerId sólo tenga una cuenta activa en Ektnet en la fecha del buzon, o con el identnificativo de cuenta asignado a los productos asociados al buzón y que se han instanciado tras la creación de éste
			--- OUT 4.2.5  CLIENTExCUENTA_COMISION

			
			CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS 
			SELECT * FROM
			(
			--- dupla customerId x cuenta activa en fecha de creación de buzón comisionado para clientes con sólo una cuentas activa en la fecha de creación de buzón 	
			(select c.*, cxc.swAgreementId,cxc.swAgreementId as swAgreementId_new,1 as swAgreementId_procDesc, cxc.nCuentas, Array_to_string(array_Agg(CAST(cxc.swAgreementId AS STRING)) over(partition by c.swcustomerId),",") as vswAgreementId,
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c
			inner join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_COMISION` cxc on cxc.swCustomerId=c.swCustomerId and cxc.nCuentas=1
	--		where c.buzon is not null and not contains_substr(c.buzon,"exp")
			order by 1,2,3)
			UNION ALL
			(--- duplas customerId x cuenta activos en fecha de creación de buzón comisionado para clientes con sólo una cuentas activa n la fecha de creación de buzón 	
			select c.*, cxc.swAgreementId,b.swAgreementId as swAgreementId_new, 2 as swAgreementId_procDesc,cxc.nCuentas, Array_to_string(array_Agg(CAST(cxc.swAgreementId AS STRING)) over(partition by c.swcustomerId),",") as vswAgreementId,
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c
			inner join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_COMISION` cxc on cxc.swCustomerId=c.swCustomerId and cxc.nCuentas>1
			left join  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_BUZONDESCUBIERTO`  b on CAST(b.swBuzonId AS STRING)=c.buzon and b.swAgreementId=cxc.swAgreementId
			where c.buzon is not null and not contains_substr(c.buzon,"exp")
			and cxc.swAgreementId is not null
			order by 1,2,3))
			where swAgreementId_new is not null;
			

			CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_LOG_0423_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS
			SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST`;


			
			/*	
			with swAgrDesc as (
				(
				select distinct c.*, cxc.swAgreementId, b.swAgreementId as swAgreementId_pr,  1 as swAgreementId_procDesc
				from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c
				inner join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_COMISION` cxc on cxc.swCustomerId=c.swCustomerId and cxc.nCuentas=1
				left join  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_BUZONDESCUBIERTO`  b  on CAST(b.swBuzonId AS STRING)=c.buzon
				)
				UNION ALL(
					select c.*, b.swAgreementId, b.swAgreementId as  swAgreementId_pr, 2  as swAgreementId_procDesc
					from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c
					inner join  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_BUZONDESCUBIERTO`  b 
					--on b.swCustomerId=c.swCustomerId --
					on CAST(b.swBuzonId AS STRING)=c.buzon
					where not exists( 
						select 1 
						from  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_CLIENTExCUENTA_COMISION` cxc 
						where cxc.swCustomerId=b.swCustomerId
						and cxc.nCuentas=1
					)
				)
			)
			
			select distinct c.*, s.swAgreementId, s.swAgreementId_procDesc
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c
			left join swAgrDesc s on  s.swCustomerId=c.swCustomerId  and case when swAgreementId_procDesc=2 then s.buzon=c.buzon ELSE TRUE END
			--where  
			--c.swCustomerId=7684673
			--c.swCustomerId=1724674
			order by brand_ds, swCustomerId,buzon, swAgreementId;

			*/


	
	


		--- PASO 4.3: Enriquezco la tabla HISTORICO_CAPTACION_EUSKALTEL_LIST con el número de buzones creados por cliente en periodo de comisionado
		--- OUT 4.3: HISTORICO_CAPTACION_EUSKALTEL_LIST
		
		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS	
		SELECT c.*, count( if(buzon is not null, buzon, NULL)) over(partition by marca,cif, swCustomerId  order by mes_venta) as nbuz
		FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c 
		order by marca, nbuz desc, cif, swCustomerId,buzon ;


		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_LOG_0430_HISTORICO_CAPTACION_EUSKALTEL_LIST` AS
		SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST`;


	---------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------
	---
	---	PASO 5: Creación de tabla COMISIONxFACTURACION_CAPTACION_LIST
	---



		--- PASO 5.1: Creo tablas con listado de CIFs que facturan y no facturan en los 27 meses previso a creación de buzón	
		--- PASO 5.1.1: Creo tabla AUFAC_COMISIONxNO_FACTURACION_CAPTACION_LIST con listado de buzones asociados a CIFs que no han registrado ninguna factura en los 27 meses previos a la creación del buzón
		--- OUT 5.1.1: AUFAC_COMISIONxNO_FACTURACION_CAPTACION_LIST


		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxNO_FACTURACION_CAPTACION_LIST` AS
		select c.*
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c
		where not exists(
			select 1 
			from  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL` f
			where f.cif=c.cif
		) and c.marca ="K"
		and not contains_substr(cif, "EXTRA")
		and not contains_substr(cif, "APLICA")
		order by 1 asc ,2 asc, 4 asc;


		--- PASO 5.1.2: Creo tabla AUFAC_COMISIONxFACTURACION_CAPTACION_LIST con listado de buzones asociados a CIFs que si han registrado alguna factura en los 27 meses previos a la creación del buzón
		--- OUT 5.1.2: AUFAC_COMISIONxFACTURACION_CAPTACION_LIST

		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS
		select distinct c.*, 
		parse_date("%Y%m%d",CONCAT(CAST(c.mes_venta AS STRING),"01") )as mes_venta_dt,
		f.customer_id,
		f.account_id,
		f.invoice_date, 
		date_diff(f.invoice_date,parse_date("%Y%m%d",CONCAT(CAST(c.mes_venta AS STRING),"01") ), MONTH ) as diff_nmonth, 		
		f.ncustxcif,
		f.naccxcust,
	
		--f.naccount,
		--f.invoice_id,
		f.ninvoice,
		f.vinvoice_id,		

		f.imp_fact, 
		f.imp_amount,
		f.var_arpu, 
		f.arpu_3m, f.arpu_6m, f.arpu_12m,
		f.discounts_amount,
		f.var_disc_amount, 
		f.disc_3m, f.disc_6m, f.disc_12m,
		f.imp_no_disc, 		
		f.var_imp_no_disc, 
		f.imp_no_disc_3m, f.imp_no_disc_6m, f.imp_no_disc_12m,
		f.disc_ratio,
		f.disc_ratio_3m, f.disc_ratio_6m, f.disc_ratio_12m,

		safe_divide (f.imp_amount, f.imp_no_disc) as ratio_arpu_imp_no_disc,		
		safe_divide (f.arpu_3m, f.imp_no_disc_3m) as ratio_arpu_3m_imp_no_disc_3m,
		safe_divide (f.arpu_6m, f.imp_no_disc_6m) as ratio_arpu_6m_imp_no_disc_6m,		
		safe_divide (f.arpu_12m, f.imp_no_disc_12m) as ratio_arpu_12m_imp_no_disc_12m,
		
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_HISTORICO_CAPTACION_EUSKALTEL_LIST` c 
		left join `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL` f on f.cif=c.cif
		where c.marca ="K"
		--and exists(
		--	select 1 
		--	from  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL` f
		--	where f.cif=c.cif 
		--) 
				
		--- PARCHE PARTICULAR PARA CASO EN EL QEU HAY DOS COMISIONES POR CIF, UNA LIGADA A BUZON Y OTRA A EXTRACOMISION, QUE EN EL CASO DE K SE CARACTERIZA POR CAMPO ARPU_MES NO INFORMADO
		and arpu_mes_com is not null
		--- FIN PARCHE
		--and c.cif="A48055891"	
		--and arpu_mes is not null
		 --and c.cif="B95755013"
		order by 1 asc,2 asc, 5 asc, 15 asc, 16 asc;



		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0512_AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`;

		--- PASO 5.1.3: Enriquezco la tabla AUFAC_COMISIONxFACTURACION_CAPTACION_LIST de listado de buzones que si han generado facturas en los últimos 27 meses, con variables de contabilidad de accesos (BA, TF y TM) y contabilidad de número de meses previos a la creación del buzón, en los que la cuenta asociada al buzón, generó una factura
		--- OUT 5.1.3: AUFAC_COMISIONxFACTURACION_CAPTACION_LIST

		------------------
		-- Nuevas variables
		--		Por fila: 
		--			Contabilidad de accesos activos por mes facturado:	accesos BA (nBA), accesos TF (nTF), accesos TM (nTM)
		--			nmesesfact_preventa: Contabilidad de número de meses previos al buzón, en los que la cuenta asociada al buzónm, generó una factura		


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST_NEW` AS	
		with ns as (
			with p as (
				--- Tripletas marca, customer_id, fecha de factura
				select distinct brand_ds, invoice_date, customer_id  from  `mm-commissions-reporting.KRT_CAP_PYME.LOG_0512_AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`
			)
			select p.brand_ds, p.invoice_date, p.customer_id,-- Date_diff(p.invoice_date,EXTRACT( DATE FROM s.fecha_rfb_dt),DAY),
			count(distinct if(service_type='BROADBAND', service_id, NULL)) as nBA,
			count(distinct if(service_type='FIX', service_id, NULL)) as nTF,
			count(distinct if(service_type='MOBILE' and billing_type_ds="POSTPAID", service_id, NULL)) as nTM,
			from p 
			inner join `mm-datamart-kd.SERVICES.service_base_telco` s on s.brand_ds=p.brand_ds and s.customer_id=CAST(p.customer_id AS STRING)
			-- el invoice date es la fecha del primer día del mes que se factura y contiene la facturación de servicios activos entre día 22 de mes previo y 21 del mes en curso
			-- la fecha rfb debe ser anterior a la fecha de fin de factura
			-- la fecha de baja debe se posterior a  la fecha de inicio de factura
			and Date_diff(PARSE_DATE("%Y%m%d",CONCAT(FORMAT_DATE("%Y%m",p.invoice_date),"21")) ,s.activation_date,DAY)>=0 
			and Date_diff(s.deactivation_date,date_sub(PARSE_DATE("%Y%m%d",CONCAT(FORMAT_DATE("%Y%m",p.invoice_date),"22")), interval 1 MONTH) ,DAY) >=0
			group by 1,2,3 
			order by 1,3,2
		) select distinct cxf.*, ns.nBA, ns.nTF, ns.nTM , count( distinct if( diff_nmonth<0,cxf.invoice_date,NULL)) over(PARTITION BY cxf.brand_ds, cif) as nmesesfact_preventa 
		from `mm-commissions-reporting.KRT_CAP_PYME.LOG_0512_AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` cxf 
		left join ns on cxf.brand_ds=ns.brand_ds and cxf.invoice_date=ns.invoice_date and cast(cxf.customer_id AS STRING)=cast(ns.customer_id AS STRING)
		--where buzon="21216378"
		order by 2,3,7, 22;




		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS	
		with ns as (
			with p as (
				--- Tripletas marca, customer_id, fecha de factura
				select distinct brand_ds, invoice_date, customer_id  from  `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_FACTURACION_CAPTACION_EUSKALTEL`
			)
			select p.brand_ds, p.invoice_date, p.customer_id,-- Date_diff(p.invoice_date,EXTRACT( DATE FROM s.fecha_rfb_dt),DAY),
			count(distinct if(categoria_servicio_ds='BANDA ANCHA', servicio_id, NULL)) as nBA,
			count(distinct if(categoria_servicio_ds='FIJA', servicio_id, NULL)) as nTF,
			count(distinct if(categoria_servicio_ds='MOVILES POSTPAGO', servicio_id, NULL)) as nTM,
			from p 
			inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on s.marca_ds=p.brand_ds and s.cliente_id=p.customer_id 
			-- el invoice date es la fecha del primer día del mes que se factura y contiene la facturación de servicios activos entre día 22 de mes previo y 21 del mes en curso
			-- la fecha rfb debe ser anterior a la fecha de fin de factura
			-- la fecha de baja debe se posterior a  la fecha de inicio de factura
			and Date_diff(PARSE_DATE("%Y%m%d",CONCAT(FORMAT_DATE("%Y%m",p.invoice_date),"21")) ,EXTRACT( DATE FROM s.fecha_rfb_dt),DAY)>=0 
			and Date_diff(EXTRACT( DATE FROM s.fecha_baja_dt),date_sub(PARSE_DATE("%Y%m%d",CONCAT(FORMAT_DATE("%Y%m",p.invoice_date),"22")), interval 1 MONTH) ,DAY) >=0
			group by 1,2,3 
			order by 1,3,2
		) select distinct cxf.*, ns.nBA, ns.nTF, ns.nTM , count( distinct if( diff_nmonth<0,invoice_date,NULL)) over(PARTITION BY brand_ds, cif) as nmesesfact_preventa 
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` cxf 
		left join ns using(brand_ds, invoice_date, customer_id)
		--where buzon="21216378"
		order by 2,3,7, 22;

		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0513_AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`;

		-- Tabla que integra de la evolución de facturacion de cuenta asociada a cada buzon que factura

		--- PASO 5.1.4: Recreo tabla AUFAC_COMISIONxFACTURACION_CAPTACION_LIST integrando la evolución de la facturacion de la cuenta asociada a cada buzon que factura, y la no evolución de la facturación de los buzones que no facturan, enriquecidos con múltiples variables 
		--- OUT 5.1.4: AUFAC_COMISIONxFACTURACION_CAPTACION_LIST
		------------------
		-- Nuevas variables
		--		Por fila: 
		--			indUltimoMesFactura:			Índice del último mes en el que hay factura. 
		--												Se calcula como valor máximo del índice del mes informado por marca, id cliente e id cuenta (este indicador sólo se informa si hay factura)
		--			indMesAct						Índice del primer mes en el que hay factura. 
		--												Se calcula como valor mínimo del índice del mes informado  por marca, id cliente e id cuenta (este indicador sólo se informa si hay factura)		
		--			indMesActBA						Índice del primer mes en el que hay factura en un buzon que contiene un BA.
		--												Se calcula como valor mínimo del índice del mes informado  por marca, id cliente e id cuenta (este indicador sólo se informa si hay factura)	
		--			bCaptacion: 					Indicador booleano que informa si el cliente se puede considerar de captación. 
		--												Se considera captación si el índice del primer mes en el que hay facturación de BA es mayor o igual que 0 
		--			bActivacion:					Indicador booleano que informa si el ultimo mes del que hay factura es posterior a creación de buzón
		--			bFactPrevia						Indicador booleano que informa si el buzón está asociado a una cuenta que facturaba antes de su creación
		--			clase							Segmenta el buzón en nuevo cliente o ya cliente
		--												Nuevo cliente: No se registra facturación previa a mes de comisionado para el id cliente 
		--												Ya cliente:  Se registra facturación previa a mes de comisionado del id cliente 
		--			categoria						captación o cartera	
		--												Captación: Se registra activación de BA en meses posteriores a mes de venta de buzón 
		--															o No se registra facturación previa a mes de comisionado para el id cliente y no se informa mes de activación de BA
		--												Cartera: Se registra factura previa de cliente
		--			imp_amount_m0					Importe facturado en mes 0
		--			a3_m0							Arpu a 3 meses del importe facturado en mes 0
		--			a6_m0							Arpu a 6 meses del importe facturado en mes 0
		--			via_m0							Variación del importe respecto al facturado en mes0
		--			va3_m0							Variación del arpu a 3 meses respecto al registrado en mes0
		--			va6_m0							Variación del arpu a 6 meses respecto al registrado en mes0	
		--			pia_m0							Porcentaje de variación del importe facturado respecto al facturado en mes0
		--			pa3_m0							Porcentaje de variación del arpu a 3 meses respecto al registrado en mes0
		--			pa6_m0							Pocentaje de variación del arpu a 6 meses respecto al registrado en mes0	
		--			via_arp_est						Variación del importe facturado respecto al arpu estimado en el comisionado del buzón
		--			va3_arp_est						Variación del arpu a 3 meses respecto al arpu estimado en el comisionado del buzón
		--			va6_arp_est						Variación del arpu a 6 meses respecto al arpu estimado en el comisionado del buzón
		--			pia_arpu_est					Porcentaje de variación del importe facturado respecto al arpu estimado en el comisionado del buzón
		--			pa3_arpu_est					Porcentaje de variación del arpu a 3 meses respecto al arpu estimado en el comisionado del buzón
		--			pa6_arpu_est					Porcentaje de variación del arpu a 6 meses respecto al arpu estimado en el comisionado del buzón	
		
		
		--			disc_m0							Descuento facturado en mes 0
		--			d3_m0							Descuento a 3 meses del importe facturado en mes 0
		--			d6_m0							Descuento a 6 meses del importe facturado en mes 0
		--			vda_m0							Variación del descuento respecto al facturado en mes0
		--			vd3_m0							Variación del descuento a 3 meses respecto al registrado en mes0
		--			vd6_m0							Variación del descuento a 6 meses respecto al registrado en mes0	

		
		
		--		Cruce por marca, cif 	
	
	
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS	
		with p as (
			--- Tabla con relaciones  cliente y cuenta vinculada a buzones creados en periodo de comisionado y que han generado facturación, caracterizados en función de si son nuevos clientes, si ya disponían o no de BA antes de creación de buzón y por tanto si las operaciones sobre ellos pueden ser consideradas como  operaciones de captación o cortera
			with mxc as ( 
				-- Población de tripletas marca, customer_id, account_id informadas (buzones con factura)
				select distinct marca, customer_id, account_id 
				from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` 
				where customer_id is not null
			),
			im0 as ( 
				-- Poblacion de tripletas marca, customer_id , account_id enriquecida con datos en caso de que esté informada comisión en m0
				select marca, customer_id,account_id,nBA, sum(imp_amount)  as ia_m0, sum(arpu_3m) as a3_m0, sum(arpu_6m) as a6_m0 
				from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` 
				where diff_nmonth=0		
				and buzon is not null
				group by 1,2,3,4
			), 
			cpba as(
			
				with ba as(
						--- Población de buzones en los que facturan 1 o más accesos BA
						select distinct marca, customer_id,account_id,--nBA,
						min(diff_nmonth) over (partition by marca, customer_id, account_id order by diff_nmonth asc) as indmesActBACuenta, 
						min(diff_nmonth) over (partition by marca, customer_id order by diff_nmonth asc) as indmesActBACliente,
						min(diff_nmonth) over (partition by marca, cif order by diff_nmonth asc) as indmesActBACif,					
						from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` 
						where 
						--coalesce(nBA,0)>=1
						--and diff_nmonth>=-1
						buzon is not null
						and NBA>=1
						--and customer_id=3570270
						--and buzon="20749742"
				)
				
				select distinct f.marca, f.customer_id,f.account_id,--nBA,
				max(f.diff_nmonth) over (partition by f.marca, f.customer_id, f.account_id) as indUltimoMesFactura,		
				min(f.diff_nmonth) over (partition by f.marca, f.customer_id, f.account_id) as indMesAct,
				ba.indmesActBACuenta, 
				ba.indmesActBACliente,
				ba.indmesActBACif,
				case when min(f.diff_nmonth)  over (partition by f.marca, customer_id, f.account_id) < 0 then 1 else 0 end as bFacturaPreviaCuenta,
				case when min(f.diff_nmonth)  over (partition by f.marca, customer_id) < 0 then 1 else 0 end as bFacturaPreviaCliente,
				case when min(f.diff_nmonth)  over (partition by f.marca, cif) < 0 then 1 else 0 end as bFacturaPreviaCif,			
				from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` f
				left join ba using(marca,customer_id,account_id)
				where 
				--coalesce(nBA,0)>=1
				--and diff_nmonth>=-1
				buzon is not null
				--and customer_id=3570270
				--and buzon="20749742"
				
			)

			select mxc.*, 
			cpba.indUltimoMesFactura,
			cpba.indMesAct,
			cpba.indmesActBACuenta,
			cpba.indmesActBACliente,
			cpba.indmesActBACif,
			case when cpba.indUltimoMesFactura <0 then 0 else 1 end as bActivacion,
			--case when (coalesce(im0.ia_m0,0)=0 or coalesce(im0.nBA,0)=0) then 1 else 0 end as bCaptacionOld, 
			case when cpba.indmesActBACliente>=0 then 1 else 0 end as bCaptacion, 
			cpba.bFacturaPreviaCuenta,
			cpba.bFacturaPreviaCliente,
			cpba.bFacturaPreviaCif,		
			case when cpba.bFacturaPreviaCliente=0 then  "Nuevo cliente"
				 when cpba.bFacturaPreviaCliente=1 then  "Ya cliente"
				 end as clase,
			case when cpba.indmesActBACliente>=0 Then "Captacion"
				 when cpba.indmesActBACliente  is null and cpba.bFacturaPreviaCliente=0 Then "Captacion"		
				 when cpba.bFacturaPreviaCliente=1 Then "Cartera"
				 --when cpba.indUltimoMesFactura is Null then  "NoEjecutado"			 
				 --when cpba.indmesActBACliente  is null Then "Resto"
			end as categoria,	
			case 
				 when cpba.indUltimoMesFactura <1 Then "NoFactura" 
				 when cpba.indmesActBACliente>=0 and cpba.bFacturaPreviaCliente=0 Then "Nuevo cliente activa BA" 
				 when cpba.indmesActBACliente  is null and cpba.bFacturaPreviaCliente=0 Then "Nuevo cliente no activa BA" 			 
				 when cpba.indmesActBACliente>=0 and cpba.bFacturaPreviaCliente=1 Then "Ya cliente sin BA activa BA" 
				 when cpba.indmesActBACliente<0 and cpba.bFacturaPreviaCliente=1 Then  "Ya Cliente con BA" 
				 when cpba.indmesActBACliente is null and cpba.bFacturaPreviaCliente=1 Then "Ya cliente sin BA no activa BA" 
				 when cpba.indUltimoMesFactura is Null then  "NoEjecutado"			 
			end as tipoComision,	
			im0.ia_m0,im0.a3_m0,im0.a6_m0 
			from mxc
			left join im0 using(marca, customer_id, account_id)
			left join cpba using(marca, customer_id, account_id)		
			--where mxc.customer_id=3453726
			order by 1,2		

		) /*Fin de CTE p*/
		
		--- Tabla que integra de la evolución de facturacion de cuenta asociada a cada buzon que factura
		---	se pone nueva condición de que account_id no es nulo para asegurar que en esta población sólo entran los buzones que ha llegado a facturar
		(
			select distinct cf.*, 
			p.indUltimoMesFactura,
			p.indMesAct,
			p.indmesActBACuenta,
			p.indmesActBACliente,
			p.indmesActBACif,		
			p.bActivacion,
			--p.bCaptacionOld, 
			p.bCaptacion, 
			
			p.bFacturaPreviaCuenta,
			p.bFacturaPreviaCliente,
			p.bFacturaPreviaCif,			
			p.clase,
			p.categoria,
			p.tipoComision,
			
			p.ia_m0, p.a3_m0, p.a6_m0,
			-- Variación respecto a mes 0	
			case  when p.bCaptacion=0 then imp_amount-p.ia_m0
					when p.bCaptacion=1 then imp_amount 		
			end as via_m0,
			case when p.bCaptacion=0 then arpu_3m-p.a3_m0 
				 when p.bCaptacion=1 then arpu_3m 		
			end as va3_m0,
			case when p.bCaptacion=0 then arpu_6m-p.a6_m0 
				 when p.bCaptacion=1 then arpu_6m 		
			end as va6_m0,
			-- Porcentaje de variación respecto a mes 0
			case when p.bCaptacion=0 then case when (imp_amount>p.ia_m0)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((imp_amount-p.ia_m0),p.ia_m0))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(imp_amount,p.ia_m0))) end 
				 when p.bCaptacion=1 then  case when (imp_amount>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((imp_amount-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(imp_amount,arpu_mes_com))) end  
			end  as pia_m0,
			case when p.bCaptacion=0 then case when (arpu_3m>p.a3_m0)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_3m-p.a3_m0),p.a3_m0) ) else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_3m,p.a3_m0)))  end 
				 when p.bCaptacion=1 then case when (arpu_3m>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_3m-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_3m,arpu_mes_com))) end
			end as  pa3_m0,
			case when p.bCaptacion=0 then case when (arpu_6m>p.a6_m0)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_6m-p.a6_m0),p.a6_m0))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_6m,p.a6_m0))) end 
				 when p.bCaptacion=1 then case when (arpu_6m>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_6m-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_6m,arpu_mes_com))) end    
			end as  pa6_m0,
			
			
			-- Variación respecto a arpu estimado para calculo de comisionado
			imp_amount-arpu_mes_com as via_arp_est,
			arpu_3m-arpu_mes_com as va3_arp_est,
			arpu_6m-arpu_mes_com as va6_arp_est,
			
			-- Porcentaje de variación respecto a arpu estimado para comisionado
			--		Diferenciamos entre captación y cartera
			--			En captación
			--					Numerador: Incremento de arpu a N meses	
			--					Denominador: Arpu a N meses en mes 0 (demominador).
			--			En cartera 
			--					En cartera, 
			--						Arpu objetivo es la suma del arpu_3m en m0 + arpu COMISIONADO	
			--						Cumplimiento de arpu objetivo= porcentaje entre importe facturado  y arpu objetivo (suma arpu_3m en mes 0 + arpu comisionado)
			--							Numerador: 	 	
			--							Denominador: Arpu objetivo
			--						
			
			-- Porcentaje de variación respecto a arpu estimado para comisionado
			case when p.bCaptacion=0 then case when (imp_amount> p.ia_m0 + arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((imp_amount-(p.ia_m0 + arpu_mes_com) ),(p.ia_m0+arpu_mes_com)))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(imp_amount,p.ia_m0+arpu_mes_com))) end 
				 when p.bCaptacion=1 then case when (imp_amount>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((imp_amount-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(imp_amount,arpu_mes_com))) end  
			end  as pia_arpu_est,
				
			case when p.bCaptacion=0 then case when (arpu_3m> p.a3_m0 + arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_3m-(p.a3_m0 + arpu_mes_com) ),(p.a3_m0+arpu_mes_com)))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_3m,p.a3_m0+arpu_mes_com))) end 
											--case when (arpu_3m>p.a3_m0)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_3m-p.a3_m0),p.a3_m0) ) else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_3m,p.a3_m0)))  end 																					
				 when p.bCaptacion=1 then case when (arpu_3m>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_3m-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_3m,arpu_mes_com))) end
			end as  pa3_arpu_est,
			
			case when p.bCaptacion=0 then case when (arpu_6m> p.a6_m0 + arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_6m-(p.a6_m0 + arpu_mes_com) ),(p.a6_m0+arpu_mes_com)))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_6m,p.a6_m0+arpu_mes_com))) end 
											--case when (arpu_6m>p.a6_m0)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_6m-p.a6_m0),p.a6_m0))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_6m,p.a6_m0))) end 
				 when p.bCaptacion=1 then case when (arpu_6m>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_6m-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_6m,arpu_mes_com))) end   										-- 
			end as  pa6_arpu_est,
				
			---case when (imp_amount>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((imp_amount-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(imp_amount,arpu_mes_com))) end  as pvia_arpu_est,
			---case when (arpu_3m>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_3m-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_3m,arpu_mes_com))) end as  pa3_arpu_est,
			---case when (arpu_6m>arpu_mes_com)  then SAFE_MULTIPLY(100, SAFE_DIVIDE((arpu_6m-arpu_mes_com),arpu_mes_com))   else SAFE_MULTIPLY(100, SAFE_NEGATE(1- SAFE_DIVIDE(arpu_6m,arpu_mes_com))) end as  pa6_arpu_est,   		
			
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` cf 
			left  join  p on p.marca=cf.marca and p.customer_id=cf.customer_id and p.account_id=cf.account_id		
			where cf.buzon is not null 
			and cf.account_id is not null
			--where cif="A48055891" -- caso de 3 buzones por cliente
			--where cif="B95755013"
			--and cif="B95106753"	
			--where cif="13734160D" -- caso de 2 cuentas por cliente-
			--and cif="72722231A"
			order by marca, cif, account_id, ncomxcif, ind, invoice_date
		)
		UNION ALL 
		--- evolución de facturacion de cuenta no asociada buzon
		(
			select distinct cf.*, 
			p.indUltimoMesFactura,
			p.indMesAct,
			p.indmesActBACuenta,
			p.indmesActBACliente,
			p.indmesActBACif,
			p.bActivacion,
			--p.bCaptacionOld, 
			p.bCaptacion, 
			
			p.bFacturaPreviaCuenta,
			p.bFacturaPreviaCliente,
			p.bFacturaPreviaCif,					
			p.clase,
			p.categoria,
			p.tipoComision,
			
			---p.ia_m0, p.a3_m0, p.a6_m0,
			NULL, NULL, NULL,
			NULL,NULL,NULL,
			NULL,NULL,NULL,
			NULL,NULL,NULL,
			NULL,NULL,NULL
			
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` cf 
			left  join  p on p.marca=cf.marca and p.customer_id=cf.customer_id and p.account_id=cf.account_id
			where cf.buzon is null
			--and cif="B95106753"
			--and cif="72722231A"		
		)
		
		UNION ALL 
		--- buzones sin facturacion
		(
			select distinct cf.*, 
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,
			NULL,		
			--NULL,
			NULL, 
			
			p.bFacturaPreviaCuenta,
			p.bFacturaPreviaCliente,
			p.bFacturaPreviaCif,					
			p.clase,
			p.categoria,
			"NoFactura",
			
			---p.ia_m0, p.a3_m0, p.a6_m0,
			NULL, NULL, NULL,
			NULL,NULL,NULL,
			NULL,NULL,NULL,
			NULL,NULL,NULL,
			NULL,NULL,NULL
			
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` cf 
			left  join  p on p.marca=cf.marca and p.customer_id=cf.customer_id and p.account_id=cf.account_id
			where cf.account_id is null
			--and cif="B95106753"
			--and cif="72722231A"		
		)	
		;	
		

		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0514_AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`;

		--- PASO 5.1.5: Tipificación de los registros de la tabla de comisiones vinculadas a buzones que no facturan (campo buzon informado y cruce con tabla AUFAC_COMISIONxNO_FACTURACION_CAPTACION_LIST)
		--- OUT 5.1.5.1: AUFAC_COMISIONxFACTURACION_CAPTACION_LIST

		UPDATE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` c
		SET clase="NoEjecutado",
		categoria="NoEjecutado"
		FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxNO_FACTURACION_CAPTACION_LIST` b
		where c.marca=b.marca
		and c.cif=b.cif
		and c.buzon=b.BUZON
		and c.mes_abono=b.mes_abono;
		
		CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0515_AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`;

		--- PASO 5.1.6: Tipifico los buzones agregando datos de tabla AUFAC_COMISIONxFACTURACION_CAPTACION_LIST
		
		--- PASO 5.1.6.1: Creo tabla con tipificación de buzones

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_BUZONES_TIPIFICADOS_LIST` AS	
			--- Buzones que no han llegado a generar facturacion
		(select b.* 
		except(invoice_date, ninvoice, vinvoice_id, imp_amount, diff_nmonth, var_arpu, arpu_3m, arpu_6m, arpu_12m, nBA, nTF, nTM, nmesesfact_preventa, ia_m0, a3_m0, a6_m0, via_m0, va3_m0, va6_m0, pia_m0, pa3_m0, pa6_m0, via_arp_est, va3_arp_est, va6_arp_est, pia_arpu_est, pa3_arpu_est, pa6_arpu_est,  account_id,customer_id, indMesAct, indMesActBACif, indMesActBACliente, indMesActBACuenta,bFacturaPreviaCif,bFacturaPreviaCliente,bFacturaPreviaCuenta,indUltimoMesFactura),
		(nBA_com + nTF_com + nTM_com) as nRGU_com, SAFE_DIVIDE(comision_total,(nBA_com + nTF_com + nTM_com)) as comision_totalxcifxrgu, SAFE_DIVIDE(comision_acumuladaxcif,(nBA_com + nTF_com + nTM_com)) as comision_acumuladaxcifxrgu,
		2 as grb
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` b where diff_nmonth is null)
		UNION ALL
		(	
		--- Buzones que han llegado a facturar
		with p as (
			--- Meses transcurridos entre la creación del buzón y la primera factura
			select marca, buzon, max(diff_nmonth)as diff_nmonth--, count(diff_nmonth) as nf  
			from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`  
			where diff_nmonth>0 group by 1,2

		)
		----Población de buzones 
		select distinct b.* 
		except(invoice_date, ninvoice, vinvoice_id, imp_amount, diff_nmonth, var_arpu, arpu_3m, arpu_6m, arpu_12m, nBA, nTF, nTM, nmesesfact_preventa, ia_m0, a3_m0, a6_m0, via_m0, va3_m0, va6_m0, pia_m0, pa3_m0, pa6_m0, via_arp_est, va3_arp_est, va6_arp_est, pia_arpu_est, pa3_arpu_est, pa6_arpu_est, account_id,customer_id, indMesAct, indMesActBACif, indMesActBACliente, indMesActBACuenta,bFacturaPreviaCif,bFacturaPreviaCliente,bFacturaPreviaCuenta,indUltimoMesFactura),
		(nBA_com + nTF_com + nTM_com) as nRGU_com,SAFE_DIVIDE(comision_total,(nBA_com + nTF_com + nTM_com)) as comision_totalxcifxrgu, SAFE_DIVIDE(comision_acumuladaxcif,(nBA_com + nTF_com + nTM_com)) as comision_acumuladaxcifxrgu,
		1 as grb 
		from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` b
		inner join p using(marca, buzon, diff_nmonth)
		);

		
		--- PASO 5.1.6.2: Tipifico con clase "NoFactura" y tipo "NoFactura" aquellos buzones con tipo comision que contienen texto Factura o NoEjecuta en campo Tipocomision		
		UPDATE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_BUZONES_TIPIFICADOS_LIST`
		SET clase="NoFactura",
		categoria="NoFactura"	
		WHERE contains_substr(tipoComision,"Factura")
		or  contains_substr(tipoComision,"NoEjecuta");

		
		--- PASO 5.1.6.3: Tipifico con clase "NoFactura" y tipo "NoFactura" aquellos buzones cuyo último mes facturado es previo a la creación del buzón
		
/*		UPDATE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_BUZONES_TIPIFICADOS_LIST` b
		SET clase="NoFactura",
		categoria="NoFactura"	
		FROM (
				select distinct marca, cif, customer_id,account_id, buzon, ncomxcif,comision_total, comision_Acumuladaxcif,
				max(diff_nmonth) over (partition by marca, customer_id, account_id,buzon) as indmesAct, 
				max(invoice_date) over (partition by marca, customer_id, account_id,buzon) as indmesFact, 
				from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` 
				where buzon is not null
				Qualify indmesAct<1
				order by 10 desc
		)	n
		WHERE n.marca=b.marca
		and	n.buzon=b.buzon
		and n.cif=b.cif;
    	--and n.customer_id=b.swcustomerid;
*/
		UPDATE `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_BUZONES_TIPIFICADOS_LIST` b
		SET clase="NoFactura",
		categoria="NoFactura"	
		FROM (
				with p as (
					select distinct marca, cif, customer_id,account_id, buzon, ncomxcif,comision_total, comision_Acumuladaxcif,
					max(diff_nmonth) over (partition by marca, customer_id, account_id,buzon) as indmesAct, 
					max(invoice_date) over (partition by marca, customer_id, account_id,buzon) as indmesFact, 
					from `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` 
					where buzon is not null
					Qualify indmesAct<1
					order by 2 desc
				)
				select distinct marca, cif, customer_id,account_id, buzon
				from p 
				
		)	n
		WHERE n.marca=b.marca
		and	n.buzon=b.buzon
		and n.cif=b.cif;
    	--and n.customer_id=b.swcustomerid;



	CREATE OR  REPLACE TABLE `mm-commissions-reporting.KRT_CAP_PYME.LOG_0516_AUFAC_COMISIONxFACTURACION_CAPTACION_LIST` AS SELECT * FROM `mm-commissions-reporting.KRT_CAP_PYME.AUFAC_COMISIONxFACTURACION_CAPTACION_LIST`;
	

END