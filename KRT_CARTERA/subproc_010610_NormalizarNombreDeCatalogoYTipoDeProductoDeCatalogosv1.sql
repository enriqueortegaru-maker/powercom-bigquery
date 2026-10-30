BEGIN

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_010610_CATALOGOS_EVENTOS_NORMALIZAR_TIPOPRODUCTO` as 
  select distinct e.marca_ds, e.idcatalogo,e.NombreProducto as NombreProducto_Evento, c.NombreProducto  as NombreProducto_Catalogo , c.TipoProducto
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e 
  inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c on c.marca_ds=e.marca_ds and c.idProdCat=e.idcatalogo and e.TipoProducto is null;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_010610_LISTADO_EVENTOS_NORMALIZAR_TIPOPRODUCTO` as 
  select distinct e.marca_ds, e.idcatalogo,e.idFijo, e.idProducto, e.concepto_ds, e.NombreProducto as NombreProducto_Evento, c.NombreProducto  as NombreProducto_Catalogo , c.TipoProducto
  from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e 
  inner join `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c on c.marca_ds=e.marca_ds and c.idProdCat=e.idcatalogo and e.TipoProducto is null;


  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` e
  SET e.TipoProducto=c.TipoProducto,
  e.NombreProducto=c.NombreProducto
  from  `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO` c
  where  c.marca_ds=e.marca_ds and c.idProdCat=e.idcatalogo and e.TipoProducto is null;


  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_010610_EVENTOS_CARTERA` as 
  select * from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


END