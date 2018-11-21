classdef round
    %ROUND helper methods
    
    properties (Constant = true)
        % Masses in kg -> 0.1 mg -> ok?
        iPrecision = 5;
    end
    
    methods (Static = true)
        function fValue = prec(fValue, iPrecision)
            if nargin < 2, iPrecision = tools.round.iPrecision; end
            
            iPrecision = 10 ^ iPrecision;
            fValue = round(fValue * iPrecision) / iPrecision;
        end
    end
end