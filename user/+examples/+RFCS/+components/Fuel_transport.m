classdef Fuel_transport < matter.procs.p2ps.flow
    % transports all the "new" water from the mixed absorber phase to
    % the liquid phase of the membrane
    properties (SetAccess = public, GetAccess = public)
        
        arExtractPartials;
        fLastExec = 0;
        fFlow=0;
        flowrateH2=0;
        flowrateO2=0;
        t=0;
        lastexec=0;
        laststate;
        fdo=0;
        fdh=0;
        delta=0;
        flowrate_alt=0;
        e_int=0;
    end
    
    methods
        
        function this = Fuel_transport(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn,sPhaseOut);
            
            %define which substances should be transported
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            
        end
        
        function update(this)
            
            
            %mass ratio of the educts
            k=this.oMT.afMolarMass(this.oMT.tiN2I.O2)/(this.oMT.afMolarMass(this.oMT.tiN2I.H2)*2);
            
            %flowrate form the root system
            fFlowRateH2=this.oStore.oContainer.oManipulator.FlowRateH2;
            
            
            faH2=1/(1+k); %share of h2 on flowrate
            faO2=faH2*k;  %share of o2 on flowrate
            
            fFlowRate=fFlowRateH2/faH2; %overall flowrate
            
            
            
            this.arExtractPartials(this.oMT.tiN2I.H2) = faH2;
            this.arExtractPartials(this.oMT.tiN2I.O2) = faO2;
            
            
            this.setMatterProperties(fFlowRate,this.arExtractPartials);
            this.fFlow=fFlowRate;
            
            
            
            
            
        end
    end
    
end
