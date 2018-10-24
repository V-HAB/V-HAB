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
        function this = mixture(oStore, sName, sPhaseType, tfMasses, fVolume, fTemperature, fPressure)
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            this.sPhaseType = sPhaseType;
            this.fVolume = fVolume;
            this.fDensity = this.fMass / this.fVolume;
            this.fPressure = fPressure;
            this.fPressureLastHeatCapacityUpdate = this.fPressure;
        end
        
        function this = registerUpdate(this)
            registerUpdate@matter.phase(this);
            
            this.fDensity = this.fMass / this.fVolume;
            
            % TO DO: implement pressure calculation for liquid phase
            if strcmp(this.sPhaseType, 'gas')
                this.fPressure = this.oMT.calculatePressure(this);
            end
            
            
        end
    end
end

