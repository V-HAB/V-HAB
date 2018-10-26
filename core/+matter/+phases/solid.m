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
        
        function bSuccess = setPressure(this, fPressure)
            % Changes the pressure of the phase. If no processor for volume
            % change registered, do nothing.
            
            bSuccess = this.setParameter('fPressure', fPressure);
            this.fDensity = this.fMass / this.fVolume;
        end
        
        function bSuccess = setVolume(this, fVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.
            
            bSuccess = this.setParameter('fVolume', fVolume);
            this.fDensity = this.fMass / this.fVolume;
        end
    end
end

