classdef setup < simulation.infrastructure
    % setup file for the Greenhouse system
    
    properties
        tmCultureParametersValues = struct();
        tiCultureParametersIndex = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % call superconstructor (with possible altered monitor configs)
            this@simulation.infrastructure('GreenhouseV2', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            warning('off', 'all');
            
            % Create Root Object - Initializing system 'Greenhouse'
            tutorials.GreenhouseV2.systems.GreenhouseV2(this.oSimulationContainer, 'GreenhouseV2');
            
            % set simulation time
            this.fSimTime  = 20e6;      % [s]
            
            % if true, use fSimTime for simulation duration, if false use
            % iSimTicks below
            this.bUseTime  = true;      
            
            % set amount of simulation ticks
            this.iSimTicks = 400;       % [ticks]
        end
        
        function configureMonitors(this)
            %% Logging Setup
            oLogger = this.toMonitors.oLogger;
            
            oLogger.add('GreenhouseV2', 'flow_props');
            
            % Find the plant cultures to log
            csCultures = {};
            oGreenhouseV2 = this.oSimulationContainer.toChildren.GreenhouseV2;
            for iChild = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csChildren)
                % culture object gets assigned using its culture name 
                if isa(oGreenhouseV2.toChildren.(oGreenhouseV2.csChildren{iChild}), 'components.PlantModuleV2.PlantCulture')
                    csCultures{length(csCultures)+1} = oGreenhouseV2.csChildren{iChild};
                end
            end
            
            % log culture subsystems
            for iI = 1:length(csCultures)                
                % Balance Mass
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.Balance'], 'fMass', 'kg', [csCultures{iI}, ' Balance Mass']);
                
                % Plant Mass
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.Plants'], 'fMass', 'kg', [csCultures{iI}, ' Plant Mass']);
                
                % Plant Atmosphere Mass
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.PlantAtmosphere'], 'fMass', 'kg', [csCultures{iI}, ' Plant Atmosphere Mass']);
                
                % p2p flowrates
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, ':s:Plant_Culture.toProcsP2P.BiomassGrowth_P2P'], 'fFlowRate', 'kg/s', [csCultures{iI}, ' BiomassGrowth']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', [csCultures{iI}, ' CO2 In Flow']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)', 'kg/s', [csCultures{iI},  ' O2 In Flow']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', [csCultures{iI}, ' H2O In Flow']);
                
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', [csCultures{iI}, ' CO2 Out Flow']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)', 'kg/s', [csCultures{iI},  ' O2 Out Flow']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', [csCultures{iI}, ' H2O Out Flow']);
                
                %% MMEC Rates and according flow rates
                
                % MMEC rates
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fWC', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC WC']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fTR', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC TR']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fOC', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC OC']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fOP', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC OP']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fCO2C', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC CO2C']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fCO2P', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC CO2P']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fNC', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC NC']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfMMECRates.fCGR', 'kg s^-1 m^-2', [csCultures{iI}, ' MMEC CGR']);
                
                % flow rates
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfGasExchangeRates.fO2ExchangeRate', 'kg s^-1 m^-2', [csCultures{iI}, ' FlowRate O2']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfGasExchangeRates.fCO2ExchangeRate', 'kg s^-1 m^-2', [csCultures{iI}, ' FlowRate CO2']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfGasExchangeRates.fTranspirationRate', 'kg s^-1 m^-2', [csCultures{iI}, ' FlowRate H2O']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'fNutrientConsumptionRate', 'kg s^-1 m^-2', [csCultures{iI}, ' FlowRate Nutrients']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfBiomassGrowthRates.fGrowthRateEdible', 'kg s^-1 m^-2', [csCultures{iI}, ' FlowRate Edible']);
                oLogger.addValue(['GreenhouseV2:c:', csCultures{iI}], 'tfBiomassGrowthRates.fGrowthRateInedible', 'kg s^-1 m^-2', [csCultures{iI}, ' FlowRate Inedible']);
                
            end
            
            % P2P flow rates
%             oLogger.addValue('GreenhouseV2:s:BiomassSplit.toProcsP2P.EdibleInedible_Split_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate BiomassSplit');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toProcsP2P.ExcessO2_P2P', 'fFlowRate', 'kg/s', 'Extraction Rate ExcessO2');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toProcsP2P.ExcessCO2_P2P', 'fFlowRate', 'kg/s', 'Extraction Rate ExcessCO2');
%             oLogger.addValue('GreenhouseV2:s:WaterSeparator.toProcsP2P.WaterAbsorber_P2P', 'fExtractionRate', 'kg/s', 'WaterAbsorber');
            
            %
            oLogger.addValue('GreenhouseV2', 'fCO2', 'ppm', 'CO2 Concentration');
            
            % greenhouse atmosphere composition
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'fPressure', 'Pa', 'Total Pressure');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.O2)', 'Pa', 'O2 Partial Pressure');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'CO2 Partial Pressure');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.N2)', 'Pa', 'N2 Partial Pressure');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'rRelHumidity', '-', 'Humidity');
            
            
            %% Define Plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
%             oPlot.definePlot('Pa', 'Tank Pressures');
%             oPlot.definePlot('K',  'Tank Temperatures');
%             oPlot.definePlot('kg', 'Tank Masses');
%             oPlot.definePlot('kg/s', 'Flow Rates');
            
            % or you can specify the labels you want to plot
            cNames = {'Partial Pressure CO_2 Tank 1', 'Partial Pressure CO_2 Tank 2'};
            sTitle = 'Partial Pressure CO2';
%             oPlot.definePlot(cNames, sTitle);
%             
%             cBalanceNames = cell(1,length(csCultures));
%             cPlantNames = cell(1,length(csCultures));
%             for iI = 1:length(csCultures)
%                 cNames = {[csCultures{iI}, ' BiomassGrowth'],...
%                           ['- 1 * ',csCultures{iI}, ' CO2 In Flow - ',csCultures{iI}, ' CO2 Out Flow'],...
%                           ['- 1 * ',csCultures{iI}, ' O2 In Flow - ',csCultures{iI}, ' O2 Out Flow'],...
%                           ['- 1 * ',csCultures{iI}, ' H2O In Flow - ',csCultures{iI}, ' H2O Out Flow']};
%                 
%                 oPlot.definePlot(cNames, ['P2P Flow Rates ', csCultures{iI}]);
%                 
%                 
%                 cNames = {[csCultures{iI}, ' FlowRate O2'], [csCultures{iI}, ' FlowRate CO2'], [csCultures{iI}, ' FlowRate H2O'],...
%                           [csCultures{iI}, ' FlowRate Nutrients'], [csCultures{iI}, ' FlowRate Edible'], [csCultures{iI}, ' FlowRate Inedible']};
%                 
%                 oPlot.definePlot(cNames, ['Plant Module Flow Rates ', csCultures{iI}]);
%                 
%                 
%                 cBalanceNames{iI} = [csCultures{iI}, ' Balance Mass'];
%                 cPlantNames{iI} = [csCultures{iI}, ' Plant Mass'];
%             end
%             
%             oPlot.definePlot(cBalanceNames, 'Balance Mass in Cultures');
%             oPlot.definePlot(cPlantNames,   'Plant Mass in Cultures');
%             
%             oPlot.definePlot({'CO2 Concentration'},'CO2 Concentration');
%             
%             oPlot.definePlot({'Humidity'},'Humidity');
%             
%             oPlot.definePlot({'Total Pressure', 'N2 Partial Pressure', 'O2 Partial Pressure', 'CO2 Partial Pressure'},'Atmosphere Pressures');
        end
        
        function plot(this)
            close all
           
            tParameters.sTimeUnit = 'd';
            
            this.toMonitors.oPlotter.plot(tParameters);
            
        end
    end
end