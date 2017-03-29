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
            this@simulation.infrastructure('Tutorial_Human_Model', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            tutorials.human_model.systems.Example(this.oSimulationContainer, 'Example');
            

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 24 * 5; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        
        function configureMonitors(this)
            
            %% Logging
            % Creating a cell setting the log items. You need to know the
            % exact structure of your model to set log items, so do this
            % when you are done modelling and ready to run a simulation. 
            
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity', '-', 'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)', 'P_Pa', 'Partial Pressure CO2 Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.O2)', 'P_Pa', 'Partial Pressure O2 Cabin');
            
%             oLog.add('Example:c:Three_Humans', 'flow_props');

%             oLog.addValue('Example:c:Three_Humans:s:Human.toPhases.Air', 'rRelHumidity', '-', 'Relative Humidity Human');
%             oLog.addValue('Example:c:Three_Humans:s:Human.toPhases.Air', 'afPP(this.oMT.tiN2I.CO2)', 'P_Pa', 'Partial Pressure CO2 Human');
%             oLog.addValue('Example:c:Three_Humans:s:Human.toPhases.Air', 'afPP(this.oMT.tiN2I.O2)', 'P_Pa', 'Partial Pressure O2 Human');
            
            
            oLog.add('Example:c:One_Human', 'flow_props');
            
            oLog.addValue('Example:c:One_Human:s:Human.toPhases.Air', 'rRelHumidity', '-', 'Relative Humidity Human');
            oLog.addValue('Example:c:One_Human:s:Human.toPhases.Air', 'afPP(this.oMT.tiN2I.CO2)', 'P_Pa', 'Partial Pressure CO2 Human');
            oLog.addValue('Example:c:One_Human:s:Human.toPhases.Air', 'afPP(this.oMT.tiN2I.O2)', 'P_Pa', 'Partial Pressure O2 Human');
            
            oLog.addValue('Example:c:One_Human:s:Human.toPhases.SolidFood', 'afMass(this.oMT.tiN2I.C)', 'P_kg', 'Partial Mass Dry Solid Food');
            oLog.addValue('Example:c:One_Human:s:Human.toPhases.SolidFood', 'afMass(this.oMT.tiN2I.H2O)', 'P_kg', 'Partial Mass H2O in Solid Food');
            
             oLog.addValue('Example:c:One_Human:s:Human.toPhases.SolidFood.toManips.substance' ,'afPartialFlows(this.oMT.tiN2I.C)', 'Manip_kg/s', 'Digestion C Flow Rate');
             oLog.addValue('Example:c:One_Human:s:Human.toPhases.SolidFood.toManips.substance' ,'afPartialFlows(this.oMT.tiN2I.H2O)', 'Manip_kg/s', 'Digestion Water Flow Rate');
             oLog.addValue('Example:c:One_Human:s:Human.toPhases.SolidFood.toManips.substance' ,'afPartialFlows(this.oMT.tiN2I.Feces)', 'Manip_kg/s', 'Digestion Feces Flow Rate');
             oLog.addValue('Example:c:One_Human:s:Human.toPhases.SolidFood.toManips.substance' ,'afPartialFlows(this.oMT.tiN2I.UrineSolids)', 'Manip_kg/s', 'Digestion UrineSolids Flow Rate');
             oLog.addValue('Example:c:One_Human:s:Human.toPhases.SolidFood.toManips.substance' ,'afPartialFlows(this.oMT.tiN2I.Waste)', 'Manip_kg/s', 'Digestion Waste Flow Rate');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot('Pa', 'Tank Pressures');
            oPlot.definePlot('K', 'Tank Temperatures');
            oPlot.definePlot('kg', 'Tank Masses');
            oPlot.definePlot('kg/s', 'Flow Rates');
            
            oPlot.definePlot('P_Pa', 'Partial Pressures in Cabin');
            oPlot.definePlot('-', 'Relative Humidity in Cabin');
            oPlot.definePlot('P_kg', 'Partial Masses in human');
            
            oPlot.definePlot('Manip_kg/s', 'Digestion Flow Rates');
            

        end
        
        function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();
        
        end
        
    end
    
end

