classdef solid < matter.phase
    %SOLID Summary of this class goes here
    %   Detailed explanation goes here

    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, ?)
        % @type string
        %TODO: rename to |sMatterState|
        sType = 'solid';

    end

    properties (SetAccess = protected, GetAccess = public)
        %afVolume;        % Array containing the volume of the individual substances in m^3
        fVolume = 0;     % Volume of all solid substances in m^3
        fPressure = NaN; % Placeholder/compatibility "pressure" since solids do not have an actual pressure.
        
    end
    
    methods
        
        function this = solid(oStore, sName, tfMasses, fIgnoredVolume, fTemperature)
            %SOLID Create a new solid phase
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            
            csKeys = fieldnames(tfMasses);
            afVolumes = zeros(1,length(csKeys));
            for iI = 1:length(csKeys)
                sKey     = csKeys{iI};
                fMass    = this.afMass(this.oMT.tiN2I.(sKey));
                fVolumeSolid = this.oMT.calculateSolidVolume(tfMasses, fTemperature);
                fDensity = fMass / fVolumeSolid;
                %what is the purpose of this?
                afVolumes(this.oMT.tiN2I.(sKey)) = fMass / fDensity;
            end
            this.fVolume  = sum(afVolumes);
            this.fDensity = this.fMass / this.fVolume;
            
            if ~isempty(fIgnoredVolume) && abs(1 - fIgnoredVolume / this.fVolume) > 1e-3
                this.warn('matter:phases:solid', 'Volume %d m^3 set for solid will be ignored. Instead, the value was set to %d m^3.', fIgnoredVolume, this.fVolume);
            end
            
        end
        
        function bSuccess = setVolume(this, ~)
            % Prevent volume from being set.
            bSuccess = false;
            this.throw('matter:phases:solid', 'Cannot compress a solid, duh!');
        end
        
        function updateSpecificHeatCapacity(this)
            % When a phase was empty and is being filled with matter again,
            % it may be a couple of ticks until the phase.update() method
            % is called, which updates the phase's specific heat capacity.
            % Other objects, for instance matter.flow, may require the
            % correct value for the heat capacity as soon as there is
            % matter in the phase. In this case, these objects can call
            % this function, that will update the fSpecificHeatCapacity
            % property of the phase.
            
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
    
    %% Protected methods, called internally to update matter properties %%%
    methods (Access = protected)
        function setAttribute(this, sAttribute, xValue)
            % Internal helper, see @matter.phase class.
            %
            %TODO throw out, all done with events hm?
            
            this.(sAttribute) = xValue;
        end
    end
    
end

