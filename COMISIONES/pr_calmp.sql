BEGIN

-- CALL `mm-commissions-reporting.COMISIONES.pr_calmp`(202606, ['MP']);


-- Crear sfids en tabla DEALER con agrup_canal NEXC y canal MP

				-- Si es necesario volver a lanzar el cálculo, borrar los que creamos en la ejecución anterior
				DELETE `mm-commissions-reporting.COMISIONES.dealer` 
				WHERE canal = 'MP'
				AND id_mes = id_mes_pr
				;

INSERT INTO `mm-commissions-reporting.COMISIONES.dealer`
(
	id_mes
,	agrupacion_canal
,	sfid
,	id_comisionista
,	distribuidor
,	canal
,	comisiona
,	nombre_comercio
,	razon_social
,	documento
,	zona_fiscal
,	comentarios
,	cif_gpv
, creado_por
, creado
)
SELECT 
id_mes_pr
,	agrupacion_canal
,	sfid
,	id_comisionista
,	distribuidor
,	canal
,	comisiona
,	nombre_comercio
,	razon_social
,	documento
,	zona_fiscal
,	comentarios
,	cif_gpv
, 'CALMP' AS creado_por
, CURRENT_TIMESTAMP() AS creado
FROM 
			(SELECT DISTINCT * EXCEPT(creado,creado_por)
			FROM `mm-commissions-reporting.COMISIONES.dealer` A
			INNER JOIN `mm-commissions-reporting.GS.cartera_mp` B
							ON A.id_comisionista = B.sfid_origen
			WHERE id_mes = 202601
      )
;

-- Lanzar cálculo cartera MP e insertar en tabla Transacciones

CALL `mm-commissions-reporting.COMISIONES.pr_cald_mp_exc`(id_mes_pr, ['MP']);


-- Llevar a estado rechazado los sellers que no crucen con sfid_origen

	UPDATE `mm-commissions-reporting.COMISIONES.transacciones` A
	SET A.estado = 'rechazado'
	FROM (SELECT commission_id
	      FROM `mm-commissions-reporting.COMISIONES.transacciones` A
	      LEFT JOIN `mm-commissions-reporting.GS.cartera_mp` B
	            ON A.seller = B.sfid_origen
	      WHERE id_mes = id_mes_pr
	      AND canal = 'MP'
	      AND (B.sfid_origen IS NULL OR B.sfid_migrado IS NULL)
	      AND A.estado NOT IN ('facturado','validado')
	      ) B
WHERE A.commission_id = B.commission_id
;

-- Actualizar campos en tabla Transacciones

	UPDATE `mm-commissions-reporting.COMISIONES.transacciones` A
	SET 
	      A.agrupacion_canal = 'Exclusivo'
	      ,A.id_comisionista = B.sfid_migrado
	      ,A.seller = B.sfid_migrado
	      ,A.cif = B.cif_migrado
	      ,A.comments = 'Mig. MP_'||A.comments
	FROM (SELECT commission_id, sfid_migrado,cif_migrado
	      FROM `mm-commissions-reporting.COMISIONES.transacciones` A
	      LEFT JOIN `mm-commissions-reporting.GS.cartera_mp` B
	            ON A.seller = B.sfid_origen
	      WHERE 1 =1 
	      AND id_mes = id_mes_pr
	      AND canal = 'MP'
				AND facturador != 'C_IFS' -- Cálculo Javi
	      AND B.sfid_origen IS NOT NULL
	      AND A.estado NOT IN ('rechazado', 'facturado', 'confirmado')
	      ) B
WHERE A.commission_id = B.commission_id
;

END