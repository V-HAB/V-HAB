classdef heatsource < base & event.source
    %HEATSOURCE A heat source that is connected to a thermal capacity object
    %   Via the fHeatFlow property the inner energy of the connected matter
    %   object will be changed accordingly. If the power is changed via the
    %   setPower() method, the thermal capacity this heat source belongs
    %   to is tainted and an update of the thermal solver is bound to the
    %   post-tick. This thermal solver update is however only triggered, if
    %   the change in power is greater than one milliwatt. This is to
    %   prevent too frequent updates, which take a long time. 
    
    properties (SetAccess = protected)
        sName;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Current heat flow of this heat source. For negative values it is
        % actually a heat sink and cools the capacity
        fHeatFlow = 0; % [W]
        
        % As with the manual solver in the mass domain, we cannot change
        % the heat flow directly, as we first have to perform the
        % temperature update of the capacity with the old heat flow to
        % transfer the correct amount of thermal energy!
        fRequestedHeatFlow = 0; % [W]
        
        % Object reference to the capacity in which this heat source is
        % located
        oCapacity;
    end
    
    properties (Access = protected)
        % A handle to trigger the post tick update of the heat source. To
        % be used whenever the heat flow changes (note directly changing
        % the heat flow is not allowed for energy conversation reasons, see
        % discussion of mass balance on the matter domain side)
        hBindPostTickUpdate;
        
        chUnbindFunctions;
        
        % Performance hack - only .trigger() if .bind() happened. Replaces
        % the specific multi heat source handling.
        bTriggerUpdateCallbackBound = false;
        bTriggerSetFlowRateCallbackBound = false;
    end
    
    methods
        
        function this = heatsource(sName, fHeatFlow)
            % create a heat source, as optional parameter the initial heat
            % flow of the heat source can be set. Note that after creating
            % the heat source, it will not yet do anything, it first has to
            % be added to a capacity using the addHeatSource function of
            % the capacity
            this.sName  = sName;
            
            if nargin > 1
                this.fHeatFlow = fHeatFlow;
                this.fRequestedHeatFlow = fHeatFlow;
            end
            
        end
        
        function setHeatFlow(this, fHeatFlow)
            % This function can be used to change the heat flow of this
            % heat source. The only input parameter is:
            % fHeatFlow: Heat Flow in [W]
            
            % store the previous heat flow as old heat flow and provide it
            % as possible input for other functions bound to the update
            % trigger of this heat flow
            this.fRequestedHeatFlow = fHeatFlow;
            
            % Tell the capacity that its time step is now outdated as a
            % heat flow has changed. If the heat flow is identical we do
            % not have to do anything
            if this.fHeatFlow ~= this.fRequestedHeatFlow 
                this.oCapacity.setOutdatedTS();
                this.hBindPostTickUpdate();
            end
            
            % If anything is bound to this trigger of this heat source, we
            % trigger an event to tell other objects/functions that this
            % heat source was updated
            if this.bTriggerSetFlowRateCallbackBound
                this.trigger('setHeatFlow', struct('fHeatFlowOld', this.fHeatFlow, 'fHeatFlow', this.fRequestedHeatFlow));
            end
        end
        
        function setCapacity(this, oCapacity)
            % Function to tell this heat source what its connected capacity
            % is. This should be used directly, instead it is used by the
            % addHeatSource function of the capacity
            if isempty(this.oCapacity)
                this.oCapacity = oCapacity;
            else
                this.throw('setCapacity', 'Heatsource already has a capacity object');
            end
            
            [this.hBindPostTickUpdate,          this.chUnbindFunctions{end+1}] = this.oCapacity.oTimer.registerPostTick(@this.updateHeatFlow, 'thermal', 'heatsources');
        end
        
        % Catch 'bind' calls, so we can set a specific boolean property to
        % true so the .trigger() method will only be called if there are
        % callbacks registered.
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            [ this, unbindCallback ] = bind@event.source(this, sType, callBack);
            
            % Only do for set
            if strcmp(sType, 'update')
                this.bTriggerUpdateCallbackBound = true;
            elseif strcmp(sType, 'setHeatFlow')
                this.bTriggerSetFlowRateCallbackBound = true;
            end
        end
    end
    methods (Access = protected)
        
        function updateHeatFlow(this)
            % Since the temperature update of the capacity was called
            % beforehand, we can now set the newly requested heat flow for
            % the heat source!
            this.fHeatFlow = this.fRequestedHeatFlow;
        end
    end 
end