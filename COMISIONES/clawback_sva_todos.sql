begin


declare id_mes_claw int64;
declare prefijo string;
set id_mes_claw = id_mes_pr;
set prefijo = 'CLAWB_';

IF canales_pr IS NULL THEN SET canales_pr = ['ALTN', 'ALTNC','ALTNH', 'NR', 'PH', 'ST', 'XI', 'XO', 'XOF', 'XS','XSO', 'DO', 'OU','WA', 'EDB', 'EML' ,'ENX', 'EYG','ENK', 'D2D', 'D2N', 'DEM', 'CIN', 'DON', 'OUN', 'XIN', 'XSN'];
END IF;

--call`COMISIONES.clawback_sva_todos`(202508, NULL);

create or replace table TEMP.CLAWB_SVAS AS (


select * from 
(

select 

id_mes_claw as id_mes,
prefijo||'C_luz'||id_mes_claw||'_'||trans.canal||'_'||row_number () OVER () AS commission_id,
trans.canal,
trans.agrupacion_canal,
COD_CANAL,

case 

      when trans.concepto = 'B - Energia' then 'E - Clawback energia' --si
      when trans.concepto = 'D - Rappel energia' then 'E - Clawback rappel energia'   --si
      when trans.concepto = 'F - Gestion de canal energia' then 'H - Clawback Gestion de canal energia'  --si
      when trans.concepto = 'D - Extracomision energia' then 'E - Clawback extracomision energia'
      when trans.concepto = 'D - Multiplicador energia' then 'E - Clawback multiplicador energia' --si


 END as concepto,  
 'CSEN' as tipo_concepto,
 1 as unidades,
 case 


 --EXCLUSIVO--

 when trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','XO','XOF','WA') AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN trans.comision * -1
 when trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','XO','XOF','WA') AND DATE_DIFF  (churn_date, pen.activation_date, DAY) BETWEEN 61 AND 120 THEN (trans.comision * 0.75) * -1
 when trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','XO','XOF','WA') AND DATE_DIFF  (churn_date, pen.activation_date, DAY)BETWEEN 121 AND 180 THEN (trans.comision * 0.5) * -1



 --D2D--

 when trans.canal IN ('D2D','DEM','D2N')  AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 180 THEN trans.comision * -1






 -----------------------------------------------------INCORPORANDO XS A LA QUERY OJO 25-06-2024 --------------------------------------------------

      when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) like '%_eg%' and trans.concepto = 'D - Rappel energia'   AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN trans.comision * -1
     when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) not like '%_eg%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN trans.comision * -1
     when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) not like '%_eg%' AND DATE_DIFF (churn_date, pen.activation_date, DAY) BETWEEN 61 AND 120 THEN (trans.comision * 0.75) * -1
     when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) not like '%_eg%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)BETWEEN 121 AND 180 THEN (trans.comision * 0.5) * -1
    

     
          when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) like '%_me%' and trans.concepto = 'D - Rappel energia'  AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN trans.comision * -1
     when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) not like '%_me%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN trans.comision * -1
     when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) not like '%_me%' AND DATE_DIFF (churn_date, pen.activation_date, DAY) BETWEEN 61 AND 120 THEN (trans.comision * 0.75) * -1
     when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) not like '%_me%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)BETWEEN 121 AND 180 THEN (trans.comision * 0.5) * -1

 --DISTRIBUCION ONLINE--

 when trans.canal in ('DO','DON')  AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 90 THEN trans.comision * -1
  when trans.canal in ('OU','OUN')  AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 90 THEN trans.comision * -1



 else 0
 END AS COMISION,


 trans.id_comisionista,
 trans.distribuidor,
 trans.id_comisionista as sfid_id,
 trans.seller,
 trans.nombre_comercio,
 trans.razon_social,
 trans.cif,
 trans.zona_fiscal,
 trans.marca,
 trans.service_type,
 trans.phone_nm,
 trans.tariff_id,
 trans.tariff_ds,
 trans.service_id,
 trans.account_id,
 trans.customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
 trans.sale_date,
 trans.activation_date,
 churn_date as deactivation_date,
 trans.order_id,
 trans.order_type_agg,
 trans.cod_segmento,
 trans.cod_tipo_contrato,
 trans.cod_producto,
 trans.cod_marca,
 cast (null as string) as claim_code,
 trans.campaign_code,
 trans.serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
 trans.facturador,
 'calculado' as estado
FROM(
 select canal,
  comision,
  concepto,
   id,
  unique_id, 
  contract_code,
  tenant_code,
  cups_code, 
  L.activation_date, 
  churn_date
from `mm-datamart-kd.ENERGY.lucera_polissas_electricity` L
inner join `mm-commissions-reporting.COMISIONES.transacciones` T
on CAST(L.cups_code AS STRING) = T.account_id
where (DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) AND T.canal in ('EYG','EML','ENX','MI','MR', 'ALTN','ST','ALTNC','ALTNH','MP','PH', 'CA', 'D2D', 'D2N','DEM','XI','WA','XO','XOF') and DATE_DIFF (churn_date, T.activation_date, DAY)< 181)
and  T.concepto not like ('%Claw%')
 
and concepto not in ( 'D - Rappel Fijo_B','D - Apoyo Coche','B - SVE')
and tipo_concepto= 'CSEN'
and concepto is not null

or ((DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) AND T.canal in ('DO') and DATE_DIFF (churn_date, T.activation_date, DAY)< 91)
and  T.concepto not like ('%Claw%')
 
and concepto not in ( 'D - Rappel Fijo_B','D - Apoyo Coche','B - SVE')
and tipo_concepto= 'CSEN'
and concepto is not null)

or ( (DATE_TRUNC(DATE(churn_date), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING)) AND T.canal in ('XS') and DATE_DIFF (churn_date, T.activation_date, DAY)< 181)
and  T.concepto not like ('%Claw%')
  
and concepto not in ( 'D - Rappel Fijo_B','D - Apoyo Coche','B - SVE')
and tipo_concepto= 'CSEN'
and concepto is not null)


QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING) ORDER BY cups_code DESC   ) =  1) pen
inner join `mm-commissions-reporting.COMISIONES.transacciones` trans
on CAST(pen.id AS STRING) = trans.service_id
where 
trans.concepto in ( 'B - Energia' ,
       'D - Rappel energia',
       'F - Gestion de canal energia', 
     'D - Extracomision energia' ,
    'D - Multiplicador energia'
    )
and not (trans.canal = 'XS' and trans.concepto= 'B - Energia' and (lower(seller) like '%_eg%' or  lower(seller) like '%_me%'))
)
where comision!= 0 
and concepto is not null

UNION ALL

select * from (

SELECT
  id_mes_claw AS id_mes,
prefijo||'C_gas'||id_mes_claw||'_'||trans.canal||'_'||row_number () OVER () AS commission_id,
  trans.canal,
  trans.agrupacion_canal,
  trans.COD_CANAL,
  CASE
    WHEN trans.concepto = 'B - Gas' THEN 'E - Clawback gas' --si
    WHEN trans.concepto = 'F - Gestion de canal gas' THEN 'H - Clawback Gestion de canal gas' --si
    WHEN trans.concepto = 'D - Multiplicador gas' THEN 'E - Clawback multiplicador gas' --si
END
  AS concepto,
  'CSEN' AS tipo_concepto,
  1 AS unidades,
  CASE

   --EXCLUSIVO--

    WHEN trans.canal IN('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','WA') AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN (comision * -1)
    WHEN trans.canal IN('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','WA') AND DATE_DIFF (churn_date, pen.activation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1
    WHEN trans.canal IN('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','WA') AND DATE_DIFF (churn_date, pen.activation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1

    
    --D2D--

    WHEN trans.canal IN ('D2D','D2N','DEM') AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 180 THEN comision * -1

  
   

     -- CARTERA OUTBOUND--

     
     when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) not like '%_eg%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN (trans.comision * -1)
     when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) not like '%_eg%' AND DATE_DIFF (churn_date, pen.activation_date, DAY) BETWEEN 61 AND 120 THEN (trans.comision * 0.75) * -1
     when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) not like '%_eg%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)BETWEEN 121 AND 180 THEN (trans.comision * 0.5) * -1
     when  tenant_code IN ('energygo','yoigo') and trans.canal = 'XS' and lower(trans.seller) like '%_eg%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN (trans.comision * -1)
    
    

     
          
     when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) not like '%_me%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN (trans.comision * -1)
     when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) not like '%_me%' AND DATE_DIFF (churn_date, pen.activation_date, DAY) BETWEEN 61 AND 120 THEN (trans.comision * 0.75) * -1
     when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) not like '%_me%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)BETWEEN 121 AND 180 THEN (trans.comision * 0.5) * -1
     when  tenant_code= 'masmovil' and trans.canal = 'XS' and lower(trans.seller) like '%_me%' AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 60 THEN (trans.comision * -1)

   --DISTRIBUCION ONLINE--
    
    WHEN trans.canal IN('DO','DON','OU','OUN') AND DATE_DIFF (churn_date, pen.activation_date, DAY)<= 90 THEN comision * -1
  ELSE
  0
END
  AS COMISION,
  trans.id_comisionista,
  trans.distribuidor,
  trans.id_comisionista AS sfid_id,
  trans.seller,
  trans.nombre_comercio,
  trans.razon_social,
  trans.cif,
  trans.zona_fiscal,
  trans.marca,
  trans.service_type,
  trans.phone_nm,
  trans.tariff_id,
  trans.tariff_ds,
  trans.service_id,
  trans.account_id,
  trans. customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
  trans.sale_date,
  trans.activation_date,
  churn_date AS deactivation_date,
  trans.order_id,
  trans.order_type_agg,
  trans.cod_segmento,
  trans.cod_tipo_contrato,
  trans.cod_producto,
  trans.cod_marca,
  cast (null as string) as claim_code,
  trans.campaign_code,
  trans.serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
  trans.facturador,
  'calculado' AS estado
FROM (
  SELECT
    canal,
    id,
    unique_id,
    T.concepto,
    tenant_code,
    cups_code,
    L.activation_date,
    churn_date
  FROM
    `mm-datamart-kd.ENERGY.lucera_polissas_gas` L
  INNER JOIN
    `mm-commissions-reporting.COMISIONES.transacciones` T
  ON
    CAST(L.cups_code AS STRING) = T.account_id  
  WHERE
    ((DATE_TRUNC(DATE(L.churn_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING))
        AND T.canal IN ('EYG',
          'EML',
          'ENX',
          'MI',
          'ALTN',
          'ST',
          'ALTNC',
          'ALTNH',
          'MP',
          'PH',
          'CA',
          'D2D',
          'D2N',
          'DEM',
          'XI',
          'WA')
        AND DATE_DIFF (L.churn_date, L.activation_date, DAY)< 180)
      AND T.concepto NOT LIKE ('%Claw%')
      AND concepto NOT IN ( 'D - Rappel Fijo_B',
        'D - Apoyo Coche',
        'B - SVE')
      AND tipo_concepto= 'CSEN'
      AND concepto IS NOT NULL)

    OR ( (DATE_TRUNC(DATE(L.churn_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING))
        AND T.canal IN ('DO','OU')
        AND DATE_DIFF (L.churn_date, L.activation_date, DAY)< 90)
      AND T.concepto NOT LIKE ('%Claw%')
      AND concepto NOT IN ( 'D - Rappel Fijo_B',
        'D - Apoyo Coche',
        'B - SVE')
      AND tipo_concepto= 'CSEN'
      AND concepto IS NOT NULL)

    OR (DATE_TRUNC(DATE(L.churn_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING))
      AND T.canal IN ('XS')
      AND DATE_DIFF (L.churn_date, L.activation_date, DAY)< 180)
    AND T.concepto NOT LIKE ('%Claw%')
    AND concepto NOT IN ( 'D - Rappel Fijo_B',
      'D - Apoyo Coche',
      'B - SVE')
    AND tipo_concepto= 'CSEN'
    AND concepto IS NOT NULL
  QUALIFY
    ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING)
    ORDER BY
      T.concepto DESC ) = 1 ) pen
INNER JOIN
  `mm-commissions-reporting.COMISIONES.transacciones` trans
ON
  CAST(pen.id AS STRING) = trans.service_id
WHERE
  trans.concepto IN ('B - Gas',
    'F - Gestion de canal gas',
    'D - Multiplicador gas')
)
where comision != 0

UNION ALL

 select * from (
SELECT
  id_mes_claw AS id_mes,
  prefijo||'C_sve'||id_mes_claw||'_'||trans.canal||'_'||row_number () OVER () AS commission_id,
  trans.canal,
  trans.agrupacion_canal,
  COD_CANAL,
  CASE
    WHEN trans.concepto = 'B - SVE' THEN 'E - Clawback SVE'
    WHEN trans.concepto = 'F - Gestion de canal SVE' THEN 'H - Clawback Gestion de canal sve' --si
    
END
  AS concepto,
  'CSEN' AS tipo_concepto,
  1 AS unidades,
  CASE

    WHEN trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','XO','XOF','WA') AND DATE_DIFF (churn_date ,pen.activation_date, DAY)<= 60 THEN comision * -1
    WHEN trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','XO','XOF','WA') AND DATE_DIFF (churn_date , pen.activation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1
    WHEN trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','XO','XOF','WA') AND DATE_DIFF (churn_date , pen.activation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1


    
    --D2D--
    WHEN trans.canal = 'D2D' AND DATE_DIFF (churn_date , pen.activation_date, DAY)<= 180 THEN comision * -1
    WHEN trans.canal = 'D2N' AND DATE_DIFF (churn_date , pen.activation_date, DAY)<= 180 THEN comision * -1
    WHEN trans.canal = 'DEM' AND DATE_DIFF (churn_date , pen.activation_date, DAY)<= 180 THEN comision * -1
  
     -- CARTERA OUTBOUND--

    WHEN trans.canal = 'XS' AND DATE_DIFF (churn_date , pen.activation_date, DAY)<= 60 THEN comision * -1
    
    --DISTRIBUCION ONLINE--
    
    WHEN trans.canal in ('DO','DON') AND DATE_DIFF (churn_date , pen.activation_date, DAY)<= 90 THEN comision * -1
    WHEN trans.canal in ('OU','OUN')  AND DATE_DIFF (churn_date , pen.activation_date, DAY)<= 90 THEN comision * -1
  ELSE
  0
END
  AS COMISION,
  trans.id_comisionista,
  trans.distribuidor,
  trans.id_comisionista AS sfid_id,
  trans.seller,
  trans.nombre_comercio,
  trans.razon_social,
  trans.cif,
  trans.zona_fiscal,
  trans.marca,
  trans.service_type,
  trans.phone_nm,
  trans.tariff_id,
  trans.tariff_ds,
  trans.service_id,
  trans.account_id,
  trans.customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
  trans.activation_date as sale_date,
  trans.activation_date as activation_date,
  churn_date AS deactivation_date,
  trans.order_id,
  trans.order_type_agg,
  trans.cod_segmento,
  trans.cod_tipo_contrato,
  trans.cod_producto,
  trans.cod_marca,
  cast (null as string) as claim_code,
  trans.campaign_code,
  trans.serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
  trans.facturador,
  'calculado' AS estado
FROM (
  SELECT
    T.service_id, 
    T.canal,
    L.cups_code,
    T.account_id,
    T.concepto,
    tenant_code,
    T.account_id,
    L.activation_date,
    L.churn_date
  FROM
    `mm-new-business-reporting.ENERGY.SVE` L
  INNER JOIN
    `mm-commissions-reporting.COMISIONES.transacciones` T
  ON
    L.cups_code = T.account_id
  WHERE
  L.product = 'SVE'

    and ((DATE_TRUNC(DATE(L.churn_date), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING))
        AND T.canal IN ('EYG',
          'EML',
          'ENX',
          'MI',
          'MR',
          'ALTN',
          'ST',
          'ALTNC',
          'ALTNH'
          'MP',
          'PH',
          'CA',
          'D2D',
          'D2N',
          'XS',
          'DEM',
          'XI',
          'WA')
        AND DATE_DIFF (L.churn_date, L.activation_date, DAY)< 180)
      AND T.concepto NOT LIKE ('%Claw%')
      AND concepto NOT IN ( 'D - Rappel Fijo_B',
        'D - Apoyo Coche',
        'B - SVE')
      AND tipo_concepto= 'CSEN'
      AND concepto IS NOT NULL)
  QUALIFY
    ROW_NUMBER() OVER (PARTITION BY CAST(L.cups_code AS STRING)
    ORDER BY
      T.concepto DESC ) = 1 ) pen
INNER JOIN
  `mm-commissions-reporting.COMISIONES.transacciones` trans
ON
  pen.cups_code = trans.account_id
WHERE
  trans.concepto = 'B - SVE'    
)
where comision != 0



UNION ALL

 select * from (
SELECT id_mes_claw AS id_mes,
prefijo||'C_svg'||id_mes_claw||'_'||trans.canal||'_'||row_number () OVER () AS commission_id,
  trans.canal,
  trans.agrupacion_canal,
  COD_CANAL,
  CASE
    WHEN trans.concepto = 'B - SVG' THEN 'E - Clawback SVG'
    WHEN trans.concepto in ('F - Gestion decanal SVG','F - Gestion de canal SVG') THEN 'H - Clawback Gestion de canal svg'
    
END
  AS concepto,
  'CSEN' AS tipo_concepto,
  1 AS unidades,                       
  CASE

  

    WHEN trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','WA') AND DATE_DIFF (pen.data_fi , pen.data_inici, DAY)<= 60 THEN comision * -1
    WHEN trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','WA')  AND DATE_DIFF (pen.data_fi ,  pen.data_inici, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1
    WHEN trans.canal IN ('EYG','EML','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','MP','PH','CA','XI','WA')  AND DATE_DIFF (pen.data_fi ,  pen.data_inici, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1
    
    --D2D--
    WHEN trans.canal IN ('D2D','D2N','DEM') AND DATE_DIFF (pen.data_fi ,  pen.data_inici, DAY)<= 180 THEN comision * -1

       -- CARTERA OUTBOUND--
    
      WHEN trans.canal = 'XS' AND DATE_DIFF (pen.data_fi, pen.data_inici, DAY)<= 60 THEN trans.comision * -1
         --DISTRIBUCION ONLINE--
    
    WHEN trans.canal in ('DO','DON') AND DATE_DIFF (pen.data_fi ,  pen.data_inici, DAY)<= 90 THEN comision * -1
  ELSE
  0
END
  AS COMISION,
  trans.id_comisionista,
  trans.distribuidor,
  trans.id_comisionista AS sfid_id,
  trans.seller,
  trans.nombre_comercio,
  trans.razon_social,
  trans.cif,
  trans.zona_fiscal,
  trans.marca,
  trans.service_type,
  trans.phone_nm,
  trans.tariff_id,
  trans.tariff_ds,
  trans.service_id,
  trans.account_id,
  trans.customer_id,
CAST(NULL AS STRING) AS line_type_ds,
CAST(NULL AS STRING) AS bundle_type,
CAST(NULL AS STRING) AS technology_ds,
CAST(NULL AS STRING) AS billing_type_ds,
  trans.activation_date as sale_date,
  trans.activation_date as activation_date,
  pen.data_fi AS deactivation_date,
  trans.order_id,
  trans.order_type_agg,
  trans.cod_segmento,
  trans.cod_tipo_contrato,
  trans.cod_producto,
  trans.cod_marca,
  cast (null as string) as claim_code,
  trans.campaign_code,
  trans.serial_number,
cast ( null as float64 ) tax_base,
cast (null as string) as process_code,
cast (null as string) as comments,
  trans.facturador,
  'calculado' AS estado FROM (

SELECT
  A.cups_code, A.sfid_id, B.data_inici,B.data_fi, D.canal
  FROM
  `mm-new-business-reporting.ENERGY.ganancia_neta_energia` A
INNER JOIN
  `mm-datamart-kd.ENERGY.lucera_gas_additional_services` B
ON
  A.id = B.polissa_id
LEFT JOIN
  `mm-commissions-reporting.COMISIONES.v_dealer` C
ON
  UPPER(author_id) = C.sfid_id
  OR A.sfid_id = C.sfid_id
  OR (SUBSTRING(UPPER(A.author_id),1,2)) = C.sfid_id
  OR (SUBSTRING(UPPER(A.author_id),1,2)) = C.id_comisionista
  OR UPPER(SPLIT(a.author_id,'@')[
  OFFSET
    (0)]) = C.sfid_id
  OR UPPER(SPLIT(a.author_id,'@')[
  OFFSET
    (0)]) =C.id_comisionista
INNER JOIN
  `mm-commissions-reporting.GS.CANALES` D
ON
  D.CANAL=C.CANAL
WHERE
  DATE_TRUNC(DATE(B.data_fi), MONTH) = PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING))
  AND C.canal IS NOT NULL
  AND product = 'SVG'
  AND tenant_code IN ('masmovil_svg',
    'energygo_svg',
    'yoigo_svg',
    'pepe_svg')
  AND subchannel_ds NOT IN ('WEB',
    'SERVICES2SALES',
    'CANCELACIONES',
    'RECUPERADAS_AN',
    'PLAT. FIDELIZACION/RETENCION')
   QUALIFY  ROW_NUMBER() OVER (PARTITION BY A.id ORDER BY A.sfid_id DESC ) = 1 ) pen
 inner join `mm-commissions-reporting.COMISIONES.transacciones` trans 
  on pen.cups_code = trans.account_id 
WHERE trans.concepto = 'B - SVG'
)
where comision != 0 

-- SE INCLUYE CLAWBACKS EN PROCESO DE ALARMAS, COMENTAMOS LAS LÍNEAS
/*
UNION ALL
select * from (
select 
id_mes_claw as id_mes,
prefijo||'E-Clal'||id_mes_claw||'_'||canal||'_'||row_number () over () as commission_id,
tr.canal,
tr.agrupacion_canal,
tr.COD_CANAL,
case when concepto in ('B - alarmas', 'B - Alarmas') then 'E - Clawback Alarmas' 
     when concepto = 'F - Gestion Canal Alarmas' then 'H - Clawback Gestion de canal alarmas'
     when concepto = 'D - Rappel alarma' then 'E - Clawback Rappel alarma'
end 
as concepto,  
'ALRM' as tipo_concepto,
1 as unidades,
case 

when canal IN ('XI','EYG','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','EML','MP','PH')   AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 60 THEN comision * -1
when canal IN ('XI','EYG','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','EML','MP','PH')   AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1
when canal IN ('XI','EYG','ENX','MI','MR','ALTN','ST','ALTNC','ALTNH','EML','MP','PH')   AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1

when canal  = 'XS' and concepto = 'D - Rappel alarma' AND DATE_DIFF (fecha_baja_contrato, tr.activation_date, DAY)<= 60 THEN comision * -1
when canal  = 'XS' and concepto = 'D - Rappel alarma' AND DATE_DIFF (fecha_baja_contrato, tr.activation_date, DAY) BETWEEN 61 AND 120 THEN (comision * 0.75) * -1
when canal  = 'XS' and concepto = 'D - Rappel alarma' AND DATE_DIFF (fecha_baja_contrato, tr.activation_date, DAY)BETWEEN 121 AND 180 THEN (comision * 0.5) * -1

when canal = 'D2D'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 180 THEN comision * -1
when canal = 'D2N'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 180 THEN comision * -1
when canal = 'DEM'  AND DATE_DIFF (fecha_baja_contrato, installation_date, DAY)<= 180 THEN comision * -1

else 0
END AS COMISION,


tr.id_comisionista,
tr.distribuidor,
tr.sfid_id,
tr.seller,
tr.nombre_comercio,
tr.razon_social,
tr.cif,
tr.zona_fiscal,
tr.marca,
tr.service_type,
tr.phone_nm,
tr.tariff_id,
tr.tariff_ds,
tr.service_id,
tr.account_id,
tr.customer_id,
tr.line_type_ds,
tr.bundle_type,
tr.technology_ds,
tr.billing_type_ds,
tr.sale_date,
tr.activation_date,
al.fecha_baja_contrato as deactivation_date,
tr.order_id,
tr.order_type_agg,
tr.cod_segmento,
tr.cod_tipo_contrato,
tr.cod_producto,
tr.cod_marca,
tr.claim_code,
tr.campaign_code,
cast ( null as string ) as serial_number,
cast ( null as float64 ) as tax_base,
tr.process_code,
tr.comments,
'C_MANUAL' as facturador,
'calculado' as estado
from  `mm-new-business-reporting.ALARMAS.alarmas_ventas_canales` al
left join `mm-commissions-reporting.COMISIONES.transacciones` tr 
on tr.phone_nm = al.phone_nm
where tipo_concepto = 'ALRM'
and ot_status  in('INSTALADA')
AND DATE_TRUNC(DATE(fecha_baja_contrato), MONTH) =  PARSE_DATE('%Y%m', CAST(id_mes_claw AS STRING))
and DATE_DIFF (fecha_baja_contrato, installation_date, DAY)< 180 
and sfid_subchannel NOT IN ('PLAT. FIDELIZACION/RETENCION')
and comision is not null
and not (concepto = 'E - Clawback Alarmas')
and comision != 0
and substring(matricula,1,5) not in ('DP749','DP751','DP750','DP768' )
)
where comision != 0 and concepto is not null
*/

)
;

CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.CLAWB_SVAS_FINAL` AS (
  SELECT * 
  FROM `mm-commissions-reporting.TEMP.CLAWB_SVAS`
  CROSS JOIN UNNEST(canales_pr) AS canal_pr
  WHERE canal = canal_pr
)
;

CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CLAWB_',id_mes_pr,canales_pr,'TEMP.CLAWB_SVAS_FINAL','ACTUALIZAR');

--CALL `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` ('CLAWB_',id_mes_pr,(SELECT ARRAY_AGG(DISTINCT canal) FROM TEMP.CLAWB_SVAS),'TEMP.CLAWB_SVAS','ACTUALIZAR')

END