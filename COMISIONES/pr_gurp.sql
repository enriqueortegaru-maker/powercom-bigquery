begin

declare sql , prefijo , mes_string string;

declare canales_pr ARRAY <STRING>;

set canales_pr = (select COMISIONES.f_canales_por_proceso ('GURP'));

set prefijo = 'GURP';

set mes_string = cast(mes_int as string);

-- call `mm-commissions-reporting.COMISIONES.pr_gurp` (202309);

CREATE OR REPLACE TABLE
  `mm-commissions-reporting.TEMP.gurp` AS
SELECT
  a.* EXCEPT (
    concepto,
    comision,
    commission_id,
    mes_liquidado,
    facturador,
    tipo_concepto,
    comments,
    id_mes),
 
  prefijo||'_'||mes_string||'_'||a.canal||'_'||row_number () OVER () AS commission_id,

  CASE
    WHEN c.concepto = 'D - Rappel Guuk'   
      and bundle_type in ('FMC','2P')                           then b.rappel_guuk
  end  AS comision,

  c.concepto,

  c.tipo_concepto,

  mes_int AS id_mes, 

  'C_MANUAL' AS facturador,

  cast (null as string ) as comments

FROM
  `mm-commissions-reporting.COMISIONES.transacciones` a
INNER JOIN
  `mm-commissions-reporting.GS.MARCO_RAPPEL_GU` b
ON
  a.id_comisionista=b.id_comisionista
  AND b.id_mes = mes_int
  and a.canal = b.canal
CROSS JOIN
  `mm-commissions-reporting.GS.CONCEPTOS` c
WHERE
  a.agrupacion_canal = 'Guuk'
  AND c.proceso = 'GURP'
  AND a.concepto = 'A - Servicio Fijo'
  AND a.id_mes = mes_int
  and
  CASE
    WHEN c.concepto = 'D - Rappel Guuk'   
      and bundle_type in ('FMC','2P')                            then b.rappel_guuk
  end > 0
;

-- Inserta tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, mes_int, canales_pr , 'TEMP.gurp' , 'ACTUALIZAR');

end