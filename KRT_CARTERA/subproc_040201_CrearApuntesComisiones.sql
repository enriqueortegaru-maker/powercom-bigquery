BEGIN
 
    --- 20251112 --- Cambio de versión de funcion desc_mm y clase_mm
    ---     Filas 61 y 67

 --DECLARE DESDE, HASTA INT64;SET DESDE=desde;SET HASTA=hasta;
 
  DECLARE MES_COMISION INT64;
    --DECLARE DESDE, HASTA INT64;SET DESDE=20231101;SET HASTA=20231130; 
	SET MES_COMISION=CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d',CAST(DESDE AS string)),month)) AS INT64);


  --  SEGMENTAR EN PASOS
  --    10: CREAR TABLA COMISIONES (INTEGRAR APUNTES + ELIMINAR DUPLICADOS + TIPIFICAR COMISIONES + ELIMINAR COMISIONES PUBLICADAS EN MESES PREVIOS)
  --    20: INTEGRAR EXTRAS (INTGRAR EXTRAS + REDONDEAR A CUARTO DIGITO)
  --    30: MARCAR COMISION POR TRASPASO COMO NO DECOMISIONABLES
  --    40: APLICAR MULTIPLICADOR A COMSION TOTAL (NUEVO PASO)



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

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040201_COMISIONES_DUPLICADAS` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS    
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
    --SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv1`(TipoMovimiento, concepto_ds, NombreProducto, TipoProducto) as desc_mm,
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_comisionesv2`(TipoMovimiento, concepto_ds, NombreProducto, TipoProducto) as desc_mm,
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS`;


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` AS
    --SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisiones`(desc_mm) as clase_mm,
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_comisionesv1`(desc_mm) as clase_mm,
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;



	--- PASO 5: ELIMINAR COMISIONES PUBLICADAS EN MESES PREVIOS
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040201_COMISIONES_PUBLICADAS_MESES_PREVIOS` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS     
    SELECT d.* 
    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES`d 
    inner join `mm-commissions-reporting.KRT_CARTERA.HISTORICO_COMISIONES_CARTERA_FACTURADO` dh
    --`mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO` dh
    on d.marca_ds=dh.marca_ds and d.IdFijo=dh.IdFijo  and d.IdProducto =dh.IdProducto and d.mes_comision_id!=dh.mes_comision_id 
    --and d.canal!="B2B"
    where not (d.marca_ds='R' and d.TipoProducto='MOVILES POSTPAGO' and contains_substr(d.tipoMovimiento,"cambio servicios móviles" ));



    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` d
    WHERE EXISTS ( SELECT 1 FROM `mm-commissions-reporting.KRT_CARTERA.LOG_040201_COMISIONES_PUBLICADAS_MESES_PREVIOS` dp where d.marca_ds=dp.marca_ds and d.IdFijo=dp.IdFijo  and d.IdProducto =dp.IdProducto 
    );


	--- PASO 6: CREO LOG
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_040201_COMISIONES` 
    OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)) AS    
    SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`;

END