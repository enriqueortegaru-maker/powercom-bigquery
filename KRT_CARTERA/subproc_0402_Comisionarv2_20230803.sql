BEGIN

    DECLARE MES_COMISION INT64;
    SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);

    --- PASO 1 : INTEGRO COMISIONES DE BONOS 
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.BONOS` AS
    SELECT
      * REPLACE(CAST(nivel AS string) AS nivel),
      ifnull(importe_nivel,
        0) + ifnull(bono_comercial,
        0) + ifnull(bono_calidad,
        0) total,
      NULL campana_id,
      '' nombre_campana,
      'S' decomisionable
    FROM
      `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS`
    UNION ALL
    SELECT
      * EXCEPT(campana_id,
        nombre_campana,
        importe,
        importe_nivel,
        nivel_tvt_ups_virgin),
      importe,
      NULL,
      importe_nivel,
      0,
      0,
      ifnull(importe_nivel,
        0) total,
      campana_id,
      nombre_campana,
      'S' decomisionable
    FROM
      `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`;


    --- PASO 2 : ENRIQUEZCO REGISTROS CON DATO DE MES DE COMISION
    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.BONOS`
    ADD COLUMN mes_comision_id INT64;
    UPDATE `mm-commissions-reporting.KRT_CARTERA.BONOS` SET mes_comision_id = MES_COMISION WHERE mes_comision_id is null;

    --- PASO 3 : CLASIFICO BONOS Y CREO TABLA COMISIONES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisiones`(TipoMovimiento, concepto_ds, TipoProducto) as desc_mm,
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(desc_mm) as clase_mm,
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;


    --- PASO 3.1 : ELIMINO DUPLICADOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES_DUPLICADAS` AS
    with p as (
      select marca_ds, idFijo, contrato,nombreproducto, idproducto,Coalesce(idProductoOrigen,0) as idProductoOrigen ,concepto_ds, tipomovimiento, count(Fecha_Activacion) as ncom 
      from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`  
      group by 1,2,3,4,5,6,7,8 having count(Fecha_Activacion)>1 
      order by 9 desc
    ) SELECT distinct c.*,p.ncom
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
    inner join p 
    on p.marca_ds=c.marca_ds and p.idFijo=c.IdFijo and p.contrato=c.Contrato and p.nombreproducto=c.NombreProducto and p.idproducto=c.idproducto  and coalesce(p.idproductoOrigen,0)= coalesce(c.idproductoOrigen,0) and p.concepto_ds=c.concepto_ds and p.tipomovimiento =c.TipoMovimiento
order by p.ncom desc;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT distinct *,
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;



  --- PASO 3: ELIMINAR COMISIONES PUBLICADAS EN MESES PREVIOS
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS` AS
    SELECT d.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`d 
    inner join `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO` dh
    on d.marca_ds=dh.marca_ds and d.IdFijo=dh.IdFijo  and d.IdProducto =dh.IdProducto and d.mes_comision_id!=dh.mes_comision_id;


    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` d
    WHERE EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS` dp
      where d.marca_ds=dp.marca_ds and d.IdFijo=dp.IdFijo  and d.IdProducto =dp.IdProducto 
    );
 


  --- PASO 4:ACTUALIZO HISTORICO DE COMISIONES DUPLICADAS EN MESES PREVIOS
    --PASO TRASLADADO A MODULO SUBPROC_0701_ACTUALIZARHISTORICODECARTERAV1
    --DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    --WHERE mes_comision_id=MES_COMISION;

    --INSERT  INTO `mm-commissions-reporting.KRT_CARTERA.COMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    --SELECT * except(agente_creador_id)FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS`;




  --- PASO 5: CREO LOG DE COMISIONES A SALIDA DE ESTE PASO
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES` AS
    SELECT c.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c ;



END