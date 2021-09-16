classdef setup < simulation.infrastructure
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Example_Fan_Loop_Flow', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            examples.multibranch_solver.systems.Example(this.oSimulationContainer, 'Example');
            
            this.fSimTime = 1800 * 1;
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            oLog = this.toMonitors.oLogger;
            oLog.add('Example','flowProperties');
        end
        
        function plot(this, varargin)
            oPlotter = plot@simulation.infrastructure(this);
            oPlotter.plot();
        end
    end
end