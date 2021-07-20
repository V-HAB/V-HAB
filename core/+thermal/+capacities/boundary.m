classdef boundary < thermal.capacity
    %BOUNDARY A capacity with an infinitely large heat capacity
    %   The temperature of this capacity is constant and should only be
    %   changed using the setBoundaryTemperature() method. The
    %   updateTemperature() and updateSpecificHeatCapacity() methods of the
    %   parent class are overloaded to do nothing.
    
    methods
        function this = boundary(oPhase, fTemperature)
            % Calling the parent class constructor
            this@thermal.capacity(oPhase, fTemperature);
            
            % Since this is a boundary capacity, its temperature should
            % never change. This is equivalent to an infinite heat
            % capacity, so that is exactly what we are setting here. 
            this.fTotalHeatCapacity = inf;
            
            this.bBoundary = true;
        end
        
        function setBoundaryTemperature(this, fTemperature)
            % External function to set the boundary temperature
            this.setTemperature(fTemperature);
            
            % We also update the specific heat capacity, since we do not
            % want to do this if nothing has changed in the boundary
            this.fSpecificHeatCapacity = this.oMT.calculateSpecificHeatCapacity(this.oPhase);
        end
        
        function updateTemperature(this, ~)
            % Overloaded function, calculates some time step values and
            % sets the current one outdated. 
            
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastTemperatureUpdate;
            
            this.fLastTemperatureUpdate     = fTime;
            this.fTemperatureUpdateTimeStep = fLastStep;
            
            % Capacity sets new time step (registered with parent store,
            % used for all phases of that store)
            this.setOutdatedTS();
            
            if this.bTriggerSetUpdateTemperaturePostCallbackBound
            	this.trigger('updateTemperature_post');
            end
        end
        
        function updateSpecificHeatCapacity(~)
            % Overloaded function, does nothing
        end
    end
end