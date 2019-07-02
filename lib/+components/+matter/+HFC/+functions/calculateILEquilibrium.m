% calculateILEquilibrium.m
% this function attempts to determine the directionality of CO2 mass
% transfer in conjunction with an IL in the presence of CO2, dependent on
% the temperature and pressure and the amount of CO2 present in the liquid 
% phase. Temperature and pressure are assumed equal for gas and liquid
% phases. Equation of state model taken from Yokozeki et al. 2008.

clear all
clc

% first case: [emim][Ac]
% fTemperature = 298.15;  % [K]
% fPressure = 6.5e6;      % [Pa]
% R = 8.314;              % [J/mol/K]

% 
% 
% fMassIL = 7.5 * 1e-3; % [kg]
% MolarMassIL = .17011; % [kg/mol]

% V = densityIL / MolarMassIL;

% LookUp Temperature and Mol Fraction
R = 8.314;
fDensityIL = 1052;      % [kg/m^3];
fTemperature = 283.15;  % [K]
fPressure = 101325;    % [Pa]
fVaporPressure = 6501 * 1e3;
n = 100;
x = zeros(n,2);
x(:,1) = linspace(0,1,n);  % mol fraction of CO2 (component 1)
x(:,2) = 1 - x(:,1);                    % mol fraction of IL (component 2)

% x(1) = 0.1;             
% x(2) = 1 - x(1);        

% Pure component parameters: column 1 - CO2; column 2 - BMIMAc
afMolarMass = [.04401, .19826];       % [kg/mol]
afMolarVolume = [R*fTemperature/fPressure, afMolarMass(2)/fDensityIL];
afCriticalTemperature = [304.13, 867.68];   % [K]
afCriticalPressure = [7385, 2942] * 1e3;    % [Pa]
afBeta = [1.005, 1.0; 0.43866, 1.34306; -0.10498, 0; 0.06250, 0];   % (unitless)
% Binary interaction perameters [2 x 2]
% at ii = jj, values = 0 (off-diagonal values)
afLambda = [0 0.11580; 0.53511, 0];     % (unitless)
afMixing = [0, -0.03976; -0.03976, 0];   % (unitless)
afTao = [0, 79.594; 79.594, 0];          % [K]

iSubstance = 2;

for qq = 1:n
    alpha = zeros(2,1);
    aSubstance = zeros(2,1);
    bSubstance = zeros(2,1);
    alpha_single = zeros(4,iSubstance);
    for ii = 1:iSubstance
        rTemperatureRatio(ii) = fTemperature / afCriticalTemperature(ii);

        for kk = 1:4
            alpha_single(kk,ii) = afBeta(kk,ii) * (1/rTemperatureRatio(ii) - rTemperatureRatio(ii))^(kk-1);
        end
        alpha(ii) = sum(alpha_single(:,ii));
        aSubstance(ii) = 0.427480 * R^2 * afCriticalTemperature(ii)^2 / afCriticalPressure(ii) * alpha(ii);
        bSubstance(ii) = 0.08664 * R * afCriticalTemperature(ii) / afCriticalPressure(ii);
    end

    fPressureCalculated(1) = R * fTemperature / (afMolarVolume(1) - bSubstance(1)) - aSubstance(1)/(afMolarVolume(1) * (afMolarVolume(1) + bSubstance(1)));
    fPressureCalculated(2) = R * fTemperature / (afMolarVolume(2) - bSubstance(2)) - aSubstance(2)/(afMolarVolume(2) * (afMolarVolume(2) + bSubstance(2)));

    afKparameter = zeros(2,2);
    afFugacity = zeros(2,2);
    aSingle = zeros(2,2);
    bSingle = zeros(2,2);
    aTotal = 0;
    bTotal = 0;
    for ii = 1:iSubstance
        for jj = 1:iSubstance
            afFugacity(ii,jj) = 1 + afTao(ii,jj)/fTemperature;
            afKparameter(ii,jj) = afLambda(ii,jj)*afLambda(jj,ii) * (x(qq,ii) + x(qq,jj)) / (afLambda(jj,ii) * x(qq,ii) + afLambda(ii,jj) * x(qq,jj));
            if ii == jj
                afKparameter(ii,jj) = 0;
            end
            aSingle(ii,jj) = sqrt(aSubstance(ii)*aSubstance(jj)) * afFugacity(ii,jj) * (1 - afKparameter(ii,jj)) * x(qq,ii) * x(qq,jj);
            bSingle(ii,jj) = (bSubstance(ii) + bSubstance(jj)) * (1 - afKparameter(ii,jj)) * (1 - afMixing(ii,jj)) * x(qq,ii) * x(qq,jj);        
        end
    end
    aTotal = sum(sum(aSingle));
    bTotal = 0.5 * sum(sum(bSingle));

    aPrimeSingle = zeros(2,2);
    bPrimeSingle = zeros(2,2);
    aPrimeTotal = zeros(1,2);
    bPrimeTotal = zeros(1,2);
    for ii = 1:iSubstance
        for jj = 1:iSubstance
            if ii == jj
                aPrimeSingle(ii,jj) = sqrt(aSubstance(ii)*aSubstance(jj)) * afFugacity(ii,jj) * x(qq,jj) * (1 - afKparameter(ii,jj) - 0) - aTotal;
                bPrimeSingle(ii,jj) = (bSubstance(ii) + bSubstance(jj)) * (1 - afMixing(ii,jj)) * x(qq,jj) * (1 - afKparameter(ii,jj) - 0) - bTotal;
            else
                aPrimeSingle(ii,jj) = sqrt(aSubstance(ii)*aSubstance(jj)) * afFugacity(ii,jj) * x(qq,jj) * (1 - afKparameter(ii,jj) - ((afLambda(ii,jj)*afLambda(jj,ii)*(afLambda(ii,jj) - afLambda(jj,ii))*x(qq,ii)*x(qq,jj))/((afLambda(jj,ii)*x(qq,ii) + afLambda(ii,jj)*x(qq,jj))^2))) - aTotal;
                bPrimeSingle(ii,jj) = (bSubstance(ii) + bSubstance(jj)) * (1 - afMixing(ii,jj)) * x(qq,jj) * (1 - afKparameter(ii,jj) - ((afLambda(ii,jj)*afLambda(jj,ii)*(afLambda(ii,jj) - afLambda(jj,ii))*x(qq,ii)*x(qq,jj))/((afLambda(jj,ii)*x(qq,ii) + afLambda(ii,jj)*x(qq,jj))^2))) - bTotal;    
            end
        end
        aPrimeTotal(ii) = 2 * sum(aPrimeSingle(ii,:));
        bPrimeTotal(ii) = sum(bPrimeSingle(ii,:));
    end

    % Equation of State - Fugacity Coefficient
    for ii = 1:iSubstance
        % this is actually the natural log of the Fugacity Coefficient
        afLnFugacityCoefficient(ii) = log(R * fTemperature / (fPressure * (afMolarVolume(ii) - bTotal))) + bPrimeTotal(ii) * (1/(afMolarVolume(ii) - bTotal) - aTotal/(R * fTemperature * bTotal * (afMolarVolume(ii) + bTotal))) + aTotal / (R * fTemperature * bTotal) * (aPrimeTotal(ii)/aTotal - bPrimeTotal(ii)/bTotal + 1) * log(afMolarVolume(ii) / (afMolarVolume(ii) + bTotal));
        afFugacityCoefficient(qq,ii) = exp(afLnFugacityCoefficient(ii));
    end
end

afPureLnFugacityCoefficient(1) = log(R * fTemperature / (fPressureCalculated(1) * (afMolarVolume(1) - bTotal))) + bPrimeTotal(1) * (1/(afMolarVolume(1) - bTotal) - aTotal/(R * fTemperature * bTotal * (afMolarVolume(1) + bTotal))) + aTotal / (R * fTemperature * bTotal) * (aPrimeTotal(1)/aTotal - bPrimeTotal(1)/bTotal + 1) * log(afMolarVolume(1) / (afMolarVolume(1) + bTotal));
afPureFugacityCoefficient(1) = exp(afPureLnFugacityCoefficient(1));

K1 = 0;
K2 = 220.3;
dH1 = 0;
dH2 = -30.81*1e3;       % [J/mol]
kH = 5.12e-3*1e6;       % [Pa]
% 
% % assume
zIL = 0.7;
zH2O = 1-zIL;
% 
xIL = (1+K1)*zIL + K2*zIL^2*(1 - zIL) / (1 + K1*zIL*(2-zIL) + K2*zIL^2*(3-2*zIL));
Gexcess = (1-xIL) * log((1-zIL)/((1-xIL)*(1+K1*zIL+K2*zIL^2))) + xIL*log(zIL/xIL);
activity = exp(Gexcess/R/fTemperature);
Hexcess = (1-xIL) * zIL * (K1*dH1 + K2*dH2*zIL) / (R*fTemperature*(1 + K1*zIL + K2*zIL^2));


close all

hold on
figure(1)
plot(x(:,1),afFugacityCoefficient(:,1))
ylabel('Fugacity Coefficient')
xlabel('CO2 in solution (mol fraction)')
hold off

PP = x(:,1) .* fVaporPressure .* afFugacityCoefficient(:,1) ./ afPureFugacityCoefficient(1);
PP2 = (x(:,1) .* fVaporPressure .* exp(log(afFugacityCoefficient(:,1)./x(:,1)) + (1 - afFugacityCoefficient(:,1)./x(:,1))));

% rows = different temperature; columns = different pressure (MPa)
% temperatures: [283.1; 298.1; 323.1; 348.1] K
afPressureData =    [0.0102, 0.0502, 0.1002, 0.3997, 0.6994, 0,      0,      0,      0;...
                    0.0101, 0.0502, 0.1003, 0.3999, 0.7002, 0.9996, 1.3001, 1.5001, 1.9994; ...
                    0.0104, 0.0504, 0.1004, 0.3995, 0.7003, 1.0001, 1.3002, 1.4995, 1.9993; ...
                    0.0104, 0.0505, 0.1000, 0.4002, 0.6994, 1.0003, 1.2994, 1.4997, 1.9993];

afSolubilityData =  [0.192, 0.273, 0.307, 0.357, 0.394, 0, 0, 0, 0;...
                    0.188, 0.252, 0.274, 0.324, 0.355, 0.381, 0.405, 0.420, 0.455;...
                    0.108, 0.176, 0.204, 0.263, 0.292, 0.315, 0.334, 0.346, 0.373;...
                    0.063, 0.129, 0.161, 0.226, 0.253, 0.272, 0.287, 0.294, 0.316];

figure(3)
hold on
plot(x(:,1), PP2 / 1000000);
for ii = 1:4
    plot(afSolubilityData(ii,:), afPressureData(ii,:), '--o')
end
xlabel('CO2 in solution (mol fraction)')
ylabel('Pressure / MPA')
hold off
% axis([0 1 0 10])