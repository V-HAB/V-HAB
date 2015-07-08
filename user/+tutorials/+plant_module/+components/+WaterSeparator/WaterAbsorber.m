classdef WaterAbsorber < matter.procs.p2ps.flow

    
    properties (SetAccess = protected, GetAccess = public)
        %Substances to absorb
            sSubstance;
        %Array for handling the matter that should be extracted
            arExtractPartials;
        %Parent System
            oParent;
        %Flowrate for Balancing in- and output flowrate of the seperator
        %'air'-phase
            fFlowValue;
        
    end
    
    methods
        function this = WaterAbsorber(oParent, oStore, sName, sPhaseIn, sPhaseOut, sSubstance)
                this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
                
                %Forwarding paramters
                    this.sSubstance = sSubstance;
                    this.oParent = oParent;
                    this.arExtractPartials = zeros(1, this.oMT.iSubstances);
                    this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;
                
        end
        
        function update(this)
                        
            %Assigning the position number of the substances to absorb in the
            %matter table
                iSubstances = this.oMT.tiN2I.(this.sSubstance);
            
            %...get the corresponding flowrate
                [ afFlowRate, mrPartials ] = this.getInFlows();

                if isempty(afFlowRate)
                    this.setMatterProperties(0, this.arExtractPartials);

                    return;
                end
        
            %Array, including the flowrates corresponding to all available matter
                afFlowRate = afFlowRate .* mrPartials(:, iSubstances);
        
            %Sum up all flows -> in this case only H2O flow
                fFlowRate = sum(afFlowRate);
           
            
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
        end
        
    end
end
