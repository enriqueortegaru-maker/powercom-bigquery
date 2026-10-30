BEGIN

DECLARE mes_string STRING;

SET mes_string = CAST(id_mes_pr AS STRING);


IF canales_pr IS NULL THEN 
  SET canales_pr = ['D2D','D2N','DEM'];

END IF;

/*
CALL COMISIONES.pr_resumen_bruto_rappel_d2d_insertar (202609, ['D2D','D2N','DEM']);
*/

DELETE FROM `mm-commissions-reporting.TEMP.RESUMEN_BRUTO_RAPPEL_D2D` 
WHERE id_mes = id_mes_pr

;

INSERT INTO `mm-commissions-reporting.TEMP.RESUMEN_BRUTO_RAPPEL_D2D` (

SELECT
  A.id_mes,
  A.canal,
  -- A.marca,
  A.sfid_id AS CODIGO,
  A.razon_social AS DISTRIBUIDOR,
  A.cif AS CIF,
  SUM(CASE 
        WHEN A.CONCEPTO LIKE 'D - Rappel Fijo_%' THEN A.unidades 
        ELSE 0 END) 
  AS INSTALACIONES_CODIGO,
  SUM(CASE 
      WHEN A.CONCEPTO LIKE 'D - Rappel Fijo_%' AND A.tariff_ds like 'Base%' THEN A.unidades 
      ELSE 0 END) 
  AS INSTALACIONES_CENTRALITA,
  FIJO.SERVICIOS AS INSTALACIONES_CIF,
  MAX(CASE 
        WHEN A.concepto LIKE 'D - Rappel Fijo_%' THEN SUBSTR(A.concepto, 17, 1)
        ELSE NULL 
      END) AS  TRAMO,
  C.RANGO_INI AS OBJETIVO,
  MAX(CASE 
        WHEN A.concepto = 'D - Apoyo Coche' THEN COCHES.COCHES
        ELSE 0 
      END) AS COCHES,
  ROUND(SUM(CASE 
        WHEN A.concepto = 'D - Apoyo Coche' THEN A.comision 
        ELSE 0 
      END)) AS CANTIDAD_COCHES,
  SUM(CASE 
        WHEN A.concepto LIKE 'D - Rappel Fijo_%' THEN A.comision 
        ELSE 0 
      END) AS RAPPEL_FIX,
  MAX(CASE 
        WHEN A.concepto = 'P - Penalizacion Venta Telefonica' THEN CONCAT(CAST(ROUND(B.POR_VENTA_TELEFONICA * 100,2) AS STRING), '%')
        ELSE '0'
      END) AS PORCEN_VENTA_TELEFONICA,
  SUM(CASE 
        WHEN A.concepto = 'P - Penalizacion Venta Telefonica' AND A.commission_id LIKE '%PTLF%' THEN A.comision 
        ELSE 0 
      END) AS PENALIZACION_VENTA_TELEFONICA,
  SUM(CASE 
        WHEN A.concepto = 'P - Penalizacion CIF' AND A.commission_id LIKE '%PCIF%' THEN A.comision 
        ELSE 0 
      END) AS PENALIZACION_CIF,
  ROUND(SUM(CASE 
        WHEN A.concepto LIKE 'E - Clawback Apoyo Coche' THEN A.comision 
        ELSE 0 
      END),2) AS CLAWBACK_COCHE,
  ROUND(SUM(CASE 
        WHEN A.concepto LIKE 'E - Clawback Rappel Fijo_%' THEN A.comision 
        ELSE 0 
      END),2) AS CLAWBACK_FIX,
  ROUND(SUM(CASE 
        WHEN A.concepto = 'D - Rappel Objetivo Anual' THEN A.comision 
        ELSE 0 
      END),2) AS INCENTIVO_ANUAL,

  SUM(CASE 
        WHEN A.concepto = 'P - Penalizacion Venta Telefonica' AND A.commission_id LIKE '%RPD2%' THEN A.comision 
        ELSE 0 
      END) AS ANULACION_PENALIZACION_VENTA_TELEFONICA,

  SUM(CASE 
        WHEN A.concepto = 'P - Penalizacion CIF' AND A.commission_id LIKE '%RPD2%' THEN A.comision 
        ELSE 0 
      END) AS ANULACION_PENALIZACION_CIF,
  
  ROUND(SUM(CASE 
            WHEN A.concepto = 'Z - Ajuste Objetivo Rappel' THEN A.comision 
            ELSE 0 
          END)) AS AJUSTE_RAPPEL,
  ROUND(SUM(CASE 
              WHEN A.concepto in('D - Extracomision comercial', 'D - Apoyo Comercial') THEN A.comision 
              ELSE 0 
            END)) AS EXTRACOMISION_COMERCIAL,
  ROUND(SUM(CASE 
              WHEN A.concepto in('P - Penalizacion Objetivo','P - Penalizacion') THEN A.comision 
              ELSE 0 
            END)) AS PENALIZACION,
    CASE 
      WHEN A.CIF = 'B01886902' THEN 'LEVANTE'
      WHEN A.CIF = 'B26868786' THEN 'LEVANTE'
      WHEN A.CIF = 'B09961558' THEN 'NORESTE'       
      ELSE OPTICO.dho_territorio 
    END AS TERRITORIO

FROM `mm-commissions-reporting.COMISIONES.transacciones` A

LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fix_config` C
  ON A.cif = C.grupo_cif AND C.MES = id_mes_pr


LEFT JOIN `mm-commissions-reporting.TEMP.cif_equivalencias_D2D` CIF
    ON CIF.cif = a.cif

LEFT JOIN `mm-commissions-reporting.TEMP.cont_venta_telefonica` B
    ON B.grupo_cif = CIF.grupo_cif 

LEFT JOIN `mm-commissions-reporting.TEMP.rappel_coches_config` COCHES
    ON A.cif = COCHES.CODIGO 

LEFT JOIN `mm-commissions-reporting.TEMP.rappel_fix_config` FIJO
    ON CIF.CIF = FIJO.grupo_cif

LEFT JOIN `mo-b2b-ssme-reporting.AA_DRAGOS.GS_SSME_OPTICO` OPTICO
    ON OPTICO.ID_UNICO = A.id_comisionista

WHERE A.canal IN ('D2D','D2N','DEM')
  AND A.id_mes = id_mes_pr
  AND A.comision != 0


GROUP BY ALL
HAVING
  CANTIDAD_COCHES != 0 OR
  RAPPEL_FIX != 0 OR
  PENALIZACION_VENTA_TELEFONICA != 0 OR
  PENALIZACION_CIF != 0 OR
  CLAWBACK_COCHE != 0 OR
  CLAWBACK_FIX != 0 OR
  INCENTIVO_ANUAL != 0 OR
  AJUSTE_RAPPEL != 0 OR
  EXTRACOMISION_COMERCIAL != 0 OR
  PENALIZACION != 0 OR
  ANULACION_PENALIZACION_VENTA_TELEFONICA != 0 OR
  ANULACION_PENALIZACION_CIF != 0
)
;
-- DELETE  `mm-commissions-reporting.TEMP.RESUMEN_BRUTO_RAPPEL_D2D`
-- WHERE  (CANTIDAD_COCHES = 0
--  AND RAPPEL_FIX = 0
--  AND PENALIZACION_VENTA_TELEFONICA = 0 
--  AND PENALIZACION_CIF = 0 
--  AND CLAWBACK_COCHE = 0 
--  AND CLAWBACK_FIX = 0 
--  AND INCENTIVO_ANUAL = 0
--  AND AJUSTE_RAPPEL = 0
--  AND EXTRACOMISION_COMERCIAL = 0
--  AND PENALIZACION = 0
--  AND ANULACION_PENALIZACION_VENTA_TELEFONICA = 0
--  AND ANULACION_PENALIZACION_CIF = 0
-- )

-- ;
END