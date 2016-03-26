%returns the pressure loss for the in- and outlet of a pipe bundle
%in N/m² = Pa
%
%entry parameters of the function are
%
%fD_i           = inner hydraulic diameter of the pipes in m
%fs_1           = distance between the center of two pipes next to each
%                 other perpendicular to flow direction in m
%fs_2           = distance between the center of two pipes next to each
%                 other in flow direction in m
%fFlowSpeed     = flow speed of the fluid in the pipe in m/s
%fDyn_Visc      = dynamic viscosity of the fluid in kg/(m s)
%fDensity       = density of the fluid in kg/m³
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
%fDelta_Pressure = pressure loss in N/m²
%
%these parameters are used in the equation as follows:
%
%fDelta_Pressure = pressure_loss_in_out_bundle (fD_i, fs_1, fs_2,...
%                                          fFlowSpeed, fDyn_Visc, fDensity)

function [fDelta_Pressure] = pressure_loss_InOut_bundle(fD_i, fs_1, fs_2,...
                                           fFlowSpeed, fDyn_Visc, fDensity)

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]
%the source "VDI Wärmeatlas" will from now on be defined as [9]

%Definition of the kinematic viscosity
fKin_Visc_m = fDyn_Visc(1)/fDensity(1);

%Definition of the Reynolds number according to [1] page 232 equation
%(10.30)
%note that for a pipe bundle the hydraulic diameter is equal to the
%diameter of one of its pipes
fRe = (fFlowSpeed * fD_i) / fKin_Visc_m;

%Definition of the area relation between supply pipe and pipe bundle
%according to [9] section Lac 1 equation (4)
fArea_Relation = (pi/4)*(fD_i^2/(fs_1*fs_2));

%%
%interpolation for the friction factor at the inlet of the bundle according
%to [9] section Lac 1 Bild 2
if fRe < 2000
    fFriction_Factor = 1.1 - 0.4*fArea_Relation;
elseif 2000 <= fRe && fRe < 10000
    fFriction_Factor = 0.55 - 0.4*fArea_Relation;
elseif 10000 <= fRe && fRe < 1000000
    fFriction_Factor = 0.5 - 0.4*fArea_Relation;
elseif 1000000 <= fRe
    fFriction_Factor = 0.4 - 0.4*fArea_Relation;
else
    error('no interpolation for values of fD_o/fD_i larger than 100 in pressure_loss_pipe')
end
  
%definition of the pressure loss at the inlet of the bundle according to
%[9] section Lac equation (2)
fDelta_Pressure_In = fFriction_Factor * (fDensity(1)*fFlowSpeed^2)/2;

fDelta_Pressure_Out = ((1 -fArea_Relation)^2)*(fDensity(1)*fFlowSpeed^2)/2;

fDelta_Pressure = fDelta_Pressure_In + fDelta_Pressure_Out;

end