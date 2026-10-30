BEGIN

-- CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_plantilla_thadea_tlv_crossell`(202609);

CREATE OR REPLACE TABLE `mm-commissions-reporting.60_EDW_DELIVERABLES.plantilla_thadea_tlv_crosssell` AS (
SELECT 
 T.id_comisionista  AS SFID
,CASE WHEN T.CANAL IN ('XI','XIBO') THEN T.concepto 
      WHEN T.canal IN ('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') AND T.commission_id LIKE '%RPXS%' THEN
            CASE 
             WHEN T.claim_code IN ('Servicio Fijo','Servicio Movil Pospago')  THEN 'C_ALTA_PTF'
             WHEN T.claim_code IN ('Seguro Movil','Television')               THEN 'C_ALTA_SVA_PTF'
             WHEN T.claim_code IN ('Renuevo')                                 THEN 'C_ALTA_RENOVE_PTF'
             WHEN T.claim_code IN ('Energia')                                 THEN 'C_ALTA_LUZ_PTF'
             WHEN T.claim_code IN ('Gas')                                     THEN 'C_ALTA_GAS_PTF'
             ELSE C.CONCEPTO_THADEA 
             END
      WHEN T.canal IN ('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') THEN C.CONCEPTO_THADEA
END AS IDConcepto
-- ,mes_liquidado AS FechaCompensacion
,'2026-09-01' AS FechaCompensacion
,ROUND(comision,4) AS Value
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
ELSE T.concepto END AS Comentario
,CONT.PEP
, CASE WHEN T.CANAL IN ('XI','XIBO') THEN 'PLATAFORMA_INBOUND' 
      WHEN T.CANAL IN ('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') THEN 'PLATAFORMA_OUTBOUND'
 END AS Canal
,CONT.EventoContexto AS IDEventoContexto
,CAST (NULL AS STRING) AS NumeroReclamacion	
,CAST (NULL AS STRING) AS ReclamacionCasoID
,commission_id AS NOTASADV
,CASE WHEN T.CONCEPTO LIKE 'Z -%' THEN 'R' ELSE 'M' END AS TIPO
,CAST (NULL AS STRING) AS IDFiscalCliente
,CLAIM_CODE
,CASE WHEN T.CANAL IN ('XI','XIBO') THEN C.CONCEPTO_THADEA
      WHEN T.CANAL IN ('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') THEN T.concepto
END AS CONCEPTO_THADEA
,T.commission_id


FROM `mm-commissions-reporting.COMISIONES.transacciones` T
-- FROM `mm-commissions-reporting.TEMP.base_comisiones_final_outbound_OSP` T
LEFT JOIN `mm-commissions-reporting.GS.CONCEPTOS_TLV_CROSSELL_THADEA` C
ON T.concepto = C.CONCEPTO
AND T.canal = C.CANAL

LEFT JOIN `mm-commissions-reporting.GS.CUENTAS_CONTABLES_THADEA` CONT
ON  UPPER(CASE WHEN T.CANAL IN ('XI','XIBO') THEN T.concepto 
              WHEN T.canal IN('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') AND T.service_type IN ('NETFLIX','MAX','DISNEY','AMAZON PRIME') THEN T.concepto
              WHEN T.canal IN('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') AND T.commission_id LIKE '%RPXS%' THEN
                        CASE 
                        WHEN T.claim_code IN ('Servicio Fijo','Servicio Movil Pospago')  THEN 'C_ALTA_PTF'
                        WHEN T.claim_code IN ('Seguro Movil','Television')               THEN 'C_ALTA_SVA_PTF'
                        WHEN T.claim_code IN ('Renuevo')                                 THEN 'C_ALTA_RENOVE_PTF'
                        WHEN T.claim_code IN ('Energia')                                 THEN 'C_ALTA_LUZ_PTF'
                        WHEN T.claim_code IN ('Gas')                                     THEN 'C_ALTA_GAS_PTF'
                        ELSE C.CONCEPTO_THADEA 
                        END
                  WHEN T.canal IN ('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') THEN C.CONCEPTO_THADEA
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
      WHEN T.service_type IN ('NETFLIX','MAX','DISNEY','AMAZON PRIME') AND T.MARCA = 'ORANGE' THEN 'MOVIL'
  END = CONT.Tecnologia

AND CONT.CANAL = CASE WHEN T.CANAL IN ('XI','XIBO') THEN 'PLATAFORMA_INBOUND'
                      WHEN T.CANAL IN ('XSO','OUO','OUOC','OUOV','OUOCC','OUOP') THEN 'PLATAFORMA_OUTBOUND'
                      END

LEFT JOIN `mm-commissions-reporting.GS.tlv_cross_sell_dealers` DEALERS
ON T.id_comisionista = DEALERS.id_comisionista

WHERE agrupacion_canal IN ('TLV - Cross-sell','TLV - Outbound')
AND id_mes  = id_mes_pr
AND T.MARCA IN ('JAZZTEL','SIMYO','ORANGE')
-- AND T.canal IN ('XI','XIBO','XSO','OUO','OUOC','OUOV','OUOCC','OUOP')
AND T.claim_code IN ( 'Abono Dispositivos Jazztel 202609', 'Recalculo Dispositivos Jazztel 202609')
-- AND ESTADO = 'rechazado'
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY 
    T.commission_id
  ORDER BY T.id_comisionista

) = 1)
;

END