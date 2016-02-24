classdef CultureGrowth < matter.procs.p2p
    % This p2p processor moves "general" biomass from the biomass buffer
    % phase into the culture's phase to according to the culture's 
    % calculated growth rate.
    
    properties
    end
    
    methods
        function this = CultureGrowth(oParent, sName)
            this@matter.procs.p2p(oParent, sName);
        end
    end
end