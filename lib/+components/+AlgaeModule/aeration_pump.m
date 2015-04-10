classdef aeration_pump < matter.procs.f2f
    %F2F Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public, Abstract = true)
     
    end
    
    properties
        fDeltaTemp = 0;
        fDeltaPress = 0;
        bActive = 1;
        fAerationPower = 0;
        fPower;
        fLevel1 = 100;
        fLevel2 = 200;
        fLevel3 = 400;
    end
    methods
        function this = aeration_pump(varargin)
            this@matter.procs.f2f(varargin{1:2});
            
            
            this.fAerationPower = varargin(3);
            
            
        end
        
        
        function update(this)
            
       
        end
    end
end




% if fAerationPower == 100
 %                oB3.setFlowRate(0.6);
 %         elseif fAerationPower == 200
 %               oB3.setFlowRate(2.1);
 %         elseif fAerationPower == 400
 %                oB3.setFlowRate(4.2);


