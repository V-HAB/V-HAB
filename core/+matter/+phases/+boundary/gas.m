classdef gas < matter.phases.boundary.boundary
    %% gas_boundary
    % A gas phase that is modelled as containing an infinite amount of matter
    % with specifiable (and changeable) values for the composition and
    % temperature. The intended use case is e.g. to model vacuum in space
    % and environmental conditions in test cases
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'gas';
    end

    properties (SetAccess = protected, GetAccess = public)
        % Partial pressures in Pa
        afPP;
        
        % Substance concentrations in ppm
        afPartsPerMillion;
        
        % Relative humidity in the phase, see this.update() for details on
        % the calculation.
        rRelHumidity;
    end
    
    methods
        function this = gas(oStore, sName, tfMass, fVolume, fTemperature, fPressure)
            %% gas boundary class constructor
            %
            % creates a gas boundary phase with the specifid conditions.
            % These will remain constant throughout the simulation unless
            % they are directly changed using the setBoundaryProperties
            % function!
            %
            % to make the boundary phase compatible with phase definitions
            % of normal gas phases, if the volume is provided it is simply
            % ignored, otherwise only three parameters are required
            %
            % Required inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fVolume       : Just here so that nothing must be changed
            %                 when a phase definition is changed from a
            %                 normal phase to a boundary phase
            % fTemperature  : Temperature of matter in phase
            % fPressure     : Pressure of the phase
            
            this@matter.phases.boundary.boundary(oStore, sName, tfMass, fTemperature);
            
            if nargin >= 4 && ~isempty(fVolume) && (nargin <= 5 || isempty(fPressure))
                % To be compatible with the standard gas definition (which uses
                % the volume), the boundary phase also has the volume as input,
                % but it is only used to calculate the pressure of the gas
                % phase
                
                % p*V = m*R*T;
                if this.fMass == 0
                    this.fMassToPressure = 0;
                else
                    this.fMassToPressure = this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * fVolume);
                end
            elseif nargin >= 6
                this.fMassToPressure = fPressure / this.fMass;
            end
            
            % Now we set all required properties
            tProperties.afMass = this.afMass;
            this.setBoundaryProperties(tProperties)
        end
        
        function setBoundaryProperties(this, tProperties)
            %% setBoundaryProperties
            % using this function the user can set the properties of the
            % boundary phase. Currently the following properties can be
            % set:
            %
            % afMass:       partial mass composition of the phase
            % fPressure:    Total pressure, from which the partial
            %               pressures of the boundary are calculated based
            %               on afMass
            % afPP:         partial pressure composition of the phase (if
            %               afMass is not provided)
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
                
                if this.fMass ~= 0
                    % Now we calculate the molar mass fractions, since these
                    % represent the partial pressure fractions as well
                    afMols = this.afMass ./ this.oMT.afMolarMass;
                    arMolFractions = afMols/sum(afMols);
                    % And then set the correct partial pressure composition for
                    % the phase
                    this.afPP = this.fPressure .* arMolFractions;
                end
            % Since elseif is used afPP is ignored if afMass is provided
            elseif isfield(tProperties, 'afPP')
                % if the partial pressures are provided the mass
                % composition is calculated
                fPressure = sum(tProperties.afPP);
                this.afPP = tProperties.afPP;
                
                arMolFractions = this.afPP ./ sum(this.afPP);
                this.afMass = arMolFractions .* this.oMT.afMolarMass;
                this.fMass = sum(this.afMass);
            end
            
            if this.fMass ~= 0
                % Now we calculate other derived values with the new parameters
                this.fMassToPressure = fPressure/this.fMass;
                this.fMolarMass      = this.fMass ./ sum(this.afMass ./ this.oMT.afMolarMass);
                
                this.afPartsPerMillion = (this.afMass ./ this.fMolarMass) ./ (this.oMT.afMolarMass ./ this.fMass) * 1e6;
                
                this.arPartialMass = this.afMass/this.fMass;
                
                % V/m = p/R*T
                this.fDensity = this.fPressure / ((this.oMT.Const.fUniversalGas / this.fMolarMass) * this.fTemperature);
                
                if this.afPP(this.oMT.tiN2I.H2O)
                    % calculate saturation vapour pressure [Pa];
                    fSaturationVapourPressure = this.oMT.calculateVaporPressure(this.fTemperature, 'H2O');
                    % calculate relative humidity
                    this.rRelHumidity = this.afPP(this.oMT.tiN2I.H2O) / fSaturationVapourPressure;
                else
                    this.rRelHumidity = 0;
                end
                
            else
                this.fMassToPressure = 0;
                this.fMolarMass = 0;
                this.afPartsPerMillion = zeros(1, this.oMT.iSubstances);
                this.arPartialMass = zeros(1, this.oMT.iSubstances);
                this.fDensity = 0;
                this.afPP = zeros(1, this.oMT.iSubstances);
            end
            
            % We also need to reset some thermal values (e.g. total heat
            % capacity) which is done in the temperature function
            this.oCapacity.setBoundaryTemperature(this.fTemperature);
            
            this.setBranchesOutdated();
        end
    end
end