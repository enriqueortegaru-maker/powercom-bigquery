BEGIN


  --create or replace table `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL` AS  select * from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN`;

  /*--select * from `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  select * from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN`
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and equipo in (
    'BIO48TV-02000',
    'CAM48TV-02000',
    'NNS48TV-02000',
    'ERA48TV-02000',
    'GIT48TV-02000',
    'LND48TV-02000'
  )
  and UPPER(TRIM(coalesce(marco_retributivo,'NOINF')))!="MR TELEVENTA_UPS";
  */

  UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  SET marco_retributivo="MR Televenta_UPS"
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and equipo in (
    'BIO48TV-02000',
    'CAM48TV-02000',
    'NNS48TV-02000',
    'ERA48TV-02000',
    'GIT48TV-02000',
    'LND48TV-02000'
  )
  and UPPER(TRIM(coalesce(marco_retributivo,'NOINF')))!="MR TELEVENTA_UPS";


  /*--select * from `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  select * from `mm-commissions-reporting.KRT_CARTERA.LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN`  
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and equipo in (
    'IBE48TV-02000',
    'GIT48TV-04000',
    'LND48TV-04000',
    'XUP48TV-04000'
  )
  and UPPER(TRIM(coalesce(marco_retributivo,"NOINF")))!="MR TELEVENTA_UPG";  
  */


  UPDATE `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`
  SET marco_retributivo="MR Televenta_UPG"
  WHERE marca_ds="EUSKALTEL"
  AND canal="TELEVENTA"
  AND subcanal="AGENTE VENTAS CARTERA"
  and equipo in (
    'IBE48TV-02000',
    'GIT48TV-04000',
    'LND48TV-04000',
    'XUP48TV-04000'
  )
  and UPPER(TRIM(coalesce(marco_retributivo,"NOINF")))!="MR TELEVENTA_UPG";




  --- PASO 3: CREO TABLA LOG LOG_0306_MARCO_RETRIBUTIVO_TELEVENTASxCANAL
  CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CARTERA.LOG_030610_MARCO_RETRIBUTIVO_TELEVENTASxCANAL_FIN` AS
  SELECT * FROM `mm-commissions-reporting.KRT_CARTERA.MARCO_RETRIBUTIVO_TELEVENTASxCANAL`;

END