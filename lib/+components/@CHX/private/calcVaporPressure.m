function fVaporPressure = calcVaporPressure(fTemp, sSubstance)
%The vapor pressure over temperature is required for the 
%calculation of condensation in the heat exchanger. The values and
%equation are taken from http://webbook.nist.gov for every sustance and the
%vapor pressure returned in case the substance is liquid for any pressure
%is 0 and if it is a gas for any pressure it is inf.
    
%first it is necessary to decide for which substance the vapor pressure
%should be calculated
if strcmp(sSubstance, 'CH4')
    %Anotine Equation Parameters
    if fTemp < 90.99
        %Methan is  a liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 90.99 && fTemp < 189.99
        %parameters for the vapor pressure calculation
        fA = 3.9895;
        fB = 443.028;
        fC = -0.49;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %Methan is a gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'H2')
    %Anotine Equation Parameters
    if fTemp < 21.01
        %Hydrogen is  a liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 21.01 && fTemp < 32.27
        %parameters for the vapor pressure calculation
        fA = 3.54314;
        fB = 99.395;
        fC = 7.726;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %Hydrogen is a gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'O2')
    %Anotine Equation Parameters
    if fTemp < 54.36
        %liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 54.36 && fTemp < 154.33
        %parameters for the vapor pressure calculation
        fA = 3.9523;
        fB = 340.024;
        fC = -4.144;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'H2O')
    %Anotine Equation Parameters
    if fTemp < 255.9
        %Water is  a liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 255.9 && fTemp < 379
        %parameters for the vapor pressure calculation
        fA = 4.6543;
        fB = 1435.264;
        fC = -64.848;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    elseif fTemp >= 379 && fTemp < 573
        %parameters for the vapor pressure calculation
        fA = 3.55959;
        fB = 643.748;
        fC = -198.043;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %Water is a gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'CO2') 
    %Anotine Equation Parameters
    if fTemp < 154.26
        %Carbondioxid is  a liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 154.26 && fTemp < 195.89
        %parameters for the vapor pressure calculation
        fA = 6.81228;
        fB = 1301.679;
        fC = -3.494;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %Carbondioxid is a gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'NH3') 
    %Anotine Equation Parameters
    if fTemp < 164
        %Carbondioxid is  a liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 164 && fTemp < 239.6
        %parameters for the vapor pressure calculation
        fA = 3.18757;
        fB = 596.713;
        fC = -80.78;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
  	elseif fTemp >= 239.6 && fTemp < 371.5
        %parameters for the vapor pressure calculation
        fA = 4.86886;
        fB = 1113.928;
        fC = -10.409;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %Carbondioxid is a gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'CO') 
    %for CO there were no Antoine Equation Parameters on the nist website.
    %Therefore only the boiling point is used as deciding instance
    if fTemp < 81.63
        %CO is  a liquid at this temperature
        fVaporPressure = 0;
    else
        %CO is a gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'N2') 
    %for CO there were no Antoine Equation Parameters on the nist website.
    %Therefore only the boiling point is used as deciding instance
    if fTemp < 64.14
        %liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 63.14 && fTemp < 126
        %parameters for the vapor pressure calculation
        fA = 3.7362;
        fB = 264.651;
        fC = -6.788;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %gas at this temperature
        fVaporPressure = inf;
    end
elseif strcmp(sSubstance, 'Ar')
    %Anotine Equation Parameters
    if fTemp < 83.78
        %liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 83.78 && fTemp < 150.72
        %parameters for the vapor pressure calculation
        fA = 3.29555;
        fB = 215.24;
        fC = -22.233;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5;
    else
        %gas at this temperature
        fVaporPressure = inf;
    end    
%%
%possible trace contaminants but they are not in the normal matter table
%yet

elseif strcmp(sSubstance, 'C3H6O')
    %Anotine Equation Parameters
    if fTemp < 259.16
        %liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 259.16 && fTemp < 507.6
        %parameters for the vapor pressure calculation
        fA = 4.42448;
        fB = 1312.253;
        fC = -32.445;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %gas at this temperature
        fVaporPressure = inf;
    end    
elseif strcmp(sSubstance, 'CH2CL2')
    %Anotine Equation Parameters
    if fTemp < 233
        %liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 233 && fTemp < 313
        %parameters for the vapor pressure calculation
        fA = 4.53691;
        fB = 1327.016;
        fC = -20.474;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %gas at this temperature
        fVaporPressure = inf;
    end   
elseif strcmp(sSubstance, 'CH4O')
    %Anotine Equation Parameters
    if fTemp < 288.1
        %liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 288.1 && fTemp < 353.3
        %parameters for the vapor pressure calculation
        fA = 5.20409;
        fB = 1569.613;
        fC = -34.846;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
	elseif fTemp >= 353.3 && fTemp < 512.63
        %parameters for the vapor pressure calculation
        fA = 5.15853;
        fB = 1569.613;
        fC = -34.846;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %gas at this temperature
        fVaporPressure = inf;
    end   
elseif strcmp(sSubstance, 'C8H10')
    %Anotine Equation Parameters
    if fTemp < 273
        %liquid at this temperature
        fVaporPressure = 0;
    elseif fTemp >= 273 && fTemp < 332.4
        %parameters for the vapor pressure calculation
        fA = 5.09199;
        fB = 1996.545;
        fC = -14.772;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
	elseif fTemp >= 332.4 && fTemp < 413.19
        %parameters for the vapor pressure calculation
        fA = 4.13607;
        fB = 1463.218;
        fC = -57.991;
        %Antoine Equation
        fVaporPressure = (10^(fA -(fB/(fTemp+fC))))*10^5; 
    else
        %gas at this temperature
        fVaporPressure = inf;
    end   
else
    error('the calculation for the substance %s is not available. Please visit http://webbook.nist.gov/chemistry/ and add the calculation to this file\n', sSubstance);
end

end

