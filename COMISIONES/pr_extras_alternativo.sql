BEGIN

DECLARE prefijo, mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);

SET prefijo = 'EALT';

SET canales_pr = COALESCE(canales_pr, ['ALTN','PH']);


/*
CALL COMISIONES.pr_extras_alternativo(202606, ['ALTN']);
*/


DROP TABLE TEMP.extracomisiones_alternativo;


CREATE TABLE IF NOT EXISTS `mm-commissions-reporting.TEMP.extracomisiones_alternativo`
(
 mes_liquidado               DATE
,id_mes                      INT64
,agrupacion_canal            STRING
,canal                       STRING
,unidades                    INT64
,id_comisionista             STRING
,distribuidor                STRING
,sfid_id                     STRING
,seller                      STRING
,nombre_comercio             STRING
,razon_social                STRING
,cif                         STRING
,zona_fiscal                 STRING
,cond_pago                   STRING
,marca                       STRING
,service_type                STRING
,phone_nm                    STRING
,tariff_id                   STRING
,tariff_ds                   STRING
,service_id                  STRING
,account_id                  STRING
,customer_id                 STRING
,line_type_ds                STRING
,bundle_type                 STRING
,technology_ds               STRING
,billing_type_ds             STRING
,sale_date                   DATE
,activation_date             DATE
,deactivation_date           DATE
,order_id                    STRING
,order_type_agg              STRING
,cod_segmento                STRING
,cod_marca                   STRING
,cod_canal                   STRING
,campaign_code               STRING
,serial_number               STRING
,tax_base                    FLOAT64
,claim_code                  STRING
,process_code                STRING
,proceso_sap                 STRING
,id_registro                 STRING
,invoice_id                  STRING
,sociedad                    STRING
,bp                          STRING
,cuenta_contable             STRING
,centro_coste                STRING
,documento_sap               STRING
,documento_sap_posicion      STRING
,fecha_contabilizacion       STRING
,creado                      TIMESTAMP
,modificado                  TIMESTAMP
,id_factura_drive            STRING
,emails_acceso_trazabilidad  ARRAY<STRING>
,estado                      STRING
,concepto                    STRING
,tipo_concepto               STRING
,facturador                  STRING
,comments                    STRING
,comision                    FLOAT64
,cod_producto                STRING
,cod_tipo_contrato           STRING

)
;


--- BLINDAJE PANZER ---- 

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ALTN','ALTNC','ALTNH')) THEN

INSERT INTO TEMP.extracomisiones_alternativo 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision,cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo'           THEN 16
          WHEN TRANSACCIONES.concepto = 'A - Servicio Movil Pospago'  THEN 5
      END AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato



FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON TRANSACCIONES.service_id = VENTAS.service_id
 AND TRANSACCIONES.phone_nm = VENTAS.phone_nm
 AND TRANSACCIONES.customer_id = VENTAS.customer_id

LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
     ON TRANSACCIONES.sfid_id = OPTICO.sfid 
     OR TRANSACCIONES.seller = OPTICO.sfid 
     OR TRANSACCIONES.id_comisionista = OPTICO.SFID 
     OR VENTAS.user_store = OPTICO.SFID
     


CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      -- AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN UNNEST(canales_pr)
      AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
      AND CONCEPTOS.concepto = 'D - Blindaje "Panzer"'
      AND UPPER(OPTICO.panzer) IN ('PANZER','SUPREME')

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id, TRANSACCIONES.id_comisionista ORDER BY TRANSACCIONES.sale_date DESC) = 1)

;
END IF;

--- INCENTIVO PH JUNIO Y JULIO 2026 --- COM-686

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('PH')) THEN

INSERT INTO TEMP.extracomisiones_alternativo 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision,cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,6.30 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato



FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN UNNEST(canales_pr)
      AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
      AND CONCEPTOS.concepto = 'D - Incentivo Activacion'
      AND TRANSACCIONES.cod_segmento = '10'
      AND TRANSACCIONES.id_mes BETWEEN 202606 AND 202607

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id, TRANSACCIONES.id_comisionista ORDER BY TRANSACCIONES.sale_date DESC) = 1)

;
END IF;

--- PAGO SUPREME ---

IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ALTN','ALTNC','ALTNH')) THEN

INSERT INTO TEMP.extracomisiones_alternativo 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision,cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CONCEPTOS.concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,350/CONTEO.UNIDADES AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato



FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
ON TRANSACCIONES.service_id = VENTAS.service_id
 AND TRANSACCIONES.phone_nm = VENTAS.phone_nm
 AND TRANSACCIONES.customer_id = VENTAS.customer_id

LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
     ON TRANSACCIONES.sfid_id = OPTICO.sfid 
     OR TRANSACCIONES.seller = OPTICO.sfid 
     OR TRANSACCIONES.id_comisionista = OPTICO.SFID 
     OR VENTAS.user_store = OPTICO.SFID

LEFT JOIN ( SELECT OPTICO.sfid_unico, COUNT(DISTINCT TRANSACCIONES.service_id) AS UNIDADES
            FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

            LEFT JOIN `mm-commissions-reporting.COMISIONES.ventas_comisiones` VENTAS
            ON TRANSACCIONES.service_id = VENTAS.service_id
            AND TRANSACCIONES.phone_nm = VENTAS.phone_nm
            AND TRANSACCIONES.customer_id = VENTAS.customer_id

            LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
            ON TRANSACCIONES.sfid_id = OPTICO.sfid 
            OR TRANSACCIONES.seller = OPTICO.sfid 
            OR TRANSACCIONES.id_comisionista = OPTICO.SFID 
            OR VENTAS.user_store = OPTICO.SFID
            


            CROSS JOIN UNNEST(canales_pr) canal_pr

            WHERE TRANSACCIONES.id_mes = id_mes_pr
                  AND TRANSACCIONES.canal = canal_pr
                  AND TRANSACCIONES.estado IN ('calculado', 'validado')
                  AND TRANSACCIONES.canal IN UNNEST(canales_pr)
                  AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
                  AND UPPER(OPTICO.panzer) = 'SUPREME'

            GROUP BY ALL) CONTEO
            ON CONTEO.sfid_unico = OPTICO.sfid_unico



CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = canal_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN UNNEST(canales_pr)
      AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'A - Servicio Movil Pospago')
      AND CONCEPTOS.concepto = 'D - Imagen Supreme'
      AND UPPER(OPTICO.panzer) = 'SUPREME'

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id, TRANSACCIONES.id_comisionista ORDER BY TRANSACCIONES.sale_date DESC) = 1)

;
END IF;

---- EXTRACOMISION SOHO ----
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ALTN','ALTNC','ALTNH','PH')) THEN

INSERT INTO TEMP.extracomisiones_alternativo 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision,cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     ,CASE
          WHEN TRANSACCIONES.concepto = 'A - Servicio Fijo'           THEN 'A - Extra SOHO'
          WHEN TRANSACCIONES.concepto = 'F - Servicio Fijo'           THEN 'F - Extra SOHO'
      END AS concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,CASE
          WHEN CANAL IN ('ALTN','ALTNC','ALTNH') AND TRANSACCIONES.concepto = 'A - Servicio Fijo'           THEN 15
          WHEN CANAL IN ('PH')                   AND TRANSACCIONES.concepto = 'A - Servicio Fijo'           THEN 20
          WHEN CANAL IN ('ALTN','ALTNC','ALTNH') AND TRANSACCIONES.concepto = 'F - Servicio Fijo'           THEN 5
      END AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato



FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES


CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.canal IN UNNEST(canales_pr)
      AND TRANSACCIONES.concepto IN ('A - Servicio Fijo', 'F - Servicio Fijo')
      AND TRANSACCIONES.cod_segmento = '12'
      AND CONCEPTOS.concepto IN ('A - Extra SOHO','F - Extra SOHO')
      
      -- En PH sólo ventas Masmovil 
      AND ((TRANSACCIONES.canal IN ('ALTN','ALTNC','ALTNH')) OR (TRANSACCIONES.canal = 'PH' AND TRANSACCIONES.marca = 'MASMOVIL'))


QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.phone_nm, TRANSACCIONES.id_comisionista ORDER BY TRANSACCIONES.sale_date DESC) = 1)
;
END IF;



---- EXTRACOMISION SOHO 2025 ----
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ALTN','ALTNC','ALTNH')) THEN


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.extra_soho_alternativo_base` AS (
SELECT  
    CAST (FORMAT_DATE('%Y%m', DATE(T.sale_date)) AS INT64) AS ID_MES,
    ID_PDV.sfid_digo,
    PDV.objetivo,
    ROW_NUMBER() OVER (PARTITION BY ID_PDV.SFID_DIGO, CAST (FORMAT_DATE('%Y%m', DATE(T.sale_date)) AS INT64) ORDER BY t.activation_date) AS orden_activacion,
    T.*

 FROM `mm-commissions-reporting.COMISIONES.ventas_comisiones` T

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version`  b 
  ON ( T.sfid_id = b.sfid_id 
  or (T.seller_formato_tms = b.sfid_id AND T.agrupacion_canal NOT IN ('No Exclusivo'))
  or T.seller = b.sfid_id
  or T.sfid_id    || '-' || T.seller = replace ( b.sfid_id , ' ', '') )

LEFT JOIN `mm-commissions-reporting.GS.DIS_digo_unico` ID_PDV
  ON T.sfid_id  = ID_PDV.sfid_id

INNER JOIN `mm-commissions-reporting.GS.ALTERNATIVO_EXTRACOMISION_SOHO_PDV` PDV 
  ON ID_PDV.sfid_digo = PDV.id_pdv
  AND CAST (PDV.id_mes AS STRING) = FORMAT_DATE('%Y%m', DATE(T.sale_date))

WHERE B.canal IN ('ALTN', 'ALTNH', 'ALTNC')
    AND T.service_type IN ('FIX')
    AND T.order_type_agg IN ('ALTA NUEVA','PORTABILIDAD')
    AND T.comisionamiento LIKE 'Comisiona%'
    AND T.segment_ds LIKE '%SOHO%'
    AND DATE_TRUNC(T.sale_date, MONTH) BETWEEN DATE_SUB(PARSE_DATE('%Y%m', mes_string), INTERVAL 1 MONTH) AND PARSE_DATE('%Y%m', mes_string)
    AND (DATE_TRUNC(T.deactivation_date, MONTH) > DATE_ADD(DATE(T.sale_date), INTERVAL 1 MONTH) OR T.deactivation_date IS NULL)

)


;
INSERT INTO TEMP.extracomisiones_alternativo 
(
SELECT
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision,cod_producto, cod_tipo_contrato, estado)
     ,'calculado' AS estado
     , 'D - Incentivo SOHO' AS concepto
     ,CONCEPTOS.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,30 AS comision
     ,COALESCE(CONCEPTOS.cod_producto, TRANSACCIONES.cod_producto) AS cod_producto
     ,COALESCE(CONCEPTOS.cod_tipo_contrato, TRANSACCIONES.cod_tipo_contrato) AS cod_tipo_contrato



FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TEMP.extra_soho_alternativo_base` BASE 
ON TRANSACCIONES.phone_nm = BASE.phone_nm 
  AND TRANSACCIONES.account_id = BASE.account_id
  AND TRANSACCIONES.customer_id = BASE.customer_id

CROSS JOIN UNNEST(canales_pr) canal_pr

CROSS JOIN `mm-commissions-reporting.GS.CONCEPTOS` CONCEPTOS

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND BASE.orden_activacion > BASE.objetivo
      AND TRANSACCIONES.estado IN ('calculado', 'validado')
      AND TRANSACCIONES.concepto IN ('A - Servicio Fijo')
      AND CONCEPTOS.concepto IN ('D - Incentivo SOHO')
      AND TRANSACCIONES.canal IN ('ALTN','ALTNH','ALTNC')
      AND TRANSACCIONES.cod_segmento = '12'

QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACCIONES.service_id ORDER BY TRANSACCIONES.sale_date DESC) = 1)
;

END IF;

---- EXTRACOMISION BONO IMAGEN ----
IF EXISTS (SELECT 1 FROM UNNEST(canales_pr) canal WHERE canal IN ('ALTN')) THEN
INSERT INTO TEMP.extracomisiones_alternativo (
WITH TRAMOS AS (
SELECT BONO.ID_PDV,BONO.Tipo_Rebranding_simyo, SEGMENTACION.TRAMO_OBTENIDO
FROM `mm-commissions-reporting.GS.ALTERNATIVO_BONO_IMAGEN` BONO

LEFT JOIN `mm-commissions-reporting.TEMP.nex_optico_final` OPTICO
ON BONO.ID_PDV = OPTICO.sfid_unico 

LEFT JOIN `mm-commissions-reporting.GS.SEGMENTACION_ALTERNATIVO_FIJO` SEGMENTACION
ON BONO.ID_PDV = SEGMENTACION.ID_EMPRESA
 AND SEGMENTACION.MES = ID_MES_PR

GROUP BY ALL
)

SELECT
PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING)) AS mes_liquidado
,id_mes_pr AS id_mes                   
,DEALER.agrupacion_canal            
,DEALER.canal                       
,1 AS unidades                    
,DEALER.id_comisionista             
,DEALER.distribuidor                
,DEALER.sfid_id                     
,DEALER.sfid_id as seller                      
,DEALER.nombre_comercio             
,DEALER.razon_social                
,DEALER.cif                         
,DEALER.zona_fiscal                 
,DEALER.cond_pago                   
,'SIMYO' AS marca                       
,'INTERNET' AS service_type                
,CAST (NULL AS STRING) AS phone_nm                    
,CAST (NULL AS STRING) AS tariff_id                   
,CAST (NULL AS STRING) AS tariff_ds                   
,CAST (NULL AS STRING) AS service_id                  
,CAST (NULL AS STRING) AS account_id                  
,CAST (NULL AS STRING) AS customer_id                 
,CAST (NULL AS STRING) AS line_type_ds                
,CAST (NULL AS STRING) AS bundle_type                 
,CAST (NULL AS STRING) AS technology_ds               
,'POSTPAID' AS billing_type_ds             
,CAST (NULL AS DATE) AS sale_date                   
,CAST (NULL AS DATE) AS activation_date             
,CAST (NULL AS DATE) ASdeactivation_date           
,CAST (NULL AS STRING) AS order_id                    
,CAST (NULL AS STRING) AS order_type_agg              
,'10' AS cod_segmento                
,'36' AS cod_marca                   
,'29' AS cod_canal                   
,CAST (NULL AS STRING) AS campaign_code               
,CAST (NULL AS STRING) AS serial_number               
,CAST (NULL AS FLOAT64) AS tax_base                    
,CAST (NULL AS STRING) AS claim_code                  
,CAST (NULL AS STRING) AS process_code                
,CAST (NULL AS STRING) AS proceso_sap                 
,CAST (NULL AS STRING) AS id_registro                 
,CAST (NULL AS STRING) AS invoice_id                  
,'X001' AS sociedad                    
,CAST (NULL AS STRING) AS bp                          
,CAST (NULL AS STRING) AS cuenta_contable             
,CAST (NULL AS STRING) AS centro_coste                
,CAST (NULL AS STRING) AS documento_sap               
,CAST (NULL AS STRING) AS documento_sap_posicion      
,CAST (NULL AS STRING) AS fecha_contabilizacion       
  ,CURRENT_TIMESTAMP AS creado
  ,CURRENT_TIMESTAMP AS modificado                
,CAST (NULL AS STRING) AS id_factura_drive            
,CAST(NULL AS ARRAY<STRING>) AS emails_acceso_trazabilidad
,'calculado' AS estado                      
,'D - Bono Imagen' AS concepto                    
,'UPFR' AS tipo_concepto               
,'C_MANUAL' AS facturador                  
,CAST (NULL AS STRING) AS comments                    
,CASE WHEN UPPER(A.Tipo_Rebranding_simyo) = 'COMPLETO' THEN
                                                        CASE WHEN A.TRAMO_OBTENIDO = 'ORO-PLUS' THEN 175
                                                              WHEN A.TRAMO_OBTENIDO = 'PLATINO' THEN 350
                                                              WHEN A.TRAMO_OBTENIDO = 'DIAMANTE'THEN 600
                                                        END
      WHEN UPPER(A.Tipo_Rebranding_simyo) = 'MEDIO' THEN
                                                        CASE WHEN A.TRAMO_OBTENIDO = 'ORO-PLUS' THEN 100
                                                              WHEN A.TRAMO_OBTENIDO = 'PLATINO' THEN 200
                                                              WHEN A.TRAMO_OBTENIDO = 'DIAMANTE'THEN 300
                                                        END
  END AS  comision                    
,'054' AS cod_producto                
,'61' AS cod_tipo_contrato           

FROM TRAMOS A

LEFT JOIN `mm-commissions-reporting.COMISIONES.v_dealer_ultima_version` DEALER
ON A.ID_PDV = DEALER.sfid_id

WHERE A.TRAMO_OBTENIDO IN ('ORO-PLUS','PLATINO','DIAMANTE')

QUALIFY ROW_NUMBER() OVER (PARTITION BY A.ID_PDV ORDER BY DEALER.sfid_id DESC) = 1)
;

END IF;

DELETE 
FROM TEMP.extracomisiones_alternativo
WHERE COMISION = 0
;
CREATE OR REPLACE TABLE TEMP.extracomisiones_alternativo AS
(
SELECT
      *
     ,prefijo || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
FROM TEMP.extracomisiones_alternativo
WHERE comision IS NOT NULL 
)
;



CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, canales_pr , 'TEMP.extracomisiones_alternativo' , 'ACTUALIZAR');


END