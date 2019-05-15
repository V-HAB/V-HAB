classdef mixture < matter.phases.flow.flow
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
        function this = mixture(oStore, sName, sPhaseType, tfMass, fVolume, fTemperature, fPressure)            
            this@matter.phases.flow.flow(oStore, sName, tfMass, fVolume, fTemperature);
            
            this.sPhaseType = sPhaseType;
            if nargin >= 5
                this.fPressure = fPressure;
            else
                this.fPressure = 1e5;
            end
        end
    end
end

