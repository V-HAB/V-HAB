classdef AntoineData
    %ANTOINEDATA Constant class containing parameters for the Antoine
    %equation to calculate vapor pressure
    % 
    % The values are taken from http://webbook.nist.gov.
    
    properties (Constant)
        
        CH4 = struct( ...
            'Range', struct( ...
                'mfLimits', [90.99, 189.99], ...
                'fA', 3.9895, ...
                'fB', 443.028, ...
                'fC', -0.49) ...
            );
        
        H2 = struct( ...
            'Range', struct( ...
                'mfLimits', [21.01, 32.27], ...
                'fA', 3.54314, ...
                'fB', 99.395, ...
                'fC', 7.726) ...
            );
        
        O2 = struct( ...
            'Range', struct( ...
                'mfLimits', [54.36, 154.33], ...
                'fA', 3.9523, ...
                'fB', 340.024, ...
                'fC', -4.144) ...
            );
        
        H2O = struct( ...
            'Range', [ struct( ...
                'mfLimits', [255.9, 379], ...
                'fA', 4.6543, ...
                'fB', 1435.264, ...
                'fC', -64.848) ...
            , ...
            struct( ...
                'mfLimits', [379, 573], ...
                'fA', 3.55959, ...
                'fB', 643.748, ...
                'fC', -198.043) ...
                ] ...
            );
        
        CO2 = struct( ...
            'Range', struct( ...
                'mfLimits', [154.26, 195.89], ...
                'fA', 6.81228, ...
                'fB', 1301.679, ...
                'fC', -3.494) ...
            );
        
        NH3 = struct( ...
            'Range', [ struct( ...
                'mfLimits', [164, 239.6], ...
                'fA', 3.18757, ...
                'fB', 596.713, ...
                'fC', -80.78) ...
            , ...
            struct( ...
                'mfLimits', [239.6, 371.5], ...
                'fA', 4.86886, ...
                'fB', 1113.928, ...
                'fC', -10.409) ...
                ] ...
            );
        
        CO = struct('Range', struct('mfLimits', [154.26, 195.89]));
        
        N2 = struct( ...
            'Range', struct( ...
                'mfLimits', [63.14, 126], ...
                'fA', 3.7362, ...
                'fB', 264.651, ...
                'fC', -6.788) ...
            );
        
        Ar = struct( ...
            'Range', struct( ...
                'mfLimits', [83.78, 150.72], ...
                'fA', 3.29555, ...
                'fB', 215.24, ...
                'fC', -22.233) ...
            );
        
    end
    
    methods
        
    end
end

