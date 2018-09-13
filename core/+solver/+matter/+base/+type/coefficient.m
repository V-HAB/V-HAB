classdef coefficient < handle
    %COEFFICIENT Delta pressure calculation via coefficient.
    % Solvers of this type require their F2Fs to implement the function
    % getCoefficient, which multiplied with the flowrate, results in a
    % delta pressure. The solver can then use this to calculate the overall
    % branch flowrate.
    
    properties (SetAccess = protected, GetAccess = public)
        getCoefficient
    end
    
    methods
        function this = coefficient(getCoefficient)
            this.getCoefficient = getCoefficient;
        end
    end
end

