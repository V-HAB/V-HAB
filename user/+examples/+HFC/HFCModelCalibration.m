% IL used in model is [Bmim][Ac]
% Numbers used in this model correspond to inputs for SolidWorks flow sim

%% Housekeeping
clear all
clc

%% Load Experimental Data
load('C:\Users\ge52qut\VHAB\STEPS2\user\+hojo\+ILCO2\AllCharData.mat')

%% Universal Constants
R = 8.3145;             % Gas Constant              [J/mol*K]
T = 303;                % Room Temperature          [K]
T_std = 273.15;
P = 8.41e4;
P_std = 1e5;

%% Hollow Fiber Contactor Constants
% Length of the flow channels:
L_gas = 0.1524;        % [m] (215 in) length of gas channel from solid model
L_liquid = 0.1524/2;      % 
fCount = 118;
% Cross sectional area of the flow channels:
% A_x_gas = 1.4180e-05;   % [m^2] (0.25 in x 0.125 in) gas flow channel cross sectional area from solid model
% A_x_liquid = 2*((pi/4)*((0.364)*2.54/100)^2);   % [m^2] (0.125" x 0.25" flow channel)
fFiberInnerDiameter  = 0.00039116;  % m
fCrossSectionLumen   = (pi/4) * fFiberInnerDiameter^2;
fShellInnerDiameter  = 0.03683;  % m
fFiberThickness      = 0.00014;  % m
fFiberOuterDiameter  = fFiberInnerDiameter + 2 * fFiberThickness;         % m
                           % m^2
fCrossSectionLumenTotal = fCrossSectionLumen * fCount; % m^2
fCrossSectionShellTotal = (pi/4)*fShellInnerDiameter^2 - fCrossSectionLumenTotal;   % m^2
A_x_gas = fCrossSectionLumenTotal;
A_x_liquid = fCrossSectionShellTotal;
fHydraulicDiameter = (fShellInnerDiameter^2 - (fCount * (fFiberOuterDiameter^2))) / (fCount * (fFiberOuterDiameter));

A_HFM = 0.0379;    % Contact Area [m^2] (52.5 in^2, from solid model)
V_HFM = 2.1611e-06;     % Contact Volume [m^3] (6.563 in^3 from solid model)
L_c_HFM = 0.00065;      % Char. Length [m] Hydraulic diameter of sorbent channel

%% IL properties
v_d = 200;              % Dyn. Visc. of IL [406 mPa-s] @ 303 K, (Yates/Space 2016 paper)
p = 1.0561;             % Density of IL [1.0538 g cm^-3] @ 303 K, (Bogolitsyn 2008)
v = (v_d/p)*(1e-6);     % Kin. Visc. [m^2/s] *equation standard*
D = 2.079e-10;        % Diffusivity of CO2 in IL  [m^2/s] *equation standard* (Santos 2014)
% Q_l = HFC_IL(1,1);      % IL Flow Rate              [mL/min]
% Q_l = Q_l*1.6667E-8;    % IL Flow Rate              [m^3/s]
Q_l = 1.5e-6;
vl = Q_l/A_x_liquid;    % Average Liq Velocity      [m/s]
Re = ((vl*fHydraulicDiameter)/v);  % Reynolds Number for the IL
Sc = v/D;               % Schmidt Number for the IL

%% Gas Properties
delta_C = 2;                % Concentration Gradient    [torr]
Q_g_std = HFC_Gas(:,1)./60000;  % Gas Flow Rate             [m^3/s]
Q_g = Q_g_std*(T/T_std)*(P_std/P);
vg  = Q_g./A_x_gas;         % Average Gas Velocity      [m/s]
tg  = (L_gas)./vg;            % Residence Time            [s]
dP = HFC_Gas(:,2).*(P_std./P).*(T./T_std);

%% Define Const
Const = D*delta_C*A_HFM*1e6/(L_c_HFM*V_HFM*760)*(P_std./P).*(T./T_std);

%% Define Model Fit
b = 2/3;
c = 1/3;
fo = fitoptions('Method','NonlinearLeastSquares',...
                'Lower',0,...
                'Upper',15,...
                'StartPoint',0.34...
                );
%                ,'Weights',1./(FPC_Gas_E(:,2).^2));
ft = fittype('a*(Re^b)*(Sc^c)*Const*x','problem',{'Re','Sc','Const','c','b'},'options',fo);
[HFC_Gas_MC,HFC_Gas_MC_GOF] = fit(tg,dP,ft,'problem',{Re,Sc,Const,c,b}) %#ok<NOPTS>

%% Reference Coefficients:
% a = 0.646;
% b = 1/2;
% c = 1/3;
% from Cussler 2008 *I actually think we should go with this correlation*
% Sh = a*(Re^b)*(Sc^c); %(Sherwood number)

%% Prepare Model for Plotting
HFC_Gas_MC_PX   = 0.1:0.1:0.9;
HFC_Gas_MC_PY   = HFC_Gas_MC(L_gas./(HFC_Gas_MC_PX./(A_x_gas*60000)));

%% Make Plots
h1 = figure('units','normalized','position',[0 0 0.6 0.6]);
hold on
errorbar(Q_g.*60000,dP,HFC_Gas_E(:,2),...
    '.k','MarkerSize',28,'LineWidth',1.5)
plot(HFC_Gas_M(:,1),HFC_Gas_M(:,2),'--r')
plot(HFC_Gas_MC_PX,HFC_Gas_MC_PY,'b')
grid on
set(gca,'XLim',[0.1 0.8],'YLim',[0 7000])
title('Hollow Fiber CO_2 Concentration Difference vs. Gas Flow Rate')
ylabel('Concentration Difference [\DeltaPPM CO_2]')
xlabel('Gas Flow Rate [LPM]')
legend('Experiment','Preliminary Model','Fitted Model')

% h2 = figure('units','normalized','position',[0 0 0.6 0.6]);
% hold on
% errorbar(HFC_Gas(:,1),HFC_Gas(:,2),HFC_Gas_E(:,2),...
%     '.k','MarkerSize',28,'LineWidth',1.5)
% plot(HFC_Gas_M(:,1),HFC_Gas_M(:,2),'--r')
% grid on
% set(gca,'XLim',[0.1 0.7],'YLim',[0 3000])
% title('Hollow Fiber CO_2 Concentration Difference vs. Gas Flow Rate')
% ylabel('Concentration Difference [\DeltaPPM CO_2]')
% xlabel('Gas Flow Rate [SLPM]')
% legend('Experiment','Preliminary Model')

% h3 = figure('units','normalized','position',[0 0 0.6 0.6]);
% hold on
% errorbar(HFC_Gas(:,1),HFC_Gas(:,2),HFC_Gas_E(:,2),...
%     '.k','MarkerSize',28,'LineWidth',1.5)
% plot(HFC_Gas_MC_PX,HFC_Gas_MC_PY,'b')
% grid on
% set(gca,'XLim',[0.1 0.7],'YLim',[0 3000])
% title('Hollow Fiber CO_2 Concentration Difference vs. Gas Flow Rate')
% ylabel('Concentration Difference [\DeltaPPM CO_2]')
% xlabel('Gas Flow Rate [SLPM]')
% legend('Experiment','Fitted Model')
% 
% h4 = figure('units','normalized','position',[0 0 0.6 0.6]);
% hold on
% errorbar(HFC_Gas(:,1),HFC_Gas(:,2),HFC_Gas_E(:,2),...
%     '.k','MarkerSize',28,'LineWidth',1.5)
% grid on
% set(gca,'XLim',[0.1 0.7],'YLim',[0 3000])
% title('Hollow Fiber CO_2 Concentration Difference vs. Gas Flow Rate')
% ylabel('Concentration Difference [\DeltaPPM CO_2]')
% xlabel('Gas Flow Rate [SLPM]')

%% Save Calibrated Model Data
% save('AllCharData.mat','HFC_Gas_MC','HFC_Gas_MC_GOF','-append');