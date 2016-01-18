function [ cParams, sDefaultPhase ] = SuitAtmosphere(oStore, fVolume, fTemperature, rRH, fPressure)
%SUITATMOSPHERE helper to create a matter phase with a standard space suit
%   atmosphere using 99.9% oxygen and 0.1% carbon dioxide.
%   If just volume given, created as a 100% oxygen atmosphere at 28900 Pa, 
%   20°C and 0% relative humidity.
%
% SuitVolume Parameters:
%   fVolume         - Volume in SI m3
%   fTemperature    - Temperature in K - default 293.15 K
%   rRH             - Relative humidity - ratio (default 0, max 1)
%   fPressure       - Pressure in Pa - default 28900 Pa

% Values from @matter.table
% ideal gas constant [J/K]
fRm = oStore.oMT.Const.fUniversalGas; 

% Molecular mass of water in [kg/mol]
fMolarMassH2O = oStore.oMT.ttxMatter.H2O.fMolarMass; 

% Molecular mass of oxygen in [kg/mol]
fMolarMassO2 = oStore.oMT.ttxMatter.O2.fMolarMass; 

% Check input arguments, set default
if nargin < 3 || isempty(fTemperature), fTemperature = matter.table.Standard.Temperature; end;
if nargin < 4 || isempty(rRH),          rRH          = 0;     end;
if nargin < 5 || isempty(fPressure),    fPressure    = 28900; end;

if rRH
    % Calculation of the saturation vapour pressure by using the MAGNUS
    % Formula(validity: -45degC <= T <= 60degC, for water); Formula is only
    % correct for pure steam, not the mixture of air and water; enhancement
    % factors can be used by a Poynting-Correction (pressure and
    % temperature dependent); the values of the enhancement factors are in
    % the range of 1+- 10^-3; thus they are neglected. Formula is also only
    % correct for water and air, not pure oxygen.
    %Source: Important new Values of the Physical Constants of 1986, Vapour
    % Pressure Formulations based on ITS-90, and Psychrometer Formulae. In:
    % Z. Meteorol. 40, 5, S. 340-344, (1990)
    
    fSaturationVapourPressure = 6.11213 * exp(17.62 * (fTemperature - 273.15) / (243.12 + (fTemperature - 273.15))) * 100;
    
    % calculate vapour pressure [Pa]
    fVapourPressure = rRH*fSaturationVapourPressure; 
    
    % calculate mass fraction of H2O in air
    fMassFractionH2O = fMolarMassH2O / fMolarMassO2 * fVapourPressure / (fPressure - fVapourPressure);
    
    % calculate molar fraction of H2O in air
    fMolarFractionH2O = fMassFractionH2O / fMolarMassH2O * fMolarMassO2; 
    
    % p V = m / M * R_m * T -> mol mass in g/mol so divide p*V=n*R*T;
    
    %calculate total mass
    fMassGes = (fPressure) * fVolume * ((fMolarFractionH2O * fMolarMassH2O + (1 - fMolarFractionH2O) * fMolarMassO2)) / fRm / fTemperature; 
    
    % calculate dry air mass
    fMass = fMassGes * (1 - fMassFractionH2O); 
    
else
    fMass = fPressure * fVolume * fMolarMassO2 / fRm / fTemperature;
    
    % Need to set this to zero in case of dry gas
    fMassGes = 0;
    fMassFractionH2O = 0;
end
% Matter composition
tfMass = struct(...
    'O2',  0.999 * fMass, ...
    'CO2', 0.001 * fMass ...
    );
% Calculate H2O mass if present 
tfMass.H2O = fMassGes * fMassFractionH2O; 

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { tfMass fVolume fTemperature };


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.gas';



end