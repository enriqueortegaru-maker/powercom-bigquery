BEGIN

-- CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_plantilla_thadea_tlv_web`(202608);

CREATE OR REPLACE TABLE `mm-commissions-reporting.60_EDW_DELIVERABLES.plantilla_thadea_tlv_web` AS (
SELECT 
 T.id_comisionista  AS SFID
,T.concepto AS IDConcepto
,mes_liquidado AS FechaCompensacion
,ROUND(comision,2) AS Value
,CAST (NULL AS STRING) AS UsuarioCarga
,CAST (NULL AS STRING) AS UsuarioAjuste
,CASE WHEN tipo_concepto = 'CSEN' AND T.marca = 'JAZZTEL' THEN 'JAZZTEL_ENERGIA'
      WHEN tipo_concepto = 'CSEN' AND T.marca = 'ORANGE'  THEN 'ORANGE_ENERGIA'
      WHEN tipo_concepto = 'ALRM'                         THEN 'MASORANGE_ALARMAS'
  ELSE T.marca
  END as Marca
,CASE WHEN T.cod_segmento = '12' THEN 'EMPRESA' ELSE 'RESIDENCIAL' END AS Mercado
,CASE WHEN billing_type_ds = 'PREPAID' THEN 'PREPAGO' 
      ELSE 'POSPAGO'
      END AS Contrato
,CASE WHEN tipo_concepto = 'CSEN'      THEN 'GENERICO'
      WHEN tipo_concepto = 'ALRM'      THEN 'GENERICO'
      WHEN service_type = 'INTERNET'  THEN 'FIJO'
      WHEN service_type = 'TV'  THEN 'FIJO'
      WHEN service_type = 'MOBILE'    THEN 'MOVIL'
      WHEN service_type = 'INSURANCE'    THEN 'MOVIL'
      WHEN T.concepto = 'E - Clawback OTT' THEN 'MOVIL'
      WHEN T.service_type IN ('NETFLIX','MAX','DISNEY','AMAZON PRIME') AND T.MARCA = 'ORANGE' THEN 'MOVIL'
  END AS Tecnologia
,CASE WHEN C.CONCEPTO_THADEA = 'C_CONSUMO' THEN 'NA'
      WHEN phone_nm IS NULL THEN 'NA'
      ELSE t.phone_nm 
      END AS MSISDN
,COALESCE(serial_number, '') AS IMEI
,ORDER_ID AS NumPedido
, CASE WHEN T.CONCEPTO LIKE 'F -%' OR T.CONCEPTO LIKE 'H -%' OR T.CONCEPTO LIKE 'Y -%' THEN NULL 
      ELSE order_id 
  END AS CodContrato
, CASE WHEN T.CONCEPTO LIKE 'P -%' THEN T.concepto ||' '||T.claim_code 
-- WHEN T.CONCEPTO LIKE 'Z - Servicio Movil Pospago' THEN T.concepto ||' '||T.claim_code
ELSE T.concepto END AS Comentario
,CONT.PEP
,'PLATAFORMA_INBOUND'  AS Canal
,CONT.EventoContexto AS IDEventoContexto
,CAST (NULL AS STRING) AS NumeroReclamacion	
,CAST (NULL AS STRING) AS ReclamacionCasoID
,commission_id AS NOTASADV
,CASE WHEN T.CONCEPTO LIKE 'Z -%' THEN 'R' ELSE 'M' END AS TIPO
,CAST (NULL AS STRING) AS IDFiscalCliente
,CLAIM_CODE
,C.CONCEPTO_THADEA AS CONCEPTO_THADEA
,T.commission_id

FROM `mm-commissions-reporting.COMISIONES.transacciones` T
LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS_TLV_WEB_THADEA` C
ON T.concepto = C.CONCEPTO

LEFT JOIN `mm-commissions-reporting.GS.tlv_do_dealers` DEALERS
ON T.id_comisionista = DEALERS.id_comisionista


LEFT JOIN `mm-commissions-reporting.GS.CUENTAS_CONTABLES_THADEA` CONT
ON  UPPER(T.concepto) = CONT.Concepto

AND CASE WHEN tipo_concepto = 'CSEN' AND T.marca = 'JAZZTEL' THEN 'JAZZTEL_ENERGIA'
         WHEN tipo_concepto = 'CSEN' AND T.marca = 'ORANGE' THEN 'ORANGE_ENERGIA'
         WHEN tipo_concepto = 'ALRM'                         THEN 'MASORANGE_ALARMAS'
         ELSE T.marca END = CONT.MARCA

AND CONT.MERCADO = CASE WHEN T.cod_segmento = '12' THEN 'EMPRESA' ELSE 'RESIDENCIAL' END

AND CASE WHEN T.billing_type_ds = 'PREPAID' THEN 'PREPAGO' 
          ELSE 'POSPAGO' END = CONT.Contrato

AND CASE WHEN tipo_concepto = 'CSEN'      THEN 'GENERICO'
      WHEN tipo_concepto = 'ALRM'      THEN 'GENERICO'
      WHEN service_type = 'INTERNET'  THEN 'FIJO'
      WHEN service_type = 'TV'  THEN 'FIJO'
      WHEN service_type = 'MOBILE'    THEN 'MOVIL'
      WHEN service_type = 'INSURANCE'    THEN 'MOVIL'
      WHEN T.concepto = 'E - Clawback OTT' THEN 'MOVIL'
      WHEN T.service_type IN ('NETFLIX','MAX','DISNEY','AMAZON PRIME') AND T.MARCA = 'ORANGE' THEN 'MOVIL'
  END = CONT.Tecnologia

AND CONT.CANAL = 'PLATAFORMA_INBOUND'

WHERE agrupacion_canal = 'TLV - Web'
AND id_mes  = id_mes_pr
AND T.MARCA IN ('JAZZTEL','SIMYO','ORANGE')
-- AND ESTADO = 'rechazado
AND T.concepto !='D - Camp. Horas'
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY 
    T.commission_id
  ORDER BY T.id_comisionista
) = 1)
;

END