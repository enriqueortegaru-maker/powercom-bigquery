BEGIN


    ------------------------------------------------------------
    ---
    ---   MEJORA A DESARROLLAR
    ---
    ---   pasar por parámetro nuevas variables que denominaremos desde_previo y hasta_previo,que registran las fecha límites del mes en el que se va a realizar la comparativa
    ---   Calcular la diferencia en meses entre la fecha desde_previo y la fecha actual. El valor de la diferencia se registrar en una nueva variable.
    ---   sustituir el valor 1 que se pasa por parametro que determina el valor de las variables vversion, desde y hasta por la nueva variable

    --DECLARE fecha date;


    DECLARE desde, hasta, vmes_comision_id, vversion,nmeses int64;
    --- LOCAL
    ---DECLARE DESDE_PREVIO INT64;SET DESDE_PREVIO=20230401;SET VVERSION=8;
    SET NMESES=DATE_DIFF(CURRENT_DATE(),parse_date('%Y%m%d', CAST ( DESDE_PREVIO AS string)), MONTH);

    SET vversion=CAST((SELECT `mm-commissions-reporting.KRT_CAPTACION.getVersion_nmonths`(NMESES) as vversion) as INT64) ;
    SET desde =	CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval NMESES month), month)) AS INT64);
    SET hasta =	CAST(FORMAT_DATE("%Y%m%d",LAST_DAY(date_sub(CURRENT_DATE(), interval NMESES month))) AS INT64);
    SET vmes_Comision_id=CAST(hasta/100 AS INT64);

  SELECT desde_previo, nmeses, vversion, desde, hasta, vmes_comision_id;

    ----- PASO 1.3: LEO COMISIONES DE TABLA AGG_COMISIONES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` as 
    SELECT c.* except(fecha_calc_dt, desde, hasta, version)
    FROM `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` as c
    WHERE EXISTS(
      select 1 
      from  `mm-commissions-reporting.KRT_CAPTACION.PARAM_PUBLICACION` as r
      where r.marca_ds=c.marca_ds
      and r.mes_comision_id = vmes_comision_id
      and r.fecha_id=CAST(FORMAT_DATE("%Y%m%d",c.fecha_calc_dt) as INT64)  
      and c.version=vversion    
    );


    -- CREO TABLAS BASE PARA DESARROLLO
    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1` as 
    --select * from `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where hasta=20230228 and version=6  and ((fecha_calc_dt='2023-03-02'and marca_ds='R') OR (fecha_calc_dt='2023-03-07'and marca_ds!='R') );
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` as 
    -- DESARROLLO
    --select * from `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where fecha_calc_dt='2023-03-16' and hasta=20230228 and version=6; 
    -- PRODUCCION
    select * from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` ; 


    --- CONSULTA QUE REGISTRA 883 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID  y CONCEPTO_DS NO COMISIONADO PREVIAMENTE
    SELECT * 
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    WHERE NOT EXISTS(
      SELECT 1 
      FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
      where c1.marca_ds=c2.marca_ds
      and c1.cliente_id=c2.cliente_id
      and c1.categoria_servicio_ds=c2.categoria_servicio_ds
      and c1.servicio_id=c2.servicio_id
      and TRIM(c1.concepto_ds)=TRIM(c2.concepto_ds)
    ) 
    and NOT CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal')
    and NOT CONTAINS_SUBSTR(c2.clase_mm,'Z - Ajustes') 
    and c2.servicio_id is not null; 

    -------------
    --- EL RESULTADO DE ESTA CONSULTA SE SUBDIVIDE EN DOS GRUPOS
    ---   GRUPO 1: 708 REGISTROS DE SERVICIOS CON UN ID NO COMISIONADO PREVIAMENTE -> REGISTRO ALTA TIPIFICADO CLASE A R -Recalculo periodo anterior y desc_mm heredado pero modificando la primera letra del prefijo por X
    ---         GRUPO 1.1: REGISTROS DE SERVICIOS BASICOS Y SVAS
    ---         GRUPO 1.2: REGISTROS DE CANCELACIONES
    ---
    ---   GRUPO 2: 175 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE
    ---         GRUPO 2.1: 34 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR NULO -> REGISTRO A TABLA DE ANALISIS REGISTRANDO GRUPO
    ---         GRUPO 2.2: 44 REGISTROS DE SERVICIOS DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO DE BAJA YN POSTERIOR ALTA
    ---         GRUPO 2.3: 97 REGISTROS DE SERVICIOS NO DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO A TABLA REGITRANDO GRUPO


    ---   GRUPO 1: 
    ---         GRUPO 1.1:708 REGISTROS DE SERVICIOS CON UN ID NO COMISIONADO PREVIAMENTE -> REGISTRO ALTA TIPIFICADO CLASE A R -Recalculo periodo anterior y desc_mm heredado pero modificando la primera letra del prefijo por X
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_SID` as 
    SELECT * 
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    WHERE NOT EXISTS(
      SELECT 1 
      FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
      where c1.marca_ds=c2.marca_ds
      and c1.cliente_id=c2.cliente_id
      and c1.categoria_servicio_ds=c2.categoria_servicio_ds
      and c1.servicio_id=c2.servicio_id
      --and c1.concepto_ds=c2.concepto_ds
    )
    and NOT CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal')
    and NOT CONTAINS_SUBSTR(c2.clase_mm,'Z - Ajustes') 
    and c2.servicio_id is not null; 



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` as 
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_SID`;
    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R -') WHERE 1=1;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_COMISIONES_NUEVAS_1M` as 
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`;


    ---         GRUPO 1.2: REGISTROS DE CANCELACIONES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_CANCELACIONES_1M` as 
    SELECT * 
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    WHERE NOT EXISTS(
      SELECT 1 
      FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
      where c1.marca_ds=c2.marca_ds
      and c1.cliente_id=c2.cliente_id
      and c1.categoria_servicio_ds=c2.categoria_servicio_ds
      and c1.servicio_id=c2.servicio_id
      and c1.concepto_ds=c2.concepto_ds
    )
    and CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal') and CONTAINS_SUBSTR(c2.desc_mm,'cancela')
    --and NOT (CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal') AND NOT (CONTAINS_SUBSTR(c2.desc_mm,'Cancela') ) )
    and c2.servicio_id is not null; 


    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_CANCELACIONES_1M` SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R -') WHERE 1=1;

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_CANCELACIONES_1M`;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_CANCELACIONES_NUEVAS_1M` as 
    SELECT * from `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_CANCELACIONES_1M`;


    ---   GRUPO 2: 175 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` as 
    SELECT null as idtipo, c2.* 
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    WHERE NOT EXISTS(
      SELECT 1 
      FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
      where c1.marca_ds=c2.marca_ds
      and c1.cliente_id=c2.cliente_id
      and c1.categoria_servicio_ds=c2.categoria_servicio_ds
      and c1.servicio_id=c2.servicio_id
      and c1.concepto_ds=c2.concepto_ds
    )
    and NOT EXISTS(
      SELECT 1 
      FROM   `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_SID` c1
      where c1.marca_ds=c2.marca_ds
      and c1.cliente_id=c2.cliente_id
      and c1.categoria_servicio_ds=c2.categoria_servicio_ds
      and c1.servicio_id=c2.servicio_id
      --and c1.concepto_ds=c2.concepto_ds
    )
    and NOT CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal')
    and NOT CONTAINS_SUBSTR(c2.clase_mm,'Z - Ajustes') 
    and c2.servicio_id is not null
    --and c2.cliente_id=3518206
    order by c2.marca_Ds, c2.cliente_id, c2.servicio_id, c2.concepto_ds; 

    ---         GRUPO 2.1: 34 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR NULO -> REGISTRO A TABLA DE ANALISIS REGISTRANDO GRUPO

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    SET idtipo=21
    WHERE EXISTS (
      select 1 
      from (
        Select dci.*
        from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dci
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1 
        on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
        on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
        where c1.concepto_ds is null 
        and c2.concepto_ds is null
        order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
      ) dcf
      where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
    );

    ---         GRUPO 2.2: 44 REGISTROS DE SERVICIOS DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO DE BAJA YN POSTERIOR ALTA

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    SET idtipo=22
    WHERE EXISTS (
      select 1 
      from (
        Select dci.*
        from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dci
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1 
        on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
        on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
        where c1.categoria_servicio_ds="BANDA ANCHA"
        order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
      ) dcf
      where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
    );


    -- REGISTROS A DAR DE BAJA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OPERACIONES_BAJA_1M` as 
    select c1.*
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
    on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
    where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=22;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OPERACIONES_BAJA_1M`
    SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por migracion de')  where 1=1;


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OPERACIONES_BAJA_1M`;-- where marca_ds="R";


    -- REGISTROS A DAR DE ALTA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OPERACIONES_ALTA_1M` as 
    select c2.* 
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
    where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=22;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OPERACIONES_ALTA_1M`
    SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por migracion de')  where 1=1;
      
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OPERACIONES_ALTA_1M`;-- where marca_ds="R";


    ---         GRUPO 2.3: 97 REGISTROS DE SERVICIOS NO DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO A TABLA REGITRANDO GRUPO

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    SET idtipo=23
    WHERE EXISTS (
      select 1 
      from (
        Select dci.*
        from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dci
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1 
        on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
        on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
        where c1.categoria_servicio_ds!="BANDA ANCHA"
        order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
      ) dcf
      where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
    );


    --- CREA FICHERO LOG DE SALIDA 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_RECALCULO_COMISIONES_1M` as 
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`;

END