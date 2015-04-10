classdef proc < base
    %PROC Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        aoPorts;        % Array of Ports
    end
    
    methods
        function this = proc()
            disp('asd');
        end
        
        function doIt = get(this)
            doIt = @this.blah;
        end
    end
    
    
    methods (Access = protected)
        function blah(this)
            disp('blahblubb');
        end
    end
end

