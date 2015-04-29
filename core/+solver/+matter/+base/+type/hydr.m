classdef hydr < handle
    %HYDR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fHydrDiam;
        fHydrLength;
        
        bActive           = false;
        fDeltaPressure    = 0;
        
        calculateDeltaPressure;
    end
    
    methods
        function this = hydr(fHydrDiam, fHydrLength, bActive, calcMethod)
            this.fHydrDiam    = fHydrDiam;
            this.fHydrLength  = fHydrLength;
            % Active component? Needs fct handle to calculate delta p
            if nargin >= 3 && bActive
                this.bActive             = bActive;
                this.calculateDeltaPressure = calcMethod;
            end
        end
        
        
        function fDeltaPress = updateDeltaPressure(this)
            this.fDeltaPressure = this.calculateDeltaPressure();
            fDeltaPress = this.fDeltaPressure;
        end
    end
end

