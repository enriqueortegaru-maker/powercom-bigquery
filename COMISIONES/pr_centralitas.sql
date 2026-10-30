BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'CND2';


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN','ALTNC','ALTNH','D2D','D2N','DEM','ENK','EML','EDB','OUN','PH','DON','CIN','XSN','XIN'];
END IF;


/*
CALL COMISIONES.pr_centralitas (202501, ['ALTN']);
*/


-- ACTIVACIONES DEL MES
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.centralitas_activaciones` AS (
    SELECT *
    FROM

    (
      SELECT  
      prefijo||'B_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,DEALER.agrupacion_canal
      ,DEALER.canal
      ,'B - Centralitas Base' as concepto
      ,'OTRS'as tipo_concepto
      ,1 as unidades
      ,COMISIONES.f_comision_centralitas(DEALER.canal,CENT.tariff_id,CENT.brand_ds,true,false) AS comision    
      ,DEALER.id_comisionista
      ,DEALER.distribuidor
      ,DEALER.sfid_id
      -- ,DEALER.sfid_id as seller
      -- ,CASE 
      --       WHEN CENT.CODIGO_AGENTE = '#N/A'  THEN CENT.seller 
      --       WHEN CENT.CODIGO_AGENTE = 'DBM01' THEN CENT.seller 
      --       ELSE CENT.CODIGO_AGENTE
      -- END AS seller
      ,CASE
            WHEN DEALER.agrupacion_canal = 'D2D' THEN 
                CASE 
                    WHEN CENT.CODIGO_AGENTE = '#N/A' THEN CENT.seller 
                    ELSE CENT.CODIGO_AGENTE 
                END
            ELSE CENT.seller 
      END AS seller
      ,DEALER.nombre_comercio
      ,DEALER.razon_social
      ,DEALER.cif
      ,DEALER.zona_fiscal
      ,CENT.brand_ds AS marca
      ,'OTRS' AS Service_type
      ,CENT.phone_nm
      ,CENT.tariff_id
      ,CENT.tariff_ds	
      ,CENT.service_id
      ,CENT.account_id
      ,CENT.customer_id
      ,CAST (NULL AS STRING) line_type_ds
      ,CAST (NULL AS STRING) bundle_type
      ,CAST (NULL AS STRING) technology_ds
      ,CAST (NULL AS STRING) billing_type_ds
      ,CENT.activation_date as sale_date
      ,CENT.activation_date
      ,CENT.deactivation_date
      ,CAST (NULL AS STRING) order_id
      ,CAST (NULL AS STRING) order_type_agg
      ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(CENT.segment_ds, CENT.brand_ds) AS cod_segmento
      ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(CENT.brand_ds) AS cod_marca
      ,'61' as cod_tipo_contrato
      ,'999' as cod_producto
      ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(CENT.channel_ds, CENT.subchannel_ds) AS cod_canal
      ,CAST (NULL AS STRING) AS campaign_code
      ,CAST (NULL AS STRING) AS serial_number
      ,CAST (NULL AS FLOAT64) AS tax_base
      ,CAST (NULL AS STRING) AS claim_code
      ,CAST (NULL AS STRING) AS process_code
      ,'Centralitas '||DEALER.canal||' '||id_mes_pr AS comments
      ,'C_MANUAL' AS facturador
      ,`mm-commissions-reporting.COMISIONES.f_sociedad`(CENT.Brand_ds) AS sociedad
      ,CURRENT_TIMESTAMP AS creado
      ,CURRENT_TIMESTAMP AS modificado


    FROM `mm-commissions-reporting.D2D.v_servicio_centralitas` CENT

        LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
        ON CASE
                WHEN DEALER.agrupacion_canal = 'D2D' THEN 
                    CASE 
                        WHEN CENT.CODIGO_AGENTE = '#N/A' THEN CENT.seller 
                        ELSE CENT.CODIGO_AGENTE 
                    END
                ELSE CENT.seller
            END = DEALER.sfid_id
        AND DEALER.comisiona

      WHERE DATE_TRUNC(CENT.activation_date, MONTH) = DATE_TRUNC(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), MONTH)
      AND DEALER.CANAL IN UNNEST(canales_pr)

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca ORDER BY activation_date DESC) = 1)
)
;

--- GESTION DE CANAL ---

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.centralitas_gestion_canal` AS (
  SELECT  
      prefijo||'F_'|| mes_string ||'_'|| DEALER.canal ||'_'||ROW_NUMBER () OVER () AS commission_id
      ,'calculado' AS estado
      ,PARSE_DATE('%Y%m', mes_string) AS mes_liquidado
      ,id_mes_pr AS id_mes
      ,DEALER.agrupacion_canal
      ,DEALER.canal
      ,'F - Gestion de canal Centralitas Base' as concepto
      ,'OTRS'as tipo_concepto
      ,1 as unidades
      ,COMISIONES.f_comision_centralitas(DEALER.canal,CENT.tariff_id,CENT.brand_ds, FALSE,TRUE) AS comision    
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,CASE 
          WHEN CENT.CODIGO_AGENTE = '#N/A' THEN CENT.seller 
          WHEN CENT.CODIGO_AGENTE = 'DBM01' THEN CENT.seller
          ELSE CENT.CODIGO_AGENTE 
      END AS seller
     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.documento, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
      ,CENT.brand_ds as marca
      ,'OTRS' AS Service_type
      ,CENT.phone_nm
      ,CENT.tariff_id
      ,CENT.tariff_ds	
      ,CENT.service_id
      ,CENT.account_id
      ,CENT.customer_id
      ,CAST (NULL AS STRING) line_type_ds
      ,CAST (NULL AS STRING) bundle_type
      ,CAST (NULL AS STRING) technology_ds
      ,CAST (NULL AS STRING) billing_type_ds
      ,CENT.activation_date AS sale_date
      ,CENT.activation_date
      ,CENT.deactivation_date
      ,CAST (NULL AS STRING) order_id
      ,CAST (NULL AS STRING) order_type_agg
      ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(CENT.segment_ds, CENT.brand_ds) AS cod_segmento
      ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(CENT.brand_ds) AS cod_marca
      ,'61' as cod_tipo_contrato
      ,'999' as cod_producto
      ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_canal`(CENT.channel_ds, CENT.subchannel_ds) AS cod_canal
      ,CAST (NULL AS STRING) AS campaign_code
      ,CAST (NULL AS STRING) AS serial_number
      ,CAST (NULL AS FLOAT64) AS tax_base
      ,CAST (NULL AS STRING) AS claim_code
      ,CAST (NULL AS STRING) AS process_code
      ,'Centralitas '||DEALER.canal||' '||id_mes_pr AS comments
      ,'C_MANUAL' AS facturador
      ,`mm-commissions-reporting.COMISIONES.f_sociedad`(CENT.brand_ds) AS sociedad
      ,CURRENT_TIMESTAMP AS creado
      ,CURRENT_TIMESTAMP AS modificado



      FROM `mm-commissions-reporting.D2D.v_servicio_centralitas` CENT

        LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
        ON CASE
            WHEN DEALER.agrupacion_canal = 'D2D' THEN 
                CASE 
                    WHEN CENT.CODIGO_AGENTE = '#N/A' THEN CENT.seller 
                    ELSE CENT.CODIGO_AGENTE 
                END
            ELSE CENT.seller
        END = DEALER.sfid_id

        LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista


        WHERE DATE_TRUNC(CENT.activation_date, MONTH) = DATE_TRUNC(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), MONTH)
        AND DEALER.CANAL IN UNNEST(canales_pr) 
        AND DEALER.agrupacion_canal IN ('No Exclusivo')
        AND DEALER.distribuidor IS NOT NULL

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca ORDER BY activation_date DESC) = 1
)
;


----- CLAWBACKS ----
CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.centralitas_clawback` AS (

SELECT  
  'CND2E'||'_'||mes_string||'_'||T.CANAL||row_number () over () AS commission_id,
  'calculado' AS estado,
  PARSE_DATE('%Y%m', mes_string) AS mes_liquidado,
  id_mes_pr AS id_mes,
  T.agrupacion_canal,
  T.canal,
  CASE 
    WHEN T.CONCEPTO LIKE 'B -%' THEN REPLACE(concepto, 'B -', 'E - Clawback') 
    WHEN T.CONCEPTO LIKE 'F -%' THEN REPLACE(concepto, 'F -', 'H - Clawback') 
  END AS concepto,
  T.tipo_concepto,
  T.unidades,
  COMISIONES.f_comision_clawback(DATE_DIFF(DATE (DEACTIVATIONS.deactivation_date), DATE (T.activation_date), DAY)+1,T.canal,T.tariff_ds) * T.comision AS comision,
  T.id_comisionista,
  T.distribuidor,
  T.sfid_id,
  T.seller,
  T.nombre_comercio,
  T.razon_social,
  T.cif,
  T.zona_fiscal,
  T.marca,
  T.service_type,
  T.phone_nm,
  T.tariff_id,
  T.tariff_ds,
  T.service_id,
  T.account_id,
  T.customer_id,
  T.line_type_ds,
  T.bundle_type,
  T.technology_ds,
  T.billing_type_ds,
  T.sale_date,
  T.activation_date,
  T.deactivation_date,
  T.order_id,
  T.order_type_agg,
  T.cod_segmento,
  T.cod_marca,
  T.cod_tipo_contrato,
  T.cod_producto,
  T.cod_canal,
  T.campaign_code,
  T.serial_number,
  T.tax_base,
  T.claim_code,
  T.process_code,
  T.comments,
  'C_MANUAL' AS facturador,
  T.sociedad,
  CURRENT_TIMESTAMP AS creado,
  CURRENT_TIMESTAMP AS modificado
  FROM(
     SELECT 
     commission_id
      , estado
      ,mes_liquidado
      ,id_mes
      ,agrupacion_canal
      ,canal
      ,concepto
      ,'OTRS'as tipo_concepto
      ,unidades
      ,comision    
      ,id_comisionista
      ,distribuidor
      ,sfid_id
      ,seller
      ,nombre_comercio
      ,razon_social
      ,cif
      ,zona_fiscal
      ,marca
      ,service_type
      ,phone_nm
      ,tariff_id
      ,tariff_ds	
      ,service_id
      ,account_id
      ,customer_id
      ,line_type_ds
      ,bundle_type
      ,technology_ds
      ,billing_type_ds
      ,activation_date as sale_date
      ,activation_date
      ,deactivation_date
      ,order_id
      ,order_type_agg
      ,cod_segmento
      ,cod_marca
      ,cod_tipo_contrato
      ,cod_producto
      ,cod_canal
      ,campaign_code
      ,serial_number
      ,tax_base
      ,claim_code
      ,process_code
      ,comments
      ,facturador
      ,sociedad
      ,creado
      ,modificado
     FROM `mm-commissions-reporting.COMISIONES.transacciones`
     WHERE DATE_TRUNC(activation_date, MONTH) BETWEEN DATE_SUB(PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)), INTERVAL 7 MONTH) AND PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
           AND concepto IN ('B - Centralitas Base','F - Gestion de canal Centralitas Base')
           AND estado = 'facturado'
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.centralitas_activaciones` 
     
     UNION ALL
     
     SELECT *
     FROM `mm-commissions-reporting.TEMP.centralitas_gestion_canal`
     ) T

LEFT JOIN `mm-commissions-reporting.D2D.v_servicio_centralitas` DEACTIVATIONS
         ON T.service_id = DEACTIVATIONS.service_id
            AND T.activation_date = DEACTIVATIONS.activation_date
    
CROSS JOIN UNNEST(canales_pr) canal_pr
    
WHERE DATE_TRUNC(DEACTIVATIONS.deactivation_date, MONTH) = COMISIONES.f_mes_int(id_mes_pr)
      AND DEACTIVATIONS.deactivation_date <= DATE_ADD(COALESCE(T.activation_date,'1969-01-01'), INTERVAL 180 DAY)
      AND T.canal = canal_pr

QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca ORDER BY activation_date DESC) = 1

)
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CND2B', id_mes_pr, canales_pr, 'TEMP.centralitas_activaciones', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CND2F', id_mes_pr, canales_pr, 'TEMP.centralitas_gestion_canal', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('CND2E', id_mes_pr, canales_pr, 'TEMP.centralitas_clawback', 'ACTUALIZAR');


END