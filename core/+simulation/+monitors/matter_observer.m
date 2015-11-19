classdef matter_observer < simulation.monitor
    %EXECUTION_CONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    methods
        function this = matter_observer(oSimulationInfrastructure)
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post', 'init_post', 'finish', 'pause' });
            
        end
    end
    
    
    methods (Access = protected)
        
        function onTickPost(this)
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            
        end
        
        
        function onInitPost(this)
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            % Initialize arrays etc
        end
        
        
        function onFinish(this)
            this.displayMatterBalance();
        end
        
        
        function onPause(this)
            this.displayMatterBalance();
        end
        
        
        function displayMatterBalance(this)
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            
            % DISP balance
            fprintf('+------------------- MATTER BALANCE -------------------+\n');
            
            
            fBalance = sum(this.fBalance);
            
            %TODO accuracy from time step!
            fprinft('| Mass Lost (i.e. negative masses in phases when depleted): %.12f', fBalance);
            
            fprintf('+------------------------------------------------------+\n');
        end
    end
end

