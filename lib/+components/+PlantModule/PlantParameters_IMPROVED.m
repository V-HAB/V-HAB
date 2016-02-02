function [ cxPlants ] = PlantParameters_IMPROVED()

    % TODO: most parameters just carried over for now to apply the new
    % structure, variable names are changed as seemed appropriate but since
    % I do not understand all the processes etc. involved yet those may
    % change in the future. Use 'STRG+F' and 'Replace All' to easily apply
    % new names if need arises.

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Each Parameter starts with a capital letter; names of plant species %
    % only have their first letter a capital to prevent irritations       %
    % regarding names (e.g. white-potato against rice, which are two      %
    % words  against one). Also name AND index are provided for all       %
    % species even if it may seem redundant as parameters are only used   %
    % after being called by the function                                  %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % names of plant species
    cxPlants.Drybean.Name       = 'Drybean';
    cxPlants.Lettuce.Name       = 'Lettuce';
    cxPlants.Peanut.Name        = 'Peanut';
    cxPlants.Rice.Name          = 'Rice';
    cxPlants.Soybean.Name       = 'Soybean';
    cxPlants.Sweetpotato.Name   = 'Sweetpotato';
    cxPlants.Tomato.Name        = 'Tomato';
    cxPlants.Wheat.Name         = 'Wheat';
    cxPlants.Whitepotato.Name   = 'Whitepotato';
    
    % each species gets an index number
    cxPlants.Drybean.Index      = 1;
    cxPlants.Lettuce.Index      = 2;
    cxPlants.Peanut.Index       = 3;
    cxPlants.Rice.Index         = 4;
    cxPlants.Soybean.Index      = 5;
    cxPlants.Sweetpotato.Index  = 6;
    cxPlants.Tomato.Index       = 7;
    cxPlants.Wheat.Index        = 8;
    cxPlants.Whitepotato.Index  = 9;
    
    % TODO: comments in original file were totally irritating, all legume
    % values were set to zero. Just carried them over as they were, need to
    % look into later
    cxPlants.Drybean.Legume     = 0;
    cxPlants.Lettuce.Legume     = 0;
    cxPlants.Peanut.Legume      = 0;
    cxPlants.Rice.Legume        = 0;
    cxPlants.Soybean.Legume     = 0;
    cxPlants.Sweetpotato.Legume = 0;
    cxPlants.Tomato.Legume      = 0;
    cxPlants.Wheat.Legume       = 0;
    cxPlants.Whitepotato.Legume = 0;
    
    % n is exponent in A/A_max realtion
    cxPlants.Drybean.N          = 2;
    cxPlants.Lettuce.N          = 2.5;
    cxPlants.Peanut.N           = 2;
    cxPlants.Rice.N             = 1.5;
    cxPlants.Soybean.N          = 1.5;
    cxPlants.Sweetpotato.N      = 1.5;
    cxPlants.Tomato.N           = 2.5;
    cxPlants.Wheat.N            = 1;
    cxPlants.Whitepotato.N      = 2;
    
    % minimum canopy quantum yield, units???
    cxPlants.Drybean.CQY_min        = 0.02;
    cxPlants.Lettuce.CQY_min        = 0.01; % set by someone in original file
    cxPlants.Peanut.CQY_min         = 0.02;
    cxPlants.Rice.CQY_min           = 0.01;
    cxPlants.Soybean.CQY_min        = 0.02;
    cxPlants.Sweetpotato.CQY_min    = 0.01; % set by someone in original file
    cxPlants.Tomato.CQY_min         = 0.01;
    cxPlants.Wheat.CQY_min          = 0.01;
    cxPlants.Whitepotato.CQY_min    = 0.02;
    
    % maximum carbon use efficiency
    cxPlants.Drybean.CUE_max        = 0.65;
    cxPlants.Lettuce.CUE_max        = 0.625;
    cxPlants.Peanut.CUE_max         = 0.65;
    cxPlants.Rice.CUE_max           = 0.64;
    cxPlants.Soybean.CUE_max        = 0.65;
    cxPlants.Sweetpotato.CUE_max    = 0.625;
    cxPlants.Tomato.CUE_max         = 0.65;
    cxPlants.Wheat.CUE_max          = 0.64;
    cxPlants.Whitepotato.CUE_max    = 0.625;
    
    % minimum carbon use efficiency, only for legumes???
    cxPlants.Drybean.CUE_min        = 0.5;
    cxPlants.Lettuce.CUE_min        = 0;
    cxPlants.Peanut.CUE_min         = 0.3;
    cxPlants.Rice.CUE_min           = 0;
    cxPlants.Soybean.CUE_min        = 0.3;
    cxPlants.Sweetpotato.CUE_min    = 0;
    cxPlants.Tomato.CUE_min         = 0;
    cxPlants.Wheat.CUE_min          = 0;
    cxPlants.Whitepotato.CUE_min    = 0;
    
    % matrix required for CQY calculation??? Units???
    cxPlants.Drybean.MatrixCQY      = [0 0 0 0 0;   0     4.191e-2    -1.238e-5   0             0;              0   5.3852e-5   0               -1.544e-11      0;              0   -2.1275e-8  0           6.469e-15   0;  0   0   0               0   0];
    cxPlants.Lettuce.MatrixCQY      = [0 0 0 0 0;   0     4.4763e-2   -1.1701e-5  0             0;              0   5.163e-5    0               -1.9731e-11     0;              0   -2.075e-8   0           8.9265e-15  0;  0   0   0               0   0];
    cxPlants.Peanut.MatrixCQY       = [0 0 0 0 0;   0     4.1513e-2   0           -2.1582e-8    0;              0   5.1157e-5   4.0864e-8       -1.0468e-10     4.8541e-14;     0   -2.099e-8   0           0           0;  0   0   0               0   3.9259e-21];
    cxPlants.Rice.MatrixCQY         = [0 0 0 0 0;   0     3.6186e-2   0           -2.6712e-9    0;              0   6.1457e-5   -9.1477e-9      0               0;              0   -2.4322e-8  3.889e-12   0           0;  0   0   0               0   0];
    cxPlants.Soybean.MatrixCQY      = [0 0 0 0 0;   0     4.1513e-2   0           -2.1582e-8    0;              0   5.1157e-5   4.0864e-8       -1.0468e-10     4.8541e-14;     0   -2.0992e-8  0           0           0;  0   0   0               0   3.9259e-21];
    cxPlants.Sweetpotato.MatrixCQY  = [0 0 0 0 0;   0     3.9317e-2   -1.3836e-5  0             0;              0   5.6741e-5   -6.3397e-9      -1.3464e-11     0;              0   -2.1797e-8  0           7.7362e-15  0;  0   0   0               0   0];
    cxPlants.Tomato.MatrixCQY       = [0 0 0 0 0;   0     4.0061e-2   0           -7.1241e-9    0;              0   5.688e-5    -1.182e-8       0               0;              0   -2.2598e-8  5.0264e-12  0           0;  0   0   0               0   0];
    cxPlants.Wheat.MatrixCQY        = [0 0 0 0 0;   0     4.4793e-2   -5.1946e-6  0             0;              0   5.1583e-5   0               -4.9303e-12     0;              0   -2.0724e-8  0           2.2255e-15  0;  0   0   0               0   0];
    cxPlants.Whitepotato.MatrixCQY  = [0 0 0 0 0;   0     4.6929e-2   0           0             -1.9602e-11;    0   5.0910e-5   0               -1.5272e-11     0;              0   -2.1878e-8  0           0           0;  0   0   4.3976e-15      0   0];
    
    % nominal photoperiod [h/d]
    cxPlants.Drybean.H0     = 12;
    cxPlants.Lettuce.H0     = 16;
    cxPlants.Peanut.H0      = 12;
    cxPlants.Rice.H0        = 12;
    cxPlants.Soybean.H0     = 12;
    cxPlants.Sweetpotato.H0 = 18;
    cxPlants.Tomato.H0      = 12;
    cxPlants.Wheat.H0       = 20;
    cxPlants.Whitepotato.H0 = 12;
    
    % mean atmospheric temperature during crop light cycle [°C]. Where do
    % they come from, what are they used for??? just carried over for now
    cxPlants.Drybean.TemperatureLight       = 26;
    cxPlants.Lettuce.TemperatureLight       = 23;
    cxPlants.Peanut.TemperatureLight        = 26;
    cxPlants.Rice.TemperatureLight          = 29;
    cxPlants.Soybean.TemperatureLight       = 26;
    cxPlants.Sweetpotato.TemperatureLight   = 28;
    cxPlants.Tomato.TemperatureLight        = 26;
    cxPlants.Wheat.TemperatureLight         = 23;
    cxPlants.Whitepotato.TemperatureLight   = 20;
    
    % mean atmospheric temperature during crop dark cycle [°C]. Where do
    % they come from, what are they used for??? just carried over for now
    cxPlants.Drybean.TemperatureDark        = 26;
    cxPlants.Lettuce.TemperatureDark        = 23;
    cxPlants.Peanut.TemperatureDark         = 26;
    cxPlants.Rice.TemperatureDark           = 29;
    cxPlants.Soybean.TemperatureDark        = 26;
    cxPlants.Sweetpotato.TemperatureDark    = 28;
    cxPlants.Tomato.TemperatureDark         = 26;
    cxPlants.Wheat.TemperatureDark          = 23;
    cxPlants.Whitepotato.TemperatureDark    = 20;
    
    % fraction of edible biomass after tE
    cxPlants.Drybean.XFRT = 0.97;
    cxPlants.Lettuce.XFRT = 0.95;
    cxPlants.Peanut.XFRT = 0.49;
    cxPlants.Rice.XFRT = 0.98;
    cxPlants.Soybean.XFRT = 0.95;
    cxPlants.Sweetpotato.XFRT = 1;
    cxPlants.Tomato.XFRT = 0.7;
    cxPlants.Wheat.XFRT = 1;
    cxPlants.Whitepotato.XFRT = 1;
end