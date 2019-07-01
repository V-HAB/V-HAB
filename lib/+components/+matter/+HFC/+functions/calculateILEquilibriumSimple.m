function rEquilibriumLookUp = calculateILEquilibriumSimple(oLumen, oShell)
% calculateILEquilibriumSimple calculates the equilibrium loading of CO2 in
% the IL based on the temperature and pressure of the IL. A future
% iteration may also include the effect of water content in the IL.
%
% output of mol fraction CO2 in the IL (xCO2 / (xCO2 + xIL))
% oLumen = gas phase; oShell = IL phase
%
% Correlates gas pressure of the "solute" gas with how much can be absorbed
% into the solvent (equilibrium concentration) based on Vapor Liquid 
% Equilibrium curves. Separate curves are presented at different 
% temperaturs, and intermiate values of equilibrium concentrations are
% interpolated LINEARLY. 

% Set min and max temperature values from the experimental dataset
fMinTemp = 283.1; % [K]
fMaxTemp = 348.1; % [K]
afTemperatureData = [283.1, 298.1, 323.1, 348.1];   % [K]
afTemperature = linspace(fMinTemp,fMaxTemp,100);    % [K]
% Check to see which IL is being used, BMIMAc or EMIMAc
if oShell.afMass(oShell.oMT.tiN2I.BMIMAc) > 0
    % data from Shiflet and Yokozeki 2008 for BMIMAc ([C1C4Im][OAc])
    % row 1 = 283.1 K, row 2 = 298.1 K, row 3 = 323.1 K, row 4 = 348.1 K
    afPressureData =    1000000.*[0.0102, 0.0502, 0.1002, 0.3997, 0.6994, 0,      0,      0,      0;...
                    0.0101, 0.0502, 0.1003, 0.3999, 0.7002, 0.9996, 1.3001, 1.5001, 1.9994; ...
                    0.0104, 0.0504, 0.1004, 0.3995, 0.7003, 1.0001, 1.3002, 1.4995, 1.9993; ...
                    0.0104, 0.0505, 0.1000, 0.4002, 0.6994, 1.0003, 1.2994, 1.4997, 1.9993];

    afSolubilityData =  [0.192, 0.273, 0.307, 0.357, 0.394, 0, 0, 0, 0;...
                    0.188, 0.252, 0.274, 0.324, 0.355, 0.381, 0.405, 0.420, 0.455;...
                    0.108, 0.176, 0.204, 0.263, 0.292, 0.315, 0.334, 0.346, 0.373;...
                    0.063, 0.129, 0.161, 0.226, 0.253, 0.272, 0.287, 0.294, 0.316];
elseif oShell.afMass(oShell.oMT.tiN2I.EMIMAc) > 0
    % TODO: NOTE ************ Need to change this data set
    % data from Shiflet and Yokozeki 2008 for BMIMAc ([C1C4Im][OAc])
    % row 1 = 283.1 K, row 2 = 298.1 K, row 3 = 323.1 K, row 4 = 348.1 K
    afPressureData =    1000000.*[0.0102, 0.0502, 0.1002, 0.3997, 0.6994, 0,      0,      0,      0;...
                    0.0101, 0.0502, 0.1003, 0.3999, 0.7002, 0.9996, 1.3001, 1.5001, 1.9994; ...
                    0.0104, 0.0504, 0.1004, 0.3995, 0.7003, 1.0001, 1.3002, 1.4995, 1.9993; ...
                    0.0104, 0.0505, 0.1000, 0.4002, 0.6994, 1.0003, 1.2994, 1.4997, 1.9993];

    afSolubilityData =  [0.192, 0.273, 0.307, 0.357, 0.394, 0, 0, 0, 0;...
                    0.188, 0.252, 0.274, 0.324, 0.355, 0.381, 0.405, 0.420, 0.455;...
                    0.108, 0.176, 0.204, 0.263, 0.292, 0.315, 0.334, 0.346, 0.373;...
                    0.063, 0.129, 0.161, 0.226, 0.253, 0.272, 0.287, 0.294, 0.316];
elseif oShell.afMass(oShell.oMT.tiN2I.BMIMAc) > 0 && oShell.afMass(oShell.oMT.tiN2I.EMIMAc) > 0
    error('No vapor-liquid equilibrium profiles are set for mixtures of ILs')
end

fMaxPressure = max(max(afPressureData));    % [Pa]
afPressure = linspace(0,fMaxPressure,100);  % [Pa]
% fit coefficients calculated from logarithm fits to data presented in
% Shiflet and Yokozeki (2008) in an external excel file
afSlopeCoeff = [0.0462; 0.0472; 0.0485; 0.0592];
afInterceptCoeff = [0.231; 0.2618; 0.3501; 0.5464];

mrEquilibriumSolubility = zeros(length(afTemperatureData),length(afPressure));
% build the equilibrium curves as a function of gas pressure
for ii = 2:length(afPressure)
    for jj = 1:length(afTemperatureData)
        % mol fraction of CO2 in IL
        mrEquilibriumSolubility(jj,ii) = afSlopeCoeff(jj) * log(afPressure(ii)) - afInterceptCoeff(jj);
    end
end

% Look up how much water is currently in the IL as a molar fraction
fShellMolarRatios = (oShell.arPartialMass ./ oShell.oMT.afMolarMass)/sum(oShell.arPartialMass ./ oShell.oMT.afMolarMass);
rH2OLookUp = fShellMolarRatios(oShell.oMT.tiN2I.H2O);

% Look up current pressure of the gas and temperature of the IL
fPressureLookUp = oLumen.fPressure;         % [Pa]
fTemperatureLookUp = oShell.fTemperature;   % [K]

% Find the closest temperature on the curve to the current temperature. If
% the current temperature is out of bounds of the dataset, throw an error.
if fPressureLookUp < fMaxPressure
    [~, closestIndex] = min(abs(afPressure - fPressureLookUp));
    for ii = 1:length(afTemperatureData)-1
        if fTemperatureLookUp >= afTemperatureData(ii) && fTemperatureLookUp <= afTemperatureData(ii+1)
            v1 = mrEquilibriumSolubility(ii+1,closestIndex);
            v2 = mrEquilibriumSolubility(ii,closestIndex);
            a2 = afTemperatureData(ii+1);
            a1 = afTemperatureData(ii);
            break
        end       
    end
else
    error('IL pressure is out of the range necessary for determining equilibrium loading of the IL based on temperature!')
end

rEquilibriumLookUp = v2 - (fTemperatureLookUp - a2)*(v2 - v1)/(a1 - a2);

end

% Plot to enable if you want to look at the curves
% figure(1)
% hold on
% for ii = 1:length(arH2O)
%     plot(afTemperature,mfViscosity(:,ii))
% end
% plot(fTemperatureLookUp, fViscosityLookUp, 'o')
% legend('x_H_2_O = 0', 'x_H_2_O = 0.1843', 'x_H_2_O = 0.3889', 'x_H_2_O = 0.5951', 'x_H_2_o = 0.8004', 'guess','Location','NorthEast')
% hold off