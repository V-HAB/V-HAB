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
            this@simulation.infrastructure('Greenhouse', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Create Root Object - Initializing system 'Greenhouse'
            examples.Greenhouse.systems.Greenhouse(this.oSimulationContainer, 'Greenhouse');
            
            % set simulation time
            this.fSimTime  = 10e6;      % [s]
            
            % if true, use fSimTime for simulation duration, if false use
            % iSimTicks below
            this.bUseTime  = true;      
            
            % set amount of simulation ticks
            this.iSimTicks = 400;       % [ticks]
        end
        
        function configureMonitors(this)
            %% Logging Setup
            oLogger = this.toMonitors.oLogger;
            
            % Find the plant cultures to log
            csCultures = {};
            oGreenhouse = this.oSimulationContainer.toChildren.Greenhouse;
            for iChild = 1:length(this.oSimulationContainer.toChildren.Greenhouse.csChildren)
                % culture object gets assigned using its culture name 
                if isa(oGreenhouse.toChildren.(oGreenhouse.csChildren{iChild}), 'components.matter.PlantModuleV2.PlantCulture')
                    csCultures{length(csCultures)+1} = oGreenhouse.csChildren{iChild};
                end
            end
            
            % log culture subsystems
            for iI = 1:length(csCultures)                
                % Balance Mass
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.Balance'], 'fMass', 'kg', [csCultures{iI}, ' Balance Mass']);
                
                % Plant Mass
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.Plants'], 'fMass', 'kg', [csCultures{iI}, ' Plant Mass']);
                
                % Plant Atmosphere Mass
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toPhases.PlantAtmosphere'], 'fMass', 'kg', [csCultures{iI}, ' Plant Atmosphere Mass']);
                
                % p2p flowrates
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, ':s:Plant_Culture.toProcsP2P.BiomassGrowth_P2P'], 'fFlowRate', 'kg/s', [csCultures{iI}, ' BiomassGrowth']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2) * -1', 'kg/s', [csCultures{iI}, ' CO2 In Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)  * -1', 'kg/s', [csCultures{iI},  ' O2 In Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O) * -1', 'kg/s', [csCultures{iI}, ' H2O In Flow']);
                
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', [csCultures{iI}, ' CO2 Out Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)', 'kg/s', [csCultures{iI},  ' O2 Out Flow']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}, '.toBranches.Atmosphere_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', [csCultures{iI}, ' H2O Out Flow']);
                
                oLogger.addVirtualValue(['"', csCultures{iI}, ' CO2 In Flow" - "', csCultures{iI}, ' CO2 Out Flow"'], 'kg/s', [csCultures{iI}, ' Atmosphere CO_2 Flow Rate']);
                oLogger.addVirtualValue(['"', csCultures{iI}, ' O2 In Flow" - "', csCultures{iI}, ' O2 Out Flow"'], 'kg/s',   [csCultures{iI}, ' Atmosphere O_2 Flow Rate']);
                oLogger.addVirtualValue(['"', csCultures{iI}, ' H2O In Flow" - "', csCultures{iI}, ' H2O Out Flow"'], 'kg/s', [csCultures{iI}, ' Atmosphere H_2O Flow Rate']);
                    
                %% MMEC Rates and according flow rates
                
                % MMEC rates
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fWC     * this.txInput.fGrowthArea', 'kg/s)', [csCultures{iI}, ' MMEC WC']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fTR     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC TR']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fOC     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC OC']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fOP     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC OP']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fCO2C   * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC CO2C']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fCO2P   * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC CO2P']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fNC     * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC NC']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfMMECRates.fCGR    * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' MMEC CGR']);
                
                % flow rates
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfGasExchangeRates.fO2ExchangeRate       * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' FlowRate O2']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfGasExchangeRates.fCO2ExchangeRate      * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' FlowRate CO2']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfGasExchangeRates.fTranspirationRate    * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' FlowRate H2O']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.fNutrientConsumptionRate                 * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' FlowRate Nutrients']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfBiomassGrowthRates.fGrowthRateEdible   * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' FlowRate Edible']);
                oLogger.addValue(['Greenhouse:c:', csCultures{iI}], 'this.tfBiomassGrowthRates.fGrowthRateInedible * this.txInput.fGrowthArea', 'kg/s', [csCultures{iI}, ' FlowRate Inedible']);
                
                
            end
            
            % P2P flow rates
%             oLogger.addValue('Greenhouse:s:BiomassSplit.toProcsP2P.EdibleInedible_Split_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate BiomassSplit');
            oLogger.addValue('Greenhouse:s:Atmosphere.toProcsP2P.ExcessO2_P2P', 'fFlowRate', 'kg/s', 'Extraction Rate ExcessO2');
            oLogger.addValue('Greenhouse:s:Atmosphere.toProcsP2P.ExcessCO2_P2P', 'fFlowRate', 'kg/s', 'Extraction Rate ExcessCO2');
%             oLogger.addValue('Greenhouse:s:WaterSeparator.toProcsP2P.WaterAbsorber_P2P', 'fExtractionRate', 'kg/s', 'WaterAbsorber');
            
            %
            oLogger.addValue('Greenhouse', 'fCO2', 'ppm', 'CO2 Concentration');
            
            % greenhouse atmosphere composition
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'fPressure', 'Pa', 'Total Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.O2)', 'Pa', 'O2 Partial Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'CO2 Partial Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.N2)', 'Pa', 'N2 Partial Pressure');
            oLogger.addValue('Greenhouse:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'rRelHumidity', '-', 'Humidity');
            
            
        end
        
        function plot(this)
            
            %% Define Plots
            
            close all
           
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions.sTimeUnit = 'days';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            
            % Find the plant cultures to log
            csCultures = {};
            oGreenhouse = this.oSimulationContainer.toChildren.Greenhouse;
            for iChild = 1:length(this.oSimulationContainer.toChildren.Greenhouse.csChildren)
                % culture object gets assigned using its culture name 
                if isa(oGreenhouse.toChildren.(oGreenhouse.csChildren{iChild}), 'components.matter.PlantModuleV2.PlantCulture')
                    csCultures{length(csCultures)+1} = oGreenhouse.csChildren{iChild};
                end
            end
            
            cBalanceNames = cell(1,length(csCultures));
            cPlantNames = cell(1,length(csCultures));
            coPlots_P2P = cell(1,length(csCultures));
            coPlots_PlantFlowRates = cell(1,length(csCultures));
            
            for iCulture = 1:length(csCultures)
                cNames = {['"', csCultures{iCulture}, ' BiomassGrowth"'],...
                          ['"', csCultures{iCulture}, ' Atmosphere CO_2 Flow Rate"'],...
                          ['"', csCultures{iCulture}, ' Atmosphere O_2 Flow Rate"'],...
                          ['"', csCultures{iCulture}, ' Atmosphere H_2O Flow Rate"']};
                 
                coPlots_P2P{iCulture} = oPlotter.definePlot(cNames, ['P2P Flow Rates ', csCultures{iCulture}], tPlotOptions);
                cNames = {['"', csCultures{iCulture}, ' FlowRate O2"'], ['"', csCultures{iCulture}, ' FlowRate CO2"'], ['"', csCultures{iCulture}, ' FlowRate H2O"'],...
                          ['"', csCultures{iCulture}, ' FlowRate Nutrients"'], ['"', csCultures{iCulture}, ' FlowRate Edible"'], ['"', csCultures{iCulture}, ' FlowRate Inedible"']};
                
                coPlots_PlantFlowRates{iCulture} = oPlotter.definePlot(cNames,      ['Plant Module Flow Rates ', csCultures{iCulture}], tPlotOptions);

                
                cBalanceNames{iCulture}   = ['"', csCultures{iCulture}, ' Balance Mass"'];
                cPlantNames{iCulture}     = ['"', csCultures{iCulture}, ' Plant Mass"'];
            end
           
            oPlotter.defineFigure({coPlots_P2P{:}; coPlots_PlantFlowRates{:}}, 'Plant Module Flow Rates ', tFigureOptions);

            coPlots{1,1} = oPlotter.definePlot(cBalanceNames, 'Balance Mass in Cultures', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(cPlantNames,   'Plant Mass in Cultures', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Total Pressure"', '"N2 Partial Pressure"', '"O2 Partial Pressure"', '"CO2 Partial Pressure"', '"CO2 Concentration"'},'Atmosphere Pressures');
            coPlots{2,2} = oPlotter.definePlot({'"Humidity"'},'Humidity');
            oPlotter.defineFigure(coPlots,  'Masses, CO2 Concentration, Humidity', tFigureOptions);
            
             oPlotter.plot();
        end
    end
end