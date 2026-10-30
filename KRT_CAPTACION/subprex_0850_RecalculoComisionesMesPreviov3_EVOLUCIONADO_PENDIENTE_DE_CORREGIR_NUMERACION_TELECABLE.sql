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
    --DECLARE DESDE_PREVIO INT64;SET DESDE_PREVIO=20240501;SET VVERSION=14;
    SET NMESES=DATE_DIFF(CURRENT_DATE(),parse_date('%Y%m%d', CAST ( DESDE_PREVIO AS string)), MONTH);

    SET vversion=CAST((SELECT `mm-commissions-reporting.KRT_CAPTACION.getVersion_nmonths`(NMESES) as vversion) as INT64) ;
    SET desde =	CAST(FORMAT_DATE("%Y%m%d",date_trunc(date_sub(CURRENT_DATE(), interval NMESES month), month)) AS INT64);
    SET hasta =	CAST(FORMAT_DATE("%Y%m%d",LAST_DAY(date_sub(CURRENT_DATE(), interval NMESES month))) AS INT64);
    SET vmes_Comision_id=CAST(hasta/100 AS INT64);

    ---- SELECT desde_previo, nmeses, vversion, desde, hasta, vmes_comision_id;



    -------------------------------------------------------------------------------
    ----
    ----  PASO 0: CREO TABLAS BASE PARA DESARROLLO
    ----
        
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


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_0M` as 
    -- DESARROLLO
    --select * from `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where fecha_calc_dt='2023-03-16' and hasta=20230228 and version=6; 
    -- PRODUCCION
    select * from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` ; 




    -------------------------------------------------------------------------------
    ----
    ----  PASO 1: IDENTIFICO POBLACIONES 
    ----
        

    -------------
    --- EL RESULTADO DE ESTA CONSULTA SE SUBDIVIDE EN CINCO GRUPOS
    ---   GRUPO 1: REGISTROS DE SERVICIOS CON UN ID NO COMISIONADO PREVIAMENTE 
	---				-> REGISTRO ALTA TIPIFICADO CLASE A R -Recalculo periodo anterior y desc_mm heredado pero modificando la primera letra del prefijo por X
	---
    ---         GRUPO 1.1: REGISTROS DE SERVICIOS BASICOS Y SVAS (GRID 111)
    ---         GRUPO 1.2: REGISTROS DE CANCELACIONES (GRID 112)
    ---
    ---   GRUPO 2: REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE	
    ---         GRUPO 2.1: REGISTROS DE SERVICIOS CON COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CONCEPTO_DS PREVIO Y POSTERIOR NULO 								-> NO SE HACE NADA  
    ---         GRUPO 2.2: SERVICIOS DE BANDA ANCHA CON COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO (GRID 122) 						-> REGISTRO DE BAJA Y POSTERIOR ALTA
    ---         GRUPO 2.3: REGISTROS DE SERVICIOS NO DE BANDA ANCHA CON COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO(GRID 123)	-> REGISTRO DE BAJA Y POSTERIOR ALTA 
	
	
    ---   GRUPO 3: REGISTROS DE SERVICIOS CON DISTINTO VALOR DE RAPPEL TEORICO COMISIONADO
    ---         GRUPO 3.1: REGISTROS CON DISTINTO IMPORTE COMISIONADO POR RAPPEL (GRID 131)
    ---         GRUPO 3.2: REGISTROS CON DISTINTO IMPORTE COMISIONADO POR  PENALIZACION DE RAPPEL (GRID 132)



    ---   GRUPO 5: REGISTROS DE SERVICIOS CON UN ID NO COMISIONADO ACTUALMENTE 
	---				-> REGISTRO ALTA TIPIFICADO CLASE A R -Recalculo periodo anterior y desc_mm heredado pero modificando la primera letra del prefijo por X
	---
    ---         GRUPO 5.1: REGISTROS DE SERVICIOS BASICOS Y SVAS (GRID 151)


	---   GRUPO 6: REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS COMISIONADO PREVIAMENTE	
	---			GRUPO 6.1: REGISTROS DE SERVICIOS DE BANDA ANCHA CON COMBINACION DE ID y CONCEPTO_DS COMISIONADO PREVIAMENTE Y NO COMISIONADO EN ACTUAL (GRID 161)					  		-> REGISTRO DE BAJA
	


	-----------------------------------------------------------------------------------------------------
	---
    ---   GRUPO 1: APUNTES DE SERVICIOS CON UN ID NO COMISIONADO PREVIAMENTE 
    ---
    ---             -> REGISTRO ALTA TIPIFICADO CLASE A R -Recalculo periodo anterior y desc_mm heredado pero modificando la primera letra del prefijo por X
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR1_COM_1M_LIST_COM_DIST_SID` as 
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
    SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR1_COM_1M_LIST_COM_DIST_SID`;
    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R -'), grid=111 WHERE 1=1;


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
    and ((CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal') OR CONTAINS_SUBSTR(c2.clase_mm,'penaliza') ) and CONTAINS_SUBSTR(c2.desc_mm,'cancela'))  
    --and NOT (CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal') AND NOT (CONTAINS_SUBSTR(c2.desc_mm,'Cancela') ) )
    and c2.servicio_id is not null; 


    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_CANCELACIONES_1M` SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R -'), grid=112 WHERE 1=1;

    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_CANCELACIONES_1M`;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_CANCELACIONES_NUEVAS_1M` as 
    SELECT * from `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_CANCELACIONES_1M`;

	---
    ---   FIN GRUPO 1
	---
	-----------------------------------------------------------------------------------------------------



	-----------------------------------------------------------------------------------------------------
	---
    ---   GRUPO 2: REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID DE SERVICIO y CONCEPTO_DS 
    ---         GRUPO 2.1: REGISTROS DE SERVICIOS CON 
    ---                       COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE  
    ---                       Y CONCEPTO_DS PREVIO Y POSTERIOR NULO 
    ---                       -> NO SE HACE NADA  
    ---         GRUPO 2.2: SERVICIOS DE BANDA ANCHA CON 
    ---                       COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE 
    ---                       Y CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO 
    ---                       -> REGISTRO DE BAJA Y POSTERIOR ALTA
    ---         GRUPO 2.3: REGISTROS DE SERVICIOS NO DE BANDA ANCHA CON 
    ---                       COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE
    ---                       Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO 
    ---                      -> REGISTRO DE BAJA Y POSTERIOR ALTA 



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` as 
    SELECT distinct null as idtipo, c2.* 
    from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    WHERE NOT EXISTS(
      SELECT 1 
      FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
      where c1.marca_ds=c2.marca_ds
      and c1.cliente_id=c2.cliente_id
      and c1.categoria_servicio_ds=c2.categoria_servicio_ds
      and c1.servicio_id=c2.servicio_id
      and c1.concepto_ds=c2.concepto_ds
      --and c1.importe=c2.importe
    )
	and NOT EXISTS(
      SELECT 1 
      FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
      where c1.marca_ds=c2.marca_ds
      and c1.cliente_id=c2.cliente_id
      and c1.categoria_servicio_ds=c2.categoria_servicio_ds
      and c1.servicio_id=c2.servicio_id
      and c1.importe=c2.importe
    )
    and NOT EXISTS(
      SELECT 1 
      FROM   `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` c1
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


	-----------------------------------------------------------------------------------------------------------------
	---
    ---         GRUPO 2.1: REGISTROS DE SERVICIOS CON 
	---							UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE  
	---							CONCEPTO_DS PREVIO Y POSTERIOR NULO 
	---
	---						-> NO HACER NADA
	
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    SET idtipo=21, grid=121
    WHERE EXISTS (
      select 1 
      from (
        Select dci.*
        from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dci
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1 
        on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
        on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
		--- Concepto anterior y posterior nulo
        where c1.concepto_ds is null 
        and c2.concepto_ds is null
        order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
      ) dcf
      where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
    );


	/*
    -- REGISTROS A DAR DE BAJA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR21_OPERACIONES_BAJA_1M` as 
    select distinct c1.*
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
    on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
    where dc.idtipo=21;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR21_OPERACIONES_BAJA_1M`
    SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por migracion de'), grid=121  where 1=1;


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR21_OPERACIONES_BAJA_1M`;-- where marca_ds="R";


    -- REGISTROS A DAR DE ALTA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR21_OPERACIONES_ALTA_1M` as 
    select distinct c2.* 
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
    where dc.idtipo=21;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR21_OPERACIONES_ALTA_1M`
    SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por migracion de'), grid=121  where 1=1;
      
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR21_OPERACIONES_ALTA_1M`;-- where marca_ds="R";

	*/

	-----------------------------------------------------------------------------------------------------------------
	---
    ---         GRUPO 2.2: REGISTROS DE SERVICIOS DE CON 
	---							UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y 
	---							CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO DE BAJA YN POSTERIOR ALTA
	---
	
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    SET idtipo=22, grid=122
    WHERE EXISTS (
      select 1 
      from (
        Select dci.*
        from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dci
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1 
        on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
        on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
		where c1.concepto_ds is not null and c2.concepto_ds is not null
        --where c1.categoria_servicio_ds="BANDA ANCHA"
        order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
      ) dcf
      where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
    );
	


    -- REGISTROS A DAR DE BAJA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR22_OPERACIONES_BAJA_1M` as 
    select distinct c1.*
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
    on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
    where /*dc.categoria_servicio_ds="BANDA ANCHA" and*/ dc.idtipo=22;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR22_OPERACIONES_BAJA_1M`
    SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por migracion de'), grid=122  where 1=1;


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR22_OPERACIONES_BAJA_1M`;-- where marca_ds="R";


    -- REGISTROS A DAR DE ALTA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR22_OPERACIONES_ALTA_1M` as 
    select distinct c2.* 
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
    where /*dc.categoria_servicio_ds="BANDA ANCHA" and*/ dc.idtipo=22;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR22_OPERACIONES_ALTA_1M`
    SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por migracion de'), grid=122  where 1=1;
      
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR22_OPERACIONES_ALTA_1M`;-- where marca_ds="R";

/*
	-----------------------------------------------------------------------------------------------------------------
	---
    ---         GRUPO 2.3: 97 REGISTROS DE SERVICIOS NO DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO A TABLA REGITRANDO GRUPO
	---
	
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    SET idtipo=23, grid=123
    WHERE EXISTS (
      select 1 
      from (
        Select dci.*
        from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dci
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1 
        on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
        left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
        on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
        where c1.categoria_servicio_ds!="BANDA ANCHA"
        order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
      ) dcf
      where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
    );
	



    -- REGISTROS A DAR DE BAJA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR23_OPERACIONES_BAJA_1M` as 
    select distinct c1.*
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
    on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
    where dc.categoria_servicio_ds!="BANDA ANCHA" and dc.idtipo=23;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR23_OPERACIONES_BAJA_1M`
    SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por migracion de'), grid=123  where 1=1;


    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` 
	select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR23_OPERACIONES_BAJA_1M`;-- where marca_ds="R";


    -- REGISTROS A DAR DE ALTA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR23_OPERACIONES_ALTA_1M` as 
    select distinct c2.* 
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` dc
    inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
    on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
    where dc.categoria_servicio_ds!="BANDA ANCHA" and dc.idtipo=23;

    UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR23_OPERACIONES_ALTA_1M`
    SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por migracion de'), grid=123  where 1=1;
      
    INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR23_OPERACIONES_ALTA_1M`;-- where marca_ds="R";
*/
	---
    ---   FIN GRUPO 2
	---
	-----------------------------------------------------------------------------------------------------




	-----------------------------------------------------------------------------------------------------
	---
  ---     GRUPO 3: REGISTROS DE SERVICIOS CON DISTINTO VALOR DE RAPPEL TEORICO COMISIONADO
  ---           GRUPO 3.1: REGISTROS CON DISTINTO IMPORTE COMISIONADO POR RAPPEL 
	---           GRUPO 3.2: REGISTROS CON DISTINTO IMPORTE COMISIONADO POR  PENALIZACION DE RAPPEL 


		-----------------------------------------------------------------------------------------------------------------
		---
		---         GRUPO 3.1: REGISTROS CON DISTINTO IMPORTE COMISIONADO POR RAPPEL 
		---
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR3_COM_1M_LIST_COM_DIST_RAPPEL` as 
		SELECT CAST(31 AS INT64) as idtipo, c2.*
		from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		WHERE EXISTS (
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  and c1.clase_mm=c2.clase_mm
		  and c1.desc_mm=c2.desc_mm
		  and c1.importe!=c2.importe 
		  --and c1.concepto_ds=c2.concepto_ds
		)
		and CONTAINS_SUBSTR(c2.clase_mm,'D - Extracomision')
		and CONTAINS_SUBSTR(c2.desc_mm,'Rappel');    
		
		

		-- REGISTROS A DAR DE BAJA

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR31_OPERACIONES_BAJA_CAMBIO_RAPPEL` as 
		select distinct c1.*
		from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR3_COM_1M_LIST_COM_DIST_RAPPEL` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
		on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm;
		--where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=31;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR31_OPERACIONES_BAJA_CAMBIO_RAPPEL`
		SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por actualización de'), grid=131  where 1=1;


		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR31_OPERACIONES_BAJA_CAMBIO_RAPPEL`;-- where marca_ds="R";


		-- REGISTROS A DAR DE ALTA
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR31_OPERACIONES_ALTA_CAMBIO_RAPPEL` as 
		select distinct c2.* 
		from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR3_COM_1M_LIST_COM_DIST_RAPPEL` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm;


		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR31_OPERACIONES_ALTA_CAMBIO_RAPPEL`
		SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por actualización de'), grid=131  where 1=1;
		  
		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR31_OPERACIONES_ALTA_CAMBIO_RAPPEL`;-- where marca_ds="R";




		-----------------------------------------------------------------------------------------------------------------
		---
		---         GRUPO 3.2: REGISTROS CON DISTINTO IMPORTE COMISIONADO POR  PENALIZACION DE RAPPEL 
		---
		
		
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR32_COM_1M_LIST_COM_DIST_PENALIZA_RAPPEL` as 
		SELECT  distinct CAST(32 AS INT64) idtipo,  c2.*
		from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		WHERE EXISTS (
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  and c1.clase_mm=c2.clase_mm
		  and c1.desc_mm=c2.desc_mm
		  and c1.importe!=c2.importe 
		  --and c1.concepto_ds=c2.concepto_ds
		)
		and CONTAINS_SUBSTR(c2.clase_mm,'P - Penaliza')
		and CONTAINS_SUBSTR(c2.desc_mm,'Rappel');    
		

		-- REGISTROS A DAR DE BAJA

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR32_OPERACIONES_BAJA_PENALIZA_RAPPEL` as 
		select distinct c1.*
		from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR32_COM_1M_LIST_COM_DIST_PENALIZA_RAPPEL` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
		on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
		where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=32;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR32_OPERACIONES_BAJA_PENALIZA_RAPPEL`
		SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por actualización de'), grid=132  where 1=1;


		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR32_OPERACIONES_BAJA_PENALIZA_RAPPEL`;-- where marca_ds="R";


		-- REGISTROS A DAR DE ALTA
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR32_OPERACIONES_ALTA_PENALIZA_RAPPEL` as 
		select distinct c2.* 
		from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR32_COM_1M_LIST_COM_DIST_PENALIZA_RAPPEL` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
		where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=32;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR32_OPERACIONES_ALTA_PENALIZA_RAPPEL`
		SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por actualización de'), grid=132  where 1=1;
		  
		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR32_OPERACIONES_ALTA_PENALIZA_RAPPEL`;-- where marca_ds="R";

		--- LOG TRAS GRUPO 3 
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OUT_GR32` as  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`;

	---
  ---   FIN GRUPO 3
	---
	-----------------------------------------------------------------------------------------------------



	----------------------------------------------------------------------------------------------------------------
	---
  ---     GRUPO 4: REGISTROS DE SERVICIOS CON DISTINTO VALOR DE IMPORTE COMISIONADA POR POSTVENTA O EXTRAS
  ---           GRUPO 4.1: REGISTROS CON APUNTE POSTVENTA PREVIO Y POSTERIOR PERO CON DISTINTO IMPORTE
	---           GRUPO 4.5: REGISTROS CON APUNTE EXTRA PREVIO Y POSTERIOR PERO CON DISTINTO IMPORTE


		-----------------------------------------------------------------------------------------------------------------
		---
		---         GRUPO 4.1: REGISTROS CON APUNTE POSTVENTA PREVIO Y POSTERIOR PERO CON DISTINTO IMPORTE
		---
		
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR41_COM_1M_LIST_COM_DIST_POSTVENTA` as 
		SELECT CAST(41 AS INT64) as idtipo, c2.*
		from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		WHERE EXISTS (
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  and c1.clase_mm=c2.clase_mm
		  and c1.desc_mm=c2.desc_mm
		  and c1.importe!=c2.importe 
		  --and c1.concepto_ds=c2.concepto_ds
		)
		and CONTAINS_SUBSTR(c2.clase_mm,'D - Extracomision')
		and CONTAINS_SUBSTR(c2.desc_mm,'Postventa');    
		

		-- REGISTROS A DAR DE BAJA

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR41_OPERACIONES_BAJA_POSTVENTA` as 
		select distinct c1.*
		from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR41_COM_1M_LIST_COM_DIST_POSTVENTA` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
		on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
		where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=41;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR41_OPERACIONES_BAJA_POSTVENTA`
		SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por actualización de'), grid=141  where 1=1;


		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR41_OPERACIONES_BAJA_POSTVENTA`;-- where marca_ds="R";


		-- REGISTROS A DAR DE ALTA
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR41_OPERACIONES_ALTA_POSTVENTA` as 
		select distinct c2.* 
		from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR41_COM_1M_LIST_COM_DIST_POSTVENTA` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
		where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=41;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR41_OPERACIONES_ALTA_POSTVENTA`
		SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por actualización de'), grid=141  where 1=1;
		  
		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR41_OPERACIONES_ALTA_POSTVENTA`;-- where marca_ds="R";

		--- LOG TRAS GRUPO 4.1 
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OUT_GR41` as  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`;



		-----------------------------------------------------------------------------------------------------------------
		---
		---         GRUPO 4.5: REGISTROS CON APUNTE EXTRA PREVIO Y POSTERIOR PERO CON DISTINTO IMPORTE
		---
		
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR45_COM_1M_LIST_COM_DIST_EXTRA` as 
		SELECT CAST(45 AS INT64) as idtipo, c2.*
		from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		WHERE EXISTS (
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M`c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  and c1.clase_mm=c2.clase_mm
		  and c1.desc_mm=c2.desc_mm
		  and c1.importe!=c2.importe 
		  --and c1.concepto_ds=c2.concepto_ds
		)
		and CONTAINS_SUBSTR(c2.clase_mm,'D - Extracomision')
		and CONTAINS_SUBSTR(c2.desc_mm,'D - Extra');    
		

		-- REGISTROS A DAR DE BAJA

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR45_OPERACIONES_BAJA_EXTRA` as 
		select distinct c1.*
		from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR45_COM_1M_LIST_COM_DIST_EXTRA` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
		on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
		where dc.idtipo=45;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR45_OPERACIONES_BAJA_EXTRA`
		SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por actualización de'), grid=145  where 1=1;


		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR45_OPERACIONES_BAJA_EXTRA`;-- where marca_ds="R";


		-- REGISTROS A DAR DE ALTA
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR45_OPERACIONES_ALTA_EXTRA` as 
		select distinct c2.* 
		from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR45_COM_1M_LIST_COM_DIST_EXTRA` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M` c2
		on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
		where dc.idtipo=45;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR45_OPERACIONES_ALTA_EXTRA`
		SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por actualización de'), grid=145  where 1=1;
		  
		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR45_OPERACIONES_ALTA_EXTRA`;-- where marca_ds="R";

		--- LOG TRAS GRUPO 4.5 
		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_OUT_GR45` as  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`;







	---
  ---   FIN GRUPO 4
	---
	-----------------------------------------------------------------------------------------------------



	-----------------------------------------------------------------------------------------------------
	---
    ---   GRUPO 5: APUNTES DE SERVICIOS CON UN ID NO COMISIONADO ACTUALMENTE
    ---         GRUPO 5.1: REGISTROS DE SERVICIOS LIQUIDADOS PERO INACTIVOS EN EL MOMENTO DE EJECUCION DEL RECALCULO
    ---

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR51_COM_0M_LIST_COM_DIST_SID` as 
		SELECT * 
		from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
		WHERE NOT EXISTS(
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M`c2
		  where c2.marca_ds=c1.marca_ds
		  and c2.cliente_id=c1.cliente_id
		  and c2.categoria_servicio_ds=c1.categoria_servicio_ds
		  and c2.servicio_id=c1.servicio_id
		  --and c1.concepto_ds=c2.concepto_ds
		)
		--- Añadido para excluir las ya procesadas		
		and NOT EXISTS(
		  SELECT 1 
		  FROM   `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` c2
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  --and c1.concepto_ds=c2.concepto_ds
		) 	
		--- Añadido para excluir las bajas que se hayan podido dar desde la liquidación 
		and NOT EXISTS(
		  SELECT 1 
		  FROM   `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_0M` c2
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  --and c1.concepto_ds=c2.concepto_ds
		) 	
			
		and NOT CONTAINS_SUBSTR(c1.clase_mm,'F - Gestion de canal')
		and NOT CONTAINS_SUBSTR(c1.clase_mm,'Z - Ajustes') 
		and c1.servicio_id is not null; 


	
		-- REGISTROS A DAR DE BAJA

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR51_OPERACIONES_BAJA` as 
		select distinct c1.*
		from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR51_COM_0M_LIST_COM_DIST_SID` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
		on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR51_OPERACIONES_BAJA`
		SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por actualización de'), grid=151  where 1=1;


		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR51_OPERACIONES_BAJA`;-- where marca_ds="R";

		

	---
    ---   FIN GRUPO 5
	---
	-----------------------------------------------------------------------------------------------------

/*
	-----------------------------------------------------------------------------------------------------
	---
	---   GRUPO 6: REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE	
	---			GRUPO 6.1: REGISTROS DE SERVICIOS DE BANDA ANCHA CON COMBINACION DE ID y CONCEPTO_DS COMISIONADO PREVIAMENTE Y NO COMISIONADO EN ACTUAL 					  		-> REGISTRO DE BAJA


		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR61_COM_0M_LIST_COM_DIST_CONCEPTO` as 
		SELECT distinct null as idtipo, c2.* 
		from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c2
		WHERE NOT EXISTS(
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M`c1
		  where c2.marca_ds=c1.marca_ds
		  and c2.cliente_id=c1.cliente_id
		  and c2.categoria_servicio_ds=c1.categoria_servicio_ds
		  and c2.servicio_id=c1.servicio_id
		  and c2.concepto_ds=c1.concepto_ds
		  --and c1.importe=c2.importe
		)
		and NOT EXISTS(
		  SELECT 1 
		  FROM   `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR51_COM_0M_LIST_COM_DIST_SID` c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  --and c1.concepto_ds=c2.concepto_ds
		) 
		and NOT EXISTS(
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_0M`c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  and c1.importe=c2.importe
		) 
		and NOT EXISTS(
		  SELECT 1 
		  FROM  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR2_COM_1M_LIST_COM_DIST_CONCEPTO` c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  --and c1.importe=c2.importe
		)     
		and NOT EXISTS(
		  SELECT 1 
		  FROM   `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` c1
		  where c1.marca_ds=c2.marca_ds
		  and c1.cliente_id=c2.cliente_id
		  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
		  and c1.servicio_id=c2.servicio_id
		  --and c1.concepto_ds=c2.concepto_ds
		) 	
		--- Añadido para excluir las bajas que se hayan podido dar desde la liquidación 
		and NOT EXISTS(
		  SELECT 1 
		  FROM   `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES_0M` c1
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



		-- REGISTROS A DAR DE BAJA

		CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR61_OPERACIONES_BAJA` as 
		select distinct c1.*
		from  `mm-commissions-reporting.KRT_CAPTACION.AUDIT_RECALCULO_GR61_COM_0M_LIST_COM_DIST_CONCEPTO` dc
		inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_1M` c1
		on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm;

		UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR61_OPERACIONES_BAJA`
		SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por actualización de'), grid=161  where 1=1;


		INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_GR51_OPERACIONES_BAJA`;-- where marca_ds="R";

	*/



	---
    ---   FIN GRUPO 6
	---
	-----------------------------------------------------------------------------------------------------



    --- CREA FICHERO LOG DE SALIDA 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0850_RECALCULO_COMISIONES_1M` as 
    SELECT * FROM  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`;

END