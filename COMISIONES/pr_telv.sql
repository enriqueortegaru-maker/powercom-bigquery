BEGIN

DECLARE mes_string, prefijo STRING;

SET mes_string = FORMAT_DATE('%Y%m', mes_pr);

SET prefijo = 'TELV';


IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH','CA', 'GB','ENDE','MP', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU', 'CI' ,'WA', 'ECI', 'EDB', 'EML' ,'ENX', 'EYG','ENK','ENKO','ENXO', 'D2D', 'D2N', 'DEM', 'CIN', 'DON','OUO', 'OUN','OSPNIN','OSPNXSN','OSPNOUN', 'XIN', 'XSN', 'GUUK', 'GUD2D'];
END IF;


/*
CALL COMISIONES.pr_telv(DATE('2026-09-01'),['ENKO']);
CALL COMISIONES.pr_telv(DATE('2026-08-01'),NULL);
*/


---- Tabla de Activaciones ----

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tv_activaciones` AS
SELECT
      prefijo||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_pr AS mes_liquidado
     ,CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64) AS id_mes
     --,`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) AS agrupacion_canal
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,CONCEPTOS.concepto
     ,tipo_concepto
     ,1 AS unidades
     ,CASE  WHEN DEALER.CANAL IN ('OUOP','OUOCC','OSPNOUN','OSPNXSN','XSO') --- MARCOS OUTBOUND PONDERACION --
                  AND TELEVISION.brand_ds IN ('JAZZTEL','SIMYO','ORANGE')
                  AND TLV_CAMP.campaign IN (
                                          --- MR POSPAGO FIJO Y MOVIL RES Y EMPRESA --- 
                                          'COLD CALLING CAPTA SOHO',
                                          'COLD CALLING CARTERA SOHO',
                                          'COLD CALLING CAPTA RES',
                                          'COLD CALLING CAPTA RES T EXTERNOS',
                                          'COLD CALLING CAPTA RES NEW',
                                          'COLD CALLING CAPTACION IA',


                                          --- MR COLD CALLING CONTROLADO SOLO MARCA JAZZTEL ---

                                          'COLD CALLING CONTROLADO CRECIMIENTOS OFFSHORE',
                                          'COLD CALLING CONTROLADO OFFSHORE',
                                          'COLD CALLING CONTROLADO',
                                          'COLD CALLING CONTROLADO TEMPL',
                                          'COLD CALLING CONTROLADO CRECIMIENTOS',
                                          'COLD CALLING CONTROLADO JE ',
                                          'COLD CALLING CONTROLADO PL_EX',

                                          --- MR LINEAS ADICIONALES SOLO MARCA JAZZTEL ---
                                          'LINEAS ADICIONALES',


                                          --- MR XSELLING SOLO MARCA JAZZTEL ---

                                          'CROSS SELLING_MV',
                                          'CROSS SELLING',
                                          'CROSELLING_SEGUNDA RESIDENCIA'
                                          )
                        THEN 
                              CASE WHEN TARIFAS_TV_OSP.COMISION < 1  THEN TARIFAS_TV_OSP.COMISION * UNITARIOS.UNITARIO -- TARIFAS PONDERADAS
                                   WHEN TARIFAS_TV_OSP.COMISION > 1  THEN TARIFAS_TV_OSP.COMISION -- TARIFAS CON UNITARIO
                              END

            WHEN DEALER.CANAL IN ('DO','WA','XI','ALTN','OSPNIN','XSO','OSPNXSN','OUOC','OUOV','OSPNOUN','ENDE','FNAC_NR','MKT_NR','ENKO','ENXO') AND TELEVISION.brand_ds IN ('JAZZTEL','SIMYO','ORANGE') THEN TARIFAS_TV_OSP.COMISION 
            WHEN  DEALER.CANAL = 'DOT' AND TELEVISION.brand_ds = 'SIMYO' THEN 18.00
     ELSE `mm-commissions-reporting.COMISIONES.f_comision_television`
      (
      DEALER.canal,
      TELEVISION.brand_ds, 
      TELEVISION.product_id,
      TELEVISION.product,
      premium = 1,
           ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
      COALESCE(TLV_CAMP.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV')),
      TRUE,
      FALSE
      )
      END AS comision
      --- vendedor ---
     ,DEALER.id_comisionista
     ,COALESCE(distribuidor, DEALER.id_comisionista) AS distribuidor
     
     ,CASE WHEN DEALER.agrupacion_canal = 'Exclusivo' AND LENGTH(DEALER.sfid_id) = 2 THEN seller ELSE DEALER.sfid_id END AS sfid_id

     ,seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,cif
     ,DEALER.zona_fiscal
     ,DEALER.cond_pago
      --- servicio ---
     ,brand_ds AS marca
     ,'TV' AS service_type
     ,CAST(phone_nm AS STRING) AS phone_nm
     ,TELEVISION.product_id AS tariff_id
     ,TELEVISION.product AS tariff_ds
--      ,service_id
     ,COALESCE(service_id,service_tv_id) AS service_id
     ,account_id
     ,customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,technology_ds
     ,'POSTPAID' AS billing_type_ds
     ,order_date AS sale_date
     ,activation_date
     ,deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'006' AS cod_producto
     ,TELEVISION.cod_canal

     ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
     ,COALESCE(TLV_CAMP.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV'))as campaign_code


--      ,CAST(NULL AS STRING)  AS serial_number
     ,TELEVISION.service_tv_id AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad

FROM `mm-commissions-reporting.COMISIONES.v_servicio_television` TELEVISION

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE 
               WHEN TELEVISION.premium = 1  THEN 'PREMIUM' 
               WHEN (TELEVISION.premium = 0 OR TELEVISION.premium IS NULL) THEN 
                 CASE WHEN (TELEVISION.product_id IN ('PACN69','PACN70','PACN72','PACN73','PACN53','PACN25') 
                            OR UPPER(TELEVISION.product) LIKE '%FUTBOL%' 
                            OR UPPER(TELEVISION.product) LIKE '%FÚTBOL%' 
                            OR UPPER(TELEVISION.product) LIKE '%DEPORTE%'
                            OR UPPER(TELEVISION.product) LIKE '%DAZN%'
                           )
                           AND TELEVISION.brand_ds IN ('ORANGE','JAZZTEL','SIMYO')
                             THEN 'DEPORTE'
                      ELSE 'BASE' END
               END = CONCEPTOS.subproceso 
            AND CONCEPTOS.proceso = 'TELV'
            AND CONCEPTOS.TIPO_CONCEPTO = 'SVTV'

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (TELEVISION.sfid_id = DEALER.sfid_id 
            OR (TELEVISION.brand_ds = 'YOIGO' AND SUBSTR(TELEVISION.sfid_id, 1, 2) = DEALER.sfid_id)
             OR (TELEVISION.brand_ds = 'SIMYO' AND TELEVISION.user_store = DEALER.sfid_id)
            OR TELEVISION.seller = DEALER.sfid_id
            OR TELEVISION.sfid_id || '-' || TELEVISION.seller = REPLACE(DEALER.sfid_id, ' ', ''))
            AND CAST (DEALER.id_mes AS STRING) = mes_string


LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign`  TLV_CAMP
         ON DEALER.id_comisionista = TLV_CAMP.id_comisionista AND DEALER.canal = TLV_CAMP.canal

LEFT JOIN `mm-commissions-reporting.COMISIONES.V_TARIFAS_TV` TARIFAS_TV_OSP
ON TARIFAS_TV_OSP.MARCA = TELEVISION.brand_ds
 AND TARIFAS_TV_OSP.PRODUCT_ID = COALESCE(TELEVISION.product_id, TELEVISION.tariff_ds)
 AND TARIFAS_TV_OSP.PRODUCT = TELEVISION.product
 AND TARIFAS_TV_OSP.CANAL = DEALER.CANAL
  AND (
    DEALER.canal NOT IN ('XS','XSO','OUO','OUOP','OUOCC','OSPNOUN','OSPNXSN')
    OR TLV_CAMP.campaign = TARIFAS_TV_OSP.CAMPAIGN
      )
LEFT JOIN `mm-commissions-reporting.GS.UNITARIOS_OUTBOUND` UNITARIOS
          ON DEALER.ID_COMISIONISTA = UNITARIOS.SFID
          AND CAST(UNITARIOS.mes AS STRING) = mes_string 

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             COALESCE(DEALER.agrupacion_canal, TELEVISION.agrupacion_canal) = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(TELEVISION.activation_date, MONTH) = mes_pr
      AND activation_date <= COALESCE(TELEVISION.deactivation_date, '9999-12-31')
      --AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
     --  AND TELEVISION.agrupacion_canal = DEALER.agrupacion_canal  --- 20261023 Ainhoa: comento esta parte porque no cruza con AG NATIONAL RETAIL MIGRACION
      AND (
                  TELEVISION.order_type_agg != 'MIGRACION CONTRATO'
                  OR TELEVISION.order_type_agg IS NULL
            )
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND NOT (
              DEALER.canal IN ('XS')
              AND TELEVISION.brand_ds = 'MASMOVIL'
              AND DEALER.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013','CAROUT033')
              AND CASE
                      WHEN TELEVISION.activation_date < '2024-07-22' --<-- INCLUSION DE NUEVOS SFIDS Y CAMPAÑAS EN TLV CROSS-SELL - JULIO 2024
                      THEN COALESCE(
                                    `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, seller, 'TV')
                                   ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, COALESCE(distribuidor, DEALER.id_comisionista), 'TV')
                                   ,TLV_CAMP.campaign
                                   )
                      
                      ELSE COALESCE(
                                    TLV_CAMP.campaign
                                   ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, seller, 'TV')
                                   ,`mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, COALESCE(distribuidor, DEALER.id_comisionista), 'TV')
                                   )
                  END = 'Lineas adicionales OUT'
              )

          AND NOT (
              DEALER.canal = 'XS'
              AND DEALER.id_comisionista IN ('CAROUT032')
              
              )
        
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, phone_nm, brand_ds, TELEVISION.product ORDER BY activation_date DESC) = 1
AND COALESCE(comision,0) <> 0
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.restriccion_LEGO_television` AS (

WITH activaciones_mes_pr AS (
SELECT 
  TELEVISION.DWH_CUSTOMER_KEY
  ,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)) AS activation_date
  ,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_DEACTIVATION_DAY_KEY AS STRING)) AS deactivation_date

FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_television_cha_orange` TELEVISION

LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tv_channel` TARIFF
    ON TELEVISION.TV_CHANNEL_SERV_KEY = TARIFF.TV_CHANNEL_SERV_KEY

WHERE (
        PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_DEACTIVATION_DAY_KEY AS STRING)) = '9999-12-31'
      OR
        PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_DEACTIVATION_DAY_KEY AS STRING)) >= DATE_SUB(DATE_TRUNC(mes_pr, MONTH), INTERVAL 3 MONTH)
      )
AND DATE_TRUNC(PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)), MONTH) = mes_pr
AND TARIFF.TV_CHANNEL_SERV_ID IN ('PACN37','PACN41','PACN69','PACN70','11841','13220','PACN72','13827','PACN73','PACN66','PACN48','PACN71')
GROUP BY DWH_CUSTOMER_KEY,TVCH_ACTIVATION_DAY_KEY,TVCH_DEACTIVATION_DAY_KEY,TV_CHAN_ORDER_ID
ORDER BY DWH_CUSTOMER_KEY DESC 
),


desactivaciones AS (
SELECT 
  TELEVISION.DWH_CUSTOMER_KEY
  ,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)) AS activation_date
  ,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_DEACTIVATION_DAY_KEY AS STRING)) AS deactivation_date

FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_television_cha_orange` TELEVISION

LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tv_channel` TARIFF
    ON TELEVISION.TV_CHANNEL_SERV_KEY = TARIFF.TV_CHANNEL_SERV_KEY

LEFT JOIN activaciones_mes_pr ACTIVACIONES
    ON PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)) = ACTIVACIONES.activation_date

WHERE PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_DEACTIVATION_DAY_KEY AS STRING)) != '9999-12-31'
AND PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)) != '9999-12-31' 
AND DATE_TRUNC(PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)), MONTH) <= mes_pr
AND TARIFF.TV_CHANNEL_SERV_ID IN ('PACN37','PACN41','PACN69','PACN70','11841','13220','PACN72','13827','PACN73','PACN66','PACN48','PACN71')
AND ACTIVACIONES.activation_date IS NULL
GROUP BY DWH_CUSTOMER_KEY,TVCH_ACTIVATION_DAY_KEY,TVCH_DEACTIVATION_DAY_KEY,TV_CHAN_ORDER_ID
QUALIFY ROW_NUMBER() OVER( PARTITION BY DWH_CUSTOMER_KEY ORDER BY TVCH_ACTIVATION_DAY_KEY DESC) = 1
ORDER BY DWH_CUSTOMER_KEY DESC 
),


Comisiona AS (
SELECT 
  DESACTIVACIONES.*
  ,TV_DES.TV_CHANNEL_SERV_ID AS tariff_id_desact
  ,TV_DES.TV_CHANNEL_SERV_DES AS tariff_ds_desact
  ,TV_ACT.TV_CHANNEL_SERV_ID AS tariff_id_act
  ,TV_ACT.TV_CHANNEL_SERV_DES AS tariff_ds_act
  ,CASE
       WHEN TV_ACT.TV_CHANNEL_SERV_ID = 'PACN71' AND TV_DES.TV_CHANNEL_SERV_ID IN ('PACN48','PACN71')          THEN 'NO' -- TV 90 canales
       WHEN TV_ACT.TV_CHANNEL_SERV_ID = 'PACN72' AND TV_DES.TV_CHANNEL_SERV_ID IN ('13827','PACN72')           THEN 'NO' -- DAZN Motor
       WHEN TV_ACT.TV_CHANNEL_SERV_ID = 'PACN73' AND TV_DES.TV_CHANNEL_SERV_ID IN ('PACN66','PACN73')          THEN 'NO' -- DAZN Baloncesto
       WHEN TV_ACT.TV_CHANNEL_SERV_ID = 'PACN70' AND TV_DES.TV_CHANNEL_SERV_ID IN ('11841','13220','PACN70')   THEN 'NO' -- Todo Deporte
       WHEN TV_ACT.TV_CHANNEL_SERV_ID = 'PACN69' AND TV_DES.TV_CHANNEL_SERV_ID IN ('PACN41','PACN37','PACN69') THEN 'NO' -- Todo Fútbol
       ELSE 'SI'
   END AS Comisiona

FROM activaciones_mes_pr ACTIVACIONES

INNER JOIN desactivaciones DESACTIVACIONES
    ON ACTIVACIONES.DWH_CUSTOMER_KEY = DESACTIVACIONES.DWH_CUSTOMER_KEY

LEFT JOIN (SELECT DWH_CUSTOMER_KEY,TV_CHANNEL_SERV_ID,TV_CHANNEL_SERV_DES,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)) AS activation_date,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_DEACTIVATION_DAY_KEY AS STRING)) AS deactivation_date
          FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_television_cha_orange` TELEVISION

          LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tv_channel` TARIFF
              ON TELEVISION.TV_CHANNEL_SERV_KEY = TARIFF.TV_CHANNEL_SERV_KEY
          
          WHERE TARIFF.TV_CHANNEL_SERV_ID IN ('PACN37','PACN41','PACN69','PACN70','11841','13220','PACN72','13827','PACN73','PACN66','PACN48','PACN71')
          ) TV_ACT
    ON ACTIVACIONES.DWH_CUSTOMER_KEY = TV_ACT.DWH_CUSTOMER_KEY
    AND ACTIVACIONES.activation_date = TV_ACT.activation_date
    
LEFT JOIN (SELECT DWH_CUSTOMER_KEY,TV_CHANNEL_SERV_ID,TV_CHANNEL_SERV_DES,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_ACTIVATION_DAY_KEY AS STRING)) AS activation_date,PARSE_DATE('%Y%m%d',CAST(TELEVISION.TVCH_DEACTIVATION_DAY_KEY AS STRING)) AS deactivation_date
          FROM `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_television_cha_orange` TELEVISION

          LEFT JOIN `mm-datamart-kd.00_SANDBOX_DWH_ORANGE.osp_maestro_tv_channel` TARIFF
              ON TELEVISION.TV_CHANNEL_SERV_KEY = TARIFF.TV_CHANNEL_SERV_KEY
          
          WHERE TARIFF.TV_CHANNEL_SERV_ID IN ('PACN37','PACN41','PACN69','PACN70','11841','13220','PACN72','13827','PACN73','PACN66','PACN48','PACN71')
          ) TV_DES    
    ON DESACTIVACIONES.DWH_CUSTOMER_KEY = TV_DES.DWH_CUSTOMER_KEY
    AND DESACTIVACIONES.activation_date = TV_DES.activation_date
ORDER BY DWH_CUSTOMER_KEY
)


SELECT 
  B.* 
  ,A.tariff_id_act
  ,A.tariff_ds_act
  ,A.activation_date AS activation_date_prev
  ,A.deactivation_date AS deactivation_date_prev
  ,A.tariff_id_desact
  ,A.tariff_ds_desact
  ,A.Comisiona

FROM Comisiona A

INNER JOIN activaciones_mes_pr B
    ON A.DWH_CUSTOMER_KEY = B.DWH_CUSTOMER_KEY

WHERE A.Comisiona = 'NO'
AND (
     A.tariff_id_act IN ('PACN71','PACN72','PACN73') AND A.deactivation_date BETWEEN DATE_SUB(B.activation_date, INTERVAL 30 DAY) AND B.activation_date
    OR
     A.tariff_id_act IN ('PACN69','PACN70') AND A.deactivation_date BETWEEN DATE_SUB(B.activation_date, INTERVAL 90 DAY) AND B.activation_date
    )
)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tv_activaciones_final` AS (

SELECT ACTIVACIONES.*

FROM `mm-commissions-reporting.TEMP.tv_activaciones` ACTIVACIONES

LEFT JOIN `mm-commissions-reporting.TEMP.restriccion_LEGO_television` RESTRICCION
     ON ACTIVACIONES.customer_id = CAST(RESTRICCION.DWH_CUSTOMER_KEY AS STRING)
     AND ACTIVACIONES.activation_date = RESTRICCION.activation_date
     AND ACTIVACIONES.tariff_id = RESTRICCION.tariff_id_act


WHERE RESTRICCION.DWH_CUSTOMER_KEY IS NULL
)
;


ASSERT NOT EXISTS
(
SELECT service_id, phone_nm, marca, tariff_ds
FROM `mm-commissions-reporting.TEMP.tv_activaciones_final`
GROUP BY marca, concepto, service_id, phone_nm, tariff_ds
HAVING COUNT(1) > 1
);


--- FACTOR SEGMENTACIÓN LIGA (SOLO D2D)

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('D2D','D2N','DEM')) THEN
UPDATE `mm-commissions-reporting.TEMP.tv_activaciones_final` v
SET comision = v.comision * f.porcentaje
FROM `mm-commissions-reporting.GS.gs_segmento_liga` f
WHERE v.cif = f.cif
  AND f.id_mes = CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64)
  AND v.activation_date >= '2026-07-01'
  AND v.estado = 'calculado'
  AND v.canal IN ('D2D','D2N','DEM');
END IF;


---- Tabla de Gestion de Canal ----

SET prefijo = 'TVGC';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tv_gestion_canal` AS
SELECT
      prefijo||'_'||mes_string||'_'||canal_pr||'_'||ROW_NUMBER () OVER () AS commission_id
     ,'calculado' AS estado
     ,mes_pr AS mes_liquidado
     ,CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64) AS id_mes
     --,`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) AS agrupacion_canal
     ,DEALER.agrupacion_canal
     ,DEALER.canal
     ,REPLACE(concepto, 'B -', 'F -') AS concepto
     ,tipo_concepto
     ,1 AS unidades
     ,CASE WHEN DEALER.CANAL = 'ALTN' AND TARIFAS_TV_OSP.COMISION >0 THEN 2.00 
           WHEN DEALER.CANAL = 'DOT' AND TELEVISION.brand_ds = 'SIMYO' THEN 18.00
     ELSE
     
      `mm-commissions-reporting.COMISIONES.f_comision_television`
      (
      DEALER.canal,
      TELEVISION.brand_ds, 
      TELEVISION.product_id,
      TELEVISION.product,
      premium = 1,
           ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
      COALESCE(TLV_CAMP.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV')),
      FALSE,
      TRUE
      ) END AS comision
      --- vendedor ---
     ,COALESCE(MASTER.id_comisionista, DEALER.id_comisionista) AS id_comisionista
     ,COALESCE(distribuidor, DEALER.id_comisionista) AS distribuidor
     
     ,CASE WHEN DEALER.agrupacion_canal = 'Exclusivo' AND LENGTH(DEALER.sfid_id) = 2 THEN seller ELSE DEALER.sfid_id END AS sfid_id
     
     ,seller
     ,COALESCE(MASTER.nombre_comercio, DEALER.nombre_comercio) AS nombre_comercio
     ,COALESCE(MASTER.razon_social, DEALER.razon_social) AS razon_social
     ,COALESCE(MASTER.documento, DEALER.cif) AS cif
     ,COALESCE(MASTER.zona_fiscal, DEALER.zona_fiscal) AS zona_fiscal
     ,DEALER.cond_pago
      --- servicio ---
     ,brand_ds AS marca
     ,'TV' AS service_type
     ,CAST(phone_nm AS STRING) AS phone_nm
     ,TELEVISION.product_id AS tariff_id
     ,TELEVISION.product AS tariff_ds
--      ,service_id
     ,COALESCE(service_id,service_tv_id) AS service_id
     ,account_id
     ,customer_id
     ,CAST(NULL AS STRING) AS line_type_ds
     ,CAST(NULL AS STRING) AS bundle_type
     ,technology_ds
     ,'POSTPAID' AS billing_type_ds
     ,order_date AS sale_date
     ,activation_date
     ,deactivation_date
     ,CAST(order_id AS STRING) AS order_id
     ,CAST(NULL AS STRING) AS order_type_agg
      --- variables analiticas ---
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_segmento`(segment_ds, brand_ds) AS cod_segmento
     ,`mm-commissions-reporting.COMISIONES.f_ventas_base_net_cod_marca`(brand_ds) AS cod_marca
     ,'99' AS cod_tipo_contrato
     ,'006' AS cod_producto
     ,TELEVISION.cod_canal

          ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
     ,COALESCE(TLV_CAMP.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(DEALER.canal, TELEVISION.brand_ds, TELEVISION.sfid_id, 'TV')) as campaign_code
              
--      ,CAST(NULL AS STRING)  AS serial_number
     ,TELEVISION.service_tv_id AS serial_number
     ,CAST(NULL AS FLOAT64) AS tax_base
     ,CAST(NULL AS STRING)  AS claim_code
     ,CAST(NULL AS STRING)  AS process_code
     ,CAST(NULL AS STRING)  AS comments
      --- informacion contabilizacion ---
     ,'C_MANUAL' AS facturador

     ,`mm-commissions-reporting.COMISIONES.f_sociedad`(brand_ds) AS sociedad

FROM `mm-commissions-reporting.COMISIONES.v_servicio_television` TELEVISION

INNER JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS
          ON CASE WHEN TELEVISION.premium = 1 THEN 'PREMIUM' ELSE 'BASE' END = CONCEPTOS.subproceso AND CONCEPTOS.proceso = 'TELV'

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer` DEALER
         ON (TELEVISION.sfid_id = DEALER.sfid_id 
            OR (TELEVISION.brand_ds = 'YOIGO' AND SUBSTR(TELEVISION.sfid_id, 1, 2) = DEALER.sfid_id)
            OR TELEVISION.seller = DEALER.sfid_id
            OR TELEVISION.sfid_id || '-' || TELEVISION.seller = REPLACE(DEALER.sfid_id, ' ', ''))
            AND CAST(DEALER.id_mes AS STRING) = mes_string

LEFT JOIN `mm-commissions-reporting.GS.no_exclusivo_acceso_trazabilidad` MASTER
         ON DEALER.distribuidor = MASTER.id_comisionista

-- LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` TLV_CAMP
         ON DEALER.id_comisionista = TLV_CAMP.id_comisionista AND DEALER.canal = TLV_CAMP.canal

INNER JOIN `mm-commissions-reporting.GS.CANALES` CHANNEL
          ON --`mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = CHANNEL.agrupacion_canal
             TELEVISION.agrupacion_canal = CHANNEL.agrupacion_canal
             AND DEALER.canal = CHANNEL.canal

INNER JOIN (SELECT DISTINCT gc from `mm-commissions-reporting.GS.CONCEPTOS`, UNNEST(SPLIT(gestion_canal, ',')) gc) GESTION_CANAL
           ON DEALER.canal = GESTION_CANAL.gc

LEFT JOIN `mm-commissions-reporting.COMISIONES.V_TARIFAS_TV` TARIFAS_TV_OSP
ON TARIFAS_TV_OSP.MARCA = TELEVISION.brand_ds
 AND TARIFAS_TV_OSP.PRODUCT_ID = COALESCE(TELEVISION.product_id, TELEVISION.tariff_ds)
 AND TARIFAS_TV_OSP.PRODUCT = TELEVISION.product
 AND TARIFAS_TV_OSP.CANAL = DEALER.CANAL

CROSS JOIN UNNEST(canales_pr) AS canal_pr

WHERE DATE_TRUNC(TELEVISION.activation_date, MONTH) = mes_pr
      AND activation_date <= COALESCE(TELEVISION.deactivation_date, '9999-12-31')
      --AND `mm-commissions-reporting.COMISIONES.f_clasificacion_canales`(channel_segment_ds, channel_ds, subchannel_ds) = DEALER.agrupacion_canal
      AND TELEVISION.agrupacion_canal = DEALER.agrupacion_canal
      AND (
                  TELEVISION.order_type_agg != 'MIGRACION CONTRATO'
                  OR TELEVISION.order_type_agg IS NULL
            )
      AND TELEVISION.agrupacion_canal != 'Exclusivo'
      AND DEALER.canal = canal_pr
      AND DEALER.comisiona
      AND ((DEALER.agrupacion_canal = 'No Exclusivo' AND MASTER.id_comisionista IS NOT NULL) OR DEALER.agrupacion_canal <> 'No Exclusivo')
      AND NOT (
            DEALER.canal = 'WA'
            AND DEALER.id_comisionista IN ('RONL004', 'RONL025', 'RONL050', 'MW','3W')
            )
      AND NOT (
            DEALER.canal = 'OU'
            AND DEALER.id_comisionista IN ('TLVOU009', 'TLVOU022')
            )
      AND NOT (
            DEALER.canal = 'DO'
            AND DEALER.id_comisionista IN ('DONL003', 'NE')
            )
        
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, brand_ds ORDER BY activation_date DESC) = 1
;


ASSERT NOT EXISTS
(
SELECT service_id, phone_nm, marca, tariff_ds
FROM `mm-commissions-reporting.TEMP.tv_activaciones_final`
GROUP BY service_id, phone_nm, marca, tariff_ds
HAVING COUNT(1) > 1
);


---- Tabla de Clawback ----

SET prefijo = 'TVCB';

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.tv_clawback` AS
SELECT
      TRANSACCIONES.* EXCEPT(concepto, comision, commission_id, estado, mes_liquidado, deactivation_date, bundle_type, cod_producto, facturador, campaign_code, comments, id_mes, id_comisionista, distribuidor, sfid_id, seller, nombre_comercio, razon_social, cif, zona_fiscal)
     ,prefijo||'_'||mes_string||'_'||TRANSACCIONES.canal||'_'||ROW_NUMBER () OVER () AS commission_id
     ,`mm-commissions-reporting.COMISIONES.f_comision_clawback`(DATE_DIFF(VENTAS.deactivation_date, TRANSACCIONES.activation_date, DAY), TRANSACCIONES.canal, TRANSACCIONES.tariff_ds) * TRANSACCIONES.comision AS comision

     ,CASE 
      --      WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto NOT LIKE '%Premium%'     THEN 'H - Clawback Television'
      --      WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto LIKE '%Premium%'         THEN 'H - Clawback Television Premium'
           WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) IN ('F', 'S', 'Y')      THEN REPLACE(TRANSACCIONES.concepto, 'B - ','H - Clawback ')
      --      WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto NOT LIKE '%Premium%' THEN 'E - Clawback Television'
      --      WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('F', 'S', 'Y')  AND TRANSACCIONES.concepto LIKE '%Premium%'     THEN 'E - Clawback Television Premium'
           WHEN SUBSTR(TRANSACCIONES.concepto, 1, 1) NOT IN ('F', 'S', 'Y')  THEN REPLACE(TRANSACCIONES.concepto, 'B - ','E - Clawback ')

      END AS concepto

     ,'calculado' AS estado
     ,mes_pr AS mes_liquidado
     ,CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64) AS id_mes
     ,VENTAS.deactivation_date

     ,CASE WHEN VENTAS.bundle_type = 'DESC' THEN 'FMC' ELSE VENTAS.bundle_type END AS bundle_type
     ,'006' AS cod_producto

     ,'C_MANUAL' AS facturador

      ---- AÑADIMOS CAMPAIGN CODE PARA XSELL 202601 ---
     ,COALESCE(TLV_CAMP.campaign, `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(TRANSACCIONES.canal, TRANSACCIONES.marca, TRANSACCIONES.sfid_id, 'TV')) as campaign_code

     ,'Factura cargo retrotraído en un '|| REPLACE(CAST(-100 * `mm-commissions-reporting.COMISIONES.f_comision_clawback`
     (DATE_DIFF(VENTAS.deactivation_date, TRANSACCIONES.activation_date, DAY), TRANSACCIONES.canal, TRANSACCIONES.tariff_ds) AS STRING), '.', '') || '%: ' || TRANSACCIONES.invoice_id AS comments

     ,DEALER.id_comisionista
     ,COALESCE(DEALER.distribuidor, DEALER.id_comisionista) AS distribuidor
     ,DEALER.sfid_id
     ,DEALER.id_comisionista AS seller
     ,DEALER.nombre_comercio
     ,DEALER.razon_social
     ,DEALER.cif
     ,DEALER.zona_fiscal

FROM (
     SELECT
           * 
          ,1 AS rank

     FROM (
          SELECT
                * EXCEPT(comision)
               ,SUM(comision) OVER (PARTITION BY service_id, marca) AS comision
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE service_type IN ('TV')
                AND SUBSTR(concepto,1,1) NOT IN ('F', 'H', 'S', 'Y','C')
                AND concepto NOT LIKE ('%Acelerador%')
                AND concepto NOT LIKE ('%Multiplicador%')
                AND concepto NOT LIKE ('%Camp%')
                AND concepto NOT LIKE ('%estion%')
                AND estado = 'facturado'
          )
     WHERE comision > 0
     QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca ORDER BY concepto ASC) = 1

     UNION ALL

     SELECT
           *
          ,1 AS rank
     FROM (
          SELECT
                * EXCEPT(comision)
               ,SUM(comision) OVER (PARTITION BY service_id, marca) AS comision
          FROM `mm-commissions-reporting.COMISIONES.transacciones`
          WHERE service_type IN ('TV')
                AND (SUBSTR(concepto,1,1) IN ('F', 'H', 'S', 'Y') OR concepto LIKE ('%estion%'))
                AND concepto NOT LIKE ('%Acelerador%')
                AND concepto NOT LIKE ('%Multiplicador%')
                AND concepto NOT LIKE ('%GPV%')
                AND estado = 'facturado'
                AND agrupacion_canal != ' Exclusivo'
          )
     WHERE comision > 0
     QUALIFY RANK() OVER (PARTITION BY service_id, marca ORDER BY concepto ASC) = 1

     UNION ALL

     SELECT
           * EXCEPT(comision, sociedad)
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
          ,CAST(NULL AS STRING) AS bp
          ,CAST(NULL AS STRING) AS cuenta_contable
          ,CAST(NULL AS STRING) AS centro_coste
          ,CAST(NULL AS STRING) AS documento_sap
          ,CAST(NULL AS STRING) AS documento_sap_posicion
          ,CAST(NULL AS STRING) AS fecha_contabilizacion
          ,CAST(NULL AS TIMESTAMP) AS creado
          ,CAST(NULL AS TIMESTAMP) AS modificado
          ,CAST(NULL AS STRING) AS id_factura_drive
          ,NULL AS emails_acceso_trazabilidad
          ,comision
          ,2 AS rank

     FROM `mm-commissions-reporting.TEMP.tv_activaciones_final`
     
     WHERE DATE_TRUNC(COALESCE(deactivation_date, '9999-12-31'), MONTH) = mes_pr

     UNION ALL

     SELECT
           * EXCEPT(comision, sociedad)
          ,CAST(NULL AS STRING) AS proceso_sap
          ,CAST(NULL AS STRING) AS id_registro
          ,CAST(NULL AS STRING) AS invoice_id
          ,sociedad
          ,CAST(NULL AS STRING) AS bp
          ,CAST(NULL AS STRING) AS cuenta_contable
          ,CAST(NULL AS STRING) AS centro_coste
          ,CAST(NULL AS STRING) AS documento_sap
          ,CAST(NULL AS STRING) AS documento_sap_posicion
          ,CAST(NULL AS STRING) AS fecha_contabilizacion
          ,CAST(NULL AS TIMESTAMP) AS creado
          ,CAST(NULL AS TIMESTAMP) AS modificado
          ,CAST(NULL AS STRING) AS id_factura_drive
          ,NULL AS emails_acceso_trazabilidad
          ,comision
          ,2 AS rank

     FROM `mm-commissions-reporting.TEMP.tv_gestion_canal`
     
     WHERE DATE_TRUNC(COALESCE(deactivation_date, '9999-12-31'), MONTH) = mes_pr

     ) TRANSACCIONES

INNER JOIN `mm-commissions-reporting.COMISIONES.v_servicio_television` VENTAS
          ON TRANSACCIONES.service_id = VENTAS.service_id AND TRANSACCIONES.marca = VENTAS.brand_ds

-- LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
LEFT JOIN `mm-commissions-reporting.COMISIONES.tlv_dealers_campaign` TLV_CAMP
         ON TRANSACCIONES.id_comisionista = TLV_CAMP.id_comisionista AND TRANSACCIONES.canal = TLV_CAMP.canal

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
         ON TRANSACCIONES.id_comisionista = DEALER.id_comisionista

CROSS JOIN UNNEST(canales_pr) canal_pr

WHERE DATE_TRUNC(COALESCE(VENTAS.deactivation_date, '9999-12-31'), MONTH) = mes_pr
      AND TRANSACCIONES.activation_date <= VENTAS.deactivation_date
      AND TRANSACCIONES.canal = canal_pr
      AND DEALER.comisiona
      AND `mm-commissions-reporting.COMISIONES.f_comision_clawback`(DATE_DIFF(VENTAS.deactivation_date, TRANSACCIONES.activation_date, day), TRANSACCIONES.canal, TRANSACCIONES.tariff_ds) * TRANSACCIONES.comision != 0
      AND NOT (
            TRANSACCIONES.canal IN ('XS')
            AND TRANSACCIONES.marca = 'MASMOVIL'
            AND TRANSACCIONES.id_comisionista IN ('CAROUT006', 'CAROUT010', 'CAROUT013')
            AND TRANSACCIONES.campaign_code = 'Lineas adicionales OUT'
            )
      AND NOT (
            TRANSACCIONES.canal = 'WA'
            AND TRANSACCIONES.id_comisionista IN ('RONL004', 'RONL025', 'RONL050', 'MW','3W')
            )
      AND NOT (
            TRANSACCIONES.canal = 'OU'
            AND TRANSACCIONES.id_comisionista IN ('TLVOU009', 'TLVOU022')
            )
      AND NOT (
            TRANSACCIONES.canal = 'DO'
            AND TRANSACCIONES.id_comisionista IN ('DONL003', 'NE')
            )
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_id, marca, concepto ORDER BY rank ASC) = 1
;


ASSERT NOT EXISTS
(
SELECT service_id, phone_nm, marca, tariff_ds
FROM `mm-commissions-reporting.TEMP.tv_activaciones_final`
GROUP BY service_id, phone_nm, marca, tariff_ds
HAVING COUNT(1) > 1
);


--- ELIMINAR CLAWBACKS ANTERIORES A MIGRACIONES DE THADEA A POWERCOM
DELETE FROM `mm-commissions-reporting.TEMP.tv_clawback` CBSR
WHERE 
     -- TLV - DO Migrado en Marzo26 --
     (
     CANAL IN ('DO','DOT') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-03-01'
     )
     OR
     -- TLV - Cross-sell + TLV - Web Capta Migrado en Mayo --
     (
     CANAL IN ('WA','BO','XI','XIBO') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-05-01'
     )
     OR
     -- TLV - Negocios INB Migrado en Junio26 --
     (
     CANAL IN ('OSPNIN') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-06-01'
     )
     OR
     -- Alternativo Migrado en Febrero26 --
     (
     CANAL IN ('ALTN') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-02-01'
     )
     OR
     -- TLV - Negocios OUT Migrado en sept 2026 (SÓLO CAMPAÑAS MULTIPRODUCTO Y XSELLING ORANGE)
     (
     CANAL IN ('OSPNXSN') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND campaign_code IN ('XSELLING ORANGE','MULTIPRODUCTO GENERICA','MULTIPRODUCTO TERMINAL')
     AND activation_date < '2026-09-01'
     )
     OR
     -- TLV - Cross-sell OUT Migrado en sept 2026 (SÓLO CAMPAÑAS MULTIPRODUCTO Y XSELLING ORANGE)
     (
     CANAL IN ('XSO') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND campaign_code IN ('XSELLING ORANGE','MULTIPRODUCTO GENERICA','MULTIPRODUCTO TERMINAL')
     AND activation_date < '2026-09-01'
     )
     OR
     -- NATIONAL RETAIL
     (
     CANAL IN ('FNAC_NR','MKT_NR') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-09-01'
     )
     OR
     -- EXCLUSIVO MULTIBRAND
     (
     CANAL IN ('ENKO','ENXO') 
     AND MARCA IN ('ORANGE','JAZZTEL','SIMYO') 
     AND activation_date < '2026-07-20'
     )

;
-- --- Insertar tabla final ----
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('TELV_', CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64), canales_pr, 'TEMP.tv_activaciones_final', 'ACTUALIZAR');
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('TVGC_', CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64), canales_pr, 'TEMP.tv_gestion_canal', 'ACTUALIZAR');--
CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones`('TVCB_', CAST(FORMAT_DATE('%Y%m', mes_pr) AS INT64), canales_pr, 'TEMP.tv_clawback', 'ACTUALIZAR');


END