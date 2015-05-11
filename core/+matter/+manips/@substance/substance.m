classdef substance < matter.manip
    %SUBSTANCES
    %
    %TODO
    %   - differences for solid, gas, liquid ...?
    %   - helpers for required energy, catalyst, produced energy, etc, then
    %     some energy object input for e.g. heat
    
    
    properties (Abstract, SetAccess = protected)
        % Changes in partial masses in kg/s
        afPartialFlows;
        
    end
    
    methods
        function this = substance(sName, oPhase)
            this@matter.manip(sName, oPhase);
            
        end
    end
       
    methods (Abstract)
        update(this)
    end
    
    methods
    
        function exec(this, fTime)
            % Called from subsystem to update the internal state of the
            % processor, e.g. change efficiencies etc
        end
        
    end
end

