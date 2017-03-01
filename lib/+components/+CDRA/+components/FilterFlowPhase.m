classdef FilterFlowPhase < matter.phases.gas
    % flow phase for filters that are thermally ideally coupled with their solid materials
    
    properties (SetAccess = protected, GetAccess = public)
        
        fAdditionalConstantTotalHeatCapacity = 0;
    end
    
    
    methods
        function this = FilterFlowPhase(oStore, sName, tfMasses, fVolume, fTemperature, fAdditionalConstantTotalHeatCapacity)
            
            this@matter.phases.gas(oStore, sName, tfMasses, fVolume, fTemperature);
            
            if nargin > 5
                this.fAdditionalConstantTotalHeatCapacity = fAdditionalConstantTotalHeatCapacity;
            end
            
            this.fTotalHeatCapacity = this.fTotalHeatCapacity + this.fAdditionalConstantTotalHeatCapacity;
        end
        
        function this = update(this)
            update@matter.phases.gas(this);
            
            this.fTotalHeatCapacity = this.fTotalHeatCapacity + this.fAdditionalConstantTotalHeatCapacity;
        end
        
        function fTotalHeatCapacity = getTotalHeatCapacity(this)
            % Returns the total heat capacity of the phase. 
            
            this.warn('getTotalHeatCapacity', 'Use oPhase.fSpecificHeatCapacity * oPhase.fMass!');
            
            % We'll only calculate this again, if it has been at least one
            % second since the last update. This is to reduce the
            % computational load and may be removed in the future,
            % especially if the calculateSpecificHeatCapactiy() method and
            % the findProperty() method of the matter table have been
            % substantially accelerated.
            % One second is also the fixed timestep of the thermal solver. 
            %
            % Could that not be written as:
            % this.oTimer.fTime < (this.fLastTotalHeatCapacityUpdate + ...
            %                  this.fMinimalTimeBetweenHeatCapacityUpdates)
            % It feels like that is more readable ...
            if isempty(this.fLastTotalHeatCapacityUpdate) || (this.oTimer.fTime - this.fLastTotalHeatCapacityUpdate < this.fMinimalTimeBetweenHeatCapacityUpdates)
                fTotalHeatCapacity = this.fTotalHeatCapacity;
            else
                this.updateSpecificHeatCapacity();
                
                fTotalHeatCapacity = this.fSpecificHeatCapacity * this.fMass + this.fAdditionalConstantTotalHeatCapacity;
            
                % Save total heat capacity as a property for faster logging.
                this.fTotalHeatCapacity = fTotalHeatCapacity;
                
                this.fLastTotalHeatCapacityUpdate = this.oTimer.fTime;
            end
            
        end
        
    end
    
end

