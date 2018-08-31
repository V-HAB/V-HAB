%returns the convection coeffcient alpha for the interior of a single pipe
%in W/m²K
%
%entry parameters of the function are
%
%fD_Hydraulic           = inner hydraulic diameter of the pipe in m
%fLength                = length of the pipe in m
%fFlowSpeed             = flow speed of the fluid in the pipe in m/s
%fDyn_Visc              = dynamic viscosity of the fluid in kg/(m s)
%fDensity               = density of the fluid in kg/m³
%fThermal_Conductivity  = thermal conductivity of the fluid in W/(m K)
%fC_p                   = heat capacity of the fluid in J/K
%fConfig                = parameter to set the function configuration 
%                         for fConfig = 0 disturbed flow is assumed
%                         for fConfig = 1 nondisturbed flow is assumed
%
%for temperature dependant material values the values are needed for the
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
%fConvection_alpha = convection_pipe (fD_Hydraulic, fLength, fFlowSpeed,
%               fDyn_Visc, fDensity, fThermal_Conductivity, fC_p, fConfig);

function [fConvection_alpha] = convection_pipe (fD_Hydraulic, fLength,...
    fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fC_p, fConfig)

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]

%the source "VDI Wärmeatlas" will from now on be defined as [9]
    
%decides wether temperature dependancy should also be accounted for
if length(fDyn_Visc) == 2 && fConfig == 0
    fConfig = 2;
elseif length(fDyn_Visc) == 2 && fConfig == 1
    fConfig = 3;
end

%calculates the kinematic viscosity
fKin_Visc_m = fDyn_Visc(1)/fDensity(1);

%Definition of the Reynolds number according to [1] page 232 equation
%(10.30)
fRe = (fFlowSpeed * fD_Hydraulic) / fKin_Visc_m;

%Definition of the Prandtl number according to [1] page 207 equation
%(9.13)

if fConfig == 0 || fConfig == 1
    fPr_m = (fDyn_Visc * fC_p) / fThermal_Conductivity;
elseif fConfig == 2 || fConfig == 3
    fPr_m = (fDyn_Visc(1) * fC_p(1)) / fThermal_Conductivity(1);
    fPr_w = (fDyn_Visc(2) * fC_p(2)) / fThermal_Conductivity(2);
end


%checks the three possible cases of laminar flow, turbulent flow or
%transient area between those two

%%
%laminar flow
if (fRe < 2300) && (fRe ~= 0)

    %definition of the first part of the Nußelt number according to [9]
    %section Ga 2 equation (4) 
    fNu_1 = 3.66;

    %definition of the second part of the Nußelt number according to [9]
    %section Ga 2 equation (5) 
    fNu_2 = 1.615 * (fRe * fPr_m * (fD_Hydraulic/fLength)^(1/3));

    %definition of the third part of the Nußelt number according to [9]
    %section Ga 2 equation (6) 
    %this part contains the thermic and hydrodynamic inlet effects. In the
    %case of nondisturbed flow over the pipe it will be set to zero
    if fConfig == 1 || fConfig == 3
        fNu_3 = (2/(1 + 22 * fPr_m))^(1/6) * (fRe * fPr_m *...
                (fD_Hydraulic/fLength)^(1/2));
    elseif fConfig ==0 || fConfig == 2
        fNu_3 = 0;
    end

    %definition of the Nußelt number according to [9] section Ga 2 
    %equation (12)
    fNu = ( (fNu_1^3) + (0.7^3) + ((fNu_2 - 0.7)^3) + (fNu_3^3) )^(1/3);

%%
%turbulent flow
elseif (10^4 < fRe) && (fRe < 10^6) && (fPr_m < 1000) && (0.1 < fPr_m)

    %definition of the coeffcient decribing the friction within the pipe
    %according to [9] section Ga 5 equation (27)
    fFriction_Factor = (1.8 * log10(fRe) -1.5)^(-2);

    %definition of the Nußelt number according to [9] section Ga 5 
    %equation (26)
    fNu = ((fFriction_Factor/8) * fRe + fPr_m)/(1 + 12.7 *...
          sqrt(fFriction_Factor/8) * ((fPr_m^(2/3)) -1)) *...
          (1 + (fD_Hydraulic/fLength)^(2/3));

%%    
%transient area    
elseif (2300 <= fRe) && (fRe <= 10^4) && (0.6 < fPr_m) && (fPr_m < 1000)

    %in the transient area an interpolation equation is used to calculate
    %the Nußelt number. For this reason the equation used so far will also
    %be used here, but without comments.

    %definition of the interpolation coeffcient according to [9] section
    %Ga 7 equation (30)
    fInterpolation_Factor = (fRe - 2300)/(10^4 - 2300);

    %see laminar case in this code for information on equation etc
    fNu_1 = 3.66;
    fNu_2 = 1.615 * (fRe * fPr_m * (fD_Hydraulic/fLength)^(1/3));
    if fConfig == 1 || fConfig == 3
        fNu_3 = (2/(1 + 22 * fPr_m))^(1/6) * (fRe * fPr_m *...
                (fD_Hydraulic/fLength)^(1/2));
    else
        fNu_3 = 0;
    end
    fNu_Laminar = ( (fNu_1^3) + (0.7^3) + ((fNu_2 - 0.7)^3) +...
                    (fNu_3^3) )^(1/3);

    %see the turbulent case in this code for information on equations etc.
    fFriction_Factor = (1.8 * log10(fRe) -1.5)^(-2);
    fNu_Turbulent = ((fFriction_Factor/8) * fRe + fPr_m)/(1 + 12.7 *...
                    sqrt(fFriction_Factor/8) * ((fPr_m^(2/3)) -1)) *...
                    (1 + (fD_Hydraulic/fLength)^(2/3));

    %definition of the Nußelt number according to [9] section  Ga 7
    %equation (29)
    fNu = (1 - fInterpolation_Factor) * fNu_Laminar +...
           fInterpolation_Factor * fNu_Turbulent;

%in the case that the flow speed is zero, the Nußelt number is set to zero
elseif fRe == 0
    fNu = 0;
%%    
%in case that no possible solution are found the programm returns the 
%values of Reynolds and Prandtlnumber as well as some key data to simplify
%debugging for the user    
else
    fprintf(['Either the Reynolds or the Prandtl number are out of bounds. \n', ...
             'Reynolds is valid for Re < 10^6. The value is %d \n', ...
             'Prandtl is valid between 0.6 and 10^3. The value is %d \n', ...
             'The flow speed is: %d \n', ...
             'The kinematic viscosity is %d\n'], ...
             fRe, fPr_m, fFlowSpeed, fKin_Visc_m);

    error('No possible equation was found in convection_pipe, either Reynolds number or Prandtl number out of bounds!')
end

if fConfig == 2 || fConfig == 3
    %influence of temperature dependant material values is taken into 
    %account with this equation
    fNu = fNu*((fPr_m/fPr_w)^(0.11));
end

%Definition of the Nußelt number according to [1] page 232 equation
%(10.31) transposed for fConvection_alpha the convection coeffcient
fConvection_alpha = (fNu * fThermal_Conductivity(1)) / fD_Hydraulic;

end