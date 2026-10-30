BEGIN
  call `mm-commissions-reporting.KRT_CAPTACION_MM.pr_EVENTOS_CAPTACION`(desde , hasta);  
  call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0201_CalcularUnitario`();
  call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0202_CalcularRappel`();
  call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0301_CalcularDecomisiones`(desde , hasta);
  call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0401_ExtraerComisiones`();
  call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0402_GenerarInfomeComisiones`();  
  call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0403_ExtraerDecomisiones`();
  call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0404_GenerarInformeDecomisiones`();  
  if registro >0 then
    call `mm-commissions-reporting.KRT_CAPTACION_MM.subpr_0501_ActualizarHistoricoDeCaptacion`(desde, hasta);
  end if;
END