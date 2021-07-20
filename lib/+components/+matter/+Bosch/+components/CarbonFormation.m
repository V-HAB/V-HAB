classdef CarbonFormation < matter.manips.substance.flow
    %Carbon Formation Reactor
    % Two reactions take place simultaneously: H2+CO-->C(s)+H2O (CO Hydro)
    %                                          2CO-->C(s)+CO2 (Boudouard)
    % side reactions as the sabatier reactions are assumed to not occur
    % We assume that the Boudouard reaction is the main reaction and that it
    % reaches equilibrium. Only 50% of the remaining CO is transformed via 
    % the CO Hydrogenation reaction
    
    properties (SetAccess = protected, GetAccess = public)
    
        fTemperature = -1;     %in K
       
        fMolarFluxInH2  = -1;  %in mol/s
        fMolarFluxInCO2 = -1;  %in mol/s
        fMolarFluxInCO  = -1;  %in mol/s
        
        fMolarFluxOutH2  = -1; %in mol/s
        fMolarFluxOutCO2 = -1; %in mol/s
        fMolarFluxOutCO  = -1; %in mol/s
        fMolarFluxOutH2O = -1; %in mol/s
        
        %CO Hydrogenation: index 1
        fConvertedH2   = -1;   %in mol/s
        fConvertedCO_1 = -1;   %in mol/s
        fProducedH2O   = -1;   %in mol/s
        fProducedC_1   = -1;   %in mol/s
        
        fAvailableCO = -1;     %in mol/s
        
        %Boudouard Reaction; index 2
        fBoudouardCO2  = -1;   %in [-]; Percentage of CO2 produced when equilibrium is reached
        fConvertedCO_2 = -1;   %in mol/s
        fProducedCO2   = -1;   %in mol/s
        fProducedC_2   = -1;   %in mol/s
        
        fProducedC = -1;       %in mol/s
        
        %Output for solver
        fTotalMassFlowBack = 0; %in kg/s
        fMassFlowOutC = 0;      %in kg/s
        
        afConversionRates;
    end
    
    properties (Constant)
        
        fPressure = 100000 %in Pa
        
        %The percentage of CO2 that is existent  when the
        %equilibrium of the Boudouard reaction is reached can be calculated
        %with an interpolation of given values.
        mfBoudouardCO2 = [0.966, 0.895, 0.8, 0.703, 0.6, 0.41, 0.21, 0.165, 0.075, 0.03] %in [-] at Equilibrium
        mfBoudouardTemperature = [673.15, 753.15, 828.15, 873.15, 908.15, 973.15, 1053.15, 1073.15, 1168.15, 1273.15] %in K
        
    end

    
    
    methods
        
       
        function this = CarbonFormation(sName, oPhase)
            %create a manipulator in which the Carbon Formation reactions take place
            this@matter.manips.substance.flow(sName, oPhase);
            this.afConversionRates = zeros(1, this.oMT.iSubstances);
        end
        
        function calculateConversionRate(this, afInFlowRates, aarInPartials, ~)
            %getting inflowrates
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
            % Since we also consider P2P flowrates for these in flows, we
            % have to check to not use negative total flowrates here:
            afPartialInFlows(afPartialInFlows < 0) = 0;
            
            % Abbreviating some of the variables to make code more legible
            afMolarMass = this.oPhase.oMT.afMolarMass;
            tiN2I     = this.oPhase.oMT.tiN2I;
            
            this.afConversionRates = zeros(1, this.oMT.iSubstances);
            % Make sure that if the inlet flow is 0, there is no flow out
            if sum(afPartialInFlows) <= 0
                this.update();
                return;
            end
            
            % Getting the total CO2 mass flow [kg/s] in the phase
            % Same for H2 and CO
            fMassFlowCO2 = afPartialInFlows(tiN2I.CO2);
            fMassFlowH2  = afPartialInFlows(tiN2I.H2);
            fMassFlowCO  = afPartialInFlows(tiN2I.CO);
            
            
            % Convert Mass Flow into Molar Flow
            % Factor 1000 because MolMass from matter table is in g/mol
            fMolarFlowCO2 = fMassFlowCO2 / afMolarMass(tiN2I.CO2);
            fMolarFlowH2  = fMassFlowH2 / afMolarMass(tiN2I.H2);
            fMolarFlowCO  = fMassFlowCO / afMolarMass(tiN2I.CO);
            
            
            %Call calculateReaction function, which calculates the
            %conversion in the Carbon Formation Reactor and gives us the 
            %"new" Molar flows that exit the reactor
            [fMolarFlowOutCO2, fMolarFlowOutH2, fMolarFlowOutCO, fMolarFlowOutH2O, fMolarFlowOutC ] = this.calculateReaction(fMolarFlowCO2, fMolarFlowH2, fMolarFlowCO);
            
            % Convert Molar flow into Mass Flow
            fMassFlowOutCO2     = fMolarFlowOutCO2  * afMolarMass(tiN2I.CO2);
            fMassFlowOutH2      = fMolarFlowOutH2   * afMolarMass(tiN2I.H2);
            fMassFlowOutCO      = fMolarFlowOutCO   * afMolarMass(tiN2I.CO);
            fMassFlowOutH2O     = fMolarFlowOutH2O  * afMolarMass(tiN2I.H2O);
            this.fMassFlowOutC  = fMolarFlowOutC    * afMolarMass(tiN2I.C);
            
            this.fTotalMassFlowBack = fMassFlowOutCO2 + fMassFlowOutH2 + fMassFlowOutCO + fMassFlowOutH2O;
            
            
            % Now we can fill the arPartials array which indicates the mass
            % change in the phase affected by the manipulator. The CO2, H2 
            % and CO mass flows are negative
            % the C and H2O mass flows are positive. We create the
            % differences of the mass flows, because not all of the
            % incoming CO2, H2 and CO is converted into C and H2O. VHab can
            % then calculate the composition of the outgoing gas stream.
            afMassFlowDiff = zeros(1, this.oMT.iSubstances);
            afMassFlowDiff(tiN2I.CO2)   = fMassFlowOutCO2 - fMassFlowCO2;
            afMassFlowDiff(tiN2I.H2)    = -1 * (fMassFlowH2 - fMassFlowOutH2);
            afMassFlowDiff(tiN2I.CO)	= -1 * (fMassFlowCO - fMassFlowOutCO);
            afMassFlowDiff(tiN2I.H2O)   = fMassFlowOutH2O;
            afMassFlowDiff(tiN2I.C)     = this.fMassFlowOutC;
            
            % Ensure mass flow differences have expected sign.
            assert(afMassFlowDiff(tiN2I.CO2) >= 0, 'CO2 is destroyed!');
            assert(afMassFlowDiff(tiN2I.H2)  <= 0, 'H2 is created!');
            assert(afMassFlowDiff(tiN2I.CO)  <= 0, 'CO is created!');
            assert(afMassFlowDiff(tiN2I.H2O) >= 0, 'H2O is destroyed!');
            assert(afMassFlowDiff(tiN2I.C)   >= 0, 'C is destroyed!');
            
            % Now we can call the parent update method and pass on the
            % afMassFlowDiff variable. The last parameter indicates that the
            % values in afMassFlowDiff are Flow rates
            this.afConversionRates = afMassFlowDiff;
            
            this.update();
        end
    end
        
    methods (Access = protected)
        
        function update(this)
            update@matter.manips.substance.flow(this, this.afConversionRates);
        end
        
        function [fMolarFlowOutCO2, fMolarFlowOutH2, fMolarFlowOutCO, fMolarFlowOutH2O, fMolarFlowOutC] = calculateReaction(this, fMolarFlowInCO2, fMolarFlowInH2, fMolarFlowInCO)
            
            % use the given flow rates for the following calculations
            this.fMolarFluxInH2  = fMolarFlowInH2;
            this.fMolarFluxInCO2 = fMolarFlowInCO2;
            this.fMolarFluxInCO = fMolarFlowInCO;
            
            % Get the temperature of the created phase
            % Since V-HAB will cool down the phase, set a (fake) fixed
            % temperature
            this.fTemperature = 823.15; %this.oPhase.fTemp;
            
            this.fBoudouardCO2 = this.calculateEqBoudouardCO2();
            
            this.fProducedCO2 = this.calculateProdCO2();
            this.fProducedC_2 = this.fProducedCO2;
            this.fConvertedCO_2 = this.calculateConvCO_2();
            
            this.fAvailableCO = this.calculateAvailableCO();
            
            this.fConvertedH2 = this.calculateConvH2();
            this.fConvertedCO_1 = this.calculateConvCO_1();
            this.fProducedH2O = this.calculateProd_1();
            this.fProducedC_1 = this.calculateProd_1();
            
            this.fProducedC = this.fProducedC_1 + this.fProducedC_2;
            this.fMolarFluxOutH2 = this.calculateMolFluxOutH2();
            this.fMolarFluxOutCO2 = this.calculateMolFluxOutCO2();
            this.fMolarFluxOutCO = this.calculateMolFluxOutCO();
            this.fMolarFluxOutH2O = this.calculateMolFluxOutH2O();
            
            % Return the values of the molar fluxes 
            fMolarFlowOutCO2 = this.fMolarFluxOutCO2;
            fMolarFlowOutH2 = this.fMolarFluxOutH2;
            fMolarFlowOutCO = this.fMolarFluxOutCO;
            fMolarFlowOutH2O = this.fMolarFluxOutH2O;
            fMolarFlowOutC = this.fProducedC;
            
           
         
        end
       
       %%Boudouard Reaction
        %converts CO to C and CO2 until equilibrium
       
        function fBoudouardCO2 = calculateEqBoudouardCO2(this)
            %calculate Boudouard Equlibrium with a linear interpolation
            fBoudouardCO2 = interp1(this.mfBoudouardTemperature, this.mfBoudouardCO2, this.fTemperature);
            
        end
        
        function fProducedCO2 = calculateProdCO2(this)
            %calculate produced CO2. Convert a percentage into a Molar flow
            %in [mol/s]
            fProducedCO2 = this.fBoudouardCO2 * (this.fMolarFluxInCO/(1 + this.fBoudouardCO2));
            
            
        end
        
        function fConvertedCO_2 = calculateConvCO_2(this)
            %calculate how much CO has been converted via the Boudouard
            %reaction
            fConvertedCO_2 = 2*this.fProducedCO2;
            
        end
        
        %%CO Hydrogenation
        %calculate converted H2
        %assumption: 50% of CO available is  converted
        function fAvailableCO = calculateAvailableCO(this)
            %Calculate the amount of CO that is available after the
            %Boudouard reaction has reached equilibrium
            fAvailableCO = this.fMolarFluxInCO - this.fConvertedCO_2;
            
        end
        
        function fConvertedH2 = calculateConvH2(this)
            %calculate how much H2 is converted during the reaction (it's
            %the same amount than the converted CO. As we assume that 50%
            %of the available CO is converted via the CO Hydrogenation, the
            %same amount of H2 is converted)
            fConvertedH2 = 0.5*this.fAvailableCO;
            
        end
        
        function fConvertedCO_1 = calculateConvCO_1(this)
            %calculate converted CO (see converted H2 above)
            fConvertedCO_1 = 0.5*this.fAvailableCO;
            
        end
        
        function fProduced_1 = calculateProd_1(this)
            %calculate produced H2O and C(s) (see reaction equation)
            fProduced_1 = 0.5*this.fAvailableCO;
            
        end
        
        
        %%Generally
        %calculate Molar Flux out H2
        function fMolarFluxOutH2 = calculateMolFluxOutH2(this)
            %calculate Molar Flux out H2
            fMolarFluxOutH2 = this.fMolarFluxInH2 - this.fConvertedH2;
            
        end
        
        function fMolarFluxOutCO2 = calculateMolFluxOutCO2(this)
            %calculate Molar Flux Out CO2
            fMolarFluxOutCO2 = this.fMolarFluxInCO2 + this.fProducedCO2;
            
        end
        
        function fMolarFluxOutCO = calculateMolFluxOutCO(this)
            %calculate Molar Flux Out CO
            fMolarFluxOutCO = this.fMolarFluxInCO - this.fConvertedCO_1 - this.fConvertedCO_2;
            
        end
        
        function fMolarFluxOutH2O = calculateMolFluxOutH2O(this)
            %calculate Molar Flux Out H2O
            fMolarFluxOutH2O = this.fProducedH2O;
            
        end 
        
    end
    
end

