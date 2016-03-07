classdef Urine_Production < matter.procs.p2ps.flow
    
    % A phase manipulator to remove water from the liquid digestion system
    % and put it in the bladder (the water part of the urine)
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
        
        afInitialMassLiquidFood;
    end
    
    methods
        function this = Urine_Production(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.afInitialMassLiquidFood = this.oIn.oPhase.afMass;
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O)   = 1;
            
        end
        
        function update(this)
            
            fTimeStep = this.oIn.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            %very small time steps are simply skipped by this calculation.
            %It is exectued at most every 0.1 seconds
            if fTimeStep <= 0.1
                return
            end
            % According to BVAD table 3.26 on page 50 a human nominally
            % produces 1.6 kg of urine water per day
            fBaselineFlowRate = 1.8519e-05; % 1.6/(24*3600)
            
            % But if more water is consumed the production of urine water
            % should also increase:
            afMassCurrent = this.oIn.oPhase.afMass - this.afInitialMassLiquidFood;
            
            % TO DO: once the food property table is implemented in V-HAB
            % use it to find out all possible names for food for V-HAB and
            % use that to decide the total food mass in the phase.
            % Currently it only uses the carbon mass.
            fWaterMass       = afMassCurrent(this.oMT.tiN2I.H2O);
            
            % Water is considered to be excess water over the nominal limit
            % if the water mass in the liquid digestion system exceeds 3.5
            % kg per crew member. 3.5 kg is the total water nominal
            % released as humidity/urine water according to BVAD table 3.26
            % on page 50. I know its not perfect but it is good enough for
            % now
            if fWaterMass > (this.oIn.oPhase.oStore.oContainer.iCrewMembers * 3.5)
                fExcessWaterMass = fWaterMass - (this.oPhase.oStore.oContainer.iCrewMembers * 3.5);
                
                fAdditionalUrineFlow = fExcessWaterMass / (24*3600);
            else
                fAdditionalUrineFlow = 0;
            end
            
            fFlowRate = fBaselineFlowRate + fAdditionalUrineFlow;
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
        end
    end
end