classdef CRA_Sabatier_manip_proc < matter.manips.substance.flow
    
    %A phase manipulator to simulate the sabatier reaction. It uses the
    %whole mass of CO2 and H2 from the phase it is assigned to check how
    %much CO2 and H2 can at best react with each other (assuming the
    %specified efficiency) according to the chemical reaction. If a
    %surplus of CO2 is supplied this does not react and simply remains in
    %the reactor, the same happens for H2 if too much H2 is available. It
    %then calculated the produced heat flow based and educt flow rates
    %based on the actual reacting amount of H2 and CO2.
    
    properties (SetAccess = protected, GetAccess = public)
        fH2OProduction;
        fCH4Production;
        fH2Reduction;
        fCO2Reduction;
        
        mPartialConversionFlowRates;
        
        fEfficiency = 1;            % Conversion efficiency
        
        fHeatFlowProduced = 0;
    end
    
    methods
        function this = CRA_Sabatier_manip_proc(sName, oPhase, fEfficiency)
            this@matter.manips.substance.flow(sName, oPhase);
            
            if nargin == 3
                this.fEfficiency = fEfficiency;
            end
            
            this.mPartialConversionFlowRates = zeros(1, this.oPhase.oMT.iSubstances); 
        end
        function calculateConversionRate(this, afInFlowRates, aarInPartials)
            
            %initializes the flowrates for each individual substance of this manipulator to 0
            this.mPartialConversionFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            
            if ~(isempty(afInFlowRates) || all(sum(aarInPartials) == 0))
                afPartialInFlowRates = sum((afInFlowRates .* aarInPartials),1);
            else
                this.fH2OProduction     = 0;
                this.fCH4Production     = 0;
                this.fH2Reduction       = 0;
                this.fCO2Reduction      = 0;

                this.fHeatFlowProduced  = 0;
                
                this.update();
                return
            end
            
            %saves the tiN2I struct that contains the number for each
            %substance according to its name to make the calls to it
            %simpler
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            %get the amount of mol in the sabatier reactor for H2 and CO2
            fMolMassCO2 = this.oPhase.oMT.afMolarMass(tiN2I.CO2); %kg/mol
            fMolMassH2 = this.oPhase.oMT.afMolarMass(tiN2I.H2); %kg/mol
            
            %The reaction uses the overall mass of CO2 and H2 that is in
            %the reactor to check the molar ratio between those two. The
            %residual mass is assumed to be unable to react.
            if this.oPhase.afMass(tiN2I.CO2) > 0
                %For very small time steps this calculation might become
                %unstable since it would suggest a very high mol flow rate.
                fMolCO2 = (afPartialInFlowRates(tiN2I.CO2)/fMolMassCO2); %mol/s
            else
                %if no CO2 is available nothing can react and the
                %calculation is finished
                this.update();
                return
            end
            if this.oPhase.afMass(tiN2I.H2) > 0
                %For very small time steps this calculation might become
                %unstable since it would suggest a very high mol flow rate.
                fMolH2 = (afPartialInFlowRates(tiN2I.H2)/fMolMassH2); %mol/s
            else
                %if no H2 is available nothing can react and the
                %calculation is finished
                this.update();
                return
            end
            
            %The Sabatier reaction is 4H2 + CO2 --> 2H2O + CH4 so 4 mol of
            %H2 are required per mol of CO2. If there is too much H2 some
            %of it is left after the reaction and if there is too little H2
            %some CO2 is left after the reaction
            if fMolH2 > 4*fMolCO2
                fMolH2used = 4*fMolCO2*this.fEfficiency;
                fMolCO2used = fMolCO2*this.fEfficiency;
            elseif fMolH2 < 4*fMolCO2
                fMolH2used = fMolH2*this.fEfficiency;
                fMolCO2used = 0.25*fMolH2*this.fEfficiency;
            else
                %this case covers a fully stochiometric reaction
                fMolH2used = fMolH2*this.fEfficiency;
                fMolCO2used = fMolCO2*this.fEfficiency;
            end
            
            %according to "Modeling,Simulation, and Operation of a Sabatier
            %Reactor" by Peter J. Lunde in Ind. Eng. Chem.,  Process Des. Develop., Vol. 13, No. 3, 1974
            %on page 228 the reaction enthalpy is -39.433 cal/mol
            fReactionEnthalpy = abs(1.8*(-16.4*this.oPhase.fTemperature+(0.00557*this.oPhase.fTemperature^2)-(112000/this.oPhase.fTemperature)-34633)*4.184); %J/mol
            
            %this means the overall released heat flow is
            this.fHeatFlowProduced = fReactionEnthalpy*(fMolH2used+fMolCO2used); %J/s
            %the heat flow is only saved as property since this manipulator
            %is not able to increase the temperature. Instead a f2f heater
            %can use this property to calculate the temperature increase
            
            %Now the mol values have to be converted back to masses again
            this.fCO2Reduction  = fMolCO2used*fMolMassCO2; %kg/s
            this.fH2Reduction   = fMolH2used*fMolMassH2; %kg/s
            
            %also the production of water and methan has to be calculated.
            %As can be seen from the reaction 4H2 + CO2 --> 2H2O + CH4 for
            %every 4mol of H2 and 1 mol of CO2 the reactor generates 2 mol
            %of water and one mol of methan. Basically for 5mol of input it
            %generated 3 mol of output split into 2/3 water and 1/3 methan.
            %But since the chemical equation does not end in a closed mass
            %balance: (4*fMolMassH2+fMolMassCO2) - (2*fMolMassWater+fMolMassMethan) ~= 0
            %It is necessary to transform these mol ratios into a mass
            %ratio for how much of the mass flow that is produced is
            %methance and how much is water:
            fMolMassWater = this.oPhase.oMT.afMolarMass(tiN2I.H2O); %kg/mol
            fMolMassMethane = this.oPhase.oMT.afMolarMass(tiN2I.CH4); %kg/mol
            rCH4Ratio = fMolMassMethane/(2*fMolMassWater+fMolMassMethane);
            rH2ORatio = 1-rCH4Ratio;
            %Then using the total mass flow that is used in the reaction it
            %is possible to calculate the mass flows of water and methane
            %that are generated:
            fTotalMassFlowUsed = this.fCO2Reduction+this.fH2Reduction; %kg/s
            
            this.fCH4Production = fTotalMassFlowUsed*rCH4Ratio; %kg/s
            this.fH2OProduction = fTotalMassFlowUsed*rH2ORatio; %kg/s
            
            %These flow rates are then set for the respective entry for
            %this subsatnce in the flow rates vector which is then used to
            %update the manipulator.
            this.mPartialConversionFlowRates(tiN2I.CO2)   =   - this.fCO2Reduction;    %kg/s
            this.mPartialConversionFlowRates(tiN2I.H2)    =   - this.fH2Reduction;     %kg/s
            this.mPartialConversionFlowRates(tiN2I.H2O)   = this.fH2OProduction;       %kg/s
            this.mPartialConversionFlowRates(tiN2I.CH4)   = this.fCH4Production;       %kg/s
            
            %In order to prevent numerical errors in the calculation from
            %creating or destroying mass the educt mass flow is adapted.
            %This will not work in every case and sometimes mass will still
            %be created/destroyed but only on the order of magnitude of
            %e-22 to e-20 which is neglegible
            this.mPartialConversionFlowRates(tiN2I.CH4) = this.mPartialConversionFlowRates(tiN2I.CH4) - 0.5*sum(this.mPartialConversionFlowRates);
            this.mPartialConversionFlowRates(tiN2I.H2O) = this.mPartialConversionFlowRates(tiN2I.H2O) - 0.5*sum(this.mPartialConversionFlowRates);
            
            this.update();
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            update@matter.manips.substance.flow(this, this.mPartialConversionFlowRates);
        end
    end
end