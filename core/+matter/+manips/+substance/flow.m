classdef (Abstract) flow < matter.manips.substance
    % flow manipulator which can be used inside of flow phases to calculate
    % mass transformations
    
    properties (SetAccess = protected)
        % Changes in partial masses in kg/s
        afPartialFlows;
    end
    
    methods
        function this = flow(sName, oPhase)
            this@matter.manips.substance(sName, oPhase);
            
            if ~this.oPhase.bFlow
                % Manips of this type are intended to be used in conjunction
                % with a flow phase which has no mass. If you want to use a
                % manip in a normal phase please use the stationary manip type!
                this.throw('manip', 'The flow manip %s is not located in a flow phase. For normal phases use stationary manips!', this.sName);
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
    
    methods (Abstract)
        % This function is called by the multibranch solver, which also
        % calculates the inflowrates and partials 
        %
        % afInFlowRates: vector containin the total mass flowrates entering
        %                the flow phase
        % aarInPartials: matrix containing the corresponding partial mass
        %                ratios of the inflowrates
        %
        % You can use afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
        % to calculate the total partial inflows in kg/s
        calculateConversionRate(this, afInFlowRates, aarInPartials);
    end
end

