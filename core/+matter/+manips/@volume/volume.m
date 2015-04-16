classdef volume < matter.manip
    %VOLUME
    
    
    properties (SetAccess = private, GetAccess = public)
        % Type of volume change
        sType;
        
        %TODO reference some "energy.flow" object that defines the
        %     available volume change energy
        oMechanicalEnergy;
        
        % Actual volume change in m3/s
        fDeltaVol;
    end
    
    methods
        function this = volume(sName, oPhase, sRequiredType, sType)
            if nargin < 3, sRequiredType = []; end;
            
            this@matter.manip(sName, oPhase, sRequiredType);
            
            if nargin >= 4, this.sType = sType; end;
        end
    end
    
    methods (Access = protected)
        
    end
end

