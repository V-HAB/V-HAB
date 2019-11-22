classdef H2O2_transport < matter.procs.p2ps.flow
    % transports all the water from the mixed absorber phase to
    % the liquid phase of the membrane
    properties (SetAccess = public, GetAccess = public)
        
        arExtractPartials;
        
    end
    
    methods
        
        function this = H2O2_transport(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn,sPhaseOut);
            
            %define which substances should be transported
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            %calculate the substance fractions of the overall massflow
            k=this.oMT.afMolarMass(this.oMT.tiN2I.O2)/(this.oMT.afMolarMass(this.oMT.tiN2I.H2)*2+this.oMT.afMolarMass(this.oMT.tiN2I.O2));
            
            this.arExtractPartials(this.oMT.tiN2I.H2) = 1-k;
            this.arExtractPartials(this.oMT.tiN2I.O2) = k;
        end
    end
    
    methods (Access = protected)
        function update(this)
            % calculate the overall massflow to the next phase
            fflowrateH2=this.oStore.oContainer.oManipulator.fMassH2;
            fflowrateO2=this.oStore.oContainer.oManipulator.fMassO2;
            
            fflowrate=fflowrateH2+fflowrateO2;
            
            this.setMatterProperties(fflowrate, this.arExtractPartials);
            
            % set the flowrate to the gaschanal store
            if this.oStore.toPhases.gas_output.fMass>0.01
                this.oStore.oContainer.pipe.setFlowRate(fflowrateH2+fflowrateO2);
            else
                this.oStore.oContainer.pipe.setFlowRate(0);
            end
        end
    end
end
