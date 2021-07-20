function fNu = calculateNusseltFlatGap(fRe, fPr, fD_Hydraulic, fLength, fConfig)
%%
%laminar flow
if (fRe < 3.2*10^3) && (fRe ~= 0) 
    
    % Assuming heat exchange from both sides of the gap
    fNu1 = 7.541;
    
    fNu2 = 1.841 * (fRe * fPr * fD_Hydraulic / fLength)^(1/3);
    
    %Definition of the Nußelt Number according to [42] page 800 in VDI heat
    %atlas
    fNu = (fNu1^3 + fNu2^3)^(1/3);
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
    fprintf(' either the Reynolds or the Prandtl number are out of bounds. \n Reynolds is valid for Re < 10^6. The value is %d \n Prandtl is valid between 0.6 and 10^3. The value is %d \n \n the kinematic viscosity is %d', fRe, fPr, fKin_Visc_m);
    error('no possible equation was found in convection_pipe, either Reynolds number or Prandtl number out of boundaries')
end
end
