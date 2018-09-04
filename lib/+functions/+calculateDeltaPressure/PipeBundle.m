%returns the pressure loss for a pipe bundle in N/m² = Pa
%
%sketch of the possible pipe configurations:
%
%                  aligend    |   shiffted     |  partially shiffted
%                 O   O   O   |  O   O   O     |  O     O     O
%                 O   O   O   |    O   O   O   |    O     O    O
%
%                                       /|\
%                  flow direction:       |
%
%entry parameters of the function are
%
%fD_o           = outer hydraulic diameter of the pipes in m
%fs_1           = distance between the center of two pipes next to each
%                 other perpendicular to flow direction in m
%fs_2           = distance between the center of two pipes next to each
%                 other in flow direction in m
%fN_Rows        = number of pipe rows
%fFlowSpeed             = flow speed of the fluid in the pipe in m/s
%fDyn_Visc      = dynamic viscosity of the fluid in kg/(m s)
%fDensity           = density of the fluid in kg/m³
%fConfig        = parameter to set the function configuration 
%               for fConfig = 0 a aligend pipe configuration is assumed
%               for fConfig = 1 a shiffted pipe configuration is assumed
%               
%for temperature depnedant material values the values are needed for the
%average temperature between in and outlet T_m as well as the wall 
%temperature T_w
%These should be saved in the function values as vectors with the first
%entry beeing the material value for T_m and the second value for T_w
%
%for example for temperature dependant material values the inputs could be
%fDyn_Visc      = [21.9 ; 22.7]kg/(m s)
%fDensity           = [0.93; 0.88]kg/m³
%
%with the return parameter
%
%fDelta_Pressure         = pressure loss in N/m²
%
%these parameters are used in the equation as follows:
%
%fDelta_Pressure = calculatePipeBundle (fD_o, fs_1, fs_2, fN_Rows, fFlowSpeed,
%                                      fDyn_Visc, fDensity, fConfig);

function [fDelta_Pressure] = calculatePipeBundle (fD_o, fs_1, fs_2, fN_Rows, fFlowSpeed, fDyn_Visc, fDensity, fConfig)

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]

%the source "VDI Wärmeatlas" will from now on be defined as [9]
    
%decides wether temperature dependancy should also be accounted for
if length(fDyn_Visc) == 2 && fConfig == 0
    fConfig = 2;
elseif length(fDyn_Visc) == 2 && fConfig == 1;
    fConfig = 3;
end

fKin_Visc_m = fDyn_Visc(1)/fDensity(1);

%Definition of the overflowed length of the pipes according to [9] section
%Gg 1
fOverflow_Length = (pi/2) * fD_o;

%Definition of fPsi the relation between the diameter of the pipes and the
%spacing between them according to [9] section Gg 1 equation (9) + (10)

if fs_2/fD_o >= 1
    fPsi = 1 - (pi * fD_o)/(4 * fs_1);

else
    fPsi = 1 - (pi * fD_o^2)/(4 * fs_1 * fs_2);
end

%Definition of the Reynolds number according to [9] section Gg 1 
%equation (6)
fRe = (fFlowSpeed * fOverflow_Length) / (fKin_Visc_m * fPsi);

%Definition of the laminar friction factor according to [9] section Lad
%equation (3) + (4)
if (fConfig == 0 || fConfig == 2) 
    fFriction_Factor_Lam = (280*pi*(((fs_2/fD_o)^0.5 -0.6)^2+0.75))/...
                         (fRe*(4*(fs_1*fs_2/(fD_o^2))-pi)*(fs_1/fD_o)^1.6);
elseif (fConfig == 1 || fConfig == 3) &&...
       (fs_2/fD_o) >= (0.5*sqrt(2*fs_1/fD_o + 1))
    fFriction_Factor_Lam = (280*pi*(((fs_2/fD_o)^0.5 -0.6)^2+0.75))/...
                        (fRe*(4*(fs_1*fs_2/(fD_o^2))-pi)*(fs_1/fD_o)^1.6);
elseif (fConfig == 1 || fConfig == 3) &&...
       (fs_2/fD_o) < 0.5*sqrt(2*fs_1/fD_o + 1)
    fFriction_Factor_Lam = (280*pi*(((fs_2/fD_o)^0.5 -0.6)^2 + 0.75))/...
              (fRe*(4*(fs_1*fs_2/(fD_o^2))-pi)*( sqrt((fs_1/(2*fD_o))^2 ...
              + (fs_2/fD_o)^2))^1.6);
end

%Defintion of the turbulent friction factor according to [9] section Lad
%equation (5) + (6)
if fConfig == 0 || fConfig == 2
    fFriction_Factor_Turb = ((0.22+1.2*((1-0.94*fD_o/fs_2)^0.6)/...
        (((fs_1/fD_o)-0.85)^1.3))*10^(0.47*(fs_2/fs_1 - 1.5))+...
        (0.03*(fs_1/fD_o - 1)*(fs_2/fD_o - 1)))/(fRe^(0.1*fs_2/fs_1));
elseif fConfig == 1 || fConfig == 3 
    fFriction_Factor_Turb = (2.5+(1.2/((fs_1/fD_o-0.85)^1.08))+...
     0.4*(fs_2/fs_1 - 1)^3 - 0.01*(fs_1/fs_2 - 1)^3)/(fRe^(0.1*fs_2/fs_1));
end

if (fConfig == 2 || fConfig == 3) && fN_Rows > 9
    %factor for temperature dependency for laminar flow and more than 9 
    %rows according to [9] section Lad 4 - 5 equation (13) + (16)
    fLaminar_Factor = (fDyn_Visc(2)/fDyn_Visc(1))^...
                        (0.57/(((4*fs_1*fs_2/(pi*fD_o^2) - 1)*fRe)^0.25));
    %factor for temperature dependency for turbulent flow according to [9]
    %section Lad 5 equation (14)
    fTemp_Turb_Factor = (fDyn_Visc(2)/fDyn_Visc(1))^0.14;
elseif (fConfig == 2 || fConfig == 3) && fN_Rows <= 9
    %factor for temperature dependency for laminar flow and less than 10 
    %rows according to [9] section Lad 5 equation (15)
    fLaminar_Factor = (fDyn_Visc(2)/fDyn_Visc(1))^(0.57*...
           ((fN_Rows/10)^0.25)/(((4*fs_1*fs_2/(pi*fD_o^2) - 1)*fRe)^0.25));
    %factor for temperature dependency for turbulent flow according to [9]
    %section Lad 5 equation (14)
    fTemp_Turb_Factor = (fDyn_Visc(2)/fDyn_Visc(1))^0.14;
else
    fLaminar_Factor = 1;
    fTemp_Turb_Factor = 1;
end

%factor for turbulent flow to calculate the influence of the number of
%pipe rows according to [9] section Lad 5 equation (17) to (20)

if (fConfig == 1 || fConfig == 3) && (fs_2/fD_o) < 0.5*sqrt(2*fs_1/fD_o +1)
    fFriction_Factor_0 = (2*(sqrt((fs_1/(2*fD_o))^2 +(fs_2/fD_o)^2)-1))/...
                         (fs_1/fD_o * (fs_1/fD_o -1));
else
    fFriction_Factor_0 = (fD_o^2)/(fs_1^2);
end
    
if 4 < fN_Rows && fN_Rows < 10
    fRow_Turb_Factor = fFriction_Factor_0 * (1/fN_Rows - 1/10);
else
    fRow_Turb_Factor = 0;
end

%combined friction factor according to [9] section Lad 5 equation (21)+(22)
if fConfig == 0 || fConfig == 2
    fFriction_Factor = fFriction_Factor_Lam * fLaminar_Factor + ...
                      (fFriction_Factor_Turb * fTemp_Turb_Factor + ...
                       fRow_Turb_Factor) * (1 - exp(-(fRe + 1000)/2000)); 
elseif fConfig == 1 || fConfig == 3
    fFriction_Factor = fFriction_Factor_Lam * fLaminar_Factor + ...
                      (fFriction_Factor_Turb * fTemp_Turb_Factor + ...
                       fRow_Turb_Factor) * (1 - exp(-(fRe + 200)/2000));
else
    error('wrong input for fConfig in pressure_loss_pipe_bundle')
end

%definition of the pressure loss according to [9] section Lad
%equation (1)

if (fConfig == 1 || fConfig == 3) && (fs_2/fD_o) < 0.5*sqrt(2*fs_1/fD_o +1)
    fN_Resistances = fN_Rows - 1;
else
    fN_Resistances = fN_Rows;
end

fDelta_Pressure = fFriction_Factor * fN_Resistances * (fDensity(1)*...
                  fFlowSpeed^2)/2;

end