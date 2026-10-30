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


    --create or replace table `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS  select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0201_MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

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
    SELECT distinct a.*, c.campana_id, c.nombre_campana, coalesce(c.mr_televenta,mr.agrupador_mr) as MARCO_RETRIBUTIVO_UPD, b.FECHA_INICIO_DT, b.FECHA_FIN_DT
      FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a 
      inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND UPPER(b.marca_ds) = UPPER(a.marca_ds)
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c on UPPER(TRIM(c.marca_ds)) = UPPER(TRIM(a.marca_ds))  and UPPER(TRIM(c.marca_ds))=UPPER(TRIM(b.marca_ds))
      and CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE  UPPER(TRIM(a.nombre_distribuidor)) = UPPER(TRIM(c.nombre_distribuidor)) END and c.campana_id = b.id_campana
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave
      where length(b.ID_CAMPANA)>0  or b.id_campana is not null;

    --- PASO 1.1.2: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA Y CRUZAN POR NOMBRE DE CAMPAÑA
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_NOMBRE` AS
    SELECT distinct a.*, c.campana_id, c.nombre_campana, coalesce(c.mr_televenta,mr.agrupador_mr) as MARCO_RETRIBUTIVO_UPD, b.FECHA_INICIO_DT, b.FECHA_FIN_DT
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



    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_PREV` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS
    SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD`;
      
      
    --- ELIMINO DUPLICADOS, Y ME QUEDO CON LA VENTA MAS PROXIMA A LA FECHA DE INICIO DE LA CAMPAÑA 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` AS  
    SELECT
        *
    FROM
         `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD`
    QUALIFY
    ROW_NUMBER() OVER (
          PARTITION BY
            marca_ds,
            idFijo,
            idProducto
          ORDER BY
          DATE_DIFF(Fecha_Creacion, FECHA_INICIO_DT, DAY) ASC
    ) = 1;





    UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    SET a.MARCO_RETRIBUTIVO = u.MARCO_RETRIBUTIVO_UPD,
      a.campana_id = u.campana_id,
      a.nombre_campana = u.nombre_Campana
    FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD`  u
    WHERE
      a.marca_ds=u.marca_ds    
      and a.idfijo = u.idFijo
      and a.nombre_distribuidor=u.nombre_distribuidor
      --and a.clave=u.clave_mr
      and a.idProducto=u.idProducto
      --and UPPER(TRIM(a.MARCO_RETRIBUTIVO)) = UPPER(TRIM(u.MARCO_RETRIBUTIVO_UPD))
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