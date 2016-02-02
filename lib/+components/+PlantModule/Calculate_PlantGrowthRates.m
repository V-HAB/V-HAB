function [aoPlants ,HOP_net ,HCC_net ,HCGR ,HTR ,HWC ] = ...
    Calculate_PlantGrowthRates(aoPlants, t, tA, tQ, tM, PPF, CO2, RH_day, RH_night, p_atm, H, Temp_light, Temp_dark,fDensityH2O)

% Short description:
%  Basic plant growth rates are calculated within this function.


%  This function uses the formulas for plant growth adapted by the University
%  of Arizonas lunar greenhouse team. They are derived from the Modified Energy Cascade Modell (MEC) by Cavazzoni
%  paper: "Modified energy cascade model adapted for a mutlicrop Lunar
%  greenhouse prototype" Advanced In Space Research 50 - p.941-951 (2012)

%Output Parameters are:
    %   aoPlants    -       references the object '...fCCulture.plants{i, 1}' which is
    %                       including plant growth data and where several parameters are logged here                [-]  
    %   HOP_net     -       net hourly oxygen production -> can be positiv or negativ depending on growth cycle     [g/m^2/h]
    %   HCC_net     -       net hourly carbon dioxide consumption -> can be positiv or negativ depending on growth cycle
    %                                                                                                               [g/m^2/h]
    %   HCGR        -       hourly crop growth rate                                                                 [g/m^2/h]
    %   HTR         -       hourly water transpiration rate                                                         [g_water/m^2/h]                                                                
    %   HWC         -       hourly water consumption                                                                [g_water/m^2/h]
    
    
%Input Parameters are:
    %   aoPlants    -       references the object '...fCCulture.plants{i, 1}' which is
    %                       including plant growth data and where several parameters are logged here                [-]  
    %   t           -       time [min] regarding the growth cycle of the current culture (variable  i  above)       [min]
    %   tA          -       time till canopy closure                                                                [min]
    %   tQ          -       time of onset of canopy closure                                                         [min]
    %   tM          -       time of crop maturity /harvest time                                                     [min]
    %   PPF         -       photosynthetic photon flux                                                              [µmol/m^2/s]
    %   CO2         -       CO2 level                                                                               [µmol/mol]
    %   RH_day      -       relative humidity day                                                                   [-]
    %   RH_night    -       relative humidity night                                                                 [-]
    %   p_atm       -       air-phase pressure                                                                      [Pa]
    %   H           -       photoperiod per day                                                                     [h/d]
    %   Temp_light  -       mean air temperature                                                                    [°C]
    
    
    
%Setting Photo- and Night period factor
% used for calculating HCG, which is reused in several other equations
    if mod(t, 1440) < H*60
        %Photo period
        I       = 1;        % [-]    
        RH      = RH_day;   % [-]   
    else
        %Dark period
        I       = 0;        % [-]    
        RH      = RH_night; % [-]
    end
    
    %Guaranteeing allowed RH range between 0 and 1
        if RH < 0
            RH = 0;
        end
        if RH > 1
            RH = 1;
        end
        
% crop coefficient for water transpiration calculation
Kcmid  = aoPlants.plant.Kcmid;
Kclate = aoPlants.plant.Kclate;

%PARSOL-Conversion factor of PAR to solar radiation[-]
PARSOL = 0.45;%

%TODO Get these values differently, best from matter table constants
%struct. But not like Avogadro number, that is slow. Just pass the matter
%table to this function as a parameter.
%planck constant in [m^2kgs^-1]
h=6.626*10^-34; 
%speed of light in [m/s]
c=2.998*10^8;
%Avogrado constant in[Photons*mol^-1]
N_A=matter.table.Const.fAvogadro;%

%Avarege wavelenght in [m]
delta=535*10^-9;
ho=h*c/delta;

%%Energy per mol PAR in [MJmolSolar^-1]
Em = ho*N_A*10^-6;

%specific heat capaticity of air at 293.15 K[J/kgK]
c_p=1005;

%Plant type from call (-> defined plant setup "PlantEng.mat")
    plant_type = aoPlants.state.plant_type; %[-] 
    
%A_max: maximum fraction of incident irradiance absorbed by the canopy
    A_max = 0.93; %[-]
    
%Calculation of fraction of incident irradiance absorbed by the canopy
    if t < tA
        A = A_max * (t/tA) ^ aoPlants.plant.n; %[-]
    else
        A = A_max; %[-]
    end
    
    
% CQY_max: maximum canopy quantum yield 
    CQY_max = [1/CO2 1 CO2 CO2^2 CO2^3] * aoPlants.plant.matrix_CQY * [1/PPF; 1; PPF; PPF^2; PPF^3]; %[mumol Carbon Fixed/mumol Absorbed PPF] = [-]


% CQY: canopy quantum yield 
    if (plant_type==2)||(plant_type==6)||(t<=tQ)
        CQY     = CQY_max; %[mumol Carbon Fixed/mumol Absorbed PPF] = [-]
    elseif (tQ<=t) && (t<=tM)
        CQY     = CQY_max - (CQY_max-aoPlants.plant.CQY_min) * (t-tQ)/(tM-tQ); %[mumol Carbon Fixed/mumol Absorbed PPF] = [-]
    else
        CQY     = 0; %[-]
    end
    
% CUE24: 24-hour (UOT) carbon use efficiency
    if aoPlants.plant.legume==1
        if t<=tQ
            CUE_24 = aoPlants.plant.CUE_max; %[-]
        elseif (tQ<=t) && (t<=tM)
            CUE_24 = aoPlants.plant.CUE_max - (aoPlants.plant.CUE_max - aoPlants.plant.CUE_min) * (t-tQ)/(tM-tQ); %[-]
        end
    else
        CUE_24 = aoPlants.plant.CUE_max; %[-]
    end
    aoPlants.state.CUE_24 = CUE_24; %[-]
    
    

    
%Hourly carbon gain
    HCG = 0.0036 * CUE_24 * A * CQY * PPF * I;   %[mol_carbon/m^2/h]
    
    
  % MWC: molar weight of carbon
    MWC = 12.011;         %[g/mol]
  % MWO2: molar weight of oxygen
    MWO2 = 32;            %[g/mol]
  % MWCO2: molar weight of carbon dioxid
    MWCO2 = 44.011;       %[g/mol]
  % MWW: molar weight of water
    MWW = 18.015;         %[g/mol]
    
    
%Hourly crop growth rate on a dry basis
    HCGR = HCG * MWC / aoPlants.plant.BCF;  %[g/m^2/h]
    
    
%Hourly crop growth rate on a wet basis
    HWCGR = HCGR / (1 - aoPlants.plant.WBF);   %[g/m^2/h]

    
%Hourly oxygen production
    HOP = HCG / CUE_24 * aoPlants.plant.OPF * MWO2;   %[g/m^2/h]
%Hourly oxygen consumption
    HOC = 0.0036 * CUE_24 * A * CQY * PPF * (1 - CUE_24)/CUE_24 * aoPlants.plant.OPF * MWO2 * H/24; %[g/m^2/h]
    
    %Hourly net oxygen production
        HOP_net = HOP - HOC;   %[g/m^2/h]
        
% Calculation of e_a, the Atmospheric vapor pressure in Pa and es, the
% saturaion vapor pressure at mean atmospheric temperature in Pa

%%%Vapor Pressure for Light and Dark Phases
VP_light= 0.6108 * exp( 17.27 * Temp_light / ( Temp_light + 237.3 )); 
VP_dark = 0.6108 * exp( 17.27 * Temp_dark  / ( Temp_dark  + 237.3 ));

e_s = (VP_light+VP_dark)/2*1000;

e_a = e_s*RH; %%% relative humidity consant factor in closed environemnts ! simplified equation
        
        
% P_net: net canopy photosynthesis 
    P_net = A * CQY * PPF;                  %[µmol_carbon/m^2/s]
        
%%Rate of change of saturation specific humidity with air temperature in [Pa/K]
d = 1000 * 4098 * 0.6108 *exp( 17.27 * Temp_light / ( Temp_light + 237.3 )) / (( Temp_light + 237)^2 ); 

%%%Volumetric latent heat of vaporization in [MJ/kg]
L_v=2.45*10^6;

%Psychometric constant in [Pa/K]
gamma = 0.665*(10^-3)*p_atm;

%%%Netsolar irradiance in [Wm^-2]
Rn = (PPF/PARSOL)*Em; 

%%%stomatal conductance in [m^(2)smol^-1]
gS = 8.2*RH*(P_net/CO2);

%%%crop height of grass in [m]
h=0.12;

%%%Leaf Area Index [-]
LAI = 24*h;

%%%Leaf Area Active Index [-]
LAI_active = 0.5*LAI;

%%%bulk stomatal resistance[sm^-1]
r1= 1/(0.025*gS);

%%%bulk surface resistance [sm^-1]
r_s = r1/LAI_active; 

%%%soil heat flux in [Wm^-2]
G = 0; 

%%%wind speed in [m/s]
u=1.5; 

%%%aerodynamic resistance[sm^-1]
r_a =  208/u; 

%dry air density [kg/m^3]
rho_a = 1.2922; 

%%%PENMAN-Monteith equation ET_0 in [Lm^-2s^-1]
a = d*(Rn-G)+ rho_a*c_p*(e_s-e_a)/r_a;
b = (d+gamma*(1+r_s/r_a))*L_v;

ET_0 = a/b; 

%%% Crop Coefficient development during plant growth

if t < tA
    
K_c = Kcmid*(t/tA)^aoPlants.plant.n;

elseif (tA<=t)&&(t<=tQ)
    
K_c = Kcmid;

else
    
K_c = Kcmid + ((t-tQ)/(tM-tQ))*(Kclate - Kcmid);

end


%%%Final Water volume evapotranspiration ET_c in [Lm^-2s^-1]
ET_c = K_c*ET_0;

% Conversion to hourly transpiration rate
HTR = ET_c * 3600 * fDenstiyH2O; % [g/m^2/h]


 %Hourly CO2 consumption rate
    HCO2C = HOP * MWCO2/MWO2;       %[g/m^2/h]
 %Hourly CO2 production rate
    HCO2P = HOC * MWCO2/MWO2;       %[g/m^2/h]
    
    %Daily CO2 net consumption rate
        HCC_net = HCO2C - HCO2P;    %[g/m^2/h]
        
        
 %Hourly plant macrontutrients uptake 
    HNC = HCGR * aoPlants.plant.DRYfr * aoPlants.plant.NCfr;  %[g/m^2/h]
    
    
    
 %Water balance
 %Hourly Water Consumtion 
    HWC = HTR + HOP + HCO2P + HWCGR - HOC - HCO2C - HNC;  %[g_water/m^2/h]
    

    
    
    
