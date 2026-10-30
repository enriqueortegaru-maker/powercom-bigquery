BEGIN


  --create or replace table `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS  select * from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN`;

  /*select * from `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and contains_substr(equipo, "02000")
  and marco_retributivo="MR Televenta_UPG";
  */

  UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  SET marco_retributivo="MR Televenta_UPS"
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and contains_substr(equipo, "02000")
  and marco_retributivo="MR Televenta_UPG";


  /*select * from `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and contains_substr(equipo, "04000")
  and marco_retributivo="MR Televenta_UPS";
  */


  UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  SET marco_retributivo="MR Televenta_UPG"
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and contains_substr(equipo, "04000")
  and marco_retributivo="MR Televenta_UPS";




  --- PASO 3: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_030610_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

END