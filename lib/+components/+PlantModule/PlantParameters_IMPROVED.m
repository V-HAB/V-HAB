function [ cxPlantsRETURNED ] = PlantParameters_IMPROVED(sPlantSpecies)

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
    
    % minimum canopy quantum yield (CQY at time of crop maturity (tM))
    % [µmol_carbon/µmol_AbsPPF]
    cxPlants.Drybean.CQY_Min        = 0.02;
    cxPlants.Lettuce.CQY_Min        = 0.01; % set by someone in original file
    cxPlants.Peanut.CQY_Min         = 0.02;
    cxPlants.Rice.CQY_Min           = 0.01;
    cxPlants.Soybean.CQY_Min        = 0.02;
    cxPlants.Sweetpotato.CQY_Min    = 0.01; % set by someone in original file
    cxPlants.Tomato.CQY_Min         = 0.01;
    cxPlants.Wheat.CQY_Min          = 0.01;
    cxPlants.Whitepotato.CQY_Min    = 0.02;
    
    % maximum carbon use efficiency         [-]
    cxPlants.Drybean.CUE_Max        = 0.65;
    cxPlants.Lettuce.CUE_Max        = 0.625;
    cxPlants.Peanut.CUE_Max         = 0.65;
    cxPlants.Rice.CUE_Max           = 0.64;
    cxPlants.Soybean.CUE_Max        = 0.65;
    cxPlants.Sweetpotato.CUE_Max    = 0.625;
    cxPlants.Tomato.CUE_Max         = 0.65;
    cxPlants.Wheat.CUE_Max          = 0.64;
    cxPlants.Whitepotato.CUE_Max    = 0.625;
    
    % minimum carbon use efficiency, only for legumes???    [-]
    cxPlants.Drybean.CUE_Min        = 0.5;
    cxPlants.Lettuce.CUE_Min        = 0;
    cxPlants.Peanut.CUE_Min         = 0.3;
    cxPlants.Rice.CUE_Min           = 0;
    cxPlants.Soybean.CUE_Min        = 0.3;
    cxPlants.Sweetpotato.CUE_Min    = 0;
    cxPlants.Tomato.CUE_Min         = 0;
    cxPlants.Wheat.CUE_Min          = 0;
    cxPlants.Whitepotato.CUE_Min    = 0;
    
    % matrix required for CQY calculation??? Units???
    % coefficient matrix, units depend on coefficient
    cxPlants.Drybean.Matrix_CQY         = [0 0 0 0 0;   0     4.191e-2    -1.238e-5   0             0;              0   5.3852e-5   0               -1.544e-11      0;              0   -2.1275e-8  0           6.469e-15   0;  0   0   0               0   0];
    cxPlants.Lettuce.Matrix_CQY         = [0 0 0 0 0;   0     4.4763e-2   -1.1701e-5  0             0;              0   5.163e-5    0               -1.9731e-11     0;              0   -2.075e-8   0           8.9265e-15  0;  0   0   0               0   0];
    cxPlants.Peanut.Matrix_CQY          = [0 0 0 0 0;   0     4.1513e-2   0           -2.1582e-8    0;              0   5.1157e-5   4.0864e-8       -1.0468e-10     4.8541e-14;     0   -2.099e-8   0           0           0;  0   0   0               0   3.9259e-21];
    cxPlants.Rice.Matrix_CQY            = [0 0 0 0 0;   0     3.6186e-2   0           -2.6712e-9    0;              0   6.1457e-5   -9.1477e-9      0               0;              0   -2.4322e-8  3.889e-12   0           0;  0   0   0               0   0];
    cxPlants.Soybean.Matrix_CQY         = [0 0 0 0 0;   0     4.1513e-2   0           -2.1582e-8    0;              0   5.1157e-5   4.0864e-8       -1.0468e-10     4.8541e-14;     0   -2.0992e-8  0           0           0;  0   0   0               0   3.9259e-21];
    cxPlants.Sweetpotato.Matrix_CQY     = [0 0 0 0 0;   0     3.9317e-2   -1.3836e-5  0             0;              0   5.6741e-5   -6.3397e-9      -1.3464e-11     0;              0   -2.1797e-8  0           7.7362e-15  0;  0   0   0               0   0];
    cxPlants.Tomato.Matrix_CQY          = [0 0 0 0 0;   0     4.0061e-2   0           -7.1241e-9    0;              0   5.688e-5    -1.182e-8       0               0;              0   -2.2598e-8  5.0264e-12  0           0;  0   0   0               0   0];
    cxPlants.Wheat.Matrix_CQY           = [0 0 0 0 0;   0     4.4793e-2   -5.1946e-6  0             0;              0   5.1583e-5   0               -4.9303e-12     0;              0   -2.0724e-8  0           2.2255e-15  0;  0   0   0               0   0];
    cxPlants.Whitepotato.Matrix_CQY     = [0 0 0 0 0;   0     4.6929e-2   0           0             -1.9602e-11;    0   5.0910e-5   0               -1.5272e-11     0;              0   -2.1878e-8  0           0           0;  0   0   4.3976e-15      0   0];
    
    % nominal photoperiod [h/d]
    cxPlants.Drybean.H_Nominal        = 12;
    cxPlants.Lettuce.H_Nominal        = 16;
    cxPlants.Peanut.H_Nominal         = 12;
    cxPlants.Rice.H_Nominal           = 12;
    cxPlants.Soybean.H_Nominal        = 12;
    cxPlants.Sweetpotato.H_Nominal    = 18;
    cxPlants.Tomato.H_Nominal         = 12;
    cxPlants.Wheat.H_Nominal          = 20;
    cxPlants.Whitepotato.H_Nominal    = 12;
    
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
    
    % fraction of edible biomass after onset of edible biomass (tE) [-]
    cxPlants.Drybean.XFRT = 0.97;
    cxPlants.Lettuce.XFRT = 0.95;
    cxPlants.Peanut.XFRT = 0.49;
    cxPlants.Rice.XFRT = 0.98;
    cxPlants.Soybean.XFRT = 0.95;
    cxPlants.Sweetpotato.XFRT = 1;
    cxPlants.Tomato.XFRT = 0.7;
    cxPlants.Wheat.XFRT = 1;
    cxPlants.Whitepotato.XFRT = 1;
    
    % time at onset of edible biomass (tE)      [days]
    cxPlants.Drybean.T_E        = 40;
    cxPlants.Lettuce.T_E        = 1;
    cxPlants.Peanut.T_E         = 49;
    cxPlants.Rice.T_E           = 57;
    cxPlants.Soybean.T_E        = 46;
    cxPlants.Sweetpotato.T_E    = 33;
    cxPlants.Tomato.T_E         = 41;
    cxPlants.Wheat.T_E          = 34;
    cxPlants.Whitepotato.T_E    = 45;
    
    % time at onset of canopy senescence (tQ)   [days]
    cxPlants.Drybean.T_Q        = 42;
    cxPlants.Lettuce.T_Q        = 48;
    cxPlants.Peanut.T_Q         = 65;
    cxPlants.Rice.T_Q           = 61;
    cxPlants.Soybean.T_Q        = 48;
    cxPlants.Sweetpotato.T_Q    = 48;
    cxPlants.Tomato.T_Q         = 56;
    cxPlants.Wheat.T_Q          = 33;
    cxPlants.Whitepotato.T_Q    = 75;
    
    % time at harvest or crop maturity (tM)      [days]
    % Source: "Baseline Values and Assumptions Document" 2015 - table 4.119
    % (There are some differing harvest times available, stated in the same document, table: 4.97)
    cxPlants.Drybean.T_M_Nominal        = 63;
    cxPlants.Lettuce.T_M_Nominal        = 30;
    cxPlants.Peanut.T_M_Nominal         = 110;
    cxPlants.Rice.T_M_Nominal           = 88;
    cxPlants.Soybean.T_M_Nominal        = 86;
    cxPlants.Sweetpotato.T_M_Nominal    = 120;
    cxPlants.Tomato.T_M_Nominal         = 80;
    cxPlants.Wheat.T_M_Nominal          = 62;
    cxPlants.Whitepotato.T_M_Nominal    = 138;
    
    % Biomas Carbon Fraction (BCF)      [-]
    cxPlants.Drybean.BCF        = 0.45;
    cxPlants.Lettuce.BCF        = 0.4;
    cxPlants.Peanut.BCF         = 0.5;
    cxPlants.Rice.BCF           = 0.44;
    cxPlants.Soybean.BCF        = 0.46;
    cxPlants.Sweetpotato.BCF    = 0.44;
    cxPlants.Tomato.BCF         = 0.42;
    cxPlants.Wheat.BCF          = 0.44;
    cxPlants.Whitepotato.BCF    = 0.41;
    
    % Oxygen Production Fraction (OPF)   [mol O2/mol C]
    cxPlants.Drybean.OPF        = 1.1;
    cxPlants.Lettuce.OPF        = 1.08;
    cxPlants.Peanut.OPF         = 1.19;
    cxPlants.Rice.OPF           = 1.08;
    cxPlants.Soybean.OPF        = 1.16;
    cxPlants.Sweetpotato.OPF    = 1.02;
    cxPlants.Tomato.OPF         = 1.09;
    cxPlants.Wheat.OPF          = 1.02;
    cxPlants.Whitepotato.OPF    = 1.07;
    
    % coefficient matrix, units depend on coefficient 
    cxPlants.Drybean.Matrix_T_A        = [2.9041e5  0           0           0           0;          1.5594e3    15.840  6.1120e-3   0           0;              0           0           0           -3.7409e-9  0;              0           0           0           0   0;  0           0   0   0   9.6484e-19];
    cxPlants.Lettuce.Matrix_T_A        = [0         0           1.8760      0           0;          1.0289e4    1.7571  0           0           0;              -3.7018     0           0           0           0;              0           2.3127e-6   0           0   0;  3.6648e-7   0   0   0   0];
    cxPlants.Peanut.Matrix_T_A         = [3.7487e6  -1.8840e4   51.256      -0.05963    2.5969e-5;  2.9200e3    23.912  0           5.5180e-6   0;              0           0           0           0           0;              0           0           0           0   0;  9.4008e-8   0   0   0   0];
    cxPlants.Rice.Matrix_T_A           = [6.5914e6  -3.748e3    0           0           0;          2.5776e4    0       0           4.5207e-6   0;              0           -0.043378   4.562e-5    -1.4936e-8  0;              6.4532e-3   0           0           0   0;  0           0   0   0   0];
    cxPlants.Soybean.Matrix_T_A        = [6.7978e6  -4.326e4    112.63      -0.13637    6.6918e-5;  -4.3658e3   33.959  0           0           -2.1367e-8;     1.5573      0           0           0           1.5467e-11;     0           0           -4.911e-9   0   0;  0           0   0   0   0];
    cxPlants.Sweetpotato.Matrix_T_A    = [1.2070e6  0           0           0           4.0109e-7;  4.9484e3    4.2978  0           0           0;              0           0           0           0           2.0193e-12;     0           0           0           0   0;  0           0   0   0   0];
    cxPlants.Tomato.Matrix_T_A         = [6.2774e5  0           0.44686     0           0;          3.1724e3    24.281  5.6276e-3   -3.0690e-6  0;              0           0           0           0           0;              0           0           0           0   0;  0           0   0   0   0];
    cxPlants.Wheat.Matrix_T_A          = [9.5488e4  0           0.3419      -1.9076e-4  0;          1.0686e3    15.977  1.9733e-4   0           0;              0           0           0           0           0;              0           0           0           0   0;  0           0   0   0   0];
    cxPlants.Whitepotato.Matrix_T_A    = [6.5773e5  0           0           0           0;          8.5626e3    0       0.042749    -1.7905e-5  0;              0           0           8.8437e-7   0           0;              0           0           0           0   0;  0           0   0   0   0];
    
    % minimum, nominal and maximum allowed values for photosynthetic photon 
    % flux density (PPF)    [µmol/m^2s]
    cxPlants.Drybean.PPF_Min        = 200;
    cxPlants.Lettuce.PPF_Min        = 200;
    cxPlants.Peanut.PPF_Min         = 200;
    cxPlants.Rice.PPF_Min           = 200;
    cxPlants.Soybean.PPF_Min        = 200;
    cxPlants.Sweetpotato.PPF_Min    = 200;
    cxPlants.Tomato.PPF_Min         = 200;
    cxPlants.Wheat.PPF_Min          = 200;
    cxPlants.Whitepotato.PPF_Min    = 200;
    
    cxPlants.Drybean.PPF_Nominal        = 600;
    cxPlants.Lettuce.PPF_Nominal        = 300;
    cxPlants.Peanut.PPF_Nominal         = 600;
    cxPlants.Rice.PPF_Nominal           = 1200;
    cxPlants.Soybean.PPF_Nominal        = 800;
    cxPlants.Sweetpotato.PPF_Nominal    = 600;
    cxPlants.Tomato.PPF_Nominal         = 500;
    cxPlants.Wheat.PPF_Nominal          = 1400;
    cxPlants.Whitepotato.PPF_Nominal    = 655;
    
    cxPlants.Drybean.PPF_Max        = 1000;
    cxPlants.Lettuce.PPF_Max        = 500;
    cxPlants.Peanut.PPF_Max         = 1000;
    cxPlants.Rice.PPF_Max           = 2000;
    cxPlants.Soybean.PPF_Max        = 1000;
    cxPlants.Sweetpotato.PPF_Max    = 1000;
    cxPlants.Tomato.PPF_Max         = 1000;
    cxPlants.Wheat.PPF_Max          = 2000;
    cxPlants.Whitepotato.PPF_Max    = 1000;
    
    % minimum, nominal und maximum allowed values for CO2 concentration
    % [ppm]
    cxPlants.Drybean.CO2_Min        = 330;
    cxPlants.Lettuce.CO2_Min        = 330;
    cxPlants.Peanut.CO2_Min         = 330;
    cxPlants.Rice.CO2_Min           = 330;
    cxPlants.Soybean.CO2_Min        = 330;
    cxPlants.Sweetpotato.CO2_Min    = 330;
    cxPlants.Tomato.CO2_Min         = 330;
    cxPlants.Wheat.CO2_Min          = 330;
    cxPlants.Whitepotato.CO2_Min    = 330;
    
    cxPlants.Drybean.CO2_Nominal        = 1200;
    cxPlants.Lettuce.CO2_Nominal        = 1200;
    cxPlants.Peanut.CO2_Nominal         = 1200;
    cxPlants.Rice.CO2_Nominal           = 1200;
    cxPlants.Soybean.CO2_Nominal        = 1200;
    cxPlants.Sweetpotato.CO2_Nominal    = 1200;
    cxPlants.Tomato.CO2_Nominal         = 1200;
    cxPlants.Wheat.CO2_Nominal          = 1200;
    cxPlants.Whitepotato.CO2_Nominal    = 1200;
    
    cxPlants.Drybean.CO2_Max        = 1300;
    cxPlants.Lettuce.CO2_Max        = 1300;
    cxPlants.Peanut.CO2_Max         = 1300;
    cxPlants.Rice.CO2_Max           = 1300;
    cxPlants.Soybean.CO2_Max        = 1300;
    cxPlants.Sweetpotato.CO2_Max    = 1300;
    cxPlants.Tomato.CO2_Max         = 1300;
    cxPlants.Wheat.CO2_Max          = 1300;
    cxPlants.Whitepotato.CO2_Max    = 1300;
    
    % fraction of nutrient consumed for gained biomass (NCfr) - used for calculation macronutrients uptake
    % Source: Baseline Values and Assumptions Document 2015 - Table 4.101
    % "Stock Usage per Dry Biomass"
    % [g_Nutrients/g_DryBiomass] - only available for Soybean, Wheat, Potatos, Lettuce
    cxPlants.Drybean.NC_Fraction        = 0;
    cxPlants.Lettuce.NC_Fraction        = 0.034;
    cxPlants.Peanut.NC_Fraction         = 0;
    cxPlants.Rice.NC_Fraction           = 0;
    cxPlants.Soybean.NC_Fraction        = 0.026;
    cxPlants.Sweetpotato.NC_Fraction    = 0.022;
    cxPlants.Tomato.NC_Fraction         = 0;
    cxPlants.Wheat.NC_Fraction          = 0.021;
    cxPlants.Whitepotato.NC_Fraction    = 0.022;
    
    % Crop  dry over wet  biomass fraction (DRYfr), will be named DBF here
    % since Water Biomass Fraction is WBF
    % -->  DRYfr = 1-WBF (Water biomass fraction); averaged from edible and
    % inedible biomass
    % Source: Derived from "Baseline Values and Assumptions Document" 2015 - Table 4.98
    % --> ratio of productivity [g_DryBiomass/g_WetBiomass]
    cxPlants.Drybean.DBF        = 0.155;
    cxPlants.Lettuce.DBF        = 0.053;
    cxPlants.Peanut.DBF         = 0.129;
    cxPlants.Rice.DBF           = 0.136;
    cxPlants.Soybean.DBF        = 0.171;
    cxPlants.Sweetpotato.DBF    = 0.036;
    cxPlants.Tomato.DBF         = 0.076;
    cxPlants.Wheat.DBF          = 0.155;
    cxPlants.Whitepotato.DBF    = 0.154;
    
    % Water Biomass Fraction (WBF) of edible biomass (for inedible biomass 
    % it is always assumed to be 0.9, see BVAD)
    cxPlants.Drybean.WBF        = 0.10;
    cxPlants.Lettuce.WBF        = 0.95;
    cxPlants.Peanut.WBF         = 0.056;
    cxPlants.Rice.WBF           = 0.12;
    cxPlants.Soybean.WBF        = 0.10;
    cxPlants.Sweetpotato.WBF    = 0.71;
    cxPlants.Tomato.WBF         = 0.94;
    cxPlants.Wheat.WBF          = 0.12;
    cxPlants.Whitepotato.WBF    = 0.80;
    
    % crop coefficients for water model     [-]
    cxPlants.Drybean.KC_Mid        = 1.15;
    cxPlants.Lettuce.KC_Mid        = 1.3;
    cxPlants.Peanut.KC_Mid         = 1.3;
    cxPlants.Rice.KC_Mid           = 1.2;
    cxPlants.Soybean.KC_Mid        = 1.25;
    cxPlants.Sweetpotato.KC_Mid    = 1.15;
    cxPlants.Tomato.KC_Mid         = 1.32;
    cxPlants.Wheat.KC_Mid          = 1.2;
    cxPlants.Whitepotato.KC_Mid    = 1.3;
    
    cxPlants.Drybean.KC_Late        = 0.35;
    cxPlants.Lettuce.KC_Late        = 0.95;
    cxPlants.Peanut.KC_Late         = 0.60;
    cxPlants.Rice.KC_Late           = 0.90;
    cxPlants.Soybean.KC_Late        = 0.50;
    cxPlants.Sweetpotato.KC_Late    = 0.65;
    cxPlants.Tomato.KC_Late         = 0.70;
    cxPlants.Wheat.KC_Late          = 1.2;
    cxPlants.Whitepotato.KC_Late    = 0.75;
    
    % Planting Density (how many plants per m^2)
    cxPlants.Drybean.PlantingDensity        = 7;
    cxPlants.Lettuce.PlantingDensity        = 19.2;
    cxPlants.Peanut.PlantingDensity         = 7;
    cxPlants.Rice.PlantingDensity           = 200;
    cxPlants.Soybean.PlantingDensity        = 35;
    cxPlants.Sweetpotato.PlantingDensity    = 16;
    cxPlants.Tomato.PlantingDensity         = 6.3;
    cxPlants.Wheat.PlantingDensity          = 720;
    cxPlants.Whitepotato.PlantingDensity    = 6.4;
    
    cxPlantsRETURNED = cxPlants.(sPlantSpecies);
end