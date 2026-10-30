BEGIN


    --- PASO 0: EVITO DUPLICIDADES EN PARAMETRIZACION DE CAMPAÑAS
    create or replace table `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` AS 
    select distinct * from `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS`;


    --- PASO 1: CREO TABLA DE EVENTOS DE ACTIVACIONES EN CLIENTES QUE HAN SIDO OBJETO DE CAMPAÑA
    --- OUT 1: LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INICIO` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

    --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` as SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_INICIO`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_UPD` AS
    SELECT distinct a.*, c.campana_id, c.nombre_campana, coalesce(c.mr_televenta,mr.agrupador_mr) as MARCO_RETRIBUTIVO_UPD
      FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` a 
      inner join `mm-commissions-reporting.KRT_CARTERA.CAMPANA` b on b.cliente_id=a.idfijo  AND UPPER(b.marca_ds) = UPPER(a.marca_ds)
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CAMPANAS` c on UPPER(c.marca_ds) = UPPER(a.marca_ds)  
      and CASE WHEN c.nombre_distribuidor = 'X' THEN 1=1 ELSE  a.nombre_distribuidor = c.nombre_distribuidor END and c.campana_id = b.id_campana
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` mr on  a.clave_mr = mr.clave;



    --- PASO 2: ACTUALIZO TABLA MARCO_RETRIBUTIVO_TELEVENTASxCANAL
    --- PASO 2.1: CREO NUEVOS CAMPOS
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN campana_id string;
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` ADD COLUMN nombre_campana string;


    --- PASO 2.2: IDENTIFICO DUPLICADOS EN CAMPAÑA

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
      and a.idProducto=u.idProducto;


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

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;


  END