classdef network < thermal.capacity
    %NETWORK A capacity intent for the use with the advanced thermal multi
    % branch solver. For this capacity, the thermal multi branch solver
    % handles the temperature calculation and everything else. 
    
    properties (GetAccess = public, SetAccess = protected)
        
    end
    
    methods
        function this = network(oPhase, fTemperature, bBoundary)
            % Calling the parent class constructor
            this@thermal.capacity(oPhase, fTemperature);
            
            if nargin > 2
                this.bBoundary = bBoundary;
            end
            
            this.setTimeStep(inf,true);
        end
        
        
        function updateTemperature(this, fTemperature)
            % Overloaded function, calculates some time step values and
            % sets the current one outdated. 
            
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastTemperatureUpdate;
            
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            % Since the advanced multi branch solver is the only thing
            % which actually knows the new temperature, and the solver
            % calls with a temperature value, we only set this if the
            % temperature is provided
            if nargin > 1
                this.setTemperature(fTemperature);
            end
            
            if this.bTriggerSetUpdateTemperaturePostCallbackBound
            	this.trigger('updateTemperature_post');
            end
        end
        
        function setOutdatedTS(this)
            % we overload the normal setOutdatedTS because instead of the
            % capacity, we should inform the thermal multi branch solver
            % that it should update. For this purpose we bind the update of
            % the thermal multi branch solver to a post tick level after
            % the capacities, heat sources and other thermal branches
            
            % This function can also be called by a connected heat sources
            % therefore, we update the fTotalHeatSourceHeatFlow property:
            afHeatSourceFlows = zeros(this.iHeatSources,1);
            for iI = 1:this.iHeatSources
                afHeatSourceFlows(iI) = this.coHeatSource{iI}.fRequestedHeatFlow;
            end
            
            this.fTotalHeatSourceHeatFlow = sum(afHeatSourceFlows);
            
            if this.fTimeStep ~= inf
                this.setTimeStep(inf,true);
            end
            
            this.trigger('OutdatedNetworkTimeStep');
        end
    end
    
    methods (Access = protected)
        function calculateTimeStep(~)
            
        end
    end
end