classdef Breathing_Carbon_Supply < matter.procs.p2ps.flow
    
    % A phase manipulator to add the required carbon for the breathing
    % simulation to the breathing process phase (its taken from the solid
    % food phase)
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
    end
    
    methods
        function this = Breathing_Carbon_Supply(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.C)   = 1;
            
        end
        
        function update(this)
            
            fFlowRate = this.oOut.oPhase.toManips.substance.fRequiredCMassFlow;
                
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
        end
    end
end