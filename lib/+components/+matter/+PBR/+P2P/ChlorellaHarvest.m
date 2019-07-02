classdef ChlorellaHarvest < matter.procs.p2ps.flow
    %CHLORELLAHARVEST can harvest chlorella cells out of the harvester in the
    %PBR system to maintain a continuously growing continuously. The
    %harvester set point is defined by the growth rate calculation module
    %to ensure optimum growth.
    
    
    properties (SetAccess=public, GetAccess=public)
        arExtractPartials
        oSystem

        %continuous
        fFiltrationEfficiency                           %[-], between 0 and 1. 0 means nothing of specified substance is filtered, 1 means everything that flows into harvester flow phase
        fStartContinuousHarvestingBiomassConcentration  %[kg/m3] biomass concentration at which harvesting begins
        fEndContinuousHarvestingBiomassConcentration    %[kg/m3] biomass concentration at which harvesting ends

        % harvesting
        fCurrentBiomassConcentration                    %[kg/m3]
        bHarvest                                        %boolean to specify if harvesting should currently be performed
        fVolumetricFlow;                                %[kg/m3]incoming volumetric flow
    end
    
    methods
        
        
        function this = ChlorellaHarvest (oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P,oSystem)
            this@matter.procs.p2ps.flow(oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P);
            this.oSystem = oSystem; %connect to PBR system.
            
            %% harvesting parameters
            this.fStartContinuousHarvestingBiomassConcentration = this.oSystem.oParent.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule.fMaximumGrowthBiomassConcentration*0.97; %[kg/m3]
            this.fEndContinuousHarvestingBiomassConcentration = this.oSystem.oParent.toChildren.ChlorellaInMedia.oGrowthRateCalculationModule.fMaximumGrowthBiomassConcentration*1.03;%[kg/m3]
            this.fFiltrationEfficiency = 0.7; %[-] reference from Niederwieser 2018 (thesis reference [5])  with reference to E. H. Gomez, ?DEVELOPMENT OF A CONTINUOUS FLOW ULTRASONIC HARVESTING SYSTEM FOR MICROALGAE,? PhD Thesis, Colorado State University, Fort Collins, CO, 2014. Thesis Reference [110] 
            this.bHarvest = false;     %set to false initially, will be changed when chlorella concentration too high and set to zero again when below minimum
            this.fVolumetricFlow = this.oSystem.oParent.fVolumetricFlowToHarvester;
            %% P2P-relevant Properties
            %instantiate Extract Partials array
            this.arExtractPartials = zeros(1,this.oMT.iSubstances);
            
            %tell which substances. Can be more than one substance, but
            %then the sum of all together should be one since it represents
            %the full flow. Can also be changed during sim with update
            %function.
            this.arExtractPartials(this.oMT.tiN2I.Chlorella) = 1;

        end
        
        function calculateFlowRate(this, ~, ~, ~, ~)
            
            this.fCurrentBiomassConcentration = this.oSystem.oGrowthRateCalculationModule.fBiomassConcentration; %kg/m3
            
            %hysteresis behavior: only start when above start concentration and only end
            %when below end concentration. 
            if this.fCurrentBiomassConcentration > this.fStartContinuousHarvestingBiomassConcentration
                this.bHarvest = true;
            elseif this.fCurrentBiomassConcentration <= this.fEndContinuousHarvestingBiomassConcentration
                this.bHarvest = false;
            end
            
            if this.bHarvest == true
                [afFlowRate, mrPartials] = this.getInFlows();
                
                %element-wise matrix multiplication to get mass flow of desired substance
                %(in this case CO2)
                afChlorellaInFlows = afFlowRate .* mrPartials(:, this.oMT.tiN2I.Chlorella);

                fFlowRate = sum(afChlorellaInFlows)*this.fFiltrationEfficiency;

            else
                fFlowRate = 0;
            end

            %% Set Flow Rate and update time of last execution for next calculation
            %tell that this matter should be removed
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

