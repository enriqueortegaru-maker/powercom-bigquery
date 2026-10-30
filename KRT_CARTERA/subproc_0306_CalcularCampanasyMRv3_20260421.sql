BEGIN

  ---======================================================================================================
  --- MODULO QUE ENRIQUECE EL EVENTOS EN CLIENTES QUE HAN SIDO OBJETO DE UNA CAMPAÑA CON DOS CAMPOS
  ---   CAMPANA_ID: IDENTIFICATIVO DE LA CAMPAÑA
  ---   NOMBRE_CAMPANA: NOMBRE DE LA CAMPAÑA
  ---
  ---   PARA ELLO EN ESTE MODULO SE CRUZAN
  ---     LOS EVENTOS REALIZADOS POR CANALES DE TELEVENTAS
  ---     LA POBLACION DE CLIENTES OBJETIVO DE LAS CAMPAÑAS DESCUBIERTAS Y VIGENTES
  ---     LA POBLACION DE CAMPAÑAS PARAMETRIZADAS, SEGMENTADAS POR MARCA, DISTRIBUIDOR, MARCO RETRIBUTIVO Y CUMPLIMIENTO DE OBJETIVOS DE CAMPAÑA (MULTIPLICADOR EN UPG y NIVEL ALCANZADO EN UPD)
  ---
  ---   SE GESTIONAN CASOS EN LOS QUE UN EVENTO PUEDE RELACIONARSE A MAS DE 1 CAMPAÑA
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

  --- PASO 1.1.1: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA Y CRUZAN POR ID CAMPAÑA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_ID` AS
  SELECT distinct a.*, c.campana_id, c.nombre_campana, coalesce(c.mr_televenta,mr.agrupador_mr) as MARCO_RETRIBUTIVO_UPD
    FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND UPPER(b.marca_ds) = UPPER(a.marca_ds)
    inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
        on UPPER(TRIM(c.marca_ds)) = UPPER(TRIM(a.marca_ds))
        and UPPER(TRIM(c.marca_ds))=UPPER(TRIM(b.marca_ds))
        and (c.nombre_distribuidor = 'X' OR UPPER(TRIM(a.nombre_distribuidor)) = UPPER(TRIM(c.nombre_distribuidor))) -- CASE optimizado
        and c.campana_id = b.id_campana
    inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave
    where b.id_campana is not null; -- WHERE optimizado

  --- PASO 1.1.2: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA Y CRUZAN POR NOMBRE DE CAMPAÑA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_NOMBRE` AS
  SELECT distinct a.*, c.campana_id, c.nombre_campana, coalesce(c.mr_televenta,mr.agrupador_mr) as MARCO_RETRIBUTIVO_UPD
    FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND TRIM(UPPER(b.marca_ds)) = TRIM(UPPER(a.marca_ds))
    inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
        on UPPER(TRIM(c.marca_ds)) = UPPER(TRIM(a.marca_ds))
        and (c.nombre_distribuidor = 'X' OR UPPER(TRIM(a.nombre_distribuidor)) = UPPER(TRIM(c.nombre_distribuidor))) -- CASE optimizado
        and UPPER(TRIM(c.nombre_campana)) = UPPER(TRIM(b.nombre_campana))
    inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave
    where b.id_campana is null; -- WHERE optimizado (y ORDER BY eliminado)


  --- PASO 1.1.3: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA
  --- (OPTIMIZADO: Consolida 5 tablas (_INCR_ID, _INCR_NOMBRE, _UPD) en una sola sentencia)
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_ID`
  UNION ALL
  SELECT N.*
  FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_NOMBRE` N
  WHERE NOT EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD_CMP_ID` I
      WHERE I.MARCA_DS=N.MARCA_DS AND I.IDFIJO=N.IDFIJO AND I.IDPRODUCTO=N.IDPRODUCTO
    );


  --- PASO 2: ACTUALIZO TABLA MARCO_RETRIBUTIVO_TELEVENTASxCANAL
  --- PASO 2.1: CREO NUEVOS CAMPOS (de forma idempotente)
  ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN IF NOT EXISTS campana_id string;
  ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN IF NOT EXISTS nombre_campana string;


  --- PASO 2.2: IDENTIFICO DUPLICADOS EN CAMPAÑA
  --- (OPTIMIZADO: Este bloque entero parecía ser código muerto para logging
  --- ya que `...LIST_PR_DUP_CAMPANA` se redefine en el paso 2.3. Se elimina.)


  --- PASO 2.3: ACTUALIZO PARA TODAS LAS MARCAS MENOS R

  --- Identifico produtos asociados a 2 o mas campañas (Definición utilizada en el MERGE)
  --- (OPTIMIZADO: Se elimina el JOIN innecesario a la tabla 'a')
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` AS
  select u.*
  from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` u
  QUALIFY count(1) over(partition by u.marca_ds, u.idFijo, u.nombre_distribuidor, u.idProducto) > 1;


  --- (OPTIMIZADO: Se combinan los dos UPDATEs siguientes en un solo MERGE)
  MERGE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
  USING (
    --- 1. Campañas únicas (no están en la tabla de duplicados)
    SELECT u.*
    FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` u
    WHERE NOT EXISTS (
      select 1
      from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` d
      where d.marca_ds=u.marca_ds
        and d.idfijo = u.idFijo
        and d.nombre_distribuidor=u.nombre_distribuidor
        and d.idProducto=u.idProducto
    )
    UNION ALL
    --- 2. Campañas duplicadas 

    /*
    --- (resueltas para elegir la "más antigua" según la lógica original)
    SELECT d.*
    FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` d
    inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c
      on c.marca_ds=d.marca_ds
      and c.NOMBRE_CAMPANA=d.nombre_campana
      and c.CLIENTE_ID=d.idFijo
    QUALIFY ROW_NUMBER() over(partition by c.marca_ds, c.CLIENTE_ID, d.idProducto order by DATE_DIFF(d.Fecha_Creacion,c.FECHA_INICIO_DT, DAY) desc) = 1
      */
    
    --- (resueltas para elegir la "más cercana" posterior al inicio de la campaña)
    SELECT
      d.*
    FROM
      `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_LIST_PR_DUP_CAMPANA` d
    INNER JOIN
      `mm-commissions-reporting.KRT_CARTERA.CAMPANA` c
      ON c.marca_ds = d.marca_ds
      AND c.NOMBRE_CAMPANA = d.nombre_campana
      AND c.CLIENTE_ID = d.idFijo
      AND c.FECHA_INICIO_DT < d.Fecha_Creacion -- Condición clave 1: La campaña debe ser ANTERIOR a la venta
    QUALIFY
      ROW_NUMBER() OVER (
        PARTITION BY
          -- Particionamos por los campos que identifican una venta única
          d.marca_ds, d.idFijo, d.idProducto, d.Fecha_Creacion, d.nombre_campana
        ORDER BY
          -- Condición clave 2: Ordenamos por la diferencia de días ASCENDENTE
          -- para encontrar la fecha de inicio MÁS PRÓXIMA (mínima diferencia)
          DATE_DIFF(d.Fecha_Creacion, c.FECHA_INICIO_DT, DAY) ASC
      ) = 1

  ) u
  ON
    a.marca_ds=u.marca_ds
    and a.idfijo = u.idFijo
    and a.nombre_distribuidor=u.nombre_distribuidor
    and a.idProducto=u.idProducto
  WHEN MATCHED AND UPPER(TRIM(a.marca_ds)) != 'R' THEN
    UPDATE SET
      a.MARCO_RETRIBUTIVO = u.MARCO_RETRIBUTIVO_UPD,
      a.campana_id = u.campana_id,
      a.nombre_campana = u.nombre_Campana;


  --- PASO 2.3: ACTUALIZO PARA MARCA R (Se mantiene como un UPDATE separado, ya que la lógica es totalmente diferente)
  update `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
  set MARCO_RETRIBUTIVO = c.mr_televenta,
  a.campana_id = a.medio_conocimiento ,
  a.nombre_campana = c.nombre_campana
  from `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
  WHERE (c.nombre_distribuidor = 'X' OR a.nombre_distribuidor = c.nombre_distribuidor) -- CASE optimizado
  and a.medio_conocimiento = c.campana_id
  and a.marca_ds = 'R';


  --- PASO 3: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

END