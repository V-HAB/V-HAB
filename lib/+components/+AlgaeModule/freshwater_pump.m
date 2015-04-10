classdef freshwater_pump < matter.procs.f2f
    %F2F Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public, Abstract = true)
      
    end
     properties
        fDeltaTemp = 0;
        fDeltaPress = 0;
        bActive = 1;
    end
    methods
        function this = freshwater_pump(varargin)
            this@matter.procs.f2f(varargin{:});
  
        end
        function update(this, ~)
        end
    end
end


% if fAerationPower == 100
 %                oB3.setFlowRate(0.6);
 %         elseif fAerationPower == 200
 %               oB3.setFlowRate(2.1);
 %         elseif fAerationPower == 400
 %                oB3.setFlowRate(4.2);

