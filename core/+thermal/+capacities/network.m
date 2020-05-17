classdef network < thermal.capacity
    %NETWORK A capacity intent for the use with the advanced thermal multi
    % branch solver. For this capacity, the thermal multi branch solver
    % handles the temperature calculation and everything else. 
    
    properties (GetAccess = public, SetAccess = protected)
        % Reference to the thermal multi branch solver solving the
        % temperature of this capacity
        oHandler;
        
        % Index of this capacity in the 
        iHandlerCapacityIndex;
        
        % For the total heat source heat flow rate to be easily accesible
        % to the thermal network solver, we store it in this property for
        % each capacity
        fHeatSourceHeatFlow = 0;
    end
    
    methods
        function this = network(oPhase, fTemperature, bBoundary)
            % Calling the parent class constructor
            this@thermal.capacity(oPhase, fTemperature);
            
            if nargin > 2
                this.bBoundary = bBoundary;
            end
            
            this.oHandler.hBindPostTickUpdate = @this.PlaceHolder;
            this.setTimeStep(inf,true);
        end
        
        
        function updateTemperature(this, ~)
            % Overloaded function, calculates some time step values and
            % sets the current one outdated. 
            
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastTemperatureUpdate;
            
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            
            this.setTemperature(this.oHandler.afTemperatures(this.iHandlerCapacityIndex));
            
            if this.bTriggerSetUpdateTemperaturePostCallbackBound
            	this.trigger('updateTemperature_post');
            end
        end
        
        function PlaceHolder(~)
            % Does nothing, just a place holder so we do not require an if
            % query in the setOutdatedTS function
        end
        
        function setOutdatedTS(this)
            % we overload the normal setOutdatedTS because instead of the
            % capacity, we should inform the thermal multi branch solver
            % that it should update. For this purpose we bind the update of
            % the thermal multi branch solver to a post tick level after
            % the capacities, heat sources and other thermal branches
            
            % This function can also be called by a connected heat sources
            % therefore, we update the fHeatSourceHeatFlow property:
            if this.iHeatSources ~= 0
                this.fHeatSourceHeatFlow = sum(cellfun(@(cCell) cCell.fHeatFlow, this.coHeatSource));
            end
            if this.fTimeStep ~= inf
                this.setTimeStep(inf,true);
            end
            this.oHandler.hBindPostTickUpdate();
        end
    end
    methods (Access = protected)
        function calculateTimeStep(~)
            
        end
    end
    methods (Access = {?solver.thermal.multi_branch.advanced.branch})
        function setHandler(this, oHandler, iIndex)
            % THis function is called by the thermal multi branch solver to
            % register itself as solver for the capacity and provide the
            % index of the capacity in the solvers afTemperatures vector.
            this.oHandler = oHandler;
            this.iHandlerCapacityIndex = iIndex;
        end
    end
end