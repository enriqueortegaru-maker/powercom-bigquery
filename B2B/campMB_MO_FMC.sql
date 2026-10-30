BEGIN

--Procedimiento que calcula la campaña cuando un MO se convierte en una FMC o una BA si tiene un móvil activo mayor a un mes.

DECLARE MO_FMC, BA_MO, MO_BA  STRING;
DECLARE mes_ini DATE;

SET mes_ini = DATE_TRUNC(PARSE_DATE('%Y%m',CAST(mes_int AS STRING)),MONTH);

SET MO_FMC = ARRAY_TO_STRING([ --CASO 1
        '3P MO - FMC', 
        '3P MO - FMC >=12M', 
        '3P MO - FMC <12M', 
        'INCENTIVO AD DTO', 
        '3P MO - FMC >60D']
      , ',');

SET BA_MO = ARRAY_TO_STRING([ --CASO 2
        'BA MO' --ALTAS DE BANDA ANCHA (2P - 3P) QUE TIENEN AHORA UN MO CON MAS DE 15 DÍAS DE ANTIGÜEDAD
      ], ',');

SET MO_BA = ARRAY_TO_STRING([ --CASO 3
        'MO BA'] -- MOVILES QUE CONTRATAN UNA BANDA ANCHA (2P - 3P) CON MAS DE 15 DÍAS DE ANTIGÜEDAD
      , ',');

-- call `mm-commissions-reporting.COMISIONES.campMB_MO_FMC`(202508)

-- Verificamos si en la liquidación del mes correspondiente existe la campaña especial

  IF EXISTS(
    SELECT 1
    FROM `mm-commissions-reporting.GS.EXTRA_CAMPANA_MB`
    WHERE UPPER(tipo_linea) IN UNNEST(SPLIT(MO_FMC, ',')) OR UPPER(tipo_linea) IN UNNEST(SPLIT(BA_MO, ','))
      AND FECHA_CAMPANA = LAST_DAY(mes_ini)
    ) THEN

  --Eliminamos si exite información de la liquidación para no duplicar.

    DELETE `mm-commissions-reporting.TEMP.HIST_CAMPANA_MO_FMC` 
    WHERE PERIODO_LIQ = mes_ini;

  --Insertamos la información en la tabla para que se calcule la campaña por el procedimiento general
    INSERT INTO `mm-commissions-reporting.TEMP.HIST_CAMPANA_MO_FMC` (
    
    WITH

      dealers_CM_MB AS (
        SELECT 
          b.id_comisionista AS id_comisionista_CM,
          c.id_comisionista AS id_comisionista_MB, 
          b.documento
        FROM `mm-commissions-reporting.GS.DEALERS_CABLEMOVIL` b
        LEFT JOIN (
          SELECT 
            id_comisionista, 
            documento
          FROM `mm-commissions-reporting.GS.DEALERS_MARBLANCA`
        ) c ON b.documento = c.documento
        QUALIFY ROW_NUMBER() OVER(PARTITION BY b.id_comisionista) = 1
      ),

      CASO_1 AS ( 
        SELECT 
          mes_ini AS PERIODO_LIQ,
          a.* EXCEPT(PERIODO_MES,codigo_cliente),
          id_comisionista_MB,
          DESDE,
          HASTA,
          CASE
            WHEN REGEXP_CONTAINS(CAST(MOVIL_ASOCIADO AS STRING), r'^[67]') AND REGEXP_CONTAINS(CAST(MSISDN AS STRING), r'^[89]') THEN  
                    CASE 
                      WHEN FECHA_ACTIVACION_MOVIL_ASOCIADO > FECHA_ACT_FIBRA THEN 'Móvil activado después de fibra'
                      WHEN FECHA_ACTIVACION_MOVIL_ASOCIADO = FECHA_ACT_FIBRA THEN 'Móvil activado el mismo día que fibra'
                      ELSE 'Móvil activado antes de fibra'
                    END
            ELSE NULL
          END AS coments
        FROM `mm-b2b-reporting.SERVICES.detalle_marblanca_2024` a
        LEFT JOIN dealers_CM_MB e ON  a.codigo_cliente = e.id_comisionista_CM OR a.codigo_cliente= e.id_comisionista_MB
        LEFT JOIN (
          SELECT 
            DEALER, 
            DESDE,
            HASTA
          FROM `mm-commissions-reporting.GS.EXTRA_CAMPANA_MB`
          WHERE UPPER(tipo_linea) IN UNNEST(SPLIT(MO_FMC, ','))
            AND FECHA_CAMPANA = LAST_DAY(mes_ini) 
        ) f ON f.DEALER = e.id_comisionista_MB
        WHERE 1=1
          --AND codigo_cliente = 'F88520'
          AND codigo_cliente = e.id_comisionista_CM
          --AND FECHA_ACT_FIBRA BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE(),INTERVAL 5 MONTH),MONTH) AND LAST_DAY(DATE_SUB(CURRENT_DATE(),INTERVAL 1 MONTH)) 
          AND FECHA_ACT_FIBRA BETWEEN DESDE AND HASTA
          AND FECHA_DESACT_FIBRA IS NULL
          AND DATE_DIFF(FECHA_ACT_FIBRA,FECHA_ACTIVACION_MOVIL_ASOCIADO,DAY) > 30
          AND TARIFA_ID IN (
            '805', --	FIBRA 300MB + ILIMITADA 25GB 3P CABLEMÓVIL
            '806', --	FIBRA 300MB INDIRECTA + ILIMITADA 25GB 3P CABLEMÓVIL
            '807', --	FIBRA 300MB + ILIMITADA 50GB 3P CABLEMÓVIL
            '808', --	FIBRA 300MB INDIRECTA + ILIMITADA 50GB 3P CABLEMÓVIL
            '809', --	FIBRA 300MB + TARIFA COMPARTIDA 50GB 3P CABLEMÓVIL
            '810', --	FIBRA 300MB INDIRECTA + TARIFA COMPARTIDA 50GB 3P CABLEMÓVIL
            '629', --	FIBRA 600MB + TARIFA COMPARTIDA 40GB 3P CABLEMÓVIL
            '631', --	FIBRA 600MB INDIRECTA + TARIFA COMPARTIDA 40GB 3P CABLEMÓVIL
            '881', --	FIBRA 600MB + ILIMITADA 40GB 3P CABLEMOVIL
            '882', --	FIBRA 600MB INDIRECTA + ILIMITADA 40GB 3P CABLEMOVIL
            '883', --	FIBRA 600MB + ILIMITADA 80GB 3P CABLEMOVIL
            '884'  --	FIBRA 600MB INDIRECTA + ILIMITADA 80GB 3P CABLEMOVIL
          )
        QUALIFY ROW_NUMBER() OVER(PARTITION BY MSISDN ORDER BY FECHA_ACTIVACION_MOVIL_ASOCIADO ASC)= 1
      ),

      CASO_2 AS (
        SELECT 
          mes_ini AS PERIODO_LIQ,
          a.* EXCEPT(PERIODO_MES,codigo_cliente),
          id_comisionista_MB,
          DESDE,
          HASTA,
          CASE
            WHEN REGEXP_CONTAINS(CAST(MOVIL_ASOCIADO AS STRING), r'^[67]') AND REGEXP_CONTAINS(CAST(MSISDN AS STRING), r'^[89]') THEN  
                    CASE 
                      WHEN FECHA_ACTIVACION_MOVIL_ASOCIADO > FECHA_ACT_FIBRA THEN 'Móvil activado después de fibra'
                      WHEN FECHA_ACTIVACION_MOVIL_ASOCIADO = FECHA_ACT_FIBRA THEN 'Móvil activado el mismo día que fibra'
                      ELSE 'Móvil activado antes de fibra'
                    END
            ELSE NULL
          END AS coments
        FROM `mm-b2b-reporting.SERVICES.detalle_marblanca_2024` a
        LEFT JOIN dealers_CM_MB e ON  a.codigo_cliente = e.id_comisionista_CM OR a.codigo_cliente= e.id_comisionista_MB
        LEFT JOIN (
          SELECT 
            DEALER, 
            DESDE,
            HASTA
          FROM `mm-commissions-reporting.GS.EXTRA_CAMPANA_MB`
          WHERE UPPER(tipo_linea) IN UNNEST(SPLIT(BA_MO, ','))
            AND FECHA_CAMPANA = LAST_DAY(mes_ini) 
        ) f ON f.DEALER = e.id_comisionista_MB
        WHERE 1=1
          AND codigo_cliente = e.id_comisionista_CM
          AND FECHA_ACT_FIBRA BETWEEN DESDE AND HASTA
          AND FECHA_DESACT_FIBRA IS NULL
          AND DATE_DIFF(FECHA_ACTIVACION_MOVIL_ASOCIADO,FECHA_ACT_FIBRA,DAY) > 15
        QUALIFY ROW_NUMBER() OVER(PARTITION BY MSISDN ORDER BY FECHA_ACTIVACION_MOVIL_ASOCIADO ASC)= 1
      ),

      CASO_3 AS (
        SELECT 
          mes_ini AS PERIODO_LIQ,
          a.* EXCEPT(PERIODO_MES,codigo_cliente),
          id_comisionista_MB,
          DESDE,
          HASTA,
          CASE
            WHEN REGEXP_CONTAINS(CAST(MOVIL_ASOCIADO AS STRING), r'^[67]') AND REGEXP_CONTAINS(CAST(MSISDN AS STRING), r'^[89]') THEN  
                    CASE 
                      WHEN FECHA_ACTIVACION_MOVIL_ASOCIADO > FECHA_ACT_FIBRA THEN 'Móvil activado después de fibra'
                      WHEN FECHA_ACTIVACION_MOVIL_ASOCIADO = FECHA_ACT_FIBRA THEN 'Móvil activado el mismo día que fibra'
                      ELSE 'Móvil activado antes de fibra'
                    END
            ELSE NULL
          END AS coments
        FROM `mm-b2b-reporting.SERVICES.detalle_marblanca_2024` a
        LEFT JOIN dealers_CM_MB e ON  a.codigo_cliente = e.id_comisionista_CM OR a.codigo_cliente= e.id_comisionista_MB
        LEFT JOIN (
          SELECT 
            DEALER, 
            DESDE,
            HASTA
          FROM `mm-commissions-reporting.GS.EXTRA_CAMPANA_MB`
          WHERE UPPER(tipo_linea) IN UNNEST(SPLIT(MO_BA, ','))
            AND FECHA_CAMPANA = LAST_DAY(mes_ini) 
        ) f ON f.DEALER = e.id_comisionista_MB
        WHERE 1=1
          AND codigo_cliente = e.id_comisionista_CM
          AND FECHA_ACT_FIBRA BETWEEN DESDE AND HASTA
          AND FECHA_DESACT_FIBRA IS NULL
          AND DATE_DIFF(FECHA_ACT_FIBRA,FECHA_ACTIVACION_MOVIL_ASOCIADO,DAY) > 15
        QUALIFY ROW_NUMBER() OVER(PARTITION BY MSISDN ORDER BY FECHA_ACTIVACION_MOVIL_ASOCIADO ASC)= 1
      )

    SELECT *
    FROM CASO_1

    UNION ALL

    SELECT *
    FROM CASO_2

    UNION ALL

    SELECT *
    FROM CASO_3
    );
  END IF;
END