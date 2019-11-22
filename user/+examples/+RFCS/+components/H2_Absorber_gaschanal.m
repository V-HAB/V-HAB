classdef H2_Absorber_gaschanal < matter.procs.p2ps.flow
    %absorbs the whole inflow of the O2
    
    properties (SetAccess = protected, GetAccess = public)
        
        
        % Defines which substances are extracted
        arExtractPartials;
        lastexec=0;
        y=0;
        u=0;
        e_int=0;
        
    end
    
    
    methods
        function this = H2_Absorber_gaschanal(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            
            this.arExtractPartials(this.oMT.tiN2I.H2) = 1;
        end
        
        function update(this)
            
            ftau=1; %time konstant anode
            
            h=this.oTimer.fTime-this.lastexec;
            
            this.u=this.oStore.oContainer.oManipulator.FlowRateH2;
            if h<1
                this.y=this.y+h*(this.u-this.y)*ftau;
            end
            
            
            
            this.setMatterProperties(this.y, this.arExtractPartials);
            
            
            this.lastexec=this.oTimer.fTime;
            
            this.oStore.oContainer.oBranch1.setFlowRate(this.u);
            
            
            
        end
    end
    
end

