classdef Food_H2O_Removal < matter.procs.p2ps.flow
    
    % A phase manipulator to remove the water that the human took in with
    % the solid food
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
    end
    
    methods
        function this = Food_H2O_Removal(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O)   = 1;
            
        end
        
        function update(this)
            
            fTimeStep = this.oIn.oPhase.oStore.oTimer.fTime-this.fLastUpdate;
            
            %very small time steps are simply skipped by this calculation.
            %It is exectued at most every 1 seconds
            if fTimeStep <= 1
                return
            end
            % feces are supposed to contain some amount of water therefore
            % this proc should not remove all water from the food phase to
            % allow the digestion simulation to use some for the feces
            % production:
            fFlowRate = (this.oIn.oPhase.afMass(this.oMT.tiN2I.H2O) - 0.05)/(10*fTimeStep);
            % If the solid food phase contains less than 50g of water the
            % water is taken from the liquid digestion system (for example
            % if the human eats very dry food)
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
        end
    end
end