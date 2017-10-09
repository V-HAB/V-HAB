function [ cParams, sDefaultPhase ] = gas(oStore, fVolume, tfPartialPressure, fTemperature, rRelativeHumidity)
% Gas helper to create a gas matter phase by defining the partial pressures 
% of the components and the temperature.
%
% gas Parameters:
%   oStore              - can be a vsys but also a store, basically
%                         anything that has oMT as property
%   fVolume             - Volume in SI m3
%   tfPartialPressure   - struct containing the Partial Pressure in Pa for
%                         the substances. For example use struct('N2', 8e4, 'O2', 2e4)
%                         to generate a gas phase with 0.2 bar pressure of
%                         O2 and 0.8 bar pressure of N2
%   fTemperature        - Temperature in K - default 288.15 K
%   rRelativeHumidity   - can be used to define the relative humidity (if a
%                         partial pressure of water is defined as well, the
%                         humidity is used)
   
% Values from @matter.table
fRm           = oStore.oMT.Const.fUniversalGas;                 % ideal gas constant [J/K]

if nargin < 4 || isempty(fTemperature),         fTemperature = matter.table.Standard.Temperature; end;
if nargin < 5 || isempty(rRelativeHumidity),    rRelativeHumidity = 0; end

mfPartialPressure = zeros(1, oStore.oMT.iSubstances);
csSubstances = fieldnames(tfPartialPressure);

% from the struct we create the partial pressure vector
for iSubstance = 1:length(csSubstances)
    mfPartialPressure(oStore.oMT.tiN2I.(csSubstances{iSubstance})) = tfPartialPressure.(csSubstances{iSubstance});
end

% if a relative humidity was defined, we use it to calculate a partial
% pressure for water and add it to the mfPartialPressure vector
if rRelativeHumidity > 0
    fSaturationVaporPressureWater = oStore.oMT.calculateVaporPressure(fTemperature, 'H2O');
    % relative humidity is defined as the percentage of vapor pressure at the
    % current vapor pressure
    mfPartialPressure(oStore.oMT.tiN2I.H2O) = rRelativeHumidity * fSaturationVaporPressureWater;
end

% Find the indices of all substances that are in the flow
aiIndices = find(mfPartialPressure > 0);

% Alternative more accurate calculation: 
% Not used because the calculation within the V Hab phases also uses the
% ideal gas law

% % Go through all substances that have mass and get the density of each. 
% afRho   = zeros(1, length(aiIndices));
% 
% for iIndex = 1:length(aiIndices)
%     % Generating the paramter struct that findProperty() requires.
%     tParameters = struct();
%     tParameters.sSubstance      = oStore.oMT.csSubstances{aiIndices(iIndex)};
%     tParameters.sProperty       = 'Density';
%     tParameters.sFirstDepName   = 'Temperature';
%     tParameters.fFirstDepValue  = fTemperature;
%     tParameters.sPhaseType      = 'gas';
%     tParameters.sSecondDepName  = 'Pressure';
%     tParameters.fSecondDepValue = mfPartialPressure(aiIndices(iIndex));
%     tParameters.bUseIsobaricData = true;
%     
%     % Now we can call the findProperty() method.
%     afRho(iIndex) = oStore.oMT.findProperty(tParameters);
% end

% Now we use the ideal gas law to calculate the mass of the individual
% components:
% p V = m R T --> m = (p V) / (R T)
afMass = (mfPartialPressure .* fVolume) ./ ((fRm ./ oStore.oMT.afMolarMass) .* fTemperature);

% define the struct that is required to define the phase in the vsys:
tfMass = struct();
for iIndex = 1:length(aiIndices)
    tfMass.(oStore.oMT.csSubstances{aiIndices(iIndex)}) = afMass(aiIndices(iIndex));
end

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };

% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';
    
end
