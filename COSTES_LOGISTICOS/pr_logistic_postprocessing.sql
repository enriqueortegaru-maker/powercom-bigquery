BEGIN

--CALL `mm-commissions-reporting.COSTES_LOGISTICOS.pr_logistic_postprocessing`();

DECLARE id_mes_actual INT64;
SET id_mes_actual = CAST(CONCAT(EXTRACT(YEAR FROM CURRENT_DATE()), EXTRACT(MONTH FROM CURRENT_DATE())) AS INT64);

  --------------------
  -- DESISTIMIENTOS --
  --------------------

 --Actualizacion Modificar estado final
  UPDATE `mm-commissions-reporting.TEMP.desistimiento_estado_final` dest
  SET dest.accion = (SELECT MAX(pop.estado_final) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pop WHERE pop.tipo_pedido = 'Desistimiento' AND pop.accion = 'Modificar estado final' AND pop.id_orden = CAST(dest.orderCrmId AS INT64))
--  WHERE SAFE_CAST(dest.orderCrmId AS INT64) IN (SELECT pp.id_orden FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Desistimiento' AND pp.accion IN ('Modificar estado final','Modificar estado y fecha final'));
  WHERE dest.orderCrmId IN (SELECT CAST(pp.id_orden AS STRING) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Desistimiento' AND pp.accion IN ('Modificar estado final','Modificar estado y fecha final'));

 --Actualizacion Modificar fecha estado final
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET lo.fecha_estado_final = (SELECT MAX(pp.fecha_estado_final) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE tipo_pedido = 'Desistimiento' AND accion = 'Modificar fecha estado final' AND CAST(pp.id_orden AS STRING) = lo.id_orden)
--  WHERE lo.id_orden IN (SELECT pp.id_orden FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Desistimiento' AND pp.accion IN ('Modificar fecha estado final','Modificar estado y fecha final'))
  WHERE lo.id_orden IN (SELECT CAST(pp.id_orden AS STRING) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Desistimiento' AND pp.accion IN ('Modificar fecha estado final','Modificar estado y fecha final'))
    AND lo.tipo_pedido = 'Desistimiento';

 --Actualizacion Modificar numero de serie
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` li
  SET li.numero_serie = (SELECT MAX(pp.numero_serie_nuevo) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE li.tipo_pedido = 'Desistimiento' AND accion = 'Modificar numero de serie' AND CAST(pp.id_orden AS STRING) = li.id_orden)
--  WHERE li.id_orden IN (SELECT pp.id_orden FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Desistimiento' AND pp.accion = 'Modificar numero de serie')
  WHERE li.id_orden IN (SELECT CAST(pp.id_orden AS STRING) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Desistimiento' AND pp.accion = 'Modificar numero de serie')
--    AND li.numero_serie IN (SELECT pp.numero_serie_original FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Desistimiento' AND pp.accion = 'Modificar numero de serie') --No es necesario actualmente
    AND li.tipo_pedido = 'Desistimiento';

  --------------
  -- ENTREGAS --
  --------------

 --Actualizacion Modificar estado final
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET lo.estado_final = (SELECT MAX(pop.estado_final) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pop WHERE pop.tipo_pedido = 'Entrega' AND pop.accion = 'Modificar estado final' AND CAST(pop.id_orden AS STRING) = lo.id_orden)
--  WHERE lo.id_orden IN (SELECT pp.id_orden FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Entrega' AND pp.accion IN ('Modificar estado final','Modificar estado y fecha final')) AND lo.tipo_pedido = 'Entrega';
  WHERE lo.id_orden IN (SELECT CAST(pp.id_orden AS STRING) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Entrega' AND pp.accion IN ('Modificar estado final','Modificar estado y fecha final')) AND lo.tipo_pedido = 'Entrega';

 --Actualizacion Modificar fecha estado final
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET lo.fecha_estado_final = (SELECT MAX(pp.fecha_estado_final) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE tipo_pedido = 'Entrega' AND accion = 'Modificar fecha estado final' AND CAST(pp.id_orden AS STRING) = lo.id_orden)
--  WHERE lo.id_orden IN (SELECT pp.id_orden FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Entrega' AND pp.accion IN ('Modificar fecha estado final','Modificar estado y fecha final'))
  WHERE lo.id_orden IN (SELECT CAST(pp.id_orden AS STRING) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Entrega' AND pp.accion IN ('Modificar fecha estado final','Modificar estado y fecha final'))
    AND lo.tipo_pedido = 'Entrega';

 --Actualizacion Modificar numero de serie
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` li
  SET li.numero_serie = (SELECT MAX(pp.numero_serie_nuevo) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE li.tipo_pedido = 'Entrega' AND accion = 'Modificar numero de serie' AND CAST(pp.id_orden AS STRING) = li.id_orden)
--  WHERE li.id_orden IN (SELECT pp.id_orden FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Entrega' AND pp.accion = 'Modificar numero de serie')
  WHERE li.id_orden IN (SELECT CAST(pp.id_orden AS STRING) FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Entrega' AND pp.accion = 'Modificar numero de serie')
    AND li.numero_serie IN (SELECT pp.numero_serie_original FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_postprocessing` pp WHERE pp.tipo_pedido = 'Entrega' AND pp.accion = 'Modificar numero de serie')
    AND li.tipo_pedido = 'Entrega';

    --Actualización de la tabla de ordenes para marcar las MULTISIM --mar/25
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` aaa
  SET estado_final = 'MULTISIM', estado_reexpedicion = 'MULTISIM'
  FROM (
      --Buscamos todos los pedidos padre de SIM que tienen varios id_orden con una única expedición 
      --así podemos marcar los pedidos adicionales, de modo que no se facturen.
    SELECT bbb.marca, bbb.tipo_pedido, bbb.numero_expedicion, MIN(id_orden) AS pedido_a_facturar
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` bbb
    WHERE bbb.numero_expedicion IN (
        SELECT numero_expedicion
        FROM (
          SELECT numero_expedicion, COUNT(distinct(aaa.id_orden)) AS cuenta_id_orden
          FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` aaa
          WHERE dispositivo = 'SIM'
            AND pedido_padre IS NOT NULL
          GROUP BY ALL 
          HAVING  cuenta_id_orden > 1
        )
      )
      AND dispositivo = 'SIM'
    GROUP BY ALL 
  ) ccc
  WHERE aaa.marca = ccc.marca
    AND aaa.tipo_pedido = ccc.tipo_pedido
    AND aaa.numero_expedicion = ccc.numero_expedicion
    AND aaa.id_orden <> ccc.pedido_a_facturar;

    --Actualización de la tabla de ordenes de logistica para marcar las MULTISIM --mar/25
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` aaa
  SET estado_final = 'MULTISIM', estado_reexpedicion = 'MULTISIM'
  FROM (
      --Buscamos todos los pedidos padre de SIM que tienen varios id_orden con una única expedición 
      --así podemos marcar los pedidos adicionales, de modo que no se facturen.
    SELECT bbb.marca, bbb.tipo_pedido, bbb.numero_expedicion, MIN(id_orden) AS pedido_a_facturar
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` bbb
    WHERE bbb.numero_expedicion IN (
        SELECT numero_expedicion
        FROM (
          SELECT numero_expedicion, COUNT(distinct(aaa.id_orden)) AS cuenta_id_orden
          FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` aaa
          WHERE dispositivo = 'SIM'
            AND pedido_padre IS NOT NULL
          GROUP BY ALL 
          HAVING  cuenta_id_orden > 1
        )
      )
      AND dispositivo = 'SIM'
    GROUP BY ALL 
  ) ccc
  WHERE aaa.marca = ccc.marca
    AND aaa.tipo_pedido = ccc.tipo_pedido
    AND aaa.numero_expedicion = ccc.numero_expedicion
    AND aaa.id_orden <> ccc.pedido_a_facturar;

    --Actualización de la tabla de ordenes para marcar el nº total de líneas que tiene el pedido que sí se factura en caso de MULTISIM --mar/25
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` aaa
  SET aaa.numero_lineas = bbb.numero_lineas
  FROM (
    SELECT lo.marca, lo.tipo_pedido, lo.numero_expedicion, MAX(lol.numero_linea) AS numero_lineas
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` lol
        ON  lol.marca = lo.marca
        AND lol.tipo_pedido = lo.tipo_pedido
        AND lol.id_orden = lo.id_orden
        AND lol.numero_expedicion = lo.numero_expedicion
    WHERE lo.estado_final = 'MULTISIM'
    GROUP BY ALL 
  ) bbb
  WHERE aaa.marca = bbb.marca
    AND aaa.tipo_pedido = bbb.tipo_pedido
    AND aaa.numero_expedicion = bbb.numero_expedicion
    AND aaa.estado_final NOT IN ('MULTISIM');

    --Actualización de la tabla de ordenes de logistica para marcar el nº total de líneas que tiene el pedido que sí se factura en caso de MULTISIM --mar/25
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` aaa
  SET aaa.numero_lineas = bbb.numero_lineas
  FROM (
    SELECT lo.marca, lo.tipo_pedido, lo.numero_expedicion, MAX(lol.numero_linea) AS numero_lineas
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
      LEFT JOIN `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` lol
        ON  lol.marca = lo.marca
        AND lol.tipo_pedido = lo.tipo_pedido
        AND lol.id_orden = lo.id_orden
        AND lol.numero_expedicion = lo.numero_expedicion
    WHERE lo.estado_final = 'MULTISIM'
    GROUP BY ALL 
  ) bbb
  WHERE aaa.marca = bbb.marca
    AND aaa.tipo_pedido = bbb.tipo_pedido
    AND aaa.numero_expedicion = bbb.numero_expedicion
    AND aaa.estado_final NOT IN ('MULTISIM');

	--ACTUALIZAMOS DISPOSITIVO + SIM
	UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
	SET lo.dispositivo = CASE WHEN lo.dispositivo in ('TERMINAL','STB','ACCESORIO','ROUTER','SMART TV','SMART TV+DOCUMENTACION','PAE','TABLET','MODEM','PATINETE') THEN CONCAT(lo.dispositivo,' + SIM')
							  WHEN lo.dispositivo = 'SIN DATOS EN ORDERBOX' THEN 'SIN DATOS EN ORDERBOX'
							  ELSE 'DISPOSITIVO + SIM' END,
		lo.numero_lineas =  pe_SIM.n_SIMs_ped_padre
	FROM `mm-commissions-reporting.TEMP.pedidos_SIM` pe_SIM
	WHERE pe_SIM.pedido_padre = lo.pedido_padre
	  AND pe_SIM.marca = lo.marca
    AND pe_SIM.numero_expedicion = lo.numero_expedicion
	  AND lo.dispositivo NOT IN ('SIM');

    --LISTADO DE PEDIDOS DE SIM CON DISPOSITIVOS CON SIM ADICIONAL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.TEMP.pedidos_DISPOSITIVO_SIM`
  OPTIONS(expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 15 DAY)) AS
  (
    SELECT loa.id_orden, loa.reexpedition, loa.pedido_padre, loa.marca --loa.pedido_padre, loa,id_orden, loa.marca
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` loa
    WHERE loa.pedido_padre in (
      SELECT distinct lo.pedido_padre
      FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
      WHERE lo.dispositivo LIKE '% + SIM'
    )
      AND loa.dispositivo IN ('SIM')
    GROUP BY ALL
  );
	  
	--ACTUALIZAMOS SIM + DISPOSITIVO
	UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
	SET lo.dispositivo = CONCAT(lo.dispositivo,' + DISPOSITIVO')
	FROM `mm-commissions-reporting.TEMP.pedidos_DISPOSITIVO_SIM` pds
	WHERE pds.pedido_padre = lo.pedido_padre
	  AND pds.marca = lo.marca
    AND pds.id_orden = lo.id_orden
    AND pds.reexpedition = lo.reexpedition
	  AND lo.dispositivo IN ('SIM');

	--ACTUALIZAMOS SIM + DISPOSITIVO
	UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
	SET lo.dispositivo = CONCAT(lo.dispositivo,' + DISPOSITIVO')
	FROM `mm-commissions-reporting.TEMP.pedidos_DISPOSITIVO_SIM` pds
	WHERE pds.pedido_padre = lo.pedido_padre
	  AND pds.marca = lo.marca
    AND pds.id_orden = lo.id_orden
    AND pds.reexpedition = lo.reexpedicion
	  AND lo.dispositivo IN ('SIM');

  --ACTUALIZAMOS SMART TV+DOCUMENTACION a impresos = 1, ya que los impresos se envían por Correos
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET total_impresos = 1
  WHERE lo.dispositivo IN ('SMART TV+DOCUMENTACION');

  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order`
  SET total_impresos = 1
  WHERE dispositivo IN ('SMART TV+DOCUMENTACION');

  --ACTUALIZAMOS MELILLA a impresos = 2 (Proforma y factura) 
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET total_impresos = 2
  WHERE UPPER(lo.provincia) IN ('MELILLA');

  --ACTUALIZAMOS MELILLA a impresos = 2 (Proforma y factura) 
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order`
  SET total_impresos = 2
  WHERE UPPER(provincia) IN ('MELILLA');

/*
  ------------------------------------------
  -- Corrijo PAE, MAE y GAE según el peso --
  -- Descartado a favor de la info de IB  --
  ------------------------------------------

  --DEFINO MAE EN MAYOR O IGUAL DE 6KG. 
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET dispositivo = 'MAE'
  WHERE UPPER(lo.dispositivo) IN ('PAE','MAE')
    AND UPPER(operador_logistico) = 'INTERBOX'
    AND UPPER(tipo_pedido) = 'ENTREGA' 
    AND UPPER(tipo_destinatario) = 'B2C'
    AND lo.total_peso > 7
    AND lo.total_peso <= 18;

  --DEFINO MAE EN MAYOR O IGUAL DE 6KG. 
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order`
  SET dispositivo = 'MAE'
  WHERE UPPER(dispositivo) IN ('PAE','MAE')
    AND UPPER(operador_logistico) = 'INTERBOX'
    AND UPPER(tipo_pedido) = 'ENTREGA' 
    AND UPPER(tipo_destinatario) = 'B2C'
    AND total_peso > 7
    AND total_peso <= 18;

  --DEFINO MAE EN MAYOR O IGUAL DE 6KG. 
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET dispositivo = 'GAE'
  WHERE UPPER(lo.dispositivo) IN ('PAE','MAE','GAE')
    AND UPPER(operador_logistico) = 'INTERBOX'
    AND UPPER(tipo_pedido) = 'ENTREGA' 
    AND UPPER(tipo_destinatario) = 'B2C'
    AND lo.total_peso > 18;

  --DEFINO MAE EN MAYOR O IGUAL DE 6KG. 
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order`
  SET dispositivo = 'GAE'
  WHERE UPPER(dispositivo) IN ('PAE','MAE','GAE')
    AND UPPER(operador_logistico) = 'INTERBOX'
    AND UPPER(tipo_pedido) = 'ENTREGA' 
    AND UPPER(tipo_destinatario) = 'B2C'
    AND total_peso > 18;
*/
  --------------------------------------------------------------------
  --Corrijo PAE, MAE y GAE según la información recibida de Interbox--
  --------------------------------------------------------------------

  --Actualizamos PAE, MAE y GAE en la orden, según el fichero recibido de Interbox  
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET lo.dispositivo = PMG.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` lol,
       `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_PAE_MAE_GAE` PMG
  WHERE lo.id_orden = lol.id_orden
    AND lo.reexpedition = lol.reexpedicion
    AND lo.tipo_pedido = lol.tipo_pedido
    AND lol.id_modelo = PMG.codigo;

  --Actualizamos PAE, MAE y GAE en la orden, según el fichero recibido de Interbox
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET lo.dispositivo = PMG.dispositivo
  FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` lol,
       `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_PAE_MAE_GAE` PMG
  WHERE lo.id_orden = lol.id_orden
    AND lo.reexpedicion = lol.reexpedicion
    AND lo.tipo_pedido = lol.tipo_pedido
    AND lol.id_modelo = PMG.codigo;

  --Actualizamos PAE, MAE y GAE en la línea, según el fichero recibido de Interbox
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line` lol
  SET lol.dispositivo = PMG.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_PAE_MAE_GAE` PMG
  WHERE lol.id_orden = lol.id_orden
    AND lol.reexpedicion = lol.reexpedicion
    AND lol.tipo_pedido = lol.tipo_pedido
    AND lol.id_modelo = PMG.codigo;

  --Actualizamos PAE, MAE y GAE en la línea, según el fichero recibido de Interbox
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line` lol
  SET lol.dispositivo = PMG.dispositivo
  FROM `mm-commissions-reporting.COSTES_LOGISTICOS.10_gs_PAE_MAE_GAE` PMG
  WHERE lol.id_orden = lol.id_orden
    AND lol.reexpedicion = lol.reexpedicion
    AND lol.tipo_pedido = lol.tipo_pedido
    AND lol.id_modelo = PMG.codigo;

  --Corregimos problemas con el peso de los contratos de smart tv
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET total_peso = 0.2
  WHERE lo.dispositivo = 'DOCUMENTACION SMART TV'  
    AND lo.tipo_pedido = 'Entrega'
    AND lo.total_peso IS NULL;

  --Corregimos problemas con el peso de los contratos de smart tv
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET total_peso = 0.2
  WHERE lo.dispositivo = 'DOCUMENTACION SMART TV'  
    AND lo.tipo_pedido = 'Entrega'
    AND lo.total_peso IS NULL;

  --ONT lleva 1 preimpreso que actualizamos manualmente
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET total_preimpresos = 1
  WHERE LOWER(lo.id_orden) LIKE '%ont'
    AND lo.estado_final NOT IN ('MULTISIM')
    AND total_preimpresos = 0;

  --ONT lleva 1 preimpreso que actualizamos manualmente
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET total_preimpresos = 1
  WHERE LOWER(lo.id_orden) LIKE '%ont'
    AND lo.estado_final NOT IN ('MULTISIM')
    AND total_preimpresos = 0;

--ONT lleva peso que actualizamos manualmente
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET total_peso = 1
  WHERE LOWER(lo.id_orden) LIKE '%ont'
    AND lo.estado_final NOT IN ('MULTISIM')
    AND total_peso IS NULL;

  --ONT lleva peso que actualizamos manualmente
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET total_peso = 1
  WHERE LOWER(lo.id_orden) LIKE '%ont'
    AND lo.estado_final NOT IN ('MULTISIM')
    AND total_peso IS NULL;

  --Precio ONT = 30€
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order_line`
  SET precio_almacen_sin_imp = 20
  WHERE LOWER(id_orden) LIKE '%ont'
    AND precio_almacen_sin_imp IS NULL;
  
  --Precio ONT = 30€
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line`
  SET precio_almacen_sin_imp = 20
  WHERE LOWER(id_orden) LIKE '%ont'
    AND precio_almacen_sin_imp IS NULL;

  --Actualizamos el pedido del dispositivo adicional para que no se facture
  UPDATE `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
  SET estado_final = 'MULTIDISPOSITIVO'
  FROM (
    SELECT lo.id_orden, lo.reexpedition
    FROM `mm-commissions-reporting.COSTES_LOGISTICOS.41_logistic_order` lo
    INNER JOIN `mm-commissions-reporting.TEMP.pedidos_varios_dispositivos` pvd
      ON pvd.ot = lo.pedido_padre
    WHERE lo.numero_lineas = 1
  --    AND lo.pedido_padre IN ('PV12958764','PV13015999')
    GROUP BY ALL
  ) AS tabla
  WHERE lo.id_orden = tabla.id_orden
    AND lo.reexpedition = tabla.reexpedition
    AND lo.tipo_pedido = 'Entrega';

  --Actualizamos el pedido del dispositivo adicional para que no se facture
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
  SET estado_final = 'MULTIDISPOSITIVO'
  FROM (
    SELECT lo.id_orden
    FROM `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order` lo
    INNER JOIN `mm-commissions-reporting.TEMP.pedidos_varios_dispositivos` pvd
      ON pvd.ot = lo.pedido_padre
    WHERE lo.numero_lineas = 1
  --    AND lo.pedido_padre IN ('PV12958764','PV13015999')
    GROUP BY ALL
  ) AS source
  WHERE lo.id_orden = source.id_orden;

  -------------------------------
  -- Corrección de dispositivo --
  -------------------------------
  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order`
  SET dispositivo = 'ACCESORIO'
  WHERE dispositivo IN ('Accesories','ACCESORIES WITH SERIAL NUMBER');

  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order`
  SET dispositivo = 'SIM'
  WHERE dispositivo = 'SIM CARD';

  UPDATE `mm-logistics-reporting.LOG_DIRECTA.40_logistic_order_line`
  SET dispositivo = 'ACCESORIO'
  WHERE dispositivo IN ('Accesories','ACCESORIES WITH SERIAL NUMBER');

----------------------------------------------------------------------------------------
-- Hay que meter el claim_code en los costes, después de este proceso y del de costes --
--          Quizá basta con meterlo en los listados finales, en los invoices          --
----------------------------------------------------------------------------------------

END