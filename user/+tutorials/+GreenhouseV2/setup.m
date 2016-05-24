classdef setup < simulation.infrastructure
    % setup file for the Greenhouse system
    
    properties
        CultureAtmospherePP = struct();
        CultureAtmosphereIndex = struct();
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
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_GasExchange_P2P'], 'fExtractionRate', 'kg/s', 'GasExchange');
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_BiomassGrowth_P2P'], 'fExtractionRate', 'kg/s', 'BiomassGrowth');
                
                % manipulator flowrates
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Balance.toManips.substance'], 'fBalanceFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Balance Flow']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Balance.toManips.substance'], 'fWaterFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Water Flow']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Balance.toManips.substance'], 'fNutrientFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Nutrient Flow']);
                
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1.toManips.substance'], 'fBalanceFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE Balance Flow']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1.toManips.substance'], 'fO2Flow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE O2 Flow']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1.toManips.substance'], 'fCO2Flow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE CO2 Flow']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1.toManips.substance'], 'fH2OFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE H2O Flow']);
                
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Plants.toManips.substance'], 'fBalanceFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Balance Flow']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Plants.toManips.substance'], 'fEdibleFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Edible Flow']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Plants.toManips.substance'], 'fInedibleFlow', 'kg/s', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Inedible Flow']);
                
                % culture atmosphere cycle phase
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1'], 'afPP(this.oMT.tiN2I.O2)', 'Pa', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP O2']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1'], 'afPP(this.oMT.tiN2I.CO2)', 'Pa', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP CO2']);
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toPhases.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_Phase_1'], 'afPP(this.oMT.tiN2I.N2)', 'Pa', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP N2']);
            end
            
            % P2P flow rates
%             oLogger.addValue('GreenhouseV2:s:BiomassSplit.toProcsP2P.EdibleInedible_Split_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate BiomassSplit');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toProcsP2P.ExcessO2_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate ExcessO2');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toProcsP2P.ExcessCO2_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate ExcessCO2');
%             oLogger.addValue('GreenhouseV2:s:WaterSeparator.toProcsP2P.WaterAbsorber_P2P', 'fExtractionRate', 'kg/s', 'WaterAbsorber');
            
            %
            oLogger.addValue('GreenhouseV2', 'fCO2', 'ppm', 'CO2 Concentration');
            
            % greenhouse atmosphere composition
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.O2)', 'Pa', 'O2 Partial Pressure');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'CO2 Partial Pressure');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.N2)', 'Pa', 'N2 Partial Pressure');
            
            
            %% Define Plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K',  'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
        end
        
        function plot(this)
            close all
           
            this.toMonitors.oPlotter.plot();
            
            afTime = this.toMonitors.oLogger.afTime;
            
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
                end
            end
            
            
            
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures)
                if isa(this.oSimulationContainer.toChildren.GreenhouseV2.toChildren.(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}), 'tutorials.GreenhouseV2.components.Culture3Phases')
                    for iJ = 1:length(this.toMonitors.oLogger.tLogValues)
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP O2'])
                            this.CultureAtmosphereIndex(iI).iPPO2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP CO2'])
                            this.CultureAtmosphereIndex(iI).iPPCO2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PP N2'])
                            this.CultureAtmosphereIndex(iI).iPPN2 = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Balance Flow'])
                            this.CultureAtmosphereIndex(iI).iWNBalanceFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Water Flow'])
                            this.CultureAtmosphereIndex(iI).iWNWaterFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' WN Nutrient Flow'])
                            this.CultureAtmosphereIndex(iI).iWNNutrientFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE Balance Flow'])
                            this.CultureAtmosphereIndex(iI).iGEBalanceFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE O2 Flow'])
                            this.CultureAtmosphereIndex(iI).iGEO2Flow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE CO2 Flow'])
                            this.CultureAtmosphereIndex(iI).iGECO2Flow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' GE H2O Flow'])
                            this.CultureAtmosphereIndex(iI).iGEH2OFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Balance Flow'])
                            this.CultureAtmosphereIndex(iI).iPGBalanceFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Edible Flow'])
                            this.CultureAtmosphereIndex(iI).iPGEdibleFlow = iJ;
                        end
                        
                        if strcmp(this.toMonitors.oLogger.tLogValues(iJ).sLabel, [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ' PG Inedible Flow'])
                            this.CultureAtmosphereIndex(iI).iPGInedibleFlow = iJ;
                        end
                    end
                end
            end
            
            
            
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures) 
                % atmosphere partial pressure
                this.CultureAtmospherePP(iI).mPPO2 = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iPPO2);
                this.CultureAtmospherePP(iI).mPPO2(isnan(this.CultureAtmospherePP(iI).mPPO2(:,1)), :) = [];       
                    
                this.CultureAtmospherePP(iI).mPPCO2 = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iPPCO2);
                this.CultureAtmospherePP(iI).mPPCO2(isnan(this.CultureAtmospherePP(iI).mPPCO2(:,1)), :) = [];      
                    
                this.CultureAtmospherePP(iI).mPPN2 = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iPPN2);
                this.CultureAtmospherePP(iI).mPPN2(isnan(this.CultureAtmospherePP(iI).mPPN2(:,1)), :) = [];
                
                % manipulator flowrates
                this.CultureAtmospherePP(iI).mWNBalanceFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iWNBalanceFlow);
                this.CultureAtmospherePP(iI).mWNBalanceFlow(isnan(this.CultureAtmospherePP(iI).mWNBalanceFlow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mWNWaterFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iWNWaterFlow);
                this.CultureAtmospherePP(iI).mWNWaterFlow(isnan(this.CultureAtmospherePP(iI).mWNWaterFlow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mWNNutrientFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iWNNutrientFlow);
                this.CultureAtmospherePP(iI).mWNNutrientFlow(isnan(this.CultureAtmospherePP(iI).mWNNutrientFlow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mGEBalanceFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iGEBalanceFlow);
                this.CultureAtmospherePP(iI).mGEBalanceFlow(isnan(this.CultureAtmospherePP(iI).mGEBalanceFlow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mGEO2Flow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iGEO2Flow);
                this.CultureAtmospherePP(iI).mGEO2Flow(isnan(this.CultureAtmospherePP(iI).mGEO2Flow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mGECO2Flow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iGECO2Flow);
                this.CultureAtmospherePP(iI).mGECO2Flow(isnan(this.CultureAtmospherePP(iI).mGECO2Flow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mGEH2OFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iGEH2OFlow);
                this.CultureAtmospherePP(iI).mGEH2OFlow(isnan(this.CultureAtmospherePP(iI).mGEH2OFlow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mPGBalanceFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iPGBalanceFlow);
                this.CultureAtmospherePP(iI).mPGBalanceFlow(isnan(this.CultureAtmospherePP(iI).mPGBalanceFlow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mPGEdibleFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iPGEdibleFlow);
                this.CultureAtmospherePP(iI).mPGEdibleFlow(isnan(this.CultureAtmospherePP(iI).mPGEdibleFlow(:,1)), :) = [];
                
                this.CultureAtmospherePP(iI).mPGInedibleFlow = this.toMonitors.oLogger.mfLog(:, this.CultureAtmosphereIndex(iI).iPGInedibleFlow);
                this.CultureAtmospherePP(iI).mPGInedibleFlow(isnan(this.CultureAtmospherePP(iI).mPGInedibleFlow(:,1)), :) = [];
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
                (afTime./86400), mO2PP, ...
                (afTime./86400), mCO2PP, ...
                (afTime./86400), mN2PP)
            xlabel('Time in d')
            ylabel('Pressure in Pa')
            legend('PP O2', 'PP CO2', 'PP N2')
            
            for iI = 1:length(this.oSimulationContainer.toChildren.GreenhouseV2.csCultures)
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'Atmosphere Composition'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.CultureAtmospherePP(iI).mPPO2, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mPPCO2, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mPPN2)
                xlabel('time in d')
                ylabel('Pressure in Pa')
                legend('PP O2', 'PP CO2', 'PP N2')
                
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'WaterNutrient Conversion'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.CultureAtmospherePP(iI).mWNBalanceFlow, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mWNWaterFlow, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mWNNutrientFlow)
                xlabel('time in d')
                ylabel('Flowrate in kg/s')
                legend('Balance Mass', 'Water', 'Nutrients')
                
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'GasExchange Conversion'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.CultureAtmospherePP(iI).mGEBalanceFlow, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mGEO2Flow, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mGECO2Flow, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mGEH2OFlow)
                xlabel('time in d')
                ylabel('Flowrate in kg/s')
                legend('Balance Mass', 'O2', 'CO2', 'H2O')
                
                figure('name', [this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, 'PlantGrowth Conversion'])
                hold on
                grid minor
                plot(...
                    (afTime./86400), this.CultureAtmospherePP(iI).mPGBalanceFlow, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mPGEdibleFlow, ...
                    (afTime./86400), this.CultureAtmospherePP(iI).mPGInedibleFlow)
                xlabel('time in d')
                ylabel('Flowrate in kg/s')
                legend('Balance Mass', 'Edible Biomass', 'Inedible Biomass')
            end
        end
    end
end