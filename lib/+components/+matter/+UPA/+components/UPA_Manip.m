classdef UPA_Manip < matter.manips.substance.stationary
    
    properties (SetAccess = protected, GetAccess = public)
        % Urine conversion efficiency from Carter, Williamson et al. 2019 – Status of ISS Water Management
        rUrineConversionEfficiency = 0.85;
        
        bActive = false;
    end
    methods
        function this = UPA_Manip(sName, oPhase)
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
            
            if(this.bActive)
                % Abbreviating some of the variables to make code more legible
                tiN2I      = this.oPhase.oMT.tiN2I;
                
                afResolvedMass = this.oPhase.oMT.resolveCompoundMass(this.oPhase.afMass, this.oPhase.arCompoundMass);
                
                afResolvedMass = afResolvedMass - this.oPhase.afMass;
                afResolvedMass(this.oMT.abCompound) = 0;
                
                rWaterInUrine = afResolvedMass(tiN2I.H2O) / this.oPhase.afMass(tiN2I.Urine);
                rBrineWaterContent = (1 - this.rUrineConversionEfficiency) * rWaterInUrine;
                
                afBrineMasses = afResolvedMass;
                afBrineMasses(tiN2I.H2O) = afResolvedMass(tiN2I.H2O) * rBrineWaterContent;
                aarFlowsToCompound = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
                aarFlowsToCompound(tiN2I.Brine, :) = afBrineMasses ./ sum(afBrineMasses);
                
                % Now we can fill the arPartials array which indicates the mass
                % change in the phase affected by the manipulator. The urine mass
                % is negative, the urea and H2O masses are positive. This
                % means that effectively all urine is converted to urea and
                % water.
                afPartialFlows(tiN2I.Urine)     = -1 * this.oPhase.oStore.oContainer.fBaseFlowRate;
                
                afPartialFlows(tiN2I.H2O)       = this.rUrineConversionEfficiency * rWaterInUrine * this.oPhase.oStore.oContainer.fBaseFlowRate;
                
                afPartialFlows(tiN2I.Brine)     = this.oPhase.oStore.oContainer.fBaseFlowRate - afPartialFlows(tiN2I.H2O);
                
                % Now we can call the parent update method and pass on the
                % afPartials variable. The last parameter indicates that the
                % values in afPartials are absolute masses, so within the
                % update method they are converted to flow rates.
                update@matter.manips.substance(this, afPartialFlows, aarFlowsToCompound);
                
                afBrineP2PFlows = zeros(1, this.oPhase.oMT.iSubstances);
                afBrineP2PFlows(tiN2I.Brine) = afPartialFlows(tiN2I.Brine);
                this.oPhase.oStore.toProcsP2P.BrineP2P.setFlowRate(afBrineP2PFlows);
                
                afWaterP2PFlows = zeros(1, this.oPhase.oMT.iSubstances);
                afWaterP2PFlows(tiN2I.H2O) = afPartialFlows(tiN2I.H2O);
                this.oPhase.oStore.toProcsP2P.WaterP2P.setFlowRate(afWaterP2PFlows);
                
                this.oPhase.oStore.oContainer.toBranches.Outlet.oHandler.setFlowRate(afPartialFlows(tiN2I.H2O));
            else
                this.oPhase.oStore.toProcsP2P.BrineP2P.setFlowRate(zeros(1, this.oPhase.oMT.iSubstances));
                this.oPhase.oStore.toProcsP2P.WaterP2P.setFlowRate(zeros(1, this.oPhase.oMT.iSubstances));
                this.oPhase.oStore.oContainer.toBranches.Outlet.oHandler.setFlowRate(0);
                
                update@matter.manips.substance(this, afPartialFlows);
            end
        end
    end
end