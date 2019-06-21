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
        sPhaseType;
    end
    
    methods
        function this = mixture(oStore, sName, sPhaseType, tfMasses, ~, fTemperature, fPressure)
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.sPhaseType = sPhaseType;
            if strcmp(this.sPhaseType, 'gas')
                this.fMassToPressure = this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            else
                this.fMassToPressure = fPressure / this.fMass;
            end
            this.fDensity = this.oMT.calculateDensity(this);
            this.fVolume = this.fMass / this.fDensity;
            
            this.bMixture = true;
        end
    end
    
    
    methods (Access = protected)
        function this = update(this)
            update@matter.phase(this);
            
            this.fDensity = this.fMass / this.fVolume;
            
            if ~strcmp(this.sPhaseType, 'solid')
                this.fMassToPressure = this.oMT.calculatePressure(this) / this.fMass;
            end
        end
        
        function fPressure = get_fPressure(this)
            %% get_fPressure
            % for mixtures we do not want to include the mass change between
            % updates as a pressure change
            fPressure = this.fMassToPressure * this.fMass;
        end
    end
end

