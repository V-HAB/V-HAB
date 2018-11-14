classdef boundary < thermal.capacity
    % a boundary capacity that models a infinite large capacity with
    % setable temperature
        
    properties (SetAccess = protected) %, Abstract)
        
    end
    
    methods
        
        function this = boundary(oPhase, fTemperature)
            %CAPACITY Create new thermal capacity object
            %   Create a new capacity with a name and associated phase
            %   object. Capacities are generated automatically together
            %   with phases and all thermal calculations are performed here
            this@thermal.capacity(oPhase, fTemperature);
            
            this.fTotalHeatCapacity     = inf;
            
        end
        
        function setBoundaryTemperature(this, fTemperature)
            % external function to set the boundary temperature
            this.setTemperature(fTemperature);
        end
        
        function updateTemperature_post(this, ~)
            % use fCurrentHeatFlow to calculate the temperature change
            % since the last execution fLastTemperatureUpdate
           
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastTemperatureUpdate;
            
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            
            if this.bTriggerSetUpdateTemperaturePostCallbackBound
            	this.trigger('updateTemperature_post');
            end
        end
    end
end