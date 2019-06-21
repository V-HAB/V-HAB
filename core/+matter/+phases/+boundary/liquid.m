classdef liquid < matter.phases.boundary.boundary
    %% liquid_boundary
    % A liquid phase that is modelled as containing an infinite amount of matter
    % with specifiable (and changeable) values for the composition and
    % temperature. The intended use case is e.g. to model vacuum in space
    % and environmental conditions in test cases
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        sType = 'liquid';
    end
    
    methods
        function this = liquid(oStore, sName, tfMass, fTemperature, fPressure)
            
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fTemperature  : Temperature of matter in phase
            % fPress        : Pressure of matter in phase

            this@matter.phases.boundary.boundary(oStore, sName, tfMass, fTemperature);
            
            this.fMassToPressure =  fPressure / sum(this.afMass);
            
            tProperties.afMass = this.afMass;
            this.setBoundaryProperties(tProperties)
            
        end
        
        function bSuccess = setPressure(this, fPressure)
            % Changes the pressure of the phase. If no processor for volume
            % change registered, do nothing.
            
            bSuccess = this.setParameter('fPressure', fPressure);
        end
        
        function bSuccess = setVolume(this, fVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.
            
            bSuccess = this.setParameter('fVolume', fVolume);
            this.fDensity = this.fMass / this.fVolume;
        end
        
        function setBoundaryProperties(this, tProperties)
            % using this function the user can set the properties of the
            % boundary phase. Currently the following properties can be
            % set:
            %
            % afMass:       partial mass composition of the phase
            % fPressure:    Total pressure, from which the partial
            %               pressures of the boundary are calculated based
            %               on afMass
            % fTemperature: Temperature of the boundary
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            % Since the pressure calculation require the temperature, we
            % first set the temperature if it was provided
            if isfield(tProperties, 'fTemperature')
                this.oCapacity.setBoundaryTemperature(tProperties.fTemperature);
            end
            
            % Store the current pressure in a local variable in case
            % nothing else overwrites the pressure this will again be the
            % pressure of the phase
            fPressure = this.fPressure;
            
            % In case afMass is used we calculate the partial pressures
            if isfield(tProperties, 'afMass')
                if isfield(tProperties, 'fPressure')
                   fPressure = tProperties.fPressure;
                end
                
                this.afMass = tProperties.afMass;
                this.fMass = sum(this.afMass);
            end
            
            if this.fMass ~= 0
                % Now we calculate other derived values with the new parameters
                this.fMassToPressure = fPressure/this.fMass;
                this.fMolarMass      = sum(this.afMass .* this.oMT.afMolarMass) / this.fMass;
                
                this.arPartialMass = this.afMass/this.fMass;
                
                % V/m = p*R*T;
                this.fDensity = this.oMT.calculateDensity(this);
            else
                this.fMassToPressure = 0;
                this.fMolarMass = 0;
                this.arPartialMass = zeros(1, this.oMT.iSubstances);
                this.fDensity = 0;
            end
            
            % We also need to reset some thermal values (e.g. total heat
            % capacity) which is done in the temperature function
            this.oCapacity.setBoundaryTemperature(this.fTemperature);
            
            this.setBranchesOutdated();
        end
    end
end