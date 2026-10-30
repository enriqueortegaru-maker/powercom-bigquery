BEGIN


DECLARE fecha date;
DECLARE hasta_1m, vmes_comision_id_1m int64;
SET fecha="2023-01-31";
SET hasta_1m=20230131;
SET vmes_Comision_id_1m=CAST(hasta_1m/100 AS INT64);

----- PASO 1: LEO PARAMETRIZACION 


-- CREO TABLAS BASE PARA DESARROLLO
CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1` as 
select * from `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where hasta=20230228 and version=6  and ((fecha_calc_dt='2023-03-02'and marca_ds='R') OR (fecha_calc_dt='2023-03-07'and marca_ds!='R') );
CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` as 
select * from `mm-commissions-reporting.KRT_CAPTACION.AGG_COMISIONES` where fecha_calc_dt='2023-03-16' and hasta=20230228 and version=6; 



--- CONSULTA QUE REGISTRA 883 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID  y CONCEPTO_DS NO COMISIONADO PREVIAMENTE
SELECT * 
from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c2
WHERE NOT EXISTS(
  SELECT 1 
  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1`c1
  where c1.marca_ds=c2.marca_ds
  and c1.cliente_id=c2.cliente_id
  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
  and c1.servicio_id=c2.servicio_id
  and TRIM(c1.concepto_ds)=TRIM(c2.concepto_ds)
) 
and NOT CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal')
and NOT CONTAINS_SUBSTR(c2.clase_mm,'Z - Ajustes') 
and c2.servicio_id is not null; 

-------------
--- EL RESULTADO DE ESTA CONSULTA SE SUBDIVIDE EN DOS GRUPOS
---   GRUPO 1: 708 REGISTROS DE SERVICIOS CON UN ID NO COMISIONADO PREVIAMENTE -> REGISTRO ALTA TIPIFICADO CLASE A R -Recalculo periodo anterior y desc_mm heredado pero modificando la primera letra del prefijo por X
---   GRUPO 2: 175 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE
---         GRUPO 2.1: 34 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR NULO -> REGISTRO A TABLA DE ANALISIS REGISTRANDO GRUPO
---         GRUPO 2.2: 44 REGISTROS DE SERVICIOS DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO DE BAJA YN POSTERIOR ALTA
---         GRUPO 2.3: 97 REGISTROS DE SERVICIOS NO DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO A TABLA REGITRANDO GRUPO


---   GRUPO 1: 708 REGISTROS DE SERVICIOS CON UN ID NO COMISIONADO PREVIAMENTE -> REGISTRO ALTA TIPIFICADO CLASE A R -Recalculo periodo anterior y desc_mm heredado pero modificando la primera letra del prefijo por X
CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_SID` as 
SELECT * 
from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c2
WHERE NOT EXISTS(
  SELECT 1 
  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1`c1
  where c1.marca_ds=c2.marca_ds
  and c1.cliente_id=c2.cliente_id
  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
  and c1.servicio_id=c2.servicio_id
  --and c1.concepto_ds=c2.concepto_ds
)
and NOT CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal')
and NOT CONTAINS_SUBSTR(c2.clase_mm,'Z - Ajustes') 
and c2.servicio_id is not null; 



CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` as 
SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_SID`;
UPDATE  `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M` SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R -') WHERE 1=1;


---   GRUPO 2: 175 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE

CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` as 
SELECT null as idtipo, c2.* 
from `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c2
WHERE NOT EXISTS(
  SELECT 1 
  FROM  `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1`c1
  where c1.marca_ds=c2.marca_ds
  and c1.cliente_id=c2.cliente_id
  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
  and c1.servicio_id=c2.servicio_id
  and c1.concepto_ds=c2.concepto_ds
)
and NOT EXISTS(
  SELECT 1 
  FROM   `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_SID` c1
  where c1.marca_ds=c2.marca_ds
  and c1.cliente_id=c2.cliente_id
  and c1.categoria_servicio_ds=c2.categoria_servicio_ds
  and c1.servicio_id=c2.servicio_id
  --and c1.concepto_ds=c2.concepto_ds
)
and NOT CONTAINS_SUBSTR(c2.clase_mm,'F - Gestion de canal')
and NOT CONTAINS_SUBSTR(c2.clase_mm,'Z - Ajustes') 
and c2.servicio_id is not null
--and c2.cliente_id=3518206
order by c2.marca_Ds, c2.cliente_id, c2.servicio_id, c2.concepto_ds; 

---         GRUPO 2.1: 34 REGISTROS DE SERVICIOS CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR NULO -> REGISTRO A TABLA DE ANALISIS REGISTRANDO GRUPO

UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
SET idtipo=21
WHERE EXISTS (
  select 1 
  from (
    Select dci.*
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dci
    left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1` c1 
    on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
    left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c2
    on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
    where c1.concepto_ds is null 
    and c2.concepto_ds is null
    order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
  ) dcf
  where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
);

---         GRUPO 2.2: 44 REGISTROS DE SERVICIOS DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO DE BAJA YN POSTERIOR ALTA

UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
SET idtipo=22
WHERE EXISTS (
  select 1 
  from (
    Select dci.*
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dci
    left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1` c1 
    on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
    left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c2
    on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
    where c1.categoria_servicio_ds="BANDA ANCHA"
    order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
  ) dcf
  where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
);


-- REGISTROS A DAR DE BAJA

CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0802_OPERACIONES_BAJA_1M` as 
 select c1.*
 from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
 inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c1
 on c1.marca_ds=dc.marca_ds and c1.cliente_id=dc.cliente_id and c1.categoria_servicio_ds=dc.categoria_servicio_ds and c1.servicio_id=dc.servicio_id and c1.clase_mm=dc.clase_mm and c1.desc_mm=dc.desc_mm
 where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=22;

UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0802_OPERACIONES_BAJA_1M`
SET importe=SAFE_NEGATE(importe), clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Baja por migracion de')  where 1=1;

INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`
select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0802_OPERACIONES_BAJA_1M`;


-- REGISTROS A DAR DE ALTA
CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0802_OPERACIONES_ALTA_1M` as 
 select c2.* 
 from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
 inner join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c2
 on c2.marca_ds=dc.marca_ds and c2.cliente_id=dc.cliente_id and c2.categoria_servicio_ds=dc.categoria_servicio_ds and c2.servicio_id=dc.servicio_id and c2.clase_mm=dc.clase_mm and c2.desc_mm=dc.desc_mm
 where dc.categoria_servicio_ds="BANDA ANCHA" and dc.idtipo=22;

UPDATE  `mm-commissions-reporting.KRT_CAPTACION.LOG_0802_OPERACIONES_ALTA_1M`
SET clase_mm='R - Recalculo periodo anterior', desc_mm=REPLACE(desc_mm,left(desc_mm,3),'R - Alta por migracion de')  where 1=1;

INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.RECALCULO_COMISIONES_1M`
select * from  `mm-commissions-reporting.KRT_CAPTACION.LOG_0802_OPERACIONES_ALTA_1M`;


---         GRUPO 2.3: 97 REGISTROS DE SERVICIOS NO DE BANDA ANCHA CON UNA COMBINACION DE ID y CONCEPTO_DS NO COMISIONADO PREVIAMENTE Y CON CONCEPTO_DS PREVIO Y POSTERIOR INFORMADO -> REGISTRO A TABLA REGITRANDO GRUPO

UPDATE `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dc
SET idtipo=23
WHERE EXISTS (
  select 1 
  from (
    Select dci.*
    from `mm-commissions-reporting.KRT_CAPTACION.AUDIT_COM_1M_LIST_COM_DIST_CONCEPTO` dci
    left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES1` c1 
    on c1.marca_ds=dci.marca_ds and c1.cliente_id=dci.cliente_id and c1.categoria_servicio_ds=dci.categoria_servicio_ds and c1.servicio_id=dci.servicio_id and c1.clase_mm=dci.clase_mm and c1.desc_mm=dci.desc_mm
    left join `mm-commissions-reporting.KRT_CAPTACION.COMISIONES_DES2` c2
    on c2.marca_ds=c1.marca_ds and c2.cliente_id=c1.cliente_id and c2.categoria_servicio_ds=c1.categoria_servicio_ds and c2.servicio_id=c1.servicio_id and c2.clase_mm=c1.clase_mm and c2.desc_mm=c1.desc_mm
    where c1.categoria_servicio_ds!="BANDA ANCHA"
    order by  dci.marca_ds, dci.cliente_id, dci.servicio_id
  ) dcf
  where dcf.marca_ds=dc.marca_ds and dcf.cliente_id=dc.cliente_id and dcf.categoria_servicio_ds=dc.categoria_servicio_ds and dcf.servicio_id=dc.servicio_id
);


END