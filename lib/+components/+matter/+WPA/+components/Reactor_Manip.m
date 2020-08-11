classdef Reactor_Manip < matter.manips.substance.flow
    %models the reactor in V-HAB based on:
     %Two-Phase Oxidizing Flow in Volatile Removal Assembly Reactor Under Microgravity Conditions
    % written by Boyun Guo, Donald W. Holder and John T. Tester
    properties
        fReactorLength           = 1.12; %[m]
        fBubbleVelocity          = 0.0018; %m/s 0.18cm/s
        fBubbleRadius            = 0.139; %[m] if there'd be 1g instead of 0.01g--> 12.7cm
        rSphericityOxygenBubbles = 0.5; %small_diameter/large_diameter
        fOxidationRate           = -5.15*10^-4; %in kg/m^2 32 Mol_O2,
        
        % Vectors containing the stochiometric ratios of the corrsponding
        % substance dividided with the molar amount of the volatile at
        % which the entry is located
        arStochiometricO2Ratio;
        arStochiometricCO2Ratio;
        arStochiometricH2ORatio;
        arStochiometricN2Ratio;
            
        abVolatile;
            
        fResidenceTime                   = 0; %the time the water stays in the reactor 
        afFlowRates;
        
    end
    methods
        function this = Reactor_Manip(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            
            this.afFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            
            %getting values
            this.fResidenceTime   = this.oPhase.oStore.fVolume*1000/this.oPhase.oStore.oContainer.fFlowRate;
            
            % Here we define the stochiometric conversion rates for the
            % considered volatiles. The stochiometric ratio is the mol
            % amount of the respective substance divided with the mol
            % amount of the organic volatile
            arStochiometricO2Ratio  = zeros(1, this.oMT.iSubstances);
            arStochiometricCO2Ratio = zeros(1, this.oMT.iSubstances);
            arStochiometricH2ORatio = zeros(1, this.oMT.iSubstances);
            arStochiometricN2Ratio  = zeros(1, this.oMT.iSubstances);
            
            % Note, it is also feasible to calculate these values
            % automatically by counting the C, H and O atoms of the
            % substances. Note that it is necessary to always calculate
            % this to have a one for the volatile, otherwise check equation
            % (6) from the mentioned paper at the beginning of this file
            
            % C2H6O + 3 O2 -> 2 CO2 + 3 H2O
            arStochiometricO2Ratio(this.oMT.tiN2I.C2H6O)    = 3;
            arStochiometricCO2Ratio(this.oMT.tiN2I.C2H6O)   = 2;
            arStochiometricH2ORatio(this.oMT.tiN2I.C2H6O)   = 3;
            
            % CH2O2 + 0.5 O2 -> CO2 + H2O
            arStochiometricO2Ratio(this.oMT.tiN2I.CH2O2)    = 0.5;
            arStochiometricCO2Ratio(this.oMT.tiN2I.CH2O2)   = 1;
            arStochiometricH2ORatio(this.oMT.tiN2I.CH2O2)   = 1;
            
            % C3H8O2 + 4 O2 -> 3 CO2 + 4 H2O
            arStochiometricO2Ratio(this.oMT.tiN2I.C3H8O2)   = 4;
            arStochiometricCO2Ratio(this.oMT.tiN2I.C3H8O2)  = 3;
            arStochiometricH2ORatio(this.oMT.tiN2I.C3H8O2)  = 4;
            
            % CH2O + 1 O2 -> 1 CO2 + 1 H2O
            arStochiometricO2Ratio(this.oMT.tiN2I.CH2O)     = 1;
            arStochiometricCO2Ratio(this.oMT.tiN2I.CH2O)    = 1;
            arStochiometricH2ORatio(this.oMT.tiN2I.CH2O)    = 1;
            
            % C2H6O2 + 1.5 O2 -> 2 CO2 + 3 H2O
            arStochiometricO2Ratio(this.oMT.tiN2I.C2H6O2) 	= 1.5;
            arStochiometricCO2Ratio(this.oMT.tiN2I.C2H6O2)	= 2;
            arStochiometricH2ORatio(this.oMT.tiN2I.C2H6O2) 	= 3;
            
            % C3H6O + 4 O2 -> 3 CO2 + 3 H2O
            arStochiometricO2Ratio(this.oMT.tiN2I.C3H6O)    = 4;
            arStochiometricCO2Ratio(this.oMT.tiN2I.C3H6O)   = 3;
            arStochiometricH2ORatio(this.oMT.tiN2I.C3H6O)   = 3;
            
            % C3H6O3 + 3 O2 -> 3 CO2 + 3 H2O
            arStochiometricO2Ratio(this.oMT.tiN2I.C3H6O3)   = 3;
            arStochiometricCO2Ratio(this.oMT.tiN2I.C3H6O3)  = 3;
            arStochiometricH2ORatio(this.oMT.tiN2I.C3H6O3)  = 3;
            
            % CH4N2O + 1.5 O2 -> 1 CO2 + 2 H2O + N2
            arStochiometricO2Ratio(this.oMT.tiN2I.CH4N2O)   = 1.5;
            arStochiometricCO2Ratio(this.oMT.tiN2I.CH4N2O)  = 1;
            arStochiometricH2ORatio(this.oMT.tiN2I.CH4N2O)  = 2;
            arStochiometricN2Ratio(this.oMT.tiN2I.CH4N2O)   = 1;
            
            this.arStochiometricO2Ratio     = arStochiometricO2Ratio;
            this.arStochiometricCO2Ratio    = arStochiometricCO2Ratio;
            this.arStochiometricH2ORatio    = arStochiometricH2ORatio;
            this.arStochiometricN2Ratio     = arStochiometricN2Ratio;
            
            this.abVolatile = false(1, this.oMT.iSubstances);
            this.abVolatile(arStochiometricO2Ratio ~= 0) = true;
            
        end
        
        function calculateConversionRate(this, afInFlowRates, aarInPartials)
            %getting inflowrates
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
            
            % Since we also consider P2P flowrates for these in flows, we
            % have to check to not use negative total flowrates here:
            afPartialInFlows(afPartialInFlows < 0) = 0;
            
            % The amount of organics injected into the reactor are given by
            % the inlet flows of the phase, multiplied with the residence
            % time yields the corresponding organics that the reactor
            % should oxidize: Equation (8)
            afOrganicsToRemove = afPartialInFlows(this.abVolatile) * this.fResidenceTime;
            
            if all(afOrganicsToRemove == 0)
                this.afFlowRates = zeros(1, this.oMT.iSubstances);
            else
                Density_O2 = 4.2817311450828; %density of O_2 at given reactor temperature and pressure

                % "Two-Phase Oxidizing Flow in Volatile Removal Assembly
                % Reactor Under Microgravity Conditions", Boyun Guo, Donald W.
                % Holder and John T. Tester, 2005
                % Equation (3)
                rOxygenUtilization = 1 - exp(((3 * this.fOxidationRate * this.rSphericityOxygenBubbles) / (this.fBubbleRadius * Density_O2 * this.fBubbleVelocity)) * this.fReactorLength); %percentage of oxygen that can oxidate

                % Get the current oxygen inlet flowrate
                fOxygenInjection = this.oPhase.oStore.toProcsP2P.ReactorOxygen_P2P.fFlowRate * this.oPhase.oStore.toProcsP2P.ReactorOxygen_P2P.arPartialMass(this.oMT.tiN2I.O2);

                % According to the same paper, the oxygen mass consumption
                % potential is defined in equation (5)
                fOxygenMassConsumptionPotential = rOxygenUtilization * fOxygenInjection * this.fResidenceTime; %amount of oxygen that can be used for oxidation

                % And the amount of organics removed in the reaction can be
                % expressed by equation (6)
                afRemovedOrganics = fOxygenMassConsumptionPotential .* this.oMT.afMolarMass(this.abVolatile) ./ (this.arStochiometricO2Ratio(this.abVolatile) .* this.oMT.afMolarMass(this.oMT.tiN2I.O2));

                % If the removed organics value is larger than the value that
                % enters the reactor, everything of that substance reacts.
                % Otherwise, a specific ratio remains.
                arRemovalEfficiencies = ones(1, this.oMT.iSubstances);
                arRemovalEfficiencies(this.abVolatile) = (afOrganicsToRemove - afRemovedOrganics) ./ afOrganicsToRemove;
                arRemovalEfficiencies(arRemovalEfficiencies < 0) = 0;
                arRemovalEfficiencies = ones(1, this.oMT.iSubstances) - arRemovalEfficiencies;

                afReactedVolatiles = afPartialInFlows .* arRemovalEfficiencies;

                afReactedVolatilesMols = afReactedVolatiles ./ this.oMT.afMolarMass;

                afReactedO2Mols     = afReactedVolatilesMols .* this.arStochiometricO2Ratio;
                afProducedCO2Mols   = afReactedVolatilesMols .* this.arStochiometricCO2Ratio;
                afProducedH2OMols   = afReactedVolatilesMols .* this.arStochiometricH2ORatio;
                afProducedN2Mols    = afReactedVolatilesMols .* this.arStochiometricN2Ratio;

                fO2Consumption  = sum(afReactedO2Mols)      * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
                fCO2Production  = sum(afProducedCO2Mols)    * this.oMT.afMolarMass(this.oMT.tiN2I.CO2);
                fH2OProduction  = sum(afProducedH2OMols)    * this.oMT.afMolarMass(this.oMT.tiN2I.H2O);
                fN2Production   = sum(afProducedN2Mols)     * this.oMT.afMolarMass(this.oMT.tiN2I.N2);

                this.afFlowRates     = - afReactedVolatiles;
                this.afFlowRates(this.oMT.tiN2I.O2)  = - fO2Consumption;
                this.afFlowRates(this.oMT.tiN2I.CO2) = fCO2Production;
                this.afFlowRates(this.oMT.tiN2I.H2O) = fH2OProduction;
                this.afFlowRates(this.oMT.tiN2I.N2)  = fN2Production;
            end
            
            this.update();

        end
    end
    
    methods (Access = protected)
        function update(this)
            update@matter.manips.substance.flow(this, this.afFlowRates);
        end
    end
end

