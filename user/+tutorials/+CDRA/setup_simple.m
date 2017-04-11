classdef setup_simple < simulation.infrastructure
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
        function this = setup_simple(ptConfigParams, tSolverParams) % Constructor function
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            warning( 'off', 'all')
            
            this@simulation.infrastructure('Tutorial_CCAA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            tutorials.CDRA.systems.Example_simple(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 50; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            oLog.add('Example:c:CDRA', 'flow_props');
            oLog.add('Example:c:CCAA', 'flow_props');
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity',              '-',    'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)',  'Pa',   'Partial Pressure CO2');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'fTemperature',              'K',    'Temperature Atmosphere');
            
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fTemperature',      'K',    'Temperature CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fPressure',         'Pa',   'Pressure CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX', 'fFlowRate',      'kg/s', 'Condensate Flowrate CHX');
            
            oLog.addValue('Example:c:CDRA:s:Filter5A_1.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO2 Zeolite5A_1');
            oLog.addValue('Example:c:CDRA:s:Filter5A_2.toPhases.FilteredPhase', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO2 Zeolite5A_2');
            
            % CDRA In
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 2');
            
            
            % CDRA Out
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 2');
            
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot('K', 'Tank Temperatures');
            oPlot.definePlot('Pa', 'Tank Pressures');
            oPlot.definePlot('kg', 'Tank Masses');
            oPlot.definePlot('kg/s', 'Flow Rates');
            
            csNames = {'Partial Mass CO2 Zeolite5A_1', 'Partial Mass CO2 Zeolite5A_2'};
            sTitle = 'CDRA Absorbed CO2'; 
            oPlot.definePlot(csNames, sTitle);
            
            csNames = {'CDRA CO2 Inlet Flow 1 + CDRA CO2 Inlet Flow 2', 'CDRA CO2 Outlet Flow 1 + CDRA CO2 Outlet Flow 2'};
            sTitle = 'CDRA CO2 Flowrates'; 
            oPlot.definePlot(csNames, sTitle);
            
            csNames = {'CDRA H2O Inlet Flow 1 + CDRA H2O Inlet Flow 2', 'CDRA H2O Outlet Flow 1 + CDRA H2O Outlet Flow 2'};
            sTitle = 'CDRA H2O Flowrates'; 
            oPlot.definePlot(csNames, sTitle);
            
            csNames = {'Condensate Flowrate CHX'};
            sTitle = 'CHX Condensate Flowrate'; 
            oPlot.definePlot(csNames, sTitle);
            
            csNames = {'Partial Pressure CO2'};
            sTitle = 'Partial Pressure CO2 Habitat'; 
            oPlot.definePlot(csNames, sTitle);
            
            csNames = {'Partial Pressure CO2 / 133.32'};
            sTitle = 'Partial Pressure CO2 Habitat Torr'; 
            oPlot.definePlot(csNames, sTitle);
            
            csNames = {'Relative Humidity Cabin * 100'};
            sTitle = 'Relative Humidity Habitat'; 
            oPlot.definePlot(csNames, sTitle);
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
            
            tParameters.sTimeUnit = 'h';
            
            this.toMonitors.oPlotter.plot(tParameters);
        end
    end
end