classdef callback < handle
    %CALLBACK Delta Pressure Calculation via Specific Function
    % Solvers of this type require the F2Fs to implement a specific
    % function that calculates the delta pressure of the component for a
    % specific flowrate. (solverDeltas)
    % The solver uses this information to calculate the overall flowrate
    % through the branch (e.g. by iterating the flowrate and the F2F
    % calculations untill the pressure difference is equal to the total
    % delta pressure of the branch)
    properties
        calculateDeltas;
    end
    
    methods
        function this = callback(solverDeltas)
            this.calculateDeltas = solverDeltas;
        end
    end
    
end

