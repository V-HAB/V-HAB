%returns the convection coeffcient alpha for a row of pipes which the flow 
%crosses perpendicular to the main axis of the pipes in W/m²K
%
%entry parameters of the function are
%
%fD_o                   = outer diameter of the pipes in m 
%fs_1                   = distance between the center of two pipes next to
%                         each other in m
%fFlowSpeed             = flow speed of the fluid outside the pipes in m/s
%fDyn_Visc              = dynamic viscosity of the fluid in kg/(m s)
%fDensity               = density of the fluid in kg/m³
%fThermal_Conductivity  = thermal conductivity of the fluid in W/(m K)
%fC_p                   = heat capacity of the fluid in J/K
%
%for temperature depnedant material values the values are needed for the
%average temperature between in and outlet T_m as well as the wall 
%temperature T_w
%These should be saved in the function values as vectors with the first
%entry beeing the material value for T_m and the second value for T_w
%
%for example for temperature dependant material values the inputs could be
%fDyn_Visc              = [21.9 ; 22.7]kg/(m s)
%fDensity               = [0.93; 0.88]kg/m³
%fThermal_Conductivity  = [31.6; 33] W/(m K)
%fC_p                   = [1.011; 1.013]J/K
%
%with the return parameter
%
%fConvection_alpha      = convection coeffcient in W/m²K
%
%these parameters are used in the equation as follows:
%
%fConvection_alpha = convection_one_pipe_row (fD_o, fs_1, fl, 
%           fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fC_p);

function [fConvection_alpha] = convection_one_pipe_row (fD_o, fs_1,...
    fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fC_p)
%the source "Wärmeübertragung" Polifke will from now on be defined as [1]

%the source "VDI Wärmeatlas" will from now on be defined as [9]

%fills parameter used to differentiate between calculation with temperature
%dependant material values and undependant material values
if length(fDyn_Visc) == 1
    fTemp_Dep = 0;
elseif length(fDyn_Visc) == 2
    fTemp_Dep = 1;
else
    error('wrong number of inputs for material values')
end

%Definition of the kinematic viscosity
if fTemp_Dep == 0 
    fKin_Visc_m = fDyn_Visc/fDensity;
elseif fTemp_Dep == 1
    fKin_Visc_m = fDyn_Visc(1)/fDensity(1);
    fKin_Visc_w = fDyn_Visc(2)/fDensity(2);
end

%Definition of the overflowed length of the pipes according to [9] section
%Gg 1
fOverflow_Length = (pi/2) * fD_o;

%Definition of fPsi the relation between the diameter of the pipes and the
%spacing between them according to [9] section Gg 1 equation (1)
fPsi = 1 - (pi * fD_o)/(4 * fs_1);
if fPsi < 0
    error('the area relation fPsi = 1 - (pi * fD_o)/(4 * fs_1) should not be negativ for correct inputs')
end

%Definition of the Reynolds number according to [9] section Gg 1 
%equation (6)
fRe = (fFlowSpeed * fOverflow_Length) / (fKin_Visc_m * fPsi);

%Definition of the Prandtl number according to [1] page 207 equation
%(9.13)
if fTemp_Dep == 0
    fPr_m = (fDyn_Visc * fC_p) / fThermal_Conductivity;
elseif fTemp_Dep == 1
    fPr_m = (fKin_Visc_m * fC_p(1)) / fThermal_Conductivity(1);
    fPr_w = (fKin_Visc_w * fC_p(2)) / fThermal_Conductivity(2);
end

if 10 < fRe && fRe < 10^6 && 0.6 < fPr_m && fPr_m < 10^3
    %definition of the laminar case Nußelt number according to [9] section
    %Gg 1 equation (3)
    fNu_Laminar = 0.664 * sqrt(fRe) * nthroot(fPr_m, 3); 
    %definition of the turbulent case Nußelt number according to [9] 
    %section Gg 1 equation (4)
    fNu_Turbulent = (0.037 * fRe^0.8 * fPr_m)/(1 + 2.443 * fRe^(-0.1) *...
                    (fPr_m^(2/3) - 1));
    %definition of the Nußelt number according to [9] section Gg 1 
    %equation (4)    
    fNu = 0.3 + sqrt(fNu_Laminar^2 + fNu_Turbulent^2);

%for no flow speed the Nußelt number and with it also the convection
%coeffcient alpha are set to 0
elseif fRe == 0
    fNu = 0;
%in the case that no possible solution is found the Reynolds and Prandtl 
%number are displayed as well as some key data to simplify debugging for 
%the user  
else
    fprintf(['Either the Reynolds or the Prandtl number are out of bounds. \n', ...
             'Reynolds is valid between 10 and 10^6. The value is %d \n', ...
             'Prandtl is valid between 0.6 and 10^3. The value is %d \n', ...
             'The flow speed is: %d \n', ...
             'The kinematic viscosity is %d \n'], ...
             fRe, fPr_m, fFlowSpeed, fKin_Visc_m);
    
    error('No possible equation was found in convection_one_pipe_row, either Reynolds number or Prandtl number out of bounds!')
end
if fTemp_Dep == 1
    %influence of temperature dependant material values is taken into 
    %account with this equation. According to [9] section Gg 3 equation
    %(24)+(25)
    %for cooling of the fluid
    if fPr_m/fPr_w < 1
        fNu = fNu*((fPr_m/fPr_w)^(0.11));
    %for heating
    else
        fNu = fNu*((fPr_m/fPr_w)^(0.25));
    end
end

%Definition of the Nußelt number according to [9] Section Gg 1 equation
%(5) transposed for fConvection_alpha the convection coeffcient
fConvection_alpha = (fNu * fThermal_Conductivity(1)) / fOverflow_Length;
end