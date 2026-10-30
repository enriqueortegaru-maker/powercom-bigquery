BEGIN

-- CALL `mm-commissions-reporting.COMISIONES.pr_ETL_thadea_union_tablas`('2026-10-01')

  -- SET de la variable de Ejecucion
      DECLARE mes_diario,mes_consumo, mes_ajustes, mes_unificado DATE;

      IF p_mes IS NOT NULL THEN
        SET mes_unificado = p_mes;
      ELSE

        SET mes_diario =
          (SELECT DATE(CAST(SUBSTR(ANY_VALUE(FechaCalculo), 1, 4) AS INT64), CAST(SUBSTR(ANY_VALUE(FechaCalculo), 6, 2) AS INT64), 1)
          FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_diario_staging`
        );
        SET mes_consumo =
          (SELECT DATE(CAST(SUBSTR(ANY_VALUE(FechaCalculo), 1, 4) AS INT64), CAST(SUBSTR(ANY_VALUE(FechaCalculo), 6, 2) AS INT64), 1)
          FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_consumo_staging`
        );
        SET mes_ajustes =
          (SELECT DATE(CAST(SUBSTR(ANY_VALUE(RUN), 1, 4) AS INT64), CAST(SUBSTR(ANY_VALUE(RUN), 6, 2) AS INT64), 1)
          FROM `mm-commissions-reporting.TEMP.rpiq_manual_comissions_staging`
        )
        ;

        ASSERT mes_diario IS NOT NULL
          AND mes_consumo IS NOT NULL
          AND mes_ajustes IS NOT NULL
          AND mes_diario = mes_consumo
          AND mes_consumo = mes_ajustes
        AS 'Error: algún mes es NULL o los tres meses no coinciden';

        SET mes_unificado = mes_diario;
      END IF;

      SELECT mes_unificado AS valor, TYPEOF(mes_unificado) AS tipo;

  -- Aplicamos el criterio de Idempotencia

  DELETE `mm-commissions-reporting.TEMP.thadea_informe_hist`
  WHERE FECHACALCULO = mes_unificado
  ;
  
  ---------------
  --UNION TABLAS
  ---------------

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.thadea_informe_hist` 
  --PARTITION BY FECHACALCULO
  --CLUSTER BY MARCA,SFID,numfactura,DMEVENTOID

  --AS
  INSERT INTO `mm-commissions-reporting.TEMP.thadea_informe_hist`
    WITH base AS (  

        SELECT
          CAST(FORMAT_DATE('%Y%m',FECHACALCULO) AS INT64) AS id_mes,
          numfactura,	
          FECHACALCULO,
          ISPUBLISHED,	
          DMEVENTOID,	
          SFID,	
          --`mm-commissions-reporting.TEMP.f_normalizacion_nombres`(CONCEPTO) AS CONCEPTO,	
          IDCONCEPTO AS CONCEPTO,
          EVENTOID,	
          EVENTOVERSIONEID,	
          EVENTOTIPOID,	
          EVENTOCONTEXTO,	
          CODIGOVENTAS,	
          SFIDSECUNDARIO,	
          MSISDN,	
          MARCA,	
          MERCADO,	
          TIPOCONTRATO,	
          TECNOLOGIA,	
          CREATIONDATE,
          VALOR,	
          TIPOCLIENTE,	
          TARIFAID,	
          MATERIALID,	
          CONTRATO,	
          TARIFADATOSID,	
          NUMEROLINEAS,	
          ACTOCOMERCIAL,	
          PROCEDENCIALINEA,	
          IMPORTCONSUMO,	
          IDFISCALCLIENTE,	
          TIPORECARGA,	
          ORDINALRECARGA,	
          ESTADOFACTURA,	
          EMAILVERIFICADO,	
          LOGADOAPP,	
          DIFFECHASSERVICIORECARGA,	
          IMPORTEFACTURACARGOS,	
          IMPORTEFACTURAOTROSCARGOS,	
          IMPORTEFACTURADESCUENTOS,	
          IMPORTEFACTURAOTROSDESCUENTOS,	
          TARIFAIDNOMBRE,	
          TARIFADATOSIDNOMBRE,	
          MATERIALIDNOMBRE,	
          SFIDPADRE,	
          ELIGIBLE,	
          TITLE,	
          TIPOACTIVACIONPREPAGO,	
          IDMODELO,	
          TIPOCOMISSION,	
          IDCONCEPTO,	
          CERRADO,	
          CALCIDVALIDO,
          IMEI
        FROM `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle`
        WHERE FECHACALCULO >= mes_unificado

      UNION ALL

        SELECT 
          CAST(FORMAT_DATE('%Y%m',FECHACALCULO) AS INT64) AS id_mes,
          numfactura,	
          FECHACALCULO,
          ISPUBLISHED,	
          DMEVENTOID,	
          SFID,	
          --`mm-commissions-reporting.TEMP.f_normalizacion_nombres`(CONCEPTO) AS CONCEPTO,	
          IDCONCEPTO as CONCEPTO,      
          EVENTOID,	
          EVENTOVERSIONEID,	
          EVENTOTIPOID,	
          EVENTOCONTEXTO,	
          CODIGOVENTAS,	
          SFIDSECUNDARIO,	
          MSISDN,	
          MARCA,	
          MERCADO,	
          TIPOCONTRATO,	
          TECNOLOGIA,	
          COALESCE(SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(CREATIONDATE, 1, 10)), DATE(SAFE.PARSE_DATETIME('%Y-%m-%d %H:%M:%S', SUBSTR(CREATIONDATE, 1, 19)))) AS CREATIONDATE,
          --DATE(PARSE_DATETIME('%Y-%m-%d %H:%M:%S', SUBSTR(CREATIONDATE, 1, 19))) AS CREATIONDATE,
          VALOR,	
          TIPOCLIENTE,	
          TARIFAID,	
          MATERIALID,	
          CONTRATO,	
          TARIFADATOSID,	
          NUMEROLINEAS,	
          ACTOCOMERCIAL,	
          PROCEDENCIALINEA,	
          IMPORTCONSUMO,	
          IDFISCALCLIENTE,	
          TIPORECARGA,	
          ORDINALRECARGA,	
          ESTADOFACTURA,	
          EMAILVERIFICADO,	
          LOGADOAPP,	
          DIFFECHASSERVICIORECARGA,	
          IMPORTEFACTURACARGOS,	
          IMPORTEFACTURAOTROSCARGOS,	
          IMPORTEFACTURADESCUENTOS,	
          IMPORTEFACTURAOTROSDESCUENTOS,	
          TARIFAIDNOMBRE,	
          TARIFADATOSIDNOMBRE,	
          MATERIALIDNOMBRE,	
          SFIDPADRE,	
          ELIGIBLE,	
          TITLE,	
          TIPOACTIVACIONPREPAGO,	
          IDMODELO,	
          'CONSUMO' AS TIPOCOMISSION,	
          IDCONCEPTO,	
          CERRADO,	
          CALCIDVALIDO,
          CAST(NULL AS STRING) AS IMEI,
        FROM `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_consumo`	
        WHERE FECHACALCULO >= mes_unificado

      UNION ALL

        SELECT 
          CAST(FORMAT_DATE('%Y%m',FECHACALCULO) AS INT64) AS id_mes,
          numfactura,	
          FECHACALCULO,
          ISPUBLISHED,	
          IDMODELO AS DMEVENTOID,	
          SFID,	
          --IDCONCEPTO AS CONCEPTO,	
          CASE 
            WHEN IDCONCEPTO = 'D - BLINDAJE PANZER' THEN 'D - BLINDAJE "PANZER"'
            WHEN IDCONCEPTO = 'E - CLAWBACK BLINDAJE PANZER' THEN 'E - CLAWBACK BLINDAJE "PANZER"'
            ELSE IDCONCEPTO 
          END AS CONCEPTO,	
          IDCOMISIONMANUAL AS EVENTOID,	
          1  AS EVENTOVERSIONEID,	
          'AJUSTE' AS EVENTOTIPOID,	
          'AJU' AS EVENTOCONTEXTO,	
          CAST(NULL AS STRING) AS CODIGOVENTAS,	
          CAST(NULL AS STRING) AS SFIDSECUNDARIO,	
          MSISDN,	
          MARCA,	
          MERCADO,	
          CAST(NULL AS STRING) AS TIPOCONTRATO,	
          TECNOLOGIA,	
          FECHACOMPENSACION AS CREATIONDATE,	
          VALORCOMISSAO AS VALOR,	
          CAST(NULL AS STRING) AS TIPOCLIENTE,	
          CAST(NULL AS STRING) AS TARIFAID,	
          CAST(NULL AS STRING) AS MATERIALID,	
          CONTRATO,	
          CAST(NULL AS STRING) AS TARIFADATOSID,	
          CAST(NULL AS INT64) AS NUMEROLINEAS,	
          CAST(NULL AS STRING) AS ACTOCOMERCIAL,	
          CAST(NULL AS STRING) AS PROCEDENCIALINEA,	
          CAST(NULL AS INT64) AS IMPORTCONSUMO,	
          CAST(NULL AS STRING) AS IDFISCALCLIENTE,	
          CAST(NULL AS STRING) AS TIPORECARGA,	
          CAST(NULL AS INT64) AS ORDINALRECARGA,	
          CAST(NULL AS STRING) AS ESTADOFACTURA,	
          CAST(NULL AS STRING) AS EMAILVERIFICADO,	
          CAST(NULL AS STRING) AS LOGADOAPP,	
          CAST(NULL AS FLOAT64) AS DIFFECHASSERVICIORECARGA,	
          CAST(NULL AS FLOAT64) AS IMPORTEFACTURACARGOS,	
          CAST(NULL AS FLOAT64) AS IMPORTEFACTURAOTROSCARGOS,	
          CAST(NULL AS FLOAT64) AS IMPORTEFACTURADESCUENTOS,	
          CAST(NULL AS FLOAT64) AS IMPORTEFACTURAOTROSDESCUENTOS,	
          CAST(NULL AS STRING) AS TARIFAIDNOMBRE,	
          CAST(NULL AS STRING) AS TARIFADATOSIDNOMBRE,	
          CAST(NULL AS STRING) AS MATERIALIDNOMBRE,	
          CAST(NULL AS STRING) AS SFIDPADRE,	
          CAST(NULL AS STRING) AS ELIGIBLE,	
          CAST(NULL AS STRING) AS TITLE,	
          CAST(NULL AS STRING) AS TIPOACTIVACIONPREPAGO,	
          CAST(NULL AS STRING) AS IDMODELO,	
          'AJUSTE' AS TIPOCOMISSION,	
          CAST(NULL AS STRING) AS IDCONCEPTO,	
          CAST(NULL AS FLOAT64) AS CERRADO,	
          CAST(NULL AS FLOAT64) AS CALCIDVALIDO,	
          IMEI
        FROM `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_ajustes`
        WHERE FECHACALCULO >= mes_unificado
    )

    SELECT *
    FROM base
  ;
END