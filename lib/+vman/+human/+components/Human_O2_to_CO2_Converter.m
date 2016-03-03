classdef Human_O2_to_CO2_Converter < matter.manips.substance.flow
    
    %A phase manipulator to simulate conversion of O2 into CO2 inside the
    %human body. It does not use any other inputs except for O2 so the mass
    %balance is not closed.
                                    
    
    properties (SetAccess = protected, GetAccess = public)
       fLastUpdate;
       
       fRequiredCMassFlow = 0;
       
       fCO2_FlowRate = 0;
    end
    
    methods
        function this = Human_O2_to_CO2_Converter(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this.fLastUpdate = 0;
        end
        
        function update(this)
            
            fTimeStep = this.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            if fTimeStep <= 0
                return
            end
            
            arPartialFlowRates = zeros(1, this.oPhase.oMT.iSubstances);
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            %simply converts all the O2 in the human into CO2, since only
            %O2 that is consumed by the human goes into the phase it is not
            %necessary to regard the ~17% O2 that are left in the air when
            %a human breathes out
            fO2MassFlow     = this.oPhase.toProcsEXME.O2_In.oFlow.fFlowRate;
            
            fMolarMassO2    = this.oMT.ttxMatter.O2.fMolarMass;
            fO2MolFlow      = fO2MassFlow / fMolarMassO2; % mol/s
            
            % The required mol flow for C to produce CO2 from O2 is the
            % exact same as the O2 mol flow. therefore the required mass of
            % C can be calculated from the o2 mol flow
            fMolarMassCO2           = this.oMT.ttxMatter.C.fMolarMass;
            this.fRequiredCMassFlow = fO2MolFlow * fMolarMassCO2;
            
            % The overall CO2 mass flow then is the sum of the mass flows
            % of C and O2.
            this.fCO2_FlowRate      = fO2MassFlow + this.fRequiredCMassFlow;
            
            % Now the flow rates have to be set for the manip
            arPartialFlowRates(tiN2I.CO2)   =  this.fCO2_FlowRate;
            arPartialFlowRates(tiN2I.O2)    = -fO2MassFlow;
            arPartialFlowRates(tiN2I.C)     = -this.fRequiredCMassFlow;
            
            update@matter.manips.substance.flow(this, arPartialFlowRates);
            
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
        end
        
        
    end
end