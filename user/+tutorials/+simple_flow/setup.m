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
        tiLogIndexes = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, fSimTime) % Constructor function
            
            % vhab.exec always passes in ptConfigParams, tSolverParams
            % If not provided, set to empty containers.Map/struct
            % Can be passed to vhab.exec:
            %
            % ptCfgParams = containers.Map();
            % ptCfgParams('Tutorial_Simple_Flow/Example') = struct('fPipeLength', 7);
            % vhab.exec('tutorials.simple_flow.setup', ptCfgParams);
            
            
            % By Path - will overwrite (by definition) CTOR value, even 
            % though the CTOR value is set afterwards!
            %%%ptConfigParams('Tutorial_Simple_Flow/Example') = struct('fPipeLength', 7);
            
            
            % By constructor
            %%%ptConfigParams('tutorials.simple_flow.systems.Example') = struct('fPipeLength', 5, 'fPressureDifference', 2);
            
            
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            %%%ttMonitorConfig.oConsoleOutput = struct('cParams', {{ 50 5 }});
            
            %tSolverParams.rUpdateFrequency = 0.1;
            %tSolverParams.rHighestMaxChangeDecrease = 100;
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Simple_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            oSys = tutorials.simple_flow.systems.Example(this.oSimulationContainer, 'Example');
            
            % This is an alternative to providing the ttMonitorConfig above
            %this.toMonitors.oConsoleOutput.setReportingInterval(10, 1);
            
            
            
            
            
            %solver.thermal.lumpedparameter(oSys);
            
            

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 1; % In seconds
            
            if nargin >= 3 && ~isempty(fSimTime)
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
%             this.toMonitors.oConsoleOutput.setLogOn();
%             this.toMonitors.oConsoleOutput.setLevel(5);
            
            oLog.add('Example', 'flow_props');
            
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
            %   - :s: = toStores
            %   - :c: = toChildren
            
            this.tiLogIndexes.iTempIdx1 = oLog.addValue('Example.toProcsF2F.Pipe1.aoFlows(1)', 'fTemperature', 'K', 'Flow Temperature - Left', 'flow_temp_left');
            this.tiLogIndexes.iTempIdx2 = oLog.addValue('Example.toProcsF2F.Pipe1.aoFlows(2)', 'fTemperature', 'K', 'Flow Temperature - Right', 'flow_temp_right');
            
            
            % The log is built like this:
            %
            %               Path to the object containing the log value     Log Value                       Unit    Label of log value (used for legends and to plot the value) 
            oLog.addValue('Example:s:Tank_1.aoPhases(1)',                   'afPP(this.oMT.tiN2I.CO2)',     'Pa',   'Partial Pressure CO_2 Tank 1', 'ppCO2_Tank1');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)',                   'afPP(this.oMT.tiN2I.CO2)',     'Pa',   'Partial Pressure CO_2 Tank 2', 'ppCO2_Tank2');
            
            % it is also possible to define a calculation as log value and
            % e.g. multiply two values from the object.
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'this.fMass * this.fMassToPressure', 'kg', 'Pressure Tank 1');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'this.fMass * this.fMassToPressure', 'kg', 'Pressure Tank 2');
            % This can be usefull if you want to log the flowrate of CO2
            % through a branch that transports air for example            
            oLog.addValue('Example.aoBranches(1).aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'Flowrate of CO2', 'fr_co2');
               
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'afMass(this.oMT.tiN2I.CO2)', 'kg');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO_2 Tank 2');
            
            oLog.addValue('Example.toBranches.Branch1', 'fFlowRate', 'kg/s', 'Branch Flow Rate', 'branch_FR');
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'fPressure', 'Pa', 'Tank 1 Pressure');
            
            this.tiLogIndexes.iIndex_1 = oLog.addVirtualValue('fr_co2 * 1000', 'g/s', 'CO_2 Flowrate', 'co2_fr_grams');
            this.tiLogIndexes.iIndex_2 = oLog.addVirtualValue('flow_temp_left - 273.15', '°C', 'Temperature Left in Celsius');
            this.tiLogIndexes.iIndex_3 = oLog.addVirtualValue('mod(flow_temp_right .^ 2, 10) ./ "Partial Mass CO_2 Tank 2"', '-', 'Nonsense');
                                                
        end
        
        function plot(this) % Plotting the results
            
            %% Define plots
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            cxPlotValues1 = { '"CO_2 Flowrate"', this.tiLogIndexes.iIndex_2, 'Nonsense' };
            csPlotValues2 = { '"Partial Pressure CO_2 Tank 1"', '"Partial Pressure CO_2 Tank 2"'};
            csPlotValues3 = { 'flow_temp_left', 'flow_temp_right' };
            
            %TODO Implement getByTitles() and getByFilter() in logger_basic
            %cPlotValues2 = oLog.getByTitles({ 'Titel 1', 'Titel 2' });
            %cPlotValues3 = oLog.getByFilter('My/Sys/Path/*', struct('sUnit', 'kg'));
            
            % tPlotOptions has field names that correspond to the
            % properties of axes objects in MATLAB. The values given here
            % are directly set on the axes object once it is created. To
            % adhere to the V-HAB variable naming convention, the field
            % names can still include the prefixes to signal the data type,
            % for example 'csNames'. The lower case letters at the
            % beginning of the string will then be stripped by the define
            % plot method.
            %
            % There are a few additional fields that tPlotOptions can have
            % that do not correspond to the properties of the axes object.
            % One field can contain another struct called tLineOptions.
            % This struct can contain settings for the individual line
            % objects of the plot, like markers, line styles and colors.
            % Again, the field names must have the same names as the
            % properties of the line objects. If there are multiple lines
            % in a plot, the values in the struct must be contained in
            % cells with the values in the same order as the lines. If no
            % information is given here, the MATLAB default values are
            % used. 
            %
            % With the sTimeUnit field the user can determine the unit of
            % time for of each plot. The default is seconds, but minutes,
            % hours, days, weeks, months and years are also possible. The
            % sTimeScale field is a string and can contain exactly these
            % words.
            %
            % If the user chooses to have two y axes, we need to provide an
            % opportunity to customize that as well. For this the
            % tRightYAxesOptions field exists. It can have the same entries
            % as the tPlotOptions struct, so field names that correspond to
            % the properties of axes object. 
            % 
            % The bLegend field determines if the legend of the axes is
            % visible or not. The default is visible. 
            
            %tPlotOptions = struct('csUnitOverride', {{ 'all left' }});
            tPlotOptions = struct('csUnitOverride', {{ {'°C'}, {'g/s','-'} }});
            tPlotOptions.tLineOptions.('fr_co2').csColor = 'g';
            tPlotOptions.tLineOptions.('Nonsense').csColor = 'y';
            tPlotOptions.bLegend = false;
            coPlots{1,1} = oPlotter.definePlot(cxPlotValues1, 'Bullshit', tPlotOptions);
            
            tPlotOptions.tLineOptions.('ppCO2_Tank1').csColor = 'g';
            tPlotOptions.tLineOptions.('ppCO2_Tank2').csColor = 'y';
            coPlots{1,2} = oPlotter.definePlot(csPlotValues2, 'CO_2 Partial Pressures', tPlotOptions);
            
            tPlotOptions = struct('sTimeUnit','hours');
            coPlots{2,1} = oPlotter.definePlot(csPlotValues3, 'Temperatures', tPlotOptions);
            
            
            % tFigureOptions includes turing on or off the plottools (off
            % by default), including or excluding the time plot (off by
            % default). Otherwise it can contain any fields that correspond
            % to the properties of the MATLAB figure object. 
            
            tFigureOptions = struct('bTimePlot', true, 'bPlotTools', false);
            oPlotter.defineFigure(coPlots, 'Test Figure Title', tFigureOptions);
            
            tPlotOptions = struct('sAlternativeXAxisValue', '"Branch Flow Rate"', 'sXLabel', 'Main Branch Flow Rate in [kg/s]', 'fTimeInterval',10);
            coPlots = {oPlotter.definePlot({'"Tank 1 Pressure"'}, 'Pressure vs. Flow Rate', tPlotOptions)};
            oPlotter.defineFigure(coPlots, 'Pressure vs. Flow Rate');
            

            tPlotOptions = struct('sTimeUnit','hours');
            coPlots = {};
            coPlots{1,1} = oPlotter.definePlot({'"Branch Flow Rate"'}, 'Flow Rate', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Pressure Tank 1"', '"Pressure Tank 2"'}, 'Pressures', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'Flow Rate');
            
            oPlotter.plot();
        end
        
    end
    
end

