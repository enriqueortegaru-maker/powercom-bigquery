BEGIN

  ---======================================================================================================
  --- MODULO QUE ENRIQUECE EL EVENTOS EN CLIENTES QUE HAN SIDO OBJETO DE UNA CAMPAÑA CON DOS CAMPOS
  ---   CAMPANA_ID: IDENTIFICATIVO DE LA CAMPAÑA
  ---   NOMBRE_CAMPANA: NOMBRE DE LA CAMPAÑA
  ---   
  ---  PARA ELLO EN ESTE MODULO SE CRUZAN 
  ---    LOS EVENTOS REALIZADOS POR CANALES DE TELEVENTAS 
  ---    LA POBLACION DE CLIENTES OBJETIVO DE LAS CAMPAÑAS DESCUBIERTAS Y VIGENTES
  ---    LA POBLACION DE CAMPAÑAS PARAMETRIZADAS, SEGMENTADAS POR MARCA, DISTRIBUIDOR, MARCO RETRIBUTIVO Y CUMPLIMIENTO DE OBJETIVOS DE CAMPAÑA (MULTIPLICADOR EN UPG y NIVEL ALCANZADO EN UPD)
  ---
  ---  SE GESTIONAN CASOS EN LOS QUE UN EVENTO PUEDE RELACIONARSE A MAS DE 1 CAMPAÑA
  ---
  ---======================================================================================================


    --create or replace table `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS  select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0301_MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

    --- PASO 0: EVITO DUPLICIDADES EN PARAMETRIZACION DE CAMPAÑAS
    create or replace table `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` AS 
    select distinct * from `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`;


    --- PASO 1: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA
    --- OUT 1: LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INICIO` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` as SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INICIO`;

    --- PASO 1.1.1: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA Y CRUZAN POR ID CAMPAÑA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_ID` AS
    SELECT distinct a.*, c.campana_id, c.nombre_campana, coalesce(c.mr_televenta,mr.agrupador_mr) as MARCO_RETRIBUTIVO_UPD
      FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a 
      inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND UPPER(b.marca_ds) = UPPER(a.marca_ds)
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c on UPPER(TRIM(c.marca_ds)) = UPPER(TRIM(a.marca_ds))  and UPPER(TRIM(c.marca_ds))=UPPER(TRIM(b.marca_ds))
      and CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE  UPPER(TRIM(a.nombre_distribuidor)) = UPPER(TRIM(c.nombre_distribuidor)) END and c.campana_id = b.id_campana
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave
      where length(b.ID_CAMPANA)>0  or b.id_campana is not null;

    --- PASO 1.1.2: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA Y CRUZAN POR NOMBRE DE CAMPAÑA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_NOMBRE` AS
    SELECT distinct a.*, c.campana_id, c.nombre_campana, coalesce(c.mr_televenta,mr.agrupador_mr) as MARCO_RETRIBUTIVO_UPD
      FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a 
      inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND TRIM(UPPER(b.marca_ds)) = TRIM(UPPER(a.marca_ds))
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c on UPPER(TRIM(c.marca_ds)) = UPPER(TRIM(a.marca_ds))  
      and CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE  UPPER(TRIM(a.nombre_distribuidor)) = UPPER(TRIM(c.nombre_distribuidor)) END and UPPER(TRIM(c.nombre_campana)) = UPPER(TRIM(b.nombre_campana))
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave
      where length(b.ID_CAMPANA)=0  or b.id_campana is null    
      order by 1, IdFijo;


    --- PASO 1.1.3: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INCR_ID` AS
    SELECT DISTINCT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_ID`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INCR_NOMBRE` AS    
    SELECT DISTINCT *  fROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_NOMBRE` N 
    WHERE NOT EXISTS (
        SELECT 1
        FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_ID` I
        WHERE I.MARCA_DS=N.MARCA_DS AND I.IDFIJO=N.IDFIJO AND I.IDPRODUCTO=N.IDPRODUCTO
      );


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` AS
    SELECT DISTINCT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INCR_ID`
    UNION ALL
    SELECT DISTINCT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INCR_NOMBRE`; 


    --- PASO 2: ACTUALIZO TABLA MARCO_RETRIBUTIVO_TELEVENTASxCANAL
    --- PASO 2.1: CREO NUEVOS CAMPOS
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN campana_id string;
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN nombre_campana string;


    --- PASO 2.2: IDENTIFICO DUPLICADOS EN CAMPAÑA

	--- Listado de población eventos actualizables duplicados
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_UPD_DUP` AS
    select u.marca_ds, u.canal, u.subcanal,u.nombre_distribuidor, u.idfijo, u.idproducto, 
    count(u.marco_retributivo) as nmr , count(distinct u.marco_retributivo) as nmrd
    from  `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` u
    group by 1,2,3,4,5,6
    having count(u.marco_retributivo)>1;


	--- Listado de jerarquias en las que se registran eventos con marco retributivo duplicado 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_CONT_CAN_DUP` AS
	  SELECT marca_ds, canal, subcanal, nombre_distribuidor, 
	  count (idfijo) as ncl, count (distinct idfijo) as ncld,
	  count (idproducto) as npr, count (distinct idproducto) as nprd,	
	  nmr, nmrd
	  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_UPD_DUP`
	  group by 1,2,3,4,9,10
	  order by 1,2,3,4;


	--- Listado de eventos a actualizar con mr duplicado
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` AS
    select a.*
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` a
    inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_UPD_DUP` u
    on a.marca_ds=u.marca_ds    
		and a.canal = u.canal
        and a.subcanal = u.subcanal      
        and a.idfijo = u.idFijo
        and a.idProducto=u.idProducto      
        and a.nombre_distribuidor=u.nombre_distribuidor
          --and a.clave=u.clave_mr
	  order by a.marca_ds, a.idFijo, a.idProducto;
	
	/* POTENCIAL DESARROLLO 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP` AS
	select d.marca_ds, d.canal, d.subcanal, d.nombre_distribuidor, d.idfijo, d.idproducto, d.nmr, d.nmrd, d.nidc, d.nidcd, d.nnc, d.nncd, u.MARCO_RETRIBUTIVO, u.MARCO_RETRIBUTIVO_UPD
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_CONT_PR_DUP_CAMPANA` d
    inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` u
	on d.marca_ds=u.marca_ds    
		and d.canal = u.canal
        and d.subcanal = u.subcanal      
        and d.idfijo = u.idFijo
        and d.idProducto=u.idProducto      
        and d.nombre_distribuidor=u.nombre_distribuidor
    order by 1,2,3,4,5,6,7;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` AS
	select d.marca_ds, d.canal, d.subcanal, d.nombre_distribuidor, d.idfijo, d.idproducto, d.nmr, d.nmrd, d.nidc, d.nidcd, d.nnc, d.nncd, u.MARCO_RETRIBUTIVO, u.MARCO_RETRIBUTIVO_UPD
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_CONT_PR_DUP_CAMPANA` d
    inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` u
	on d.marca_ds=u.marca_ds    
		and d.canal = u.canal
        and d.subcanal = u.subcanal      
        and d.idfijo = u.idFijo
        and d.idProducto=u.idProducto      
        and d.nombre_distribuidor=u.nombre_distribuidor
    order by 1,2,3,4,5,6,7;
	*/

    --- PASO 2.3: ACTUALIZO PARA TODAS LAS MARCAS MENOS R


    --- Identifico produtos asociados a 2 o mas campañas 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` AS
    select u.*
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` u
    inner join `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    on a.marca_ds=u.marca_ds    
      and a.idfijo = u.idFijo
      and a.nombre_distribuidor=u.nombre_distribuidor
      --and a.clave=u.clave_mr
      and a.idProducto=u.idProducto
      --and UPPER(TRIM(a.marca_ds)) != 'R'
    QUALIFY count(a.nombreProducto) over(partition by a.marca_ds, a.idFijo, a.nombre_distribuidor, a.idProducto) >1;


    --- Asigno campañas a productos asociados a 1 campaña 
    UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    SET a.MARCO_RETRIBUTIVO = u.MARCO_RETRIBUTIVO_UPD,
      a.campana_id = u.campana_id,
      a.nombre_campana = u.nombre_Campana
    FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` u
    WHERE
      a.marca_ds=u.marca_ds    
      and a.idfijo = u.idFijo
      and a.nombre_distribuidor=u.nombre_distribuidor
      --and a.clave=u.clave_mr
      and a.idProducto=u.idProducto
      and UPPER(TRIM(a.marca_ds)) != 'R'
      and not exists(
          select 1
          from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` d
          where  d.marca_ds=u.marca_ds    
          and d.idfijo = u.idFijo
          and d.nombre_distribuidor=u.nombre_distribuidor
          --and a.clave=u.clave_mr
          and d.idProducto=u.idProducto
      );      


    --- Asigno campañas a productos asociados a más de 1 campaña 
      --- Se asigna a campaña más antigua
    UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    SET a.MARCO_RETRIBUTIVO = u.MARCO_RETRIBUTIVO_UPD,
      a.campana_id = u.campana_id,
      a.nombre_campana = u.nombre_Campana
    FROM (
      SELECT d.* , c.* except(marca_ds,nombre_campana), DATE_DIFF(d.Fecha_Activacion,c.FECHA_INICIO_DT, DAY)  
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` d
      inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c on c.marca_ds=d.marca_ds and c.NOMBRE_CAMPANA=d.nombre_campana and c.CLIENTE_ID=d.idFijo 
--      QUALIFY ROW_NUMBER() over(partition by c.marca_ds, c.CLIENTE_ID order by DATE_DIFF(d.Fecha_Creacion,c.FECHA_INICIO_DT, DAY) desc)=1
      QUALIFY ROW_NUMBER() over(partition by c.marca_ds, c.CLIENTE_ID,d.idProducto order by DATE_DIFF(d.Fecha_Creacion,c.FECHA_INICIO_DT, DAY) desc)=1
    ) u
    WHERE
      a.marca_ds=u.marca_ds    
      and a.idfijo = u.idFijo
      and a.nombre_distribuidor=u.nombre_distribuidor
      --and a.clave=u.clave_mr
      and a.idProducto=u.idProducto
      and UPPER(TRIM(a.marca_ds)) != 'R';


    --- PASO 2.3: ACTUALIZO PARA MARCA R
    update `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    set MARCO_RETRIBUTIVO = c.mr_televenta,
    a.campana_id =a.medio_conocimiento ,
    a.nombre_campana = c.nombre_campana
    from `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
    WHERE case when c.nombre_distribuidor <> 'X' then a.nombre_distribuidor = c.nombre_distribuidor else 1 = 1 end 
    and a.medio_conocimiento = c.campana_id 
    and a.marca_ds = 'R';



    --- PASO 3: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;


  END