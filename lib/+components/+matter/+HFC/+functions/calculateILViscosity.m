function fViscosityLookUp = calculateILViscosity(this)
% calculateILViscosty calculates the viscosity of an IL based on the
% temperature and the water content of the IL.
%
% output of viscosity in mPa*s OR cP (same unit)
%
% Correlates IL viscosity with temperature and water content based on VFT 
% relations of IL viscosity at fixed water contents. Intermediated values 
% of water content are interpolated LINEARLY.

% Set min and max temperature values from the experimental dataset
fMinTemp = 293; % [K]
fMaxTemp = 363; % [K]
afTemperature = linspace(fMinTemp,fMaxTemp,100);    % [K]
% Check to see which IL is being used, BMIMAc or EMIMAc
if this.afMass(this.oMT.tiN2I.BMIMAc) > 0
    % data from Stevanovic et al. 2012 for BMIMAc ([C1C4Im][OAc])
    arH2O = [0, 0.1843, 0.3889, 0.5951, 0.8004];        % [molar fraction]
    afC1 = [2.45, 1.95, 3.86, 2.07, 3.08] .* 10^-3;     % [mPa*s/K^1/2]
    afC2 = [1081, 1128, 927, 1021, 751];                % [K]
    afT0 = [185, 177, 183, 168, 175];                   % [K]
    
elseif this.afMass(this.oMT.tiN2I.EMIMAc) > 0
    % data from Stevanovic et al. 2012 for EMIMAc ([C1C2Im][OAc])
    arH2O = [0, 0.2088, 0.4000, 0.6014, 0.8023];        % [molar fraction]
    afC1 = [10.33, 1.99, 3.93, 1.83, 0.57];             % [mPa*s/K^1/2]
    afC2 = [663, 1042, 890, 1078, 1279];                % [K]
    afT0 = [199, 164, 169, 148, 126];                   % [K]
    
elseif this.afMass(this.oMT.tiN2I.BMIMAc) > 0 && this.afMass(this.oMT.tiN2I.EMIMAc) > 0
    error('No viscosity profiles are set for mixtures of ILs')
end

% Build the viscosity curves as a function of temperature based on the
% fitting parameters provided to fit the VFT formula in Stevanovic et al.
% 2012
mfViscosity = zeros(length(afTemperature),length(arH2O));
for ii = 1:length(arH2O)
    for jj = 1:length(afTemperature)
        mfViscosity(jj,ii) = afC1(ii) * afTemperature(jj)^0.5 * exp(afC2(ii)/(afTemperature(jj) - afT0(ii)));
    end
end

% Look up how much water is currently in the IL as a molar fraction
if sum(this.arPartialMass) == 0
    rH2OLookUp = 0;
else
    fMolarRatios = (this.arPartialMass ./ this.oMT.afMolarMass)/sum(this.arPartialMass ./ this.oMT.afMolarMass);
    rH2OLookUp = fMolarRatios(this.oMT.tiN2I.H2O);
end

% Look up current temperature of the IL
fTemperatureLookUp = this.fTemperature;

% Find the closest temperature on the curve to the current temperature. If
% the current temperature is out of bounds of the dataset, throw an error.
if and(fTemperatureLookUp >= fMinTemp, fTemperatureLookUp <= fMaxTemp)
    [~, closestIndex] = min(abs(afTemperature - fTemperatureLookUp));
    for ii = 1:length(arH2O)
        if rH2OLookUp >= arH2O(ii) && rH2OLookUp < arH2O(ii+1)
            v1 = mfViscosity(closestIndex,ii+1);
            v2 = mfViscosity(closestIndex,ii);
            a1 = arH2O(ii+1);
            a2 = arH2O(ii);
            break
        end       
    end
else
    error('IL temperature is out of the range necessary for determining viscosity of the IL based on temperature!')
end

fViscosityLookUp = v2 - (rH2OLookUp - a2)*(v2 - v1)/(a1 - a2);

% Plot to enable if you want to look at the curves
% figure(1)
% hold on
% for ii = 1:length(arH2O)
%     plot(afTemperature,mfViscosity(:,ii))
% end
% plot(fTemperatureLookUp, fViscosityLookUp, 'o')
% legend('x_H_2_O = 0', 'x_H_2_O = 0.1843', 'x_H_2_O = 0.3889', 'x_H_2_O = 0.5951', 'x_H_2_o = 0.8004', 'guess','Location','NorthEast')
% hold off