function [fWaterEQPressure,fWaterEQMolFractionGas] = calculateWaterILEquilibrium(oLumen, oShell)
% calculate the equilibrium between water and the IL
% specifically: water in the vapor phase and water in the liquid phase
% inputs:   oLumen = gas phase in a Hollow Fiber Contactor
%           oShell = liquid phase in a Hollow Fiber Contactor
%           fTemperature = temperature of the system (assumed phase-equal)
%           fPressure = pressure of the gas phase
%           various constants and coefficients (defined below)
% outputs:  fWaterEQPressure = pressure that water in the liquid phase 
%           will equilibrate to in the gas phase
fWaterEQPressure = 0;
fWaterEQMolFractionGas = 0;

fMinTemperature = 293.15;   % [K]
fMaxTemperature = 353.15;   % [K]
fPressure = oLumen.fPressure;   % [Pa]
fTemperature = oShell.fTemperature; % [K]
if fTemperature <= fMinTemperature || fTemperature >= fMaxTemperature
    warning('IL temperature is out of range for IL-Water equilibrium calculations')
end
arShellMolarRatios = (oShell.arPartialMass ./ oShell.oMT.afMolarMass)/sum(oShell.arPartialMass ./ oShell.oMT.afMolarMass);
rMolFractionWaterInIL = arShellMolarRatios(oShell.oMT.tiN2I.H2O);

% NIST Antoine parameters for water
A = 4.6543;
B = 1435.264;
C = -64.848;
fSaturationPressureWater = (10 .^ (A - B ./ (C + fTemperature))).* 100000;

% include NRTL parameters from Roemich et al (2012) for [EMIM][Ac]
fsmallG12 = 28939;      % [J/mol]
fsmallG21 = -25691;     % [J/mol]
fAlpha12 = 0.10243;     % []
R = 8.314;              % [J/mol-K]

% calculations from Roemich et al (2012) - Non-Random Two Liquid (NRTL) Parameters
fTao12 = fsmallG12 ./ R ./ fTemperature;  % []
fTao21 = fsmallG21 ./ R ./ fTemperature;  % []
fbigG12 = exp(-fAlpha12.*fTao12);         % []
fbigG21 = exp(-fAlpha12.*fTao21);         % []

fLnActivityCoefficient = (1 - rMolFractionWaterInIL).^2 ...
                        .* ((fTao21 .* fbigG21.^2 ./ ((rMolFractionWaterInIL + (1 - rMolFractionWaterInIL)) .* fbigG21).^2) ...
                        + fTao12 .* fbigG12.^2 ./ (((1 - rMolFractionWaterInIL) + rMolFractionWaterInIL .* fbigG12).^2));

rMolFractionWaterInGas = exp(fLnActivityCoefficient) .* rMolFractionWaterInIL .* fSaturationPressureWater ./ fPressure;
fWaterEQPressure = rMolFractionWaterInGas .* fPressure;     % [Pa]
fWaterEQMolFractionGas = rMolFractionWaterInGas;

end
% %% Section for function verification
% % look up values
% fLookUpPressure = 101325;
% 
% % load experimental data set (entered manually) from above for verification
% afTemperatureData = [293.15; 303.15; 313.15; 323.15; 333.15; 343.15; 353.15];
% % afxH2O = mol fraction of water in the liquid mixture
% % each row is a new temperature, i.e.
% % afxH2O(1,:) is for 293.15 K
% afxH2OData = [0.687, 0.745, 0.782, 0.818, 0.855, 0.886, 0.933, 0.957, 1.0, 1.0, 1.0, 1.0, 1.0;...
%             0.612, 0.655, 0.686, 0.745, 0.782, 0.818, 0.855, 0.933, 0.957, 1.0, 1.0, 1.0, 1.0;...
%             0.495, 0.553, 0.612, 0.655, 0.686, 0.745, 0.782, 0.817, 0.855, 0.933, 0.956, 1.0, 1.0;...
%             0.494, 0.553, 0.612, 0.654, 0.686, 0.745, 0.781, 0.817, 0.854, 0.884, 0.932, 0.956, 1.0;...
%             0.494, 0.553, 0.611, 0.654, 0.686, 0.744, 0.781, 0.816, 0.853, 0.883, 0.931, 0.955, 1.0;...
%             0.494, 0.553, 0.611, 0.653, 0.685, 0.743, 0.780, 0.815, 0.852, 0.882 0.930, 0.954, 1.0;...
%             0.494, 0.552, 0.611, 0.653, 0.684, 0.742, 0.778, 0.814, 0.851, 0.881, 0.929, 0.952, 1.0;];
% 
% % EQ pressure data provided in mbar. 1 mbar = 100 Pa
% afEQPressureData = 100.*[1.40, 3.60, 5.41, 7.82, 11.32, 13.95, 19.30, 21.05, 23.18, 23.18, 23.18, 23.18, 23.18;...
%                     1.83, 3.05, 3.90, 8.22, 10.92, 14.75, 19.86, 24.94, 36.32, 40.86, 44.43, 44.43, 44.43;...
%                     1.45, 2.71, 4.70, 8.67, 8.71, 14.85, 18.89, 25.44, 37.12, 47.10, 64.35, 71.78, 77.86;...
%                     3.52, 5.33, 8.19, 12.77, 15.73, 25.05, 34.27, 47.32, 63.57, 79.83, 105.59, 116.02, 126.69;...
%                     6.45, 9.55, 14.71, 22.05, 26.41, 45.75, 59.26, 78.14, 103.64, 127.52, 166.52, 182.77, 199.28;...
%                     10.90, 16.11, 23.24, 37.74, 47.01, 75.58, 94.62, 122.92, 161.62, 197.12, 255.91, 283.28, 305.97;...
%                     17.80, 25.06, 38.59, 63.95, 76.87, 117.52, 147.00, 189.97, 245.64, 298.54, 386.79, 426.49, 463.22;];
%          
% figure(20)
% hold on
% for i = 1:length(afxH2OData(:,1))
%     plot(afxH2OData(i,:),afEQPressureData(i,:))
% end
% xlabel('molar fraction of H_2O')
% ylabel('partial pressure of CO_2')
% hold off
% 
% % include NRTL parameters from Roemich et al (2012) for [EMIM][Ac]
% fsmallG12 = 28939;      % [J/mol]
% fsmallG21 = -25691;     % [J/mol]
% fAlpha12 = 0.10243;     % []
% R = 8.314;              % [J/mol-K]
% 
% % NIST Antoine parameters for water
% A = 4.6543;
% B = 1435.264;
% C = -64.848;
% 
% afSaturationPressureWater = (10 .^ (A - B ./ (C + afTemperatureData))).* 100000;
% 
% % calculations from Roemich et al (2012) - Non-Random Two Liquid (NRTL) Parameters
% afTao12 = fsmallG12 ./ R ./ afTemperatureData;  % []
% afTao21 = fsmallG21 ./ R ./ afTemperatureData;  % []
% afbigG12 = exp(-fAlpha12.*afTao12);         % []
% afbigG21 = exp(-fAlpha12.*afTao21);         % []
% 
% x = linspace(0,1,100);
% for ii = 1:length(x)
%     for jj = 1:length(afTemperatureData)
%         afLnActivityCoefficient(jj,ii) = (1 - x(ii)).^2 ...
%                             .* ((afTao21(jj) .* afbigG21(jj).^2 ./ ((x(ii) + (1 - x(ii))) .* afbigG21(jj)).^2) ...
%                             + afTao12(jj) .* afbigG12(jj).^2 ./ (((1 - x(ii)) + x(ii) .* afbigG12(jj)).^2));
% 
%         afyH2O(jj,ii) = exp(afLnActivityCoefficient(jj,ii)) .* x(ii) .* afSaturationPressureWater(jj) ./ fLookUpPressure;
%         afCalculatedEQPressure(jj,ii) = afyH2O(jj,ii) .* fLookUpPressure;
%     end
% end
% 
% figure(2)
% hold on
% for i = 1:length(afCalculatedEQPressure(:,1))
%     plot(x(:),afCalculatedEQPressure(i,:))
% end
% plot(fPressure,fWaterEQPressure,'o')
% xlabel('molar fraction of H_2O')
% ylabel('partial pressure of CO_2')
% hold off
                        