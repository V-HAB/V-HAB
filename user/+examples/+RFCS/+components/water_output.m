classdef water_output < matter.procs.p2ps.flow
    % transports all the "new" water from the mixed absorber phase to
    % the liquid phase of the membrane
    properties (SetAccess = public, GetAccess = public)
        
        arExtractPartials;
        fFlowRate_H2O=0;
        
        
    end
    
    methods
        
        function this = water_output(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn,sPhaseOut);
            
            %define which substances should be transported
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            this.arExtractPartials(this.oMT.tiN2I.H2O) =1;
            
        end
        
        function update(this)
            
            
            
            if this.oIn.oPhase.fMass>0.005
                
                this.fFlowRate_H2O=this.oStore.oContainer.P2P_1.fFlow;
                
            else
                this.fFlowRate_H2O=0;
            end
            
            
            this.setMatterProperties(this.fFlowRate_H2O,this.arExtractPartials);
            
            rHumidity_H2=this.oStore.oContainer.toStores.gaschanal_in_h2.toPhases.fuel.rRelHumidity;
            rHumidity_O2=this.oStore.oContainer.toStores.gaschanal_in_o2.toPhases.O2_H2O.rRelHumidity;
            
            
            
            if this.oOut.oPhase.fMass>0.5
                flowrate1=(100-rHumidity_H2)*10^-5;
                flowrate2=(100-rHumidity_O2)*10^-5;
            else
                flowrate1=0;
                flowrate2=0;
                this.fFlowRate_H2O=0;
            end
            
            fOutputwater=this.fFlowRate_H2O-flowrate1-flowrate2;
            if fOutputwater<0
                fOutputwater=0;
            end
            
            if flowrate1<0
                flowrate1=0;
            end
            
            if flowrate2<0
                flowrate2=0;
            end
            
            
            %              this.oStore.oContainer.oBranch3.setFlowRate(flowrate1);
            %              this.oStore.oContainer.oBranch4.setFlowRate(flowrate2);
            this.oStore.oContainer.oBranch5.setFlowRate(this.fFlowRate_H2O);
            %
            
        end
    end
    
end
