BEGIN
    

      DECLARE VMES_COMISION_ID INT64;
      --VARIABLES LOCALES
      --DECLARE DESDE, HASTA INT64;
      --SET DESDE=20230401;
      --SET HASTA=20230430;
      --FIN VARIABLES LOCALES      
      SET VMES_COMISION_ID= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);


      -- PASO 1: CREAR TABLA COMISIONES 
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_ANTES_PONDERACION` AS
      SELECT distinct v.* 
      FROM `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` v;



    -- PASO 2: ACTUALIZAR ATRIBUTO DE MES DE COMISION
    
    --ALTER TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` ADD COLUMN mes_comision_id INT64;
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` as 
    SELECT *, VMES_COMISION_ID as mes_comision_id 
    FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_ANTES_PONDERACION`;


    -- PASO 3: ACTUALIZAR RAPPEL DE TODOS LOS  CANALES CUYO RAPPEL DEBE SER PONDERADO
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


    -- PASO 4: ELIMINAR LAS COMISIONES ACTUALIZADAS CUYO RAPPEL ES DE VALOR 0

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



  --- PASO 5: ELIMINAR COMISIONES PUBLICADAS EN MESES PREVIOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PUBLICADAS_MESES_PREVIOS` AS
    SELECT c.* 
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`c 
    --inner join `mm-commissions-reporting.KRT_CAPTACION.ACC_CAPTACION_HISTORICO` ch
    inner join `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` ch    
    on c.marca_ds=ch.marca_ds and c.Cliente_id=ch.Cliente_id  and c.servicio_id =ch.servicio_id and c.mes_comision_id!=ch.mes_comision_id
    where ch.mes_comision_id<VMES_COMISION_ID;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PUBLICADAS_MESES_PREVIOS_NO_LIQUIDADAS` AS
    SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    WHERE EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PUBLICADAS_MESES_PREVIOS` cp
      where c.marca_ds=cp.marca_ds and c.Cliente_id=cp.Cliente_id  and c.servicio_id =cp.servicio_id and  c.mes_comision_id<VMES_COMISION_ID 
      --- Considero las comisiones de unitarios que fueron liquidadas con importes positivos en meses previos
      and cp.importe >0 
    );

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PUBLICADAS_MESES_LIQUIDADAS` AS
    SELECT *  FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    WHERE EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PUBLICADAS_MESES_PREVIOS` cp
      where c.marca_ds=cp.marca_ds and c.Cliente_id=cp.Cliente_id  and c.servicio_id =cp.servicio_id and  c.mes_comision_id<VMES_COMISION_ID 
      --- Elimino las comisiones de unitarios que fueron liquidadas con importes positivos en meses previos
      and cp.importe <0 
    );

  
    DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    WHERE EXISTS (
      SELECT 1
      FROM  `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_PUBLICADAS_MESES_PREVIOS_NO_LIQUIDADAS` cp
      where c.marca_ds=cp.marca_ds and c.Cliente_id=cp.Cliente_id  and c.servicio_id =cp.servicio_id and  c.mes_comision_id=cp.mes_comision_id
    );
 

 --- PASO 6: PUBLICAR COMISIONES DUPLICADAS EN MES DE COMISION
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0801_COMISIONES_DUPLICADAS_MES_COMISION` AS
    with ncom as (select marca_ds, cliente_id, servicio_id, CONCEPTO_DS, count(importe) as ncom, sum(importe) as importe
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` as com
    where not contains_substr(concepto_ds,'cancela')
    group by 1,2,3,4) 
    select c.*
    from ncom
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c
    on ncom.marca_ds=c.marca_ds and ncom.Cliente_id=c.Cliente_id and coalesce(ncom.servicio_id,0)=coalesce(c.servicio_id,0) and ncom.concepto_ds=c.concepto_ds
    where ncom.ncom>1 
    order by c.marca_ds, c.cliente_id, c.servicio_id, c.concepto_ds;


END