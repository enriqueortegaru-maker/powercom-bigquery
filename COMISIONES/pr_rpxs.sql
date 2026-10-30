BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN SET canales_pr = ['XS'];
END IF;



-- CALL COMISIONES.pr_rpxs (202605, ['XS']);


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.UNITARIO_ENERGIA_XSELL` 
OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) AS (
WITH BASE AS (
  SELECT  
    CAMP_ENERGIA.id_comisionista AS sfid_id,
    CAMP_ENERGIA.marca,
    CAMP_ENERGIA.campaign AS campaign_code,
    TRANSACCIONES.concepto,
    TRANSACCIONES.comision,
    CAMP_ENERGIA.comision_fija as importe
  FROM `mm-commissions-reporting.GS.XS_CAMP_ENERGIA` CAMP_ENERGIA 
  LEFT JOIN `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES
    ON CAMP_ENERGIA.id_comisionista = TRANSACCIONES.id_comisionista
    AND CAMP_ENERGIA.mes = TRANSACCIONES.id_mes
    AND CAMP_ENERGIA.campaign = TRANSACCIONES.campaign_code
    AND CAMP_ENERGIA.marca = CASE 
                                WHEN TRANSACCIONES.marca = 'ENERGYGO' THEN 'YOIGO' 
                                ELSE TRANSACCIONES.marca 
                              END
    AND TRANSACCIONES.canal = 'XS'
    AND TRANSACCIONES.concepto IN (
        'B - Energia', 'B - Gas',
        'B - SVE', 'B - SVG',
        'E - Clawback Energia', 'E - Clawback Gas',
        'E - Clawback SVE', 'E - Clawback SVG'
    )
  WHERE CAMP_ENERGIA.mes = id_mes_pr
    
)
,
UNIDAD AS (
SELECT 
 sfid_id
,marca
,campaign_code
,COUNT (CASE WHEN CONCEPTO IN ('B - Gas','B - Energia') THEN 1 END) AS UDS
,SUM(COMISION) AS COMISION
,IMPORTE

FROM BASE

GROUP BY ALL)
,
CALCULO_UNITARIOS AS (
SELECT 
SFID_ID
,marca
,campaign_code
,IMPORTE
,UDS
,SAFE_DIVIDE(COMISION, UDS) AS UNITARIO_ENERGIA
,120 - SAFE_DIVIDE(COMISION, UDS) AS UNITARIO_DISPONIBLE
,(120 - SAFE_DIVIDE(COMISION, UDS)) * UDS AS A_PAGAR
FROM UNIDAD
GROUP BY ALL)

SELECT 
 SFID_ID
 ,MARCA
 ,CAMPAIGN_CODE
 ,IMPORTE
 ,UDS
 ,CASE WHEN IMPORTE - (A_PAGAR) < 0 THEN 0 ELSE IMPORTE - A_PAGAR END AS RESTO
 ,CASE WHEN IMPORTE - (A_PAGAR) < 0 THEN IMPORTE/UDS ELSE A_PAGAR / UDS END AS UNITARIO_ENERGIA
FROM CALCULO_UNITARIOS

)
;


CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.RPXS`
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
-- ,claim_code                  STRING
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
,claim_code                  STRING
)
;

INSERT INTO `mm-commissions-reporting.TEMP.RPXS`(
  --- REPARTO SOBRE ENERGIA ---
  SELECT
     
      TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado, claim_code)
     ,'calculado' AS estado
     ,'D - Camp. '|| TRANSACCIONES.campaign_code AS CONCEPTO
     ,TRANSACCIONES.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,UNITARIO_ENERG.UNITARIO_ENERGIA AS comision
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,SUBSTR(TRANSACCIONES.concepto,5) AS claim_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

INNER JOIN `mm-commissions-reporting.TEMP.UNITARIO_ENERGIA_XSELL` UNITARIO_ENERG
ON TRANSACCIONES.sfid_id = UNITARIO_ENERG.sfid_id
  AND TRANSACCIONES.marca = UNITARIO_ENERG.MARCA
  AND UNITARIO_ENERG.CAMPAIGN_CODE = TRANSACCIONES.campaign_code
  


WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = 'XS'
      AND TRANSACCIONES.concepto IN (
              'B - Energia',
              'B - Gas' 
                      )

UNION ALL


--- REPARTO SOBRE RESTO DE SVAS ---
SELECT
     
     TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado,claim_code)
     ,'calculado' AS estado
     ,'D - Camp. '|| TRANSACCIONES.campaign_code AS CONCEPTO

     ,TRANSACCIONES.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,UNITARIO_ENERG.RESTO / CONTEO_OTROS.UDS_OTROS  AS comision
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,SUBSTR(TRANSACCIONES.concepto,5) AS claim_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TEMP.UNITARIO_ENERGIA_XSELL` UNITARIO_ENERG
ON TRANSACCIONES.sfid_id = UNITARIO_ENERG.sfid_id
  AND TRANSACCIONES.marca = UNITARIO_ENERG.MARCA
   AND UNITARIO_ENERG.CAMPAIGN_CODE = TRANSACCIONES.campaign_code

LEFT JOIN (
           SELECT TRANSACCIONES.SFID_ID, TRANSACCIONES.MARCA,TRANSACCIONES.campaign_code, COUNT(*) AS UDS_OTROS 
            FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

            LEFT JOIN `mm-commissions-reporting.TEMP.UNITARIO_ENERGIA_XSELL` UNITARIO_ENERG
             ON TRANSACCIONES.sfid_id = UNITARIO_ENERG.sfid_id
              AND TRANSACCIONES.marca = UNITARIO_ENERG.MARCA
                AND UNITARIO_ENERG.CAMPAIGN_CODE = TRANSACCIONES.campaign_code
            

            WHERE TRANSACCIONES.id_mes = id_mes_pr
                AND TRANSACCIONES.canal = 'XS'
                AND TRANSACCIONES.concepto IN (
                        'A - Servicio Fijo',
                        'A - Servicio Movil Pospago',
                        'B - Amazon Prime',
                        'B - Disney',
                        'B - Max',
                        'B - Netflix',
                        'B - Renuevo',
                        'B - Television',
                        'B - Television Premium',
                        'D - Dispositivo Captacion'
                                )
                GROUP BY ALL) CONTEO_OTROS
      ON CONTEO_OTROS.sfid_id = TRANSACCIONES.sfid_id
        AND CONTEO_OTROS.MARCA = TRANSACCIONES.marca
        AND CONTEO_OTROS.CAMPAIGN_CODE = TRANSACCIONES.campaign_code


WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = 'XS'
      AND TRANSACCIONES.concepto IN (
              'A - Servicio Fijo',
              'A - Servicio Movil Pospago',
              'B - Amazon Prime',
              'B - Disney',
              'B - Max',
              'B - Netflix',
              'B - Renuevo',
              'B - Television',
              'B - Television Premium',
              'D - Dispositivo Captacion'
                      )
      AND UNITARIO_ENERG.sfid_id IS NOT NULL
      AND UNITARIO_ENERG.RESTO > 0
      AND UNITARIO_ENERG.MARCA IS NOT NULL
            AND UNITARIO_ENERG.CAMPAIGN_CODE IS NOT NULL

  UNION ALL

--- REPARTO CUANDO NO TIENE VENTAS EN ENERGIA ---
SELECT
     
     TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado, claim_code)
     ,'calculado' AS estado
     ,'D - Camp. '|| TRANSACCIONES.campaign_code AS CONCEPTO
     ,TRANSACCIONES.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,GS.comision_fija / CONTEO_OTROS.UDS_OTROS  AS comision
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,SUBSTR(TRANSACCIONES.concepto,5) AS claim_code

FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

LEFT JOIN `mm-commissions-reporting.TEMP.UNITARIO_ENERGIA_XSELL` UNITARIO_ENERG
ON TRANSACCIONES.sfid_id = UNITARIO_ENERG.sfid_id
  AND TRANSACCIONES.marca = UNITARIO_ENERG.MARCA
    AND UNITARIO_ENERG.CAMPAIGN_CODE = TRANSACCIONES.campaign_code


LEFT JOIN (
  SELECT TRANSACCIONES.SFID_ID, TRANSACCIONES.MARCA,UNITARIO_ENERG.CAMPAIGN_CODE, COUNT(*) AS UDS_OTROS 
  FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

  INNER JOIN `mm-commissions-reporting.TEMP.UNITARIO_ENERGIA_XSELL` UNITARIO_ENERG
  ON TRANSACCIONES.sfid_id = UNITARIO_ENERG.sfid_id
    AND TRANSACCIONES.marca = UNITARIO_ENERG.MARCA
      AND UNITARIO_ENERG.CAMPAIGN_CODE = TRANSACCIONES.campaign_code


  WHERE TRANSACCIONES.id_mes = id_mes_pr
        AND TRANSACCIONES.canal = 'XS'
        AND TRANSACCIONES.concepto IN (
                'A - Servicio Fijo',
                'A - Servicio Movil Pospago',
                'B - Amazon Prime',
                'B - Disney',
                'B - Max',
                'B - Netflix',
                'B - Renuevo',
                'B - Television',
                'B - Television Premium',
                'D - Dispositivo Captacion'
                        )
                  GROUP BY ALL) CONTEO_OTROS
        ON CONTEO_OTROS.sfid_id = TRANSACCIONES.sfid_id
          AND CONTEO_OTROS.MARCA = TRANSACCIONES.marca
          AND CONTEO_OTROS.CAMPAIGN_CODE = TRANSACCIONES.campaign_code


LEFT JOIN `mm-commissions-reporting.GS.XS_CAMP_ENERGIA` GS 
  ON GS.id_comisionista = TRANSACCIONES.sfid_id
   AND GS.marca = TRANSACCIONES.MARCA
   AND GS.mes = id_mes_pr
   AND GS.campaign = TRANSACCIONES.campaign_code

WHERE TRANSACCIONES.id_mes = id_mes_pr
      AND TRANSACCIONES.canal = 'XS'
      AND TRANSACCIONES.concepto IN (
              'A - Servicio Fijo',
              'A - Servicio Movil Pospago',
              'B - Amazon Prime',
              'B - Disney',
              'B - Max',
              'B - Netflix',
              'B - Renuevo',
              'B - Television',
              'B - Television Premium',
              'D - Dispositivo Captacion'
                      )
      AND UNITARIO_ENERG.UNITARIO_ENERGIA IS NULL
      AND GS.MARCA IS NOT NULL

)
;
INSERT INTO `mm-commissions-reporting.TEMP.RPXS` (
  WITH BASE_RAPPEL AS (
SELECT 
  T.id_comisionista
  ,T.marca
  ,T.campaign_code
  ,COUNT (*) AS unidades
  ,RAPPEL.comision_rappel
FROM `mm-commissions-reporting.COMISIONES.transacciones` T
LEFT JOIN `mm-commissions-reporting.GS.XS_CAMP_ENERGIA` RAPPEL
ON T.id_comisionista = RAPPEL.id_comisionista
 AND T.MARCA = RAPPEL.marca
 AND T.campaign_code = RAPPEL.campaign
 AND RAPPEL.MES = id_mes_pr

WHERE ID_MES = id_mes_pr
AND CANAL = 'XS'
AND((campaign_code = 'Multiproducto Television' AND concepto IN ('B - Television','B - Television Premium')) OR
    (campaign_code = 'Multiproducto Generica' AND concepto IN ('B - Energia','B - Gas')) OR
    (campaign_code = 'Multiproducto Terminales' AND concepto IN ('B - Renuevo')) )

GROUP BY ALL
)


SELECT
     
     TRANSACCIONES.* EXCEPT(commission_id, concepto, tipo_concepto, facturador, comments, comision, cod_producto, cod_tipo_contrato, estado, claim_code)
     ,'calculado' AS estado
     ,CASE 
        WHEN RAPPEL.campaign_code = 'Multiproducto Generica'       THEN 'D - Rappel Multiproducto Generica'
        WHEN RAPPEL.campaign_code = 'Multiproducto Terminales'     THEN 'D - Rappel Multiproducto Terminales'
        WHEN RAPPEL.campaign_code = 'Multiproducto Television'     THEN 'D - Rappel Multiproducto Television'
      ELSE NULL END AS concepto
     ,TRANSACCIONES.tipo_concepto
     ,'C_MANUAL' AS facturador
     ,CAST(NULL AS STRING) AS comments
     ,RAPPEL.comision_rappel / RAPPEL.unidades  AS comision
     ,TRANSACCIONES.cod_producto
     ,TRANSACCIONES.cod_tipo_contrato
     ,SUBSTR(TRANSACCIONES.concepto,5) AS claim_code

     FROM `mm-commissions-reporting.COMISIONES.transacciones` TRANSACCIONES

     LEFT JOIN BASE_RAPPEL RAPPEL
      ON TRANSACCIONES.id_comisionista = RAPPEL.id_comisionista
      AND TRANSACCIONES.marca = RAPPEL.marca
      AND TRANSACCIONES.campaign_code = RAPPEL.campaign_code

     WHERE TRANSACCIONES.ID_MES = id_mes_pr
      AND TRANSACCIONES.CANAL = 'XS'
      AND((TRANSACCIONES.campaign_code = 'Multiproducto Television' AND concepto IN ('B - Television','B - Television Premium')) OR
          (TRANSACCIONES.campaign_code = 'Multiproducto Generica'   AND concepto IN ('B - Energia','B - Gas')) OR
          (TRANSACCIONES.campaign_code = 'Multiproducto Terminales' AND concepto IN ('B - Renuevo')) )
)
;
CREATE OR REPLACE TABLE TEMP.RPXS AS
(
  SELECT
        *
      ,'RPXS' || '_'|| mes_string || '_' || canal || '_' || ROW_NUMBER() OVER() AS commission_id
  FROM TEMP.RPXS
  WHERE comision IS NOT NULL
  AND CONCEPTO IS NOT NULL
)
;

ASSERT (
  (
    SELECT COUNT(*)
    FROM (
      WITH gs_agg AS (
        SELECT
          id_comisionista,
          marca,
          campaign,
          mes,
          SUM(comision_fija + comision_rappel) AS total_esperado
        FROM `mm-commissions-reporting.GS.XS_CAMP_ENERGIA`
        WHERE mes = ID_MES_PR
        GROUP BY id_comisionista, marca, campaign, mes
      )
      SELECT
        r.id_comisionista,
        r.marca,
        r.campaign_code,
        ROUND(SUM(r.comision), 2) AS total_repartido,
        ROUND(MAX(gs.total_esperado), 2) AS total_esperado,
        ROUND(
          SUM(r.comision) - MAX(gs.total_esperado),
          2
        ) AS diferencia
      FROM `mm-commissions-reporting.TEMP.RPXS` r
      LEFT JOIN gs_agg gs
        ON gs.id_comisionista = r.id_comisionista
       AND gs.marca = r.marca
       AND gs.campaign = r.campaign_code
       AND gs.mes = r.id_mes
      GROUP BY
        r.id_comisionista,
        r.marca,
        r.campaign_code
      HAVING ABS(SUM(r.comision) - MAX(gs.total_esperado)) > 0.01
    )
  ) = 0
)AS 'ERROR RPXS: El importe repartido no cuadra con XS_CAMP_ENERGIA';



CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('RPXS', id_mes_pr, ['XS'] , 'TEMP.RPXS' , 'ACTUALIZAR');



END