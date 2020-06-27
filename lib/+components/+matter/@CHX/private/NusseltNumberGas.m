%% NusseltNumberGas: Calculates the Nusselt-Number of the Gas for the selected CHX type
function [fNu] = NusseltNumberGas(fRe, fPr, fD_Hydraulic, fLength)
% If this function is used with the Schmidt-Number instead of Prandtl it
% yields the Sherwood-Number. See VDI Heat Atlas 11. Auflage (2013) Page 15
% in Section A2, explanation of the Sherwood Number

% for fConfig = 0 disturbed flow is assumed
% for fConfig = 1 nondisturbed flow is assumed
fConfig = 1;

%laminar flow
if (fRe < 2300) && (fRe ~= 0)

    %definition of the first part of the Nußelt number according to [9]
    %section Ga 2 equation (4) 
    fNu_1 = 3.66;

    %definition of the second part of the Nußelt number according to [9]
    %section Ga 2 equation (5) 
    fNu_2 = 1.615 * (fRe * fPr * (fD_Hydraulic/fLength)^(1/3));

    %definition of the third part of the Nußelt number according to [9]
    %section Ga 2 equation (6) 
    %this part contains the thermic and hydrodynamic inlet effects. In the
    %case of nondisturbed flow over the pipe it will be set to zero
    if fConfig == 1 || fConfig == 3
        fNu_3 = (2/(1 + 22 * fPr))^(1/6) * (fRe * fPr *...
                (fD_Hydraulic/fLength)^(1/2));
    elseif fConfig ==0 || fConfig == 2
        fNu_3 = 0;
    end

    %definition of the Nußelt number according to [9] section Ga 2 
    %equation (12)
    fNu = ( (fNu_1^3) + (0.7^3) + ((fNu_2 - 0.7)^3) + (fNu_3^3) )^(1/3);

%%
%turbulent flow
elseif (10^4 < fRe) && (fRe < 10^6) && (fPr < 1000) && (0.1 < fPr)

    %definition of the coeffcient decribing the friction within the pipe
    %according to [9] section Ga 5 equation (27)
    fFriction_Factor = (1.8 * log10(fRe) -1.5)^(-2);

    %definition of the Nußelt number according to [9] section Ga 5 
    %equation (26)
    fNu = ((fFriction_Factor/8) * fRe + fPr)/(1 + 12.7 *...
          sqrt(fFriction_Factor/8) * ((fPr^(2/3)) -1)) *...
          (1 + (fD_Hydraulic/fLength)^(2/3));

%%    
%transient area    
elseif (2300 <= fRe) && (fRe <= 10^4) && (0.6 < fPr) && (fPr < 1000)

    %in the transient area an interpolation equation is used to calculate
    %the Nußelt number. For this reason the equation used so far will also
    %be used here, but without comments.

    %definition of the interpolation coeffcient according to [9] section
    %Ga 7 equation (30)
    fInterpolation_Factor = (fRe - 2300)/(10^4 - 2300);

    %see laminar case in this code for information on equation etc
    fNu_1 = 3.66;
    fNu_2 = 1.615 * (fRe * fPr * (fD_Hydraulic/fLength)^(1/3));
    if fConfig == 1 || fConfig == 3
        fNu_3 = (2/(1 + 22 * fPr))^(1/6) * (fRe * fPr *...
                (fD_Hydraulic/fLength)^(1/2));
    else
        fNu_3 = 0;
    end
    fNu_Laminar = ( (fNu_1^3) + (0.7^3) + ((fNu_2 - 0.7)^3) +...
                    (fNu_3^3) )^(1/3);

    %see the turbulent case in this code for information on equations etc.
    fFriction_Factor = (1.8 * log10(fRe) -1.5)^(-2);
    fNu_Turbulent = ((fFriction_Factor/8) * fRe + fPr)/(1 + 12.7 *...
                    sqrt(fFriction_Factor/8) * ((fPr^(2/3)) -1)) *...
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
    fprintf(' either the Reynolds or the Prandtl number are out of bounds. \n Reynolds is valid for Re < 10^6. The value is %d \n Prandtl is valid between 0.6 and 10^3. The value is %d \n the flow speed is: %d \n the kinematic viscosity is %d', fRe, fPr, fFlowSpeed, fKin_Visc_m);
    error('no possible equation was found in convection_pipe, either Reynolds number or Prandtl number out of boundaries')
end
    
end