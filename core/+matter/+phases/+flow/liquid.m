classdef liquid < matter.phases.flow.flow
    %% liquid_flow_node
    % A liquid phase that is modelled as containing no matter. 
    
    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'liquid';
        
    end
    
    methods
        function this = liquid(oStore, sName, varargin)
            this@matter.phases.flow.flow(oStore, sName, varargin{:});
            
            this.fPressure = 1e5;
        end
    end
end

