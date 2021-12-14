classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Test_Thermal', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.thermal.systems.Example(this.oSimulationContainer, 'Example');
            

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            
            if nargin >= 4 && ~isempty(fSimTime)
                this.fSimTime = fSimTime;
            end
            
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        
        function configureMonitors(this)
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            % Aside from using the shortcut helpers like flow_props you can
            % also specfy the exact value you want to log. For this you
            % first have to find out the path to the value, which you can
            % find by double clicking on the oLastSimObj in the workspace
            % (usually on the right). This will open a window containing
            % all the properties of the oLastSimObj, in it you can find a
            % oSimulationContainer and doubleclick it again. Then navigate
            % toChildren and you will find an Object with the name of your
            % Simulation. The path up to here does not have to be specified
            % but everything from the name of your system onward is
            % required as input for the log path. Simple click through the
            % system to the value you want to log to find out the correct
            % path (it will be displayed in the top of the window). In the
            % definition of the path to the log value you can use these
            % shorthands: 
            % :c: for .toChildren.
            % :s: for .toStores.
            % :p: for .toPhases.
            % :b: for .toBranches.
            % :t: for .toThermalBranches.

            % The log is built like this:
            %
            %              Path to the object containing the log value   Log Value                   Unit   Label of log value (used for legends and to plot the value)   String identifier of the log item (can be used in the plotter to reference this item)
            oLog.addValue('Example:s:Tank_1:p:Tank1Air',                'afPP(this.oMT.tiN2I.CO2)', 'Pa',  'Partial Pressure CO_2 Tank 1',                               'ppCO2_Tank1');
            oLog.addValue('Example:s:Tank_2:p:Tank2Air',                'afPP(this.oMT.tiN2I.CO2)', 'Pa',  'Partial Pressure CO_2 Tank 2', 'ppCO2_Tank2');
            
            % It is also possible to define a calculation as log value and
            % e.g. multiply two values from the object. This can be usefull
            % if you want to log the flowrate of CO2 through a branch that
            % transports air for example.
            oLog.addValue('Example.aoBranches(1).aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'Flowrate of CO2', 'fr_co2');
            
            oLog.addValue('Example:s:Tank_1:p:Tank1Air', 'afMass(this.oMT.tiN2I.CO2)', 'kg');
            oLog.addValue('Example:s:Tank_2:p:Tank2Air', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO_2 Tank 2');
            
            oLog.addValue('Example:s:Tank_1:p:Tank1Air',      'fTemperature', 'K', 'Temperature Air 1');
            oLog.addValue('Example:s:Tank_1:p:FilteredPhase', 'fTemperature', 'K', 'Temperature Solid 1');
            oLog.addValue('Example:s:Tank_2:p:Tank2Air',      'fTemperature', 'K', 'Temperature Air 2');
            oLog.addValue('Example:s:Space:p:VacuumPhase',    'fTemperature', 'K', 'Temperature Space');
            
            oLog.addValue('Example:c:SubSystem:s:Filter:p:FlowPhase',     'fTemperature', 'K', 'Temperature Filter Flow');
            oLog.addValue('Example:c:SubSystem:s:Filter:p:FlowPhase',     'fPressure',    'Pa','Pressure Filter Flow');
            oLog.addValue('Example:c:SubSystem:s:Filter:p:FilteredPhase', 'fTemperature', 'K', 'Temperature Filter Absorbed');
            
            oLog.addValue('Example:s:Tank_1:p:Tank1Air', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 1');
            oLog.addValue('Example:s:Tank_2:p:Tank2Air', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 2');
            
            oLog.addValue('Example:b:Branch',             'fFlowRate', 'kg/s', 'Branch Flow Rate', 'branch_FR');
            oLog.addValue('Example:c:SubSystem:b:Inlet',  'fFlowRate', 'kg/s', 'Subsystem Inlet Flow Rate');
            oLog.addValue('Example:c:SubSystem:b:Outlet', 'fFlowRate', 'kg/s', 'Subsystem Outlet Flow Rate');
            
            
            oLog.addValue('Example:t:Branch',                   'fHeatFlow', 'W', 'Branch Heat Flow');
            oLog.addValue('Example:t:Radiator',                 'fHeatFlow', 'W', 'Radiator Heat Flow');
            oLog.addValue('Example:t:Pipe_Material_Conductor',	'fHeatFlow', 'W', 'Pipe Conductor Heat Flow');
            oLog.addValue('Example:c:SubSystem:t:Inlet',        'fHeatFlow', 'W', 'Subsystem Inlet Heat Flow');
            oLog.addValue('Example:c:SubSystem:t:Outlet',       'fHeatFlow', 'W', 'Subsystem Outlet Heat Flow');
            
            
            oLog.addValue('Example:c:SubSystem:t:filterproc',                   'fHeatFlow', 'W', 'Subsystem Adsorption Mass Heat Flow');
            oLog.addValue('Example:c:SubSystem:t:Pipe_Material_Conductor_In',   'fHeatFlow', 'W', 'Subsystem Conduction Inlet Heat Flow');
            oLog.addValue('Example:c:SubSystem:t:Pipe_Material_Conductor_Out',	'fHeatFlow', 'W', 'Subsystem Conduction Outlet Heat Flow');
            oLog.addValue('Example:c:SubSystem:t:Convective_Branch',            'fHeatFlow', 'W', 'Subsystem Convective Heat Flow');
            
            oLog.addValue('Example:s:Tank_1:p:Tank1Air.oCapacity.toHeatSources.Heater', 'fHeatFlow', 'W', 'Phase 1 Heat Source Heat Flow');
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define plots
            
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions = struct('sTimeUnit','hours');
            coPlots = [];
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Air 1"', '"Temperature Solid 1"', '"Temperature Air 2"', '"Temperature Space"', '"Temperature Filter Flow"', '"Temperature Filter Absorbed"'}, 'Temperatures', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Pressure Phase 1"', '"Pressure Phase 2"', '"Pressure Filter Flow"'}, 'Pressure', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Branch Flow Rate"', '"Subsystem Inlet Flow Rate"', '"Subsystem Outlet Flow Rate"'}, 'Flowrate', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"Branch Heat Flow"', '"Radiator Heat Flow"', '"Pipe Conductor Heat Flow"', '"Subsystem Inlet Heat Flow"',...
                '"Subsystem Outlet Heat Flow"', '"Subsystem Conduction Inlet Heat Flow"', '"Subsystem Conduction Outlet Heat Flow"',...
                '"Subsystem Convective Heat Flow"', '"Phase 1 Heat Source Heat Flow"', '"Subsystem Adsorption Mass Heat Flow"'}, 'Heat Flows', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'Thermal Values and Flowrates');
            
            oPlotter.plot();
        end
        
    end
    
end

