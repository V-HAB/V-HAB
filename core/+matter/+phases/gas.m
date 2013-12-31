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
    
    properties (SetAccess = protected, GetAccess = public)
        % Phase type (for matter table etc)
        sType = 'gas';
        
        fVolume;                % Volume in m^3
        fPressure;              % Pressure in Pa
        afPP;                   % Partial pressures in Pa
        
        fMassToPressure;        % Coefficient for pressure = COEFF * mass
                                % depends on current matter properties
    end
    
    properties (Dependent = true)
        rRelHumidity;           % Relative Humidity in %
    end
    
    methods
        % oStore    : Name of parent store
        % sName     : Name of phase
        % tfMasses  : Struct containing mass value for each species
        % fVolume   : Volume of the phase
        % fTemp     : Temperature of matter in phase
        %
        %TODO fVolume is stupid - needs to be set by store!
        function this = gas(oStore, sName, tfMasses, fVolume, fTemp)
            %TODO
            %   - not all params required, use defaults?
            %   - volume from store ...?
            
            this@matter.phase(oStore, sName, tfMasses, fTemp);
            
            this.fVolume  = fVolume;
            this.fDensity = this.fMass / this.fVolume;
        end
        
        function rRelHumidity = get.rRelHumidity(this)
            rRelHumidity = 0; %Calculate this here...;
        end
        
        
        
        function bSuccess = setVolume(this, fVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.
            %
            %TODO see above, needs to be redone (processors/manipulator)
            
            bSuccess = this.setParameter('fVolume', fVolume);
            
            return;
            
            %TODO with events:
            this.trigger('set.fVolume', struct('fVolume', fVolume, 'setAttribute', @this.setAttribute));
            
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
                this.afPP      = this.getPartialPressures();
            else
                this.fPressure = 0;
            end
        end
        
        function [ afPartialPressures ] = getPartialPressures(this)
            %TODO see @matter.flow.getPartialPressures
            %     PROTECTED! automatically called in .update() -> afPPs!
            %
            %TODO allow param (cell, string, index) --> select species for
            %     whom to get partial pressure
            
            % No mass? 
            if this.fMass == 0
                % Partials have to be zero, as fMass is zero which is the
                % sum() of afMass. arPartials derived from afMass.
                afPartialPressures = this.arPartialMass;
            else
                % Calculating the number of mols for each species
                afMols = this.arPartialMass ./ this.oStore.oMT.afMolMass;
                % Calculating the total number of mols
                fGasAmount = sum(afMols);
                % Calculating the partial amount of each species by mols
                arFractions = afMols ./ fGasAmount;
                % Calculating the partial pressures by multiplying with the
                % total pressure in the phase
                afPartialPressures = arFractions .* this.fPressure;
            end
        end
        
        
        function fMassToPressure = calculatePressureCoefficient(this)
            % p = m * (R_m * T / M / V)
            %
            %TODO matter table -> store mol mass this.fMolMass as kg/mol!
            %     move this calc to matter.table.calcGasPressure, or do
            %     some matter.helper.table.gas.pressure or so?
            
            fMassToPressure = matter.table.C.R_m * this.fTemp / ((this.fMolMass / 1000) * this.fVolume);
            
            %TODO mol mass zero if no mass - NaN, or Inf if mass zero
            if isnan(fMassToPressure) || isinf(fMassToPressure)
                fMassToPressure = 0;
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

