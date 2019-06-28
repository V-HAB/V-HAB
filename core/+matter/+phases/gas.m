classdef gas < matter.phase
    % GAS Describes a volume of ideally mixed gas using ideal gas
    % assumptions. Must be located inside a store to work!
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'gas';
    end

    properties (SetAccess = protected, GetAccess = public)
        % Partial pressures in Pa
        afPP;
        
        % Relative humidity in the phase, see this.update() for details on
        % the calculation.
        rRelHumidity;
    end
    
    properties (Dependent)
        % Substance concentrations in ppm. This is a dependent property because it is
        % only calculated on demand because it should rarely be used. if
        % the property is used often, making it not a dependent property or
        % providing a faster calculation option is suggested
        afPartsPerMillion;
    end
    
    methods
        function this = gas(oStore, sName, tfMasses, fVolume, fTemperature)
            %% gas class constructor
            % describes an ideally mixed volume of gas. Different from the
            % boundary and flow type phases the mass of this phase will
            % change and a time step is calculated limiting by how much the
            % phase properties are allowed to change. This type of phase
            % should be used e.g. to model the habitat atmosphere (boundary
            % would be e.g. the martian atmosphere, flow phases would be
            % e.g. individual phases within subsystems that are very small)
            %
            % Required Inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fVolume       : The volume of the phase in m^3
            % fTemperature  : Temperature of matter in phase
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            % Get volume from 
            if nargin < 4 || isempty(fVolume), fVolume = oStore.fVolume; end
            
            this.fVolume  = fVolume;
            this.fDensity = this.fMass / this.fVolume;
            
            this.fMassToPressure = this.calculatePressureCoefficient();
            
            this.afPP               = this.oMT.calculatePartialPressures(this);
            
            if this.afPP(this.oMT.tiN2I.H2O)
                % calculate saturation vapour pressure [Pa];
                fSaturationVapourPressure = this.oMT.calculateVaporPressure(this.fTemperature, 'H2O');
                % calculate relative humidity
                this.rRelHumidity = this.afPP(this.oMT.tiN2I.H2O) / fSaturationVapourPressure;
            else
                this.rRelHumidity = 0;
            end
        end
        
        function fMassToPressure = calculatePressureCoefficient(this)
            %% calculatePressureCoefficient
            % calculate the coefficient from the ideal gas law which
            % results in the pressure in Pav if multiplied with a mass in
            % kg. p = m * (R_m * T / M / V)
            % For pressures higher than 10 bar the coefficient is instead
            % calculated by using the matter table (realgas assumption) and
            % dividing it with the current mass
            
            if this.fPressure < 10e5
                fMassToPressure = this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            else
                fMassToPressure = this.oMT.calculatePressure(this) / this.fMass;
            end
            
            if isnan(fMassToPressure) || isinf(fMassToPressure)
                fMassToPressure = 0;
            end
        end
        
        function afPartsPerMillion = get.afPartsPerMillion(this)
            %% get.fPressure
            % Since the pressure is a dependent property but some child
            % classes require a different calculation approach for
            % the pressure this function only defines the function name
            % which is used to calculate the pressure (since child classes
            % cannot overload this function).
            afPartsPerMillion = this.oMT.calculatePartsPerMillion(this);
        end
    end
    
    
    %% Protected methods, called internally to update matter properties %%%
    methods (Access = {?thermal.capacity, ?matter.phase})
        function setTemperature(this, fTemperature)
            %% setTemperature
            % INTERNAL FUNCTION!
            % This function can only be called from the ascociated capacity
            this.fTemperature = fTemperature;
            
            if ~isempty(this.fVolume)
                this.fMassToPressure = this.calculatePressureCoefficient();
            end
        end
    end
    
    methods (Access = protected)
        function this = update(this)
            %% gas update
            % INTERNAL FUNCTION!
            % called in addition to the normal phase update to calculate
            % gas specific properties like the partial pressure and parts
            % per million
            update@matter.phase(this);
            
            % Check for volume not empty, when called from constructor
            if ~isempty(this.fVolume)
                this.fMassToPressure = this.calculatePressureCoefficient();
                
                this.afPP               = this.oMT.calculatePartialPressures(this);
                this.fDensity = this.fMass / this.fVolume;
                
                
                % Function rRelHumidity calculates the relative humidity of
                % the gas by using the MAGNUS Formula(validity: 
                % -45[C] <= T <= 60[C], for water); Formula is only correct 
                % for pure steam, not the mixture of air and water; 
                % enhancement factors can be used by a Poynting-Correction 
                % (pressure and temperature dependent); the values of the 
                % enhancement factors are in the range of 1+- 10^-3; thus 
                % they are neglected.
                % Source: Important new Values of the Physical Constants of 
                % 1986, Vapour Pressure Formulations based on ITS-90, and 
                % Psychrometer Formulae. In: Z. Meteorol. 40, 5,
                % S. 340-344, (1990)
                
                if this.afMass(this.oMT.tiN2I.H2O)
                    % calculate saturation vapour pressure [Pa];
                    fSaturationVapourPressure = this.oMT.calculateVaporPressure(this.fTemperature, 'H2O');
                    % calculate relative humidity
                    this.rRelHumidity = this.afPP(this.oMT.tiN2I.H2O) / fSaturationVapourPressure;
                else
                    this.rRelHumidity = 0;
                end
            else
                this.fMassToPressure = 0;
            end
        end
    end
end