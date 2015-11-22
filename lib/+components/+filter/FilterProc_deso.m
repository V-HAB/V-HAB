classdef FilterProc_deso < matter.procs.p2ps.flow
    % P2P processor representing the desorption flow.
    % Called and set externaly in the adsorption p2p processor.
    properties
    end
    
    methods
        function [this] = FilterProc_deso(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);  
        end
        
        function update(~)   
        end
    end
    
end