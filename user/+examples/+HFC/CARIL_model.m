% CARIL_model.m

clear all
clc

% %% Flat Plate Contactor
% % IL used in model is [Bmim][Ac]
% % Numbers used in this model correspond to inputs for SolidWorks flow sim
% 
% 
% % constants
% R = 8.3145;             %[J/mol*K]
% T = 293;                %[K] %Lab room temp.
% 
% % IL properties
% v_d = 406;              %[mPa-s] %Dynamic viscosity of IL in (406 mPa-s @ 303 K, from Yates/ICES 2016 paper)
% p = 1.0538;             %[g/cm^3] %Density of IL in (1.0538 g cm^-3 @ 303 K, from Bogolitsyn 2008)
% v = (v_d/p)*(1e-6);     %[m^s/s] %Kinematic viscocity *equation standard*
% D = 7.52398e-11;        %[m^2/s] %Diffusivity of CO2 in IL *equation standard* (Santos 2014)
% 
% % Flat Plate Contactor numbers
% n_channels = 21;                %Number of channels
% L_gas = 5.4674;                 %[m] %Length of gas channel (215in)
% L_liquid = 5.334;               %[m] %Length of the liquid channel (21 x 10" flow channels)
% A_x_gas = 0.00635*0.003175;     %[m^2] %Gas flow channel cross sectional area (0.25 in x 0.125 in)
% A_x_liquid = 0.00635*0.003175*21;%[m^2] %Liquid channel cross sectional area (0.125" x 0.25" flow channel)
% Flow_g = linspace(.2,.6,5);     %[SLPM] %Gas flow rate
% 
% % i - iteration is for parametric variation of gas flow rate
% % j - iteration is for parametric variation of ppCO2 in inlet gas flow
% % For loop to vary gas flow rate
% for i=1:length(Flow_g)
%     Q_l = 3.065e-6;             %[m^3/s] %Liquid flow rate (183.9 mL/min)
%     Q_g(i) = Flow_g(i)/60000;   %[m^3/s] %Gas flow rate (=0.2-0.6 L/min)
%     L_c_FP = (4*A_x_gas)/(2*(0.00635+0.003175)); %[m] %Characteristic length of FPC. Hydraulic diameter of sorbent channel
%     A_FP = 0.0338709;           %[m^2] %Contact area (52.5 in^2)
%     V_FP = 0.000107540107;      %[m^3] %Contact volume, IL volume (6.563 in^3)
%     delta_C = linspace(2,4,5);  %[Torr ] %Partial pressure gradient of gas species of interest in sorbent (2-4 Torr )
%     
%     % This for loop is used to run the code over the range of partial pressure
%     % gradients
%     for j=1:length(delta_C)
%         delta_C_m = delta_C(j)/(R*T);       %[mol] %Molar concentration gradient of gas species of interest in sorbent
%         vel_gas(i) = Q_g(i)/A_x_gas;        %[m/s] %Average (superficial) gas velocity
%         vel_liquid = Q_l/A_x_liquid;        %[m/s] %Average (superficial) liquid velocity
%         
%         % Dimensionless number calculations (no units)
%         Re = ((vel_liquid*L_liquid)/v);     %Reynolds number for the IL
%         Sc = v/D;                           %(Schmidt number)
%         a = 0.646;                          %a, b, c from Cussler 2008 *I actually think we should go with
%         b = 1/2;                            % this correlation*
%         c = 1/3;
%         Sh = a*(Re^b)*(Sc^c);               %(Sherwood number)
%         %Sh = 2 + 0.991*(Re*Sc)^(1/3)
%         
%         k = Sh*D/L_c_FP;                    %Mass transfer coefficient
%         x = delta_C_m*k;                    %[mol/m^2*s] %Mass flux rate
%         n = x*A_FP;                         %[mol/s] %Molar rate of absorption
%         dP = (n*R*T)/V_FP;                  %[Torr /s] %Rate of partial pressure change
%         
%         %Residence time calculation
%         t_gas(i) = L_gas/vel_gas(i);        %[s] %Residence time of gas
%         t_liquid = (L_liquid/vel_liquid)/n_channels;    %[s] %Resisence time of liquid
%         
%         %Change in ppm calculation
%         delta_n(i) = dP*t_gas(i);           %[Torr] %Predicted partial pressure change of gas species of interest
%         % In d_ppm the rows are constant flow rate and the columns are constant
%         % concentration gradient
%         
%         d_ppm(i,j) = (delta_n(i)/760)*100*10000; %[ppm] %Predicted concentration change
%         
%         %Printing the change in concentration for the different variables
%         print = [d_ppm(i,j) delta_C(j) Flow_g(i)];
%         fprintf('The change in concentration is %g ppm CO2 for a concentration gradient of %g Torr and a gas flow rate of %g SLPM. \n', print')
%     end
% end
% 
% % calculating pressure drop across gas channel
% %kv_air = 1.5e-5; %[m^2/s] %Kinematic viscosity of air
% %aa = 0.00635; %[m] %0.25 inches in m
% %bb = 0.003175; %[m] %0.125 inches in m
% %d_h_gas = (4*(aa)*(bb))/...
% % (2*(aa+bb)); %[m] %Hydraulic diameter
% %r_h_gas = d_h_gas/2; %[m] %"hydralulic radius"?
% 
% %delta_p_gas_pa = (Q_g*(8*kv_air*L_gas)/(pi*r_h_gas^4)); %pressure drop (gas channel) in Pascals
% %delta_p_gas = ...
% % delta_p_gas_pa*(1.45e-4); %[psi] %convert from Pa to psi
% % Printing Important Parameters
% % Print commands for the important parameters
% 
% res_print = [t_gas' Flow_g'];
% fprintf('The Reynolds number is %g. \n', Re)
% fprintf('The Schmidt number is %g. \n', Sc)
% fprintf('The Sherwood number is %g. \n', Sh)
% fprintf('The residence time of the liquid is %g seconds. \n', t_liquid)
% fprintf('The residence time of the gas is %g seconds for a gas flow rate of %g SLPM. \n', res_print')
% 
% % Plotting the results
% figure(1)
% plot(Flow_g,d_ppm(:,1),Flow_g,d_ppm(:,2),Flow_g,d_ppm(:,3),Flow_g,d_ppm(:,4),Flow_g,d_ppm(:,5),'linewidth',2)
% grid on
% xlabel('Gas Flow Rate [SLPM]')
% ylabel('CO_2 Absorbed [\Deltappm]')
% title('CO_2 uptake as a function of flow rate and concentration gradient')
% legend('2 Torr Concentration Gradient','2.5 Torr Concentration Gradient','3 Torr Concentration Gradient','3.5 Torr Concentration Gradient','4 Torr Concentration Gradient')

%% Hollow Fiber Contactor
% IL used in model is [Bmim][Ac]
% Numbers used in this model correspond to inputs for SolidWorks flow sim

clear all
clc

% constants
R = 8.3145;             %[J/mol*K]
T = 293;                %[K] %Lab room temperature

% IL properties
v_d = 406;              %[mPa-s] %Dynamic viscosity of IL in (406 mPa-s @ 303 K, from Yates/Space 2016 paper)
p = 1.0538;             %[g/cm^3] %Density of IL in (1.0538 g cm^-3 @ 303 K, from Bogolitsyn 2008)
v = (v_d/p)*(1e-6);     %[m^2/s] %Kinematic viscocity *equation standard*
D = 7.52398e-11;        %[m^2/s] %Diffusivity of CO2 in IL *equation standard* (Santos 2014)

% Hollow Fiber Contactor numbers
% Length of the flow channels
L_gas = 17.9832;            %[m] %Length of gas "channels" 118 fibers (6" each)
L_liquid = 0.0315;          %[m] %Average length of particle travel across contactor
%% NOTE A_x_gas Calculated Incorrectly (used A = pi*d^2 instead of A = pi/4*d^2)
A_x_gas = 5.6385e-05/4;       %[m^2] %Gas flow channel cross sectional area
A_x_liquid = 2*((pi/4)*((0.364)*2.54/100)^2);       %[m^2] %Inlet areas of the liquid channel
Flow_g = linspace(.2,.6,5); %[SLPM] %Gas flow rate

% For loop changing the gas flow rate
for i = 1:length(Flow_g)
    Q_l = 1.51e-6;              %[m^3/s] %IL flow rate (90.6 ml/min)
    Q_g(i) = Flow_g(i)/60000;   %[m^3/s] %Gas flow rate (0.2-0.6 SLPM)
    L_c_HFM = 0.00065;          %[m] %Characteristic length (0.65 mm:fiber outer diameter)
    A_HFM = 0.035909606;        %[m^2] %Contact area (55.66 in^2)
    V_HFM = 2.1611e-06;   %[m^3] %Inner housing volume - volume occupied by fibers (10.229 in^3)
    delta_C = linspace(2,4,6);  %[Torr ] %Partial pressure gradient of gas species of interest in sorbent
    
    % This for loop is to run the code over a range of concentration gradients
    for j=1:length(delta_C)
        % Molar concentration gradient
        delta_C_m = delta_C(j)/(R*T); %[mol] %Molar concentration gradient of gas species of interest in sorbent
        
        %Velocity calculations
        vel_gas(i) = Q_g(i)/A_x_gas;    %[m/s] %Gas velocity
        vel_liquid = Q_l/A_x_liquid;    %[m/s] %Liquid velocity
        
        %HFM Calculations (Dimensionless numbers)
        Re = (L_c_HFM*vel_liquid)/v;    %Reynolds number
        Sc = v/D;                       %(Schmidt number)
        a = 0.7742;
        b = 0.67;                       %Mavroudi
        c = 1/3;                        %Sirkar, Mavroudi
        Sh = a*(Re^b)*(Sc^c);           %(Sherwood number)
        k = Sh*D/L_c_HFM;               %Mass transfer coefficient
        x = delta_C_m*k;                %[mol/m^2*s]%Mass flux rate
        n = x*A_HFM;                    %[mol/s] %Molar rate of absorption
        dP = (n*R*T)/V_HFM;             %[Torr /s] %Rate of partial pressure change
        t_gas_all(i) = L_gas/vel_gas(i); %[sec] %Residence time in s of entire system
        delta_n(i) = dP*t_gas_all(i);   %[Torr ] %Predicted partial pressure change of gas species of interest
        
        %Change in ppm calculation
        d_ppm(i,j) = (delta_n(i)/760)*100*10000; %[ppm] %Concentration change
        
        %Printing the change in concentration for the different variables
        print = [d_ppm(i,j) delta_C(j) Flow_g(i)];
        fprintf('The change in concentration is %g ppm CO2 for a concentration gradient of %g Torr and a gas flow rate of %g SLPM. \n', print')
    end
end

%Residence time calculations
t_gas = (L_gas/118)./vel_gas;       %[sec] %Residence time of the gas, divided by 118 for appropriate contactor length
t_liquid = (L_liquid/vel_liquid);   %[sec] %Residence time of liquid

% Printing Important Parameters
% Print commands for the important parameters
res_print = [t_gas' Flow_g'];
fprintf('The Reynolds number is %g. \n', Re)
fprintf('The Schmidt number is %g. \n', Sc)
fprintf('The Sherwood number is %g. \n', Sh)
fprintf('The residence time of the liquid is %g seconds. \n', t_liquid)
fprintf('The residence time of the gas is %g seconds at a gas flow rate of %g SLPM. \n', res_print')

% Plotting the results
figure(1)
plot(Flow_g,d_ppm(:,1),Flow_g,d_ppm(:,2),Flow_g,d_ppm(:,3),Flow_g,d_ppm(:,4),Flow_g,d_ppm(:,5),'linewidth',2)
grid on
xlabel('Gas Flow Rate [SLPM]')
ylabel('CO_2 Absorbed [\Deltappm]')
title('CO_2 uptake as a function of flow rate and concentration gradient')
legend('2 Torr Concentration Gradient','2.5 Torr Concentration Gradient','3 Torr Concentration Gradient','3.5 Torr Concentration Gradient','4 Torr Concentration Gradient')

% %% Interior Corner Capillary Contactor
% % IL used in model is [Bmim][Ac]
% % Numbers used in this model correspond to inputs for SolidWorks flow sim
% 
% clear all
% clc
% 
% % constants
% R = 8.3145;                 %[J/mol*K]
% T = 293;                    %[K] %Lab room temperature
% 
% % IL properties
% v_d = 406;                  %[mPa-s] %Dynamic viscosity of IL in (406 mPa-s @ 303 K, from Yates/Space 2016 paper)
% p = 1.0538;                 %[g/cm^3] %Density of IL in (1.0538 g cm^-3 @ 303 K, from Bogolitsyn 2008)
% v = (v_d/p)*(1e-6);         %[m^2/s] %Kinematic viscocity *equation standard*
% D = 7.52398e-11;            %[m^2/s] %Diffusivity of CO2 in IL *equation standard* (Santos 2014)
% 
% % Capillary Contactor numbers
% n_cap = 40;                 %number of capillaries
% L_gas = 0.2;                %[m] %Length of gas channel
% L_liquid = 5.2;             %[m] %Length of the liquid channel (40 x 130mm flow channels)
% A_x_gas = .015*.13;         %[m^2] %Gas flow channel cross sectional area from solid model (130mm x 15mm)
% A_x_liquid = 0.000933;      %[m^2] %Liquid flow channel cross sectional area
% 
% % IL and CO2 flow rates
% Flow_g = linspace(.2,.6,5); %[SLPM] %Gas flow rate
% 
% % For loop
% for i=1:length(Flow_g)
%     Q_l = 7.55e-7;              %[m^3/s] %Liquid flow rate (=45.3 mL/min; 78IL flow rate)
%     Q_g(i) = Flow_g(i)/60000;   %[m^3/s] %Gas flow rate (0.2-0.6 SLPM)
%     
%     % Capillary contactor parameters
%     z = tand(15);               %hydraulic parameter
%     h = 9.33/1000;              %[m] %height of channel
%     L_c_CC = z*h/(sqrt(1+z^2)); %[m] %Hydraulic diameter of sorbent channel
%     A_CC = 0.13*0.2;            %[m^2] %contacting area from solid model
%     V_CC = A_x_liquid*.13;      %[m^3] %contacting volume (IL volume)
%     
%     % Partial pressure gradient vector definition
%     delta_C = linspace(2,4,6); %[Torr ] %Partial pressure gradient of gas species of interest in sorbent
%     
%     % This for loop is to run the code over a range of concentration gradients
%     for j=1:length(delta_C)
%         % Molar concentration gradient
%         delta_C_m = delta_C(j)/(R*T);   %[mol] %molar concentration gradient of gas species of interest in sorbent
%         
%         % Flow velocities
%         vel_gas(i) = Q_g(i)/A_x_gas;    %[m/s] %average (superficial) gas velocity
%         vel_liquid = Q_l/A_x_liquid;    %[m/s] %averag liquid velocity
%         
%         % Dimensionless number calculation
%         Re = ((vel_liquid*L_liquid)/v); %Reynolds number for the IL
%         
%         %FPC Calculations
%         Sc = v/D;                       %(Schmidt number)
%         a = 1;                          %a, b, c from Cussler 2008
%         b = 1/2;
%         c = 1/3;
%         Sh = a*(Re^b)*(Sc^c);           %(Sherwood number)
%         %Sh = 2 + 0.991*(Re*Sc)^(1/3)
%         
%         k = Sh*D/L_c_CC;                %Mass transfer coefficient
%         x = delta_C_m*k;                %[mol/m^2*s %Mass flux rate
%         n = x*A_CC;                     %[mol/s] %Molar rate of absorption
%         dP = (n*R*T)/V_CC;              %[Torr /s] %Rate of partial pressure change
%         
%         %Residence time calculation
%         t_gas(i) = L_gas/vel_gas(i);    %[sec] %Residence time of gas
%         t_liquid = (L_liquid/vel_liquid)/n_cap; %[sec] %residence time of liquid
%         
%         %Change in ppm calculation
%         delta_n = dP*t_gas;                         %[Torr ] %Predicted partial pressure change of gas species of interest
%         d_ppm(i,j) = (delta_n(i)/760)*100*10000;    %[ppm] %Concentration change
%         
%         %Printing the change in concentration for the different variables
%         print = [d_ppm(i,j) delta_C(j) Flow_g(i)];
%         fprintf('The change in concentration is %g ppm CO2 for a concentration gradient of %g Torr and a gas flow rate of %g SLPM. \n', print')
%     end
% end
% 
% % calculating pressure drop across gas channel
% %kv_air = 1.5e-5; %[m^2/s] %Kinematic viscosity of air
% %aa = 0.00635; %[m] %0.25 inches in m
% %bb = 0.003175; %[m] %0.125 inches in m
% %d_h_gas = (4*(aa)*(bb))...
% % /(2*(aa+bb)); %[m] %hydraulic diameter
% %r_h_gas = d_h_gas/2; %[m] %"hydralulic radius"?
% %delta_p_gas_pa = ...
% % (Q_g*(8*kv_air*L_gas)...
% 
% % /(pi*r_h_gas^4)); %[Pa] %pressure drop (gas channel)
% %delta_p_gas = delta_p_gas_pa...
% % *(1.45e-4); %[psi] %convert from Pa to psi
% 
% % Printing Important Parameters
% % print is just a matrix used in printing concentration
% res_print = [t_gas' Flow_g'];
% % Print commands for the important parameters
% fprintf('The Reynolds number is %g. \n', Re)
% fprintf('The Schmidt number is %g. \n', Sc)
% fprintf('The Sherwood number is %g. \n', Sh)
% fprintf('The residence time of the liquid is %g seconds. \n', t_liquid)
% fprintf('The residence time of the gas is %g seconds for a gas flow rate of %g SLPM. \n', res_print')
% 
% % Plotting the results
% figure(1)
% plot(Flow_g,d_ppm(:,1),Flow_g,d_ppm(:,2),Flow_g,d_ppm(:,3),Flow_g,d_ppm(:,4),Flow_g,d_ppm(:,5),'linewidth',2)
% grid on
% xlabel('Gas Flow Rate [SLPM]')
% ylabel('CO_2 Absorbed [\Deltappm]')
% title('CO_2 uptake as a function of flow rate and concentration gradient')
% legend('2 Torr Concentration Gradient','2.5 Torr Concentration Gradient','3 Torr Concentration Gradient','3.5 Torr Concentration Gradient','4 Torr Concentration Gradient')