classdef fan_simple < matter.procs.f2f
    %FAN_SIMPLE Linar, static, RPM independent fan model
    %   Interpolates between max flow rate and max pressure rise, values
    %   taken from AIAA-2012-3460 for a fan running at 4630 RMP
    
    properties
        fMaxDeltaP;          % Maximum pressure rise in [Pa]
        iDir = 1;            % Direction of flow
        
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
        
        function fDeltaPressure = update(this)
            
            fDeltaPressure = -1 * this.fMaxDeltaP;
            this.fDeltaPress = fDeltaPressure;
        end
        
        
        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, ~)
            fDeltaTemp = 0;
            fDeltaPress = -1 * this.fMaxDeltaP;
            this.fDeltaPressure = fDeltaPress;
        end
        
        function fDeltaTemperature = updateManualSolver(this)
            fDeltaTemperature = this.fDeltaTemperature;
            
        end
    end
    
end

