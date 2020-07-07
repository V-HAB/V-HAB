%returns the convection coeffcient alpha for a flow in a flat gap (two
%plates with distance h). See VDI heat Atlas 2013, Page 799 for the
%original equations
%
%entry parameters of the function are
%
% fD_Hydraulic          = Hydraulic diamater, which in this case is 2
%                         times the distance between the plates
%fLength                = length of the gap over which heta exchange takes
%                         place
%fFlowSpeed             = flow speed of the fluid in the pipe in m/s
%fDyn_Visc              = dynamic viscosity of the fluid in kg/(m s)
%fDensity               = density of the fluid in kg/m³
%fThermal_Conductivity  = thermal conductivity of the fluid in W/(m K)
%fC_p                   = heat capacity of the fluid in J/K
%fConfig                = parameter to set the function configuration 
%                         for fConfig = 0 disturbed flow is assumed
%                         for fConfig = 1 nondisturbed flow is assumed
%
%Influence of the temperature dependancy of the material values can be
%accounted for by using the average temperature between inlet and outlet
%to define them
%
%with the return parameter
%
%fConvection_alpha      = convection coeffcient in W/m²K
%
%these parameters are used in the equation as follows:
%
%fConvection_alpha=calculateConvectionPlate(fLength, fFlowSpeed, fDyn_Visc,
%                                   fDensity, fThermal_Conductivity, fC_p)

function [fConvection_alpha, tDimensionlessQuantities] = convectionFlatGap (fD_Hydraulic, fLength,...
    fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fC_p, fConfig)
%the source "Wärmeübertragung" Polifke will from now on be defined as [1]

%Definition of the kinematic viscosity
fKin_Visc = fDyn_Visc(1)/fDensity(1);

fFlowSpeed = abs(fFlowSpeed);

%Definition of the Reynolds number according to [1] page 232 equation
%(10.30)
fRe = (fFlowSpeed * fD_Hydraulic) / fKin_Visc;

%Definition of the Prandtl number according to [1] page 207 equation
%(9.13)
fPr = (fDyn_Visc(1) * fC_p(1)) / fThermal_Conductivity(1);

fNu = functions.calculateHeatTransferCoefficient.calculateNusseltFlatGap(fRe, fPr, fD_Hydraulic, fLength, fConfig);

%Definition of the Nußelt number according to [1] page 232 equation
%(10.31) transposed for fConvection_alpha the convection coeffcient
fConvection_alpha = (fNu * fThermal_Conductivity(1)) / fD_Hydraulic;

tDimensionlessQuantities.fNu = fNu;
tDimensionlessQuantities.fRe = fRe;
tDimensionlessQuantities.fPr = fPr;
end