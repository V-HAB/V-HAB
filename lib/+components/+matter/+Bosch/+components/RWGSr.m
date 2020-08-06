classdef RWGSr < matter.manips.substance.flow
    %RWGSr Reverse Water Gas Shift reactor
    %   CO2+H2 --> H2O+CO, Temperature > 828°C so that No side reactions occur,
    %   reaction runs spontaneously
    %   Conversion almost reach Equilibrium
    
    properties (SetAccess = protected, GetAccess = public)
        
        fTemperature = -1;         %in K
        
        fEquilibriumConstant = -1; %[-]
        fVelocityConstant    = -1; 
        fReactionRate        = -1; %in umol/(gCat*s)
        
        
        fMolarFluxInH2  = -1;      %in mol/s
        fMolarFluxInCO2 = -1;      %in mol/s
        
        fTotalMolarFlux = -1;      %in mol/s
        
        fVolumeFlowIn = -1;        %in m^3/s

        
        fMolarFluxOutH2  = -1;     %in mol/s
        fMolarFluxOutCO2 = -1;     %in mol/s
        fMolarFluxOutCO  = -1;     %in mol/s
        fMolarFluxOutH2O = -1;     %in mol/s
        
        fConversionCO2 = -1;       %in [-]
        
        fPartialPressureInH2  = -1; %in psi
        fPartialPressureInCO2 = -1; %in psi
        
        %Output for solver
        fTotalMassFlowOut = 0;      %in kg/s
        
        afConversionRates;
    end
    
    properties (Constant)
       
        fGasConstant = 8.3145;       % in J/(K*mol)
        fAlpha = 0.56;               % in [-]
        fBeta = 0.37;                % in [-]
        fPreExpFactor = 28125.68944; % in [-]
        fActivationEnergy = 75600;   % in J/mol
        fPressure = 100000;          % in Pa
        
    end
    
    
    methods
        
       
        function this = RWGSr(sName, oPhase)
            %create a manipulator in which the RWGS reaction takes place
            this@matter.manips.substance.flow(sName, oPhase);
            this.afConversionRates = zeros(1, this.oMT.iSubstances);
        end
        
        function calculateConversionRate(this, afInFlowRates, aarInPartials)
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
            % Same for H2
            fMassFlowCO2 = afPartialInFlows(tiN2I.CO2);
            fMassFlowH2  = afPartialInFlows(tiN2I.H2);
            
            
            % Convert Mass Flow into Molar Flow
            fMolarFlowCO2 = fMassFlowCO2 / afMolarMass(tiN2I.CO2);
            fMolarFlowH2  = fMassFlowH2 / afMolarMass(tiN2I.H2);
            
            
            %Call calculatereaction function, which calculates the
            %conversion in the RWGS reactor and gives us the "new" Molar
            %flows that exit the reactor
            [fMolarFlowOutCO2, fMolarFlowOutH2, fMolarFlowOutCO, fMolarFlowOutH2O ] = this.calculateReaction(fMolarFlowCO2, fMolarFlowH2);
            
            % Convert Molar flow into Mass Flow
            fMassFlowOutCO2     = fMolarFlowOutCO2  * afMolarMass(tiN2I.CO2);
            fMassFlowOutH2      = fMolarFlowOutH2   * afMolarMass(tiN2I.H2);
            fMassFlowOutCO      = fMolarFlowOutCO   * afMolarMass(tiN2I.CO);
            fMassFlowOutH2O     = fMolarFlowOutH2O  * afMolarMass(tiN2I.H2O);
            
            this.fTotalMassFlowOut = fMassFlowOutCO2 + fMassFlowOutH2 + fMassFlowOutCO + fMassFlowOutH2O;
            
            % Now we can fill the arPartials array which indicates the mass
            % change in the phase affected by the manipulator. The CO2 and
            % the H2 mass flows are negative
            % the CO and H2O masse flows are positive. We create the
            % differences of the mass flows, because not all of the
            % incoming CO2 and H2 is converted into CO and H2O. VHab can
            % then calculate the composition of the outgoing gas stream.
            afMassFlowDiff = zeros(1, this.oMT.iSubstances);
            afMassFlowDiff(tiN2I.CO2) = -1 * (fMassFlowCO2 - fMassFlowOutCO2);
            afMassFlowDiff(tiN2I.H2)  = -1 * (fMassFlowH2 - fMassFlowOutH2);
            afMassFlowDiff(tiN2I.CO)   = fMassFlowOutCO;
            afMassFlowDiff(tiN2I.H2O)  = fMassFlowOutH2O;
            
            % Ensure mass flow differences have expected sign.
            assert(afMassFlowDiff(tiN2I.CO2) <= 0, 'CO2 is created!');
            assert(afMassFlowDiff(tiN2I.H2)  <= 0, 'H2 is created!');
            assert(afMassFlowDiff(tiN2I.CO)  >= 0, 'CO is destroyed!');
            assert(afMassFlowDiff(tiN2I.H2O) >= 0, 'H2O is destroyed!');
            
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
        
        function [fMolarFlowOutCO2, fMolarFlowOutH2, fMolarFlowOutCO, fMolarFlowOutH2O] = calculateReaction(this, fMolarFlowInCO2, fMolarFlowInH2)
            
            % use the given flow rates for the following calculations
            this.fMolarFluxInH2  = fMolarFlowInH2;
            this.fMolarFluxInCO2 = fMolarFlowInCO2;
            
            % Get the temperature of the created phase
            % Since V-HAB will cool down the phase, set a (fake) fixed
            % temperature
            this.fTemperature = 1102; %this.oPhase.fTemp;
            
            this.fEquilibriumConstant = this.calculateEqConstant();
            
            this.fTotalMolarFlux = this.calculateTotalMolFlux();
            
            % calculate output
            this.fMolarFluxOutCO = this.calculateMolFluxOut1();
            this.fMolarFluxOutH2O = this.calculateMolFluxOut1();
            this.fMolarFluxOutCO2 = this.calculateMolFluxOut2();
            this.fMolarFluxOutH2 = this.calculateMolFluxOut2();
            
            % Calculate how much of the incoming CO2 has been converted
            % (value that will help to assess the results and compare them
            % to experimental data)
            this.fConversionCO2 = this.calculateConversion();
            
            % calculate reaction rate (not needed for the funtionality of
            % the system, but could be helpful for following work on the
            % model). FUTURE WORK: Using the reaction rate and the duration
            % of stay in the reactor a more precise model can be created,
            % since we assume that the reaction reaches equilibrium.
            this.fVolumeFlowIn = this.calculateVolumeFlow();
            
            this.fPartialPressureInH2 = this.calculatePartialPressure(this.fMolarFluxInH2);
            this.fPartialPressureInCO2 = this.calculatePartialPressure(this.fMolarFluxInCO2);
            
            this.fVelocityConstant = this.calculateVelConstant();
            
            this.fReactionRate = this.calculateReactionRate();
            
            % Return the values of the molar fluxes 
            fMolarFlowOutCO2 = this.fMolarFluxOutCO2;
            fMolarFlowOutH2 = this.fMolarFluxOutH2;
            fMolarFlowOutCO = this.fMolarFluxOutCO;
            fMolarFlowOutH2O = this.fMolarFluxOutH2O;
           
         
        end
       
        
        
        function fTotalMolarFlux = calculateTotalMolFlux(this)
            %calculate the total molar flux out of the incoming CO2 and H2
            %streams. It is supposed to be constant.
            fTotalMolarFlux = this.fMolarFluxInH2 + this.fMolarFluxInCO2;
            
        end
        
       
        
        
        function fEquilibriumConstant = calculateEqConstant(this)
            %The reaction is assumed to reach equilibrium. To get the 
            %composition of the outgoing gas stream the equilibrium 
            %constant has to be calculated.
            %The equation is empiric. In this case the Equilibrium is 
            %independent of pressure (for more details see thesis)
            fEquilibriumConstant = 1/(exp((4577.8/this.fTemperature)-4.33));
        
        end
        
        %%calculate outlet Molar Fluxes using the equilibrium constant
        function fMolarFluxOut1 = calculateMolFluxOut1(this)
            %index 1: Products (CO and H2O)
            fMolarFluxOut1 = this.fTotalMolarFlux/(2*((1/(this.fEquilibriumConstant^0.5))+1));
            
        end
        
        
        function fMolarFluxOut2 = calculateMolFluxOut2(this)
            %index 2: Educts (CO2 and H2)
            fMolarFluxOut2 = this.fTotalMolarFlux/(2*(1+(this.fEquilibriumConstant^0.5)));
        
        end
        
        %calculate CO2 Conversion
        function rConversionCO2 = calculateConversion(this)
            rConversionCO2 = this.fMolarFluxOutCO/this.fMolarFluxInCO2;
            
        end
        
        %%calculate reaction rate (for more details see thesis)
        function fVolumeFlowIn = calculateVolumeFlow(this)
            %calculate Volume Flow to Calculate concentration. The gas that
            %is used is assumed to be ideal, so the ideal gas law is used.
            fVolumeFlowIn = (this.fTotalMolarFlux*this.fGasConstant*this.fTemperature)/this.fPressure;
            
        end
        
        function fPartialPressure = calculatePartialPressure(this, fMolarFluxIn)
            %calculate Partial Pressure
            fFactorToPSI = 6894.75729;
            fPartialPressure = ((fMolarFluxIn*this.fGasConstant*this.fTemperature)/this.fVolumeFlowIn)/fFactorToPSI;
         
        end
        
        function fVelocityConstant = calculateVelConstant(this)
            %calculate velocity constant
            fVelocityConstant = this.fPreExpFactor * exp(-this.fActivationEnergy/(this.fTemperature*this.fGasConstant));
            
        end
        
        function fReactionRate = calculateReactionRate(this)
            %calculate reaction rate
            fReactionRate = this.fVelocityConstant*(this.fPartialPressureInH2^this.fAlpha)*(this.fPartialPressureInCO2^this.fBeta);
            
        end
        
    end
    
end



