% function rEquilibriumLookUp = calculateILEquilibriumImprovede(oLumen, oShell)
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

a = 1;
fMolFractionCO2LookUp = 0.01;
fTemperatureLookUp = 320;
fxH2OLookUp = 0;
% Data from Stevanovic et al (2012)
% oShell.afMass(oShell.oMT.tiN2I.BMIMAc) > 0
if a == 1
    fMinTemp = 303.54; % [K]
    fMaxTemp = 343.6; % [K]
    afTemperatureData = [303.54, 313.5, 323.55, 333.44, 343.5];   % [K]
    afTemperature = linspace(fMinTemp,fMaxTemp,100);    % [K]
    afxH2O = [0, 0.2045, 0.4054, 0.6426, 0.8015];
    %                       xH2O = 0
    afEqPressureData{1} =   [0,9626, 9940, 17661, 20649;  ...%
                            0,14458, 23130, 26572, NaN;   ...%
                            0,19161, 19716, 32927, NaN;   ...%
                            0,25555, 35435, NaN, NaN;...
                            0,25555, 46378, 30906, 41830];
    %                       xH2O = 0.2045
    afEqPressureData{2} =   [0;5860; 9257; 13600; 18752; 24497];
    %                       xH2O = 0.4054
    afEqPressureData{3} =   [0;4550; 7223; 11207; 15995; 21616];
    %                       xH2O = 0.6426
    afEqPressureData{4} =   [0;13388; 19029; 25625; 33128; 41094];
    %                       xH2O = 0.8015
    afEqPressureData{5} =   [0;37860; 45291; 53351; 62021; 71636];
    afEqSolubilityData{1} = [0,0.1904, 0.1932, 0.2155, 0.2188;    ...%
                            0,0.1851, 0.2043, 0.2069, NaN;        ...%
                            0,0.1730, 0.1759, 0.1945, NaN;        ...%
                            0,0.1659, 0.1766, NaN, NaN;...
                            0,0.1527, 0.1690, 0.1659, 0.1676];...
    afEqSolubilityData{2} = [0;0.1205; 0.1160; 0.1104; 0.1040; 0.0971];
    afEqSolubilityData{3} = [0;0.0656; 0.0635; 0.0606; 0.0572; 0.0534];
    afEqSolubilityData{4} = [0;0.0320; 0.0294; 0.0264; 0.0233; 0.0205];
    afEqSolubilityData{5} = [0;0.0146; 0.0129; 0.0114; 0.0101; 0.0091];
    
%     oShell.afMass(oShell.oMT.tiN2I.EMIMAc) > 0
elseif a == 0
    fMinTemp = 303.3; % [K]
    fMaxTemp = 343.3; % [K]
    afTemperatureData = [303.3, 313.4, 323.4, 333.4, 343.3];   % [K]
    afTemperature = linspace(fMinTemp,fMaxTemp,100);    % [K]
    afxH2O = [0, 0.2059, 0.4016, 0.6066];
    afEqPressureData{1} =   [2796, 4136, 5544;  ...
                            4770, 6845, 8855;   ...
                            7552, 10520, 13148; ...
                            11168, 15099, 18275];...
    afEqPressureData{2} =   [1749; 3068; 5062; 7874];
    afEqPressureData{3} =   [4325; 7223; 11156; 16149];
    afEqPressureData{4} =   [13175; 18964; 25814; 33186];
    afEqSolubilityData{1} = [0.1415, 0.1485, 0.1624;    ...
                            0.1383, 0.1443, 0.1570;     ...
                            0.1339, 0.1387, 0.1501;     ...
                            0.1283, 0.1319, 0.1421];     ...
    afEqSolubilityData{2} = [0.0765; 0.0745; 0.0728; 0.0706];
    afEqSolubilityData{3} = [0.0579; 0.0559; 0.0533; 0.0501];
    afEqSolubilityData{4} = [0.0390; 0.0358; 0.0322; 0.0287];

elseif oShell.afMass(oShell.oMT.tiN2I.BMIMAc) > 0 && oShell.afMass(oShell.oMT.tiN2I.EMIMAc) > 0
    error('No vapor-liquid equilibrium profiles are set for mixtures of ILs')
end

iTemp = 1;

for ii = 1:length(afTemperatureData)
    for iTemp = 1:length(afTemperatureData)
        afEqPressureTemp{iTemp} = afEqPressureData{1}(iTemp,~isnan(afEqPressureData{1}(iTemp,:)))';
        afEqSolubilityTemp{iTemp} = afEqSolubilityData{1}(iTemp,~isnan(afEqSolubilityData{1}(iTemp,:)))';
    %         afEqSolubilityTemp{iTemp} = afEqSolubilityTemp{iTemp}./(1+afEqSolubilityTemp{iTemp});
        oFit{iTemp} = fit(afEqSolubilityTemp{iTemp},afEqPressureTemp{iTemp},'Exp1');
        afFitCoefficentA(iTemp) = oFit{iTemp}.a(1,1);
        afFitCoefficentB(iTemp) = oFit{iTemp}.b(1,1);
    end
end

if fTemperatureLookUp <= fMinTemp
    fTemperatureLookUp = fMinTemp;
    warning('IL temperature is out of the range necessary for accurately calculating CO2 equilibrium pressure!')

elseif fTemperatureLookUp >= fMaxTemp
    fTemperatureLookUp = fMaxTemp;
    warning('IL temperature is out of the range necessary for accurately calculating CO2 equilibrium pressure!')
end

[~, closestIndex] = min(abs(afTemperatureData - fTemperatureLookUp));
deltaDirection = afTemperatureData(closestIndex) - fTemperatureLookUp;
if deltaDirection < 0
    lowerIndex = closestIndex;
    upperIndex = closestIndex + 1;        
elseif deltaDirection > 0
    upperIndex = closestIndex;
    lowerIndex = closestIndex - 1;
elseif deltaDirection == 0
    lowerIndex = NaN;
end

p1 = afFitCoefficentA(lowerIndex) * exp(afFitCoefficentB(lowerIndex) * fMolFractionCO2LookUp);
p2 = afFitCoefficentA(upperIndex) * exp(afFitCoefficentB(upperIndex) * fMolFractionCO2LookUp);
T1 = afTemperatureData(lowerIndex);
T2 = afTemperatureData(upperIndex);

fEquilibriumCO2Pressure = p1 + (p2 - p1)/(T2-T1)*(fTemperatureLookUp - T1);


% end