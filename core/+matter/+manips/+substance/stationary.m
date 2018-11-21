classdef stationary < matter.manips.substance
    % stationary manipulator which can be used in normal phases to
    % calculate mass transformations
    
    properties (SetAccess = protected)
        afPartialFlows;
    end
    
    methods
        function this = stationary(sName, oPhase)
            this@matter.manips.substance(sName, oPhase);
            
            if this.oPhase.bFlow
                % Manips of this type are intended to be used in conjunction
                % with a flow phase which has no mass. If you want to use a
                % manip in a normal phase please use the stationary manip type!
                this.throw('manip', 'The stationary manip %s is located in a flow phase. For flow phases use flow manips!', this.sName);
            end
        end
        
        function update(this, afPartialFlows)
            % Checking if any of the flow rates being set are NaNs. It is
            % necessary to do this here so the origin of NaNs can be found
            % easily during debugging. 
            if any(isnan(afPartialFlows))
                error('Error in manipulator %s. Some of the flow rates are NaN.', this.sName);
            end
            
            this.afPartialFlows = afPartialFlows;
        end
    end
    
    methods (Access = protected)
        function afMass = getTotalMasses(this)
            % Get all inward mass flows multiplied with the time step and 
            % add them the stored partial masses to get an absolute value 
            % in kg. 
            
            [ afMasses, mrInPartials ] = this.getMasses();
            
            
            if ~isempty(afMasses)
                afMass = sum(bsxfun(@times, afMasses, mrInPartials), 1);
            else
                afMass = zeros(1, this.oMT.iSpecies);
            end
            
        end
        
        function [ afInMasses, mrInPartials ] = getMasses(this)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow MULTIPLIED with current time
            % step so the become absolute masses. Then the currently stored
            % mass is added!
            
            % Get last time step
            fTimeStep = this.getTimeStep();
            
            % Initializing temporary matrix and array to save the per-exme
            % data. 
            mrInPartials = zeros(this.oPhase.iProcsEXME, this.oMT.iSubstances);
            afInMasses   = zeros(this.oPhase.iProcsEXME, 1);
            
            % Creating an array to log which of the flows are not in-flows
            abOutFlows = true(iNumberOfEXMEs, 1);
            
            % See phase.getTotalMassChange
            for iI = 1:this.oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, ~ ] = this.oPhase.coProcsEXME{iI}.getFlowData();
                
                % Inflowing?
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials(iI,:) = mrFlowPartials(abInf, :);
                    afInMasses(iI)     = afFlowRates(abInf);
                    abOutFlows(iI)     = false;
                end
            end
            
            % Now we delete all of the rows in the mrInPartials matrix
            % that belong to out-flows.
            if any(abOutFlows)
                mrInPartials(abOutFlows,:) = [];
                afInMasses(abOutFlows,:)   = [];
            end
            
            mrInPartials = [ mrInPartials;  this.oPhase.arPartialMass ];
            afInMasses   = [ afInMasses * fTimeStep; this.oPhase.fMass ];
        end
    end
    
end

