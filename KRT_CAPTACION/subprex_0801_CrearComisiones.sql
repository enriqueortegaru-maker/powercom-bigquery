BEGIN
    

      DECLARE VMES_COMISION_ID INT64;
      --DECLARE DESDE, HASTA INT64;
      --SET DESDE=20230201;
      --SET HASTA=20230220;
      SET VMES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);


      -- PASO 1: CREAR TABLA COMISIONES 
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_ANTES_PONDERACION` AS
      SELECT v.* 
      FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` v;



    -- PASO 2: ACTUALIZO ATRIBUTO DE MES DE COMISION
    
    --ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` ADD COLUMN mes_comision_id INT64;
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` as 
    SELECT *, VMES_COMISION_ID as mes_comision_id 
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_ANTES_PONDERACION`;


    -- PASO 5: ACTUALIZO RAPPEL DE TODOS LOS  CANALES CUYO RAPPEL DEBE SER PONDERADO
      -- IMPORTANTE: De momento se emplea el campo nplays

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PONDERADAS` AS 
    SELECT c.*,p.ponderacion, c.importe*p.ponderacion as importe_ponderado  from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    inner join `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p on c.marca_ds=p.marca_ds
    AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
    --AND c.nplays=p.plays
    AND c.nplays_p=p.plays 
    AND TRIM(UPPER(c.cat_plays_p))!=TRIM(UPPER(Coalesce(p.exclusion,'NA')))  -- AÑADIDO EXCLUSIONES DE VIRGIN       
    AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL');
      


    UPDATE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    SET c.importe=c.importe*p.ponderacion
    FROM `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p
    WHERE c.marca_ds=p.marca_ds 
    AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
    --AND c.nplays=p.plays
    AND c.nplays_p=p.plays
    AND TRIM(UPPER(c.cat_plays_p))!=TRIM(UPPER(Coalesce(p.exclusion,'NA')))  -- AÑADIDO EXCLUSIONES DE VIRGIN            
    AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL');


    -- PASO 6: ELIMINO LAS COMISIONES ACTUALIZADAS CUYO RAPPEL ES DE VALOR 0

    DELETE FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    WHERE EXISTS (
        select *
        from `mm-commissions-reporting.KRT_CAPTACION.PARAM_RAPPEL_CANAL_PLAY` p
        WHERE c.marca_ds=p.marca_ds
        AND (((c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(p.subcanal_ds))='X')) OR (c.canal_alta_ds=p.canal_ds AND TRIM(UPPER(c.subcanal_ds))=TRIM(UPPER(p.subcanal_ds))))
        --AND c.nplays=p.plays
        AND c.nplays_p=p.plays
        AND TRIM(UPPER(c.cat_plays_p))!=TRIM(UPPER(COALESCE(p.exclusion,'NA')))  -- AÑADIDO EXCLUSIONES DE VIRGIN                 
        AND STARTS_WITH(TRIM(UPPER(c.concepto_ds)),'RAPPEL')
        AND c.importe=0
    );

END