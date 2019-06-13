classdef solid < matter.phase
    % SOLID desribes an ideally mixed solid phase. Must be located inside
    % of a store to work

    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'solid';

    end

    properties (SetAccess = protected, GetAccess = public)
        fVolume = 0;     % Volume of all solid substances in m^3
        fPressure = 1e5; % Placeholder/compatibility "pressure" since solids do not have an actual pressure.
        
    end
    
    methods
        
        function this = solid(oStore, sName, tfMasses, fTemperature)
            %SOLID Create a new solid phase
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.fDensity = this.oMT.calculateDensity(this);
            
            this.fVolume      = this.fMass / this.fDensity;
            
        end
    end
end