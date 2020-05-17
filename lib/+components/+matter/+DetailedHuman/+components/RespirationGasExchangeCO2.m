classdef RespirationGasExchangeCO2 < matter.procs.p2ps.flow
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    methods
        function this = RespirationGasExchangeCO2(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            % this P2P
            % sPhaseAndPortIn muste be the tissue phase!
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
        end
        
        function calculateFlowRate(~, ~, ~, ~, ~)
            
        end
    end
    methods (Access = protected)
        function update(~)
            % this must be here since the normal V-HAB logic tries to
            % call the update
        end
    end
end