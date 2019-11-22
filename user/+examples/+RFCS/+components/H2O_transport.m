classdef H2O_transport < matter.procs.p2ps.stationary
    % transports all the water from the mixed absorber phase to
    % the liquid phase of the membrane
    properties (SetAccess = public, GetAccess = public)
        
        arExtractPartials;
        
        
        
        
    end
    
    methods
        
        function this = H2O_transport(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn,sPhaseOut);
            
            %define which substances should be transported
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O) = 1;
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            
            
            fflowrate=this.oStore.oContainer.oManipulator.fMassH2O;
            
            
            this.setMatterProperties(fflowrate, this.arExtractPartials);
            
            
            
        end
    end
end
