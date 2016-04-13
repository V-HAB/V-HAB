classdef coefficient < handle
    %MANUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        getCoefficient
    end
    
    methods
        function this = coefficient(getCoefficient)
            this.getCoefficient = getCoefficient;
        end
    end
end

