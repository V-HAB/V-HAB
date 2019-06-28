classdef CO2Pump < matter.procs.p2ps.flow
    %CO2PUMP moves CO2 from the cabin air intrface into the high CO2
    %content chamber of the PBR that supplies the algae. 
    
    properties (SetAccess=public, GetAccess=public)
        arExtractPartials
        oSystem
        fCurrentPP;         %[Pa], current partial pressure in the high carbon dioxide content phase
        fStartPumpingCO2PP  %[Pa], lower limit, when new CO2 is pumped into high content phase
        fEndPumpingCO2PP;   %[Pa], upper limit, when no more CO2 is pumped into high content phase
        fSeparationFactor;  %[-] similar to a filter efficiency. Can be between 0 and 1.
        bPumpActive;        %[boolean] to state if pump should be active.
    end
    
    methods
        
        
        function this = CO2Pump (oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P,oSystem)
            this@matter.procs.p2ps.flow(oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P);
            this.oSystem = oSystem;
            
            %% control parameters
            this.fStartPumpingCO2PP = 59000;%[Pa]
            this.fEndPumpingCO2PP = 60000;%[Pa]
            this.fSeparationFactor = 1; 
            %initially set to false --> no pumping
            this.bPumpActive = false;
                           
            %% P2P-relevant Properties
            %instantiate Extract Partials array
            this.arExtractPartials = zeros(1,this.oMT.iSubstances);
            %tell which substances. Can be more than one substance, but
            %then the sum of all together should be one since it represents
            %the full flow. Can also be changed during sim with update
            %function.
            this.arExtractPartials(this.oMT.tiN2I.CO2) = 1;
           
        end
        
        function calculateFlowRate(this, ~, ~, ~, ~)
            
            this.fCurrentPP = this.oOut.oPhase.afPP(this.oMT.tiN2I.CO2);
            %hysteresis behavior: only start when below start Partial
            %Pressure and only end when above endpp. update object property
            %fFlowRate and don't confuse with the variable fFlowRate
            if this.fCurrentPP < this.fStartPumpingCO2PP
                this.bPumpActive = true;
            elseif this.fCurrentPP > this.fEndPumpingCO2PP
                this.bPumpActive = false;
            end
            
            
            if this.bPumpActive == true
                [afFlowRate, mrPartials] = this.getInFlows();
                %element-wise matrix multiplication to get mass flow of
                %desired substance (in this case CO2)
                afCO2InFlows = afFlowRate .* mrPartials(:, this.oMT.tiN2I.CO2);

                fFlowRate = sum(afCO2InFlows)*this.fSeparationFactor; %[kg/s]
            else
                fFlowRate = 0;
            end
            
            %% Set Flow Rate and update time of last execution for next calculation
            %tell that this matter should be removed
            this.setMatterProperties(fFlowRate, this.arExtractPartials);

        end   
        
    end
    
    methods (Access = protected)
        function update(~)
            % this must be here since the normal V-HAB logic tries to
            % call the update
        end
    end
end

