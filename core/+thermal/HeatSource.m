classdef HeatSource < base
    %HEATSOURCE A dumb constant heat source
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        sName;
    end
    
    properties (Access = protected)
        fPower = 0; % [W]
    end
    
    methods
        
        function this = HeatSource(sIdentifier, fPower)
            this.sName  = sIdentifier;
            this.fPower = fPower;
        end
        
        function setPower(this, fPower)
            this.fPower  = fPower;
        end
        
        function fPower = getPower(this)
            fPower = this.fPower;
        end
        
    end
    
end

