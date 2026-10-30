BEGIN

    --call`mm-commissions-reporting.KRT_SAP.pr_fl_registra_invoice_factura_apuntes`(20260901);

    ---========================================================================================
    --- PROCEDIMIENTO QUE REGISTRA EN SAP_FACTURA_APUNTES Y TRANSACCIONES EL CAMPO INVOICE_ID
    --- Se soporta en dato invoice_id registrado en excel exportado de sap
    --- Y posteriormente cargado en tabla  SAP_ETT_completo por proceso 
    --- publicarFacturaDesdeExcel.py en /home/esc/bin/comisiones/publicar/bin
    ---========================================================================================

    DECLARE VMES_FACTURA_DT, VHOY_DT DATE DEFAULT NULL;
    DECLARE VUMBRAL FLOAT64; SET VUMBRAL=0.1;
    SET VMES_FACTURA_DT=PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING));
    SET VHOY_DT=CURRENT_DATE();


    ---================================================================
    --- PASO 1: BACKUP DE SAP_FACTURA_APUNTES
    ---================================================================

    insert into `mm-commissions-reporting.KRT_SAP.AGG_SAP_FACTURA_APUNTES`
    select VHOY_DT, *
    from  `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`
    where not exists (
      select 1
      from `mm-commissions-reporting.KRT_SAP.AGG_SAP_FACTURA_APUNTES`
      where mes_factura_dt=VMES_FACTURA_DT
      and fecha_calc_dt=VHOY_DT
    );


    ---================================================================
    --- PASO 2: REGISTRO INVOICE_ID
    ---================================================================


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_DISTRIBUIDOR_CODIGO` AS
    WITH sap AS (	
        SELECT
          mes_factura_dt,
          IDSOCIEDAD,
          bp,
          nombre_acreedor,
          codigo,
          conceptoFacturaDetalle,
          SUM(importe) AS suma_sap
        FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`
        WHERE mes_factura_dt=VMES_FACTURA_DT			
        GROUP BY 1,2,3,4,5,6
      ),
      ett AS (
        --DECLARE VMES_FACTURA_DT DATE DEFAULT '2026-09-01';
        SELECT
          bp,
          Sociedad AS IDSOCIEDAD,
          codigo,
          mes_factura_dt,
          sum(imp_sin_iva) as  suma_ett,
          CAST(ANY_VALUE(documento) AS STRING) AS invoice_id
        FROM `mm-commissions-reporting.TEMP.SAP_ETT_completo`
        WHERE mes_factura_dt=VMES_FACTURA_DT
        GROUP BY 1,2,3,4
      )
      SELECT
        s.mes_factura_dt,
        s.idsociedad,
        s.bp,
        s.nombre_acreedor,
        s.codigo,
        e.invoice_id
      FROM sap s
      INNER JOIN ett e
        ON s.bp = e.bp
      AND s.IDSOCIEDAD = e.IDSOCIEDAD			 
      AND s.codigo = e.codigo
      AND s.mes_factura_dt = e.mes_factura_dt
      WHERE ABS(ROUND(coalesce(s.suma_sap,0) - coalesce(e.suma_ett,0))) < VUMBRAL;


      DELETE FROM  `mm-commissions-reporting.KRT_SAP.HISTORICO_SAP_FACTURA_DISTRIBUIDOR_CODIGO` 
      where mes_factura_dt=VMES_FACTURA_DT;

      INSERT INTO `mm-commissions-reporting.KRT_SAP.HISTORICO_SAP_FACTURA_DISTRIBUIDOR_CODIGO`
      SELECT 
        mes_factura_dt,
        idsociedad,
        bp,
        nombre_acreedor,
        codigo,
        invoice_id
      FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_DISTRIBUIDOR_CODIGO` ;


    ---================================================================
    --- PASO 3: ACTUALIZO INVOICE_ID SAP_FACTURA_APUNTES
    ---================================================================

    UPDATE `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES` sf
    SET sf.INVOICE_ID=fd.invoice_id
    FROM  `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_DISTRIBUIDOR_CODIGO` fd
    WHERE sf.INVOICE_ID is null
    and sf.mes_factura_dt=VMES_FACTURA_DT
    and sf.mes_factura_dt=fd.mes_factura_dt
    and sf.IDSOCIEDAD=fd.IDSOCIEDAD
    AND sf.bp=fd.bp
    and sf.codigo=fd.codigo;




    ---================================================================
    --- PASO $: ACTUALIZO INVOICE_ID TRANSACCIONES
    ---================================================================

    -- DE MOMENTO LO HACEMOS A TRAVES DE COMMISSION_ID, UN BREVE DIRECTAMENTE CON CODIGO 

    UPDATE `mm-commissions-reporting.KRT_SAP.TRANSACCIONES` t
    SET invoice_id = s.invoice_id
    FROM (
      SELECT DISTINCT 
        idsociedad, 
        marca_ds, 
        invoice_id, 
        bp, 
        TRIM(c_id) AS commission_id    
      FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`,
      UNNEST(commission_id) AS c_id
      WHERE mes_factura_dt = vmes_factura_dt
    ) s
    WHERE t.mes_factura_dt = vmes_factura_dt 
      AND t.sociedad = s.idsociedad
      AND t.marca = s.marca_ds
      AND CAST(t.bp AS INT64) = s.bp
      AND TRIM(t.commission_id) = s.commission_id
      AND t.invoice_id IS NULL;


    

END