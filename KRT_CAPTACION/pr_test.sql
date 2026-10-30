BEGIN 
  --DECLARE marca_ds, nombre_distribuidor_ds STRING;
  --SET marca_ds="EUSKALTEL";
  --SET nombre_distribuidor_ds="ASS PROMESA SLU";

  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.TEMP` AS
  SELECT `mm-commissions-reporting.KRT_CAPTACION.f_trans_crea_acreedor`(marca, distribuidor) as valor;
END