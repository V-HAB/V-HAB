classdef setup < simulation.infrastructure
    % setup file for the Greenhouse system
    
    properties
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
                
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_GasExchange_P2P'], 'fExtractionRate', 'kg/s', 'GasExchange');
                oLogger.addValue(['GreenhouseV2:c:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, ':s:', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '.toProcsP2P.', this.oSimulationContainer.toChildren.GreenhouseV2.csCultures{iI}, '_BiomassGrowth_P2P'], 'fExtractionRate', 'kg/s', 'BiomassGrowth');
            end
            
            % P2P flow rates
%             oLogger.addValue('GreenhouseV2:s:BiomassSplit.toProcsP2P.EdibleInedible_Split_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate BiomassSplit');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toProcsP2P.ExcessO2_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate ExcessO2');
            oLogger.addValue('GreenhouseV2:s:Atmosphere.toProcsP2P.ExcessCO2_P2P', 'fExtractionRate', 'kg/s', 'Extraction Rate ExcessCO2');
%             oLogger.addValue('GreenhouseV2:s:WaterSeparator.toProcsP2P.WaterAbsorber_P2P', 'fExtractionRate', 'kg/s', 'WaterAbsorber');
            
            %
            oLogger.addValue('GreenhouseV2', 'fCO2', 'ppm', 'CO2 Concentration');
            
            
            %% Define Plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K',  'Tank Temperatures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
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
                end
            end
            
%             mBiomassSplitRate = this.toMonitors.oLogger.mfLog(:, iBiomassSplitRate);
%             mBiomassSplitRate(isnan(mBiomassSplitRate(:,1)), :) = [];
            
            mExcessO2Rate = this.toMonitors.oLogger.mfLog(:, iExcessO2Rate);
            mExcessO2Rate(isnan(mExcessO2Rate(:,1)), :) = [];
            
            mExcessCO2Rate = this.toMonitors.oLogger.mfLog(:, iExcessCO2Rate);
            mExcessCO2Rate(isnan(mExcessCO2Rate(:,1)), :) = [];
            
            figure('name', 'P2P Flowrates')
            hold on
            grid minor
            plot(...
                (afTime./86400), mExcessO2Rate, ...
                (afTime./86400), mExcessCO2Rate)
            xlabel('Time in d')
            ylabel('Flowrate in kg/s')
            legend('ExcessO2', 'ExcessCO2')
        end
    end
end