BEGIN


DECLARE err, sql STRING;


/*
CALL `mm-commissions-reporting.COMISIONES.pr_d2d_optico`(202601);
*/

-- Check Duplicados --

SET err = (
  WITH duplicates AS
  (
  SELECT
        ID_UNICO
       ,dho_tipo2
       ,COUNT(DISTINCT ID_UNICO)
  FROM `mo-b2b-ssme-reporting.AA_DRAGOS.GS_SSME_OPTICO`
  WHERE ID_UNICO IS NOT NULL
  GROUP BY 1,2
  HAVING COUNT(DISTINCT ID_UNICO) > 1
  )
  
  SELECT STRING_AGG(duplicates.ID_UNICO)
  FROM duplicates
);

IF err IS NOT NULL THEN RAISE USING MESSAGE = 'Existen sfid de D2D con conflicto de sfid unico: ' || err; END IF;


INSERT INTO `mm-commissions-reporting.COMISIONES.dealer`
(
id_mes, agrupacion_canal, sfid, id_comisionista, distribuidor,
canal, comisiona, nombre_comercio, razon_social, documento,
zona_fiscal, comentarios, cif_gpv, creado_por, creado
)

SELECT
     mes_int AS id_mes
     ,'D2D' AS agrupacion_canal
     ,ID_UNICO AS sfid
     ,CAST (NULL AS STRING) AS id_comisionista
     ,ID_UNICO AS distribuidor

     ,CASE
          WHEN dho_tipo2 = 'MASMOVIL' THEN 'D2D'
          WHEN dho_tipo2 = 'YOIGO' AND ID_UNICO LIKE 'DEM%' THEN 'DEM'
          WHEN dho_tipo2 = 'YOIGO' AND ID_UNICO LIKE 'D2N%' THEN 'D2N'
      END AS canal

     ,CASE
          WHEN COALESCE(dho_activo, 'X') <> 'INACTIVO' OR COALESCE(dho_fecha_baja, '9999-12-31') > PARSE_DATE('%Y%m', CAST(mes_int AS STRING))
          THEN TRUE ELSE FALSE
      END as comisiona
     ,dho_nombre_comercial AS nombre_comercio
     ,dho_razon_social AS razon_social
     ,dho_numero_documento AS cif
     ,CASE
          SUBSTR(LPAD(CAST(dho_cp AS STRING), 5, '0'), 1, 2)
            WHEN '35' THEN 'CAN'
            WHEN '38' THEN 'CAN'
            WHEN '51' THEN 'CEU'
            WHEN '52' THEN 'MEL'
            ELSE 'PEN'
      END AS zona_fiscal 

     ,CAST (NULL AS STRING) AS comentarios
     
     ,CAST (NULL AS STRING) AS cif_gpv

     ,'Z005' AS cond_pago ---CONFIRMAR
      
     ,SESSION_USER()
     ,CURRENT_TIMESTAMP()
FROM `mo-b2b-ssme-reporting.AA_DRAGOS.GS_SSME_OPTICO`
WHERE SUBCHANNEL = 'D2D SOHO'
AND dho_tipo2 IS NOT NULL
AND dho_numero_documento IS NOT NULL
AND dho_tipo2 IN ('MASMOVIL','YOIGO')

;

END