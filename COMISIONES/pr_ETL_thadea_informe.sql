BEGIN

-- CALL `mm-commissions-reporting.COMISIONES.pr_ETL_thadea_informe`()

      DECLARE mes_diario_str,mes_consumo_str, mes_ajustes_str STRING;
      DECLARE mes_diario,mes_consumo, mes_ajustes DATE;

      SET (mes_diario_str, mes_diario) =
        (SELECT AS STRUCT ANY_VALUE(FechaCalculo), DATE(CAST(SUBSTR(ANY_VALUE(FechaCalculo), 1, 4) AS INT64), CAST(SUBSTR(ANY_VALUE(FechaCalculo), 6, 2) AS INT64), 1)
        FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_diario_staging`
      );
      SET (mes_consumo_str, mes_consumo) =
        (SELECT AS STRUCT ANY_VALUE(FechaCalculo), DATE(CAST(SUBSTR(ANY_VALUE(FechaCalculo), 1, 4) AS INT64), CAST(SUBSTR(ANY_VALUE(FechaCalculo), 6, 2) AS INT64), 1)
        FROM `mm-commissions-reporting.TEMP.rpiq_informe_detallado_consumo_staging`
      );
      SET (mes_ajustes_str, mes_ajustes) =
        (SELECT AS STRUCT ANY_VALUE(RUN), DATE(CAST(SUBSTR(ANY_VALUE(RUN), 1, 4) AS INT64), CAST(SUBSTR(ANY_VALUE(RUN), 6, 2) AS INT64), 1)
        FROM `mm-commissions-reporting.TEMP.rpiq_manual_comissions_staging`
      )
      ;

  ------------------------------------
  --Tabla thadea_informe_detalle
  ------------------------------------

    -- Datos Bronze `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle`

    -- Aplicamos el criterio de Idempotencia

      DELETE `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle`
      WHERE FECHACALCULO = mes_diario
      ;

    --Transformación Datos Silver

      -- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle`
      -- PARTITION BY FECHACALCULO
      -- CLUSTER BY MARCA,SFID,numfactura,DMEVENTOID

      INSERT INTO `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle`
          SELECT
            numfactura,
            DATE(CAST(SUBSTR(FechaCalculo, 1, 4) AS INT64), CAST(SUBSTR(FechaCalculo, 6, 2) AS INT64), 1) as FECHACALCULO,
            CAST(CAST(ISPUBLISHED AS FLOAT64)AS INT64) AS ISPUBLISHED	,
            -- CAST(CAST( AS FLOAT64) AS INT64) AS
            DMEVENTOID	,
            SFID	,
            CONCEPTO	,
            EVENTOID	,
            CAST(CAST(EVENTOVERSIONEID AS FLOAT64) AS INT64)	EVENTOVERSIONEID	,
            EVENTOTIPOID	,
            EVENTOCONTEXTO	,
            CODIGOVENTAS	,
            SFIDSECUNDARIO	,
            MSISDN	,
            MARCA	,
            MERCADO	,
            TIPOCONTRATO	,
            TECNOLOGIA	,
            SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(CREATIONDATE, 1, 10)) AS CREATIONDATE	,
            IMEI	,
            CAST(VALOR AS FLOAT64) AS VALOR	,
            TIPOCLIENTE	,
            TARIFAID	,
            TERMINALID	,
            MATERIALID	,
            ESTADOFIJO	,
            CONTRATO	,
            TIPOPROVISION	,
            SVAID	,
            CAST(IMPORTRECARGA AS FLOAT64) AS IMPORTRECARGA	,
            TIPOACTIVACIONPREPAGO	,
            TIPOLOGIARECOGIDA	,
            TARIFAIDANTERIOR	,
            TARIFADATOSID	,
            TERMINALORANGE	,
            NUEVOCLIENTE	,
            CAST(CAST(NUMEROLINEAS AS FLOAT64) AS INT64)	AS NUMEROLINEAS	,
            PERMANENCIATARIFAID	,
            PERMANENCIAOPERADORID	,
            PROMOCIONID	,
            ACTOCOMERCIAL	,
            ORIGENPORTABILIDAD	,
            TIPOSTOCK	,
            CAST(RECARGASVA AS FLOAT64) AS RECARGASVA	,
            PROCEDENCIALINEA	,
            CAST(IMPORTCONSUMO AS FLOAT64) AS IMPORTCONSUMO	,
            MULTIDISPOSITIVO	,
            CAST(PVP AS FLOAT64) AS PVP	,
            NOMBRECLIENTE	,
            IDFISCALCLIENTE	,
            SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(FECHADESACTIVACION, 1, 10)) AS FECHADESACTIVACION	,
            TIPORECARGA	,
            CAST(CAST(ORDINALRECARGA AS FLOAT64) AS INT64)	AS ORDINALRECARGA	,
            ESTADOFACTURA	,
            EMAILVERIFICADO	,
            LOGADOAPP	,
            CAST(DIFFECHASSERVICIORECARGA AS FLOAT64) AS DIFFECHASSERVICIORECARGA	,
            CAST(IMPORTEFACTURACARGOS AS FLOAT64) AS IMPORTEFACTURACARGOS	,
            CAST(IMPORTEFACTURAOTROSCARGOS AS FLOAT64) AS IMPORTEFACTURAOTROSCARGOS	,
            CAST(IMPORTEFACTURADESCUENTOS AS FLOAT64) AS IMPORTEFACTURADESCUENTOS	,
            CAST(IMPORTEFACTURAOTROSDESCUENTOS AS FLOAT64) AS IMPORTEFACTURAOTROSDESCUENTOS	,
            CAST(DEDUCCIONDIAS AS FLOAT64) AS DEDUCCIONDIAS	,
            TARIFAIDNOMBRE	,
            TARIFADATOSIDNOMBRE	,
            TERMINALIDNOMBRE	,
            MATERIALIDNOMBRE	,
            SVAIDNOMBRE	,
            PROMOCIONIDNOMBRE	,
            PERMANENCIATARIFAIDNOMBRE	,
            PERMANENCIAOPERADORIDNOMBRE	,
            SFIDPADRE	,
            CASE
              WHEN PRECIOCESION = '' THEN 0
              ELSE CAST(PRECIOCESION AS FLOAT64)
            END AS PRECIOCESION	,
            PERMANENCIATARIFADATOS	,
            TERMINALORANGECLASSIF	,
            ELIGIBLE	,
            TIPOCOMISSION	,
            TARIFAIDANTERIORNOMBRE	,
            TITLE	,
            TIPOGARANTIA	,
            TIPOCAMBIOSIM	,
            TIPOACESSO	,
            VELOCIDADFIJO	,
            TAMANOCLIENTE	,
            TARIFADATOSIDANTERIOR	,
            VENTAPLAZO	,
            CAST(PRECIOFINANCIACION AS FLOAT64) AS PRECIOFINANCIACION	,
            CAST(PAGOINICIAL AS FLOAT64) AS PAGOINICIAL	,
            CAST(CANTIDADAPLAZADA AS FLOAT64) AS CANTIDADAPLAZADA	,
            IDMODELO	,
            IDREGLA	,
            ESTADOIMEI	,
            NUMSIMCARD	,
            CODIGOPEDIDO	,
            MOTIVONOCOMISION	,
            TIPOPROVISIONORIGENFIJO	,
            TIPOPROVISIONDESTINOFIJO	,
            MSISDNSECONDARIO	,
            PRONVINCIA	,
            TIPORIESGO	,
            TIPODEACTOCOMERCIALNOMBRE	,
            TARIFADATOSIDANTERIORNOMBRE	,
            CAST(CAST(CERRADO AS FLOAT64)AS INT64) AS CERRADO	,
            CAST(CAST(CALCIDVALIDO AS FLOAT64)AS INT64) AS CALCIDVALIDO	,
            CAST(IMPORTENDA AS FLOAT64) AS IMPORTENDA	,
            IDCONCEPTO	,
            PERMANENCIATARIFADATOSNOMBRE	,
            TARIFADATOSRECOMENDADA	,
            CAST(DIASULTIMACAPTACION AS FLOAT64) AS DIASULTIMACAPTACION	,
            FLAGTARIFARECOMENDADA	,
            TARIFADATOSRECOMENDADANOMBRE	,
            TIPOIMEI	,
            DISPOSITIVOIMEIANTERIOR	,
            POSTVENTA	,
            BONOID	,
            TIPODISPOSITIVO	,
            ESTADOPEDIDOTERMINAL	,
            MGM	,
            CAST(CAST(ACTIVIDADRETRASADA AS FLOAT64)AS INT64) AS ACTIVIDADRETRASADA	,
            FECHAEMISIONFACTURA	,
          FROM `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle`
          WHERE FECHACALCULO = mes_diario_str
        ;

  ---------------------------------------
  --Tabla thadea_informe_detalle_consumo
  ---------------------------------------

    -- Datos Bronze `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_consumo`

    -- Aplicamos el criterio de Idempotencia

      DELETE `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_consumo`
      WHERE FECHACALCULO = mes_consumo
      ;

    --Transformación Datos Silver

      -- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_consumo`
      -- PARTITION BY FECHACALCULO
      -- CLUSTER BY MARCA,SFID,numfactura

      -- AS

      INSERT INTO `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_consumo`
        SELECT
          numfactura,
          DATE(CAST(SUBSTR(FECHACALCULO, 1, 4) AS INT64), CAST(SUBSTR(FECHACALCULO, 6, 2) AS INT64), 1) as FECHACALCULO,
          CAST(ROUND(CAST(ISPUBLISHED AS FLOAT64)) AS INT64) AS ISPUBLISHED,
          DMEVENTOID,
          SFID,
          CONCEPTO,
          EVENTOID,
          CAST(ROUND(CAST(EVENTOVERSIONEID AS FLOAT64)) AS INT64) AS EVENTOVERSIONEID,
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
          CAST(VALOR AS FLOAT64) AS VALOR,
          TIPOCLIENTE,
          TARIFAID,
          MATERIALID,
          CONTRATO,
          TARIFADATOSID,
          CAST(ROUND(CAST(NUMEROLINEAS AS FLOAT64)) AS INT64) AS NUMEROLINEAS,
          ACTOCOMERCIAL,
          PROCEDENCIALINEA,
          CAST(IMPORTCONSUMO AS FLOAT64) AS IMPORTCONSUMO,
          IDFISCALCLIENTE,
          TIPORECARGA,
          CAST(ROUND(CAST(ORDINALRECARGA AS FLOAT64)) AS INT64) AS ORDINALRECARGA,
          ESTADOFACTURA,
          EMAILVERIFICADO,
          LOGADOAPP,
          CAST(DIFFECHASSERVICIORECARGA AS FLOAT64) AS DIFFECHASSERVICIORECARGA,
          CAST(IMPORTEFACTURACARGOS AS FLOAT64) AS IMPORTEFACTURACARGOS,
          CAST(IMPORTEFACTURAOTROSCARGOS AS FLOAT64) AS IMPORTEFACTURAOTROSCARGOS,
          CAST(IMPORTEFACTURADESCUENTOS AS FLOAT64) AS IMPORTEFACTURADESCUENTOS,
          CAST(IMPORTEFACTURAOTROSDESCUENTOS AS FLOAT64) AS IMPORTEFACTURAOTROSDESCUENTOS,
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
          CAST(ROUND(CAST(CERRADO AS FLOAT64)) AS INT64) AS CERRADO,
          CAST(ROUND(CAST(CALCIDVALIDO AS FLOAT64)) AS INT64) AS CALCIDVALIDO
        FROM `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_consumo`
        WHERE FECHACALCULO = mes_consumo_str
  ;

  ---------------------------------------
  --Tabla thadea_informe_detalle_ajustes
  ---------------------------------------

    -- Datos Bronze `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_ajustes`

    -- Aplicamos el criterio de Idempotencia

      DELETE `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_ajustes`
      WHERE FECHACALCULO = mes_ajustes
      ;

    --Transformación Datos Silver

      -- CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_ajustes`
      -- PARTITION BY FECHACALCULO
      -- CLUSTER BY MARCA,SFID,numfactura

      -- AS

      INSERT INTO `mm-commissions-reporting.TEMP.silver_thadea_informe_detalle_ajustes`
        SELECT
          numfactura	,
          DATE(CAST(SUBSTR(RUN, 1, 4) AS INT64), CAST(SUBSTR(RUN, 6, 2) AS INT64), 1) as FECHACALCULO,
          CAST(CAST( ISPUBLISHED AS FLOAT64) AS INT64)AS ISPUBLISHED	,
          -- CAST(CAST( AS FLOAT64) AS INT64)
          HRPAYEEASIGNACIONID	,
          PAYEE	,
          SFID	,
          IDCOMISIONMANUAL	,
          IDCONCEPTO	,
          `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(CONCEPTONOMBRE) AS CONCEPTONOMBRE	,
          IDMODELO	,
          `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(MODELONOMBRE) AS MODELONOMBRE	,
          CAST(VALORCOMISSAO AS FLOAT64) AS VALORCOMISSAO	,
          SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(FECHACOMPENSACION, 1, 10)) AS FECHACOMPENSACION	,
          CAST(VALUEDTEXTERNAL AS FLOAT64) AS VALUEDTEXTERNAL	,
          MARCA	,
          MERCADO	,
          CONTRATO	,
          TECNOLOGIA	,
          MSISDN	,
          IMEI	,
          NUMPEDIDO	,
          CODCONTRATO	,
          `mm-commissions-reporting.TEMP.f_normalizacion_nombres`(COMENTARIO) AS COMENTARIO	,
          PEP	,
          IDCUENTACONTABLE	,
          ACTIVIDAD	,
          EXCLUIDOIRPF	,
          CANONFRANQUICIA	,
          PARENTESCO	,
          DESCUENTO	,
          TIPOCORRECION	,
          INCIDENCIAID	,
          INCIDENCIAMINICASOID	,
        FROM `mm-commissions-reporting.TEMP.bronze_thadea_informe_detalle_ajustes`
        WHERE RUN = mes_ajustes_str
      ;

END