classdef fan_simple < matter.procs.f2f
    %FAN_SIMPLE Linar, static, RPM independent fan model
    %   Interpolates between max flow rate and max pressure rise, values
    %   taken from AIAA-2012-3460 for a fan running at 4630 RMP
    
    properties
        fMaxDeltaP;          % Maximum pressure rise in [Pa]
        iDir = 1;            % Direction of flow
        
        % Parameter to check if the fan is on or off
        bTurnedOn = true;
    end
        
    methods
        function this = fan_simple(oParent, sName, fMaxDeltaP, bReverse)
            this@matter.procs.f2f(oParent, sName);
            
            % tells solvers that this component produces a pressure rise
            this.bActive = true;
            
            this.fMaxDeltaP   = fMaxDeltaP;
            
            if (nargin >= 4) && islogical(bReverse) && bReverse
                this.iDir = -1;
            end
            
            
            this.supportSolver('hydraulic', -1, 1, true, @this.update);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', true, @this.updateManualSolver);
        end
        
        function switchOn(this)
            this.bTurnedOn = true;
            this.oBranch.setOutdated();
        end
        
        function switchOff(this)
            this.bTurnedOn = false;
            this.oBranch.setOutdated();
        end
        
        
        function fDeltaPressure = update(this)
            if this.bTurnedOn
                fDeltaPressure = -1 * this.fMaxDeltaP;
                this.fDeltaPressure = fDeltaPressure;
            else
                this.fDeltaPressure = 0;
            end
        end
        
        
        function [ fDeltaPressure, fDeltaTemp ] = solverDeltas(this, ~)
            if this.bTurnedOn
                fDeltaTemp = 0;
                fDeltaPressure = -1 * this.fMaxDeltaP;
                this.fDeltaPressure = fDeltaPressure;
            else
                this.fDeltaPressure = 0;
                fDeltaPressure = 0;
            end
        end
        
        function fDeltaTemperature = updateManualSolver(this)
            fDeltaTemperature = this.fDeltaTemperature;
            
        end
    end
    
end

