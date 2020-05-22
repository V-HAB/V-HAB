classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - set the simulation duration
    %   - determine which items are logged
    %   - provide methods for plotting the results
    
    properties
        tiLogIndexes = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Test_Automatic_ExMes', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tests.AutoExMes.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 3600; % In seconds
            else 
                this.fSimTime = fSimTime;
            end
            
            this.bUseTime = true;
        end
        
        
        
        function configureMonitors(this)
            
            %% Logging
            % You need to know the exact structure of your model to set log
            % items, so do this when you are done modelling and ready to
            % run a simulation.
            
            oLog = this.toMonitors.oLogger;
            
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
            
            this.tiLogIndexes.iTempIdx1 = oLog.addValue('Example.toProcsF2F.Pipe.aoFlows(1)', 'fTemperature', 'K', 'Flow Temperature - Left', 'flow_temp_left');
            this.tiLogIndexes.iTempIdx2 = oLog.addValue('Example.toProcsF2F.Pipe.aoFlows(2)', 'fTemperature', 'K', 'Flow Temperature - Right', 'flow_temp_right');
 
            
            this.tiLogIndexes.iIndex_1 = oLog.addVirtualValue('fr_co2 * 1000', 'g/s', 'CO_2 Flowrate', 'co2_fr_grams');
            this.tiLogIndexes.iIndex_2 = oLog.addVirtualValue('flow_temp_left - 273.15', 'degC', 'Temperature Left in Celsius');
            this.tiLogIndexes.iIndex_3 = oLog.addVirtualValue('mod(flow_temp_right .^ 2, 10) ./ "Partial Mass CO_2 Tank 2"', '-', 'Nonsense');
            
        end
        
        function plot(this) % Plotting the results
            
            %% Define plots
            
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions = struct('sTimeUnit','hours');
            coPlots = [];
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Phase 1"', '"Temperature Phase 2"'}, 'Temperatures', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Pressure Phase 1"', '"Pressure Phase 2"'}, 'Pressure', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Branch Flow Rate"'}, 'Flowrate', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'Tank Temperatures', struct('bTimePlot',true));
            

            oPlotter.plot();
        end
        
    end
    
end

