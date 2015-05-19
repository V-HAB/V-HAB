classdef hydraulic < handle
    %HYDRAULIC Delta Pressure Calculation via Hydraulic Length and Diameter
    %   Detailed explanation goes here
    
    properties
        fHydrDiam;
        fHydrLength;
        
        bActive           = false;
        fDeltaPressure    = 0;
        
        calculateDeltaPressure;
    end
    
    methods
        function this = hydraulic(fHydrDiam, fHydrLength, bActive, calcMethod)
            this.fHydrDiam    = fHydrDiam;
            this.fHydrLength  = fHydrLength;
            % Active component? Needs fct handle to calculate delta p
            if nargin >= 3 && bActive
                this.bActive                = bActive;
                this.calculateDeltaPressure = calcMethod;
            end
        end
        
        
        function fDeltaPress = updateDeltaPressure(this)
            % We only need the delta pressure if the active component
            % causes a pressure rise, like a fan. If the active component
            % is for instance a valve, it will just change its hydraulic
            % diameter or length when its update method is called, but it
            % will not calculate a delta pressure. 
            if nargout > 0
                this.fDeltaPressure = this.calculateDeltaPressure();
                fDeltaPress = this.fDeltaPressure;
            else
                % The component is active, but doesn't produce a pressure
                % rise, so we just call the update method and return
                % nothing. 
                this.calculateDeltaPressure();
            end
        end
    end
end

