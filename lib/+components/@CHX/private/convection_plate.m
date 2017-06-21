%returns the convection coeffcient alpha for a flow along a plate in W/m²K
%
%entry parameters of the function are
%
%fLength                = length of the plate parallel to flow direction in m
%fFlowSpeed             = flow speed of the fluid in the pipe in m/s
%fDyn_Visc              = dynamic viscosity of the fluid in kg/(m s)
%fDensity               = density of the fluid in kg/m³
%fThermal_Conductivity  = thermal conductivity of the fluid in W/(m K)
%fC_p                   = specific heat capacity of the fluid in J/kg K
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
%fConvection_alpha=convection_plate(fLength, fFlowSpeed, fDyn_Visc,
%                                   fDensity, fThermal_Conductivity, fC_p)

function [fConvection_alpha] = convection_plate (fLength, fFlowSpeed,...
                          fDyn_Visc, fDensity, fThermal_Conductivity, fC_p)
%the source "Wärmeübertragung" Polifke will from now on be defined as [1]

%Definition of the kinematic viscosity
fKin_Visc = fDyn_Visc(1)/fDensity(1);

%Definition of the Reynolds number according to [1] page 232 equation
%(10.30)
fRe = (fFlowSpeed * fLength) / fKin_Visc;

%Definition of the Prandtl number according to [1] page 207 equation
%(9.13)
fPr = (fDyn_Visc(1) * fC_p(1)) / fThermal_Conductivity(1);

%checks the three possible cases of laminar flow, turbulent flow or
%transient area between those two

%%
%laminar flow
if (fRe < 3.2*10^5) && (fRe ~= 0) && (0.01 < fPr) && (fPr < 1000) 
    
    %correction factor for the Prandtl number according to [1] page 226
    if fPr <= 0.1
        fCorrection_Pr = 0.72 + (0.91 - 0.72)/(0.1-0.01) * (fPr - 0.01);
    elseif 0.1 < fPr && fPr <= 0.7 
        fCorrection_Pr = 0.91 + (0.99 - 0.91)/(0.7-0.1) * (fPr - 0.1);
    elseif 0.7 < fPr && fPr <= 1
        fCorrection_Pr = 0.99 + (1.0 - 0.99)/(1-0.7) * (fPr - 0.7);
    elseif 1 < fPr && fPr <= 10
        fCorrection_Pr = 1 + (1.012 - 1)/(10-1) * (fPr - 1);
    elseif 10 < fPr && fPr <= 100
        fCorrection_Pr = 1.012+ (1.027- 1.012)/(100-10) * (fPr - 10);
    elseif 100 < fPr && fPr <= 1000
        fCorrection_Pr = 1.027 + (1.058 - 1.027)/(1000-100) * (fPr - 100);
    end
    
    %Definition of the Nußelt Number according to [1] page 226 equation
    %(10.14)
    fNu = 0.664 * fRe^(1/2) * fPr^(1/3) * fCorrection_Pr;

%%
%turbulent flow
elseif (3.2*10^5<fRe)&&(fRe<10^7)&&(fRe ~= 0)&&(0.6 < fPr) && (fPr < 1000)
    
    %Definition of the Nußelt Number according to [1] page 227 equation
    %(10.20)
    fNu = 0.037 * (fRe^(0.8) - 23100) * fPr^(1/3);   

%%
%for no flow speed the Nußelt number and with it also the convection
%coeffcient alpha are set to 0
elseif fRe == 0
    fNu = 0;
    
%in case that no possible solution are found the programm returns the 
%values of Reynolds and Prandtlnumber as well as some key data to simplify
%debugging for the user   
else
    string = sprintf(' either the Reynolds or the Prandtl number are out of bounds. \n Reynolds is valid for Re < 10^7. The value is %d \n Prandtl is valid between 0.6 and 10^3. The value is %d \n the flow speed is: %d \n the kinematic viscosity is %d', fRe, fPr, fFlowSpeed, fKin_Visc);
    disp(string)
    error('no possible equation was found in convection_plate, either Reynolds number or Prandtl number out of boundaries')    
end

%Definition of the Nußelt number according to [1] page 232 equation
%(10.31) transposed for fConvection_alpha the convection coeffcient
fConvection_alpha = (fNu * fThermal_Conductivity(1)) / fLength;
    
end