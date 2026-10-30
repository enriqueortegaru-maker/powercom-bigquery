BEGIN
-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('mensual');
-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('completo');
-- call `mm-commissions-reporting.COMISIONES.pr_actualizar_datastudio`('');

declare importe1, importe2 float64;
declare id_mes_ejecucion ,id_mes_actual int64;
set id_mes_ejecucion = (select cast(valor as int64) from `mm-commissions-reporting.GS.PARAMETROS` where parametro ='mes_actualizar_traza');  --modifico mes_ejecucion por mes_actualizar_traza -- SOLUCION para valor-1 teniendo en cuenta que es una fecha y no un número entero -> CAST(FORMAT_DATE('%Y%m', DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m',valor), INTERVAL 1 MONTH), MONTH)) AS INT64)
set id_mes_actual = (select cast(valor as int64) from `mm-commissions-reporting.GS.PARAMETROS` where parametro ='mes_actual');

/*
set importe1 = (select sum(comision) from `mm-commissions-reporting.COMISIONES.transacciones`);
*/
/*
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.nueva_canalizacion`
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
(
     SELECT
           * EXCEPT(canal_n0_masorange, canal_n1_masorange)
     
          ,CASE
               WHEN canal_n0_masorange IS NOT NULL THEN canal_n0_masorange
               WHEN agrupacion_canal = 'Etnico'                                              THEN 'NO EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'BY%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'DX%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'KH%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'LB%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'LM%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'LY%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'MD%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'ML%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'TA%'            THEN 'EXCLUSIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'INNERI%'     THEN 'NO EXCLUSIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MASTER%'     THEN 'NO EXCLUSIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MI%'         THEN 'NO EXCLUSIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MKT%'        THEN 'NO EXCLUSIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MR%'         THEN 'NO EXCLUSIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'PH%'         THEN 'NO EXCLUSIVO'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'AB%'     THEN 'DIGITAL'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'AO%'     THEN 'DIGITAL'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'BX%'     THEN 'OUTBOUND'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'CAROUT%' THEN 'OUTBOUND'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'GX%'     THEN 'OUTBOUND'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'LE%'     THEN 'OUTBOUND'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'KO%'     THEN 'OUTBOUND'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'KS%'     THEN 'DIGITAL'
               WHEN agrupacion_canal = 'TLV - Negocios' AND id_comisionista LIKE 'KI%'       THEN 'DIGITAL'
               WHEN agrupacion_canal = 'TLV - Negocios' AND id_comisionista IS NULL          THEN 'OUTBOUND'
               WHEN agrupacion_canal = 'TLV - Outbound'                                      THEN 'OUTBOUND'
           END AS canal_n0_masorange
     
          ,CASE
               WHEN canal_n1_masorange IS NOT NULL THEN canal_n1_masorange
               WHEN agrupacion_canal = 'Etnico'                                              THEN 'ETNICO'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'BY%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'DX%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'KH%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'LB%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'LM%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'LY%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'MD%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'ML%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'Exclusivo' AND id_comisionista LIKE 'TA%'            THEN 'EXCLUSIVO MULTIMARCA'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'INNERI%'     THEN 'NATIONAL RETAIL'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MASTER%'     THEN 'ALTERNATIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MI%'         THEN 'ALTERNATIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MKT%'        THEN 'NATIONAL RETAIL'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'MR%'         THEN 'ALTERNATIVO'
               WHEN agrupacion_canal = 'No Exclusivo' AND id_comisionista LIKE 'PH%'         THEN 'NATIONAL RETAIL'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'AB%'     THEN 'TELEWEB'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'AO%'     THEN 'TELEWEB'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'BX%'     THEN 'OUTBOUND CARTERA'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'CAROUT%' THEN 'OUTBOUND CARTERA'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'GX%'     THEN 'OUTBOUND CARTERA'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'LE%'     THEN 'OUTBOUND CARTERA'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'KO%'     THEN 'OUTBOUND CARTERA'
               WHEN agrupacion_canal = 'TLV - Cross-sell' AND id_comisionista LIKE 'KS%'     THEN 'TELEWEB'
               WHEN agrupacion_canal = 'TLV - Negocios' AND id_comisionista LIKE 'KI%'       THEN 'TELEWEB'
               WHEN agrupacion_canal = 'TLV - Negocios' AND id_comisionista IS NULL          THEN 'OUTBOUND CAPTACION'
               WHEN agrupacion_canal = 'TLV - Outbound'                                      THEN 'OUTBOUND CAPTACION'
           END AS canal_n1_masorange
           
     FROM (
          SELECT
                TRANSACCIONES.*
               ,canal_n0_masorange
               ,canal_n1_masorange
          
          FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
          
          LEFT JOIN (
                    SELECT *
          
                    FROM (
                         SELECT
                               sfid_id
                              ,channel_segment_ds
                              ,channel_ds
                              ,subchannel_ds
                              ,SUM(count) AS count
                    
                         FROM (
                              SELECT
                                    sfid_id
                                   ,channel_segment_ds
                                   ,channel_ds
                                   ,subchannel_ds
                                   ,COUNT(*) AS count
                              FROM `mm-datamart-kd.SERVICES.ventas_base_net`
                              WHERE sfid_id IS NOT NULL
                                    AND channel_ds IS NOT NULL
                                    AND channel_ds NOT IN ('CANCELACIONES', 'DESCONOCIDO', 'HISTORICO', 'PENDIENTE DEFINIR', 'PLAT. ATC', 'PLAT. FIDELIZACION/RETENCION')
                              GROUP BY 1,2,3,4
                              UNION DISTINCT
                              SELECT
                                    seller
                                   ,channel_segment_ds
                                   ,channel_ds
                                   ,subchannel_ds
                                   ,COUNT(*) AS count
                              FROM `mm-datamart-kd.SERVICES.ventas_base_net`
                              WHERE seller IS NOT NULL
                                    AND channel_ds IS NOT NULL
                                    AND channel_ds NOT IN ('CANCELACIONES', 'DESCONOCIDO', 'HISTORICO', 'PENDIENTE DEFINIR', 'PLAT. ATC', 'PLAT. FIDELIZACION/RETENCION')
                              GROUP BY 1,2,3,4
                              UNION DISTINCT
                              SELECT
                                    user_store
                                   ,channel_segment_ds
                                   ,channel_ds
                                   ,subchannel_ds
                                   ,COUNT(*) AS count
                              FROM `mm-datamart-kd.SERVICES.ventas_base_net`
                              WHERE user_store IS NOT NULL
                                    AND channel_ds IS NOT NULL
                                    AND channel_ds NOT IN ('CANCELACIONES', 'DESCONOCIDO', 'HISTORICO', 'PENDIENTE DEFINIR', 'PLAT. ATC', 'PLAT. FIDELIZACION/RETENCION')
                              GROUP BY 1,2,3,4
                              UNION DISTINCT
                              SELECT
                                    current_sfid_id
                                   ,channel_segment_ds
                                   ,channel_ds
                                   ,subchannel_ds
                                   ,COUNT(*) AS count
                              FROM `mm-datamart-kd.SERVICES.ventas_base_net`
                              WHERE current_sfid_id IS NOT NULL
                                    AND channel_ds IS NOT NULL
                                    AND channel_ds NOT IN ('CANCELACIONES', 'DESCONOCIDO', 'HISTORICO', 'PENDIENTE DEFINIR', 'PLAT. ATC', 'PLAT. FIDELIZACION/RETENCION')
                              GROUP BY 1,2,3,4
                              UNION DISTINCT
                              SELECT
                                    current_user_store
                                   ,channel_segment_ds
                                   ,channel_ds
                                   ,subchannel_ds
                                   ,COUNT(*) AS count
                              FROM `mm-datamart-kd.SERVICES.ventas_base_net`
                              WHERE current_user_store IS NOT NULL
                                    AND channel_ds IS NOT NULL
                                    AND channel_ds NOT IN ('CANCELACIONES', 'DESCONOCIDO', 'HISTORICO', 'PENDIENTE DEFINIR', 'PLAT. ATC', 'PLAT. FIDELIZACION/RETENCION')
                              GROUP BY 1,2,3,4
                              UNION DISTINCT
                              SELECT
                                    sfid_id || '-' || seller
                                   ,channel_segment_ds
                                   ,channel_ds
                                   ,subchannel_ds
                                   ,COUNT(*) AS count
                              FROM `mm-datamart-kd.SERVICES.ventas_base_net`
                              WHERE sfid_id IS NOT NULL
                                    AND seller IS NOT NULL
                                    AND channel_ds IS NOT NULL
                                    AND channel_ds NOT IN ('CANCELACIONES', 'DESCONOCIDO', 'HISTORICO', 'PENDIENTE DEFINIR', 'PLAT. ATC', 'PLAT. FIDELIZACION/RETENCION')
                              GROUP BY 1,2,3,4
                              )
                         GROUP BY 1,2,3,4
                         )
          
                    QUALIFY ROW_NUMBER() OVER (PARTITION BY sfid_id ORDER BY count DESC) = 1
                    ) SFID_CANALIZACION
                   ON (TRANSACCIONES.id_comisionista = SFID_CANALIZACION.sfid_id OR TRANSACCIONES.seller = SFID_CANALIZACION.sfid_id)
                      AND TRANSACCIONES.agrupacion_canal NOT LIKE 'B2B%'
          
          LEFT JOIN (
                    SELECT *
                    FROM `mm-sales-reporting.MASTERS.maestro_canales_masorange`
                    WHERE canal_n1_masorange NOT IN ('CANCELACIONES', 'OPERACIONES FIDELIZACIONES')
                    ) MAESTRO
                   ON SFID_CANALIZACION.channel_segment_ds = MAESTRO.CHANNEL_SEGMENT_DS
                      AND SFID_CANALIZACION.channel_ds = MAESTRO.SFID_SALE_TYPE_TDMK_A_DES
                      AND COALESCE(SFID_CANALIZACION.subchannel_ds, 'A') = COALESCE(MAESTRO.SFID_SALE_TYPE_TDMK_B_DES, 'A')
          
          QUALIFY RANK() OVER (
                              PARTITION BY TRANSACCIONES.commission_id
                              ORDER BY CASE WHEN TRANSACCIONES.id_comisionista = SFID_CANALIZACION.sfid_id THEN 1 ELSE 2 END ASC,
                                       CASE WHEN TRANSACCIONES.seller = SFID_CANALIZACION.sfid_id THEN 1 ELSE 2 END ASC
                              ) = 1
          )
)
;
*/
if modo = 'completo' then
create or replace table `mm-commissions-reporting.COMISIONES.visualizacion_comisiones`
partition by mes_liquidado
cluster by email, id_mes, invoice_id, id_comisionista
as
select
email,
a.agrupacion_canal,
id_mes,
COMISIONES.f_mes_int(id_mes) as mes_liquidado,
a.canal,
a.id_comisionista,
a.nombre_comercio,
SUBSTR( commission_id , 1, 4) as proceso,
invoice_id,
estado,
concepto,
process_code,
campaign_code,
claim_code,
comments,
id_factura_drive,
cif,
cod_tipo_contrato,
cod_segmento,
cod_producto,
tipo_concepto,
agrupacion_servicio,
marca,
sfid_id,
case when unidades is not null then seller end as seller,
distribuidor,
tariff_id,
tariff_ds,
a.service_type,
a.line_type_ds as tipo_linea,
a.bundle_type,
case when date_diff(  date_trunc (deactivation_date, month) , date_trunc (activation_date, month) , month) between 0 and 6 then date_diff(  date_trunc (deactivation_date, month) , date_trunc (activation_date, month) , month) end as diferencia_alta_baja_meses,
CASE
  WHEN a.marca = "ALTERNA" THEN "Renata de las Heras"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Serena Miguel"
  WHEN a.marca = "JOI" THEN "Ángel Olea"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Ángel Osuna"
  ELSE d.GERENTE_CUENTA
END AS GERENTE_CUENTA,
CASE 
  WHEN a.marca = "ALTERNA" THEN "ALTERNA"
  WHEN a.marca = "PARLEM" THEN "PARLEM"
  WHEN a.marca = "SWENO" THEN "SWENO"
  WHEN UPPER(a.canal) LIKE "OCT" THEN "OCT" 
  WHEN a.marca = "JOI" THEN "JOI"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "JUNTOS SOMOS MÁS"
  ELSE d.CUENTA_CLIENTE
END AS CUENTA_CLIENTE,
d.GRUPO,
CASE
  WHEN a.marca = "ALTERNA" THEN "Marcas Blancas"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Marcas Blancas"
  WHEN a.marca = "JOI" THEN "Marcas Blancas"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Marcas Propias"
  ELSE d.SEGMENTO
END AS SEGMENTO,
d.PROVINCIA--,
--canal_n0_masorange,
--canal_n1_masorange

,SUM(
    CASE
        WHEN COALESCE(unidades, 0) <> 0 AND DATE_TRUNC(COALESCE(activation_date, '1969-01-01'), MONTH) <> DATE_TRUNC(COALESCE(deactivation_date, '9999-12-31'), MONTH)
        THEN 1 ELSE 0
    END
    ) AS kpi_activations_net

,sum(unidades) as unidades,
sum(comision) as comision
--from `mm-commissions-reporting.TEMP.nueva_canalizacion` a
from `mm-commissions-reporting.COMISIONES.transacciones` a
-- inner join `mm-commissions-reporting.COMISIONES.v_accesos_comisiones` b using (agrupacion_canal, service_type, marca)
inner join `mm-commissions-reporting.COMISIONES.accesos_comisiones` b using (agrupacion_canal, service_type, marca)
LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d ON a.cif = d.documento AND a.id_comisionista = d.id_comisionista
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37--,38,39
;

else if modo = 'mensual' then
create or replace table `mm-commissions-reporting.COMISIONES.visualizacion_comisiones_mensual`
partition by mes_liquidado
cluster by email, id_mes, invoice_id, id_comisionista
as
select
email,
a.agrupacion_canal,
id_mes,
COMISIONES.f_mes_int(id_mes) as mes_liquidado,
a.canal,
a.id_comisionista,
a.nombre_comercio,
SUBSTR( commission_id , 1, 4) as proceso,
invoice_id,
estado,
concepto,
process_code,
campaign_code,
claim_code,
comments,
id_factura_drive,
cif,
cod_tipo_contrato,
cod_segmento,
cod_producto,
tipo_concepto,
agrupacion_servicio,
marca,
sfid_id,
case when unidades is not null then seller end as seller,
distribuidor,
tariff_id,
tariff_ds,
a.service_type,
a.line_type_ds as tipo_linea,
a.bundle_type,
case when date_diff(  date_trunc (deactivation_date, month) , date_trunc (activation_date, month) , month) between 0 and 6 then date_diff(  date_trunc (deactivation_date, month) , date_trunc (activation_date, month) , month) end as diferencia_alta_baja_meses,
CASE
  WHEN a.marca = "ALTERNA" THEN "Renata de las Heras"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Serena Miguel"
  WHEN a.marca = "JOI" THEN "Ángel Olea"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Ángel Osuna"
  ELSE d.GERENTE_CUENTA
END AS GERENTE_CUENTA,
CASE 
  WHEN a.marca = "ALTERNA" THEN "ALTERNA"
  WHEN a.marca = "PARLEM" THEN "PARLEM"
  WHEN a.marca = "SWENO" THEN "SWENO"
  WHEN UPPER(a.canal) LIKE "OCT" THEN "OCT" 
  WHEN a.marca = "JOI" THEN "JOI"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "JUNTOS SOMOS MÁS"
  ELSE d.CUENTA_CLIENTE
END AS CUENTA_CLIENTE,
d.GRUPO,
CASE
  WHEN a.marca = "ALTERNA" THEN "Marcas Blancas"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Marcas Blancas"
  WHEN a.marca = "JOI" THEN "Marcas Blancas"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Marcas Propias"
  ELSE d.SEGMENTO
END AS SEGMENTO,
d.PROVINCIA--,
--canal_n0_masorange,
--canal_n1_masorange

,SUM(
    CASE
        WHEN COALESCE(unidades, 0) <> 0 AND DATE_TRUNC(COALESCE(activation_date, '1969-01-01'), MONTH) <> DATE_TRUNC(COALESCE(deactivation_date, '9999-12-31'), MONTH)
        THEN 1 ELSE 0
    END
    ) AS kpi_activations_net

,sum(unidades) as unidades,
sum(comision) as comision
--from `mm-commissions-reporting.TEMP.nueva_canalizacion` a
from `mm-commissions-reporting.COMISIONES.transacciones` a
-- inner join `mm-commissions-reporting.COMISIONES.v_accesos_comisiones` b using (agrupacion_canal, service_type, marca)
inner join `mm-commissions-reporting.COMISIONES.accesos_comisiones` b using (agrupacion_canal, service_type, marca)
LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d ON a.cif = d.documento AND a.id_comisionista = d.id_comisionista
where a.id_mes >= id_mes_ejecucion -- in (id_mes_ejecucion,id_mes_actual)
group by all;

end if;
end if;

if modo = 'completo' then

call `mm-commissions-reporting.COMISIONES.pr_actualizar_visualizacion_externos_completo`();

create or replace table `mm-commissions-reporting.REPORTED.acceso_facturas` as
select
distinct
invoice_id as Numero_factura, email
from `mm-commissions-reporting.COMISIONES.transacciones` a, unnest(emails_acceso_trazabilidad	) email
where invoice_id is not null
and email like '%@%.%';

call `mm-commissions-reporting.COMISIONES.pr_actualizar_facturas_drive`();

create or replace table `mm-commissions-reporting.COMISIONES.visualizacion_trazabilidad`
partition by mes_liquidado
cluster by email, id_mes, invoice_id, id_comisionista
as
select
email,
id_mes,
COMISIONES.f_mes_int(id_mes)  as mes_liquidado,
t.agrupacion_canal,
t.canal,
t.id_comisionista,
t.invoice_id,
t.estado,
t.concepto,
t.process_code,
t.campaign_code,
t.claim_code,
t.comments,
CASE WHEN t.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE t.id_factura_drive END AS id_factura_drive,
CASE WHEN t.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE COALESCE(x.id_fichero_trazabilidad,y.id_fichero_trazabilidad) END AS id_fichero_trazabilidad,
t.cif,
t.nombre_comercio,
`mm-commissions-reporting.COMISIONES.f_clasificacion_concepto`(concepto) as agrupacion_concepto,
/*
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then sfid_id end as sfid_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then seller end as seller,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then marca end as marca,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then cod_segmento end as cod_segmento,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then service_id end as service_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then account_id end as account_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then customer_id end as customer_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then service_type end as service_type,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then bundle_type end as bundle_type,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then line_type_ds end as line_type_ds,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then phone_nm end as phone_nm,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then activation_date end as activation_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then deactivation_date end as deactivation_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then sale_date end as sale_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then order_id end as order_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then tariff_id end as tariff_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then tariff_ds end as tariff_ds,
*/
case when t.unidades is not null then t.sfid_id end as sfid_id,
case when t.unidades is not null then t.seller end as seller,
case when t.unidades is not null then t.marca end as marca,
case when t.unidades is not null then t.cod_segmento end as cod_segmento,
case when t.unidades is not null then t.service_id end as service_id,
case when t.unidades is not null then t.account_id end as account_id,
case when t.unidades is not null then t.customer_id end as customer_id,
case when t.unidades is not null then t.service_type end as service_type,
case when t.unidades is not null then t.bundle_type end as bundle_type,
case when t.unidades is not null then t.line_type_ds end as line_type_ds,
case when t.unidades is not null then t.phone_nm end as phone_nm,
case when t.unidades is not null then t.activation_date end as activation_date,
case when t.unidades is not null and  t.deactivation_date ='9999-12-31' THEN CAST(NULL AS DATE)
     when t.unidades is not null then t.deactivation_date end as deactivation_date,
case when t.unidades is not null then t.sale_date end as sale_date,
case when t.unidades is not null then t.order_id end as order_id,
case when t.unidades is not null then t.tariff_id end as tariff_id,
case when t.unidades is not null then t.tariff_ds end as tariff_ds,
case when t.unidades is not null then t.serial_number end as serial_number,
case when t.unidades is not null then t.tax_base end as tax_base,

CASE
  WHEN t.marca = "ALTERNA" THEN "Renata de las Heras"
  WHEN t.marca = "PARLEM" OR t.marca = "SWENO" OR UPPER(t.canal) LIKE "OCT" THEN "Serena Miguel"
  WHEN t.marca = "JOI" THEN "Ángel Olea"
  WHEN UPPER(t.canal) LIKE "JSM" THEN "Ángel Osuna"
  ELSE d.GERENTE_CUENTA
END AS GERENTE_CUENTA,
CASE 
  WHEN t.marca = "ALTERNA" THEN "ALTERNA"
  WHEN t.marca = "PARLEM" THEN "PARLEM"
  WHEN t.marca = "SWENO" THEN "SWENO"
  WHEN UPPER(t.canal) LIKE "OCT" THEN "OCT" 
  WHEN t.marca = "JOI" THEN "JOI"
  WHEN UPPER(t.canal) LIKE "JSM" THEN "JUNTOS SOMOS MÁS"
  ELSE d.CUENTA_CLIENTE
END AS CUENTA_CLIENTE,
d.GRUPO,
CASE
  WHEN t.marca = "ALTERNA" THEN "Marcas Blancas"
  WHEN t.marca = "PARLEM" OR t.marca = "SWENO" OR UPPER(t.canal) LIKE "OCT" THEN "Marcas Blancas"
  WHEN t.marca = "JOI" THEN "Marcas Blancas"
  WHEN UPPER(t.canal) LIKE "JSM" THEN "Marcas Propias"
  ELSE d.SEGMENTO
END AS SEGMENTO,
d.PROVINCIA,

COMPENSACION.fecha_compensacion,

sum(t.unidades) as unidades,
sum(t.comision) as comision,

from `mm-commissions-reporting.COMISIONES.transacciones` t, unnest(emails_acceso_trazabilidad) email

left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
          ) x
         ON t.invoice_id = x.invoice_id AND t.estado = 'facturado'
left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY rank ASC, created_date DESC) = 1
          ) y
         ON t.id_comisionista = y.fileid AND t.id_mes = CAST(y.month AS INT64) AND t.agrupacion_canal LIKE '%B2B%'

LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d ON t.cif = d.documento AND t.id_comisionista = d.id_comisionista

LEFT JOIN (
          SELECT header_reference AS invoice_id, MAX(clearing_date) AS fecha_compensacion
          FROM `mm-datamart-kd.SAP.general_ledger`
          WHERE vendor_id IS NOT NULL AND ledger = 'N1'
          GROUP BY 1
          ) COMPENSACION
         ON t.invoice_id = COMPENSACION.invoice_id

where estado in ( 'facturado', 'publicado', 'facturado_ifs')
      and email NOT IN ('catalina.jariego@masmovil.com', 'marcos.carrero@masmovil.com')
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43

union all

select
email,
id_mes,
COMISIONES.f_mes_int(id_mes)  as mes_liquidado,
a.agrupacion_canal,
a.canal,
a.id_comisionista,
a.invoice_id,
a.estado,
a.concepto,
a.process_code,
a.campaign_code,
a.claim_code,
a.comments,
CASE WHEN a.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE a.id_factura_drive END AS id_factura_drive,
CASE WHEN a.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE COALESCE(x.id_fichero_trazabilidad,y.id_fichero_trazabilidad) END AS id_fichero_trazabilidad,
a.cif,
a.nombre_comercio,
`mm-commissions-reporting.COMISIONES.f_clasificacion_concepto`(concepto) as agrupacion_concepto,

case when a.unidades is not null then a.sfid_id end as sfid_id,
case when a.unidades is not null then a.seller end as seller,
case when a.unidades is not null then a.marca end as marca,
case when a.unidades is not null then a.cod_segmento end as cod_segmento,
case when a.unidades is not null then a.service_id end as service_id,
case when a.unidades is not null then a.account_id end as account_id,
case when a.unidades is not null then a.customer_id end as customer_id,
case when a.unidades is not null then a.service_type end as service_type,
case when a.unidades is not null then a.bundle_type end as bundle_type,
case when a.unidades is not null then a.line_type_ds end as line_type_ds,
case when a.unidades is not null then a.phone_nm end as phone_nm,
case when a.unidades is not null then a.activation_date end as activation_date,
case when a.unidades is not null and  a.deactivation_date ='9999-12-31' THEN CAST(NULL AS DATE)
     when a.unidades is not null then a.deactivation_date end as deactivation_date,
case when a.unidades is not null then a.sale_date end as sale_date,
case when a.unidades is not null then a.order_id end as order_id,
case when a.unidades is not null then a.tariff_id end as tariff_id,
case when a.unidades is not null then a.tariff_ds end as tariff_ds,
case when a.unidades is not null then a.serial_number end as serial_number,
case when a.unidades is not null then a.tax_base end as tax_base,
CASE
  WHEN a.marca = "ALTERNA" THEN "Renata de las Heras"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Serena Miguel"
  WHEN a.marca = "JOI" THEN "Ángel Olea"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Ángel Osuna"
  ELSE d.GERENTE_CUENTA
END AS GERENTE_CUENTA,
CASE 
  WHEN a.marca = "ALTERNA" THEN "ALTERNA"
  WHEN a.marca = "PARLEM" THEN "PARLEM"
  WHEN a.marca = "SWENO" THEN "SWENO"
  WHEN UPPER(a.canal) LIKE "OCT" THEN "OCT" 
  WHEN a.marca = "JOI" THEN "JOI"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "JUNTOS SOMOS MÁS"
  ELSE d.CUENTA_CLIENTE
END AS CUENTA_CLIENTE,
d.GRUPO,
CASE
  WHEN a.marca = "ALTERNA" THEN "Marcas Blancas"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Marcas Blancas"
  WHEN a.marca = "JOI" THEN "Marcas Blancas"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Marcas Propias"
  ELSE d.SEGMENTO
END AS SEGMENTO,
d.PROVINCIA,

COMPENSACION.fecha_compensacion,

sum(a.unidades) as unidades,
sum(a.comision) as comision,

from `mm-commissions-reporting.COMISIONES.transacciones` a
-- inner join `mm-commissions-reporting.COMISIONES.v_accesos_comisiones` b using (agrupacion_canal, service_type, marca)
inner join `mm-commissions-reporting.COMISIONES.accesos_comisiones` b using (agrupacion_canal, service_type, marca)

left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
          ) x
         ON a.invoice_id = x.invoice_id AND a.estado = 'facturado'

left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY rank ASC, created_date DESC) = 1
          ) y
         ON a.id_comisionista = y.fileid AND a.id_mes = CAST(y.month AS INT64) AND a.agrupacion_canal LIKE '%B2B%'

LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d ON a.cif = d.documento AND a.id_comisionista = d.id_comisionista

LEFT JOIN (
          SELECT header_reference AS invoice_id, MAX(clearing_date) AS fecha_compensacion
          FROM `mm-datamart-kd.SAP.general_ledger`
          WHERE vendor_id IS NOT NULL AND ledger = 'N1'
          GROUP BY 1
          ) COMPENSACION
         ON a.invoice_id = COMPENSACION.invoice_id

group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43
;

/*
set importe2 = (select sum(comision) from `mm-commissions-reporting.COMISIONES.visualizacion_trazabilidad` where email = 'nuno.adam@masmovil.com');

if abs (importe1 - importe2) > 0.01
then RAISE USING MESSAGE = 'Importes no cuadran: faltan '||cast ( importe1 - importe2 as string)||' EUR';
end if;
*/
else if modo = 'mensual' then



call `mm-commissions-reporting.COMISIONES.pr_actualizar_visualizacion_externos`();

create or replace table `mm-commissions-reporting.REPORTED.acceso_facturas` as
select
distinct
invoice_id as Numero_factura, email
from `mm-commissions-reporting.COMISIONES.transacciones` a, unnest(emails_acceso_trazabilidad	) email
where invoice_id is not null
and email like '%@%.%'
and id_mes >= id_mes_ejecucion --  in (id_mes_ejecucion,id_mes_actual)
;

call `mm-commissions-reporting.COMISIONES.pr_actualizar_facturas_drive`();

create or replace table `mm-commissions-reporting.COMISIONES.visualizacion_trazabilidad_mensual`
partition by mes_liquidado
cluster by email, id_mes, invoice_id, id_comisionista
as
select
email,
id_mes,
COMISIONES.f_mes_int(id_mes)  as mes_liquidado,
t.agrupacion_canal,
t.canal,
t.id_comisionista,
t.invoice_id,
t.estado,
t.concepto,
t.process_code,
t.campaign_code,
t.claim_code,
t.comments,
CASE WHEN t.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE t.id_factura_drive END AS id_factura_drive,
CASE WHEN t.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE COALESCE(x.id_fichero_trazabilidad,y.id_fichero_trazabilidad) END AS id_fichero_trazabilidad,
t.cif,
t.nombre_comercio,
`mm-commissions-reporting.COMISIONES.f_clasificacion_concepto`(concepto) as agrupacion_concepto,
/*
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then sfid_id end as sfid_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then seller end as seller,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then marca end as marca,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then cod_segmento end as cod_segmento,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then service_id end as service_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then account_id end as account_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then customer_id end as customer_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then service_type end as service_type,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then bundle_type end as bundle_type,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then line_type_ds end as line_type_ds,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then phone_nm end as phone_nm,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then activation_date end as activation_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then deactivation_date end as deactivation_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then sale_date end as sale_date,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then order_id end as order_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then tariff_id end as tariff_id,
case when unidades is not null AND agrupacion_canal NOT LIKE 'B2B%' then tariff_ds end as tariff_ds,
*/
case when t.unidades is not null then t.sfid_id end as sfid_id,
case when t.unidades is not null then t.seller end as seller,
case when t.unidades is not null then t.marca end as marca,
case when t.unidades is not null then t.cod_segmento end as cod_segmento,
case when t.unidades is not null then t.service_id end as service_id,
case when t.unidades is not null then t.account_id end as account_id,
case when t.unidades is not null then t.customer_id end as customer_id,
case when t.unidades is not null then t.service_type end as service_type,
case when t.unidades is not null then t.bundle_type end as bundle_type,
case when t.unidades is not null then t.line_type_ds end as line_type_ds,
case when t.unidades is not null then t.phone_nm end as phone_nm,
case when t.unidades is not null then t.activation_date end as activation_date,
case when t.unidades is not null and  t.deactivation_date ='9999-12-31' THEN CAST(NULL AS DATE)
     when t.unidades is not null then t.deactivation_date end as deactivation_date,
case when t.unidades is not null then t.sale_date end as sale_date,
case when t.unidades is not null then t.order_id end as order_id,
case when t.unidades is not null then t.tariff_id end as tariff_id,
case when t.unidades is not null then t.tariff_ds end as tariff_ds,
case when t.unidades is not null then t.serial_number end as serial_number,
case when t.unidades is not null then t.tax_base end as tax_base,

CASE
  WHEN t.marca = "ALTERNA" THEN "Renata de las Heras"
  WHEN t.marca = "PARLEM" OR t.marca = "SWENO" OR UPPER(t.canal) LIKE "OCT" THEN "Serena Miguel"
  WHEN t.marca = "JOI" THEN "Ángel Olea"
  WHEN UPPER(t.canal) LIKE "JSM" THEN "Ángel Osuna"
  ELSE d.GERENTE_CUENTA
END AS GERENTE_CUENTA,
CASE 
  WHEN t.marca = "ALTERNA" THEN "ALTERNA"
  WHEN t.marca = "PARLEM" THEN "PARLEM"
  WHEN t.marca = "SWENO" THEN "SWENO"
  WHEN UPPER(t.canal) LIKE "OCT" THEN "OCT" 
  WHEN t.marca = "JOI" THEN "JOI"
  WHEN UPPER(t.canal) LIKE "JSM" THEN "JUNTOS SOMOS MÁS"
  ELSE d.CUENTA_CLIENTE
END AS CUENTA_CLIENTE,
d.GRUPO,
CASE
  WHEN t.marca = "ALTERNA" THEN "Marcas Blancas"
  WHEN t.marca = "PARLEM" OR t.marca = "SWENO" OR UPPER(t.canal) LIKE "OCT" THEN "Marcas Blancas"
  WHEN t.marca = "JOI" THEN "Marcas Blancas"
  WHEN UPPER(t.canal) LIKE "JSM" THEN "Marcas Propias"
  ELSE d.SEGMENTO
END AS SEGMENTO,
d.PROVINCIA,

COMPENSACION.fecha_compensacion,

sum(t.unidades) as unidades,
sum(t.comision) as comision,

from `mm-commissions-reporting.COMISIONES.transacciones` t, unnest(emails_acceso_trazabilidad) email

left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
          ) x
         ON t.invoice_id = x.invoice_id AND t.estado = 'facturado'
left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY rank ASC, created_date DESC) = 1
          ) y
         ON t.id_comisionista = y.fileid AND t.id_mes = CAST(y.month AS INT64) AND t.agrupacion_canal LIKE '%B2B%'

LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d ON t.cif = d.documento AND t.id_comisionista = d.id_comisionista

LEFT JOIN (
          SELECT header_reference AS invoice_id, MAX(clearing_date) AS fecha_compensacion
          FROM `mm-datamart-kd.SAP.general_ledger`
          WHERE vendor_id IS NOT NULL AND ledger = 'N1'
          GROUP BY 1
          ) COMPENSACION
         ON t.invoice_id = COMPENSACION.invoice_id

where estado in ( 'facturado', 'publicado', 'facturado_ifs')
      and (email NOT IN ('catalina.jariego@masmovil.com', 'marcos.carrero@masmovil.com') or email is null)
      and id_mes  >= id_mes_ejecucion -- in (id_mes_ejecucion,id_mes_actual)
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43

union all

select
email,
id_mes,
COMISIONES.f_mes_int(id_mes)  as mes_liquidado,
a.agrupacion_canal,
a.canal,
a.id_comisionista,
a.invoice_id,
a.estado,
a.concepto,
a.process_code,
a.campaign_code,
a.claim_code,
a.comments,
CASE WHEN a.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE a.id_factura_drive END AS id_factura_drive,
CASE WHEN a.cif = 'B70186184' THEN CAST(NULL AS STRING) ELSE COALESCE(x.id_fichero_trazabilidad,y.id_fichero_trazabilidad) END AS id_fichero_trazabilidad,
a.cif,
a.nombre_comercio,
`mm-commissions-reporting.COMISIONES.f_clasificacion_concepto`(concepto) as agrupacion_concepto,

case when a.unidades is not null then a.sfid_id end as sfid_id,
case when a.unidades is not null then a.seller end as seller,
case when a.unidades is not null then a.marca end as marca,
case when a.unidades is not null then a.cod_segmento end as cod_segmento,
case when a.unidades is not null then a.service_id end as service_id,
case when a.unidades is not null then a.account_id end as account_id,
case when a.unidades is not null then a.customer_id end as customer_id,
case when a.unidades is not null then a.service_type end as service_type,
case when a.unidades is not null then a.bundle_type end as bundle_type,
case when a.unidades is not null then a.line_type_ds end as line_type_ds,
case when a.unidades is not null then a.phone_nm end as phone_nm,
case when a.unidades is not null then a.activation_date end as activation_date,
case when a.unidades is not null and  a.deactivation_date ='9999-12-31' THEN CAST(NULL AS DATE)
     when a.unidades is not null then a.deactivation_date end as deactivation_date,
case when a.unidades is not null then a.sale_date end as sale_date,
case when a.unidades is not null then a.order_id end as order_id,
case when a.unidades is not null then a.tariff_id end as tariff_id,
case when a.unidades is not null then a.tariff_ds end as tariff_ds,
case when a.unidades is not null then a.serial_number end as serial_number,
case when a.unidades is not null then a.tax_base end as tax_base,
CASE
  WHEN a.marca = "ALTERNA" THEN "Renata de las Heras"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Serena Miguel"
  WHEN a.marca = "JOI" THEN "Ángel Olea"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Ángel Osuna"
  ELSE d.GERENTE_CUENTA
END AS GERENTE_CUENTA,
CASE 
  WHEN a.marca = "ALTERNA" THEN "ALTERNA"
  WHEN a.marca = "PARLEM" THEN "PARLEM"
  WHEN a.marca = "SWENO" THEN "SWENO"
  WHEN UPPER(a.canal) LIKE "OCT" THEN "OCT" 
  WHEN a.marca = "JOI" THEN "JOI"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "JUNTOS SOMOS MÁS"
  ELSE d.CUENTA_CLIENTE
END AS CUENTA_CLIENTE,
d.GRUPO,
CASE
  WHEN a.marca = "ALTERNA" THEN "Marcas Blancas"
  WHEN a.marca = "PARLEM" OR a.marca = "SWENO" OR UPPER(a.canal) LIKE "OCT" THEN "Marcas Blancas"
  WHEN a.marca = "JOI" THEN "Marcas Blancas"
  WHEN UPPER(a.canal) LIKE "JSM" THEN "Marcas Propias"
  ELSE d.SEGMENTO
END AS SEGMENTO,
d.PROVINCIA,

COMPENSACION.fecha_compensacion,

sum(a.unidades) as unidades,
sum(a.comision) as comision,

from `mm-commissions-reporting.COMISIONES.transacciones` a
-- inner join `mm-commissions-reporting.COMISIONES.v_accesos_comisiones` b using (agrupacion_canal, service_type, marca)
inner join `mm-commissions-reporting.COMISIONES.accesos_comisiones` b using (agrupacion_canal, service_type, marca)
left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS invoice_id
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY rank ASC, created_date DESC) = 1
          ) x
         ON a.invoice_id = x.invoice_id AND a.estado = 'facturado'

left join (
          SELECT * EXCEPT(rank)
          FROM (
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_cablemovil`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_b2b_marblanca`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_etnico`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_no_exclusivo`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,1 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_resto`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               UNION ALL
               (
               SELECT
                     REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'_(.*)'), file_name), '.xlsx', ''), '.xls', '') AS fileid
                    ,REPLACE(REPLACE(COALESCE(REGEXP_EXTRACT(file_name, r'(.*)_'), file_name), '.xlsx', ''), '.xls', '') AS month
                    ,file_id AS id_fichero_trazabilidad
                    ,created_date
                    ,2 AS rank
               FROM `mm-commissions-reporting.REPORTED.log_files_trazabilidades_historic`
               WHERE UPPER(file_name) LIKE '%XLS%'
                     AND file_name NOT LIKE 'F%'
               QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY file_size DESC, created_date DESC) = 1
               )
               )
          QUALIFY ROW_NUMBER() OVER (PARTITION BY fileid, month ORDER BY rank ASC, created_date DESC) = 1
          ) y
         ON a.id_comisionista = y.fileid AND a.id_mes = CAST(y.month AS INT64) AND a.agrupacion_canal LIKE '%B2B%'

LEFT JOIN `mm-commissions-reporting.TEMP.maestro_grupo` d ON a.cif = d.documento AND a.id_comisionista = d.id_comisionista

LEFT JOIN (
          SELECT header_reference AS invoice_id, MAX(clearing_date) AS fecha_compensacion
          FROM `mm-datamart-kd.SAP.general_ledger`
          WHERE vendor_id IS NOT NULL AND ledger = 'N1'
          GROUP BY 1
          ) COMPENSACION
         ON a.invoice_id = COMPENSACION.invoice_id
where  id_mes >= id_mes_ejecucion --  in (id_mes_ejecucion,id_mes_actual)

group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43
;

end if;
end if;

if modo = 'mensual' then
delete from `mm-commissions-reporting.COMISIONES.visualizacion_comisiones` where id_mes >= id_mes_ejecucion --  in (id_mes_ejecucion,id_mes_actual)
;
insert into `mm-commissions-reporting.COMISIONES.visualizacion_comisiones` 
select *
from  `mm-commissions-reporting.COMISIONES.visualizacion_comisiones_mensual` where 1=1;

delete from `mm-commissions-reporting.COMISIONES.visualizacion_trazabilidad` where id_mes >= id_mes_ejecucion --  in (id_mes_ejecucion,id_mes_actual)
;
insert into `mm-commissions-reporting.COMISIONES.visualizacion_trazabilidad` 
select *
from  `mm-commissions-reporting.COMISIONES.visualizacion_trazabilidad_mensual` where 1=1;

end if;



END