BEGIN
DECLARE
  prefijo,
  mes_string string;
SET
  mes_string = CAST(id_mes_pr AS string);
SET prefijo = 'SGRG_'; 
--set prefijo = 'PRUEBAMAYOSVG';

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU','WA', 'EDB', 'EML' ,'ENX', 'EYG','ENK', 'D2D', 'D2N', 'DEM', 'CIN', 'DON', 'OUN', 'XIN', 'XSN'];
END IF;

--CALL COMISIONES.pr_ENERGY_SVG (202508, NULL);

CREATE OR REPLACE TABLE TEMP.ENERGY_SVG AS 
  --__________________________________________________________________________ B - SVG ______________________________________________________________________
SELECT
  id_mes_pr AS id_mes,
  prefijo||'B-svg'||mes_string||'_'||D.canal||'_'||row_number () OVER () AS commission_id,
  case 

     when tenant_code = 'yoigo_svg' and A.sfid_id = 'SLE00001_OU' then 'DO'
     when tenant_code = 'masmovil_svg' and A.sfid_id = 'TLVOU001' then 'DO'
     else C.canal
     end

as canal,
  
  case 

     when tenant_code = 'yoigo_svg' and A.sfid_id = 'SLE00001_OU' then 'TLV - DO'
     when tenant_code = 'masmovil_svg' and A.sfid_id = 'TLVOU001' then 'TLV - DO'
     else C.agrupacion_canal
     end

as agrupacion_canal,
case 

     when tenant_code = 'yoigo_svg' and A.sfid_id = 'SLE00001_OU' then '15'
     when tenant_code = 'masmovil_svg' and A.sfid_id = 'TLVOU001' then '15'
     
     else D.cod_canal
     end

  as cod_canal,
  (
  SELECT
    concepto
  FROM
    `mm-commissions-reporting.GS.CONCEPTOS`
  WHERE
    CONCEPTO IN ('B - SVG')) AS concepto,
  'CSEN' AS tipo_concepto,
  1 AS unidades,
  CASE 

         when tenant_code = 'masmovil_svg'and C.sfid_id =  'TLVOU001'  then  30                
       when tenant_code = 'yoigo_svg' and C.sfid_id = 'SLE00001_OU' then 30               
       when tenant_code = 'yoigo_svg' and C.sfid_id = 'TLVOU001' then 30

    WHEN tenant_code IN ('yoigo_svg','masmovil_svg','pepe_svg')AND D.canal IN('XI','XIN','XS','XSN','XO','XOF','WA','EML','EYG','ENX','MP','MI','MR','ALTN','ST', 
     'ALTNC','ALTNH')THEN 10
    WHEN tenant_code IN ('yoigo_svg','masmovil_svg','pepe_svg')AND D.canal = 'ENK' THEN 15
    WHEN tenant_code IN ('yoigo_svg','pepe_svg')AND D.canal = 'PH' THEN 10
    WHEN tenant_code IN ('masmovil_svg')           AND D.canal = 'PH' THEN 15
    -- DOOR TO DOOR --ENERGYGO

    WHEN tenant_code IN ('yoigo_svg','masmovil_svg')AND D.canal IN ('D2N','D2D','DEM') THEN 20


    -- Outbound/Inbound/Distribucion Online --yoigo

    WHEN tenant_code IN ('yoigo_svg','masmovil_svg')AND D.canal IN ('OU','OUN','DO','DON') THEN 20
   
 END
  AS COMISION,
  C.id_comisionista,
  C.distribuidor,
  C.sfid_id,
  upper(SPLIT(A.author_id, "@")[OFFSET (0)]) AS seller,
  C.nombre_comercio,
  C.razon_social,
  C.cif,
  C.zona_fiscal,
  CASE
    WHEN A.tenant_code ='yoigo_svg' THEN 'ENERGYGO'
    WHEN A.tenant_code ='masmovil_svg' THEN 'MASMOVIL'
    WHEN A.tenant_code ='pepe_svg' THEN 'PEPEENERGY'
END
  AS marca,
  'ENERGY' AS service_type,
  CAST(NULL AS string) AS phone_nm,
  CAST(NULL AS STRING) AS tariff_id,
  CAST(NULL AS STRING) AS tariff_ds,
  CAST(NULL AS STRING) AS service_id,
  A.cups_code AS account_id,
  CAST(NULL AS STRING) AS customer_id,
  CAST(NULL AS STRING) AS line_type_ds,
  CAST(NULL AS STRING) AS bundle_type,
  CAST(NULL AS STRING) AS technology_ds,
  CAST(NULL AS STRING) AS billing_type_ds,
  A.signup_date_altas AS sale_date,
  B.data_inici AS activation_date,
  B.data_fi AS deactivation_date,
  CAST (NULL AS string) AS order_id,
  CAST (NULL AS string) AS order_type_agg,
  '10' AS cod_segmento,
  '99' AS cod_tipo_contrato,
  '014' AS cod_producto,
  CASE
    WHEN tenant_code ='yoigo_svg' THEN '16'
    WHEN tenant_code ='masmovil_svg' THEN '17'
    WHEN tenant_code ='pepe_svg' THEN '19'
END
  AS cod_marca,
  CAST (NULL AS string) AS claim_code,
  CASE
      WHEN B.data_inici < '2024-07-22'
      THEN COALESCE(
                    CASE 
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_EG%' OR UPPER(author_id) like'%_ME%' THEN 'Energia OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_XS%' THEN 'Cross-sell OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_TV%' THEN 'TV OUT'
                        ELSE `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(D.canal, A.tenant_code, C.sfid_id, 'ENERGY') 
                    END
                   ,TLV_CROSS_SELL.campaign
                   )
      
      ELSE COALESCE(
                    TLV_CROSS_SELL.campaign
                   ,CASE 
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_EG%' OR UPPER(author_id) like'%_ME%' THEN 'Energia OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_XS%' THEN 'Cross-sell OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_TV%' THEN 'TV OUT'
                        ELSE `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(D.canal, A.tenant_code, A.sfid_id, 'ENERGY') 
                    END
                   )
  END AS campaign_code,
  A.cups_code AS serial_number,
  CAST ( NULL AS float64 ) tax_base,
  CAST (NULL AS string) AS process_code,
  CAST (NULL AS string) AS comments,
  'C_MANUAL' AS facturador,
  'calculado' AS estado
FROM
  `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
INNER JOIN
  `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
ON
  A.id = B.polissa_id
LEFT JOIN
  `mm-commissions-reporting.COMISIONES.v_dealer` C
ON
  UPPER(A.author_id) = C.sfid_id
  OR A.sfid_id = C.sfid_id
  OR (SUBSTRING(UPPER(A.author_id),1,2)) = C.sfid_id
  OR (SUBSTRING(UPPER(A.author_id),1,2)) = C.id_comisionista
  OR UPPER(SPLIT(a.author_id,'@')[
  OFFSET
    (0)]) = C.sfid_id
  OR UPPER(SPLIT(a.author_id,'@')[
  OFFSET
    (0)]) =C.id_comisionista

LEFT JOIN
  `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
ON
  C.id_comisionista = TLV_CROSS_SELL.id_comisionista
  AND C.canal = TLV_CROSS_SELL.canal

INNER JOIN
  `mm-commissions-reporting.GS.CANALES` D
ON
  D.CANAL=C.CANAL

  CROSS JOIN UNNEST(canales_pr) AS canal_pr
WHERE
  DATE_TRUNC(DATE(B.data_inici), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_pr AS STRING))
  AND C.canal = canal_pr
  AND D.canal IS NOT NULL
  AND D.canal not in ('XSN','CIN','XIN')
  AND product = 'SVG'
  AND tenant_code IN ('masmovil_svg',
    'yoigo_svg',
    'pepe_svg')
  AND subchannel_ds NOT IN ('WEB',
    'SERVICES2SALES',
    'CANCELACIONES',
    'RECUPERADAS_AN',
    'PLAT. FIDELIZACION/RETENCION')
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC ) = 1 

----------------------------------------------------------------------------GESTION DE CANAL SVG __________________________________________________________
UNION ALL

SELECT
id_mes_pr AS id_mes,
prefijo||'G-svg'||mes_string||'_'||D.canal||'_'||row_number () OVER () AS commission_id,
C.canal as canal,
C.agrupacion_canal as agrupacion_canal,
D.cod_canal as cod_canal,
'F - Gestion de canal SVG'AS concepto,
  'CSEN' AS tipo_concepto,
  1 AS unidades,
  CASE 


    WHEN tenant_code IN ('yoigo_svg','masmovil_svg','pepe_svg')AND D.canal IN('EML','EYG','ENX')THEN 0
   
END
 AS COMISION,
 C.id_comisionista,
 C.distribuidor,
 C.sfid_id,
 upper(SPLIT(A.author_id, "@")[OFFSET (0)]) AS seller,
 C.nombre_comercio,
 C.razon_social,
 C.cif,
 C.zona_fiscal,
 CASE
   WHEN A.tenant_code ='yoigo_svg' THEN 'ENERGYGO'
   WHEN A.tenant_code ='masmovil_svg' THEN 'MASMOVIL'
   WHEN A.tenant_code ='pepe_svg' THEN 'PEPEENERGY'
END
 AS marca,
 'ENERGY' AS service_type,
 CAST(NULL AS string) AS phone_nm,
 CAST(NULL AS STRING) AS tariff_id,
 CAST(NULL AS STRING) AS tariff_ds,
 CAST(NULL AS STRING) AS service_id,
 A.cups_code AS account_id,
 CAST(NULL AS STRING) AS customer_id,
 CAST(NULL AS STRING) AS line_type_ds,
 CAST(NULL AS STRING) AS bundle_type,
 CAST(NULL AS STRING) AS technology_ds,
 CAST(NULL AS STRING) AS billing_type_ds,
 A.signup_date_altas AS sale_date,
 B.data_inici AS activation_date,
 B.data_fi AS deactivation_date,
 CAST (NULL AS string) AS order_id,
 CAST (NULL AS string) AS order_type_agg,
 '10' AS cod_segmento,
 '99' AS cod_tipo_contrato,
 '014' AS cod_producto,
 CASE
   WHEN tenant_code ='yoigo_svg' THEN '16'
   WHEN tenant_code ='masmovil_svg' THEN '17'
   WHEN tenant_code ='pepe_svg' THEN '19'
END
 AS cod_marca,
 CAST (NULL AS string) AS claim_code,
 CASE
     WHEN B.data_inici < '2024-07-22'
     THEN COALESCE(
                   CASE 
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_EG%' OR UPPER(author_id) like'%_ME%' THEN 'Energia OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_XS%' THEN 'Cross-sell OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_TV%' THEN 'TV OUT'
                        ELSE `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(D.canal, A.tenant_code, C.sfid_id, 'ENERGY') 
                    END
                   ,TLV_CROSS_SELL.campaign
                   )
      
      ELSE COALESCE(
                    TLV_CROSS_SELL.campaign
                   ,CASE 
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_EG%' OR UPPER(author_id) like'%_ME%' THEN 'Energia OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_XS%' THEN 'Cross-sell OUT'
                        WHEN C.canal = 'XS' and UPPER(author_id) like '%_TV%' THEN 'TV OUT'
                        ELSE `mm-commissions-reporting.COMISIONES.f_clasificacion_camp_cross_sell`(D.canal, A.tenant_code, C.sfid_id, 'ENERGY') 
                    END
                   )
 END AS campaign_code,
 A.cups_code AS serial_number,
 CAST ( NULL AS float64 ) tax_base,
 CAST (NULL AS string) AS process_code,
 CAST (NULL AS string) AS comments,
 'C_MANUAL' AS facturador,
 'calculado' AS estado
FROM
  `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
INNER JOIN
  `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
ON
  A.id = B.polissa_id
LEFT JOIN
  `mm-commissions-reporting.COMISIONES.v_dealer` C
ON
  UPPER(A.author_id) = C.sfid_id
  OR A.sfid_id = C.sfid_id
  OR (SUBSTRING(UPPER(A.author_id),1,2)) = C.sfid_id
  OR (SUBSTRING(UPPER(A.author_id),1,2)) = C.id_comisionista
  OR UPPER(SPLIT(a.author_id,'@')[
  OFFSET
    (0)]) = C.sfid_id
  OR UPPER(SPLIT(a.author_id,'@')[
  OFFSET
    (0)]) =C.id_comisionista

LEFT JOIN
  `mm-commissions-reporting.GS.tlv_cross_sell_dealers` TLV_CROSS_SELL
ON
  C.id_comisionista = TLV_CROSS_SELL.id_comisionista
  AND C.canal = TLV_CROSS_SELL.canal

INNER JOIN
  `mm-commissions-reporting.GS.CANALES` D
ON
  D.CANAL=C.CANAL

  CROSS JOIN UNNEST(canales_pr) AS canal_pr
WHERE
 DATE_TRUNC(DATE(B.data_inici), MONTH) = PARSE_DATE('%Y%m', mes_string) 
  AND C.canal = canal_pr
  AND D.canal IS NOT NULL
  AND D.canal IN ('EML','EYG')
  AND product = 'SVG'
  AND tenant_code IN ('masmovil_svg',
    'yoigo_svg',
    'pepe_svg')
  AND subchannel_ds NOT IN ('WEB',
    'SERVICES2SALES',
    'CANCELACIONES',
    'RECUPERADAS_AN',
    'PLAT. FIDELIZACION/RETENCION')
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC ) = 1 ;





  
   --LLAMAR A CLAWBACK DE SVG --



CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('SGRG_',id_mes_pr,canales_pr,'TEMP.ENERGY_SVG','ACTUALIZAR');
END