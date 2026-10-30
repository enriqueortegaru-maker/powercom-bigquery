BEGIN

  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` as select * from `mm-commissions-reporting.KRT_CARTERA.LOG_010610_EVENTOS_CARTERA`;

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` as 
	select * except(tipoProductoOrigen,subtipoProductoOrigen,subtipoProducto) from `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` ;

    -- PASO 2:Añado campo tipo producto
     
  --CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS SELECT * FROM  `mm-commissions-reporting.KRT_CARTERA.LOG_0105_EVENTOS_CARTERA`;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` AS 
  SELECT distinct * ,
  `mm-commissions-reporting.KRT_CARTERA.f_crea_TipoProducto`(TipoMovimiento, concepto_ds, NombreProducto, tipoProducto)  as ClaseProducto
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_010620_EVENTOS_CARTERA_CON_CLASE`AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`AS
  SELECT * except(TipoProducto,ClaseProducto), ClaseProducto as TipoProducto
  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_010620_EVENTOS_CARTERA`AS
  SELECT *  FROM `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA`;



END