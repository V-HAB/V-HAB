classdef H2_Absorber < matter.procs.p2ps.flow
    %absorbs the whole inflow of the O2
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Defines which substances are extracted
        arExtractPartials;
        fFlow=0;
        
    end
    
    
    methods
        function this = H2_Absorber(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            this.arExtractPartials(this.oMT.tiN2I.H2) = 1;
        end
        
        function update(this)
            
            if  this.oStore.oContainer.fI>0
                
                
                
                if this.oStore.toPhases.H2O2.fMass>0.01
                    
                    this.fFlow=this.oStore.oContainer.oManipulator.fMassH2;
                else
                    this.fFlow=0;
                end
                
                
                
            else
                this.fFlow=0;
            end
            this.setMatterProperties(this.fFlow, this.arExtractPartials);
            % this.oStore.oContainer.ch2.setFlowRate(this.fFlow);
            
        end
    end
    
end

