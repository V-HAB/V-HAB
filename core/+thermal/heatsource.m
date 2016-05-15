classdef heatsource < base & event.source
    %HEATSOURCE A dumb constant heat source
    %   Detailed explanation goes here
    %
    %TODO 
    %   TAINT CONTAINER!!! after setPower
    
    properties (SetAccess = protected)
        sName;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fPower = 0; % [W]
    end
    
    methods
        
        function this = heatsource(sIdentifier, fPower)
            this.sName  = sIdentifier;
            
            if nargin > 1
                this.fPower = fPower;
            end
        end
        
        function setPower(this, fPower)
            this.fPower  = fPower;
            
            this.trigger('update', fPower);
        end
        
        function fPower = getPower(this)
            this.warn('getPower', 'Access fPower directly!');
            
            fPower = this.fPower;
        end
        
    end
    
end

