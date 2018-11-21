classdef CHX_p2p < matter.procs.p2ps.flow & event.source
    
    %% p2p proc for a condensing heat exchanger
    %this p2p proc has to be added to a store DOWNSTREAM of the actual heat
    %exchanger (CHX). The actual calculation about how much and what
    %substances condense takes place in the CHX model itself and is saved
    %as a variable in it so this processor only takes these values and does
    %the actual phase change. The p2p however does need the object of the
    %condensing heat exchanger as input (this way it is also ensured that
    %noone tries to use it without the condensing heat exchanger)
    
    properties (SetAccess = protected, GetAccess = public)
        oCHX;
        % Defines which species are extracted
        arExtractPartials;
    end
    
    
    methods
        function this = CHX_p2p(oStore, sName, sPhaseIn, sPhaseOut, oCHX)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            if ~isprop(oCHX, 'sCondensateMassFlow')
                error('the CHX_p2p processor only works in combination with a condensing heat exchanger')
            end
            this.oCHX = oCHX;
            % to allow parent function to bind functions to the update
            % function of the P2P (help with the recalculation of the CHX
            % outlet flows
            this.trigger('update');
        end
        
        function calculateFlowRate(this, ~, ~)
            this.update();
        end
            
        function update(this)
            % Called whenever a flow rate changes. The two EXMES (oIn/oOut)
            % have an oPhase attribute that allows us to get the phases on
            % the left/right side.
            % Here, the oIn is always the air phase, the oOut is the solid
            % absorber phase.
            
            % The tiN2I maps the name of the species to the according index
            % in all the matter table vectors!
            
            sCondensateMassFlow = this.oCHX.sCondensateMassFlow;
            
            if ~isempty(sCondensateMassFlow)
                fFlowRate = 0;
                acCondensateNames = fieldnames(sCondensateMassFlow);
                %first the overall flowrate of condensate has to be
                %calculated
                for k = 1:length(acCondensateNames)
                    fFlowRate = fFlowRate + sCondensateMassFlow.(acCondensateNames{k});
                end
                %then the partials for each substance have to be calculated
                %this is basically the factor with which the overall flow
                %rate has to be multiplied to get the individual flow rate
                this.arExtractPartials = zeros(1, this.oMT.iSubstances);
                if fFlowRate ~= 0
                    for k = 1:length(acCondensateNames)
                        this.arExtractPartials(this.oMT.tiN2I.(acCondensateNames{k})) = sCondensateMassFlow.(acCondensateNames{k})/fFlowRate; 
                    end
                end
            else
                fFlowRate = 0;
                this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            end
                
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
end

