BEGIN


    --- PASO 0: EVITO DUPLICIDADES EN PARAMETRIZACION DE CAMPAÑAS
    create or replace table `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` AS 
    select distinct * from `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`;


    --- PASO 1: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` AS
    SELECT a.*
      FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a 
      inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND UPPER(b.marca_ds) = UPPER(a.marca_ds)
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c on UPPER(c.marca_ds) = UPPER(a.marca_ds)  
      and CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE  a.nombre_distribuidor = c.nombre_distribuidor END and c.campana_id = b.id_campana
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave;



    --- PASO 2: ACTUALIZO TABLA MARCO_RETRIBUTIVO_TELEVENTASxCANAL
    --- PASO 2.1: CREO NUEVOS CAMPOS
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN campana_id string;
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN nombre_campana string;

    --- PASO 2.2: ACTUALIZO PARA TODAS LAS MARCAS MENOS R
    UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    SET MARCO_RETRIBUTIVO = coalesce(mr_televenta,mr.agrupador_mr),
      a.campana_id = b.ID_CAMPANA,
      a.nombre_campana = b.NOMBRE_CAMPANA
    FROM
      `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b,
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c,
      `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr
    WHERE
      a.idfijo = b.cliente_id
      AND UPPER(a.marca_ds) = UPPER(b.marca_ds)
      AND UPPER(a.marca_ds) = c.marca_ds
      AND b.id_campana = c.campana_id
      AND CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE a.nombre_distribuidor = c.nombre_distribuidor END
      AND a.clave_mr = mr.clave;


    --- PASO 2.3: ACTUALIZO PARA MARCA R
    update `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a
    set MARCO_RETRIBUTIVO = c.mr_televenta,
    a.campana_id = a.medio_conocimiento,
    a.nombre_campana = c.nombre_campana
    from `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c
    WHERE case when c.nombre_distribuidor <> 'X' then a.nombre_distribuidor = c.nombre_distribuidor else 1 = 1 end 
    and a.medio_conocimiento = c.campana_id 
    and a.marca_ds = 'R';



    --- PASO 3: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;


  END