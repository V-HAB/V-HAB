classdef setup < simulation
   %Setup of the lunar greenhouse (LGH) system simulation.
    properties
        
    end
   %% -Setup-  
    methods
        function this = setup()
            this@simulation('plant_module_tutorial');
          
        %% -General Settings-
            %Setting of time parameters:
            


            
        %% -Root Object - Greenhouse System-     
            
                %Assigning Root Object - Initializing system 'Greenhouse'
                tutorials.plant_module.systems.Greenhouse(this.oRoot, 'Greenhouse');
           
                   
        
                    
        %% -Simulation Settings-
        
            % Setting simulation duration
            % 50 000 seconds is fairly short for the plant model, however to
            % enable testing and playing around with parameters, this time
            % was chosen. To produce more significant results, the
            % simulation should be run for 12 000 000 seconds. This will
            % however take several hours on a modern computer.
            this.fSimTime  = 50000;     % [s]
            this.iSimTicks = 400;       % ticks
            this.bUseTime  = true;      % true -> use this.fSimTime as Duration of Simulation


             
             
             
             
             
        %% -Simulation Log-
           %Log - Stated are paths to all values that are logged for plotting
            this.csLog = {
             'oData.oTimer.fTime';                                                  %1 Time in seconds
             
             %Greenhouse parameters
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).fPressure';        %2 Greenhouse's 'air'-phase total pressure
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).fMass';            %3 Greenhouse's 'air'-phase total mass
             
             %CO2Compensation
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(2).fMass';        %4 CO2 excess phase - mass 
             %O2Compensation
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(3).fMass'         %5 O2 excess phase - mass
             %Water separated - in and out flows
                 'toChildren.Greenhouse.aoBranches(1).fFlowRate';                   %6  Water separator Inflow - greenhouse -> water separator
                 'toChildren.Greenhouse.aoBranches(2).fFlowRate';                   %7  Water separator Outflow - water separator -> greenhouse
             %Further Greenhouse parameters
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.O2)';           %8      Greenhouse's air-phase O2 partial mass
                 'toChildren.Greenhouse.toChildren.PlantModule.toStores.PlantCultivationStore.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.O2)'; %9 PlantModule's air-phase O2 partial mass
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).rRelHumidity';                                     %10     Greenhouse's relative humidity
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.N2)'            %11     N2 partial Mass Greenhouse Air-Phase
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.H2O)';          %12     Greenhouse's air-phase H2O partial mass
                 'toChildren.Greenhouse.toChildren.PlantModule.toStores.PlantCultivationStore.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.N2)'; %13 N2 partial Mass PlantModule Air-Phase

                 'toChildren.Greenhouse.toStores.WaterSeparator.aoPhases(1).fMass';                                     %14     Water Separator's air-phase total mass
                 'toChildren.Greenhouse.toStores.WaterSeparator.aoPhases(2).fMass';                                     %15     Water Separator's separated water-phase total mass
                 'toChildren.Greenhouse.aoBranches(3).fFlowRate';                                                       %16     Not in use
                 'toChildren.Greenhouse.toStores.WaterSeparator.aoPhases(1).fPressure';                                 %17     Water Separator's air-phase pressure

                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).afPP(this.oData.oMT.tiN2I.CO2)';                   %18     Greenhouse's air-phase partial pressure of CO2
                 'toChildren.Greenhouse.fCO2ppm_Measured';                                                              %19     'Greenhouse's ppm level of CO2 in air-phase

                 'toChildren.Greenhouse.toStores.WaterTank.aoPhases(1).fMass';                                          %20     Water mass in supply tank
                 'toChildren.Greenhouse.toStores.FoodStore.aoPhases(1).fMass';                                          %21     Food store mass
                 'toChildren.Greenhouse.toStores.WasteTank.aoPhases(1).fMass';                                          %22     Waste tank mass

                 'toChildren.Greenhouse.toChildren.PlantModule.aoBranches(1).fFlowRate';                                %23     Circulation Greenhouse -> Plant Cultivation
                 'toChildren.Greenhouse.toChildren.PlantModule.aoBranches(2).fFlowRate';                                %24     Circulation Plant Cultivation -> Greenhouse

                 
                 'toChildren.Greenhouse.toChildren.PlantModule.toStores.PlantCultivationStore.aoPhases(2).fMass';       %25     Mass Plants-phase
             %Gas exchanges
                 'toChildren.Greenhouse.toChildren.PlantModule.oProc_Plants_H2OGasExchange.fFlowRate';                  %26     Exchange rate H2O (transpiration); positive: Plants-phase -> air-phase
                 'toChildren.Greenhouse.toChildren.PlantModule.oProc_Plants_O2GasExchange.fFlowRate';                   %27     Exchange rate O2; positive: Plants-phase -> air-phase
                 'toChildren.Greenhouse.toChildren.PlantModule.oProc_Plants_CO2GasExchange.fFlowRate';                  %28     Exchange rate CO2; positive: air-phase -> plants-phase
             
             %Time parameters
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.state.emerge_time';         %29     Planting  time offset, culture 1
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.state.emerge_time';         %30     Planting  time offset, culture 2
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.state.internalGeneration';  %31     Culture's internal generation, culture 1
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.state.internalGeneration';  %32     Culture's internal generation, culture 2
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.state.internaltime';        %33     Elapsed time since planting, culture 1
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.state.internaltime';        %34     Elapsed time since planting, culture 2
             
                 'toChildren.Greenhouse.oB5.fFlowRate';                                                                                 %35     CO2 supply flowrate
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).fTemperature';                                                            %36     Temperature Greenhouse air-phase
             %Mostly biomass composition 
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.state.TCB';                 %37     Total crop biomass - 1. Culture - Lettuce
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.state.TCB';                 %38     Total crop biomass - 2. Culture - Sweetpotato
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.state.TEB';                 %39     Total edible biomass - 1. Culture - Lettuce
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.state.TEB';                 %40     Total edible biomass - 2. Culture - Sweetpotato

                 'toChildren.Greenhouse.toChildren.PlantModule.toStores.PlantCultivationStore.aoPhases(3).fMass';                       %41     Inedible biomass phase
                 'toChildren.Greenhouse.toChildren.PlantModule.toStores.PlantCultivationStore.aoPhases(4).fMass';                       %42     Edible biomass phase
                 'toChildren.Greenhouse.toChildren.PlantModule.toStores.PlantCultivationStore.aoPhases(2).afMass(this.oData.oMT.tiN2I.H2O)'; %43    Partial mass H2O in plants-phase
                 'toChildren.Greenhouse.toChildren.PlantModule.aoBranches(4).fFlowRate';                                                %44     Food output PlantModule
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.state.TCB_CGR_test';        %45     Evaluation of total crop biomass 
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.INEDIBLE_CGR_d';            %46     Biomass composition: inedible dry - Lettuce(culture 1)
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.INEDIBLE_CGR_f';            %47     Biomass composition: inedible fluid - Lettuce(culture 1)
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.ED_CGR_d';                  %48     Biomass composition: edible dry - Lettuce(culture 1)
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{1, 1}.ED_CGR_f'                   %49     Biomass composition: edible fluid - Lettuce(culture 1)
             
             %O2 log
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afO2_sum_out(1)'           %50     O2 production; culture 1
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afO2_sum_out(2)'           %51     O2 production; culture 2
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fO2_sum_total'             %52     O2 production; total
             %CO2 log
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afCO2_sum_out(1)'          %53     CO2 consumption; culture 1
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afCO2_sum_out(2)'          %54     CO2 consumption; culture 2
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCO2_sum_total'            %55     CO2 consumption; total
             %H2O Transpiration log
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afH2O_trans_sum_out(1)'    %56     H2O transpiration; culture 1
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afH2O_trans_sum_out(2)'    %57     H2O transpiration; culture 2
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fH2O_trans_sum_total'      %58     H2O transpiration; total
             %H2O Consumption log
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afH2O_consum_sum_out(1)'   %59     H2O consumption; culture 1
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.afH2O_consum_sum_out(2)'   %60     H2O consumption; culture 2
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fH2O_consum_sum_total'     %61     H2O consumption; total
             %Biomass composition
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.INEDIBLE_CGR_d';    %62 Biomass composition: inedible dry - Sweetpotato(culture 2)
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.INEDIBLE_CGR_f';    %63 Biomass composition: inedible fluid - Sweetpotato(culture 2)
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.ED_CGR_d';          %64 Biomass composition: edible dry - Sweetpotato(culture 2)
                 'toChildren.Greenhouse.toChildren.PlantModule.oManip_Create_Biomass.fCCulture.plants{2, 1}.ED_CGR_f'           %65 Biomass composition: edible fluid - Sweetpotato(culture 2)
             
                 'toChildren.Greenhouse.toStores.GH_Unit.aoPhases(1).arPartialMass(this.oData.oMT.tiN2I.CO2)'                   %66 N2 partial Mass Greenhouse air-phase
                    };
            
         

         
         

         
        end
        
        
   %% -Plotting-
        function plot(this)
            close all
           
         %Greenhouse parameters
            %Greenhouse's air-phase pressure
                figure('name', 'Pressure');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 2));
                legend('Greenhouse Air-Phase');
                ylabel('Pressure [Pa]');
                xlabel('Time in [d]');
            %Greenhouse's air-phase mass
                figure('name', 'Mass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 3));
                legend('Greenhouse Air-Phase');
                ylabel('Mass [kg]');
                xlabel('Time in [d]');
            %Greenhouse's air-phase temperature
                figure('name', 'Temperature');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 36));
                legend('Greenhouse Air-Phase');
                ylabel('Temperature [K]');
                xlabel('Time in [d]');
                
            %Greenhouse's air composition partial masses
                figure('name', 'Partial Masses Greenhouse');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [8,11,66,12]));
                legend('O2', 'N2', 'CO2', 'H2O');
                ylabel('Mass (Fraction) [-]');
                xlabel('Time in [d]');
                
            %Greenhouse's and PlantModules's O2 partial mass
                figure('name', 'Partial Mass - O2');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [8,9]));
                legend('Greenhouse Air-Phase', 'PlantModule Air-Phase');
                ylabel('Mass (Fraction) [-]');
                xlabel('Time in [d]');
                
            %Greenhouse's O2 partial mass
                figure('name', 'Partial Mass - O2');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 8));
                legend('Greenhouse Air-Phase');
                ylabel('Mass (Fraction) [-]');
                xlabel('Time in [d]');   
                
            %Greenhouse's and PlantModules's N2 partial mass
                figure('name', 'Partial Mass - N2');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [11,13]));
                legend('Greenhouse Air-Phase', 'PlantModule Air-Phase');
                ylabel('Mass (Fraction) [-]');
                xlabel('Time in [d]');
            
            %Greenhouse's N2 partial mass
                figure('name', 'Partial Mass - N2');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 11));
                legend('Greenhouse Air-Phase');
                ylabel('Mass (Fraction) [-]');
                xlabel('Time in [d]');
            
            %Greenhouse's humidity 
                figure('name', 'Humidity');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 10));
                legend('Greenhouse Air-Phase');
                ylabel('Humidity [-]');
                xlabel('Time in [d]');
            
            %Greenhouse's H2O partial mass
                figure('name', 'Partial Mass - H2O');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 12));
                legend('Greenhouse Air-Phase');
                ylabel('Mass (Fraction) [-]');
                xlabel('Time in [d]');
            
            %CO2 Levels
                figure('name', 'CO2 Partial Pressure');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 18));
                legend('Greenhouse');
                ylabel(' Partial Pressure [-]');
                xlabel('Time in [d]');

                figure('name', 'CO2 Parts Per Million');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 19));
                legend('Greenhouse CO2 Level');
                ylabel('CO2 ppm [mumol/mol]');
                xlabel('Time in [d]');
            
             %Flowrate and activity of CO2 supply conroller
                figure('name', 'Flowrate CO2 Supply');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 35));
                legend('CO2 Buffer');
                ylabel(' [kg/s]');
                xlabel('Time in [d]');
                
                
            %Flowrates -  Greenhouse System <-> Plant Cultivation Subsystem
                figure('name', 'Flow Rates -  Greenhouse Air <-> Plant Cultivation Air');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [23, 24]));
                legend('Input: Greenhouse -> Plant Cultivation', 'Output: Plant Cultivation -> Greenhouse');
                ylabel(' Massflow [kg/s]');
                xlabel('Time in [d]');
                
            %Pressure Compensation Greenhouse Air-Phase
                figure('name', 'Flowrate - Greenhouse <-> Leakage Tank');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 44));
                legend('Greenhouse Leakage Rate');
                ylabel(' Massflow [kg/s]');
                xlabel('Time in [d]');
                
            %Water Tank
                figure('name', 'Water (Supply-)Tank Mass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 20));
                legend('Water Tank');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
                
         %Water Separator
           %Separated water-phase total mass
                figure('name', 'Separated Water Mass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 15));
                legend('Separated Water');
                ylabel('Mass [kg]');
                xlabel('Time in [d]');
          
          %Flowrates from/ till Greenhouse
                figure('name', 'Water Separator/Circulation Flows');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [6, 7]));
                legend('Water Separator Flow In', 'Water Separator Flow Out');
                ylabel('Mass [kg/s]');
                xlabel('Time in [d]');
                
            %Air-phase pressure
                figure('name', 'Pressure');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 17));
                legend('Water Separator Air-Phase');
                ylabel('Pressure [Pa]');
                xlabel('Time in [d]');
                
            %Air-phase total mass
                figure('name', 'Air Phase Mass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 14));
                legend('Water Separator');
                ylabel('Mass [kg]');
                xlabel('Time in [d]');
                
         %Plant Growth and Harvesting
            %Plant Generations
                figure('name', 'Plants Generation');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [31,32]));
                legend('Lettuce', 'Sweetpotato');
                ylabel(' ticks [-]');
                xlabel('Time in [d]');
            
            %Elapsed time since planting
                figure('name', 'Internaltime - Iterative Plant Cycles (Generations)');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [33,34]));
                legend('Lettuce', 'Sweetpotato');
                ylabel('Time in [min] (since planted)');
                xlabel('Time in [d]');
                
            %Harvested Biomass
                figure('name', 'Harvested Edible Biomass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 21));
                legend('Edible Biomass Tank');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');

                figure('name', 'Harvested Inedible Biomass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 22));
                legend('Inedible Biomass Tank');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');

            
            %Calculated Biomass - Comparison
                figure('name', 'Cumulated Plant Growth Values - Till Harvesting');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [37,38,39,40]));
                legend('Total Crop Biomass (TCB) - Lettuce','Total Crop Biomass (TCB) - Sweetpotato', 'Total Edible Biomass (TEB) - Lettuce', 'Total Edible Biomass (TEB) - Sweetpotato');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
                
                %Calculated Biomass - Comparison Lettuce
                figure('name', 'Cumulated Plant Growth Values - Till Harvesting - Lettuce');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [37,39]));
                legend('Total Crop Biomass (TCB) - Lettuce', 'Total Edible Biomass (TEB) - Lettuce');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
                
                %Calculated Biomass - Comparison Sweetpotato
                figure('name', 'Cumulated Plant Growth Values - Till Harvesting - Sweetpotato');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [38,40]));
                legend('Total Crop Biomass (TCB) - Sweetpotato', 'Total Edible Biomass (TEB) - Sweetpotato');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
            
            %For Comparison Cultivation Store Plants-Phase Masses
                figure('name', 'CultivationStore - Total Mass Plants - Water Mass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [25,43]));
                legend('Total Mass Plants-Phase', 'Water Mass');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
                
            %Comparison of Calculated Biomasses - Lettuce; 
                figure('name', 'Total Crop Biomass (TCB) Comparison');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [37, 45]));
                legend('From State Logging', 'From Single Components Evaluation');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
            
            %Total Crop Biomass separated in its components
                %Total Crop Biomass separated in its components - Lettuce
                figure('name', 'TCB Divided Comparison - Lettuce ');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [37, 46, 47, 48, 49]));
                legend('Total Crop Biomass (TCB)', 'Inedible Dry', 'Inedible Fluid', 'Edible Dry', 'Edible Fluid');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
                
                %Total Crop Biomass separated in its components - Sweetpotato
                figure('name', 'TCB Divided Comparison - Sweetpotato ');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [38, 62, 63, 64, 65]));
                legend('Total Crop Biomass (TCB)', 'Inedible Dry', 'Inedible Fluid', 'Edible Dry', 'Edible Fluid');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
                
                
            %Gas Exchange Flowrates
                figure('name', 'Exchange Rates - Plants');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [26, 27, 28]));
                legend('H2O', 'O2', 'CO2');
                ylabel(' Massflow [kg/s]');
                xlabel('Time in [d]');
                            
            %Cumulated total gas exchanges
                %Total Gas Exchange O2
                figure('name', 'O2 Gas Exchange - Plants');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [50, 51, 52]));
                legend('Lettuce', 'Sweetpotato', 'Total');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
            
            %Total Gas Exchange CO2
                figure('name', 'CO2 Gas Exchange - Plants');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [53, 54, 55]));
                legend('Lettuce', 'Sweetpotato', 'Total');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
            
            %H2O Transpired by Plants
                figure('name', 'H2O Transpired by Plants');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [56, 57, 58]));
                legend('Lettuce', 'Sweetpotato', 'Total');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
            
            %H2O Consumed by Plants
                figure('name', 'H2O Consumed by Plants');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, [59, 60, 61]));
                legend('Lettuce', 'Sweetpotato', 'Total');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
            
            %CO2 Excess - due to nightly CO2 production
                figure('name', 'CO2 Excess Mass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 4));
                legend('From Greenhouse Air-Phase');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');

            %O2 Excess - due to no O2 consumption
                figure('name', 'O2 Excess Mass');
                hold on;
                grid minor;
                plot(this.mfLog(:,1)/(24*60*60), this.mfLog(:, 5));
                legend('From Greenhouse Air-Phase');
                ylabel(' Mass [kg]');
                xlabel('Time in [d]');
            
            
            %Time per solver tick
                figure('name', 'Time Per Solver Tick');
                hold on;
                grid minor;
                plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
                legend('Solver');
                ylabel('Time in [s]');
                xlabel('Ticks');
                
                
            %Rearrange Plots    
                tools.arrangeWindows();
            
        end
        
        
    end

end
