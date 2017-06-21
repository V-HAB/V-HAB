classdef heatsource < base & event.source
    %HEATSOURCE A heat source that is connected to a matter object
    %   Via the fPower property the inner energy of the connected matter
    %   object will be changed accordingly. If the power is changed via the
    %   setPower() method, the thermal container this heat source belongs
    %   to is tainted and an update of the thermal solver is bound to the
    %   post-tick. This thermal solver update is however only triggered, if
    %   the change in power is greater than one milliwatt. This is to
    %   prevent too frequent updates, which take a long time. 
    %   to even be able to access it (puda)
    
    properties (SetAccess = protected)
        sName;
        
        oVsys;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fPower = 0; % [W]
    end
    
    properties (Access = protected)
        % A handle for the update of the thermal solver. To be used,
        % whenever the power of this heat source is updated. 
        hTriggerSolverUpdate;
        
        % A boolean variable indicating if this heat source is connected to
        % a matter object directly, or via a multiple heat source object
        % (heatsource_multi.m). 
        bPartOfMultiHeatSource = false;
        
        oMultiHeatSource;
    end
    
    methods
        
        function this = heatsource(oVsys, sIdentifier, fPower)
            this.oVsys = oVsys;
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
            
            this.fPower  = fPower;
            
            if this.bPartOfMultiHeatSource
                this.oMultiHeatSource.updatePower();
            end
        end
        
        function fPower = getPower(this)
            this.warn('getPower', 'Access fPower directly!');
            
            fPower = this.fPower;
        end
        
        function setUpdateCallBack(this, oThermalSolver)
            this.hTriggerSolverUpdate = @oThermalSolver.registerUpdate;
        end
        
        function setMultiHeatSource(this, oMultiHeatSource)
            this.bPartOfMultiHeatSource = true;
            this.oMultiHeatSource = oMultiHeatSource;
        end
        
    end
    
end

