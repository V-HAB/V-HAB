classdef mixture < matter.phase
    %mixture phase
    % this phase can be used to implement mixture phases that consist of
    % different substance that normally are at different phases (gas
    % liquid/solid). For example it can be used to create a phase that can
    % contain zeolite (solid) and CO2 (gas) and water (liquid) at the same
    % time. This is achieved by putting each substance into a subtype
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'mixture';
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Volume in m^3
        fVolume;
        fPressure;

        sPhaseType;
    end
    
    methods
        function this = mixture(oStore, sName, sPhaseType, tfMasses, ~, fTemperature, fPressure)
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.sPhaseType = sPhaseType;
            if strcmp(this.sPhaseType, 'gas')
                this.fPressure = this.fMass * this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            else
                this.fPressure = fPressure;
            end
            this.fDensity = this.oMT.calculateDensity(this);
            this.fVolume = this.fMass / this.fDensity;
            
            this.fPressureLastHeatCapacityUpdate = this.fPressure;
        end
        
        function bSuccess = setPressure(this, fPressure)
            % Changes the pressure of the phase. If no processor for volume
            % change registered, do nothing.

            bSuccess = this.setParameter('fPressure', fPressure);
        end

        function bSuccess = setVolume(this, fVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.

            if strcmp(this.sPhaseType, 'gas')
                bSuccess = this.setParameter('fVolume', fVolume);
                this.fDensity = this.fMass / this.fVolume;
                this.fPressure = this.fMass * this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            else
                error('you cannot compress solids or liquids')
            end
        end
    end
    
    
    methods (Access = protected)
        function this = update(this)
            update@matter.phase(this);
            
            this.fDensity = this.fMass / this.fVolume;
            
            if strcmp(this.sPhaseType, 'gas')
                this.fPressure = this.oMT.calculatePressure(this);
            end
        end
        
        function setAttribute(this, sAttribute, xValue)
            % Internal helper, see @matter.phase class.
            this.(sAttribute) = xValue;
        end
    end
end

