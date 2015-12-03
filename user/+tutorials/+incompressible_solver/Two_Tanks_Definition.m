classdef Two_Tanks_Definition < simulation.infrastructure
    % This simulation shows the equalization of pressure between two gas
    % stores over time assuming the BRANCH to be incompressible, the stores
    % are not incompressible since then the equalization would be
    % instantaneous.
    
    properties
    end
    
    methods
        function this = Two_Tanks_Definition(ptConfigParams, tSolverParams)
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('Tutorial_Incompressible_System', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            oTwo_Tanks = tutorials.incompressible_solver.systems.Two_Tanks(this.oSimulationContainer, 'Two_Tanks');
            
            warning('off', 'all');
            
            %for branch liquid the second entry is the number of cells used
            %to calculate the branches
            
            iIncompBranches = 1;
            %System Solver Inputs:
            %(oSystem, fMinTimeStep, fMaxTimeStep, fMaxProcentualFlowSpeedChange, iPartialSteps, iLastSystemBranch, fSteadyStateTimeStep, fSteadyStateAcceleration, mLoopBranches)  
            oTwo_Tanks.oSystemSolver = solver.matter.incompressible_liquid.system_incompressible_liquid(oTwo_Tanks, 1, 5, 1e-1, 300, iIncompBranches, 100, 10);
           
            %Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Two_Tanks', 'flow_props');
            
            %Define Plots
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');
                
            
            % Sim time [s]
            this.fSimTime = 30;
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            this.toMonitors.oPlotter.plot();
        end
    end
end

