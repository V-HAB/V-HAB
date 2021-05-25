classdef BPA_Manip < matter.manips.substance.stationary
    
    properties (SetAccess = protected, GetAccess = public)
        % Urine conversion efficiency from "Closing the Water Loop for
        % Exploration: 2018 Status of the Brine Processor Assembly", Laura
        % K. Kelsey et.al., 2018, ICES-2018-272
        rBrineConversionEfficiency = 0.8;
        
        bActive = false;
        
        rInitialWaterInBrine = 0;
        rLastCalcWaterInBrine = 0;
        
        aarConcentratedBrineFlowsToCompound;
    end
    methods
        function this = BPA_Manip(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
        end
        
        function setActive(this, bActive)
            this.bActive = bActive;
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            % Initialize the array we pass back to the phase once we're
            % done
            afPartialFlows = zeros(1, this.oPhase.oMT.iSubstances);
            
            if(this.bActive) && (this.oPhase.afMass(this.oPhase.oMT.tiN2I.Brine) > 0)
                % Abbreviating some of the variables to make code more legible
                tiN2I      = this.oPhase.oMT.tiN2I;
                
                afResolvedMass = this.oPhase.oMT.resolveCompoundMass(this.oPhase.afMass, this.oPhase.arCompoundMass);
                
                afResolvedMass = afResolvedMass - this.oPhase.afMass;
                afResolvedMass(this.oMT.abCompound) = 0;
                
                rWaterInBrine = afResolvedMass(tiN2I.H2O) / this.oPhase.fMass;
                
                if rWaterInBrine > this.rLastCalcWaterInBrine
                    % In this case we are processing a new batch and
                    % therefore have to calculate the new brine composition
                    this.rInitialWaterInBrine = rWaterInBrine;
                    
                    rConcentratedBrineWaterContent = (1 - this.rBrineConversionEfficiency) * this.rInitialWaterInBrine;
                    afConcentratedBrineMasses = afResolvedMass;
                    afConcentratedBrineMasses(tiN2I.H2O) = afResolvedMass(tiN2I.H2O) * rConcentratedBrineWaterContent;
                    this.aarConcentratedBrineFlowsToCompound = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
                    this.aarConcentratedBrineFlowsToCompound(tiN2I.ConcentratedBrine, :) = afConcentratedBrineMasses ./ sum(afConcentratedBrineMasses);
                
                end
                
                % Now we can fill the arPartials array which indicates the mass
                % change in the phase affected by the manipulator. The urine mass
                % is negative, the urea and H2O masses are positive. This
                % means that effectively all urine is converted to urea and
                % water.
                afPartialFlows(tiN2I.Brine)     = -1 * this.oPhase.oStore.oContainer.fBaseFlowRate;
                
                afPartialFlows(tiN2I.H2O)       = this.rBrineConversionEfficiency * this.rInitialWaterInBrine * this.oPhase.oStore.oContainer.fBaseFlowRate;
                
                afPartialFlows(tiN2I.ConcentratedBrine)     = this.oPhase.oStore.oContainer.fBaseFlowRate - afPartialFlows(tiN2I.H2O);
                
                % Now we can call the parent update method and pass on the
                % afPartials variable. The last parameter indicates that the
                % values in afPartials are absolute masses, so within the
                % update method they are converted to flow rates.
                update@matter.manips.substance(this, afPartialFlows, this.aarConcentratedBrineFlowsToCompound);
                
                afWaterP2PFlows = zeros(1, this.oPhase.oMT.iSubstances);
                afWaterP2PFlows(tiN2I.H2O) = afPartialFlows(tiN2I.H2O);
                this.oPhase.oStore.toProcsP2P.WaterP2P.setFlowRate(afWaterP2PFlows);
                
                this.rLastCalcWaterInBrine = rWaterInBrine;
            else
                update@matter.manips.substance(this, afPartialFlows);
                afWaterP2PFlows = zeros(1, this.oPhase.oMT.iSubstances);
                this.oPhase.oStore.toProcsP2P.WaterP2P.setFlowRate(afWaterP2PFlows);
            end
        end
    end
end