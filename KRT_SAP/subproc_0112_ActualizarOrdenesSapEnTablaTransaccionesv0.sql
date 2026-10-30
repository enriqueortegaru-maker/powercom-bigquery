BEGIN
		
			DECLARE VOPERATION ARRAY<STRING>;
			DECLARE VMES_FACTURA_DT DATE;
			--- LOCAL
			--DECLARE VTIPO STRING;	DECLARE VDESDE INT64; SET VTIPO="CARTERA"; SET VDESDE=20260101;
			--- FIN LOCAL
			SET VMES_FACTURA_DT=DATE_TRUNC(PARSE_DATE('%Y%m%d',CAST(VDESDE AS STRING)),MONTH);
			--SET VMES_FACTURA_DT='2026-01-01';			
			IF 	UPPER(TRIM(VTIPO))="CAPTACION" THEN SET VOPERATION=["ALTA","BAJA"]; 
			ELSEIF UPPER(TRIM(VTIPO))="CARTERA" THEN SET VOPERATION=["ALTA","BAJA","CAMBIO"];
			END IF;


			UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
			SET t.orden=u.orden_nueva	
			FROM (	
        --DECLARE VTIPO STRING;	DECLARE VOPERATION ARRAY<STRING>; DECLARE VMES_FACTURA_DT DATE;	SET VTIPO="CAPTACION";SET VOPERATION=["ALTA","BAJA"];SET VMES_FACTURA_DT='2026-01-01';
				with os as (
						--DECLARE VTIPO STRING;	DECLARE VOPERATION ARRAY<STRING>; DECLARE VMES_FACTURA_DT DATE;	SET VTIPO="CAPTACION";SET VOPERATION=["ALTA","BAJA"];SET VMES_FACTURA_DT='2026-01-01';
						select distinct tipo, marca, canal, service_type, marco, segmento,operacion, orden_previa as orden, orden as orden_nueva
						FROM `mm-commissions-reporting.KRT_SAP.PARAM_SAP_ORDENxCANAL`
						CROSS JOIN UNNEST(SPLIT(operacion)) operacion					
						CROSS JOIN UNNEST(SPLIT(service_type)) service_type
						CROSS JOIN UNNEST(SPLIT(canal)) canal
						CROSS JOIN UNNEST(SPLIT(segmento)) segmento
						CROSS JOIN UNNEST(SPLIT(marco)) marco
						where tipo=VTIPO
						and operacion IN UNNEST(VOPERATION)
						and ESTADO="PUBLICAR"		  

				), t as (

						--DECLARE VTIPO STRING;	DECLARE VOPERATION ARRAY<STRING>; DECLARE VMES_FACTURA_DT DATE;	SET VTIPO="CAPTACION";SET VOPERATION=["ALTA","BAJA"];SET VMES_FACTURA_DT='2026-01-01';

						select distinct t.mes_factura_dt, t.tipo, t.marca, t.canal_gekt as canal,  t.service_type, t.marco, t.segmento, t.operation as operacion, t.orden, count(service_id) as nsrv, sum(comision) as imp,
						from `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t

						where t.tipo=VTIPO
						and mes_factura_dt =VMES_FACTURA_DT
						and operation IN UNNEST(VOPERATION)
						--and c.orden is distinct from os.orden_previa
						--and coalesce(c.orden_sap,0) !=0
						-- and coalesce(os.orden,0)!=0
						--and not contains_substr(c.concepto_ds_gekt, "SOMO")
						and not contains_substr(t.concepto_ds_gekt, "POSTVENTA")
						group by all
						order by 1,2,3,4,5

				)
					
				select distinct t.mes_factura_dt, t.marca, t.tipo, t.canal, t.service_type, t.marco, t.segmento, t.operacion, t.orden, os.orden_nueva, t.nsrv, t.imp,			 
				case when t.orden=os.orden then 1 else 0 end as beqos,
				from  t
				inner join os on
				UPPER(TRIM(t.canal))=UPPER(TRIM(os.canal))
				and UPPER(TRIM(t.canal))=UPPER(TRIM(os.canal))
				and UPPER(TRIM(t.service_type)) =UPPER(TRIM(os.service_type))
				and UPPER(TRIM(t.segmento))=UPPER(TRIM(os.segmento)) 
				and UPPER(TRIM(t.operacion))=UPPER(TRIM(os.operacion)) 
				and case when TRIM(UPPER(os.marco))='X' then TRUE else TRIM(UPPER(os.marco))=TRIM(UPPER(t.marco)) END 
				and t.orden=os.orden
				and t.orden!=os.orden_nueva
				--left join os on os.marca=c.marca_ds and os.canal=c.canal_alta_ds and os.service_type=c.service_types and c.segmento_ds=os.segmento  and case when TRIM(UPPER(os.marco))='X' then TRUE else TRIM(UPPER(os.marco))=TRIM(UPPER(c.marco_retributivo_ds)) END and os.tipo="CAPTACION"
				--- orden parametrizada no es nula
				order by 1,2,3,4,5,6,7,8
			) u
			WHERE t.mes_factura_dt=u.mes_factura_dt 
      and t.marca=u.marca
			and t.tipo=u.tipo
			and t.canal_gekt=u.canal
			and t.service_type=u.service_type
			and t.marco=u.marco
			and t.segmento=u.segmento
			and t.operation=u.operacion;

END