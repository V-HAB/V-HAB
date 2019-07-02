classdef round
    %ROUND Static class providing rounding
    %   This class provides the prec() method which rounds a given value to
    %   a given precision. 
    
    properties (Constant = true)
        % Default decimal value. Masses V-HAB are given in kg. When using
        % the prec() method a value of 5 would yield in a rounding to the
        % nearest 10 mg. ( 1 * 10^5 kg)
        iDecimal = 5;
    end
    
    methods (Static = true)
        function fRoundedValue = prec(fRawValue, iDecimal)
            %PREC Rounds the input value to the provided decimal
            
            % If no decimal given, we use the default
            if nargin < 2, iDecimal = tools.round.iDecimal; end
            
            % To round to the provided precision, we need to multiply the
            % raw value by a multiple of ten to shift the decimal to the
            % left. Then we round it and shift the decimal back to the
            % right by dividing the result by the multiplier. 
            iMultiplier = 10 ^ iDecimal;
            fRoundedValue = round(fRawValue * iMultiplier) / iMultiplier;
        end
    end
end