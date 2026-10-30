BEGIN
  
  CREATE OR REPLACE TEMP TABLE tmp_param_terminales AS
  SELECT DISTINCT
      Modelo,
      clase,
      CASE 
        WHEN clase = "Dispositivo" THEN "DISPOSITIVOS"
        WHEN clase = "Terminal" THEN "TERMINALES" 
      END as TipoProductoNuevo_Calc
  FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES`
  WHERE Modelo IS NOT NULL;

  
  UPDATE `mm-commissions-reporting.KRT_CARTERA.EVENTOS_CARTERA` c
  SET 
      c.claseProducto = p.clase,
      c.TipoProducto = p.TipoProductoNuevo_Calc
  FROM tmp_param_terminales p
  WHERE c.NombreProducto = p.Modelo
    AND c.marca_ds != 'R'
    AND c.idCatalogo IN ("6851", "7003")   
    AND (
         (c.TipoProducto = "DISPOSITIVOS" AND UPPER(c.claseProducto) != "DISPOSITIVO") 
      OR (c.TipoProducto = "TERMINALES" AND UPPER(c.claseProducto) != "TERMINAL")
    );

END