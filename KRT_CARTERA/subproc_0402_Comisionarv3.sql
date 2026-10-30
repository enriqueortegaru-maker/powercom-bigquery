BEGIN


    DECLARE MES_COMISION INT64;
    --DECLARE DESDE, HASTA INT64;SET DESDE=20230901;SET HASTA=20230930; 
    SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);


    --- PASO 1 : INTEGRO COMISIONES DE BONOS 
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.BONOS` AS
    SELECT      * REPLACE(CAST(nivel AS string) AS nivel), ifnull(importe_nivel, 0) + ifnull(bono_comercial, 0) + ifnull(bono_calidad, 0) total, NULL campana_id, '' nombre_campana, 'S' decomisionable, MES_COMISION as mes_comision_id
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS`
    UNION ALL
    SELECT * EXCEPT(campana_id,   nombre_campana,   importe,   importe_nivel,   nivel_tvt_ups_virgin), importe, NULL, importe_nivel, 0, 0, ifnull(importe_nivel,   0) total, campana_id, nombre_campana, 'S' decomisionable, MES_COMISION as mes_comision_id
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`;


    --- PASO 2 : CREO TABLA COMISIONES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.BONOS`;



    --- PASO 3 : ELIMINO DUPLICADOS

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_DUPLICADAS` AS
    with p as ( select marca_ds, idFijo, contrato,nombreproducto, idproducto,Coalesce(idProductoOrigen,0) as idProductoOrigen ,concepto_ds, tipomovimiento, count(Fecha_Activacion) as ncom  
        from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`   
        group by 1,2,3,4,5,6,7,8 
        having count(Fecha_Activacion)>1  order by 9 desc
    ) SELECT distinct c.*,p.ncom
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
    inner join p 
    on p.marca_ds=c.marca_ds and p.idFijo=c.IdFijo and p.contrato=c.Contrato and p.nombreproducto=c.NombreProducto and p.idproducto=c.idproducto  
    and coalesce(p.idproductoOrigen,0)= coalesce(c.idproductoOrigen,0) and p.concepto_ds=c.concepto_ds and p.tipomovimiento =c.TipoMovimiento
    order by p.ncom desc;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT distinct *,
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;


    --- PASO 4 : TIPIFICO COMISIONES

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisiones`(TipoMovimiento, concepto_ds, TipoProducto) as desc_mm,
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(desc_mm) as clase_mm,
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;



  --- PASO 5: ELIMINAR COMISIONES PUBLICADAS EN MESES PREVIOS
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS` AS
    SELECT d.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`d 
    inner join `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO` dh
    on d.marca_ds=dh.marca_ds and d.IdFijo=dh.IdFijo  and d.IdProducto =dh.IdProducto and d.mes_comision_id!=dh.mes_comision_id
    where not (d.marca_ds='R' and d.TipoProducto='MOVILES POSTPAGO' and contains_substr(d.tipoMovimiento,"cambio servicios móviles" ));



    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` d
    WHERE EXISTS ( SELECT 1 FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PUBLICADAS_MESES_PREVIOS` dp where d.marca_ds=dp.marca_ds and d.IdFijo=dp.IdFijo  and d.IdProducto =dp.IdProducto 
    );



    --- PASO 6 : CALCULAR EXTRAS 

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PREVIO_EXTRAS` AS
    SELECT distinct c.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c ;

    /*
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS SELECT * from `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_PREVIO_EXTRAS` c ;
    DECLARE MES_COMISION INT64;
    DECLARE DESDE, HASTA INT64;SET DESDE=20230801;SET HASTA=20230831; 
    SET MES_COMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);
    */

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    with imp_extracom as (
      select c.marca_ds, c.nombre_distribuidor, c.canal, c.subcanal, p.importe, p.poruni, p.decomisionable, count(distinct c.idproducto) as np, count(c.idproducto) as npnd, 
      CASE WHEN TRIM(UPPER(p.poruni))='N' THEN ROUND(p.importe/ count(distinct c.idproducto),6) 
           WHEN TRIM(UPPER(p.poruni))='Y' THEN p.importe
      END as imp_extracom
      from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`  c
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat on cat.marca_ds=c.marca_ds and cat.IdProdCat=c.IdCatalogo
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS` p on p.marca_ds=c.marca_ds and c.nombre_distribuidor=p.nombre_distribuidor
      and case when TRIM(UPPER(p.canal))!='X' THEN  TRIM(UPPER(p.canal))= TRIM(UPPER(c.canal)) ELSE 1=1 END
      and case when TRIM(UPPER(p.subcanal))!='X' THEN  TRIM(UPPER(p.subcanal))= TRIM(UPPER(c.subcanal)) ELSE 1=1 END
      and case when TRIM(UPPER(p.tipoproducto))!='X' THEN  TRIM(UPPER(p.tipoproducto))= TRIM(UPPER(cat.tipoproducto)) ELSE 1=1 END
      and case when TRIM(UPPER(p.claseproducto))!='X' THEN  TRIM(UPPER(p.claseproducto))= TRIM(UPPER(cat.tipo_movimiento)) ELSE 1=1 END
      --and case when TRIM(UPPER(p.claseproducto))!='X' THEN  TRIM(UPPER(p.claseproducto))= TRIM(UPPER(cat.tipoproducto)) ELSE 1=1 END
      --and case when TRIM(UPPER(p.tipoproducto))!='X' THEN  TRIM(UPPER(p.tipoproducto))= TRIM(UPPER(cat.tipo_movimiento)) ELSE 1=1 END
      where c.total!=0 and not contains_substr(c.TipoMovimiento,'rappel')
      group by 1,2,3,4,5,6,7
    ), pob_extra_com as (
      select distinct c.marca_ds, c.canal, c.subcanal, c.nombre_distribuidor, p.claseproducto,p.tipoproducto,  c.idFijo, c.idCatalogo, c.idproducto 
      from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`  c
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` cat on cat.marca_ds=c.marca_ds and cat.IdProdCat=c.IdCatalogo
      inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_EXTRAS` p on p.marca_ds=c.marca_ds and c.nombre_distribuidor=p.nombre_distribuidor
      and case when TRIM(UPPER(p.canal))!='X' THEN  TRIM(UPPER(p.canal))= TRIM(UPPER(c.canal)) ELSE 1=1 END
      and case when TRIM(UPPER(p.subcanal))!='X' THEN  TRIM(UPPER(p.subcanal))= TRIM(UPPER(c.subcanal)) ELSE 1=1 END
      and case when TRIM(UPPER(p.tipoproducto))!='X' THEN  TRIM(UPPER(p.tipoproducto))= TRIM(UPPER(cat.tipoproducto)) ELSE 1=1 END
      and case when TRIM(UPPER(p.claseproducto))!='X' THEN  TRIM(UPPER(p.claseproducto))= TRIM(UPPER(cat.tipo_movimiento)) ELSE 1=1 END
      --and case when TRIM(UPPER(p.claseproducto))!='X' THEN  TRIM(UPPER(p.claseproducto))= TRIM(UPPER(cat.tipoproducto)) ELSE 1=1 END
      --and case when TRIM(UPPER(p.tipoproducto))!='X' THEN  TRIM(UPPER(p.tipoproducto))= TRIM(UPPER(cat.tipo_movimiento)) ELSE 1=1 END
      where c.total!=0  and not contains_substr(c.TipoMovimiento,'rappel')
    ) select distinct c.* except(total, campana_id,nombre_campana, decomisionable) , coalesce(i.imp_extracom,0) as bono_extras, ROUND(coalesce(c.total,0)+coalesce(i.imp_extracom,0),6) as total,
    c.campana_id,c.nombre_campana, c.decomisionable,coalesce(i.decomisionable,'N') as decom_bono_extra
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`  c
    left join pob_extra_com p on p.marca_ds=c.marca_ds and p.nombre_distribuidor=c.nombre_distribuidor and p.canal=c.canal and p.subcanal=c.subcanal and p.idFijo=c.idFijo and p.idCatalogo=c.idCatalogo and p.idproducto=c.idproducto 
    left join imp_extracom i on i.marca_ds=p.marca_ds and i.nombre_distribuidor=p.nombre_distribuidor and  i.canal=c.canal and i.subcanal=c.subcanal and not contains_substr(c.TipoMovimiento,'rappel')
    --where i.imp_extracom is not null  
    --and i.decomisionable='N'
    --and p.idproducto=138391058
    --where p.idproducto=139370078    
    order by 1,4,5,6,7;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    SELECT c.*  except(mes_comision_id, campana_id, nombre_campana, decomisionable, decom_bono_extra, desc_mm, clase_mm), campana_id, nombre_campana, decomisionable,decom_bono_extra, mes_comision_id, desc_mm, clase_mm
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c ;

  
  --- PASO 7: CREO LOG DE COMISIONES A SALIDA DE ESTE PASO

  
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES` AS
    SELECT c.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c ;


    



END