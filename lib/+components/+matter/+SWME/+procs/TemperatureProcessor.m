classdef TemperatureProcessor < matter.procs.f2f
    %TEMPERATURECHANGER F2F processor that changes the temperature in the
    % outflow of the SWME
    
    methods
        function this = TemperatureProcessor(oMT, sName)
            this@matter.procs.f2f(oMT, sName);
            
            this.supportSolver('manual', false);
        end
        
        
        function setHeatFlow(this, fHeatFlow)
            this.fHeatFlow    = fHeatFlow;
            
            this.oBranch.setOutdated();
        end
        
    end
    
end

