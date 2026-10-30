BEGIN

DECLARE sql, mes_string STRING;

SET mes_string = CAST(mes_int AS STRING);


-- call `mm-commissions-reporting.COMISIONES.pr_provib2b`(202403);

-- PR_ELIMINAR DETALLE

      DELETE `mm-commissions-reporting.COMISIONES.provisiones_reportadas_b2b_cable_detalle` 
      WHERE id_mes = CAST(mes_string AS INT64)
;

-- PR_ELIMINAR AGRUPADO
      DELETE `mm-commissions-reporting.COMISIONES.provisiones_reportadas_b2b_cable_agrupado` 
      WHERE id_mes = CAST(mes_string AS INT64)

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.prov_b2b_cable_detalle` AS 

      SELECT CAST(mes_string AS INT64) AS id_mes_prov,(a.comision*((b.porcentaje/100)+1)) as provision, CONCAT(b.porcentaje,"%") AS porcentaje_prov ,a.*
      FROM `mm-commissions-reporting.COMISIONES.visualizacion_transacciones_b2b` a

      --CRUZAMOS SOLO CON LOS id_comisionistas CON PORCENTAJES ESPECIALES
      JOIN `mm-commissions-reporting.GS.PORCENTAJE_PROVISIONES_B2B` b ON 
            a.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE_TRUNC(DATE(PARSE_DATE('%Y%m', CAST(CAST(mes_string AS INT64) AS STRING))), MONTH), INTERVAL 1 MONTH)) AS INT64) 
            AND a.id_comisionista = b.id_comisionista
      WHERE a.estado IN ('facturado','publicado') 
       AND b.porcentaje IS NOT NULL
       AND a.tipo_concepto = 'AIRT'

       UNION ALL

       SELECT CAST(mes_string AS INT64) AS id_mes_prov, (a.comision*((b.porcentaje/100)+1)) as provision, CONCAT(b.porcentaje,"%") AS porcentaje_prov ,a.*
      FROM `mm-commissions-reporting.COMISIONES.visualizacion_transacciones_b2b` a

      --CRUZAMOS CON TODO EL CANAL QUE TENGAN UN ÚNICO PORCENTAJE
      JOIN `mm-commissions-reporting.GS.PORCENTAJE_PROVISIONES_B2B` b ON 
            a.id_mes = CAST(FORMAT_DATE('%Y%m', DATE_SUB(DATE_TRUNC(DATE(PARSE_DATE('%Y%m', CAST(CAST(mes_string AS INT64) AS STRING))), MONTH), INTERVAL 1 MONTH)) AS INT64) 
            AND  b.id_comisionista IS NULL AND a.agrupacion_canal = b.agrupacion_canal
      WHERE a.estado IN ('facturado','publicado') 
       AND b.porcentaje IS NOT NULL

       --QUITAMOS LOS id_comisionistas CON PORCENTAJES ESPECIALES
       AND a.id_comisionista NOT IN (SELECT id_comisionista FROM `mm-commissions-reporting.GS.PORCENTAJE_PROVISIONES_B2B` WHERE id_mes = CAST(mes_string AS INT64) AND id_comisionista IS NOT NULL)
       AND a.tipo_concepto = 'AIRT'
       

;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.prov_b2b_cable_agrupado` AS

     SELECT
       CAST(mes_string AS INT64) AS id_mes
      ,'OPEX' AS opex
      ,'S3' AS clase_documento
      ,sociedad
      ,id_comisionista
      ,nombre_comercio
      ,ROUND(SUM(comision),2)  AS comision
      ,ROUND(SUM(provision),2) AS provision
      ,'60722113' AS cuenta_contable
      ,CASE
        WHEN sociedad = 'X001' THEN 'X0SL'
        ELSE sociedad
       END AS centro_coste
      ,NULL AS orden_de_inversion
      ,cod_producto
      ,cod_tipo_contrato
      ,cod_segmento
      ,'999' AS operador
      ,cod_canal AS canal
      ,cod_marca AS marca
      ,CAST(NULL AS STRING) AS sociedadGL
      ,CAST(NULL AS STRING) AS categoria
      ,CONCAT('PROVISION ', CAST(mes_string AS INT64)) AS asignacion
      ,agrupacion_canal AS texto
     FROM `mm-commissions-reporting.TEMP.prov_b2b_cable_detalle`
     GROUP BY 1,2,3,4,5,6,9,10,11,12,13,14,15,16,17,18,19,20,21

;

INSERT `mm-commissions-reporting.COMISIONES.provisiones_reportadas_b2b_cable_detalle`

      SELECT *
      FROM `mm-commissions-reporting.TEMP.prov_b2b_cable_detalle` 

;

INSERT `mm-commissions-reporting.COMISIONES.provisiones_reportadas_b2b_cable_agrupado`

      SELECT *
      FROM `mm-commissions-reporting.TEMP.prov_b2b_cable_agrupado` 

;


END