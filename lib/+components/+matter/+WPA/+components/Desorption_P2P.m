classdef Desorption_P2P < matter.procs.p2ps.flow
    % P2P processor representing the desorption flow.
    % Called and set externaly in the adsorption p2p processor.
    % IMPORTANT, the adsorption P2P must be defined before the desorption
    % P2P for correct update order!
    properties
    end
    
    methods
        function [this] = Desorption_P2P(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);  
        end
        
        function calculateFlowRate(~, ~, ~, ~, ~)
        end
    end
    
    methods (Access = protected)
        function update(~)   
        end
    end
end