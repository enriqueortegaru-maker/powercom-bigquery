BEGIN

    ---- OUT_RESUMEN
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.OUT_RESUMEN` AS

    SELECT marca_ds,nombre_distribuidor, canal, subcanal, agente, idFijo, antiguedad, dni_cif, marca_cartera, NULL Campana_id, '' NombreCampana, Segmento, MARCO_RETRIBUTIVO, SUM(importe) importe, nivel, SUM(importe_nivel) importe_nivel, SUM(bono_comercial) bono_comercial, SUM(bono_calidad) bono_calidad, SUM(ifnull(importe_nivel, 0) + ifnull(bono_comercial, 0) + ifnull(bono_calidad, 0)) total
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_VENTAS_TIENDAS`
    GROUP BY marca_ds, nombre_distribuidor, canal, subcanal, agente, idFijo, antiguedad, dni_cif, marca_cartera, Segmento, MARCO_RETRIBUTIVO, nivel
    UNION ALL
    SELECT marca_ds, nombre_distribuidor, canal, subcanal, agente, idFijo, antiguedad, dni_cif, marca_cartera, Campana_id, nombre_campana, Segmento, MARCO_RETRIBUTIVO, SUM(importe) importe, 0, SUM(importe_nivel) importe_nivel, 0 bono_comercial, 0 bono_calidad, SUM(ifnull(importe_nivel, 0)) total
    FROM `mm-commissions-reporting.KRT_CARTERA.BONOS_TELEVENTAS`
    GROUP BY marca_ds, nombre_distribuidor, canal, subcanal, agente, idFijo, antiguedad, dni_cif, marca_cartera, Segmento, MARCO_RETRIBUTIVO, Campana_id, nombre_campana;


    ---- OUT_DETALLE

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.OUT_DETALLE` AS
    --SELECT * except(TipoProducto,mes_comision_id,desc_mm,clase_mm)
    SELECT marca_ds, IdCatalogo, NombreProducto, nombre_distribuidor, Canal, subcanal, agente, IdFijo, Antiguedad, DNI_CIF, Marca_Cartera, Fecha_Activacion, Fecha_Creacion, Segmento, Subsegmento, idCatalogoOrigen, IdProductoOrigen, NombreProductoOrigen, TipoMovimiento, IdProducto, Contrato, UsuarioCreador, agente_creador_id, concepto_ds, concepto_origen_ds, medio_conocimiento, clave_mr, MARCO_RETRIBUTIVO, tvt_ups_virgin, televenta, importe, nivel, importe_nivel, bono_comercial, bono_calidad, bono_extras, total, campana_id, nombre_campana, decomisionable, decom_bono_extra, orden_sap, clase_mm,desc_mm,ClaseProducto,TipoProducto
    FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES`
    order by Fecha_Activacion desc;



    ---- OUT_DECOMISIONES
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES` AS
    SELECT * 
    /*except(TipoProducto,mes_comision_id,mes_decomision_id,FEchaDesinstalacion,desc_mm,clase_mm,desc_mm_com,clase_mm_com)*/
    , FORMAT_DATE("%Y%m%d",FEchaDesinstalacion) as Fecha_baja_id
    FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
    order by FechaDesinstalacion desc;


    ---- OUT_DECOMISIONES_DETALLE
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES_DETALLE` AS
    SELECT * , FORMAT_DATE("%Y%m%d",FEchaDesinstalacion) as Fecha_baja_id
    FROM `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES`
    order by FechaDesinstalacion desc;


    ---- OUT_REVISAR

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.OUT_REVISAR` AS

    WITH nc as( with pob as (SELECT * from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e   where not exists ( select 1  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c where c.marca_ds=e.marca_ds and c.canal=e.canal and c.subcanal=e.subcanal) ) select pob.* from pob  where not exists (   select 1   from `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` cr   where pob.marca_ds=cr.marca_ds   and pob.canal=cr.canal_ds   and pob.subcanal=cr.subcanal_ds )
    ) select * 
    from nc 
    where not exists ( select 1  from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES` c where c.marca_ds=nc.marca_ds and c.cliente_id=nc.idfijo and (c.servicio_id-nc.idproducto) <10
 );



    ---- OUT_REVISAR_COMPLETO
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.OUT_REVISAR_COMPLETO` AS 
    SELECT
      *, `mm-commissions-reporting.KRT_CARTERA.f_obtenerMarcoDesdeCanalizacionDeDistribuidorMasAgente`(marca_ds, canal, subcanal,nombre_distribuidor,agente) as MR 
    FROM
      `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
    WHERE
      NOT EXISTS (
      SELECT
        1
      FROM
        `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
      WHERE
        c.marca_ds=e.marca_ds
        AND c.idFijo=e.idFijo
        AND c.idProducto=e.idProducto); 





    -- #####PARCHE
    -- ##### Invertir signo de decomisiones

    --UPDATE `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES` SET importe = SAFE_NEGATE(importe) where importe!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES` SET importe_nivel = SAFE_NEGATE(importe_nivel) where importe_nivel!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES` SET total = SAFE_NEGATE(total) where total!=0;
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES` SET bono_comercial = SAFE_NEGATE(bono_comercial) where bono_comercial!=0;    
    --UPDATE `mm-commissions-reporting.KRT_CARTERA.OUT_DECOMISIONES` SET bono_calidad = SAFE_NEGATE(bono_calidad) where bono_calidad!=0;    

    -- #####FIN PARCHE


    ---- OUT_CARGA_EKTNET
    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.OUT_CARGA_EKTNET` AS
    select marca_ds MARCA,   idFijo IDCLIENTE,   idproducto IDPRODUCTO,   TIPOPRODUCTO NEGOCIO,   case when CONTAINS_SUBSTR(segmento,'RESIDENCIAL') then concat(c.swName , ' '  , c.swSegundoApellido, ' ', c.swApellido ) else c.swName end CLIENTE,   segmento SEGMENTO,   dni_cif  NIF ,   nombreproducto CONCEPTOINF, -- Pendiente resolver caso rappel 
    case when contains_substr(tipomovimiento,'alta') then concat('Alta Producto ', marca_ds)   
         when contains_substr(tipomovimiento,'cambio') then concat('Migración Producto ', marca_ds)   
         when contains_substr(tipomovimiento,'rappel') then concat('Alta Rappel ', marca_ds)   
         when (contains_substr(tipomovimiento,'extra') or contains_substr(tipomovimiento,'extra')) then concat(tipomovimiento,' ', marca_ds)   
     end DESCRIPCIONINF,   
     swAni IDENTIFICATIVO, fecha_activacion FECHAORIGEN,0 PLAZODED1, 0 PLAZODED2, 0 PLAZODED3, 0 PORDEDUD1, 0 PORDEDUD2, 0 PORDEDUD3,sum(total) IMPORTEREALTOTAL,
     sum(total) IMPORTEREALUNITARIO, swProdReleaseId PRODRELEASE, ifnull(p.swChnlPartnerId, 0) IDCANAL, p.swMarcaCartera  MARCACAPTCART, idproductoOrigen IDPRODUCTOORIGEN,   
     case when contains_substr(tipomovimiento,'rappel') then 'R'    
         when contains_substr(tipomovimiento,'extra') or contains_substr(tipomovimiento,'postventa') then 'E'    
         when (contains_substr(tipomovimiento,'alta') or contains_substr(tipomovimiento,'cambio') ) then 'A'  
     end TIPOCOMISION   
     from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` a    
     left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on a.idproducto = p.swInstProdId   
     left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c on a.IdFijo = c.swCustomerId   where marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')   
     --and contains_substr(tipomovimiento,'rappel')   
     group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,24   
     having sum(coalesce(importe,0))!=0
     UNION ALL
     select marca_ds MARCA,   idFijo IDCLIENTE,   idproducto IDPRODUCTO,   TIPOPRODUCTO NEGOCIO,  
      case when CONTAINS_SUBSTR(segmento,'RESIDENCIAL') then concat(c.swName , ' '  , c.swSegundoApellido, ' ', c.swApellido ) else c.swName end CLIENTE,   
      segmento SEGMENTO,   dni_cif  NIF ,   nombreproducto CONCEPTOINF, -- Pendiente resolver caso rappel   
     case when contains_substr(tipomovimiento,'alta') then concat('Alta Producto ', marca_ds)   
          when contains_substr(tipomovimiento,'cambio') then concat('Migración Producto ', marca_ds)   
          when contains_substr(tipomovimiento,'rappel') then concat('Alta Rappel ', marca_ds)   
          when (contains_substr(tipomovimiento,'extra') or contains_substr(tipomovimiento,'extra')) then concat(tipomovimiento,' ', marca_ds)   
      end DESCRIPCIONINF,   
      swAni IDENTIFICATIVO, fecha_activacion FECHAORIGEN, 0 PLAZODED1, 0 PLAZODED2, 0 PLAZODED3, 0 PORDEDUD1, 0 PORDEDUD2, 0 PORDEDUD3, sum(total) IMPORTEREALTOTAL, 
      sum(total) IMPORTEREALUNITARIO, swProdReleaseId PRODRELEASE, ifnull(p.swChnlPartnerId, 0) IDCANAL, p.swMarcaCartera  MARCACAPTCART, idproductoOrigen IDPRODUCTOORIGEN,   
      'D' AS TIPOCOMISION   
      from `mm-commissions-reporting.KRT_CARTERA.DECOMISIONES` a    
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` p on a.idproducto = p.swInstProdId   
      left join `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_cliente` c on a.IdFijo = c.swCustomerId   
      where marca_ds in ('EUSKALTEL', 'RACC', 'VIRGIN')   --and contains_substr(tipomovimiento,'rappel')   
      group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,24   
      having sum(coalesce(importe,0))!=0;


  END