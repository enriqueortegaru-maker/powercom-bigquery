BEGIN

-- CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_plantilla_thadea_tlv_negocios`(202608);

CREATE OR REPLACE TABLE `mm-commissions-reporting.60_EDW_DELIVERABLES.plantilla_thadea_tlv_negocios` AS (
SELECT 
 T.id_comisionista  AS SFID
,CASE WHEN T.CANAL IN ('OSPNIN','OSPNBO') THEN T.concepto 
      WHEN T.canal IN ('OSPNXSN','OSPNOUN') AND T.commission_id LIKE 'RPXS%' THEN
            CASE 
             WHEN T.claim_code IN ('Servicio Fijo','Servicio Movil Pospago')  THEN 'C_ALTA_PTF'
             WHEN T.claim_code IN ('Seguro Movil','Television')               THEN 'C_ALTA_SVA_PTF'
             WHEN T.claim_code IN ('Renuevo')                                 THEN 'C_ALTA_RENOVE_PTF'
             WHEN T.claim_code IN ('Energia')                                 THEN 'C_ALTA_LUZ_PTF'
             WHEN T.claim_code IN ('Gas')                                     THEN 'C_ALTA_GAS_PTF'
             ELSE C.CONCEPTO_THADEA 
             END
      WHEN T.canal IN ('OSPNXSN','OSPNOUN') THEN C.CONCEPTO_THADEA
END AS IDConcepto
,mes_liquidado AS FechaCompensacion
,ROUND(comision,4) AS Value
,CAST (NULL AS STRING) AS UsuarioCarga
,CAST (NULL AS STRING) AS UsuarioAjuste
,CASE WHEN tipo_concepto = 'CSEN' AND T.marca = 'JAZZTEL' THEN 'JAZZTEL_ENERGIA'
      WHEN tipo_concepto = 'CSEN' AND T.marca = 'ORANGE' THEN 'ORANGE_ENERGIA'
      WHEN tipo_concepto = 'ALRM'                         THEN 'MASORANGE_ALARMAS'
  ELSE T.marca
  END as Marca
,CASE WHEN T.cod_segmento = '10' then 'RESIDENCIAL' ELSE 'EMPRESA' END AS Mercado
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
      WHEN T.concepto LIKE '%Netflix%' AND T.marca = 'SIMYO' THEN 'FIJO'
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
,CASE WHEN T.CANAL IN ('OSPNBO','OSPNIN') THEN 'PLATAFORMA_INBOUND'
                      WHEN T.CANAL IN ('OSPNXSN','OSPNOUN')       THEN 'PLATAFORMA_OUTBOUND'
                      END AS Canal
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
LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS_TLV_NEGOCIOS_THADEA` C
ON T.concepto = C.CONCEPTO

LEFT JOIN `mm-commissions-reporting.GS.tlv_do_dealers` DEALERS
ON T.id_comisionista = DEALERS.id_comisionista

LEFT JOIN `mm-commissions-reporting.GS.CUENTAS_CONTABLES_THADEA` CONT
ON  UPPER(CASE WHEN T.CANAL IN ('OSPNIN','OSPNBO') THEN T.concepto 
               WHEN T.canal IN ('OSPNXSN','OSPNOUN') AND T.commission_id LIKE 'RPXS%' THEN
                  CASE 
                  WHEN T.claim_code IN ('Servicio Fijo','Servicio Movil Pospago')  THEN 'C_ALTA_PTF'
                  WHEN T.claim_code IN ('Seguro Movil','Television')               THEN 'C_ALTA_SVA_PTF'
                  WHEN T.claim_code IN ('Renuevo')                                 THEN 'C_ALTA_RENOVE_PTF'
                  WHEN T.claim_code IN ('Energia')                                 THEN 'C_ALTA_LUZ_PTF'
                  WHEN T.claim_code IN ('Gas')                                     THEN 'C_ALTA_GAS_PTF'
                  ELSE C.CONCEPTO_THADEA 
                  END
            WHEN T.canal IN ('OSPNXSN','OSPNOUN') THEN C.CONCEPTO_THADEA
            END) = CONT.Concepto

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
      WHEN T.concepto LIKE '%Netflix%' AND T.marca = 'SIMYO' THEN 'FIJO'
      WHEN T.service_type IN ('NETFLIX','MAX','DISNEY','AMAZON PRIME') AND T.MARCA = 'ORANGE' THEN 'MOVIL'
  END = CONT.Tecnologia

AND CONT.CANAL = CASE WHEN T.CANAL IN ('OSPNBO','OSPNIN') THEN 'PLATAFORMA_INBOUND'
                      WHEN T.CANAL IN ('OSPNXSN','OSPNOUN')       THEN 'PLATAFORMA_OUTBOUND'
                      END

WHERE agrupacion_canal = 'TLV - Negocios'
AND id_mes  = id_mes_pr
AND T.MARCA IN ('JAZZTEL','SIMYO','ORANGE')
-- AND T.ESTADO = 'rechazado'
AND T.canal IN ('OSPNBO','OSPNIN','OSPNXSN','OSPNOUN')
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY 
    T.commission_id

) = 1)
;

END