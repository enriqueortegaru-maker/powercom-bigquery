BEGIN


  --select * from `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES_DUPLICADAS`

  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_040210_COMISIONES_DUPLICADAS`  AS 
	with d as (
	  with dup as (
	    select *
	    from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` 
	    --where idProducto =60110535468
	    where nombreProducto!="Rappel"
	    qualify ROW_NUMBER() over(partition by marca_ds,idFijo, idProducto,concepto_ds order by idProducto, total desc)=2 
	  ) select h.*, ROW_NUMBER() over(partition by h.marca_ds,h.idfijo, h.idProducto,h.concepto_ds order by  h.idFijo, h.idProducto, h.total desc) as ind
	  from dup d
	  left join `mm-commissions-reporting.KRT_CARTERA.COMISIONES` h on h.marca_ds=d.marca_ds and h.idFijo=d.idFijo and h.idPRoducto=d.idProducto and h.concepto_ds=d.concepto_ds and h.nombreProducto!="Rappel"
	), e as (
	  select e.*, ROW_NUMBER() over(partition by marca_ds, IdFijo, IdProducto, concepto_ds order by IdFijo, IdProducto, total desc) as ie  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` e
	)
	select distinct d.*, max(e.ie)  over(partition by d.marca_ds, d.idFijo, d.idProducto,d.concepto_ds order by d.idProducto, D.total desc) as ie
	from d 
	left join e on coalesce(e.IdFijo,666)=coalesce(d.IdFijo,666) and coalesce(e.IdProducto,666)=coalesce(d.IdProducto,666) and coalesce(e.idProductoOrigen,666)=coalesce(d.idProductoOrigen,666) 
	and  e.concepto_ds=d.concepto_ds
	order by d.marca_ds, d.idProducto, d.ind;



  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_040210_COMISIONES_DUPLICADAS_BORRRAR`  AS 
  select distinct  c.*
  from `mm-commissions-reporting.KRT_CARTERA.LOG_0402_COMISIONES` c
  where exists(
    select 1 
    from `mm-commissions-reporting.KRT_CARTERA.LOG_040210_COMISIONES_DUPLICADAS` d
    where d.ind>1 
    and c.marca_ds=d.marca_ds
    and coalesce(c.IdFijo,666)=coalesce(d.IdFijo,666) and coalesce(c.IdProducto,666)=coalesce(d.IdProducto,666) and coalesce(c.idProductoOrigen,666)=coalesce(d.idProductoOrigen,666) 
    and  c.concepto_ds=d.concepto_ds  and  coalesce(c.concepto_origen_ds,"INDEF")=coalesce(c.concepto_origen_ds,"INDEF")
    --and coalesce(c.idCatalogoOrigen,"INDEF")=d.catalogoOrigen
    and c.total=d.total
   ) order by c.marca_ds, c.idFijo, c.idProducto; 


  CREATE OR REPLACE TABLE  `mm-commissions-reporting.KRT_CARTERA.LOG_040210_COMISIONES_CRUCE_DUPLICADAS_BORRRAR`  AS 
  select c.*, case when d.idPRoducto is not null then 1 else 0 end as bEliminar
  from  `mm-commissions-reporting.KRT_CARTERA.LOG_040210_COMISIONES_DUPLICADAS` c
  left join  `mm-commissions-reporting.KRT_CARTERA.LOG_040210_COMISIONES_DUPLICADAS_BORRRAR` d
  on c.marca_ds=d.marca_ds
  and coalesce(c.IdFijo,666)=coalesce(d.IdFijo,666) and coalesce(c.IdProducto,666)=coalesce(d.IdProducto,666) and coalesce(c.idProductoOrigen,666)=coalesce(d.idProductoOrigen,666) 
  and  c.concepto_ds=d.concepto_ds  and  coalesce(c.concepto_origen_ds,"INDEF")=coalesce(c.concepto_origen_ds,"INDEF")
  --and coalesce(c.idCatalogoOrigen,"INDEF")=d.catalogoOrigen
  and c.total=d.total
 	order by c.marca_ds, c.idProducto, c.ind;



  DELETE FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c 
	--Select * FROM `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c 
  where exists (
    select 1 from `mm-commissions-reporting.KRT_CARTERA.LOG_040210_COMISIONES_CRUCE_DUPLICADAS_BORRRAR`  d 
    where d.bEliminar=1	and c.marca_ds=d.marca_ds 
    and coalesce(c.IdFijo,666)=coalesce(d.IdFijo,666) and coalesce(c.IdProducto,666)=coalesce(d.IdProducto,666) --and coalesce(c.idProductoOrigen,666)=coalesce(d.idProductoOrigen,666) 
    --and  c.concepto_ds=d.concepto_ds  and  coalesce(c.concepto_origen_ds,"INDEF")=coalesce(c.concepto_origen_ds,"INDEF")
    --and c.total=d.total
  );





END