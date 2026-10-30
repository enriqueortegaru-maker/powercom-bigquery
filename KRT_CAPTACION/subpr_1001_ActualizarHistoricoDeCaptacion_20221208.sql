BEGIN
	DECLARE
		MES_COMISION INT64;
	SET
		MES_COMISION= CAST(FORMAT_DATE("%Y%m",DATE_TRUNC(PARSE_DATE('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64); 

	IF VERSION_FL > 3	THEN
			--- COMISIONES
		DELETE
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` AS h
		WHERE
			h.mes_comision_id=MES_COMISION
			and h.VERSION=VERSION_FL;		

		INSERT INTO
			`mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO`
		SELECT 
			distinct c.* except(PLAYS_RFB), VERSION_FL 
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.COMISIONES` AS c; 
			

			--- CLAWBACK
		DELETE
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO` AS h
		WHERE
			h.mes_decomision_id=MES_COMISION
			and h.VERSION=VERSION_FL;		
		INSERT INTO
			`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO`
		SELECT
			DISTINCT * ,VERSION_FL
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`;

	ELSE 
			--- COMISIONES
		DELETE
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` AS h
		WHERE
			h.mes_comision_id=MES_COMISION
			and h.VERSION=VERSION_FL;		

		INSERT INTO
			`mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO`
		SELECT 
			distinct c.* , VERSION_FL 
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.COMISIONES` AS c; 
			

			--- CLAWBACK
		DELETE
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO` AS h
		WHERE
			h.mes_decomision_id=MES_COMISION
			and h.VERSION=VERSION_FL;		
		INSERT INTO
			`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO`
		SELECT
			DISTINCT * ,VERSION_FL
		FROM
			`mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`;

	END IF;
	
END