classdef O2Pump < matter.procs.p2ps.stationary
    %O2PUMP moves O2 from the high CO2 content chamber of the PBR that supplies the algae into the cabin air intrface 
    
    properties (SetAccess=public, GetAccess=public)
        arExtractPartials
        oSystem

        fStartPumpingO2PP       %[Pa] lower limit of oxygen partial pressure. stop pumping out of high content phase
        fEndPumpingO2PP;        %[Pa] upper limit of oxygen partial pressure. start pumping out of high content phase
        fSeparationFactor;      %[-] similar to a filter efficiency. Can be between 0 and 1.
        fCurrentPP;             %[Pa] current oxygen partial pressure in the high carbon dioxide content phase
        fCurrentMass;           %[kg] mass of oxygen in flow phase (used to not take more than available)
        bPumpActive;            %[boolean] to state if pump should be active.
    end
    
    methods
        
        
        function this = O2Pump (oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P,oSystem)
            this@matter.procs.p2ps.stationary(oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P);
            this.oSystem = oSystem;
            
             %% control parameters
            this.fStartPumpingO2PP = 6000; %[Pa] in high Co2 content chamber
            this.fEndPumpingO2PP = 4000; %[Pa] in high co2 content chamber
            this.fSeparationFactor = 1; %similar to a filter efficiency. Can be between 0 and 1.
            this.bPumpActive = false; %initially to 0, no pumping. will be set to true when pumping required.
            
            %% P2P-relevant Properties
            %instantiate Extract Partials array
            this.arExtractPartials = zeros(1,this.oMT.iSubstances);
            %tell which substances. Can be more than one substance, but
            %then the sum of all together should be one since it represents
            %the full flow. Can also be changed during sim with update
            %function.
            this.arExtractPartials(this.oMT.tiN2I.O2) = 1;
            

            
        end
        
        function calculateFlowRate(this, ~, ~, ~, ~)
            
            this.fCurrentPP = this.oOut.oPhase.afPP(this.oMT.tiN2I.O2);
            %hysteresis behavior: only start when above start partial pressure and only end
            %when above end partial pressure
            if this.fCurrentPP > this.fStartPumpingO2PP
                this.bPumpActive = true;
            elseif this.fCurrentPP < this.fEndPumpingO2PP
                this.bPumpActive = false;
            end

            
            if this.bPumpActive == true
                this.fCurrentMass = this.oSystem.toStores.ReactorAir.toPhases.HighCO2Air.afMass(this.oMT.tiN2I.O2);
                fFlowRate = (this.fCurrentMass*this.fSeparationFactor)/(this.oSystem.fTimeStep*20); %need fairly small flow rate since wedon't want it to overshoot too much until the next update (reduction of only 20% desired)
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
