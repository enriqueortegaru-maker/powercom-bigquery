BEGIN
    -- Hoja COMISIONES
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_COMISIONES` AS
    SELECT
      * except(mes_comision_id,desc_mm,clase_mm, PLAYS_RFB)
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.COMISIONES`;


    -- Hoja REVISAR
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR` AS

    SELECT base.*, mm.nombre_distribuidor_ds,mm.tipo_canal_ds,mm.canal_ds
    FROM (
      SELECT
        *
      FROM
        `mm-commissions-reporting.KRT_CAPTACION.MARCO_RETRIBUTIVOxCANAL`
      WHERE
        subcanal_ds = 'DESCONOCIDO'
        OR marco_retributivo_ds IS NULL) base
    LEFT JOIN
      --`dw-cloud-euskaltel-prod-283409.D90_FINANCIERO.AG_PARAM_COMISIONAMIENTO_CAPTACION_MM_CANALES` mm
      `mm-commissions-reporting.KRT_CAPTACION_MM.PARAM_CANALES` mm
    ON
      base.marca_ds = mm.marca_ds
      AND base.nombre_distribuidor_alta_ds = mm.nombre_distribuidor_ds
      AND base.canal_alta_ds = mm.canal_ds
      AND base.subcanal_ds = mm.subcanal_ds
    WHERE
      mm.marco_retributivo_ds IS NULL;


    -- Hoja DECOMISIONES
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_DECOMISIONES` AS
    SELECT
      * except(mes_decomision_id,desc_mm,clase_mm)
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`;

      -- #####PARCHE
      -- ##### Invertir signo de decomisiones

      ---UPDATE `mm-commissions-reporting.KRT_CAPTACION.OUT_DECOMISIONES`
      ---SET importe = SAFE_NEGATE(importe)
      ---where importe!=0;

      -- #####FIN PARCHE

      -- #####PARCHE
      -- ##### Borrar las decomisiones defechas posteriores a inicio de mes, analizar si trasladar a tabla CLAWBACK

      DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.OUT_DECOMISIONES`
      WHERE FECHA_RFB_ID >= DESDE;
      
      -- #####FIN PARCHE



    -- Hoja REVISAR_PARAM_VALOR

    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR_PARAM_VALOR` AS
      with noc as (
        select * 
        from `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR` cp
        where not exists (
          select 1 
          from `mm-commissions-reporting.KRT_CARTERA.PARAM_CANALES` cr
          where cp.marca_ds=cr.marca_ds
          and cp.canal_alta_ds=cr.canal
          and cp.subcanal_ds=cr.subcanal
        ) and marca_ds !='R'
      ) select noc.* 
      from noc
      where not exists (
        select 1
        from  `mm-commissions-reporting.KRT_CARTERA.OUT_DETALLE` l
        where l.marca_ds=noc.marca_ds
        and (l.IdProducto=noc.servicio_id or l.IdProductoOrigen=noc.servicio_id)
        and l.IdFijo=noc.cliente_id
      )
      order by marca_ds, cliente_id;



--    CREATE OR REPLACE TABLE
--      `mm-commissions-reporting.KRT_CAPTACION.OUT_REVISAR_PARAM_VALOR` AS
--    SELECT
--      DISTINCT marca_ds,
--      ba,
--      post,
--      tv,
--      fija
--    FROM
--      `mm-commissions-reporting.KRT_CAPTACION.VENTASxCLIENTE`
--    WHERE
--      plays IS NULL
--      OR pack = ''
--      OR valor = '';


    -- Hoja RAPPEL_OBJETIVOS_ALCANZADOS
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_RAPPEL_OBJETIVOS_ALCANZADOS` AS
    SELECT *
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_PRESENCIAL`;


    -- Hoja RAPPEL_VOLUMEN_ALCANZADO
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_RAPPEL_VOLUMEN_ALCANZADO` AS
    SELECT *
    FROM
      `mm-commissions-reporting.KRT_CAPTACION.RAPPEL_NO_PRESENCIAL`;



    -- Hoja OUT_CARGA_EKTNET
    CREATE OR REPLACE TABLE
      `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_COM` AS

    select marca_ds MARCA,
    cliente_id IDCLIENTE,
    servicio_id IDPRODUCTO,
    categoria_servicio_ds NEGOCIO,
    case when segmento_ds = 'RESIDENCIAL' then concat(c.swName , ' '  , c.swSegundoApellido, ' ', c.swApellido ) else c.swName end CLIENTE,
    segmento_ds SEGMENTO,
    cif_nif  NIF ,
    detalle_servicio_ds CONCEPTOINF,
    case when concepto_ds like 'Rappel%' then 'Alta Rappel' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then concepto_ds else concat('Alta Producto ', marca_ds) end DESCRIPCIONINF,
    swAni IDENTIFICATIVO,
    fecha_venta_neta_dt FECHAORIGEN,
    0 PLAZODED1,
    0 PLAZODED2,
    0 PLAZODED3,
    0 PORDEDUD1,
    0 PORDEDUD2,
    0 PORDEDUD3,
    sum(importe) IMPORTEREALTOTAL,
    sum(importe) IMPORTEREALUNITARIO,
    swProdReleaseId PRODRELEASE,
    ifnull(p.swChnlPartnerId, 0) IDCANAL,
    p.swMarcaCartera  MARCACAPTCART,
    null IDPRODUCTOORIGEN,
    case when concepto_ds like 'Rappel%' then 'R' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then 'E' else 'A' end TIPOCOMISION
    from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS_Y_RETRASOS` a         
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on a.servicio_id = p.swInstProdId
    left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c on a.cliente_id = c.swCustomerId
    where marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,24;


    CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_DECOM` AS
    select marca_ds MARCA,
    cliente_id IDCLIENTE,
    servicio_id IDPRODUCTO,
    categoria_servicio_ds NEGOCIO,
    concat(c.swName , ' '  , c.swSegundoApellido, ' ', c.swApellido )  CLIENTE,
    segmento_ds SEGMENTO,
    cif_nif  NIF ,
    detalle_servicio_ds CONCEPTOINF,
    case when concepto_ds like 'Rappel%' then 'Baja Rappel' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then concepto_ds else concat('Baja Producto ', marca_ds) end DESCRIPCIONINF,
    swAni IDENTIFICATIVO,
    fecha_venta_neta_dt FECHAORIGEN,
    0 PLAZODED1,
    0 PLAZODED2,
    0 PLAZODED3,
    0 PORDEDUD1,
    0 PORDEDUD2,
    0 PORDEDUD3,
    sum(importe) IMPORTEREALTOTAL,
    sum(importe) IMPORTEREALUNITARIO,
    swProdReleaseId PRODRELEASE,
    ifnull(p.swChnlPartnerId, 0) IDCANAL,
    p.swMarcaCartera  MARCACAPTCART,
    null IDPRODUCTOORIGEN,
    case when concepto_ds like 'Rappel%' then 'DR' when concepto_ds like 'Extra%' or concepto_ds like 'Postventa%' then 'DE' else 'DA' end TIPOCOMISION
    from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` a
    left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on a.servicio_id = p.swInstProdId
    left join  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c on a.cliente_id = c.swCustomerId
    where marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,24;


    CREATE OR REPLACE TABLE
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET` AS
    SELECT * 
    FROM 
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_COM`
    UNION ALL 
    SELECT * 
    FROM 
    `mm-commissions-reporting.KRT_CAPTACION.OUT_CARGA_EKTNET_DECOM`;

  END