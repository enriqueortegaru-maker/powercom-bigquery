BEGIN 
/*
    CREACION DE NUEVA VERSION - VERSION 11
    FUNCIONALIDADES:
        INTEGRACION DE CALCULO DE TABLAS DE VENTAS DE RAPPEL EN SCRIPT DE DESCUBRIMIENTO DE VENTAS
            CREACION DE FICHERO AGG_RAPPEL VENTAS
            INTEGRACION DE CALCULO DE TABLAS DE VENTAS DE RAPPEL EN SCRIPT DE DESCUBRIMIENTO DE VENTAS
            GESTIONAR RECARGAS Y DESCUBRIIENTOS DE TABLAS DE RAPPEL VENTAS
        AÑADIR PREFIJO A CONCEPTOS DE PROMOCIONES

    FUNCIONES:
            
    CORRECTIVO

    MODULOS CON NUEVO REGISTRO DE DATOS
        subprex_0602_CalcularClawbackv6                                 -> Crea tablas BAJAS_SB_ALTAS_24M y BAJAS_TOT_ALTAS_24M

    NUEVA VERSIONES DE MODULOS
        prex_flujoDeCaptacionv11        
        subprex_0170_CrearTablaRappelVentas                             -> prex_VENTAS_CAPTACIONv7
        subprex_0180_DescubrirServiciosCaptadosConPortabilidadEntrantev1 -> descubre servicios captados con portabiliad entrante
        subprex_0501_CargarAjustesPortabilidadesIntragrupov1            -> Âpunta a nuevas tablas descubiertas por subprex_0180_DescubrirServiciosCaptadosConPortabilidadEntrantev1
        subprex_0502_ActualizarUnitariosIntragrupo`()                   -> sustituye a subpr_0502_ActualizarUnitariosIntragrupo`() 
        subprex_0602_CalcularClawbackv6                                 -> Integrar table Clawback24M
        subprex_0603_CalcularClawback_SVA_Rv1                           -> Integrar table Clawback24M
        subprex_1001_ActualizarHistoricoDeCaptacionv2                   -> Integrar table Clawback24M
        subprex_1003_ActualizarTablasAggExtraccionv5                    -> Integrar tablas y Clawback24M
               

    NUEVOS MODULOS
        subprex_011020_CargarOfertasv1`()                                -> Descubre las ofertas en EktNet
        subprex_0180_DescubrirServiciosCaptadosConPortabilidadEntrantev1 -> Descubre servicios captados con portabiliad entrante
        subprex_100130_ActualizarHistoricoDeBajas                        -> Actualiza historio de bajas   
        prActualizaReportingBajas24M                                     -> Actualiza reporting bajas

        
    NUEVAS TABLAS:
        CLAWBACK_6M
        CLAWBACK_24M
        ACC_CLAWBACK_24M
        ACC_CLAWBACK_24M_HISTORICO        
        AGG_DECOMISIONES_24M
        BAJAS_SB_ALTAS_24M
        BAJAS_TOT_ALTAS_24M
        subprex_100130_ActualizarHistoricoDeBajas        
                                        BAJAS_SB_24M_HISTORICO
                                        BAJAS_TOT_24M_HISTORICO

        prActualizaReportingBajas24M    LOG_REPORTING_BAJAS24M_CARGA_REGISTROS
                                        BAJAS_SB_24M_CARGA_REPORTING
                                        BAJAS_SB_24M_HISTORICO
                                        REPORTING_BAJAS24M

        


    NUEVAS VISTAS
        CLAWBACK_24M_HISTORICO



   
    PDTE: 
        subprex_0180_DescubrirServiciosCaptadosConPortabilidadEntrantev1    -> Integrar en módulo de servicios captación para impedir redescubrimientos innecesarios
        subprex_1001_ActualizarHistoricoDeCaptacionv2                       -> Recrear parte de tratamiento de duplicados en histórico

*/

END