BEGIN

		-- PASO 1: CREO TABLA KRT_CARTERA.VENTAS_TIENDAS
		CREATE OR REPLACE TABLE
			`mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS` AS
		SELECT
			a.*,
			CASE
				WHEN tvt_ups_virgin = 'S' AND concepto_origen_ds IS NOT NULL THEN CASE
				WHEN b.importe_base - ifnull(c.importe_base,
				0) > 0 THEN 15
				WHEN b.importe_base - ifnull(c.importe_base, 0) < 0 THEN -15
			ELSE
			0
		END
			ELSE
			b.importe_base - ifnull(c.importe_base,
				0)
		END
			importe
		FROM
			`mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TIENDASxCANAL` a
		LEFT JOIN
			`mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO` B
		ON
			UPPER(a.MARCO_RETRIBUTIVO) = UPPER(b.marco_retributivo_ds)
			AND UPPER(a.concepto_ds) = UPPER(b.concepto_ds)
			AND UPPER(a.marca_ds) = UPPER(b.marca_ds)
		LEFT JOIN
			`mm-commissions-reporting.KRT_CARTERA.PARAM_MARCO_RETRIBUTIVO` C
		ON
			UPPER(a.MARCO_RETRIBUTIVO) = UPPER(c.marco_retributivo_ds)
			AND UPPER(a.concepto_origen_ds) = UPPER(c.concepto_ds)
			AND UPPER(a.marca_ds) = UPPER(c.marca_ds)
		WHERE
			televenta = 'N'
			OR televenta IS NULL;


		--- PASO 2: VUELCA A LOG
		CREATE OR REPLACE TABLE
			`mm-commissions-reporting.KRT_CARTERA.LOG_0203_VENTAS_TIENDAS` AS
		SELECT
			*
		FROM
			`mm-commissions-reporting.KRT_CARTERA.VENTAS_TIENDAS`;

  END