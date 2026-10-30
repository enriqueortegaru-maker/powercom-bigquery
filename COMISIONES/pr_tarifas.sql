begin

declare meses array<STRING>;
declare sql string;

set meses = (
SELECT split(valor)
FROM GS.PARAMETROS
where parametro = 'meses_validacion_tarifas'
limit 1
);

IF canal_pr = 'XS' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr, * except (id_mes_pr,campaign_code), campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';

--- EXCEPCION PARA CANALES CON JAZZTEL QUE ARRASTRAMOS EL PROMOTION CODE PARA PODER CONFIGURAR EN GS AL CAMPO PVP Y ASI QUE NO FALLE LA INSERCION EN TARIFAS
ELSEIF canal_pr = 'XSO' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr,marca, service_type,tariff_id, tariff_ds, line_type_ds,CAST(NULL AS FLOAT64) AS pvp, * except (id_mes_pr,marca, service_type,tariff_id, tariff_ds,campaign_code line_type_ds,pvp), campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';

ELSEIF canal_pr = 'DO' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr,marca, service_type,tariff_id, tariff_ds, line_type_ds,CAST(NULL AS FLOAT64) AS pvp, * except (id_mes_pr,marca, service_type,tariff_id, tariff_ds, line_type_ds,pvp), NULL AS campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';

ELSEIF canal_pr = 'MKT_NR' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr,marca, service_type,tariff_id, tariff_ds, line_type_ds,CAST(NULL AS FLOAT64) AS pvp, * except (id_mes_pr,marca, service_type,tariff_id, tariff_ds, line_type_ds,pvp,bundle_type), NULL AS campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';

ELSEIF  canal_pr = 'OSPNIN' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr, * except (id_mes_pr,campaign_code), campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';

ELSEIF  canal_pr = 'OSPNXSN' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr, * except (id_mes_pr,campaign_code), campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';

ELSEIF  canal_pr = 'OSPNOUN' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr, * except (id_mes_pr,campaign_code), campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';

ELSEIF  canal_pr = 'OUO' THEN
  set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
  set sql = sql || 'select "';
  set sql = sql || canal_pr;
  set sql = sql || '", id_mes_pr, * except (id_mes_pr,campaign_code), campaign_code , SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
  set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
  set sql = sql || canal_pr;
  set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
  set sql = sql || 'where tariff_id IS NOT NULL';


ELSE

set sql = 'insert into `mm-commissions-reporting.COMISIONES.tarifas` ';
set sql = sql || 'select "';
set sql = sql || canal_pr;
set sql = sql || '", id_mes_pr, * except (id_mes_pr) ,NULL AS campaign_code, SESSION_USER(), CURRENT_TIMESTAMP(),NULL AS bundle_type from ';
set sql = sql || '`mm-commissions-reporting.GS.TARIFAS_';
set sql = sql || canal_pr;
set sql = sql || '`, unnest (['||ARRAY_TO_STRING(meses, ',')||'] ) id_mes_pr ';
set sql = sql || 'where tariff_id IS NOT NULL';

END IF;

execute immediate (sql);

end