BEGIN

insert into `mm-commissions-reporting.RappelD2D.Rappel_Fijo` 
(
    SELECT  
    'RPD2'||'_'||MES_1||'_'||S.CANAL||'_'||(case when S.TRAMO is not null then S.tramo else 'SIN_TRAMO' END ) ||'_'||row_number () over () AS commission_id,
    'calculado' AS estado,
      CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN DATE_ADD(mes_liquidado,INTERVAL 1 MONTH)  
      ELSE S.mes_liquidado END AS mes_liquidado,
    CASE WHEN S.CANAL IN ('D2N','DEM','EDB') THEN CAST((MES_1 + 1) AS INTEGER) 
      ELSE S.ID_MES END AS id_mes,
    S.agrupacion_canal,
    S.canal,
    'D - Rappel Fijo_'||S.CLASIFICACION as concepto,
    S.tipo_concepto,
    S.unidades,
    (CAST(S.PRECIO AS INTEGER)) * S.UNIDADES AS comision,
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
    'RAPPEL_'||S.CANAL||'_'||(case when S.TRAMO is not null then S.tramo else 'SIN_TRAMO' END )||'_'||MES_1 AS process_code,
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
    `mm-commissions-reporting.RappelD2D.V_CONFI_RAPPEL_FIJO` S

    WHERE
    S.id_mes = MES_1
    AND S.agrupacion_canal = 'D2D'
    AND S.CANAL = V_CANAL
    AND S.activation_date BETWEEN MES_INI AND MES_FINAL
);

END