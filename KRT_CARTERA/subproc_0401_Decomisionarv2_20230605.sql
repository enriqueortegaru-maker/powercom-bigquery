BEGIN

    
    DECLARE
      DESDE_DT,
      HASTA_DT,
      DESDE_6M_DT date;
    DECLARE MES_DECOMISION INT64;
    --- LOCAL
    --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;    

    SET
      HASTA_DT = parse_date ('%Y%m%d',
        CAST ( HASTA AS string) );
    SET
      DESDE_DT = parse_date ('%Y%m%d',
        CAST ( DESDE AS string) );
    SET
      DESDE_6M_DT=DATE_SUB(DESDE_DT, INTERVAL 6 MONTH);
    SET MES_DECOMISION= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE AS string)),month)) AS INT64);


  --- PASO 1: CREAR LA TABLA LOG_DECOMISIONES
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS
    SELECT
      DISTINCT a.* REPLACE(
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(importe) AS importe,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(importe_nivel) AS importe_nivel,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(bono_comercial) AS bono_comercial,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(bono_calidad) AS bono_calidad,
        CASE
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 1 AND 60 THEN 1
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 61
        AND 120 THEN 0.75
          WHEN DATE_DIFF(CAST(COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion) AS date), Fecha_Activacion, DAY) BETWEEN 121 AND 180 THEN 0.5
      END
        * SAFE_NEGATE(total) AS total ),
      EXTRACT(DATE FROM COALESCE(cpt.swFechaDesinstalacion, cpk.swFechaDesinstalacion)) as FechaDesinstalacion,        
      COALESCE(cpt.swCausaBaja, cpk.swCausaBaja) CausaBaja,
      COALESCE(cpt.swNombreCausaGral, cpk.swNombreCausaGral) CausaBajaGeneral
    FROM(
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        FROM `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
    ) a
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` cpt
    ON
      a.IdProducto = cpt.swInstProdId
      AND a.idCatalogo = CAST(cpt.swProdReleaseId AS string)
    LEFT JOIN
      `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` cpk
    ON
      a.idProducto = cpk.swInstProdId
      AND a.idCatalogo = CAST(cpk.swProdReleaseId AS string)
    WHERE
      ((CAST(cpt.swFechaDesinstalacion AS date) BETWEEN DESDE_DT
          AND HASTA_DT
          AND cpt.swCopiaProdId IS NULL)
        OR (CAST(cpk.swFechaDesinstalacion AS date) BETWEEN DESDE_DT
          AND HASTA_DT
          AND cpk.swCopiaProdId IS NULL))
      AND Fecha_Activacion >= DESDE_6M_DT
      AND Fecha_Activacion < DESDE_DT
      AND NOT (CONTAINS_SUBSTR(a.TipoMovimiento,"Alta Equipamiento móvil") and NOT(CONTAINS_SUBSTR(COALESCE(cpt.swCausaBaja, cpk.swCausaBaja),"Desistimiento")));


    --- PASO 2: NEGATIVIZAR IMPORTE

    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET importe = SAFE_NEGATE(importe) where importe!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET importe_nivel = SAFE_NEGATE(importe_nivel) where importe_nivel!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET total = SAFE_NEGATE(total) where total!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET bono_comercial = SAFE_NEGATE(bono_comercial) where bono_comercial!=0;            
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` SET bono_calidad = SAFE_NEGATE(bono_calidad) where bono_calidad!=0;            

    --- PASO 2 : TIPIFICAR DECOMISIONES
--    ALTER TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` ADD COLUMN mes_decomision_id INT64,  ADD COLUMN clase_mm_com STRING, ADD COLUMN desc_mm_com STRING;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC` AS
    SELECT d.*, 
    MES_DECOMISION as mes_decomision_id,
    `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(desc_mm_com) as desc_mm
    from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` AS
    SELECT f.*, 
    `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC` f;

    DROP TABLE `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_DESC`;


  --- PASO 3: INTEGRAR LAS DECOMISIONES DE R


    --- PASO 3.1: INTEGRAR DECOMISIONES DE PRODUCTOS DADOS DE BAJA
    --DECLARE DESDE, HASTA INT64;SET DESDE=20230501;SET HASTA=20230531;    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` AS
    select p.row_id,p.IDPRODUCTO, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.CODIGO, p.CODIGOPADRE, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.IDEXTERNO,p.IDINTERNO,p.IDCUENTA, c.tipoproducto, c.concepto, c.tipo_movimiento
    from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` as p    
    inner join  `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c on c.idprodcat=p.CODIGO
    where contains_substr(p.accion,'baja')
    and CAST(FORMAT_DATE("%Y%m%d",p.CREATED) as INTEGER) BETWEEN DESDE AND HASTA;

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` AS
    with p as (
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        from `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
        where Fecha_Activacion >= DESDE_6M_DT
    )
    select p.* except(importe,nivel,importe_nivel, bono_comercial,bono_calidad,total, campana_id, nombre_campana,decomisionable,mes_comision_id, desc_mm_com,clase_mm_com),
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe) as importe,
      p.nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe_nivel) as importe_nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_comercial) as bono_comercial,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_calidad) as bono_calidad,   
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total) as total,
    p.campana_id, p.nombre_campana,p.decomisionable,p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,CAST(b.CREATED AS DATE) as FechaDesinstalacion, 
    CAST(NULL AS STRING) as CausaBaja, CAST(NULL AS STRING) as CausaBajaGeneral,
    mes_decomision as mes_decomision_id, 
    `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(p.desc_mm_com) as desc_mm
    --DATE_DIFF(CAST(b.CREATED AS date), p.Fecha_Activacion, DAY) as ndays 
    from p
    inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` as b
    on CAST(p.idproducto AS STRING )= CAST(b.IDINTERNO AS STRING ) or  CAST(p.idproducto AS STRING )= CAST(b.IDEXTERNO AS STRING);


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK` AS
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK`;


    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
    select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R_CLAWBACK`;

    --- PASO 3.2: INTEGRAR DECOMISIONES DE PROMOCIONES LIGADAS A PRODUCTOS QUE SE DAN DE BAJA

      --- PASO 3.2.1: IDENTIFICO PROMOCIONES QUE SON HIJAS DE PRODUCTOS DADOS DE BAJA

      --- Bajas de promociones en mes de comision
      --SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where contains_substr(tipoentidad,'promocion');
      --- Bajas de productos en mes de comision
      --SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where contains_substr(tipoentidad,'producto');      

      --- Bajas de productos que arrastran bajas de promociones 
      --with bprod as (SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where contains_substr(tipoentidad,'producto')),
      --     bprom as (SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where contains_substr(tipoentidad,'promocion'))
      --select bprod.* 
      --from bprod
      --inner join bprom on bprom.idtreesiebel=bprod.idtreesiebel;


      --- Promociones vinculadas a productos dados de baja
      CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R` AS
      with bprod as (SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_R` where contains_substr(tipoentidad,'producto'))
      select p.row_id,p.idproducto, p.IDPRODUCTOPADRE,p.CREATED, p.ACCION, p.TIPOENTIDAD, p.codigo, p.codigopadre, p.IDPROCESO, p.IDTREESIEBEL, p.IDTREEVOA,p.tiposervicio, p.idinterno, p.idexterno,p.IDCUENTA
      from  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_R.ci_sb_cx_producto` as p
      inner join bprod on bprod.idproducto= p.IDPRODUCTO
      where contains_substr(p.TipoEntidad,"PROMOCION")
      order by p.idproducto, p.idinterno;



      --- PASO 3.2.2: DESCUBRO HISTORICO DE COMISIONES SOBRE PRODUCTOS QUE TIENEN COMO HIJOS PROMOCIONES


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` AS
    with p as (
        select * except(desc_mm, clase_mm), desc_mm as desc_mm_com, clase_mm as clase_mm_com
        from `mm-commissions-reporting.KRT_CARTERA.CARTERA_HISTORICO`
        where Fecha_Activacion >= DESDE_6M_DT
    )
    select p.* except(importe,nivel,importe_nivel, bono_comercial,bono_calidad,total, campana_id, nombre_campana,decomisionable,mes_comision_id, desc_mm_com,clase_mm_com),
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe) as importe,
      p.nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.importe_nivel) as importe_nivel,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_comercial) as bono_comercial,
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.bono_calidad) as bono_calidad,   
    `mm-commissions-reporting.KRT_CARTERA.f_calcula_importe_decomision`(CAST(b.CREATED AS DATE), CAST(p.Fecha_Activacion AS DATE), p.total) as total,
    p.campana_id, p.nombre_campana,p.decomisionable,p.mes_comision_id,p.desc_mm_com,p.clase_mm_com,CAST(b.CREATED AS DATE) as FechaDesinstalacion, 
    CAST(NULL AS STRING) as CausaBaja, CAST(NULL AS STRING) as CausaBajaGeneral,
    mes_decomision as mes_decomision_id, 
    `mm-commissions-reporting.KRT_CARTERA.f_tipificacion_desc_mm_decomisiones`(p.desc_mm_com) as desc_mm
    --DATE_DIFF(CAST(b.CREATED AS date), p.Fecha_Activacion, DAY) as ndays 
    from p
    inner join `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R` as b
    on CAST(p.idproducto AS STRING )= CAST(b.IDINTERNO AS STRING ) or  CAST(p.idproducto AS STRING )= CAST(b.IDEXTERNO AS STRING);


    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` AS
    SELECT *,`mm-commissions-reporting.KRT_CARTERA.f_tipificacion_clase_mm_decomisiones`(desc_mm) as clase_mm 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK`;


    INSERT INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
    select * from  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_BAJAS_PROMOCIONES_R_CLAWBACK` b
    where not exists(
      select 1 
      from  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d
      where d.marca_ds=b.marca_ds and d.idfijo=b.idfijo and d.IdProducto=b.idproducto
    );



  --- PASO 4: ELIMINAR DECOMISIONES PUBLICADAS EN MESES PREVIOS
    
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` AS
    SELECT d.* 
    from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`d 
    inner join `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_HISTORICO` dh
    on d.marca_ds=dh.marca_ds and d.IdFijo=dh.IdFijo  and d.IdProducto =dh.IdProducto and d.mes_decomision_id!=dh.mes_decomision_id;


    DELETE FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` d
    WHERE EXISTS (
      SELECT 1
      FROM `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` dp
      where d.marca_ds=dp.marca_ds and d.IdFijo=dp.IdFijo  and d.IdProducto =dp.IdProducto 
    );
 



  --- PASO 4:ACTUALIZO HISTORICO DE DECOMISIONES DUPLICADAS EN MESES PREVIOS
    DELETE FROM  `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    WHERE mes_decomision_id=MES_DECOMISION;

    INSERT  INTO `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES_PUBLICADAS_MESES_PREVIOS_HISTORICO`
    SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0401_DECOMISIONES_PUBLICADAS_MESES_PREVIOS`;


END