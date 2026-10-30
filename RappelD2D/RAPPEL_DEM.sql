BEGIN


insert into `mm-commissions-reporting.RappelD2D.Rappel_Fijo` 
(
with 

-- REALIZAMOS CONTEOS PREVIOS, DE DATOS QUE SUMAN PARA TRAMO PERO NO PARA GENERAR CANTIDAD DE RAPPEL
  
  -- GENERAMOS CONTEO DE ADICIONALES POR CLIENTE Y DISTRIBUIDOR

  total_adicionales as (
    select 
    ID_COMISIONISTA,
    SUM((floor((ADICIONALES)))) as ADICIONALES 
    from 
    `mm-commissions-reporting.RappelD2D.CONTADOR_MOB` 
    GROUP BY 1
    order by 2 desc
    ),

  instalaciones_adici AS (
    SELECT 
    ID_COMISIONISTA,
    adicionales,
    case 
      when adicionales between 5 and 14 then 2
      when adicionales between 15 and 24 then 3
      when adicionales > 25 then 4
      end as instlaciones_adi

    FROM total_adicionales

    ),


  -- REALIZAMOS CONTEO DE ACELERADOR POR VENTAS DE CIF

  CIF AS (
      SELECT
      S.id_comisionista,
      COUNT(DISTINCT S.phone_nm) AS VENTAS_CIF
      FROM
      `mm-commissions-reporting.RappelD2D.V_SERVICIOS_FIJO` S

        INNER JOIN `mm-commissions-reporting.RappelD2D.V_VENTAS_CIF` C
          ON S.MARCA = C.brand_ds AND S.SERVICE_ID = C.service_id AND S.phone_nm = CAST(C.phone_nm AS STRING)

      WHERE
      S.agrupacion_canal = 'D2D'
      AND S.CANAL = V_CANAL
      AND S.ID_MES = MES_1
      AND S.activation_date BETWEEN MES_INI AND MES_FINAL

      GROUP BY 1
  ),

CONTADOR_DEM AS (
  select 
  C.id_comisionista,
  CASE WHEN CIF.VENTAS_CIF / SERVICIOS >= 0.20   THEN (SERVICIOS + (IFNULL(A.instlaciones_adi,0)) + 1) 
        ELSE (SERVICIOS + (IFNULL(A.instlaciones_adi,0))) 
        END AS SERVICIOS

  from 

  `mm-commissions-reporting.RappelD2D.HISTO_CONTADOR` C

   LEFT JOIN instalaciones_adici A
   ON C.ID_COMISIONISTA = A.ID_COMISIONISTA

      LEFT JOIN CIF CIF
   ON C.ID_COMISIONISTA = CIF.ID_COMISIONISTA

  order by 2 desc
  ),

CONFI_1 AS (
  SELECT 
  *
  FROM

  CONTADOR_DEM C
  

  LEFT JOIN `mm-commissions-reporting.RappelD2D.CONFI_DISTRIS` d

   ON D.CODIGO = C.ID_COMISIONISTA AND d.MES = MES_1 

  
  ),
 
CONFI_2 AS (
  SELECT 
  *
  FROM

  CONFI_1 C
  
  LEFT JOIN `mm-commissions-reporting.RappelD2D.CONFI_MARCO` d

   ON C.SERVICIOS BETWEEN d.RANGO_INI AND d.RANGO_FIN AND D.TIPO = CASE WHEN C.id_comisionista LIKE 'DEM%' THEN 'DEM' ELSE 'MENSUAL' END
  
  WHERE
  d.MES = MES_1
  ),

RESULTADO AS (
  SELECT  
  'RPD2'||'_'||MES_1||'_'||S.CANAL||'_'||(case when C.TRAMO is not null then c.tramo else 'SIN_TRAMO' END ) ||'_'||row_number () over () AS commission_id,
  'calculado' AS estado,
    CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN DATE_ADD(mes_liquidado,INTERVAL 1 MONTH)  
    ELSE S.mes_liquidado END AS mes_liquidado,
  CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER) 
    ELSE S.ID_MES END AS id_mes,
  S.agrupacion_canal,
  S.canal,
  'D - Rappel Fijo_'||C.CLASIFICACION as concepto,
  S.tipo_concepto,
  S.unidades,
  C.PRECIO * S.UNIDADES AS comision,
  s.id_comisionista,
  S.distribuidor,
  S.sfid_id,
  S.seller,
  S.nombre_comercio,
  S.razon_social,
  S.cif,
  S.zona_fiscal,
  S.marca,
  S.service_type,
  S.phone_nm,
  S.tariff_id,
  S.tariff_ds,
  S.service_id,
  S.account_id,
  S.customer_id,
  S.line_type_ds,
  S.bundle_type,
  S.technology_ds,
  S.billing_type_ds,
  S.sale_date,
  S.activation_date,
  S.deactivation_date,
  S.order_id,
  S.order_type_agg,
  S.cod_segmento,
  S.cod_marca,
  S.cod_tipo_contrato,
  S.cod_producto,
  S.cod_canal,
  S.claim_code,
  S.campaign_code,
  'RAPPEL_'||S.CANAL||'_'||(case when C.TRAMO is not null then c.tramo else 'SIN_TRAMO' END )||'_'||MES_1 AS process_code,
  S.comments,
  S.facturador,
  '' AS proceso_sap,
  '' AS id_registro,
  '' AS invoice_id,
  S.sociedad,
  '' AS bp,
  '' AS cuenta_contable,
  '' AS centro_coste,
  '' AS documento_sap,
  '' AS documento_sap_posicion,
  '' AS fecha_contabilizacion,
  S.creado,
  S.modificado,
  '' AS id_factura_drive,
  '' as emails_acceso_trazabilidad


  FROM
  `mm-commissions-reporting.RappelD2D.V_SERVICIOS_FIJO` S

  left join CONFI_2 C
    ON S.ID_COMISIONISTA = C.id_comisionista --AND C.CLASIFICACION IS NOT NULL
  
  WHERE
  S.agrupacion_canal = 'D2D'
  AND S.CANAL = 'DEM'
  AND S.ID_MES = MES_1
  AND S.activation_date BETWEEN MES_INI AND MES_FINAL
  
  )
SELECT * FROM RESULTADO WHERE comision is not null
);

END