classdef heatsource < base & event.source
    %HEATSOURCE A heat source that is connected to a matter object
    %   Via the fHeatFlow property the inner energy of the connected matter
    %   object will be changed accordingly. If the power is changed via the
    %   setPower() method, the thermal container this heat source belongs
    %   to is tainted and an update of the thermal solver is bound to the
    %   post-tick. This thermal solver update is however only triggered, if
    %   the change in power is greater than one milliwatt. This is to
    %   prevent too frequent updates, which take a long time. 
    %
    %TODO include some kind of sign handling? Just like branch - have two
    %     'ends' of the heat source, and a positive heat flow on the left
    %     end means a negative one on the right end etc.
    
    properties (SetAccess = protected)
        sName;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fHeatFlow = 0; % [W]
        
        oCapacity;
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
        
        function this = heatsource(sName, fHeatFlow)
            this.sName  = sName;
            
            if nargin > 1
                this.fHeatFlow = fHeatFlow;
            end
        end
        
        function setHeatFlow(this, fHeatFlow)
            % We only need to trigger an update of the whole thermal solver
            % if the power has actually changed by more than one milliwatt.
            if ~isempty(this.hTriggerSolverUpdate) && this.fHeatFlow ~= fHeatFlow && abs(this.fHeatFlow - fHeatFlow) > 1e-3
                this.hTriggerSolverUpdate();
            end
            
            fHeatFlowOld   = this.fHeatFlow;
            this.fHeatFlow = fHeatFlow;
            
            this.oCapacity.setOutdatedTS();
            
            if this.bTriggerUpdateCallbackBound
                this.trigger('update', struct('fHeatFlowOld', fHeatFlowOld, 'fHeatFlow', fHeatFlow));
            end
        end
        
        % SCJO: @OLCL is this so much faster than using .trigger('update')?
        function setUpdateCallBack(this, oThermalSolver)
            this.hTriggerSolverUpdate = @oThermalSolver.registerUpdate;
        end
        
        function setCapacity(this, oCapacity)
            if isempty(this.oCapacity)
                this.oCapacity = oCapacity;
            else
                this.throw('setCapacity', 'Heatsource already has a capacity object');
            end
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

