classdef solid < matter.phase
    % SOLID desribes an ideally mixed solid phase. Must be located inside
    % of a store to work

    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'solid';

    end

    methods
        
        function this = solid(oStore, sName, tfMasses, fTemperature)
            %SOLID Create a new solid phase
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.fDensity = this.oMT.calculateDensity(this);
            
            this.fVolume      = this.fMass / this.fDensity;
            
            % initialize to the standard pressure, if a different pressure
            % for solids should be calculated have a solid and gas phase in
            % one store and use the store function addStandardVolumeManipulators
            this.fMassToPressure    = this.oMT.Standard.Pressure / this.fMass;
        end
    end
    methods (Access = protected)
        function this = update(this)
            update@matter.phase(this);
            
            this.fDensity = this.fMass / this.fVolume;
            
            this.fMassToPressure = this.oMT.calculatePressure(this) / this.fMass;
        end
        
        function fPressure = get_fPressure(this)
            %% get_fPressure
            % for solids we do not want to include the mass change between
            % updates as a pressure change
            fPressure = this.fMassToPressure * this.fMass;
        end
    end
end