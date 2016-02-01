classdef absorber < matter.phase
    %ABSORBER Model of an absorber phase 
    %   This phase is to be used in both adsorption and absorption
    %   modeling. For ease of use, the class has been named absorber since
    %   this term is more commonly known.
    %   The class utilizes special methods to calculate the return values
    %   for the different derived classes, such as exmes and flows, as to
    %   be compatible with the iterative solver while at the same time not
    %   producing illegal combinations of matter properties that would
    %   cause errors in matter table calculations.
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, ?)
        % @type string
        %TODO: rename to |sMatterState|
        sType = 'absorber';
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Volume in m^3
        fVolume;       
        
        % An integer containing the matter table index of the substance
        % that is the absorbing substance of this absorber
        iAbsorbentIndex;
        
        % Boolean to indicate if this phase is currently absorbing or
        % desorbing. 
        bAbsorbing;

    end
    
    methods
        function this = absorber(oStore, sName, tfMasses, fTemperature, sMatterState, sAbsorbentSubstance)
            this@matter.phase(oStore, sName, tfMasses, fTemperature)
            
            % If a specific absorbent substance is given, we set the
            % absorbent index property accordingly. If none is given, we'll
            % just use the substance that has the largest amount of mass in
            % this phase. 
            if nargin > 5
                this.iAbsorbentIndex = this.oMT.tiN2I.(sAbsorbentSubstance);
            else
                [ ~, this.iAbsorbentIndex ] = max(this.afMass);
                sAbsorbentSubstance = this.oMT.csI2N{this.iAbsorbentIndex};
            end
            
            if length(this.iAbsorbentIndex) > 1
                this.throw('absorber', ['Two substances within the absorber phase have the exact same mass so it is not possible to determine which one should be the main substance.\n',...
                                        'Please provide a tfMasses struct where one substance has more mass than any other or provide the substance which shall be the absorbent as a string in the fourth input parameter of this phase.']);
            end
            
            % Now we need to calculate the volume of this absorber phase.
            % To do that we first build a struct with all the parameters we
            % will need to call the findProperty() method of the matter
            % table.
            tParameters = struct();
            tParameters.sSubstance = sAbsorbentSubstance;
            tParameters.sProperty = 'Density';
            tParameters.sFirstDepName = 'Temperature';
            tParameters.fFirstDepValue = fTemperature;
            tParameters.sPhaseType = sMatterState;
            
            % Now we can call the findProperty() method.
            fDensity = this.oMT.findProperty(tParameters);
            
            % The volume is the mass divided with the density
            this.fVolume = this.fMass / fDensity;
            
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
                
                % First the standard heat capacity for all
                % substances within the adsorber is calculated
                aiIndices   = find(this.arPartialMass > 0);
                iNumIndices = length(aiIndices);
                
                % Initialize a new array filled with zeros. Then iterate through all
                % indexed substances and get their specific heat capacity.
                afCp = zeros(this.oMT.iSubstances, 1);
                
                for iI = 1:iNumIndices
                    try
                        afCp(aiIndices(iI)) = this.oMT.ttxMatter.(this.oMT.csSubstances{aiIndices(iI)}).fStandardSpecificHeatCapacity;
                    catch
                        try
                            afCp(aiIndices(iI)) = this.oMT.ttxMatter.(this.oMT.csSubstances{aiIndices(iI)}).ttxPhases.tSolid.HeatCapacity;
                        catch
                            try 
                                afCp(aiIndices(iI)) = this.oMT.ttxMatter.(this.oMT.csSubstances{aiIndices(iI)}).ttxPhases.tLiquid.HeatCapacity;
                            catch
                                try
                                    afCp(aiIndices(iI)) = this.oMT.ttxMatter.(this.oMT.csSubstances{aiIndices(iI)}).ttxPhases.tGas.HeatCapacity;
                                catch
                                    this.throw('absorber', 'No heat capacity given in any state for %s.', this.oMT.csSubstances{aiIndices(iI)});
                                end
                            end
                        end
                    end
                end
                
                % Multiply the specific heat capacities with the mass fractions. The
                % result of the matrix multiplication is the specific heat capacity of
                % the mixture.
                this.fSpecificHeatCapacity           = sum(this.arPartialMass * afCp);
                
                % Setting the properties for the next check
                this.fTemperatureLastHeatCapacityUpdate  = this.fTemperature;
                this.arPartialMassLastHeatCapacityUpdate = this.arPartialMass;

            end
            
        end
        
        function [ fMass, arPartialMasses ] = getMassesWithoutAbsorber(this)
            fAbsorberMass = this.afMass(this.iAbsorbentIndex);
            fMass = this.fMass - fAbsorberMass;
            
            arPartialMasses = this.afMass ./ fMass;
            arPartialMasses(this.iAbsorbentIndex) = 0;
            
        end
    end
    
end

