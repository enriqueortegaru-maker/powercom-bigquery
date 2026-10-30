BEGIN

    CREATE OR REPLACE TABLE `mm-commissions-reporting.KRT_CAPTACION.LOG_0506_AJUSTES_EVENTOS_DEFINITIVOS_UPD` AS
    select * from `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` where grid in (8,9);

    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` SET concepto_ds=concat('Promocion por concepto: ',concepto_ds ) WHERE grid=8;
    UPDATE `mm-commissions-reporting.KRT_CAPTACION.AJUSTES_EVENTOS_DEFINITIVOS` SET concepto_ds=concat('Oferta por concepto: ',concepto_ds ) WHERE grid=9;    

END