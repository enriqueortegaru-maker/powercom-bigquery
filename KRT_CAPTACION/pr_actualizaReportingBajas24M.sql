BEGIN
	DECLARE vMES_BAJA_DT DATE;
	-- FIX: removed unused vMES_BAJA_ID declaration
	DECLARE vMES_DECOMISION_ID INT64;
	--LOCAL
	--DECLARE NMESES INT64;SET NMESES=0;
	SET vMES_BAJA_DT=date_trunc(date_sub(CURRENT_DATE('Europe/Madrid'), interval nmeses month),month);
	SET vMES_DECOMISION_ID=CAST(FORMAT_DATE("%Y%m",date_trunc(date_sub(CURRENT_DATE('Europe/Madrid'),interval nmeses month),month)) as int64);


		/* PASO 1: RECUPERO EL FICHERO DE BAJAS DE SERVICIOS PRINCIPALES DEL MES QUE SE VA A ANALIZAR  */
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_CARGA_REPORTING` AS
	SELECT *	FROM  `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_HISTORICO` where mes_baja_dt=vMES_BAJA_DT;

		/* PASO 2: BORRO DEL FICHERO DE REPORTING LOS REGISTROS DE MES A ACTUALIZAR*/

	DELETE	FROM  `mm-commissions-reporting.KRT_CAPTACION.REPORTING_BAJAS24M` where mes_baja_dt=vMES_BAJA_DT;
	DELETE	FROM  `mm-commissions-reporting.KRT_CAPTACION.REPORTING_BAJAS24M_NOPART` where mes_baja_dt=vMES_BAJA_DT;


		/* PASO 3: OBTENGO INDICADORES DE BAJAS A INSERTAR EN FICHERO DE REPORTING*/


		/* pr:bajas que cruzan con registro de portabilidad enriquecido con dato de operador receptor de la portabilidad */

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P1` AS
	with bf as (
		select distinct b.marca_ds, b.cliente_id, b.servicio_id, b.fecha_rfb_dt, b.fecha_baja_dt, b.motivo_baja_agrup_ds, b.motivo_baja_ds,
		EXTRACT(DATE FROM p.date_vc) as fecha_ventana_cambio_dt,
		p.operator_receiver as operador_receptor_ds,
		p.brand_receiver as marca_operador_receptor_ds,
		SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] as grupo_operador_receptor_ds,
		SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] as agrup_operador_receptor_ds,
		date_diff(EXTRACT(DATE FROM p.date_vc), EXTRACT(DATE FROM b.fecha_baja_dt), DAY) as ndias,
		from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_CARGA_REPORTING` b
		inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on s.cliente_id=b.cliente_id and s.servicio_id=b.servicio_id and not contains_substr(s.categoria_servicio_ds,'MOVIL')
			                        inner JOIN  `mm-datamart-kd.PORTABILITY.portability_fix_base` p ON s.ani=p.phone_nm
		where p.operator_code_donor in ("00020","00015","00008")
		and ABS(date_diff(EXTRACT(DATE FROM p.date_vc), EXTRACT(DATE FROM b.fecha_baja_dt),  DAY))<30
		and p.confirmation_date is not null
		and EXTRACT(DATE from date_trunc(b.fecha_baja_dt,month))=vMES_BAJA_DT


	), bm as (
		select distinct b.marca_ds, b.cliente_id, b.servicio_id, b.fecha_rfb_dt, b.fecha_baja_dt, b.motivo_baja_agrup_ds, b.motivo_baja_ds,
		EXTRACT(DATE FROM p.vc_date) as fecha_ventana_cambio_dt,
		p.operator_receiver as operador_receptor_ds,
		p.brand_receiver as marca_operador_receptor_ds,
		SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] as grupo_operador_receptor_ds,
		SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] as agrup_operador_receptor_ds,
		date_diff(EXTRACT(DATE FROM p.vc_date), EXTRACT(DATE FROM b.fecha_baja_dt), DAY) as ndias,
		from `mm-commissions-reporting.KRT_CAPTACION.BAJAS_SB_24M_CARGA_REPORTING` b
		inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on s.cliente_id=b.cliente_id and s.servicio_id=b.servicio_id and contains_substr(s.categoria_servicio_ds,'MOVIL')
		inner JOIN  `mm-datamart-kd.PORTABILITY.portability_mobile_base` p ON s.ani=p.msisdn
		where  p.operator_code_donor in("006","073","053")
		and ABS(date_diff(EXTRACT(DATE FROM p.vc_date), EXTRACT(DATE FROM b.fecha_baja_dt),  DAY))<30
		and cancelation_date is null
		and reject_date is null
		and EXTRACT( DATE FROM date_trunc(b.fecha_baja_dt,month))=vMES_BAJA_DT
	)
	select "fijo" as tipo, bf.*, row_number() over( partition By bf.marca_ds, bf.cliente_id,bf.servicio_id  ORDER BY date_diff(bf.fecha_ventana_cambio_dt, EXTRACT(DATE FROM bf.fecha_baja_dt), DAY) desc) as indice
	from bf
	union all
	select "movil" as tipo, bm.*, row_number() over( partition By bm.marca_ds, bm.cliente_id,bm.servicio_id ORDER BY date_diff(bm.fecha_ventana_cambio_dt, EXTRACT(DATE FROM bm.fecha_baja_dt), DAY) desc) as indice
	from bm;


		/* por: en caso de varias posibilidades, se selecciona el que tenga menor distancia temporal entre baja y ventana de cambio */
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P2`  AS
				select distinct *
				from `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P1`
				where indice=1;

		/* l: listado de todas las bajas relacionaddas con activaciones de los últimos 24 meses, enriquecidas con datos de portabilidad  */

	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P3`  AS
	with c as (
			SELECT mes_decomision_id, marca_ds, cliente_id, servicio_id,tipo_canal_alta_ds, canal_alta_ds,subcanal_ds,desc_mm,nombre_distribuidor_alta_ds,concepto_ds,
			CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_rfb_dt)) as INT64) as mes_rfb_id,
			CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_baja_dt)) as INT64) as mes_baja_id,
			-- Native calculation: avoids fmonths_between UDF which can return NULL for valid dates.
			GREATEST(0, CAST(DATE_DIFF(EXTRACT(DATE from fecha_baja_dt),EXTRACT(DATE from fecha_rfb_dt),MONTH) AS INT64)) AS NMONTHS,
			GREATEST(0, CAST(DATE_DIFF(EXTRACT(DATE from fecha_baja_dt),EXTRACT(DATE from fecha_rfb_dt),DAY) AS INT64)) AS NDAYS
			from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_24M_HISTORICO`
			where mes_decomision_id=vmes_decomision_id
	)
	select  distinct c.*, port.marca_operador_receptor_ds,port.grupo_operador_receptor_ds,
	CASE WHEN Contains_substr(port.grupo_operador_receptor_ds,"DIGI SPAIN") THEN "DIGI"
	WHEN Contains_substr(port.grupo_operador_receptor_ds,"ADAMO") THEN "ADAMO"
	WHEN Coalesce(port.grupo_operador_receptor_ds,"NULO")="NULO" THEN "NOINF"
	ELSE agrup_operador_receptor_ds END AS agrup_operador_receptor_ds,
	from  c
	left join `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P2`as port on c.cliente_id=port.cliente_id and c.servicio_id=port.servicio_id
	where (CONTAINS_SUBSTR(c.desc_mm,'Servicio') or CONTAINS_SUBSTR(c.desc_mm,'Portabilidad')  or CONTAINS_SUBSTR(c.desc_mm,'Television acceso') or CONTAINS_SUBSTR(c.desc_mm,'Terminal') or CONTAINS_SUBSTR(c.desc_mm,'Netflix')
	or CONTAINS_SUBSTR(c.concepto_ds,'dazn')  or CONTAINS_SUBSTR(c.concepto_ds,'modulo pro') or CONTAINS_SUBSTR(c.concepto_ds,'alarma') or CONTAINS_SUBSTR(c.concepto_ds,'amazon')  or CONTAINS_SUBSTR(c.concepto_ds,'hegan')
	or CONTAINS_SUBSTR(c.concepto_ds,' GB')  or CONTAINS_SUBSTR(c.concepto_ds,'mambo') or CONTAINS_SUBSTR(c.concepto_ds,'hegan') or CONTAINS_SUBSTR(c.concepto_ds,'llamadas') or CONTAINS_SUBSTR(c.concepto_ds,'ayud')
	or CONTAINS_SUBSTR(c.concepto_ds,'bar')  or CONTAINS_SUBSTR(c.concepto_ds,'combi') )
	and not contains_substr(c.concepto_ds,'penaliza')
	and not contains_substr(c.concepto_ds,'post ')
	-- FIX BUG 1: original filter using c.mes_baja_id (clawback column, never null).
	-- The _20260701 version used port.fecha_baja_dt which is NULL when there is no portability
	-- match, silently turning the LEFT JOIN into an INNER JOIN and dropping all non-porting bajas.
	and c.mes_decomision_id = c.mes_baja_id
	;



	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P4`  AS
		/* rd: listado de todas las bajas relacionaddas con activaciones de los últimos 24 meses, enriquecidas con datos de portabilidad e indicadores de duración de perido activo  */
		select l.*, PERCENT_RANK() OVER (PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds ORDER BY ndays ASC) AS pDiario,
		-- FIX BUG 5: restored ELSE clause to avoid NULL grnmonths when NMONTHS >= 25
		case
			when nmonths <7 then 0
			when nmonths <13 then 7
			when nmonths <19 then 13
			else 19
					END as grnmonths_id,
		case
			when nmonths <7 then '0-6'
			when nmonths <13 then '7-12'
			when nmonths <19 then '13-18'
			else '19-24'
		END as grnmonths
		from  `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P3` as l
		order by mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds,nmonths, ndays;



	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P5`  AS
		/* sind: listado de todas las bajas relacionaddas con activaciones de los últimos 24 meses, enriquecidas con datos de portabilidad, agrupadores temporales*/
		select *, last_value(pDiario) OVER (PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds,nmonths ORDER BY nmonths ASC) AS pMensual,
		from `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P4`
		order by mes_decomision_id, marca_ds, tipo_canal_alta_ds, nombre_distribuidor_alta_ds,nmonths, ndays;

		/* 6: listado de todas las bajas que hubieran registrado clawback si este considerara un periodo de 24 Meses */

	-- FIX BUG 3 + BUG 4: restructured P6 into two CTEs so that NMONTHS/NDAYS/grnmonths are
	-- computed directly from clawback dates (never NULL) and pDiario/pMensual are taken from
	-- sind with COALESCE. The _20260701 version pulled all these from sind, which is NULL for
	-- records with no portability match. Also restored the month-guard filter in C (BUG 4).
	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P6`  AS
	with c as (
		SELECT  distinct * except(subsegmento_ds, orden_sap)
		from  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_24M_HISTORICO`
		where mes_decomision_id=vmes_decomision_id
		and not contains_substr(desc_mm, 'extra')
		and not contains_substr(desc_mm, 'rappel')
		and not contains_substr(desc_mm, 'cancela')
		and not contains_substr(concepto_ds, 'penaliza')
		and not contains_substr(concepto_ds,'post ')
		-- FIX BUG 4: guard that ensures mes_decomision_id matches the actual baja month,
		-- preventing rows from other decomission months from leaking in.
		and mes_decomision_id=CAST(FORMAT_DATE("%Y%m",extract(DATE FROM fecha_baja_dt)) as INT64)
	), enriched as (
		select distinct c.* except(categoria_servicio_ds, fecha_rfb_dt, fecha_venta_neta_dt),
		COALESCE(sind.marca_operador_receptor_ds,"NOINF") as marca_operador_receptor_ds,
		COALESCE(sind.grupo_operador_receptor_ds,"NOINF") as grupo_operador_receptor_ds,
		COALESCE(sind.agrup_operador_receptor_ds,"NOINF") as agrup_operador_receptor_ds,
		case when (CONTAINS_SUBSTR(c.detalle_servicio_ds,'MAMBO AXIÑA') or CONTAINS_SUBSTR(c.detalle_servicio_ds,'HEGAN-COMBI YES'))=FALSE THEN c.categoria_servicio_ds ELSE 'BANDA ANCHA' END as categoria_servicio_ds,
		case when CONTAINS_SUBSTR(c.desc_mm,'Servicio acceso BA') or CONTAINS_SUBSTR(c.detalle_servicio_ds,'MAMBO AXIÑA') or CONTAINS_SUBSTR(c.detalle_servicio_ds,'HEGAN-COMBI YES') then 1 else 0 END as Acceso_BA,
		case when CONTAINS_SUBSTR(c.desc_mm,'Servicio') or CONTAINS_SUBSTR(c.desc_mm,'Portabilidad')  or CONTAINS_SUBSTR(c.desc_mm,'Television acceso')  or CONTAINS_SUBSTR(c.detalle_servicio_ds,'MAMBO AXIÑA') or CONTAINS_SUBSTR(c.detalle_servicio_ds,'HEGAN-COMBI YES') then 1 else 0 END as Servicio,
		case when CONTAINS_SUBSTR(c.desc_mm,'Servicio acceso BA')  or CONTAINS_SUBSTR(c.detalle_servicio_ds,'MAMBO AXIÑA') or CONTAINS_SUBSTR(c.detalle_servicio_ds,'HEGAN-COMBI YES') then 1 else 0 END as Servicio_BA,
		case when CONTAINS_SUBSTR(c.desc_mm,'Servicio Fijo') or  CONTAINS_SUBSTR(c.desc_mm,'Portabilidad Fijo') then 1 else 0 END as Servicio_TF,
		case when CONTAINS_SUBSTR(c.desc_mm,'Servicio Movil') or  CONTAINS_SUBSTR(c.desc_mm,'Portabilidad Movil') then 1 else 0 END as Servicio_TM,
		case when CONTAINS_SUBSTR(c.desc_mm,'Television acceso') then 1 else 0 END as Servicio_TV,
		case when CONTAINS_SUBSTR(c.desc_mm,'Terminal') then 1 else 0 END as Terminal,
		case when CONTAINS_SUBSTR(c.desc_mm,'Netflix') then 1 else 0 END as Netflix,
		EXTRACT(DATE FROM fecha_rfb_dt) as fechaAlta,
		CAST(FORMAT_DATE("%Y%m",EXTRACT(DATE FROM fecha_rfb_dt)) AS INT64) as mes_rfb_id,
		EXTRACT(DATE FROM c.fecha_baja_dt) as fechaBaja,
		CAST(FORMAT_DATE("%Y%m",EXTRACT(DATE FROM c.fecha_baja_dt)) AS INT64) as mes_baja_id,
		-- Computed from clawback dates directly: never NULL regardless of portability match.
		-- Uses native DATE_DIFF (not UDF) to guarantee non-null output when both dates are non-null.
		GREATEST(0, CAST(DATE_DIFF(EXTRACT(DATE from c.fecha_baja_dt), EXTRACT(DATE from c.fecha_rfb_dt), MONTH) AS INT64)) as NMONTHS,
		GREATEST(0, CAST(DATE_DIFF(EXTRACT(DATE from c.fecha_baja_dt), EXTRACT(DATE from c.fecha_rfb_dt), DAY) AS INT64)) as NDAYS,
		COALESCE(sind.pDiario, 0.0) as pDiario,
		COALESCE(sind.pMensual, 0.0) as pMensual
		from c
		left join `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P5` sind
		-- Looser join (marca+cliente+servicio only) to maximize portability matches;
		-- canal/distribuidor keys were removed because they caused fanout on multi-channel records.
		on sind.marca_ds=c.marca_ds and sind.cliente_id=c.cliente_id and sind.servicio_id=c.servicio_id
	)
	select distinct enriched.*,
	CASE
		WHEN enriched.NMONTHS < 7  THEN 0
		WHEN enriched.NMONTHS < 13 THEN 7
		WHEN enriched.NMONTHS < 19 THEN 13
		ELSE 19
	END as grnmonths_id,
	CASE
		WHEN enriched.NMONTHS < 7  THEN '0-6'
		WHEN enriched.NMONTHS < 13 THEN '7-12'
		WHEN enriched.NMONTHS < 19 THEN '13-18'
		ELSE '19-24'
	END as grnmonths
	from enriched;



	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P7`  AS
	select distinct  *
	from   `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P6`  where servicio=1;


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P8` AS
	with f as (
		With c as (
			(
				with cand as (
					select distinct b.marca_ds, b.cliente_id, b.servicio_id,
					NULL AS servicio_donante_id,
					p.request_type as sentido_portabilidad_ds,
					case when p.transfer_date is not null then "CONFIRMADA"
						 ELSE "OTRO"
					END
					as estado_portabilidad_ds,
					s.ani,
					p.group_donor as  agrup_operador_donante_ds,
					p.brand_receiver as marca_operador_receptor_ds,
					SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] as grupo_operador_receptor_ds,
				    SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] AS agrup_operador_receptor_ds,
					EXTRACT(DATE FROM p.vc_date) as fecha_ventana_cambio_dt,
		        	s.fecha_baja_dt,
		        	ABS(date_diff(EXTRACT(DATE FROM p.vc_date), EXTRACT(DATE FROM s.fecha_baja_dt),  DAY)) as ndias
					from `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P7` b
					inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on s.servicio_id=b.servicio_id
					inner JOIN  `mm-datamart-kd.PORTABILITY.portability_mobile_base` p ON s.ani=p.msisdn and  p.operator_code_donor in ("006","073","053")
		  		    where b.agrup_operador_receptor_ds is null
		  		    and EXTRACT(DATE from date_trunc(s.fecha_baja_dt,month))=vMES_BAJA_DT

				) select cand.*, row_number() over( partition By cand.marca_ds, cand.cliente_id,cand.servicio_id  ORDER BY ndias desc) as indice
				from cand
				where agrup_operador_receptor_ds is not null
				and estado_portabilidad_ds="CONFIRMADA"
				and ndias<30
			)
			UNION ALL
			(	with cand as (
					select distinct b.marca_ds, b.cliente_id, b.servicio_id,
					NULL AS servicio_donante_id,
					p.request_type as sentido_portabilidad_ds,
					case when p.transfer_date is not null then "CONFIRMADA"
					     ELSE "OTRO"
					END
					as estado_portabilidad_ds,
					s.ani,
					p.group_donor as  agrup_operador_donante_ds,
					p.brand_receiver as marca_operador_receptor_ds,
					SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] as grupo_operador_receptor_ds,
				    SPLIT(`mm-commissions-reporting.KRT_REPORTING.f_port_descubrir_grupo_operador`(p.group_receiver, p.operator_receiver,p.brand_receiver)," ")[0] AS agrup_operador_receptor_ds,
					EXTRACT(DATE FROM p.date_vc) as fecha_ventana_cambio_dt,
		        	s.fecha_baja_dt,
		        	ABS(date_diff(EXTRACT(DATE FROM p.date_vc), EXTRACT(DATE FROM s.fecha_baja_dt),  DAY)) as ndias
					from `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P7` b
					inner join `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` s on s.servicio_id=b.servicio_id
					inner JOIN  `mm-datamart-kd.PORTABILITY.portability_fix_base` p ON s.ani=p.phone_nm and  p.operator_code_donor in ("00020","00015","00008")
		  		    where b.agrup_operador_receptor_ds is null
		  		    and EXTRACT(DATE from date_trunc(s.fecha_baja_dt,month))=vMES_BAJA_DT
				) select cand.*, row_number() over( partition By cand.marca_ds, cand.cliente_id,cand.servicio_id  ORDER BY ndias desc) as indice
				from cand
				where agrup_operador_receptor_ds is not null
				and estado_portabilidad_ds="CONFIRMADA"
				and ndias<30
			)

        )

        select *
        from c

    )
    select *
    from f
    where indice=1;


	UPDATE `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P7` d
	SET d.agrup_operador_receptor_ds=o.agrup_operador_receptor_ds,
	d.grupo_operador_receptor_ds=o.grupo_operador_receptor_ds,
	d.marca_operador_receptor_ds=o.marca_operador_receptor_ds
	FROM `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P8` o
	where d.marca_ds=o.marca_ds
	and d.cliente_id=o.cliente_id
	and d.servicio_id=o.servicio_id;


	CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_REPORTING_BAJAS24M_CARGA_REGISTROS` AS
	with indbm as (
		with indb as (

			with i as (
				/* i */
				select s.*,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds ORDER BY mes_decomision_id, marca_ds ASC) as int64)  as nbaj_tot,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds ASC) as int64)  as nbaj_cat_tot,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_cat_dist_tot,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_can_dist_tot,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_dist_tot,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ASC) as int64)  as nbaj_cat_dist_port_tot,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_port_tot,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds ORDER BY mes_decomision_id, marca_ds ASC) as int64)  as nbajxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds ASC) as int64)  as nbaj_catxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds ASC) as int64)  as nbaj_cat_canalxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_cat_distxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64)  as nbaj_can_distxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_distxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY  mes_decomision_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64)  as nbaj_cat_dist_portxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_portxmarca,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds  ORDER BY marca_ds ASC) as int64) as nbaj_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds  ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds ASC) as int64) as nbaj_cat_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ASC) as int64) as nbaj_cat_canal_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_dist_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_can_dist_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_dist_mesxmarca,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_dist_port_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_port_mesxmarca,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, NMONTHS ASC) as int64) as nbaj_nmes_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, NMONTHS ASC) as int64) as nbaj_cat_nmes_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ASC) as int64) as nbaj_cat_canal_nmes_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds,  NMONTHS ASC) as int64) as nbaj_cat_dist_nmes_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ORDER BY  mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,NMONTHS ASC) as int64) as nbaj_can_dist_nmes_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, NMONTHS ASC) as int64) as nbaj_cat_can_dist_nmes_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds,  NMONTHS ASC) as int64) as nbaj_cat_dist_port_nmes_mesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, NMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, NMONTHS ASC) as int64) as nbaj_cat_can_dist_port_nmes_mesxmarca,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, GRNMONTHS ORDER BY  mes_decomision_id, marca_ds, GRNMONTHS_ID ASC) as int64) as nbaj_grmesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, GRNMONTHS ORDER BY  mes_decomision_id, marca_ds, categoria_servicio_ds, GRNMONTHS_ID ASC) as int64) as nbaj_cat_grmesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, GRNMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds,GRNMONTHS ASC) as int64) as nbaj_cat_canal_grmesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, GRNMONTHS ORDER BY mes_decomision_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds,subcanal_ds,GRNMONTHS ASC) as int64) as nbaj_cat_can_grmesxmarca,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, GRNMONTHS ORDER BY  mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, GRNMONTHS_ID ASC) as int64) as nbaj_cat_dist_grmesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, GRNMONTHS ORDER BY mes_decomision_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, GRNMONTHS_ID ASC) as int64)  as nbaj_can_dist_grmesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,GRNMONTHS ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds,  GRNMONTHS_ID ASC) as int64)  as nbaj_cat_can_dist_grmesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, GRNMONTHS ORDER BY  mes_decomision_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, GRNMONTHS_ID ASC) as int64) as nbaj_cat_dist_port_grmesxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds,GRNMONTHS ORDER BY mes_decomision_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds, GRNMONTHS_ID ASC) as int64)  as nbaj_cat_can_dist_port_grmesxmarca,

				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds  ORDER BY marca_ds ASC) as int64) as nbaj_mesAltaxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds  ORDER BY mes_decomision_id, mes_rfb_id, marca_ds,categoria_servicio_ds ASC) as int64) as nbaj_cat_mesAltaxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY  mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ASC) as int64) as nbaj_cat_canal_mesAltaxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_dist_mesAltaxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ASC) as int64) as nbaj_can_dist_mesAltaxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY  mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds ASC) as int64) as nbaj_cat_can_dist_mesAltaxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_dist_port_mesAltaxmarca,
				CAST(sum(s.Servicio) over(PARTITION BY  mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ORDER BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds,  nombre_distribuidor_alta_ds, agrup_operador_receptor_ds ASC) as int64) as nbaj_cat_can_dist_port_mesAltaxmarca,

				from  `mm-commissions-reporting.KRT_CAPTACION.REPORTING_P7`  as s
				)

				select *,
				SAFE_DIVIDE(nbaj_can_dist_mesxmarca,nbaj_can_dist_tot) as pserv_can_dist_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_dist_mesxmarca,nbaj_cat_dist_tot) as pserv_cat_dist_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_canal_mesxmarca,nbaj_cat_canalxmarca) as pserv_cat_canal_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_mesxmarca,nbaj_cat_can_dist_tot) as pserv_cat_can_dist_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_dist_port_mesxmarca,nbaj_cat_dist_port_tot) as pserv_cat_dist_port_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_dist_port_tot) as pserv_cat_can_dist_port_mesxmarca,

				SAFE_DIVIDE(nbaj_can_dist_nmes_mesxmarca,nbaj_can_dist_tot) as pserv_can_dist_nmes_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_dist_nmes_mesxmarca,nbaj_cat_dist_tot) as pserv_cat_dist_nmes_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_canal_nmes_mesxmarca,nbaj_cat_canalxmarca) as pserv_cat_canal_nmes_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_mesxmarca,nbaj_cat_can_dist_tot) as pserv_cat_can_dist_nmes_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_dist_port_nmes_mesxmarca,nbaj_cat_dist_port_tot) as pserv_cat_dist_port_nmes_mesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_dist_port_tot) as pserv_cat_can_dist_port_nmes_mesxmarca,

				SAFE_DIVIDE(nbaj_cat_dist_grmesxmarca,nbaj_cat_dist_tot) as pserv_cat_dist_grmesxmarca,
				SAFE_DIVIDE(nbaj_can_dist_grmesxmarca,nbaj_can_dist_tot) as pserv_can_dist_grmesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_grmesxmarca,nbaj_cat_can_dist_tot) as pserv_cat_can_dist_grmesxmarca,
				SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nbaj_cat_dist_port_tot) as pserv_cat_dist_port_grmesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_port_grmesxmarca,nbaj_cat_can_dist_port_tot) as pserv_cat_can_dist_port_grmesxmarca,

				SAFE_DIVIDE(nbaj_cat_dist_port_mesxmarca,nbaj_cat_distxmarca) as pserv_cat_dist_intramesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_distxmarca) as pserv_cat_can_dist_intramesxmarca,
				SAFE_DIVIDE(nbaj_cat_dist_port_mesxmarca,nbaj_cat_distxmarca) as pserv_cat_dist_port_intramesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_port_mesxmarca,nbaj_cat_can_distxmarca) as pserv_cat_can_dist_port_intramesxmarca,

				SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nbaj_cat_dist_grmesxmarca) as pserv_cat_dist_intragrmesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_port_grmesxmarca,nbaj_cat_can_dist_grmesxmarca) as pserv_cat_can_dist_intragrmesxmarca,
				SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nbaj_cat_dist_grmesxmarca) as pserv_cat_dist_port_intragrmesxmarca,
				SAFE_DIVIDE(nbaj_cat_can_dist_port_grmesxmarca,nbaj_cat_can_dist_grmesxmarca) as pserv_cat_can_dist_port_intragrmesxmarca,

				from i
		), inda as (
				with la as (
					select distinct
					-- FIX na24m: use HISTORICO_COMISIONES_CAPTACION_DETALLADO (correct source table).
					-- mes_alta_id: prefer TIMESTAMP-derived month; fallback to FECHA_RFB_ID/100 if timestamp is null.
					COALESCE(
						CAST(FORMAT_DATE('%Y%m', EXTRACT(DATE FROM fecha_rfb_dt)) AS INT64),
						CAST(FECHA_RFB_ID / 100 AS INT64)
					) as mes_alta_id,
					marca_ds,
					-- Apply same MAMBO AXIÑA normalization as P6/enriched so categoria_servicio_ds matches indb.
					CASE WHEN (CONTAINS_SUBSTR(detalle_servicio_ds,'MAMBO AXIÑA') OR CONTAINS_SUBSTR(detalle_servicio_ds,'HEGAN-COMBI YES'))
						 THEN 'BANDA ANCHA' ELSE categoria_servicio_ds END as categoria_servicio_ds,
					tipo_canal_alta_ds,  canal_alta_ds, subcanal_ds,nombre_distribuidor_alta_ds, fecha_rfb_dt, servicio_id
					from `mm-commissions-reporting.KRT_CAPTACION.HISTORICO_COMISIONES_CAPTACION_DETALLADO`

				) select distinct marca_ds, categoria_servicio_ds, tipo_canal_alta_ds,  canal_alta_ds, subcanal_ds,nombre_distribuidor_alta_ds, mes_alta_id,
				CAST(count(distinct servicio_id)  over(PARTITION BY marca_ds) as int64)  as nactxmarca,
				CAST(count(distinct servicio_id)  over(PARTITION BY marca_ds,categoria_servicio_ds) as int64)  as nact_catxmarca,
				CAST(count (distinct servicio_id) over(PARTITION BY marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds ) as int64)  as nact_cat_canalxmarca,
				CAST(count (distinct servicio_id) over(PARTITION BY marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds ) as int64)  as nact_cat_canxmarca,
				CAST(count(distinct servicio_id)  over(PARTITION BY marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds) as int64)  as nact_cat_distxmarca,
				CAST(count (distinct servicio_id) over(PARTITION BY marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ) as int64)  as nact_cat_can_distxmarca,

				CAST(count(distinct servicio_id)  over(PARTITION BY mes_alta_id, marca_ds) as int64)  as nact_mesAltaxmarca,
				CAST(count(distinct servicio_id)  over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds) as int64)  as nact_cat_mesAltaxmarca,
				CAST(count (distinct servicio_id) over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds) as int64)  as nact_cat_canal_mesAltaxmarca,
				CAST(count (distinct servicio_id) over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds ) as int64)  as nact_cat_can_mesAltaxmarca,
				CAST(count(distinct servicio_id)  over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, nombre_distribuidor_alta_ds) as int64)  as nact_cat_dist_mesAltaxmarca,
				CAST(count (distinct servicio_id) over(PARTITION BY mes_alta_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds ) as int64)  as nact_cat_can_dist_mesAltaxmarca

				from la
				order by 1 desc, 2 asc, 3 asc, 4 asc,5 asc, 6 asc, 7 asc
		) select distinct indb.*,
		inda.mes_alta_id,
		inda.nactxmarca,inda.nact_catxmarca,inda.nact_cat_canalxmarca,inda.nact_cat_canxmarca,inda.nact_cat_distxmarca,inda.nact_cat_can_distxmarca, inda.nact_mesAltaxmarca,inda.nact_cat_mesAltaxmarca,inda.nact_cat_canal_mesAltaxmarca,inda.nact_cat_can_mesAltaxmarca,inda.nact_cat_dist_mesAltaxmarca,
		inda.nact_cat_can_dist_mesAltaxmarca,

		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_mesAltaxmarca) END as pact_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_mesAltaxmarca) END as pact_cat_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_canal_mesAltaxmarca) END as pact_cat_canal_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_can_mesAltaxmarca) END as pact_cat_can_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_dist_mesAltaxmarca) END as pact_cat_dist_mesAltaxmarca,
		CASE WHEN indb.SERVICIO=1 THEN SAFE_DIVIDE(1,nact_cat_can_dist_mesAltaxmarca) END as pact_cat_can_dist_mesAltaxmarca,

		SAFE_DIVIDE(nbajxmarca,nactxmarca) as pactxmarca,
		SAFE_DIVIDE(nbaj_catxmarca,nact_catxmarca) as pact_catxmarca,
		SAFE_DIVIDE(nbaj_cat_canalxmarca,nact_cat_canalxmarca) as pact_cat_canalxmarca,
		SAFE_DIVIDE(nbaj_cat_distxmarca,nact_cat_distxmarca) as pact_cat_distxmarca,
		SAFE_DIVIDE(nbaj_cat_can_distxmarca,nact_cat_can_distxmarca) as pact_cat_can_distxmarca,
		SAFE_DIVIDE(nbaj_cat_dist_portxmarca,nact_cat_distxmarca) as pact_cat_dist_portxmarca,
		SAFE_DIVIDE(nbaj_cat_can_dist_portxmarca,nact_cat_can_distxmarca) as pact_cat_can_dist_portxmarca,

		SAFE_DIVIDE(nbaj_grmesxmarca, nactxmarca) as pact_grmesxmarca,
		SAFE_DIVIDE(nbaj_cat_grmesxmarca,nact_catxmarca) as pact_cat_grmesxmarca,
		SAFE_DIVIDE(nbaj_cat_canal_grmesxmarca,nact_cat_canalxmarca) as pact_cat_canal_grmesxmarca,
		SAFE_DIVIDE(nbaj_cat_can_grmesxmarca,nact_cat_canxmarca) as pact_cat_can_grmesxmarca,
		SAFE_DIVIDE(nbaj_cat_dist_grmesxmarca,nact_cat_distxmarca) as pact_cat_dist_grmesxmarca,
		SAFE_DIVIDE(nbaj_cat_can_dist_grmesxmarca,nact_cat_can_distxmarca) as pact_cat_can_dist_grmesxmarca,
		SAFE_DIVIDE(nbaj_cat_dist_port_grmesxmarca,nact_cat_distxmarca) as pact_cat_dist_port_grmesxmarca

		from indb
		-- FIX na24m: removed day-level FECHA_RFB_ID condition; month-level mes_rfb_id is sufficient
		-- and the day match was causing null na24m/nam/pbm when CLAWBACK and CAPTACION dates diverged by even one day.
		left join inda on indb.marca_ds=inda.marca_ds and indb.categoria_servicio_ds=inda.categoria_servicio_ds  and indb.tipo_canal_alta_ds=inda.tipo_canal_alta_ds and indb.canal_alta_ds=inda.canal_alta_ds and indb.subcanal_ds=inda.subcanal_ds and inda.nombre_distribuidor_alta_ds=indb.nombre_distribuidor_alta_ds and indb.mes_rfb_id=inda.mes_alta_id
	) select distinct EXTRACT(DATE FROM DATE_TRUNC(fecha_baja_dt,month)) as mes_baja_dt, *,
	CAST(SUM(100000000000000*pact_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds) as int64)/100000000000000  as pactac_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds) as int64)/100000000000000  as pactac_cat_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_canal_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds) as int64)/100000000000000  as pactac_cat_canal_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_can_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds) as int64)/100000000000000  as pactac_cat_can_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds) as int64)/100000000000000  as pactac_cat_dist_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_can_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds) as int64)/100000000000000  as pactac_cat_can_dist_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)/100000000000000  as pactac_cat_dist_port_mesAltaxmarca,
	CAST(SUM(100000000000000*pact_cat_can_dist_mesAltaxmarca)  over(PARTITION BY mes_decomision_id, mes_rfb_id, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)/100000000000000  as pactac_cat_can_dist_port_mesAltaxmarca,

	CAST(SUM(100000000000000*pact_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds) as int64)/100000000000000  as pactac_grmesxmarca,
	CAST(SUM(100000000000000*pact_cat_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds, categoria_servicio_ds) as int64)/100000000000000  as pactac_cat_grmesxmarca,
	CAST(SUM(100000000000000*pact_cat_canal_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds) as int64)/100000000000000  as pactac_cat_canal_grmesxmarca,
	CAST(SUM(100000000000000*pact_cat_can_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds,categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds) as int64)/100000000000000  as pactac_cat_can_grmesxmarca,
	CAST(SUM(100000000000000*pact_cat_dist_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds) as int64)/100000000000000  as pactac_cat_dist_grmesxmarca,
	CAST(SUM(100000000000000*pact_cat_can_dist_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds) as int64)/100000000000000  as pactac_cat_can_dist_grmesxmarca,
	CAST(SUM(100000000000000*pact_cat_dist_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds, categoria_servicio_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)/100000000000000  as pactac_cat_dist_port_grmesxmarca,
	CAST(SUM(100000000000000*pact_cat_can_dist_grmesxmarca)  over(PARTITION BY mes_decomision_id, grnmonths, marca_ds, categoria_servicio_ds, tipo_canal_alta_ds, canal_alta_ds, subcanal_ds, nombre_distribuidor_alta_ds, agrup_operador_receptor_ds) as int64)/100000000000000  as pactac_cat_can_dist_port_grmesxmarca
	from indbm;



	/* PASO 4: INSERTO INDICADORES DE BAJAS A INSERTAR EN TABLA DE REPORTING*/
	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.REPORTING_BAJAS24M`
	SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_REPORTING_BAJAS24M_CARGA_REGISTROS`;

	INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.REPORTING_BAJAS24M_NOPART`
	SELECT distinct * FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_REPORTING_BAJAS24M_CARGA_REGISTROS`;


END