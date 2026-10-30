BEGIN

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
  SET categoria_servicio_ds="MOVILES POSTPAGO"  WHERE marca_ds="R"  and categoria_servicio_ds="DESCONOCIDO"  AND CONTAINS_SUBSTR(concepto_ds,"MAMBO AXI");

  UPDATE `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
  SET categoria_servicio_ds="MOVILES POSTPAGO"  
  WHERE (marca_ds="EUSKALTEL" or marca_ds="TELECABLE") 
  AND CATALOGO_ID="11575" 
  AND CONTAINS_SUBSTR(detalle_servicio_ds,"hegan-combi") 
  AND categoria_servicio_ds!="MOVILES POSTPAGO";

    --SELECT marca_ds, categoria_servicio_ds, detalle_servicio_ds, catalogo_id,concepto_ds, count(servicio_id) as nserv
    --from  `mm-commissions-reporting.KRT_CAPTACION.VENTAS_CAPTACION`
    --WHERE CONTAINS_SUBSTR(detalle_servicio_ds,"hegan-combi")  and catalogo_id="11575" 
    --group by 1,2,3,4,5;


END