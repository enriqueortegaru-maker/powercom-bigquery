BEGIN
  
  CREATE OR REPLACE TEMP TABLE tmp_param_terminales AS
  SELECT DISTINCT
      Modelo,
      clase,
      tipo,
      CASE 
        WHEN contains_substr(clase, "Dispositivo") THEN "DISPOSITIVOS"
        WHEN contains_substr(clase ,"Terminal") THEN "TERMINALES" 
      END as TipoProductoNuevo_Calc
  FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_TERMINALES`
  WHERE Modelo IS NOT NULL;

  
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET 
      c.claseProducto = p.clase,
      c.TipoProducto = p.TipoProductoNuevo_Calc
  FROM tmp_param_terminales p
  WHERE c.NombreProducto = p.Modelo
    AND c.marca_ds != 'R'
    AND c.idCatalogo IN ("6851", "7003")   
    AND (
         (contains_substr(c.TipoProducto,"DISPOSITIVOS") AND not contains_substr(c.claseProducto, "DISPOSITIVO")) 
      OR (contains_substr(c.TipoProducto,"TERMINALES") AND not contains_substr(c.claseProducto,"TERMINAL"))
    );
 -- AND (TRIM(UPPER(c.claseProducto))!=UPPER(TRIM(p.clase)) OR UPPER(TRIM(c.TipoProducto)) != UPPER(TRIM(p.TipoProductoNuevo_Calc)) );


/*
  --- CORRECTIVO CLASE_MM y DESC_MM añadido
  UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  SET clase_mm=  case when contains_substr(p.clase,"dispositivo") then 'T - Dispositivos'
       when contains_substr(p.clase,"terminal") then 'T - Terminales'
  END,
  desc_mm=  case when contains_substr(p.clase,"dispositivo") then concat('T - ',p.Tipo)
       when contains_substr(p.clase,"terminal") then 'T - Terminal movil'
  END
  FROM tmp_param_terminales p 
  WHERE c.NombreProducto = p.Modelo
    AND c.marca_ds != 'R'
    AND c.idCatalogo IN ("6851", "7003")   
    AND (
         (contains_substr(c.TipoProducto,"DISPOSITIVOS") AND (contains_substr(c.desc_mm, "T - Term") or not contains_substr(c.desc_mm, "T -"))) 
      OR (contains_substr(c.TipoProducto,"TERMINALES") AND not contains_substr(c.desc_mm,"T - Terminal"))
    );

*/

/*
  select c.marca_ds, c.ClaseProducto, c.TipoProducto, c.NombreProducto, c.clase_mm, c.desc_mm, p.clase, p.Tipo,p.TipoProductoNuevo_Calc, 
  case when contains_substr(p.clase,"dispositivo") then 'T - Dispositivos'
       when contains_substr(p.clase,"terminal") then 'T - Terminales'
  END as Clase_mm_nuevo,
  case when contains_substr(p.clase,"dispositivo") then concat('T - ',p.Tipo)
       when contains_substr(p.clase,"terminal") then 'T - Terminal movil'
  END as desc_mm_nuevo,
  count(distinct idProducto) as npr
  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
  inner join tmp_param_terminales p on c.NombreProducto = p.Modelo
  WHERE c.NombreProducto = p.Modelo
    AND c.marca_ds != 'R'
    AND c.idCatalogo IN ("6851", "7003")   
    AND (
         (contains_substr(c.TipoProducto,"DISPOSITIVOS") AND (contains_substr(c.desc_mm, "T - Term") or not contains_substr(c.desc_mm, "T -"))) 
      OR (contains_substr(c.TipoProducto,"TERMINALES") AND not contains_substr(c.desc_mm,"T - Terminal"))
    )
  group by all;
*/


/*
  CREATE TEMP TABLE tmp_param_catalogos AS
  SELECT DISTINCT
      NombreProducto,
      TipoProducto,
      TipoProducto as claseProductoNuevo,
      CASE 
        WHEN contains_substr(TipoProducto, "Dispositivo") THEN "DISPOSITIVOS"
        WHEN contains_substr(TipoProducto ,"Terminal") THEN "TERMINALES" 
      END as TipoProductoNuevo_Calc,

  FROM `mm-commissions-reporting.KRT_CARTERA.PARAM_CATALOGO`
  WHERE sistema="MAEXE"
  and (contains_substr(tipoProducto,"Dispositivo") or contains_substr(tipoProducto,"Terminal"))
  AND NombreProducto IS NOT NULL;


  SELECT distinct c.ClaseProducto, c.TipoProducto, p.claseProductoNuevo, p.TipoProductoNuevo_Calc
  from `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c 
  inner join tmp_param_catalogos p
  on c.NombreProducto = p.NombrePRoducto 
  AND c.marca_ds = 'R'
  AND (
          (contains_substr(c.TipoProducto,"DISPOSITIVOS") AND not contains_substr(c.claseProducto, "DISPOSITIVO")) 
        OR (contains_substr(c.TipoProducto,"TERMINALES") AND not contains_substr(c.claseProducto,"TERMINAL"))
  )
  AND (TRIM(UPPER(c.claseProducto))!=UPPER(TRIM(p.claseProductoNuevo)) OR UPPER(TRIM(c.TipoProducto)) != UPPER(TRIM(p.TipoProductoNuevo_Calc)) )

    UPDATE `mm-commissions-reporting.KRT_CARTERA.COMISIONES` c
    SET 
        c.claseProducto = p.claseProductoNuevo,
        c.TipoProducto = p.TipoProductoNuevo_Calc
    FROM tmp_param_catalogos p
    WHERE c.NombreProducto = p.Modelo
      AND c.marca_ds = 'R'
      AND (
          (contains_substr(c.TipoProducto,"DISPOSITIVOS") AND not contains_substr(c.claseProducto, "DISPOSITIVO")) 
        OR (contains_substr(c.TipoProducto,"TERMINALES") AND not contains_substr(c.claseProducto,"TERMINAL"))
      )
      AND (TRIM(UPPER(c.claseProducto))!=UPPER(TRIM(p.claseProductoNuevo)) OR UPPER(TRIM(c.TipoProducto)) != UPPER(TRIM(p.TipoProductoNuevo_Calc)) );
  */    

 
END