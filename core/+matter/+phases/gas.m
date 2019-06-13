classdef gas < matter.phase
    % GAS Describes a volume of ideally mixed gas using ideal gas
    % assumptions. Must be located inside a store to work!
    
    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'gas';

    end

    properties (SetAccess = protected, GetAccess = public)
        
        % Volume in m^3
        fVolume;       
        
        % Pressure in Pa
        fPressure;              
        
        % Partial pressures in Pa
        afPP;   
        
        % Substance concentrations in ppm
        afPartsPerMillion;
        
        % Coefficient for pressure = COEFF * mass,  depends on current 
        % matter properties
        fMassToPressure;  
        
        % Relative humidity in the phase, see this.update() for details on
        % the calculation.
        rRelHumidity;
    
    end
    
    
    methods
        % oStore        : Name of parent store
        % sName         : Name of phase
        % tfMasses      : Struct containing mass value for each species
        % fVolume       : Volume of the phase
        % fTemperature  : Temperature of matter in phase
        function this = gas(oStore, sName, tfMasses, fVolume, fTemperature)
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            % Get volume from 
            if nargin < 4 || isempty(fVolume), fVolume = oStore.fVolume; end
            
            this.fVolume  = fVolume;
            this.fDensity = this.fMass / this.fVolume;
            
            this.fMassToPressure = this.calculatePressureCoefficient();
            this.fPressure = this.fMass * this.fMassToPressure;
            
            
            [ this.afPP, this.afPartsPerMillion ] = this.oMT.calculatePartialPressures(this);
            
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
            % p = m * (R_m * T / M / V)
            %
            
            fMassToPressure = this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            
            if isnan(fMassToPressure) || isinf(fMassToPressure)
                fMassToPressure = 0;
            end
        end

        function seal(this)

            seal@matter.phase(this);

        end
        
        function setTemperature(this, oCaller, fTemperature)
            % This function can only be called from the ascociated capacity
            if ~isa(oCaller, 'thermal.capacity')
                this.throw('setTemperature', 'The setTemperature function of the phase class can only be used by capacity objects. Please do not try to set the temperature directly, as this would lead to errors in the thermal solver');
            end
                
            this.fTemperature = fTemperature;
            
            if ~isempty(this.fVolume)
                this.fMassToPressure = this.calculatePressureCoefficient();
            end
        end
    end
    
    
    %% Protected methods, called internally to update matter properties %%%
    methods (Access = protected)
        function this = update(this)
            update@matter.phase(this);
            
            % Check for volume not empty, when called from constructor
            if ~isempty(this.fVolume)
                this.fMassToPressure = this.calculatePressureCoefficient();
                
                this.fPressure = this.fMass * this.fMassToPressure;
                [ this.afPP, this.afPartsPerMillion ] = this.oMT.calculatePartialPressures(this);
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
                this.fPressure = 0;
            end
        end
    end
end