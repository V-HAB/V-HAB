classdef liquid_flow_node < matter.phases.flow_node
    %% liquid_flow_node
    % A liquid phase that is modelled as containing no matter. 
    
    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'liquid';
        
    end
    
    methods
        function this = liquid_flow_node(oStore, sName, varargin)
            this@matter.phases.flow_node(oStore, sName, varargin{:});
            
            this.fPressure = 1e5;
        end
    end
end

