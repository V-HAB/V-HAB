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
            
            % general logging parameters, greenhouse system
            oLogger.add('GreenhouseV2', 'flow_props');
            oLogger.add('GreenhouseV2', 'thermal_properties');
            
            % log culture subsystems
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures)
                oLogger.add([this.oSimulationContainer.toChildren.GreenhouseV2.toChildren.(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI})], 'flow_props');
                
                % p2p flowrates
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_GasExchange_CO2_P2P'], 'fFlowRate', 'kg/s', 'CO2 GasExchange');
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_GasExchange_O2_P2P'], 'fFlowRate', 'kg/s',  'O2 GasExchange');
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_GasExchange_H2O_P2P'], 'fFlowRate', 'kg/s', 'H2O GasExchange');
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_BiomassGrowth_P2P'], 'fFlowRate', 'kg/s', 'BiomassGrowth');
                
                % culture atmosphere cycle phase
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1'], 'fPressure', 'Pa', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' Total Pressure']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1'], 'afPP(this.oMT.tiN2I.O2)', 'Pa', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP O2']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1'], 'afPP(this.oMT.tiN2I.CO2)', 'Pa', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP CO2']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1'], 'afPP(this.oMT.tiN2I.N2)', 'Pa', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP N2']);
                
                %% MMEC Rates and according flow rates
                
                % MMEC rates
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fWC', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC WC']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fTR', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC TR']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fOC', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC OC']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fOP', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC OP']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fCO2C', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC CO2C']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fCO2P', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC CO2P']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fNC', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC NC']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfMMECRates.fCGR', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC CGR']);
                
                % flow rates
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfGasExchangeRates.fO2ExchangeRate', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate O2']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfGasExchangeRates.fCO2ExchangeRate', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate CO2']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfGasExchangeRates.fTranspirationRate', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate H2O(g)']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'fWaterConsumptionRate', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate H2O(l)']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'fNutrientConsumptionRate', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate Nutrients']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfBiomassGrowthRates.fGrowthRateEdible', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate Edible']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}], 'tfBiomassGrowthRates.fGrowthRateInedible', 'kg s^-1 m^-2', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate Inedible']);
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
            
            
            %% Define Plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot('Pa', 'Tank Pressures');
            oPlot.definePlot('K',  'Tank Temperatures');
            oPlot.definePlot('kg', 'Tank Masses');
            oPlot.definePlot('kg/s', 'Flow Rates');
        end
        
        function plot(this)
            close all
           
            this.toMonitors.oPlotter.plot();
            
            afTime = this.toMonitors.oLogger.afTime;
            
            % indexing all greenhouse parameters in this loop
            if isa(this.oSimulationContainer.toChildren.GreenhouseV2, 'tutorials.GreenhouseV2.systems.GreenhouseV2')
                for iIndex = 1:length(this.toMonitors.oLogger.tLogValues)
%                     if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Extraction Rate BiomassSplit')
%                         iBiomassSplitRate = iIndex;
%                     end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Extraction Rate ExcessO2')
                        iExcessO2Rate = iIndex;
                    end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Extraction Rate ExcessCO2')
                        iExcessCO2Rate = iIndex;
                    end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'CO2 Concentration')
                        iCO2Concentration = iIndex;
                    end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'O2 Partial Pressure')
                        iO2PP = iIndex;
                    end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'CO2 Partial Pressure')
                        iCO2PP = iIndex;
                    end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'N2 Partial Pressure')
                        iN2PP = iIndex;
                    end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Total Pressure')
                        iTotalPressure = iIndex;
                    end
                end
            end
            
            
            % indexing all culture parameters in this loop
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures)
                if isa(this.oSimulationContainer.toChildren.GreenhouseV2.toChildren.(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}), 'tutorials.GreenhouseV2.components.Culture3Phases')
                    for iJ = 1:length(this.toMonitors.oLogger.tLogValues)
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' Total Pressure'])
                            this.tiCultureParametersIndex(iI).iTotalPressure = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP O2'])
                            this.tiCultureParametersIndex(iI).iPPO2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP CO2'])
                            this.tiCultureParametersIndex(iI).iPPCO2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP N2'])
                            this.tiCultureParametersIndex(iI).iPPN2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Balance Flow'])
                            this.tiCultureParametersIndex(iI).iWNBalanceFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Water Flow'])
                            this.tiCultureParametersIndex(iI).iWNWaterFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Nutrient Flow'])
                            this.tiCultureParametersIndex(iI).iWNNutrientFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE Balance Flow'])
                            this.tiCultureParametersIndex(iI).iGEBalanceFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE O2 Flow'])
                            this.tiCultureParametersIndex(iI).iGEO2Flow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE CO2 Flow'])
                            this.tiCultureParametersIndex(iI).iGECO2Flow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE H2O Flow'])
                            this.tiCultureParametersIndex(iI).iGEH2OFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Balance Flow'])
                            this.tiCultureParametersIndex(iI).iPGBalanceFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Edible Flow'])
                            this.tiCultureParametersIndex(iI).iPGEdibleFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Inedible Flow'])
                            this.tiCultureParametersIndex(iI).iPGInedibleFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC WC'])
                            this.tiCultureParametersIndex(iI).iMMECWC = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC TR'])
                            this.tiCultureParametersIndex(iI).iMMECTR = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC OC'])
                            this.tiCultureParametersIndex(iI).iMMECOC = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC OP'])
                            this.tiCultureParametersIndex(iI).iMMECOP = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC CO2C'])
                            this.tiCultureParametersIndex(iI).iMMECCO2C = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC CO2P'])
                            this.tiCultureParametersIndex(iI).iMMECCO2P = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC NC'])
                            this.tiCultureParametersIndex(iI).iMMECNC = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' MMEC CGR'])
                            this.tiCultureParametersIndex(iI).iMMECCGR = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate O2'])
                            this.tiCultureParametersIndex(iI).iFlowRateO2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate CO2'])
                            this.tiCultureParametersIndex(iI).iFlowRateCO2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate H2O(g)'])
                            this.tiCultureParametersIndex(iI).iFlowRateH2Og = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate H2O(l)'])
                            this.tiCultureParametersIndex(iI).iFlowRateH2Ol = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate Nutrients'])
                            this.tiCultureParametersIndex(iI).iFlowRateNutrients = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate Edible'])
                            this.tiCultureParametersIndex(iI).iFlowRateEdible = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' FlowRate Inedible'])
                            this.tiCultureParametersIndex(iI).iFlowRateInedible = iJ;
                        end
                    end
                end
            end
            
            
            % bring data down to correct size
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures) 
                % atmosphere partial pressure
                this.tmCultureParametersValues(iI).mTotalPressure = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iTotalPressure);
                this.tmCultureParametersValues(iI).mTotalPressure(isnan(this.tmCultureParametersValues(iI).mTotalPressure(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mPPO2 = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iPPO2);
                this.tmCultureParametersValues(iI).mPPO2(isnan(this.tmCultureParametersValues(iI).mPPO2(:,1)), :) = [];       
                    
                this.tmCultureParametersValues(iI).mPPCO2 = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iPPCO2);
                this.tmCultureParametersValues(iI).mPPCO2(isnan(this.tmCultureParametersValues(iI).mPPCO2(:,1)), :) = [];      
                    
                this.tmCultureParametersValues(iI).mPPN2 = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iPPN2);
                this.tmCultureParametersValues(iI).mPPN2(isnan(this.tmCultureParametersValues(iI).mPPN2(:,1)), :) = [];
                
                % manipulator flowrates
                this.tmCultureParametersValues(iI).mWNBalanceFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iWNBalanceFlow);
                this.tmCultureParametersValues(iI).mWNBalanceFlow(isnan(this.tmCultureParametersValues(iI).mWNBalanceFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mWNWaterFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iWNWaterFlow);
                this.tmCultureParametersValues(iI).mWNWaterFlow(isnan(this.tmCultureParametersValues(iI).mWNWaterFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mWNNutrientFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iWNNutrientFlow);
                this.tmCultureParametersValues(iI).mWNNutrientFlow(isnan(this.tmCultureParametersValues(iI).mWNNutrientFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mGEBalanceFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iGEBalanceFlow);
                this.tmCultureParametersValues(iI).mGEBalanceFlow(isnan(this.tmCultureParametersValues(iI).mGEBalanceFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mGEO2Flow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iGEO2Flow);
                this.tmCultureParametersValues(iI).mGEO2Flow(isnan(this.tmCultureParametersValues(iI).mGEO2Flow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mGECO2Flow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iGECO2Flow);
                this.tmCultureParametersValues(iI).mGECO2Flow(isnan(this.tmCultureParametersValues(iI).mGECO2Flow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mGEH2OFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iGEH2OFlow);
                this.tmCultureParametersValues(iI).mGEH2OFlow(isnan(this.tmCultureParametersValues(iI).mGEH2OFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mPGBalanceFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iPGBalanceFlow);
                this.tmCultureParametersValues(iI).mPGBalanceFlow(isnan(this.tmCultureParametersValues(iI).mPGBalanceFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mPGEdibleFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iPGEdibleFlow);
                this.tmCultureParametersValues(iI).mPGEdibleFlow(isnan(this.tmCultureParametersValues(iI).mPGEdibleFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mPGInedibleFlow = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iPGInedibleFlow);
                this.tmCultureParametersValues(iI).mPGInedibleFlow(isnan(this.tmCultureParametersValues(iI).mPGInedibleFlow(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECWC = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECWC);
                this.tmCultureParametersValues(iI).mMMECWC(isnan(this.tmCultureParametersValues(iI).mMMECWC(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECTR = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECTR);
                this.tmCultureParametersValues(iI).mMMECTR(isnan(this.tmCultureParametersValues(iI).mMMECTR(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECOC = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECOC);
                this.tmCultureParametersValues(iI).mMMECOC(isnan(this.tmCultureParametersValues(iI).mMMECOC(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECOP = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECOP);
                this.tmCultureParametersValues(iI).mMMECOP(isnan(this.tmCultureParametersValues(iI).mMMECOP(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECCO2C = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECCO2C);
                this.tmCultureParametersValues(iI).mMMECCO2C(isnan(this.tmCultureParametersValues(iI).mMMECCO2C(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECCO2P = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECCO2P);
                this.tmCultureParametersValues(iI).mMMECCO2P(isnan(this.tmCultureParametersValues(iI).mMMECCO2P(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECNC = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECNC);
                this.tmCultureParametersValues(iI).mMMECNC(isnan(this.tmCultureParametersValues(iI).mMMECNC(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mMMECCGR = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iMMECCGR);
                this.tmCultureParametersValues(iI).mMMECCGR(isnan(this.tmCultureParametersValues(iI).mMMECCGR(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mFlowRateO2 = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iFlowRateO2);
                this.tmCultureParametersValues(iI).mFlowRateO2(isnan(this.tmCultureParametersValues(iI).mFlowRateO2(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mFlowRateCO2 = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iFlowRateCO2);
                this.tmCultureParametersValues(iI).mFlowRateCO2(isnan(this.tmCultureParametersValues(iI).mFlowRateCO2(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mFlowRateH2Og = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iFlowRateH2Og);
                this.tmCultureParametersValues(iI).mFlowRateH2Og(isnan(this.tmCultureParametersValues(iI).mFlowRateH2Og(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mFlowRateH2Ol = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iFlowRateH2Ol);
                this.tmCultureParametersValues(iI).mFlowRateH2Ol(isnan(this.tmCultureParametersValues(iI).mFlowRateH2Ol(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mFlowRateNutrients = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iFlowRateNutrients);
                this.tmCultureParametersValues(iI).mFlowRateNutrients(isnan(this.tmCultureParametersValues(iI).mFlowRateNutrients(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mFlowRateEdible = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iFlowRateEdible);
                this.tmCultureParametersValues(iI).mFlowRateEdible(isnan(this.tmCultureParametersValues(iI).mFlowRateEdible(:,1)), :) = [];
                
                this.tmCultureParametersValues(iI).mFlowRateInedible = this.toMonitors.oLogger.mfLog(:, this.tiCultureParametersIndex(iI).iFlowRateInedible);
                this.tmCultureParametersValues(iI).mFlowRateInedible(isnan(this.tmCultureParametersValues(iI).mFlowRateInedible(:,1)), :) = [];
            end
            
%             mBiomassSplitRate = this.toMonitors.oLogger.mfLog(:, iBiomassSplitRate);
%             mBiomassSplitRate(isnan(mBiomassSplitRate(:,1)), :) = [];
            
            mExcessO2Rate = this.toMonitors.oLogger.mfLog(:, iExcessO2Rate);
            mExcessO2Rate(isnan(mExcessO2Rate(:,1)), :) = [];
            
            mExcessCO2Rate = this.toMonitors.oLogger.mfLog(:, iExcessCO2Rate);
            mExcessCO2Rate(isnan(mExcessCO2Rate(:,1)), :) = [];
            
            mCO2Concentration = this.toMonitors.oLogger.mfLog(:, iCO2Concentration);
            mCO2Concentration(isnan(mCO2Concentration(:,1)), :) = [];
            
            mO2PP = this.toMonitors.oLogger.mfLog(:, iO2PP);
            mO2PP(isnan(mO2PP(:,1)), :) = [];
            
            mCO2PP = this.toMonitors.oLogger.mfLog(:, iCO2PP);
            mCO2PP(isnan(mCO2PP(:,1)), :) = [];
            
            mN2PP = this.toMonitors.oLogger.mfLog(:, iN2PP);
            mN2PP(isnan(mN2PP(:,1)), :) = [];
            
            mTotalPressure = this.toMonitors.oLogger.mfLog(:, iTotalPressure);
            mTotalPressure(isnan(mTotalPressure(:,1)), :) = [];
            
            figure('name', 'P2P Flowrates')
            hold on
            grid minor
            plot(...
                (afTime./86400), mExcessO2Rate, ...
                (afTime./86400), mExcessCO2Rate)
            xlabel('Time in d')
            ylabel('Flowrate in kg/s')
            legend('ExcessO2', 'ExcessCO2')
            
            figure('name', 'CO2 Concentration')
            hold on
            grid minor
            plot(...
                (afTime./86400), mCO2Concentration)
            xlabel('Time in d')
            ylabel('CO2 Concentration in ppm')
            legend('CO2')
            
            figure('name', 'Greenhouse Atmosphere Composition')
            hold on
            grid minor
            plot(...
                (afTime./86400), mTotalPressure, ...
                (afTime./86400), mO2PP, ...
                (afTime./86400), mCO2PP, ...
                (afTime./86400), mN2PP)
            xlabel('Time in d')
            ylabel('Pressure in Pa')
            legend('Total Pressure', 'PP O2', 'PP CO2', 'PP N2')
            
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures)
                
                % culture atmosphere cycle phase compostion
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'Atmosphere Composition'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.tmCultureParametersValues(iI).mTotalPressure, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mPPO2, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mPPCO2, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mPPN2)
                xlabel('time in d')
                ylabel('Pressure in Pa')
                legend('Total Pressure', 'PP O2', 'PP CO2', 'PP N2')
                
                % water + nutrients conversion manipulator flowrates
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'WaterNutrient Conversion'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.tmCultureParametersValues(iI).mWNBalanceFlow, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mWNWaterFlow, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mWNNutrientFlow)
                xlabel('time in d')
                ylabel('Flowrate in kg/s')
                legend('Balance Mass', 'Water', 'Nutrients')
                
                % gas exchange conversion manipulator flowrates
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'GasExchange Conversion'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.tmCultureParametersValues(iI).mGEBalanceFlow, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mGEO2Flow, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mGECO2Flow, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mGEH2OFlow)
                xlabel('time in d')
                ylabel('Flowrate in kg/s')
                legend('Balance Mass', 'O2', 'CO2', 'H2O')
                
                % plant growth conversion manipulator flowrates
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'PlantGrowth Conversion'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.tmCultureParametersValues(iI).mPGBalanceFlow, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mPGEdibleFlow, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mPGInedibleFlow)
                xlabel('time in d')
                ylabel('Flowrate in kg/s')
                legend('Balance Mass', 'Edible Biomass', 'Inedible Biomass')
                
                % culture MMEC rates
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'MMEC Rates'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECWC, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECTR, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECOC, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECOP, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECCO2C, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECCO2P, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECNC, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mMMECCGR)
                xlabel('time in d')
                ylabel('Rates in kg s^-1 m^-2')
                legend('WC', 'TR', 'OC', 'OP', 'CO2C', 'CO2P', 'NC', 'CGR')
                
                % culture flow rates
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'Flow Rates'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.tmCultureParametersValues(iI).mFlowRateO2, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mFlowRateCO2, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mFlowRateH2Og, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mFlowRateH2Ol, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mFlowRateNutrients, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mFlowRateEdible, ...
                    (afTime./86400), this.tmCultureParametersValues(iI).mFlowRateInedible)
                xlabel('time in d')
                ylabel('Flowrates in kg/s')
                legend('O2', 'CO2', 'H2O(g)', 'H2O(l)', 'Nutrients', 'Edible Biomass', 'Inedible Biomass')
            end
        end
    end
end