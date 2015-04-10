function plant = plant_parameters()

% this routine collects wheat constants of wheat

%global   plant
plant = struct();

        
plant(1).name='Drybean';
plant(2).name='Lettuce';  
plant(3).name='Peanut';  
plant(4).name='Rice';  
plant(5).name='Soybean';  
plant(6).name='Sweetpotato';  
plant(7).name='Tomato';  
plant(8).name='Wheat'; 
plant(9).name='Whitepotato';
        

% legume: legumes have the value =1, 0 otherwise
plant(1).legume=0;%1
plant(2).legume=0;  
plant(3).legume=0;  %1
plant(4).legume=0;  
plant(5).legume=0;  %1
plant(6).legume=0;  
plant(7).legume=0;  
plant(8).legume=0; 
plant(9).legume=0;
        
% n: exponent in A/A_max relation
plant(1).n=2;
plant(2).n=2.5;  
plant(3).n=2;  
plant(4).n=1.5;  
plant(5).n=1.5;  
plant(6).n=1.5;  
plant(7).n=2.5;  
plant(8).n=1; 
plant(9).n=2;

% CQY_min: minimum canopy quantum yield, [mumol Carbon Fixed/mumol Absorbed PPF]
plant(1).CQY_min=0.02;
plant(2).CQY_min=0.01;  %set by me
plant(3).CQY_min=0.02;  
plant(4).CQY_min=0.01;  
plant(5).CQY_min=0.02;  
plant(6).CQY_min=0.01;  %set by me
plant(7).CQY_min=0.01;  
plant(8).CQY_min=0.01; 
plant(9).CQY_min=0.02;

% CUE_max: maximum carbon use efficiency
plant(1).CUE_max=0.65;
plant(2).CUE_max=0.625;  
plant(3).CUE_max=0.65;  
plant(4).CUE_max=0.64;  
plant(5).CUE_max=0.65;  
plant(6).CUE_max=0.625;  
plant(7).CUE_max=0.65;  
plant(8).CUE_max=0.64; 
plant(9).CUE_max=0.625;


% CUE_min: maximum carbon use efficiency 
% only for legumes
plant(1).CUE_min=0.5;
plant(2).CUE_min=0;  
plant(3).CUE_min=0.3;  
plant(4).CUE_min=0;  
plant(5).CUE_min=0.3;  
plant(6).CUE_min=0;  
plant(7).CUE_min=0;  
plant(8).CUE_min=0; 
plant(9).CUE_min=0;

% matrix_CQY: 
plant(1).matrix_CQY=[0 0 0 0 0; 0 4.191e-2 -1.238e-5 0 0; 0 5.3852e-5 0 -1.544e-11 0; 0 -2.1275e-8 0 6.469e-15 0; 0 0 0 0 0];
plant(2).matrix_CQY=[0 0 0 0 0; 0 4.4763e-2 -1.1701e-5 0 0; 0 5.163e-5 0 -1.9731e-11 0; 0 -2.075e-8 0 8.9265e-15 0; 0 0 0 0 0];  
plant(3).matrix_CQY=[0 0 0 0 0; 0 4.1513e-2 0 -2.1582e-8 0; 0 5.1157e-5 4.0864e-8 -1.0468e-10 4.8541e-14; 0 -2.099e-8 0 0 0; 0 0 0 0 3.9259e-21];
plant(4).matrix_CQY=[0 0 0 0 0; 0 3.6186e-2 0 -2.6712e-9 0; 0 6.1457e-5 -9.1477e-9 0 0; 0 -2.4322e-8 3.889e-12 0 0; 0 0 0 0 0]; 
plant(5).matrix_CQY=[0 0 0 0 0; 0 4.1513e-2 0 -2.1582e-8 0; 0 5.1157e-5 4.0864e-8 -1.0468e-10 4.8541e-14; 0 -2.0992e-8 0 0 0; 0 0 0 0 3.9259e-21];  
plant(6).matrix_CQY=[0 0 0 0 0; 0 3.9317e-2 -1.3836e-5 0 0; 0 5.6741e-5 -6.3397e-9 -1.3464e-11 0; 0 -2.1797e-8 0 7.7362e-15 0; 0 0 0 0 0];  
plant(7).matrix_CQY=[0 0 0 0 0; 0 4.0061e-2 0 -7.1241e-9 0; 0 5.688e-5 -1.182e-8 0 0; 0 -2.2598e-8 5.0264e-12 0 0; 0 0 0 0 0];   
plant(8).matrix_CQY=[0 0 0 0 0; 0 4.4793e-2 -5.1946e-6 0 0; 0 5.1583e-5 0 -4.9303e-12 0; 0 -2.0724e-8 0 2.2255e-15 0; 0 0 0 0 0];
plant(9).matrix_CQY=[0 0 0 0 0; 0 4.6929e-2 0 0 -1.9602e-11; 0 5.0910e-5 0 -1.5272e-11 0; 0 -2.1878e-8 0 0 0; 0 0 4.3976e-15 0 0];


% nominal photoperiod [h/d]
plant(1).H0=12;
plant(2).H0=16;  
plant(3).H0=12;  
plant(4).H0=12;  
plant(5).H0=12;  
plant(6).H0=18;  
plant(7).H0=12;  
plant(8).H0=20; 
plant(9).H0=12;


% T_light: mean atmospheric temperature during the crop’s light cycle [°C]
plant(1).T_light=26;
plant(2).T_light=23;  
plant(3).T_light=26;  
plant(4).T_light=29;  
plant(5).T_light=26;  
plant(6).T_light=28;  
plant(7).T_light=26;  
plant(8).T_light=23; 
plant(9).T_light=20;


% T_light: mean atmospheric temperature during the crop’s dark cycle [°C]
plant(1).T_dark=22;
plant(2).T_dark=23;  
plant(3).T_dark=22;  
plant(4).T_dark=21;  
plant(5).T_dark=22;  
plant(6).T_dark=22;  
plant(7).T_dark=22;  
plant(8).T_dark=23; 
plant(9).T_dark=16;


% XFRT: Fraction of Edible Biomass After tE
plant(1).XFRT=0.97;
plant(2).XFRT=0.95;  
plant(3).XFRT=0.49;  
plant(4).XFRT=0.98;  
plant(5).XFRT=0.95;  
plant(6).XFRT=1;  
plant(7).XFRT=0.7;  
plant(8).XFRT=1; 
plant(9).XFRT=1;


% tE: Time at Onset of Edible Biomass Formation (UOT)
plant(1).tE=40;
plant(2).tE=1;  
plant(3).tE=49;  
plant(4).tE=57;  
plant(5).tE=46;  
plant(6).tE=33;  
plant(7).tE=41;  
plant(8).tE=34; 
plant(9).tE=45;

% tQ: Time at Onset of Canopy Senescence (UOT)
plant(1).tQ=42;
plant(2).tQ=48;  %set by me
plant(3).tQ=65;  
plant(4).tQ=61;  
plant(5).tQ=48;  
plant(6).tQ=48;  %set by me
plant(7).tQ=56;  
plant(8).tQ=33; 
plant(9).tQ=75;

% tM: Time at Harvest (UOT)
plant(1).tM_nominal=85;%%63;
plant(2).tM_nominal=30;  
plant(3).tM_nominal=110;    %%110;
plant(4).tM_nominal=88;  
plant(5).tM_nominal=97; %%86;  
plant(6).tM_nominal=120;  
plant(7).tM_nominal=80;  
plant(8).tM_nominal=62; 
plant(9).tM_nominal=138;


% BCF: Biomass Carbon Fraction
plant(1).BCF=0.45;
plant(2).BCF=0.4;  
plant(3).BCF=0.5;  
plant(4).BCF=0.44;  
plant(5).BCF=0.46;  
plant(6).BCF=0.44;  
plant(7).BCF=0.42;  
plant(8).BCF=0.44; 
plant(9).BCF=0.41;


% OPF: Oxygen Production Fraction [mol O2/mol C]
plant(1).OPF=1.1;
plant(2).OPF=1.08;  
plant(3).OPF=1.19;  
plant(4).OPF=1.08;  
plant(5).OPF=1.16;  
plant(6).OPF=1.02;  
plant(7).OPF=1.09;  
plant(8).OPF=1.07; 
plant(9).OPF=1.02;


% matrix_tA: 
plant(1).matrix_tA=[2.9041e5 0 0 0 0; 1.5594e3 15.840 6.1120e-3 0 0; 0 0 0 -3.7409e-9 0; 0 0 0 0 0; 0 0 0 0 9.6484e-19];
plant(2).matrix_tA=[0 0 1.8760 0 0; 1.0289e4 1.7571 0 0 0; -3.7018 0 0 0 0; 0 2.3127e-6 0 0 0; 3.6648e-7 0 0 0 0];  
plant(3).matrix_tA=[3.7487e6 -1.8840e4 51.256 -0.05963 2.5969e-5; 2.9200e3 23.912 0 5.5180e-6 0; 0 0 0 0 0; 0 0 0 0 0; 9.4008e-8 0 0 0 0];
plant(4).matrix_tA=[6.5914e6 -3.748e3 0 0 0; 2.5776e4 0 0 4.5207e-6 0; 0 -0.043378 4.562e-5 -1.4936e-8 0; 6.4532e-3 0 0 0 0; 0 0 0 0 0];
plant(5).matrix_tA=[6.7978e6 -4.326e4 112.63 -0.13637 6.6918e-5; -4.3658e3 33.959 0 0 -2.1367e-8; 1.5573 0 0 0 1.5467e-11; 0 0 -4.911e-9 0 0; 0 0 0 0 0];
plant(6).matrix_tA=[1.2070e6 0 0 0 4.0109e-7; 4.9484e3 4.2978 0 0 0; 0 0 0 0 2.0193e-12; 0 0 0 0 0; 0 0 0 0 0];
plant(7).matrix_tA=[6.2774e5 0 0.44686 0 0; 3.1724e3 24.281 5.6276e-3 -3.0690e-6 0; 0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
plant(8).matrix_tA=[9.5488e4 0 0.3419 -1.9076e-4 0; 1.0686e3 15.977 1.9733e-4 0 0; 0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0]; 
plant(9).matrix_tA=[6.5773e5 0 0 0 0; 8.5626e3 0 0.042749 -1.7905e-5 0; 0 0 8.8437e-7 0 0; 0 0 0 0 0; 0 0 0 0 0];

% minimum, nominal and maximum reference value for light intensity (PPF) (in micromols/m^2/s): 
plant(1).PPF_ref=[200 600 1000];
plant(2).PPF_ref=[200 300 500];
plant(3).PPF_ref=[200 600 1000];
plant(4).PPF_ref=[200 1200 2000]; 
plant(5).PPF_ref=[200 800 1000];
plant(6).PPF_ref=[200 600 1000]; 
plant(7).PPF_ref=[200 500 1000]; 
plant(8).PPF_ref=[200 1400 2000];
plant(9).PPF_ref=[200 655 1000];

% minimum, nominal and maximum reference value for CO2 concentration (C02) (in ppm): 
plant(1).C02_ref=[330 1200 1300];
plant(2).C02_ref=[330 1200 1300];
plant(3).C02_ref=[330 1200 1300];
plant(4).C02_ref=[330 1200 1300]; 
plant(5).C02_ref=[330 1200 1300];
plant(6).C02_ref=[330 1200 1300]; 
plant(7).C02_ref=[330 1200 1300]; 
plant(8).C02_ref=[330 1200 1300];
plant(9).C02_ref=[330 1200 1300];

