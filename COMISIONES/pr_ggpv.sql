begin


declare prefijo, mes_string string;

set mes_string = cast(id_mes_pr as string);

set prefijo = 'GGPV';


---call `mm-commissions-reporting.COMISIONES.pr_ggpv` (202302);

create or replace table TEMP.ggpv as
SELECT
  a.* EXCEPT (commission_id,
    concepto,
    tipo_concepto,
    facturador,
    comments,
    comision,
    cod_producto,
    cod_tipo_contrato,
    cif,
    id_comisionista,
    nombre_comercio,
    razon_social,
    zona_fiscal),
  prefijo||'_'||mes_string||'_'||a.canal||'_'||row_number () OVER () AS commission_id,
  'G' || SUBSTR( c.concepto,2) AS concepto,
  a.tipo_concepto,
  a.comision,
  'C_MANUAL' AS facturador,
  CAST (NULL AS string) AS comments,
  a.cod_producto,
  a.cod_tipo_contrato,
  m.cif,
  m.id_comisionista,
  m.nombre_comercio,
  m.razon_social,
  m.zona_fiscal
from `mm-commissions-reporting.COMISIONES.transacciones` A
inner join `mm-commissions-reporting.GS.CONCEPTOS` c on a.concepto=c.concepto
inner join `mm-commissions-reporting.COMISIONES.v_dealer` d on a.seller = d.sfid_id and d.id_mes = id_mes_pr
inner join `mm-commissions-reporting.GS.NO_EXCLUSIVO_MASTER` m on m.cif = d.cif_gpv
where a.canal in ('MI','CA')
and a.id_mes = id_mes_pr
and a.estado='calculado'
--- Configuracion ---
and a.agrupacion_canal = 'No Exclusivo'
and c.aplica_ggpv
;

-- Actualización tabla final --

call `mm-commissions-reporting.COMISIONES.pr_insert_comisiones` (prefijo, id_mes_pr, ['MI','CA'] , 'TEMP.ggpv' , 'ACTUALIZAR');

end