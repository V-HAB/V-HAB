classdef mixture < matter.phase
    %mixture phase
    % this phase can be used to implement mixture phases that consist of
    % different substance that normally are at different phases (gas
    % liquid/solid). For example it can be used to create a phase that can
    % contain zeolite (solid) and CO2 (gas) and water (liquid) at the same
    % time. This is achieved by putting each substance into a subtype
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        % @type string
        %TODO: rename to |sMatterState|
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
        
    function this = update(this)
        update@matter.phase(this);
        
        this.fDensity = this.fMass / this.fVolume;
        
        % TO DO: implement pressure calculation for liquid phase
        if strcmp(this.sPhaseType, 'gas')
            this.fPressure = this.oMT.calculatePressure(this);
        end
        
        
    end
    function updateSpecificHeatCapacity(this)
        
        
        % In order to reduce the amount of times the matter
        % calculation is executed it is checked here if the pressure
        % and/or temperature have changed significantly enough to
        % justify a recalculation
        % TO DO: Make limits adaptive
        if (this.oTimer.iTick <= 0) ||... %necessary to prevent the phase intialization from crashing the remaining checks
           (abs(this.fTemperatureLastHeatCapacityUpdate - this.fTemperature) > 1) ||...
           (max(abs(this.arPartialMassLastHeatCapacityUpdate - this.arPartialMass)) > 0.01)

            % Actually updating the specific heat capacity
            this.fSpecificHeatCapacity           = this.oMT.calculateSpecificHeatCapacity(this);

            % Setting the properties for the next check
            this.fTemperatureLastHeatCapacityUpdate  = this.fTemperature;
            this.arPartialMassLastHeatCapacityUpdate = this.arPartialMass;
        end
    end
    end
end

