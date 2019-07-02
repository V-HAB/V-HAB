classdef battery < electrical.stores.constantVoltageSource
    %BATTERY Simple Battery Model
    %   This simple battery model updates it's charge based on the
    %   outflowing current. If it reaches zero it will just set it's
    %   voltage to zero and display a message to the user. 
    
    properties (SetAccess = protected, GetAccess = public)
        % Charge of the battery in ampere-hours [Ah]
        fCharge;
    end
    
    properties
        % These properties are in here for future expansion of the battery
        % model. For now, they have no effect on the behavior of the model.
        
        % Maximum voltage that can be output by the battery
        fMaxVoltage = 20.5;
        
        % Maximum current that can be output by the battery
        fMaxCurrent = 5;
    end
    
    methods
        function this = battery(oCircuit, sName, fCapacity, fVoltage)
            % Calling the parent constructor
            this@electrical.stores.constantVoltageSource(oCircuit, sName, 'DC', fVoltage);
            
            % Since we've modeled this battery as a constant voltage
            % source, we set the constant voltages.
            this.oPositiveTerminal.setVoltage(fVoltage);
            this.oNegativeTerminal.setVoltage(0);
            
            % We initialize the battery as full, so the given capacity
            % equals the charge.
            this.fCharge = fCapacity;
        end
        
        function update(this)
            %TODO This update method should be triggered by branches that
            %connect to this battery that change their current.
            
            % Get the time that has passed since the last update.
            fElapsedTime = this.oTimer.fTime - this.fLastUpdate;
            
            % If the update has already been called, we don't have to do
            % anything, we just return.
            if fElapsedTime == 0
                return;
            end
            
            % Now we calculate the change in charge based in the current
            % out of the positive terminal of this battery and the time
            % that has passed since. 
            this.fCharge = this.fCharge - fElapsedTime / 3600 * this.oPositiveTerminal.oFlow.fCurrent;
            
            % If the new charge is zero or smaller, the battery is
            % considered empty. So we set all voltages to zero and display
            % a message to the user. 
            if tools.round.prec(this.fCharge) <= 0
                this.fVoltage = 0;
                this.oPositiveTerminal.setVoltage(0);
                this.oNegativeTerminal.setVoltage(0);
                fprintf('%i\t(%.7fs)\tBattery ''%s'' is empty.\n', this.oTimer.iTick, this.oTimer.fTime, this.sName);
            end
            
            % Finally, we update the parent class. This triggers other
            % stuff such as time step calculation etc. 
            update@electrical.stores.constantVoltageSource(this);
        end
    end
    
end

