BEGIN
    
  DECLARE vMES_DECOMISION_ID INT64;
  -- VAR LOCALES
  --DECLARE DESDE_BAJA, HASTA_BAJA INT64;SET DESDE_BAJA=20230601;SET HASTA_BAJA=20230630;
  -- FIN VAR LOCALES
  SET vMES_DECOMISION_ID= CAST(FORMAT_DATE("%Y%m",date_trunc(parse_date('%Y%m%d', CAST ( DESDE_BAJA AS string)),month)) AS INT64);



  ---- PASO 1: DECOMISIÓN DE LOS EVENTOS  DE BAJA Y DOWNGRADE DE SERVICIOS BASICOS. DECOMISIóN CON IMPORTE PONDERADO EN BASE A TIEMPO TRANSCURIDO ENTRE ACTIVACION Y BAJA
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` AS
  WITH b AS (
      SELECT b.servicio_id, b.servicio_id_original, marca_ds, fecha_baja_dt, fecha_baja_id, motivo_baja_agrup_ds, motivo_baja_ds  
      FROM  `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` b
      WHERE  b.fecha_baja_id BETWEEN DESDE_BAJA  AND HASTA_BAJA
      AND operacion_baja_ds IN ('BAJA',   'BAJA DOWNGRADE')
  ) SELECT DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap, 
  `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM fecha_baja_dt),EXTRACT(DATE FROM fecha_rfb_dt), importe) as importe,
  a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds
  FROM  b
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a ON a.servicio_id = b.servicio_id AND a.marca_ds = b.marca_ds
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` c  ON  a.marca_ds = c.marca_ds  AND a.nombre_distribuidor_alta_ds = c.nombre_distribuidor_ds  AND a.canal_alta_ds = c.canal_ds  AND  CASE  WHEN UPPER(c.subcanal_ds) <> 'X' THEN a.subcanal_ds = c.subcanal_ds  ELSE  1=1  END
  AND CASE WHEN UPPER(c.equipo_ds) <> 'X' THEN a.equipo_ds = c.equipo_ds  ELSE  1 = 1  END
  WHERE  DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0  AND 180  AND a.decomisionable = 'S';
  


  ---- PASO 2: DECOMISIÓN DE LOS SERVICIOS COMISIONADOS QUE COMPARTEN SERVICIO INICIAL CON LOS SERVICIOS QUE REGISTRAN EVENTOS DE BAJA Y DOWNGRADE. DECOMSIÓN CON IMPORTE PONDERADO EN BASE A TIEMPO TRANSCURIDO ENTRE ACTIVACION Y BAJA
  
  INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  WITH b AS (  SELECT  b.servicio_id, b.servicio_id_original, marca_ds, b.fecha_baja_dt, b.fecha_baja_id, motivo_baja_agrup_ds, motivo_baja_ds
    FROM `dw-cloud-euskaltel-prod-283409.D50_EDW.SERVICIOS` b
    WHERE  b.fecha_baja_id BETWEEN DESDE_BAJA  AND HASTA_BAJA
    AND operacion_baja_ds IN ('BAJA',   'BAJA DOWNGRADE')
  ) SELECT DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap,
`mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM fecha_baja_dt),EXTRACT(DATE FROM fecha_rfb_dt), importe) as importe,   
a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds
  FROM b
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a  ON  a.servicio_id = b.servicio_id_original  AND a.marca_ds = b.marca_ds
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca  ON  a.marca_ds = ca.marca_ds  AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds  AND a.canal_alta_ds = ca.canal_ds  AND  CASE  WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds  ELSE  1=1  END
  AND  CASE  WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds  ELSE  1 = 1  END
  LEFT JOIN (  SELECT  marca_ds, servicio_id, cliente_id  FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`) c
  ON  a.servicio_id = c.servicio_id  AND a.marca_Ds = c.marca_Ds
  WHERE  DATE_DIFF(fecha_baja_dt, fecha_rfb_dt, DAY) BETWEEN 0  AND 180  AND a.decomisionable = 'S'  AND c.cliente_id IS NULL;

  ---- PASO 3: DECOMISIÓN DE LOS PRODUCTOS QUE REGISTRAN EVENTOS DE BAJA EN EKTNET. DECOMISIONADO CON FACTOR DE PONDERACION FIJO  
  ----    Subconsulta de productos que se han dado de baja (ho se considera migrados porque el destino es nulo (swCopiaProdId es nulo)
  ----    Control de que no ha sido decomisionado en pasos previos en base a verificación de que no hay registro en tabla CLAWBACK 

  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap, 
  --a.importe * 0.75, 
  `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),EXTRACT(DATE FROM a.fecha_rfb_dt), a.importe) as importe,  
  a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds
  FROM (SELECT  b.swInstProdId, ifnull(b.swMasterInstProdId,   0) swMasterInstProdId, swFechaDesinstalacion fecha_baja_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id, b.swNombreCausaGral motivo_baja_agrup_ds, b.swCausaBaja motivo_baja_ds
        FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` b
        WHERE  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA  AND HASTA_BAJA AND b.swCopiaProdId IS NULL 
  ) b
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a  ON  a.servicio_id = b.swInstProdId  AND a.marca_ds IN ('EUSKALTEL', 'RACC', 'VIRGIN')
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca  ON  a.marca_ds = ca.marca_ds  AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds  AND a.canal_alta_ds = ca.canal_ds  AND  CASE  WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds  ELSE  1=1  END
  AND  CASE  WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds  ELSE  1 = 1  END
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c  ON  a.servicio_id = c.servicio_id  AND a.marca_ds = c.marca_ds
  WHERE  DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0  AND 180  AND c.cliente_id IS NULL  AND a.decomisionable = 'S';

  ---- PASO 4: DECOMISIÓN DE LOS PRODUCTOS COMISIONADOS QUE COMPARTEN PRODUCTO INICIAL CON LOS PRODUCTOS QUE REGISTRAN EVENTOS DE BAJA EN EL MES DE COMISIONADO EN TCNET. DECOMISIONADO CON FACTOR DE PONDERACION FIJO  
  ----    Subconsulta de productos iniciales de los productos que se han dado de baja o se han migrado (no se considera valor registado por campo swCopiaProdId
  ----    Control de que no ha sido decomisionado en pasos previos en base a verificación de que no hay registro en tabla CLAWBACK 

  INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT  DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap, 
  --a.importe * 0.75, 
  `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),EXTRACT(DATE FROM a.fecha_rfb_dt), a.importe) as importe,  
  a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds
  FROM (  SELECT  b.swInstProdId, ifnull(b.swMasterInstProdId,   0) swMasterInstProdId, swFechaDesinstalacion fecha_baja_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id, b.swNombreCausaGral motivo_baja_agrup_ds, b.swCausaBaja motivo_baja_ds
          FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_K.ci_producto` b
          WHERE  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA  AND HASTA_BAJA  AND b.swCopiaProdId IS NULL 
  ) b
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a  ON  a.servicio_id = b.swMasterInstProdId  AND a.marca_ds IN ('EUSKALTEL', 'RACC', 'VIRGIN')
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca  ON  a.marca_ds = ca.marca_ds  AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds  AND a.canal_alta_ds = ca.canal_ds  AND  CASE  WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds  ELSE  1=1  END
  AND  CASE  WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds  ELSE  1 = 1  END
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c  ON  a.servicio_id = c.servicio_id  AND a.marca_ds = c.marca_ds
  WHERE  DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0  AND 180  AND c.cliente_id IS NULL  AND a.decomisionable = 'S';


  ---- PASO 5: DECOMISIÓN DE LOS PRODUCTOS QUE REGISTRAN EVENTOS DE BAJA EN TCNET. DECOMISIONADO CON FACTOR DE PONDERACION FIJO  
  ----    Subconsulta de productos que se han dado de baja (ho se considera migrados porque el destino es nulo (swCopiaProdId es nulo)
  ----    Control de que no ha sido decomisionado en pasos previos en base a verificación de que no hay registro en tabla CLAWBACK 

  INSERT INTO `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT  DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap, 
  --a.importe * 0.75, 
  `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),EXTRACT(DATE FROM a.fecha_rfb_dt), a.importe) as importe,    
  a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds
  FROM (  SELECT  b.swInstProdId, ifnull(b.swMasterInstProdId,   0) swMasterInstProdId, swFechaDesinstalacion fecha_baja_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id, b.swNombreCausaGral motivo_baja_agrup_ds, b.swCausaBaja motivo_baja_ds
          FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` b
          WHERE  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA  AND HASTA_BAJA
          AND b.swCopiaProdId IS NULL
          AND swCausaBaja<> 'Modificación' 
  ) b
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a  ON  a.servicio_id = b.swInstProdId  AND a.marca_ds IN ('TELECABLE')
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca  ON  a.marca_ds = ca.marca_ds  AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds  AND a.canal_alta_ds = ca.canal_ds  AND  CASE  WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds  ELSE  1=1  END
  AND  CASE  WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds  ELSE  1 = 1  END
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c  ON  a.servicio_id = c.servicio_id  AND a.marca_ds = c.marca_ds
  WHERE  DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0  AND 180  AND c.cliente_id IS NULL  AND a.decomisionable = 'S';

  
  ---- PASO 4: DECOMISIÓN DE LOS PRODUCTOS COMISIONADOS QUE COMPARTEN PRODUCTO INICIAL CON LOS PRODUCTOS QUE REGISTRAN EVENTOS DE BAJA EN EL MES DE COMISIONADO EN TCNET. DECOMISIONADO CON FACTOR DE PONDERACION FIJO  
  ----    Subconsulta de productos iniciales de los productos que se han dado de baja o se han migrado (no se considera valor registado por campo swCopiaProdId
  ----    Control de que no ha sido decomisionado en pasos previos en base a verificación de que no hay registro en tabla CLAWBACK 

  INSERT INTO  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`
  SELECT  DISTINCT a.marca_ds, a.Cliente_id, a.servicio_id, a.detalle_servicio_ds, a.CONCEPTO_DS, a.FECHA_RFB_ID, a.FECHA_VENTA_NETA_ID, a.fecha_rfb_dt, a.fecha_venta_neta_dt, a.canal_alta_ds, a.subcanal_ds, a.tipo_canal_alta_ds, a.nombre_distribuidor_alta_ds, a.agente_alta_id, a.agente_creador_id, a.categoria_servicio_ds, a.cif_nif, a.segmento_ds, a.subsegmento_ds, a.marca_cartera_ds, a.Antiguedad_Cliente, a.equipo_ds, a.territorio_ds, a.clave, a.marco_retributivo_ds, a.flag_marca_cartera, a.grupo_rappel_ds, a.orden_sap, 
  --a.importe * 0.75, 
  `mm-commissions-reporting.KRT_CAPTACION.f_calcula_importe_decomision`(EXTRACT(DATE FROM b.fecha_baja_dt),EXTRACT(DATE FROM a.fecha_rfb_dt), a.importe) as importe,    
  a.decomisionable, b.fecha_baja_dt, b.fecha_baja_id, b.motivo_baja_agrup_ds, b.motivo_baja_ds
  FROM (  SELECT  b.swInstProdId, ifnull(b.swMasterInstProdId,   0) swMasterInstProdId, swFechaDesinstalacion fecha_baja_dt, `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) fecha_baja_id, b.swNombreCausaGral motivo_baja_agrup_ds, b.swCausaBaja motivo_baja_ds
  FROM  `dw-cloud-euskaltel-prod-283409.D00_SANDBOX_T.ci_producto` b
  WHERE  `dw-cloud-euskaltel-prod-283409.D80_ARQ.fnc_timestamp_to_id`(b.swFechaDesinstalacion) BETWEEN DESDE_BAJA  AND HASTA_BAJA  AND b.swCopiaProdId IS NULL ) b
  INNER JOIN `mm-commissions-reporting.KRT_CAPTACION.CAPTACION_HISTORICO` a
  ON  a.servicio_id = b.swMasterInstProdId  AND a.marca_ds IN ('TELECABLE')
  INNER JOIN  `mm-commissions-reporting.KRT_CAPTACION.PARAM_CANALES` ca
  ON  a.marca_ds = ca.marca_ds  AND a.nombre_distribuidor_alta_ds = ca.nombre_distribuidor_ds  AND a.canal_alta_ds = ca.canal_ds  AND  CASE  WHEN UPPER(ca.subcanal_ds) <> 'X' THEN a.subcanal_ds = ca.subcanal_ds  ELSE  1=1  END
  AND  CASE  WHEN UPPER(ca.equipo_ds) <> 'X' THEN a.equipo_ds = ca.equipo_ds  ELSE  1 = 1  END
  LEFT JOIN  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c  ON  a.servicio_id = c.servicio_id  AND a.marca_ds = c.marca_ds
  WHERE  DATE_DIFF(b.fecha_baja_dt, a.fecha_rfb_dt, DAY) BETWEEN 0  AND 180  AND c.cliente_id IS NULL  AND a.decomisionable = 'S';


  --- PASO 7 : CREAR TABLA DECOMISION y AÑADIR MES_DECOMISION_ID Y desc_mm

--  DECLARE DESDE_BAJA, HASTA_BAJA INT64;SET DESDE_BAJA=20230401;SET HASTA_BAJA=20230430;
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES` AS
  SELECT c.*,vMES_DECOMISION_ID as mes_decomision_id, `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_desc_mm_decomisionesv1`(c.categoria_servicio_ds, c.concepto_ds, c.fecha_baja_id, desde_baja, hasta_baja) as desc_mm
  FROM  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`c ;


  -- PASO 8: AÑADIR clase_mm
  --DECLARE DESDE_BAJA, HASTA_BAJA INT64;SET DESDE_BAJA=20230401;SET HASTA_BAJA=20230430;  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES` AS
  SELECT c.*, `mm-commissions-reporting.KRT_CAPTACION.f_tipificacion_clase_mm_decomisiones`(c.desc_mm) as clase_mm
  FROM `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES` c;


  -- PASO 9: INVERTIR VALOR DEL IMPORTE EN TABLA DECOMISIONES

  --UPDATE `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES`
  --SET importe = SAFE_NEGATE(importe)
  --where importe!=0;


  -- PASO 10: RECREAR TABLA CLAWBACK

  CREATE OR REPLACE TABLE
  `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES`;

  

  -- PASO 11: BORRAR TABLA DECOMISIONES
  DROP TABLE  `mm-commissions-reporting.KRT_CAPTACION.DECOMISIONES`;



  --- PASO 12: ELIMINAR DECOMISIONES PUBLICADAS EN MESES PREVIOS

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` AS
  SELECT d.* 
  from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK`d 
  inner join `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK_HISTORICO` dh
  on d.marca_ds=dh.marca_ds and d.cliente_id=dh.cliente_id  and d.servicio_id =dh.servicio_id and d.mes_decomision_id!=dh.mes_decomision_id;


  DELETE FROM `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` d
  WHERE EXISTS (
  SELECT 1
  FROM `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_PUBLICADAS_MESES_PREVIOS` dp
  where  d.marca_ds=dp.marca_ds and d.cliente_id=dp.cliente_id  and d.servicio_id =dp.servicio_id
  );
 


 --- PASO 14: PUBLICAR COMISIONES DUPLICADAS EN MES DE COMISION
  
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0602_DECOMISIONES_DUPLICADAS_MES_DECOMISION` AS
  with ncom as (select marca_ds, cliente_id, servicio_id, CONCEPTO_DS, count(importe) as ncom, sum(importe) as importe
  from `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` as com
  where not contains_substr(concepto_ds,'cancela')
  group by 1,2,3,4) 
  select c.*
  from ncom
  inner join `mm-commissions-reporting.KRT_CAPTACION.CLAWBACK` c
  on ncom.marca_ds=c.marca_ds and ncom.Cliente_id=c.Cliente_id and coalesce(ncom.servicio_id,0)=coalesce(c.servicio_id,0) and ncom.concepto_ds=c.concepto_ds
  where ncom.ncom>1 
  order by c.marca_ds, c.cliente_id, c.servicio_id, c.concepto_ds;




END