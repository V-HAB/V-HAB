classdef mixture_flow_node < matter.phases.flow_node
    %% mixture_flow_node
    % A mixture phase that is modelled as containing no matter. 
    
    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'mixture';
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        sPhaseType;
    end
    
    methods
        function this = mixture_flow_node(oStore, sName, varargin)            
            this@matter.phases.flow_node(oStore, sName, varargin{2:4});
            
            this.sPhaseType = varargin{1};
            if length(varargin) >= 5
                this.fPressure = varargin{5};
            else
                this.fPressure = 1e5;
            end
        end
    end
end

