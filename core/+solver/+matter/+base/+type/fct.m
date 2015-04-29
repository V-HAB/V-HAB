classdef fct < handle
    %FCT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        calculateDeltas;
    end
    
    methods
        function this = fct(solverDeltas)
            this.calculateDeltas = solverDeltas;
        end
    end
    
end

