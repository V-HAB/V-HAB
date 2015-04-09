classdef f2f < matter.procs.f2f
    %F2F Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public, Abstract = true)
        fHydrDiam;
        fHydrLength;
        
        fDeltaTemp;
        bActive;
    end
    
    methods
        function this = f2f(varargin)
            this@matter.procs.f2f(varargin{:});
        end
    end
    
    methods (Abstract = true)
        % Method returns change in pressure and temperature for the given
        % flow rate; other matter properties through this.get().XYZ
        [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, fFlowRate);
    end
end

