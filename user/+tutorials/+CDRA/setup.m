classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            warning( 'off', 'all')
            this@simulation.infrastructure('Tutorial_CCAA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            tutorials.CDRA.systems.Example(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 80; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            oLog.add('Example', 'thermal_properties');
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity', '-', 'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2');
            
            oLog.addValue('Example:c:CDRA:s:Filter_13X_1.toProcsP2P.Filter_13X_1_proc', 'fFlowRate', 'P2P 13x kg/s', 'Adsorption Flowrate 13x1');
            oLog.addValue('Example:c:CDRA:s:Filter_13X_1.toProcsP2P.DesorptionProcessor', 'fFlowRate', 'P2P 13x kg/s', 'Desorption Flowrate 13x1');
            
            oLog.addValue('Example:c:CDRA:s:Filter_13X_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.H2O)', 'Adsorbed kg 13x', 'Adsorbed H2O 13x1');
            oLog.addValue('Example:c:CDRA:s:Filter_13X_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'Adsorbed kg 13x ', 'Adsorbed CO2 13x1');
                        
            oLog.addValue('Example:c:CDRA:s:Filter_13X_2.toProcsP2P.Filter_13X_2_proc', 'fFlowRate', 'P2P 13x kg/s', 'Adsorption Flowrate 13x2');
            oLog.addValue('Example:c:CDRA:s:Filter_13X_2.toProcsP2P.DesorptionProcessor', 'fFlowRate', 'P2P 13x kg/s', 'Desorption Flowrate 13x2');
            
            oLog.addValue('Example:c:CDRA:s:Filter_13X_2.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.H2O)', 'Adsorbed kg 13x', 'Adsorbed H2O 13x2');
            oLog.addValue('Example:c:CDRA:s:Filter_13X_2.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'Adsorbed kg 13x', 'Adsorbed CO2 13x2');
            
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_1.toProcsP2P.Filter_Sylobead_1_proc', 'fFlowRate', 'P2P SG kg/s', 'Adsorption Flowrate Sylobead1');
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_1.toProcsP2P.DesorptionProcessor', 'fFlowRate', 'P2P SG kg/s', 'Desorption Flowrate Sylobead1');
            
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.H2O)', 'Adsorbed kg Sylobead', 'Adsorbed H2O Sylobead 1');
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'Adsorbed kg Sylobead', 'Adsorbed CO2 Sylobead 1');
            
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_2.toProcsP2P.Filter_Sylobead_2_proc', 'fFlowRate', 'P2P SG kg/s', 'Adsorption Flowrate Sylobead2');
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_2.toProcsP2P.DesorptionProcessor', 'fFlowRate', 'P2P SG kg/s', 'Desorption Flowrate Sylobead2');
            
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_2.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.H2O)', 'Adsorbed kg Sylobead', 'Adsorbed H2O Sylobead 2');
            oLog.addValue('Example:c:CDRA:s:Filter_Sylobead_2.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'Adsorbed kg Sylobead', 'Adsorbed CO2 Sylobead 2');
            
            oLog.addValue('Example:c:CDRA:s:Filter5A_1.toProcsP2P.Filter_5A_1_proc', 'fFlowRate', 'P2P 5A kg/s', 'Adsorption Flowrate 5A1');
            oLog.addValue('Example:c:CDRA:s:Filter5A_1.toProcsP2P.DesorptionProcessor', 'fFlowRate', 'P2P 5A kg/s', 'Desorption Flowrate 5A1');
            
            oLog.addValue('Example:c:CDRA:s:Filter5A_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.H2O)', 'Adsorbed kg 5A', 'Adsorbed H2O 5A 1');
            oLog.addValue('Example:c:CDRA:s:Filter5A_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'Adsorbed kg 5A', 'Adsorbed CO2 5A 1');
            
            oLog.addValue('Example:c:CDRA:s:Filter5A_2.toProcsP2P.Filter_5A_2_proc', 'fFlowRate', 'P2P 5A kg/s', 'Adsorption Flowrate 5A2');
            oLog.addValue('Example:c:CDRA:s:Filter5A_2.toProcsP2P.DesorptionProcessor', 'fFlowRate', 'P2P 5A kg/s', 'Desorption Flowrate 5A2');
            
            oLog.addValue('Example:c:CDRA:s:Filter5A_2.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.H2O)', 'Adsorbed kg 5A', 'Adsorbed H2O 5A 2');
            oLog.addValue('Example:c:CDRA:s:Filter5A_2.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'Adsorbed kg 5A', 'Adsorbed CO2 5A 2');
            
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX', 'fFlowRate', 'Condensed kg/s', 'CHX Condensate Flow');
            oLog.addValue('Example:s:Cabin.toProcsP2P.CrewHumidityGen', 'fFlowRate', 'Condensed kg/s', 'Crew Humidity Release');
            
            oLog.add('Example:c:CDRA', 'flow_props');
            oLog.add('Example:c:CDRA', 'thermal_properties');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa',  'Tank Pressures');
            oPlot.definePlotAllWithFilter('K',   'Temperatures');
            oPlot.definePlotAllWithFilter('kg',  'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s','Flow Rates');
            oPlot.definePlotAllWithFilter('P2P 13x kg/s','Flow Rates');
            oPlot.definePlotAllWithFilter('Adsorbed kg 13x','Adsorbed Masses 13x');
            oPlot.definePlotAllWithFilter('P2P SG kg/s','Flow Rates');
            oPlot.definePlotAllWithFilter('Adsorbed kg Sylobead','Adsorbed Masses Sylobead');
            oPlot.definePlotAllWithFilter('P2P 5A kg/s','Flow Rates');
            oPlot.definePlotAllWithFilter('Adsorbed kg 5A','Adsorbed Masses 5A');
            oPlot.definePlotAllWithFilter('Condensed kg/s','Condensate Mass Flow');
            
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
          
            this.toMonitors.oPlotter.plot();
            
            for iIndex = 1:length(this.toMonitors.oLogger.tLogValues)
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Relative Humidity Cabin')
                    iHumidityCabin = iIndex;
                end
                
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Partial Pressure CO2')
                    iCO2Cabin = iIndex;
                end
            end
            
            mLogDataHumidityCabin = this.toMonitors.oLogger.mfLog(:,iHumidityCabin);
            mLogDataHumidityCabin(isnan(mLogDataHumidityCabin(:,1)),:)=[];
            mLogDataHumidityCabin = mLogDataHumidityCabin.*100;
            
            mLogDataCO2Cabin = this.toMonitors.oLogger.mfLog(:,iCO2Cabin);
            mLogDataCO2Cabin(isnan(mLogDataCO2Cabin(:,1)),:)=[];
            
            afTime = this.toMonitors.oLogger.afTime;
            
            figure('name', 'Relative Humidity')
            grid on
            hold on
            plot((afTime./3600), mLogDataHumidityCabin)
            xlabel('Time in h')
            ylabel('Rel. Humidity in %')
            
            figure('name', 'Partial Pressure CO2')
            grid on
            hold on
            plot((afTime./3600), mLogDataCO2Cabin)
            xlabel('Time in h')
            ylabel('Partial Pressure CO2 in Pa')
            
        end
        
    end
    
end


