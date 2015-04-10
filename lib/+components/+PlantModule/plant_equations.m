function [ this, DOP,CGR,DTR,DCG] = plant_equations(this, t,tA,tQ,tM,PPF,CO2,RH,p_atm,H)
%this program evaluates the derivatives of all states given the states and
%the time-frame. Peculiar plant characteristic are loaded from routine
%xxx.m

% t:time [UOT]
% tA:time after emergence [UOT]
% tM: time at crop harvest or maturity [UOT],
% tQ: time at onset of canopy senescence [UOT].
% H: photoperiod [(UOT)/(UOT)_integration], or light on/off
% PPF: Photosynthetic photon flux [?mol/(m²s)]
% T_light: mean atmospheric temperature during the crop’s light cycle [°C]
% R: mean atmospheric relative humidity as a fraction bounded between 0 and 1
% D_PG: length of the plant growth chamber’s diurnal cycle [h/d] or light on/off
% CO2: carbon dioxide concentration [mumol(CO2) / mol(air)]

RH=0.5;
% A: fraction of PPF absorbed by the plant canopy 
A_max=0.93;
plant_type = this.state.plant_type;

if t<tA
    A=A_max*(t/tA)^this.plant.n;
else
    A=A_max;
end

% CQY_max: maximum canopy quantum yield, [mumol Carbon Fixed/mumol Absorbed PPF]
CQY_max=[1/CO2 1 CO2 CO2^2 CO2^3]*this.plant.matrix_CQY*[1/PPF; 1; PPF; PPF^2; PPF^3];

% CQY: canopy quantum yield [mumol Carbon Fixed/mumol Absorbed PPF]:
if (plant_type==2)||(plant_type==6)||(t<=tQ)
    CQY=CQY_max;
elseif (tQ<=t)&&(t<=tM)
    CQY=CQY_max-(CQY_max-this.plant.CQY_min)*(t-tQ)/(tM-tQ);
else
    CQY=0;
end

% CUE24: 24-hour (UOT) carbon use efficiency
if this.plant.legume==1
    if t<=tQ
        CUE_24=this.plant.CUE_max;
    elseif (tQ<=t)&&(t<=tM)
        CUE_24=this.plant.CUE_max-(this.plant.CUE_max-this.plant.CUE_min)*(t-tQ)/(tM-tQ);
    end
else
    CUE_24=this.plant.CUE_max;
end
this.state.CUE_24=CUE_24;
% DCG: daily (UOT) carbon gain [molCarbon/m^2/(UOT)]
DCG=0.0036*H*CUE_24*A*CQY*PPF;

% DOP: daily (UOT) oxygen production [molO2/m^2/(UOT)]
DOP=this.plant.OPF*DCG;

% MWC: molecular weight of carbon,
MWC=12.011;

% CGR: crop growth rate [g/m^2/(UOT)]
CGR=MWC*DCG/this.plant.BCF;

% VPD: vapor pressure deficit [Pa]
% VP_sat: saturated vapor pressure for air at the mean atmospheric temperature kPa]
% VP_air: actual vapor pressure for the atmosphere [Pa]
VP_sat=611*exp(17.4*this.plant.T_light/(this.plant.T_light+239)); 
VP_air=VP_sat*RH;
VPD=VP_sat-VP_air;
%disp(VP_sat)
%disp(RH)
% P_gross: gross canopy photosynthesis [?molCarbon/(m²s)]
P_gross = A*CQY*PPF;   

% P_net: net canopy photosynthesis [?molCarbon/(m²s)]
D_PG=24;
% P_net=((D_PG-H)/(D_PG)+H*CUE_24/D_PG)*P_gross;
P_net = CUE_24*P_gross;
%disp(P_net)
%disp(CO2)
% gC: canopy surface conductance [molWater/(m²s)]
% gS: canopy stomatal conductance [molWater/(m²s)]
% gA: atmospheric aerodynamic conductance [molWater/(m²s)]
if (plant_type==4)||(plant_type==8)
    % in case of erectophile canopies, such as for rice and wheat
    gS=0.1389+15.32*RH*P_net/CO2;
    gA=5.5;
    
else
    % in case of planophile-type canopies, such as for dry bean, lettuce, peanut, soybean, sweet potato, tomato, and white potato
    gS=(1.717*this.plant.T_light-19.96-10.54*VPD/1000)*P_net/CO2;
    gA=2.5;
   
end
% disp(gS);
% disp(gA);
gC=gA*gS/(gA+gS);
%disp(gC);
% MW_w: molecular weight of water [g/mol]
MW_w=18.015;

% rho_w: density of waterat 20 °C [g/L] 
rho_w=998.23;

% DTR: daily canopy transpiration rate [L Water/(m²(UOT))]
DTR=3600*H*MW_w/rho_w*gC*VPD/p_atm;
%disp(DTR);
% disp(VPD);
% disp(p_atm);
% disp(H);
%#############################################
% CORRELATION OF CGR DOP ANDWATER
if 1
%     C_Drybean = 0.992;
%     C_Lettuce = 0.18;
%     C_Peanut = 1.439;
%     C_Rice = 0.7;
%     C_Soybean = 0.726;
%     C_Sweetpotato = 0.78;
%     C_Tomato = 0.688;
%     C_Wheat = 0.714;
% 
%     
%     C_Water_Drybean = 1,571;
%     C_Water_Lettuce = 1.399;
%     C_Water_Peanut = 2.568;
%     C_Water_Rice = 0.639;
%     C_Water_Soybean = 2.896;
%     C_Water_Sweetpotato = 0.796;
%     C_Water_Tomato = 1.473;
%     C_Water_Wheat =     1.91;
CORR_fct = [0.992 0.18 1.439 0.7 0.726 0.78 0.688 0.714 1; 1.571 1.399 2.568 0.639 2.896 0.796 1.473 1.91 1];


    CGR = CGR*CORR_fct(1,plant_type);
    DOP = DOP*32*CORR_fct(1,plant_type);
    DTR = DTR*CORR_fct(2,plant_type);
else
    DOP = DOP*32;
end

% ########################################
this.state.A=A;
this.state.P_net=P_net;
this.state.CGR=CGR;
this.state.CQY=CQY;
