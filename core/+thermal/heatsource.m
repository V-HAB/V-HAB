classdef heatsource < base & event.source
    %HEATSOURCE A dumb constant heat source
    %   Detailed explanation goes here
    %
    %TODO 
    %   TAINT CONTAINER!!! after setPower
    %   Well i implemented that because otherwise the heatsource vector
    %   would just never update for me. However the taint function seems to
    %   be unfinished itself and I had to add the vsys as input parameter
    %   to even be able to access it (puda)
    
    properties (SetAccess = protected)
        sName;
        
        oVsys;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fPower = 0; % [W]
    end
    
    methods
        
        function this = heatsource(oVsys, sIdentifier, fPower)
            this.oVsys = oVsys;
            this.sName  = sIdentifier;
            
            if nargin > 1
                this.fPower = fPower;
            end
        end
        
        function setPower(this, fPower)
            this.fPower  = fPower;
            
            this.trigger('update', fPower);
            
            this.oVsys.taint();
        end
        
        function fPower = getPower(this)
            this.warn('getPower', 'Access fPower directly!');
            
            fPower = this.fPower;
        end
        
    end
    
end

