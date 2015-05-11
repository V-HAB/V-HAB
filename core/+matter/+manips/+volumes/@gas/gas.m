classdef gas < matter.manips.vol
    %VOL 
    %
    %TODO provide some helper methods, see TD book, for the different types
    %     of volume change stuff
    
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    methods
        function this = gas(sName, oPhase, sType)
            % Type could be is isentropic, isothermal etc
            if nargin < 3, sType = []; end;
            
            this@matter.manips.vol(sName, oPhase, 'gas', sType);
        end
    end
    
    methods (Access = protected)
        
    end
end

