BEGIN

DECLARE prefijo, mes_string STRING;
DECLARE mes_pr DATE;

SET mes_pr = COMISIONES.f_mes_int(mes_int);
SET prefijo = 'MULT';

/*
CALL COMISIONES.pr_mult (202306);
*/


SET mes_string = CAST(mes_int AS STRING);

/*
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.multiplicador_residencial_servicio_base` AS

SELECT
      TRANSACCIONES.* EXCEPT (commission_id, unidades, comision, concepto, tipo_concepto, service_type)
     ,prefijo||'_'||mes_string||'_'||canal||'_'||ROW_NUMBER () OVER () AS commission_id
     ,1 AS unidades
     
     ,CASE
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL  THEN 'D - Acelerador Negocios'
          WHEN REPARTOS.nivel = 0.1                      THEN 'D - Multiplicador Residencial (10%)'
          WHEN REPARTOS.nivel = 0.2                      THEN 'D - Multiplicador Residencial (20%)'
          WHEN REPARTOS.nivel = 0.3                      THEN 'D - Multiplicador Residencial (30%)'
      END AS concepto
     
     ,CASE
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL AND unidades_negocios <= 2                            THEN 20
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL AND unidades_negocios <= 4                            THEN 40
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL AND unidades_negocios <= 9                            THEN 70
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL AND unidades_negocios <= 14 AND canal IN ('MI','MR')  THEN 70
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL AND unidades_negocios <= 14 AND canal = 'MP'          THEN 120
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL                                                       THEN 120
          WHEN REPARTOS.nivel = 0.1                                                                           THEN 0.1 * comision
          WHEN REPARTOS.nivel = 0.2                                                                           THEN 0.2 * comision
          WHEN REPARTOS.nivel = 0.3                                                                           THEN 0.3 * comision
      END AS comision
     
     ,CASE
          WHEN service_type IN ('INTERNET', 'FIX', 'MOBILE') THEN 'UPFR'
          WHEN service_type = 'TV'                           THEN 'OTRS'
      END AS tipo_concepto
     
     ,CASE WHEN service_type = 'FIX' THEN 'INTERNET' ELSE service_type END AS service_type

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN (
          SELECT seller, id_mes, nivel
          FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
          WHERE id_mes = mes_int
          QUALIFY ROW_NUMBER () OVER (PARTITION BY seller ORDER BY nivel NULLS LAST) = 1
          ) REPARTOS
         ON TRANSACCIONES.id_mes = REPARTOS.id_mes
            AND CASE WHEN TRANSACCIONES.sfid_id LIKE 'MASTER%' AND LENGTH(TRANSACCIONES.sfid_id) = 8
                     THEN CONCAT(TRANSACCIONES.sfid_id, '-', LPAD(SUBSTR(TRANSACCIONES.seller, -4), 4, '0'))
                     ELSE TRANSACCIONES.sfid_id
                END = REPARTOS.seller

LEFT JOIN (
          SELECT sfid_id, marca, service_id
          FROM `mm-commissions-reporting.COMISIONES.transacciones` 
          WHERE id_mes = mes_int
                AND canal IN ('MP','MI', 'MR')
                AND concepto = 'A - Servicio Fijo'
                AND bundle_type = 'FMC'
                AND cod_segmento = '12'
          GROUP BY 1,2,3
          ) NEGOCIO_SERVICIOS
         ON CASE WHEN TRANSACCIONES.sfid_id LIKE 'MASTER%' AND LENGTH(TRANSACCIONES.sfid_id) = 8
                 THEN CONCAT(TRANSACCIONES.sfid_id, '-', LPAD(SUBSTR(TRANSACCIONES.seller, -4), 4, '0'))
                 ELSE TRANSACCIONES.sfid_id
            END = NEGOCIO_SERVICIOS.sfid_id
            AND TRANSACCIONES.service_id = NEGOCIO_SERVICIOS.service_id
            AND TRANSACCIONES.marca = NEGOCIO_SERVICIOS.marca

LEFT JOIN (
          SELECT sfid_id, SUM(unidades) AS unidades_negocios
          FROM `mm-commissions-reporting.COMISIONES.transacciones` 
          WHERE id_mes = mes_int
                AND canal IN ('MP','MI', 'MR')
                AND concepto = 'A - Servicio Fijo'
                AND bundle_type = 'FMC'
                AND cod_segmento = '12'
          GROUP BY 1
          ) NEGOCIO_UNIDADES
         ON CASE WHEN TRANSACCIONES.sfid_id LIKE 'MASTER%' AND LENGTH(TRANSACCIONES.sfid_id) = 8
                 THEN CONCAT(TRANSACCIONES.sfid_id, '-', LPAD(SUBSTR(TRANSACCIONES.seller, -4), 4, '0'))
                 ELSE TRANSACCIONES.sfid_id
            END = NEGOCIO_UNIDADES.sfid_id

WHERE TRANSACCIONES.id_mes = mes_int
      AND canal IN ('MP','MI', 'MR')
      AND (
          (
          NEGOCIO_SERVICIOS.service_id IS NULL
          AND TRANSACCIONES.concepto IN (
                                        'A - Portabilidad Fijo',
                                        'A - Portabilidad Movil Pospago',
                                        'A - Servicio Fijo',
                                        'A - Servicio Fijo Cambio de Domicilio',
                                        'A - Servicio Fijo Cambio de Tecnologia',
                                        'A - Servicio Movil Pospago',
                                        'B - Television',
                                        'B - Television Premium'
                                        )
          AND nivel > 0
          )
          OR
          (NEGOCIO_SERVICIOS.service_id IS NOT NULL AND TRANSACCIONES.concepto = 'A - Servicio Fijo')
          )
;
*/

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.multiplicador_residencial_gestion_canal` AS

SELECT
      TRANSACCIONES.* EXCEPT(id_comisionista, nombre_comercio, razon_social, cif, zona_fiscal, commission_id, unidades, comision, concepto, tipo_concepto, service_type)
     ,MASTER.id_comisionista
     ,MASTER.nombre_comercio
     ,MASTER.razon_social
     ,MASTER.cif
     ,MASTER.zona_fiscal
     ,prefijo || '_' || mes_string || '_' || TRANSACCIONES.canal || '_' || ROW_NUMBER () OVER () || 'B' AS commission_id

     ,CASE WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL THEN 1 END AS unidades
     
     ,CASE
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL  THEN 'F - Acelerador Negocios'
          WHEN REPARTOS.nivel = 0.1                      THEN 'F - Multiplicador Residencial (10%)'
          WHEN REPARTOS.nivel = 0.2                      THEN 'F - Multiplicador Residencial (20%)'
          WHEN REPARTOS.nivel = 0.3                      THEN 'F - Multiplicador Residencial (30%)'
      END AS concepto
     
     ,CASE
          WHEN NEGOCIO_SERVICIOS.service_id IS NOT NULL   THEN 20
          WHEN REPARTOS.nivel = 0.1                       THEN 0.1 * comision
          WHEN REPARTOS.nivel = 0.2                       THEN 0.2 * comision
          WHEN REPARTOS.nivel = 0.3                       THEN 0.3 * comision
      END AS comision
     
     ,CASE
          WHEN service_type IN ('INTERNET', 'FIX', 'MOBILE') THEN 'UPFR'
          WHEN service_type = 'TV'                           THEN 'OTRS'
      END AS tipo_concepto
     
     ,CASE WHEN service_type = 'FIX' THEN 'INTERNET' ELSE service_type END AS service_type

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` MASTER
          ON TRANSACCIONES.distribuidor = MASTER.id_comisionista and TRANSACCIONES.canal IN ('MI')

LEFT JOIN (
          SELECT seller, id_mes, nivel
          FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda`
          WHERE id_mes = mes_int
          QUALIFY ROW_NUMBER () OVER (PARTITION BY seller ORDER BY nivel NULLS LAST) = 1
          ) REPARTOS
         ON TRANSACCIONES.id_mes = REPARTOS.id_mes
            AND CASE WHEN TRANSACCIONES.sfid_id LIKE 'MASTER%' AND LENGTH(TRANSACCIONES.sfid_id) = 8
                     THEN CONCAT(TRANSACCIONES.sfid_id, '-', LPAD(SUBSTR(TRANSACCIONES.seller, -4), 4, '0'))
                     ELSE TRANSACCIONES.sfid_id
                END = REPARTOS.seller

LEFT JOIN (
          SELECT sfid_id, marca, service_id
          FROM `mm-commissions-reporting.COMISIONES.transacciones` 
          WHERE id_mes = mes_int
                AND canal IN ('MI')
                AND concepto = 'A - Servicio Fijo'
                AND bundle_type = 'FMC'
                AND cod_segmento = '12'
          GROUP BY 1,2,3
          ) NEGOCIO_SERVICIOS
         ON CASE WHEN TRANSACCIONES.sfid_id LIKE 'MASTER%' AND LENGTH(TRANSACCIONES.sfid_id) = 8
                 THEN CONCAT(TRANSACCIONES.sfid_id, '-', LPAD(SUBSTR(TRANSACCIONES.seller, -4), 4, '0'))
                 ELSE TRANSACCIONES.sfid_id
            END = NEGOCIO_SERVICIOS.sfid_id
            AND TRANSACCIONES.service_id = NEGOCIO_SERVICIOS.service_id
            AND TRANSACCIONES.marca = NEGOCIO_SERVICIOS.marca

LEFT JOIN (
          SELECT sfid_id, SUM(unidades) AS unidades_negocios
          FROM `mm-commissions-reporting.COMISIONES.transacciones` 
          WHERE id_mes = mes_int
                AND canal IN ('MI')
                AND concepto = 'A - Servicio Fijo'
                AND bundle_type = 'FMC'
                AND cod_segmento = '12'
          GROUP BY 1
          ) NEGOCIO_UNIDADES
         ON CASE WHEN TRANSACCIONES.sfid_id LIKE 'MASTER%' AND LENGTH(TRANSACCIONES.sfid_id) = 8
                 THEN CONCAT(TRANSACCIONES.sfid_id, '-', LPAD(SUBSTR(TRANSACCIONES.seller, -4), 4, '0'))
                 ELSE TRANSACCIONES.sfid_id
            END = NEGOCIO_UNIDADES.sfid_id

WHERE TRANSACCIONES.id_mes = mes_int
      AND TRANSACCIONES.canal IN ('MI')
      AND (
          (
          NEGOCIO_SERVICIOS.service_id IS NULL
          AND TRANSACCIONES.concepto IN (
                                        'F - Portabilidad Fijo',
                                        'F - Portabilidad Movil Pospago',
                                        'F - Servicio Fijo',
                                        'F - Servicio Fijo Cambio de Domicilio',
                                        'F - Servicio Fijo Cambio de Tecnologia',
                                        'F - Servicio Movil Pospago',
                                        'F - Television',
                                        'F - Television Premium'
                                        )
          AND nivel > 0
          )
          OR
          (NEGOCIO_SERVICIOS.service_id IS NOT NULL AND TRANSACCIONES.concepto = 'A - Servicio Fijo')
          )
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.multiplicador_residencial` AS
/*
SELECT
      * EXCEPT(id_comisionista, nombre_comercio, razon_social, cif, zona_fiscal, commission_id, unidades, comision, concepto, tipo_concepto, facturador)
     ,id_comisionista
     ,nombre_comercio
     ,razon_social
     ,cif
     ,zona_fiscal
     ,commission_id
     ,unidades
     ,comision
     ,concepto
     ,tipo_concepto
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.multiplicador_residencial_servicio_base`

UNION ALL
*/
SELECT 
      * EXCEPT(id_comisionista, nombre_comercio, razon_social, cif, zona_fiscal, commission_id, unidades, comision, concepto, tipo_concepto, facturador)
     ,id_comisionista
     ,nombre_comercio
     ,razon_social
     ,cif
     ,zona_fiscal
     ,commission_id
     ,unidades
     ,comision
     ,concepto
     ,tipo_concepto
     ,'C_MANUAL' AS facturador

FROM `mm-commissions-reporting.TEMP.multiplicador_residencial_gestion_canal`
;


ASSERT NOT EXISTS
(
SELECT DISTINCT REPARTOS.seller
FROM `mm-commissions-reporting.COMISIONES.v_repartos_no_exclusivo_nivel_tienda` REPARTOS
LEFT JOIN (
          SELECT sfid_id, COUNT(DISTINCT service_id) count
          FROM `mm-commissions-reporting.COMISIONES.transacciones` 
          WHERE id_mes = mes_int
                AND agrupacion_canal = 'No Exclusivo'
                AND concepto LIKE 'A%'
          GROUP BY 1
          ) TRANSACCIONES
         ON REPARTOS.seller = TRANSACCIONES.sfid_id AND TRANSACCIONES.count > 0
WHERE REPARTOS.id_mes = mes_int
      AND REPARTOS.nivel > 0
      AND TRANSACCIONES.sfid_id IS NOT NULL
      AND REPARTOS.seller NOT IN (SELECT DISTINCT sfid_id FROM `mm-commissions-reporting.TEMP.multiplicador_residencial`)
)
;

--CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('MULT_', mes_int, ['MI','CA', 'MP', 'MR'] , 'TEMP.multiplicador_residencial', 'ACTUALIZAR' );


END