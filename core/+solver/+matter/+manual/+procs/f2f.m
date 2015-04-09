classdef f2f < matter.procs.f2f
    %F2F Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public, Abstract = true)
        fHydrDiam;
        fHydrLength;
        
        fDeltaTemp;
        fDeltaPress;
        bActive;
    end
    
    methods
        function this = f2f(varargin)
            this@matter.procs.f2f(varargin{:});
        end
    end
end

