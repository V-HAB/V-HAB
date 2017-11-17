classdef heatsource < base & event.source
    %HEATSOURCE A heat source that is connected to a matter object
    %   Via the fPower property the inner energy of the connected matter
    %   object will be changed accordingly. If the power is changed via the
    %   setPower() method, the thermal container this heat source belongs
    %   to is tainted and an update of the thermal solver is bound to the
    %   post-tick. This thermal solver update is however only triggered, if
    %   the change in power is greater than one milliwatt. This is to
    %   prevent too frequent updates, which take a long time. 
    
    properties (SetAccess = protected)
        sName;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fPower = 0; % [W]
    end
    
    properties (Access = protected)
        % A handle for the update of the thermal solver. To be used,
        % whenever the power of this heat source is updated. 
        hTriggerSolverUpdate;
        
        % Performance hack - only .trigger() if .bind() happened. Replaces
        % the specific multi heat source handling.
        bTriggerUpdateCallbackBound = false;
    end
    
    methods
        
        function this = heatsource(sIdentifier, fPower)
            this.sName  = sIdentifier;
            
            if nargin > 1
                this.fPower = fPower;
            end
        end
        
        function setPower(this, fPower)
            % We only need to trigger an update of the whole thermal solver
            % if the power has actually changed by more than one milliwatt.
            if this.fPower ~= fPower && abs(this.fPower - fPower) > 1e-3
                this.hTriggerSolverUpdate();
            end
            
            fPowerOld   = this.fPower;
            this.fPower = fPower;
            
            if this.this.bTriggerUpdateCallbackBound
                this.trigger('update', struct('fPowerOld', fPowerOld, 'fPower', fPower));
            end
        end
        
        % SCJO: @OLCL is this so much faster than using .trigger('update')?
        function setUpdateCallBack(this, oThermalSolver)
            this.hTriggerSolverUpdate = @oThermalSolver.registerUpdate;
        end
        
        
        % Catch 'bind' calls, so we can set a specific boolean property to
        % true so the .trigger() method will only be called if there are
        % callbacks registered.
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only do for set
            if strcmp(sType, 'update')
                this.bTriggerUpdateCallbackBound = true;
            end
        end
    end
    
end

