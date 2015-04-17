classdef temperature < matter.manip
    %TEMPERATURE
    %
    %TODO what about different phase types (solid/gas/...), with e.g. not a
    %     perfectly distributed temperature ...? provide some helpers for a
    %     geometric distribution (filter or reactor -> center hot, outer 
    %     parts cooler etc? Helpers for heat transfer to wall?
    %     -> that should be covered in the oHeatFlow, so only the resulting
    %        in- or outflow is reported
    
    
    properties (SetAccess = private, GetAccess = public)
        %TODO link to some object that defines the current heat flow, then
        %     use that to calculate temp change in phase
        oHeatFlow;
        
        % Actual temp difference in K/s
        fDeltaTemp;
    end
    
    methods
        function this = temperature(sName, oPhase, sRequiredType)
            if nargin < 3, sRequiredType = []; end;
            
            this@matter.manip(sName, oPhase, sRequiredType);
        end
    end
    
    methods (Access = protected)
        function calcChange(this)
            % Use this.getMasses() to get total mass.
            % this.oPhase.fTemp is temperature, this.oPhase.fMolMass
            % Then use this.oHeatFlow."fFlowRate" to calc change per sec
            
            % Return change per second!
        end
    end
end

