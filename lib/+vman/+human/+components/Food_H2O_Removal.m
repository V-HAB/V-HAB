classdef Food_H2O_Removal < matter.procs.p2ps.flow
    
    % A phase manipulator to remove the water that the human took in with
    % the solid food
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
        fInitialFoodWaterMass;
    end
    
    methods
        function this = Food_H2O_Removal(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.fInitialFoodWaterMass = this.oIn.oPhase.afMass(this.oMT.tiN2I.H2O);
            
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
            % 1 kg is the residual mass of water that has to remain in the
            % phase. Therefore this p2p proc only removes water that
            % exceeds 1.01 kg
            if this.oIn.oPhase.afMass(this.oMT.tiN2I.H2O) > this.fInitialFoodWaterMass
                fFlowRate = (this.oIn.oPhase.afMass(this.oMT.tiN2I.H2O) - 1.01)/fTimeStep;
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