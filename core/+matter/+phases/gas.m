classdef gas < matter.phase
    %GAS Describes a volume of gas
    %   Detailed explanation goes here
    %
    %TODO
    %   - support empty / zero volume (different meanings?)
    %   - if gas is solved in a fluid, different sutff ... don't really
    %     need the fVolume, right? Just pressure of fluid, so need a linked
    %     fluid phase, or also do through store (so own store that supports
    %     that ...). Then a p2p proc to move gas out of the solvent into
    %     the outer gas phase depending on partial pressures ...

    properties (Constant)

        % State of matter in phase (e.g. gas, liquid, ?)
        % @type string
        %TODO: rename to |sMatterState|
        sType = 'gas';

    end

    properties (SetAccess = protected, GetAccess = public)
        
        % Volume in m^3
        fVolume;       
        
        % Pressure in Pa
        fPressure;              
        
        % Partial pressures in Pa
        afPP;                   
        
        % Coefficient for pressure = COEFF * mass,  depends on current 
        % matter properties
        fMassToPressure;  
        
        % Relative humidity in the phase, see this.update() for details on
        % the calculation.
        rRelHumidity
    
    end
    
    
    methods
        % oStore        : Name of parent store
        % sName         : Name of phase
        % tfMasses      : Struct containing mass value for each species
        % fVolume       : Volume of the phase
        % fTemperature  : Temperature of matter in phase
        %
        %TODO fVolume is stupid - needs to be set by store!
        function this = gas(oStore, sName, tfMasses, fVolume, fTemperature)
            %TODO
            %   - not all params required, use defaults?
            %   - volume from store ...?
            this@matter.phase(oStore, sName, tfMasses, fTemperature);
            
            % Get volume from 
            if nargin < 4 || isempty(fVolume), fVolume = oStore.fVolume; end;
            
            this.fVolume  = fVolume;
            this.fDensity = this.fMass / this.fVolume;
            
            this.fMassToPressure = this.calculatePressureCoefficient();
            this.fPressure = this.fMass * this.fMassToPressure;
            this.fPressureLastHeatCapacityUpdate = this.fPressure;
        end
        
        
        function bSuccess = setVolume(this, fNewVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.
            %
            %TODO see above, needs to be redone (processors/manipulator)
            
            bSuccess = this.setParameter('fVolume', fNewVolume);
            
            return;
            
            %TODO with events:
            %this.trigger('set.fVolume', struct('fVolume', fNewVolume, 'setAttribute', @this.setAttribute));
            
            % See human, events return data which is processed here??
            % What is several events are registered? Different types of
            % volume change etc ...? Normally just ENERGY should be
            % provided to change the volume, and the actual change in
            % volume is returned ...
            % See above, manipulators instead of processors. For each
            % phase, user needs to decide if e.g. isobaric or isochoric
            % change of volume.
        end
        
        
        function this = update(this)
            update@matter.phase(this);
            
            %TODO coeff m to p: also in liquids, plasma. Not solids, right?
            %     calc afPPs, rel humidity, ... --> in matter table!
            %
            
            % Check for volume not empty, when called from constructor
            %TODO see above, generally support empty volume? Treat a zero
            %     and an empty ([]) volume differently?
            if ~isempty(this.fVolume)
                this.fMassToPressure = this.calculatePressureCoefficient();
                
                %this.fPressure = sum(this.afMass) * this.fMassToPressure;
                this.fPressure = this.fMass * this.fMassToPressure;
                this.afPP      = this.oMT.calculatePartialPressures(this);
                this.fDensity  = this.fMass / this.fVolume;
                
                
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
                    % MAGNUS Formula; validity: -45???C <= T <= 60???C, for water
                    fSaturationVapourPressure = 610.94 * exp((17.625 * (this.fTemperature - 273.15)) / (243.04 + this.fTemperature - 273.15));
                    % calculate relative humidity
                    this.rRelHumidity = this.afPP(this.oMT.tiN2I.H2O) / fSaturationVapourPressure;
                else
                    this.rRelHumidity = 0;
                end
        
            else
                this.fPressure = 0;
            end
        end
        
        function [ afPartialPressures ] = getPartialPressures(this)
            %TODO should we still provide this proxy method? Or throw a
            %     deprecation warning/error?
            afPartialPressures = this.oMT.calculatePartialPressures(this);
        end
        
        
        function fMassToPressure = calculatePressureCoefficient(this)
            % p = m * (R_m * T / M / V)
            %
            
            fMassToPressure = this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            
            %TODO molar mass zero if no mass - NaN, or Inf if mass zero
            if isnan(fMassToPressure) || isinf(fMassToPressure)
                fMassToPressure = 0;
            end
        end


        function setProperty(this, sAttribute, xValue)
            this.(sAttribute) = xValue;
        end


        function seal(this)

            seal@matter.phase(this);

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
               (abs(this.fPressureLastHeatCapacityUpdate - this.fPressure) > 100) ||...
               (abs(this.fTemperatureLastHeatCapacityUpdate - this.fTemperature) > 1) ||...
               (max(abs(this.arPartialMassLastHeatCapacityUpdate - this.arPartialMass)) > 0.01)

                % Actually updating the specific heat capacity
                this.fSpecificHeatCapacity           = this.oMT.calculateSpecificHeatCapacity(this);
                
                % Setting the properties for the next check
                this.fPressureLastHeatCapacityUpdate     = this.fPressure;
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

