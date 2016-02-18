function [fEvaporationEnthalpy] = calculateEvaporationEnthalpy( ~, fTemperature )
%CALCULATEEVAPORATIONENTHALPY calculates the evaporation enthalpy of water
%for a given temperature


fA =  6.853070;        %parameters A-E can be found on VDI-Wärmeatlas
fB =  7.438040;       %chapter D3.1, page 385.
fC = -2.937595;
fD = -3.282093;
fE =  8.397378;

fCriticalTemperature = 647.096; %[K]  %critical temperature of water. VDI chapter D3.1, page 358.

fTau = (1 - (fTemperature / fCriticalTemperature));

fR = 461.5227; %[J/kg*K] specific gas constant for H2O

fEvaporationEnthalpy = fR * fCriticalTemperature * (fA * fTau^(1/3) + fB * fTau^(2/3) + fC * fTau + fD * fTau^2 + fE * fTau^6); %[J/kg] see chapter D3.1, page 358
                                                               
end

