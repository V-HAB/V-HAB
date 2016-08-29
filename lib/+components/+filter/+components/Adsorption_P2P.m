classdef Adsorption_P2P < matter.procs.p2ps.flow & event.source
    
    % TO DO: at the moment just empty to create the basic simulation
    % infrastructure for the new filter model
    
    properties
        
    end
    
   
    
    methods
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% Constructor %%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [this] = Adsorption_P2P(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
        end
        
        function update(~)   
        end
    end
end
