function fDensityLookUp = calculateILDensity(this)
% calculateILDensity calculates the viscosity of an IL based on the
% temperature and the water content of the IL.
%
% output of viscosity in mPa*s OR cP (same unit)
%
% Correlates IL viscosity with temperature and water content based on VFT 
% relations of IL viscosity at fixed water contents. Intermediated values 
% of water content are interpolated LINEARLY.

% Set min and max temperature values from the experimental dataset
fMinTemp = 293; % [K]
fMaxTemp = 353; % [K]
afTemperature = linspace(fMinTemp,fMaxTemp,100);    % [K]
% Check to see which IL is being used, BMIMAc or EMIMAc
if this.afMass(this.oMT.tiN2I.BMIMAc) > 0
    % data from Stevanovic et al. 2012 for BMIMAc ([C1C4Im][OAc])
    arH2O = [0, 0.1966, 0.3958, 0.6002, 0.7992];        % [molar fraction]
    afA0 = [1230.7, 1231.3, 1236.3, 1249.1, 1267.0];    % [kg/m^3]
    afA1 = [-0.5927, -0.5888, -0.5846, -0.6230, -0.6765];   % [kg/m^3/K]
    
elseif this.afMass(this.oMT.tiN2I.EMIMAc) > 0
    % data from Stevanovic et al. 2012 for EMIMAc ([C1C2Im][OAc])
    arH2O = [0, 0.2000, 0.4040, 0.6028, 0.8020];        % [molar fraction]
    afA0 = [1281.0, 1278.3, 1282.6, 1290.2, 1295.4];    % [kg/m^3]
    afA1 = [-0.6064, -0.5862, -0.5912, -0.6089, -0.6541];   % [kg/m^3/K]
    
elseif this.afMass(this.oMT.tiN2I.BMIMAc) > 0 && this.afMass(this.oMT.tiN2I.EMIMAc) > 0
    error('No density profiles are set for mixtures of ILs')
end

% Build the density curves as a function of temperature based on the
% fitting parameters provided to fit the VFT formula in Stevanovic et al.
% 2012
mfDensity = zeros(length(afTemperature),length(arH2O));
for ii = 1:length(arH2O)
    for jj = 1:length(afTemperature)
        mfDensity(jj,ii) = afA0(ii) + afA1(ii) * afTemperature(jj);
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
if and(fTemperatureLookUp >= fMinTemp, fTemperatureLookUp < fMaxTemp)
    [~, closestIndex] = min(abs(afTemperature - fTemperatureLookUp));
    for ii = 1:length(arH2O)
        if rH2OLookUp >= arH2O(ii) && rH2OLookUp < arH2O(ii+1)
            v1 = mfDensity(closestIndex,ii+1);
            v2 = mfDensity(closestIndex,ii);
            a1 = arH2O(ii+1);
            a2 = arH2O(ii);
            break
        end       
    end
else
    error('IL temperature is out of the range necessary for determining viscosity of the IL based on temperature!')
end

fDensityLookUp = v2 - (rH2OLookUp - a2)*(v2 - v1)/(a1 - a2);

% Plot to enable if you want to look at the curves
% figure(1)
% hold on
% for ii = 1:length(arH2O)
%     plot(afTemperature,mfViscosity(:,ii))
% end
% plot(fTemperatureLookUp, fViscosityLookUp, 'o')
% legend('x_H_2_O = 0', 'x_H_2_O = 0.1843', 'x_H_2_O = 0.3889', 'x_H_2_O = 0.5951', 'x_H_2_o = 0.8004', 'guess','Location','NorthEast')
% hold off