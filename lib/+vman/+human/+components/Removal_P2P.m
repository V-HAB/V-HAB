classdef Removal_P2P < matter.procs.p2ps.flow
    
    % A phase manipulator to remove the waste that were produced from the
    % consumed food (waste is not feces, waste in this case is all the
    % other solid products, like growing hair, nails etc)
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
        sSubstance;
    end
    
    methods
        function this = Removal_P2P(oStore, sName, sPhaseIn, sPhaseOut, sSubstance)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.(sSubstance)) = 1;
            this.sSubstance = sSubstance;
            
        end
        
        function update(this)
            
            fTimeStep = this.oIn.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            %very small time steps are simply skipped by this calculation.
            %It is exectued at most every 0.1 seconds
            if fTimeStep <= 0.1
                return
            end
            
            fFlowRate = this.oIn.oPhase.afMass(this.oMT.tiN2I.(this.sSubstance)) / fTimeStep;
                
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
        end
    end
end