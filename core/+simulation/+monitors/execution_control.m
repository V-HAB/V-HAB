classdef execution_control < simulation.monitor
    %EXECUTION_CONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    methods
        function this = execution_control(oSimulationInfrastructure)
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post' });
            
        end
    end
    
    
    methods (Access = protected)
        
        function onTickPost(this)
            
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            
        end
        
    end
end

