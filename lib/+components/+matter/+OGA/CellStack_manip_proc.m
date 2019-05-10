classdef CellStack_manip_proc < matter.manips.substance.stationary
    
    properties (SetAccess = protected, GetAccess = public)
        fO2 = 0;
        fElectrolyzedMassFlow; %changed name to flow since the unit is kg/s
        fO2Production;
        fH2Production;
        fH2 = 0;
        
        fEfficiency = 0.3;   % Electrolyzer efficiency (0.8 is used by T.Weber)
        fVoltage;
        fCurrent;
        fPower = 0;
        
        fTemperatureToFlow = 298.9777;   % Temperature to the flow
    end
    
    methods
        function this = CellStack_manip_proc(sName, oPhase, fOutflowTemperature)
            this@matter.manips.substance.stationary(sName, oPhase);
            this.fTemperatureToFlow = fOutflowTemperature;
        end
        
        function update(this)
            
            this.fCurrent = -6.992 * 10^(-7) * this.fPower^2 + 0.0219043626 * this.fPower + 0.0649761243;
            this.fVoltage = this.fPower / this.fCurrent;
            
            % Calculation of fFlowRateForAlpha
            [ afFlowRate, mrPartials ] = this.getInFlows();
            if isempty(afFlowRate)
%                 fFlowRate = 0;
                afFlowRate = zeros(1, this.oPhase.oMT.iSubstances);
            else
                afFlowRate= afFlowRate(1) * mrPartials(1, :);
%                 fFlowRate = sum(afFlowRate);
            end
            
            afPartials = zeros(1, this.oPhase.oMT.iSubstances);
            tiN2I      = this.oPhase.oMT.tiN2I;
            
            this.fElectrolyzedMassFlow = afFlowRate(tiN2I.H2O);
            
            if this.fElectrolyzedMassFlow < 0
                this.fElectrolyzedMassFlow = 0;
            end
            
            %The problem with this is, why would a mass flow higher than
            %what can be processed be put into the electrolyzer in the
            %first place. Also since V-HAB does not yet have a electrical
            %module the controlling parameter should be the inlet flowrate
            %up to a maximum processable flow rate.
            %Original Equation used to calculate the electrolyzed mass flow
            %that was rearranged and solved for the power instead
            %this.fElectrolyzedMassFlow = (-1.1718 * 10^(-6) * this.fPower^2 + 0.0117792082 * this.fPower - 0.0920321451) * 0.45359237 / (24 * 60 * 60);
            
            %calculation of the required power for th set electrolyzer mass
            %flow
            %Equation taken from the electrolyzer manip
            A = (-1.1718 * 10^(-6)* 0.45359237/ (24 * 60 * 60));
            B = 0.0117792082* 0.45359237 / (24 * 60 * 60);
            C = (- 0.0920321451* 0.45359237 / (24 * 60 * 60))-this.fElectrolyzedMassFlow;
            
            P_1 = (-B+sqrt(B^2-4*A*C))/(2*A);
            P_2 = (-B-sqrt(B^2-4*A*C))/(2*A);
            
            if (P_1 >= 0) && (P_2 >= 0)
                fNewPower = min(P_1, P_2);
            elseif (P_1 < 0) && (P_2 >= 0)
                fNewPower = P_1;
            elseif (P_1 >= 0) && (P_2 < 0)
                fNewPower = P_2;
            end
            
            this.fPower = fNewPower;
            
            this.fO2 = this.fElectrolyzedMassFlow * 8/9 + afFlowRate(tiN2I.O2);
            this.fO2Production = this.fElectrolyzedMassFlow * 8/9;
            this.fH2Production = this.fElectrolyzedMassFlow * 1/9;
            this.fH2 = this.fH2Production + afFlowRate(tiN2I.H2);
            
            afPartials(tiN2I.H2O) = - this.fElectrolyzedMassFlow;
            afPartials(tiN2I.O2)  = this.fO2Production;
            afPartials(tiN2I.H2)  = this.fH2Production;
            
            % updates the P2Ps at the same time, with the same flowrates as
            % the manip!
            afPartialsO2 = zeros(1,this.oMT.iSubstances);
            afPartialsO2(tiN2I.O2)  = this.fO2Production;
            
            this.oPhase.oStore.toProcsP2P.O2Proc.setFlowRate(afPartialsO2)
            
            afPartialsH2 = zeros(1,this.oMT.iSubstances);
            afPartialsH2(tiN2I.H2)  = this.fH2Production;
            this.oPhase.oStore.toProcsP2P.GLS_proc.setFlowRate(afPartialsH2)
            
            update@matter.manips.substance.stationary(this, afPartials);
            % set the corresponding flowrates to the P2Ps
            afFlowRateH2 = zeros(1,this.oMT.iSubstances);
            afFlowRateH2(this.oMT.tiN2I.H2) = afPartials(this.oMT.tiN2I.H2);
            this.oPhase.oStore.toProcsP2P.GLS_proc.setFlowRate(afFlowRateH2);
            
            afFlowRateO2 = zeros(1,this.oMT.iSubstances);
            afFlowRateO2(this.oMT.tiN2I.O2) = afPartials(this.oMT.tiN2I.O2);
            this.oPhase.oStore.toProcsP2P.O2Proc.setFlowRate(afFlowRateO2);
            
        end
        
        function setPower(this, fPower)
            this.fPower = fPower;
        end
    end
end