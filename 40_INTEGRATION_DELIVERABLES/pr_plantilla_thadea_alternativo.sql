BEGIN

-- CALL `mm-commissions-reporting.40_INTEGRATION_DELIVERABLES.pr_plantilla_thadea_alternativo`(202609);


CREATE OR REPLACE TABLE `mm-commissions-reporting.60_EDW_DELIVERABLES.plantilla_thadea_alternativo` AS (
SELECT 

 CASE WHEN T.CONCEPTO LIKE 'F -%' OR T.CONCEPTO LIKE 'H -%' OR T.CONCEPTO LIKE 'Y -%' THEN OPTICO.sfid_distribuidor
      WHEN T.CONCEPTO LIKE 'G -%' THEN T.id_comisionista
      ELSE '39990114' 
 END AS SFID
-- ,C.CONCEPTO_THADEA AS IDConcepto
, T.CONCEPTO AS IDConcepto
,mes_liquidado AS FechaCompensacion --- CAMBIAR POR MES ACTUAL, EN EL CASO DE REGULARIZACION PONER EN NOTAS ADV
,comision AS Value
,CAST (NULL AS STRING) AS UsuarioCarga
,CAST (NULL AS STRING) AS UsuarioAjuste
,CASE WHEN tipo_concepto = 'CSEN' AND T.marca = 'JAZZTEL' THEN 'JAZZTEL_ENERGIA'
  ELSE T.marca
  END as Marca
,CASE WHEN T.CONCEPTO LIKE '%Extra SOHO%' THEN 'EMPRESA' ELSE 'RESIDENCIAL' END AS Mercado
,CASE WHEN billing_type_ds = 'PREPAID' THEN 'PREPAGO' 
      ELSE 'POSPAGO'
      END AS Contrato
,CASE WHEN tipo_concepto = 'CSEN'      THEN 'GENERICO'
      WHEN service_type = 'INTERNET'  THEN 'FIJO'
      WHEN service_type = 'MOBILE'    THEN 'MOVIL'
      WHEN phone_nm LIKE '6%' THEN 'MOVIL'
      WHEN phone_nm LIKE '7%' THEN 'MOVIL'
      WHEN phone_nm LIKE '9%' THEN 'FIJO'
      WHEN phone_nm LIKE '8%' THEN 'FIJO'
  END AS Tecnologia
,CASE WHEN C.CONCEPTO_THADEA = 'C_CONSUMO' THEN 'NA'
      WHEN phone_nm IS NULL THEN 'NA'
      ELSE t.phone_nm
  END AS MSISDN
,serial_number AS IMEI
,CASE WHEN T.TIPO_CONCEPTO = 'CSEN' THEN T.account_id
      ELSE T.order_id END AS NumPedido
,OPTICO.sfid_unico AS CodContrato
,T.concepto || '#'||commission_id AS Comentario
,CONT.PEP
,'' AS Canal
,CONT.EventoContexto AS IDEventoContexto
,CAST (NULL AS STRING) AS NumeroReclamacion	
,CAST (NULL AS STRING) AS ReclamacionCasoID
,commission_id AS NOTASADV
,CASE WHEN T.CONCEPTO LIKE 'Z -%' THEN 'Y' 
      WHEN T.CONCEPTO LIKE 'Y -%' THEN 'Y' ELSE 'M' END AS TIPO --- CUANDO ES DEL CICLO ES M, INCIDENCIA DE COMISIONES Y , R INCIDENCIA DE OTROS, C INCIDENCIA EN EL DATA
,CAST (NULL AS STRING) AS IDFiscalCliente
,T.claim_code
,commission_id
,T.id_comisionista
,t.sfid_id
,T.seller
,C.CONCEPTO_THADEA

FROM `mm-commissions-reporting.COMISIONES.transacciones` T
LEFT JOIN `mm-commissions-reporting.GS.ALTERNATIVO_CONCEPTOS_THADEA` C
ON T.concepto = C.CONCEPTO

LEFT JOIN (SELECT * FROM `mm-commissions-reporting.TEMP.nex_optico_final` GROUP BY ALL) OPTICO
ON (T.sfid_id = OPTICO.sfid OR T.seller = OPTICO.sfid)
AND OPTICO.CHANNEL = 'ALTERNATIVO'
-- AND OPTICO.ESTADO = 'ACTIVO'
AND UPPER(OPTICO.marco_retributivo) != 'NORMAL'

LEFT JOIN `mm-commissions-reporting.GS.CUENTAS_CONTABLES_THADEA` CONT
ON  UPPER(T.concepto) = CONT.Concepto

AND CASE WHEN tipo_concepto = 'CSEN' AND T.marca = 'JAZZTEL' THEN 'JAZZTEL_ENERGIA'
         WHEN tipo_concepto = 'CSEN' AND T.marca = 'ORANGE' THEN 'ORANGE_ENERGIA'
         WHEN tipo_concepto = 'ALRM'                         THEN 'MASORANGE_ALARMAS'
         ELSE T.marca END = CONT.MARCA

AND CONT.MERCADO = CASE WHEN T.CONCEPTO LIKE '%Extra SOHO%' THEN 'EMPRESA' ELSE 'RESIDENCIAL' END

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

AND CONT.CANAL = 'ALTERNATIVO'

WHERE T.canal = 'ALTN'
AND id_mes  = id_mes_pr
AND T.MARCA IN ('JAZZTEL','SIMYO','ORANGE')

AND T.CONCEPTO NOT IN (

'D - Extracomision Volumen Movil',
'D - Rappel Lotes',
'F - Acelerador Eficiencia Comercial',
'F - Consecucion Incentivo',
'F - Extracomision Volumen Movil',
'Z - Rappel Lotes',
'D - Objetivo Supreme',
'Z - Objetivo Supreme',
'D - Extra Objetivo Supreme',
'D - Incentivo Lotes Fijo',
'Y - Extracomision Volumen Movil',
'D - Extra Imagen Supreme',
'D - Imagen Supreme',
'D - Incentivo Tactico'
)


GROUP BY ALL )

;

END