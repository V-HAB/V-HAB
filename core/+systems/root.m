classdef root < sys
    %ROOT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Dummy property for logging placeholder
        fDummy = NaN;
    end
    
    methods
        function this = root(sId, oData)
            this@sys([], sId);
            
            % Manually set data - setParent does nothing!
            this.setData(oData);
        end
        
        function setParent(this, ~)
            % Not really adding a parent, haw-haw!
            
            %TODO check - leave empty or reference back to itself?
            this.oParent = this;
        end
        
        function play(this)
            % Top system can be directly executed - child systems can
            % register on this system's exec - usable without timer?
            
            this.exec();
        end
    end
    
end