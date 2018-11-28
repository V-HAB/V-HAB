classdef AntoineData
    %ANTOINEPARAMETERS Constant class containing parameters for the Antoine
    %equation to calculate vapor pressure
    % 
    % The values are taken from http://webbook.nist.gov.
    %
    % The parameters are stored in cell arrays. Each row contains the
    % following items:
    %   1. Lower limit of valid temperature range
    %   2. Upper limit of valid temperature range
    %   3. Parameter A
    %   4. Parameter B
    %   5. Parameter C
    %
    % If there is more than one temperature range, the cell has more than
    % one row, see H2O or NH3.
    
    
    properties (Constant)
        
        CH4 = {90.99, 189.99, 3.9895, 443.028, -0.49};
        
        H2  = {21.01, 32.27, 3.54314, 99.395, 7.726};
        
        O2  = {54.36, 154.33, 3.9523, 340.024, -4.144};
        
        H2O = {255.9, 379.0, 4.6543, 1435.264,  -64.848; ...
               379.0, 573.0, 3.55959, 643.748, -198.043};
        
        CO2 = {154.26, 195.89, 6.81228, 1301.679, -3.494};
        
        NH3 = {164.0, 239.6, 3.18757,  596.713, -80.78; ...
               239.6, 371.5, 4.86886, 1113.928, -10.409};
        
        % For CO there were no Antoine Equation Parameters on the NIST
        % website. Therefore only the boiling point is used as deciding
        % instance.
        CO  = {81.63, 81.63, 0, 0, 0};
        
        N2  = {63.14, 126, 3.7362, 264.651, -6.788};
        
        Ar  = {83.78, 150.72, 3.29555, 215.24, -22.233};
        
    end
    
    methods
        
    end
end

