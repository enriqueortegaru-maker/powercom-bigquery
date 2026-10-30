BEGIN

    ---===============================================================================================
    --- PROCEDIMIENTO QUE AUDITA LAS DIFERENCIAS EN IMPORTES REGISTRADOS EN SAP Y SAP_FACTURA_APUNTES
		---	Auditoría realizada a nivel de Sociedad, mes, bp y concepto 
    ---===============================================================================================

		DECLARE VMES_FACTURA_DT DATE DEFAULT NULL;
	  DECLARE VUMBRAL FLOAT64 DEFAULT NULL;

		SET VMES_FACTURA_DT=PARSE_DATE('%Y%m%d', CAST(VDESDE AS STRING));
		SET VUMBRAL=0.1;

	  -- 1. Crear tabla de DETALLE con la clasificación de las 4 poblaciones
	  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.AUDIT_FACTURAS_SAP_VS_FACTURA_APUNTES_LIST` AS
	  WITH sap AS (
	    SELECT
	      bp,
	      IDSOCIEDAD,
	      codigo,
	      mes_factura_dt,
	      SUM(importe) AS suma_sap
	    FROM `mm-commissions-reporting.KRT_SAP.SAP_FACTURA_APUNTES`
	    WHERE mes_factura_dt = vmes_factura_dt
	    GROUP BY 1, 2, 3, 4
	  ),
	  ett AS (
	    SELECT
	      bp,
	      Sociedad AS IDSOCIEDAD,
	      codigo,
	      mes_factura_dt,
	      SUM(imp_sin_iva) AS suma_ett,
	      CAST(ANY_VALUE(documento) AS STRING) AS invoice_id
	    FROM `mm-commissions-reporting.TEMP.SAP_ETT_completo`
	    WHERE mes_factura_dt = vmes_factura_dt
	    GROUP BY 1, 2, 3, 4
	  )
	  SELECT
	    COALESCE(s.bp, e.bp) AS bp,
	    COALESCE(s.IDSOCIEDAD, e.IDSOCIEDAD) AS IDSOCIEDAD,
	    COALESCE(s.codigo, e.codigo) AS codigo,
	    COALESCE(s.mes_factura_dt, e.mes_factura_dt) AS mes_factura_dt,
	    e.invoice_id,
	    s.suma_sap,
	    e.suma_ett,
	    ROUND(COALESCE(s.suma_sap, 0) - COALESCE(e.suma_ett, 0), 4) AS diferencia_valor,
	    CASE
	      WHEN e.bp IS NULL THEN 'Poblacion 1: SAP sin ETT'
	      WHEN s.bp IS NULL THEN 'Poblacion 2: ETT sin SAP'
	      WHEN ABS(ROUND(COALESCE(s.suma_sap, 0) - COALESCE(e.suma_ett, 0), 4)) < vumbral THEN 'Poblacion 3: Cruce dif < Umbral'
	      ELSE 'Poblacion 4: Cruce dif >= Umbral'
	    END AS poblacion
	  FROM sap s
	  FULL OUTER JOIN ett e
	    ON s.bp = e.bp
	   AND s.IDSOCIEDAD = e.IDSOCIEDAD
	   AND s.codigo = e.codigo
	   AND s.mes_factura_dt = e.mes_factura_dt;

	  -- 2. Crear tabla de RESUMEN extrayendo indicadores y percentiles del detalle
	  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_SAP.AUDIT_FACTURAS_SAP_VS_FACTURA_APUNTES_CONT` AS
	  SELECT
	    poblacion,
	    COUNT(*) AS num_registros,
	    SUM(COALESCE(suma_sap, 0)) AS importe_total_sap,
	    SUM(COALESCE(suma_ett, 0)) AS importe_total_ett,
	    SUM(diferencia_valor) AS diferencia_total_acumulada,
	    -- Cálculo de percentiles sobre el campo diferencia_valor
	    APPROX_QUANTILES(diferencia_valor, 100)[OFFSET(1)]  AS p01,
	    APPROX_QUANTILES(diferencia_valor, 100)[OFFSET(5)]  AS p05,
	    APPROX_QUANTILES(diferencia_valor, 100)[OFFSET(25)] AS p25,
	    APPROX_QUANTILES(diferencia_valor, 100)[OFFSET(50)] AS p50,  
	    APPROX_QUANTILES(diferencia_valor, 100)[OFFSET(75)] AS p75,
	    APPROX_QUANTILES(diferencia_valor, 100)[OFFSET(95)] AS p95,
	    APPROX_QUANTILES(diferencia_valor, 100)[OFFSET(99)] AS p99
	  FROM `mm-commissions-reporting.KRT_SAP.AUDIT_FACTURAS_SAP_VS_FACTURA_APUNTES_LIST`
	  GROUP BY poblacion
	  ORDER BY poblacion;

	END