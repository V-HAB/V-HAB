classdef setup < simulation.infrastructure
    properties
    end
    
    methods
        function this = setup(varargin) 
            this@simulation.infrastructure('Tutorial_Simple_Thermal', containers.Map(), struct(), struct());
            
            tutorials.simple_thermal.systems.Example(this.oSimulationContainer, 'Example');
            
            this.fSimTime = 3600;
        end
        
        function configureMonitors(this)
            this.toMonitors.oLogger.add('Example', 'thermalProperties');
        end
        
        function plot(this) 
            oPlotter = plot@simulation.infrastructure(this);
            
            oPlotter.plot();
        end
    end
end