classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
        % Property where indices of logs can be stored
        tiLogIndexes = struct();
    end
    
    methods
        % Constructor function
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) 
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Test_Plotting', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            examples.plotting.systems.Example(this.oSimulationContainer, 'Example');
            
            % Setting the simulation duration to one hour. Time is always
            % in units of seconds in V-HAB.
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 3600;
            else 
                this.fSimTime = fSimTime;
            end
            
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
            %   - :s: = toStores
            %   - :c: = toChildren
            
            this.tiLogIndexes.iTempIdx1 = oLog.addValue('Example.toProcsF2F.Pipe.aoFlows(1)', 'fTemperature', 'K', 'Flow Temperature - Left', 'flow_temp_left');
            this.tiLogIndexes.iTempIdx2 = oLog.addValue('Example.toProcsF2F.Pipe.aoFlows(2)', 'fTemperature', 'K', 'Flow Temperature - Right', 'flow_temp_right');
            
            
            % The log is built like this:
            %
            %             Path to the object containing the log value       Log Value                       Unit    Label of log value (used for legends and to plot the value) 
            oLog.addValue('Example:s:Tank_1.aoPhases(1)',                   'afPP(this.oMT.tiN2I.CO2)',     'Pa',   'Partial Pressure CO_2 Tank 1', 'ppCO2_Tank1');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)',                   'afPP(this.oMT.tiN2I.CO2)',     'Pa',   'Partial Pressure CO_2 Tank 2', 'ppCO2_Tank2');
            
            % it is also possible to define a calculation as log value and
            % e.g. multiply two values from the object.
            
            % This can be usefull if you want to log the flowrate of CO2
            % through a branch that transports air for example            
            oLog.addValue('Example.aoBranches(1).aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'Flowrate of CO2', 'fr_co2');
            
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'afMass(this.oMT.tiN2I.CO2)', 'kg');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO_2 Tank 2');
            
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'fTemperature', 'K', 'Temperature Phase 1');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'fTemperature', 'K', 'Temperature Phase 2');
            
            oLog.addValue('Example:s:Tank_1.aoPhases(1)', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 1');
            oLog.addValue('Example:s:Tank_2.aoPhases(1)', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 2');
            
            oLog.addValue('Example.toBranches.Branch', 'fFlowRate', 'kg/s', 'Branch Flow Rate', 'branch_FR');
            
            this.tiLogIndexes.iIndex_1 = oLog.addVirtualValue('fr_co2 * 1000', 'g/s', 'CO_2 Flowrate', 'co2_fr_grams');
            this.tiLogIndexes.iIndex_2 = oLog.addVirtualValue('flow_temp_left - 273.15', 'degC', 'Temperature Left in Celsius');
            this.tiLogIndexes.iIndex_3 = oLog.addVirtualValue('mod(flow_temp_right .^ 2, 10) ./ "Partial Mass CO_2 Tank 2"', '-', 'Nonsense');
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define plots
            
            oPlotter = plot@simulation.infrastructure(this);
            
            cxPlotValues1 = { '"CO_2 Flowrate"', this.tiLogIndexes.iIndex_2, 'Nonsense' };
            csPlotValues2 = { '"Partial Pressure CO_2 Tank 1"', '"Partial Pressure CO_2 Tank 2"'};
            csPlotValues3 = { 'flow_temp_left', 'flow_temp_right' };
            
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
            tPlotOptions = struct('csUnitOverride', {{ {'degC'}, {'g/s','-'} }});
            tPlotOptions.tLineOptions.('fr_co2').csColor = 'g';
            tPlotOptions.tLineOptions.('Nonsense').csColor = 'y';
            tPlotOptions.bLegend = false;
            coPlots{1,1} = oPlotter.definePlot(cxPlotValues1, 'This makes no sense', tPlotOptions);
            
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
            coPlots = {oPlotter.definePlot({'"Pressure Phase 1"'}, 'Pressure vs. Flow Rate', tPlotOptions)};
            oPlotter.defineFigure(coPlots, 'Pressure vs. Flow Rate');
            
            
            tPlotOptions = struct('sTimeUnit','hours');
            coPlots = [];
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Phase 1"', '"Temperature Phase 2"'}, 'Temperatures', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Pressure Phase 1"', '"Pressure Phase 2"'}, 'Pressure', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Branch Flow Rate"'}, 'Flowrate', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'Tank Temperatures');
            
            % For 'quick and dirty' logging and plotting, helpers may be
            % used such as the one found in
            % simuation.helper.logger.flowProperties. This helper will log
            % all temperatures, all pressures, all masses and all flow
            % rates in a provided system. In order to plot these in a
            % somewhat organized way, we might want to group them together
            % by unit. To do that, the tPlotOptions struct can contain a
            % struct called tFilter that then contains the filtering
            % information. Below an example is given where we only plot
            % temperatures, so filtering by the unit string 'K'.
            
            % First we need to get the log indexes of all items in the
            % logger. 
            ciIndexes = tools.convertArrayToCell(1:this.toMonitors.oLogger.iNumberOfLogItems);
            
            % Now we set the tPlotOptions struct
            tPlotOptions = struct();
            tPlotOptions.tFilter = struct('sUnit','K');
            
            % Creating the plot object 
            coPlots = {oPlotter.definePlot(ciIndexes,'Temperatures',tPlotOptions)};
            
            % And finally another figure.
            oPlotter.defineFigure(coPlots, 'All Temperatures');
            
            % Doing the actual plotting. 
            oPlotter.plot();
        end
        
    end
    
end