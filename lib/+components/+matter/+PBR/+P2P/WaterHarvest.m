classdef WaterHarvest < matter.procs.p2ps.flow
    %WATERHARVEST can harvest water out of the harvester in the
    %PBR system. This P2P operates on the logic that an equal amount of
    %water is harvested to what is supplied through urine. This P2P's flow
    %rate is therefore set by the urine supply branch and has no further
    %logic implemented
    
    
    properties (SetAccess=public, GetAccess=public)
        arExtractPartials   
        oSystem                                     %PBR system

    end
    
    methods
        
        
        function this = WaterHarvest (oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P,oSystem)
            this@matter.procs.p2ps.flow(oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P);
            this.oSystem = oSystem; %chlorella in Media

            %% P2P-relevant Properties
            %instantiate Extract Partials array
            this.arExtractPartials = zeros(1,this.oMT.iSubstances);
            %tell which substances. Can be more than one substance, but
            %then the sum of all together should be one since it represents
            %the full flow. Can also be changed during sim with update
            %function.
            this.arExtractPartials(this.oMT.tiN2I.H2O) = 1;
            
        end
        
        function calculateFlowRate(this, ~, ~, ~, ~)
            %% Set Flow Rate and update time of last execution for next calculation
            %tell that this matter should be removed
            %urine flow comes from parent sys, so is defined negative.
            %phaseIn for this p2p is harvester and out is water storage, so
            %has to be defined positive.
            %flow rate is always equal to waht is flowing into growth
            %medium when urine is supplied.
            oFlowUrine              = this.oSystem.toBranches.Urine_from_PBR.aoFlows;
            arResolvedMassesUrine   = this.oMT.resolveCompoundMass(oFlowUrine.arPartialMass, oFlowUrine.arCompoundMass);
            
            oFlowNitrate            = this.oSystem.toBranches.NO3_from_Maintenance.aoFlows;
            arResolvedMassesNitrate = this.oMT.resolveCompoundMass(oFlowNitrate.arPartialMass, oFlowNitrate.arCompoundMass);
            
            fFlowRateUrine          = -oFlowUrine.fFlowRate  	* arResolvedMassesUrine(this.oMT.tiN2I.H2O);
            fFlowRateNitrate        = -oFlowNitrate.fFlowRate	* arResolvedMassesNitrate(this.oMT.tiN2I.H2O);
            
            oChlorella = this.oStore.oContainer.toChildren.ChlorellaInMedia;
            
            fWaterSurplus = (oChlorella.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.H2O) - oChlorella.tfGrowthChamberComponents.H2O) / (2 * this.oStore.oContainer.fTimeStep);
            
            fFlowRate = fFlowRateUrine + fFlowRateNitrate + fWaterSurplus;
            
            this.setMatterProperties(fFlowRate, this.arExtractPartials);

        end
        
    end
    
    methods (Access = protected)
        function update(~)
            % this must be here since the normal V-HAB logic tries to
            % call the update
        end
    end
end

