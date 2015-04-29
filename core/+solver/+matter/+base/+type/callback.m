classdef callback < handle
    %CALLBACK Delta Pressure Calculation via Specific Function
    %   Detailed explanation goes here
    
    properties
        calculateDeltas;
    end
    
    methods
        function this = callback(solverDeltas)
            this.calculateDeltas = solverDeltas;
        end
    end
    
end

