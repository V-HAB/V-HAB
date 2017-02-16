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
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Inlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'CDRA CO2 Inlet Partialratio 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', '-', 'CDRA H2O Inlet Partialratio 1');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'CDRA CO2 Inlet Partialratio 2');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', '-', 'CDRA H2O Inlet Partialratio 2');
            
            % CDRA Out
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Outlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'CDRA CO2 Outlet Partialratio 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', '-', 'CDRA H2O Outlet Partialratio 1');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'CDRA CO2 Outlet Partialratio 2');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', '-', 'CDRA H2O Outlet Partialratio 2');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
            
            sTimeUnit = 'h';
            
            csNames = {'Partial Mass CO2 Zeolite5A_1', 'Partial Mass CO2 Zeolite5A_2'};
            sTitle = 'CDRA Absorbed CO2'; 
            yLabel = 'Mass CO_2 in kg';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'CDRA CO2 Inlet Flow', 'CDRA CO2 Outlet Flow'};
            sTitle = 'CDRA CO2 Flowrates'; 
            yLabel = 'FlowRate CO_2 in kg/s';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'CDRA H2O Inlet Flow', 'CDRA H2O Outlet Flow'};
            sTitle = 'CDRA H2O Flowrates'; 
            yLabel = 'FlowRate H_2O in kg/s';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'Condensate Flowrate CHX'};
            sTitle = 'CHX Condensate Flowrate'; 
            yLabel = 'FlowRate H_2O in kg/s';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'Partial Pressure CO2'};
            sTitle = 'Partial Pressure CO2 Habitat'; 
            yLabel = 'Partial Pressure CO_2 in Pa';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'Partial Pressure CO2 in Torr'};
            sTitle = 'Partial Pressure CO2 Habitat Torr'; 
            yLabel = 'Partial Pressure CO_2 in Torr';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'Relative Humidity Cabin'};
            sTitle = 'Relative Humidity Habitat'; 
            yLabel = 'Relative Humidity';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
            
            this.toMonitors.oPlotter.plot();
            
            hCDRA_InletCalc = @(x1,x2,x3,x4)(-(x1 .* x2 + x3 .* x4));
            csLogVariables =  {'CDRA Air Inlet Flow 1','CDRA CO2 Inlet Partialratio 1','CDRA Air Inlet Flow 2','CDRA CO2 Inlet Partialratio 2'};
            sNewLogName = 'CDRA CO2 Inlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_InletCalc, sNewLogName, 'kg/s');
            
            hCDRA_OutletCalc = @(x1,x2,x3,x4)((x1 .* x2 + x3 .* x4));
            csLogVariables =  {'CDRA Air Outlet Flow 1','CDRA CO2 Outlet Partialratio 1','CDRA Air Outlet Flow 2','CDRA CO2 Outlet Partialratio 2'};
            sNewLogName = 'CDRA CO2 Outlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_OutletCalc, sNewLogName, 'kg/s');
            
            csLogVariables =  {'CDRA Air Inlet Flow 1','CDRA H2O Inlet Partialratio 1','CDRA Air Inlet Flow 2','CDRA H2O Inlet Partialratio 2'};
            sNewLogName = 'CDRA H2O Inlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_InletCalc, sNewLogName, 'kg/s');
            
            csLogVariables =  {'CDRA Air Outlet Flow 1','CDRA H2O Outlet Partialratio 1','CDRA Air Outlet Flow 2','CDRA H2O Outlet Partialratio 2'};
            sNewLogName = 'CDRA H2O Outlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_OutletCalc, sNewLogName, 'kg/s');
            
            hPascalToTorr = @(x1)(x1./133.322368);
            csLogVariables =  {'Partial Pressure CO2'};
            sNewLogName = 'Partial Pressure CO2 in Torr';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hPascalToTorr, sNewLogName, 'Torr');
            
            this.toMonitors.oPlotter.plotByName();
            
            return
            
        end
    end
end