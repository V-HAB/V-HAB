classdef Urine_Removal < matter.procs.p2ps.flow
    
    % A phase manipulator to remove the feces that were produced from the
    % consumed food (feces are assumed to be a combination of the food and
    % some of the water, but the water is not modelled independently as a
    % seperated mass)
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
    end
    
    methods
        function this = Urine_Removal(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.Urine)   = 1;
            
        end
        
        function update(this)
            
            fTimeStep = this.oIn.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            %very small time steps are simply skipped by this calculation.
            %It is exectued at most every 0.1 seconds
            if fTimeStep <= 0.1
                return
            end
            % 
            if this.oIn.oPhase.afMass(this.oMT.tiN2I.Urine) > this.oIn.oPhase.oStore.oContainer.fInitialMassUrine
                fFlowRate = (this.oIn.oPhase.afMass(this.oMT.tiN2I.Urine) - this.oIn.oPhase.oStore.oContainer.fInitialMassUrine)/fTimeStep;
            else
                fFlowRate = 0;
            end
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
        end
    end
end